/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/* Ultraparse,pike, the main UltraLog Roxen module */

string cvs_version = "$Id$";
#include <module.h>
inherit "module";
inherit "caudiumlib";
inherit "wizard";

import UltraSupport;
import Util;
#include "calendar.h";

constant thread_safe = 1;
mapping report_modules = ([]);
#include "ultra.h"
#include "country.h"

#if constant(thread_create)
mapping locks = ([]);
#define THREAD_SAFE
#define LOCK(x) do { object key; if(!locks[x]) locks[x] = Thread.Mutex(); catch(key=locks[x]->lock())
#define UNLOCK() key=0; } while(0)
#define LOCKR(x) LOCK("report_"+x)
#else
#undef THREAD_SAFE
#define LOCK() do {
#define UNLOCK() } while(0)
#endif

constant module_type = MODULE_LOCATION;
constant module_name = "UltraLog: Main Module";
constant module_doc =
"The UltraLog Displayer module. Used in combination with "
"en external summarizing program.";

void create() { 
  defvar("mountpoint", "/ultra/", "Mount Point", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "+
	 "namespace of your server.");
#if 0
  defvar("dbdir", "NONE", "Database Directory", TYPE_DIR,
	 "The location of the output from the external summarizer.");
#endif
  defvar("profile", "NONE", "Profile File Name", TYPE_FILE,
	 "The name of the profile configuration file to be used.");
  defvar("maxsize", 10000, "Max Table Size", TYPE_INT,
	 "The maximum size for tables in the yearly, weekly and monthly views. "
	 "Max table size for daily views is configured in the summarizer "
	 "configuration file.");
  defvar("year", 0, "Show all Stats for Year View", TYPE_TOGGLE,
	 "If enabled, all statistics will be available in the yearly display. "
	 "The default is to disable top pages, referrers and other stats "
	 "that may require lots of memory and CPU to generate on larger "
	 "sites. Use with caution. ");
  defvar("dontshow", ({}), "Excluded Profiles", TYPE_STRING_LIST,
	 "A list of profiles to hide from the display.");
  defvar("hidden", ({}), "Hidden Stats", TYPE_STRING_LIST,
	 "A list with statistic groups to hide unless the prestate "
	 "showall is present. Hiding can be used to remove unnecessary "
	 "statistic groups that display info you don't log or "
	 "aren't interested in.");
}

string query_location() { return QUERY(mountpoint); }

string prettify (string in, int|void linkme)
{
  if(linkme && in != "Other") {
    in = http_decode_string((string)in);
    return sprintf("<a href=\"%s\">%s</a>",
		   replace(in, ({ "\"", " " }),
			   ({ "%22", "%20" })),
		   replace(sprintf("%-=60s",in),
			   ({ "&", "<", ">", "\n",  }),
			   ({"&amp;", "&lt;", "&gt;","<br>" })));
  }
  return replace(sprintf("%-=60s",http_decode_string(in)),
		 ({ "&", "<", ">", "\n",  }),
		 ({"&amp;", "&lt;", "&gt;","<br>" }));
}
constant prefix = ({ "kB", "MB", "GB", "TB", "HB"});
constant hitprefix = ({ "", "thousand", "million", "billion", "trillion"});
string sizetostr( float|int size, int|void hit, int|void start)
{
  //  werror("%O\n", size);
  if(!start && size <= 1000000.0)
    return (string)((int)size);
  if(start == 1 &&  size <= 1000.0)
    return sprintf("%d %s", (int)(size*1000.0), start ? hitprefix[--start]:"");
  float s = (float)size;
  size = start;
  while( (int)s > 999 && size < sizeof(prefix))
  {
    s /= 1000.0;
    size ++;
  }
  return sprintf("%.1f %s", s, hit ? hitprefix[size] : prefix[ size ]);
}

array unitfy(float kb)
{
  int size = 0;
  while( kb > 999.0)
  {
    kb /= 1024.0;
    size ++;
  }
  return ({ kb||0.0, prefix[ size ], size });
}

float unisize(float kb, int size)
{
  while(size--)
    kb /= 1024.0;
  return (float)kb;
}

array summarize_map(mapping m, int|void r) {
  array res = ({});
  array count=({});
  mapping  foo = ([]);
  write("mkmap...");
  int i;
  foreach(indices(m), mixed code) {
    foreach(indices(m[code]), string u) {
      //      if(r)
      //	res[i] = 
      //		foo[({ code, u, m[code][u] })] = m[code][u];
      if(r){
	werror("reverse\n");
	res += ({ ({ code, u, m[code][u] }) });
      }
      else {
	werror("normal\n");
	res += ({ ({ u, code, m[code][u] }) });
      }
      //      else
      //      	res[({ ud, code, m[code][u] })] = m[code][u];
      //	i++;
    }
  }
  write("sort("+sizeof(res)+","+i+")...");
  //  res = indices(foo);
  if(!sizeof(res)) return res;
  sort(column(res, 2), res);
  //sort(values(foo), res);
  write("done\n");
  return res;
}

mapping string_reply(string body, object id)
{
  body = sprintf("<html><head><title>UltraLog: %s</title></head>"
		 "<body bgcolor=\"white\" text=\"black\" vlink=\"#000050\" "
		 "alink=\"red\" link=\"#0000a0\"><h1>UltraLog: %s</h1>"
		 "%s</body></html>",
		 id->variables->title || "", id->variables->title || "",
		 parse_rxml(body, id));
  return http_string_answer(body);
}

int|mapping find_file(string f, object id)
{
  mixed res;
  string what, sub;
  array mods = id->conf->get_providers("ultrareporter");
  if(mods && sizeof(mods))
    report_modules = mkmapping(mods->query_report_name(), mods);
  
  if(sscanf(f, "%s/%s", what, sub) == 1)
    sub = "";
    
    
  if(what == "stats")
    res = view_log(sub, id);
  else if(what == "reports") {
    res = view_report(sub, id);
  } else if(sizeof(report_modules)) {
    res =
      "<h3><a href=\"stats/\">Website Statistics</a></h3>"
      "<h3><a href=\"reports/\">Custom Reports</a></h3>";
    id->variables->title = "Select Statistics Type";
  } else
    return http_redirect(QUERY(mountpoint)+"stats/", id);
  if(stringp(res))
    return string_reply(res, id);
  else if(arrayp(res))
    return http_string_answer(res[0], "text/x-log-table");
  return res;
}

array|mapping|string view_report(string f, object id)
{
  string res = "";
  string report, rest;
  if(!strlen(f)) {
    array prods = values(report_modules);
    sort(values(report_modules)->name, prods);
    res += "<h1>Select Report</h1><dl>";
    foreach(prods, object report) {
      res += 
	sprintf("<p><b><dt><a href=\"%s/\">%s</a></b><dd>%s",
		report->query_report_name(), report->name, report->description);
    }
    res += "</dl>";
  }
  if(sscanf(f, "%s/%s", report, rest))
  {
    LOCKR(report);
    if(report_modules[report]) 
      res = report_modules[report]->view_report(rest||"", id,  this_object());
    else
      res = "<h1>No such report: "+report+"</h1>";
    UNLOCK();
  }
  
  if(!strlen(res))
    return "No Reply";
  return res;
}

object get_statistics(string profile, string period, string action, array t,
		      mixed ... args)
{
  object stats;
  switch(period) {
   case "year":
    action = replace(action, "hour", "month");
    action = replace(action, "day", "month");
    stats = Period.Year(t[0], profiles[profile]->method, action, QUERY(maxsize), @args);
    break;
   case "month":
    action = replace(action, "hour", "day");
    action = replace(action, "month", "day");
    stats = Period.Month(@t[0..1], profiles[profile]->method, action, QUERY(maxsize), @args);
    break;
   case "week":
    action = replace(action, "hour", "day");
    action = replace(action, "month", "day");
    stats = Period.Week(t[0], t[1], profiles[profile]->method, action, QUERY(maxsize));
    break;
   case "day":
    action = replace(action, ({"month", "day"}), ({"hour", "hour"}));
    stats = Period.Day(@t, profiles[profile]->method, action, @args);
    break;
  }
  return stats;
}

#define LINK(x,y, link) ((dates && dates[y]) ? (y == sel ? sprintf("<font size=+1><b><a href=%s%s/%s/>%s</a></b></font>", base_url, period, link, x): sprintf("<a href=%s%s/%s/>%s</a>", base_url, period, link, x)) : x)

string list_years(string base_url, mapping dates, int|void sel)
{
  string period = "year";
  array out = ({});
  foreach(sort(indices(dates)), int y) {
    out += ({ LINK((string)y, y, (string)y) });
  }
  return out * "\n  <br>";
}


string list_months(string base_url, object cal, int year,
		   mapping dates, int|void sel)
{
  string period = "month";
  array m = Array.map(cal->months(), lambda(string m) { return m[..2]; });
  string out = "";
  for(int i = 0; i < 3; i ++) {
    out += "<td rowspan=6>";
    for(int e = 1; e < 12; e += 3)
      out += sprintf("&nbsp;%s\n<br>",
		     LINK(m[i+e-1], (i+e), (year+"/"+(i+e))));
    out += "</td>";
  }
  return out;
}

string list_week_date(string base_url, object cal, int year,
		      mapping dates, int|void day, int|void week) {
  object w;
  object selday;
  int ok;
  
  string res="";
  selday = day && cal->day(day);
  w = cal->day(1) -> week();
  do
  {
    mapping wd = ([]);
    object d;
    string format="";
    ok = 0;
    foreach(Array.map(w->days(), w->day), d)
    {
      int mm=d->month()->m, dd = d->month_day();
      if(dates[d->y] && dates[d->y][mm] && dates[d->y][mm][dd])
	ok = 1;
    }
    if(ok)
      if(w->w == week)
	res += sprintf("<td><b><font size=+1><a href=\"%sweek/%d/%d/\">%d</a></b></font></td>",
		       base_url, w->y /*,cal->m*/, w->w, w->w);
      else
	res += sprintf("<td><a href=\"%sweek/%d/%d/\">%d</a></td>",
		       base_url, w->y /*, cal->m*/, w->w, w->w);
    else
      res += "<td><font color=#8585858>"+w->w+"</font></td>";
    
    foreach(Array.map(w->days(), w->day), d) {
      int mm=d->month()->m, dd = d->month_day();
      if(dates[d->y] && dates[d->y][mm] && dates[d->y][mm][dd]) {
	if(selday && selday == d)
	  res += sprintf("   <td><font size=-1><b><font size=+1><a "
			 "href=\"%sday/%d/%d/%d/\">%d</a></font></b></font>"
			 "</font></td>\n", base_url, d->y,
			 mm, dd, dd);
	else 
	  res += sprintf("   <td><font size=-1><a "
			 "href=\"%sday/%d/%d/%d/\">%d</a>"
			 "</font></td>\n", base_url, d->y,
			 mm, dd, dd);
      }  else
	res += "   <td><font color=\"#858585\">"+dd+"</td>\n";
    }
    res+="  </tr><tr valign=center align=center>\n";
    w++;
  }   while (w->day(0)->month()==cal);
  return res+"</tr>";
}


int|string intify(string s){
  sscanf(s, "%d", s);
  return s;
}

string get_calendar(string profile, string base_url, array selected) {
  string out = "";
  mapping dates = profiles[profile]->method->get_available_dates();
  multiset years = (<>);
  object cal;
  selected = Array.map(selected, intify);
  out = "<obox style=caption titlecolor=white><title>Selected period of time: ";
  switch(selected[0])
  {
   case "year":
    cal = Calendar.ISO.Year(selected[1]);
    out += "Year "+selected[1]+"</title>"
      "<table cellspacing=1 cellpadding=1 width=100%><tr align=left><th>Year</th><th colspan=3>&nbsp;Month</th></tr>"
      "<tr valign=top><td>"+
      list_years(base_url, dates, selected[1])+"</td>"+
      list_months(base_url, cal, selected[1], dates[selected[1]])
      +"</table></obox>";
    break;
    
   case "month":
    cal = Calendar.ISO.Month(@selected[1..2]);
    out += cal->name()+", "+selected[1]+"</title>"
      "<table cellspacing=1 cellpadding=1 width=100%><tr align=left><th>Year</th><th colspan=3>&nbsp;Month</th><th>&nbsp;Week</th>";
    object w = cal->day(1)->week();
    foreach (Array.map(w->days(), w->day)->week_day_name(),
	     string n)
      out += sprintf("   <th>%s</th>\n", n[..1]);

    out += "  </tr>\n<tr valign=top align=center><td rowspan=6>"+
      list_years(base_url, dates, selected[1])+"</td>"+
      list_months(base_url, cal->year(), selected[1], dates[selected[1]],
		  selected[2])+
      list_week_date(base_url, cal, selected[1], dates)
      +"</table></obox>";
    break;
   case "day":
    cal = Calendar.ISO.Month(@selected[1..2]);
    out += cal->name()+" "+selected[3]+", "+selected[1]+"</title>"
      "<table cellspacing=1 cellpadding=1 width=100%><tr align=left><th>Year</th><th colspan=3>&nbsp;Month</th><th>&nbsp;Week</th>";
    w = cal->day(1)->week();
   foreach (Array.map(w->days(), w->day)->week_day_name(),
	    string n)
     out += sprintf("   <th>%s</th>\n", n[..1]);
   
   out += "  </tr>\n<tr valign=top align=center><td rowspan=6>"+
     list_years(base_url, dates, selected[1])+"</td>"+
     list_months(base_url, cal->year(), selected[1], dates[selected[1]],
		 selected[2])+
     list_week_date(base_url, cal, selected[1], dates, selected[3])
     +"</table></obox>";
   break;    
   case "week":
    cal = Calendar.ISO.Week(@selected[1..2])->day(1)->month();
    out += "Week "+selected[2]+", "+selected[1]+"</title>"
      "<table cellspacing=1 cellpadding=1 width=100%><tr align=left><th>Year</th><th colspan=3>&nbsp;Month</th><th>&nbsp;Week</th>";
    w = cal->day(1)->week();
   foreach (Array.map(w->days(), w->day)->week_day_name(),
	    string n)
     out += sprintf("   <th>%s</th>\n", n[..1]);
   
   out += "  </tr>\n<tr valign=top align=center><td rowspan=6>"+
     list_years(base_url, dates, selected[1])+"</td>"+
     list_months(base_url, cal->year(), selected[1], dates[selected[1]],
		 selected[2])+
     list_week_date(base_url, cal, selected[1], dates, 0,
		    selected[2])
     +"</table></obox>";
   break;    
  }
  
  return out;
}

array voidsorts(array e, array indices, string|void isnull)
{
  foreach(indices, int i)
    for(int ee=0; ee < sizeof(e); ee++)
      if(e[ee][i]== (isnull||"0")) e[ee][i] = "VOID";
  return e;
}

float get_period_total(array arr)
{
  float zero; 
  zero = arr[0]/1000.0;
  for(int i=1; i<sizeof(arr); i++)
    zero += (arr[i] / 1000.0);
  return zero;
}

mapping oses = ([
  "Win95":"Windows 95",
  "Win32":"Windows 95",
  "WinNT":"Windows NT",
  "Win98":"Windows 98",
  "Windows 95":"Windows 95",
  "Windows 98":"Windows 98",
  "Windows NT":"Windows NT",
  "Windows-NT":"Windows NT",
  "Windows":"Windows",
  "Mac_PowerPC":"Macintosh",
  "Mac_68K":"Macintosh",
  "Mac_68000":"Macintosh",
  "Mac_PPC":"Macintosh",
  "Macintosh":"Macintosh",
  "SCO_SV":"SCO",
  "Win16":"Windows",
  "32bit":"Windows 95",
  "16bit":"Windows",
  "16-bit":"Windows",
  "linux":"Linux",
  "TuringOS":"TuringOS",
  "HP-UX": "HP-UX"
]);
#define SUM_FULL 0
#define SUM_OS   1
#define SUM_VER  2
#define SUM_AGENT 3
#define SUM_OS_AGENT   4

mapping summarize_browsers(mapping agents,
			   int|void type)
{
  mapping done = ([]);
  mapping work = ([]);
  array inversion = indices(allocate(10)) + ({ "v", "V" });
  foreach(sort(indices(agents)), string agent)
  {
    int ok;
    string name, version, os="unknown";
    agent = (agent / "via ")[0];
    array parts = agent / "(";
    array first = parts[0] / "/";
    array aux = ({});
    foreach(parts[1..], string subpart) {
      if(ok)
	break;
      aux = (((subpart/")")[0]/"; ")*";")/";";
      if(sizeof(aux)) {
	sscanf(aux[-1], "%s)", aux[-1]);
	if(sizeof(aux) >= 2 && lower_case(aux[0]) == "compatible") {
	  array tmp2, tmp = aux[1] / " " - ({""});
	  ok = 1;
	  switch(sizeof(tmp))
	  {
	   case 0:
	    break;
	   case 1:
	    tmp = aux[1] / "/";
	    if(sizeof(tmp) > 1)
	      first = tmp;
	    break;
	   case 2:
	    tmp2 = aux[1] / "/";
	    if(sizeof(tmp2) > 1) 
	      first = tmp2;
	    else
	      first = tmp;
	    break;
	   default:
	    tmp2 = aux[1] / "/";
	    if(sizeof(tmp2) > 1) 
	      first = tmp2;
	    else first = ({
	      tmp[..sizeof(tmp)-2]*" ", 
	      tmp[-1] });
	  }
	}
      }
    }
    if(sizeof(first) > 1) {
      first[1] = first[1..]*"/";
      name = first[0];
      version = first[1];
    } else {
      name = first[0];
      version = "";
    }
    switch(name) {
     case "Mozilla":
      name = "Netscape";
      break;
     case "MSIE":
      name = "Microsoft Internet Explorer";
      break;
     default:
      if(search(name, "MSIE")!=-1)
	name = "Microsoft Internet Explorer";
    }
    foreach(indices(oses), string fos)
      if(search(agent, fos) != -1) {
	os = oses[fos];
	break;
      }
    if (os == "unknown" && sizeof(aux)) {
      if(lower_case(aux[-1]) == "nav")
	aux = aux[..sizeof(aux)-2];
      if (oses[aux[0]])          // Check if it's a particular OS,
	os = oses[aux[0]];
      else if ((sizeof(aux) > 2)) {
	array tmp = aux[2] / " " - ({});
	if(sizeof(tmp) && oses[tmp[0]])
	  os = oses[tmp[0]];
	else
	  os = aux[-1];
      } else                       // ..guess not, take the first field.
	os = aux[0];
      
      if (aux[0] == "Macintosh")
	os = aux[0];

      switch (os) {
       case "Windows 95":
       case "Windows NT":
	break;
       default:
	array tmp = (os/" " - ({""}));
	if(sizeof(tmp))
	  os = tmp[0];
      }
    }
    if(version == "")  sscanf(name, "%s - %s", name, version);
    if(version == "")  sscanf(name, "%s_%s", name, version);
    if(version == "") {
      array tmp = name / " " - ({""});
      switch(sizeof(tmp)) {
       case 2:
	if(sizeof(tmp[1] / "" - inversion)
	   != sizeof(tmp[1])) {
	  name = tmp[0];
	  version = tmp[1];
	}
	break;
       case 1:
	break;
       case 0:
	name = "unknown";
	break;
       default:
	if((int)tmp[-1]) {
	  name = tmp[..sizeof(tmp)-2]  * " ";
	  version = tmp[-1];
	}
	break;
      }
    }
    if(version == "")  sscanf(name, "%s%[0-9.]", name, version);
    sscanf(version, "%s [", version);
    name = (name / " " - ({""})) * " ";
    if(name == "Netscape") 
      sscanf(version, "%sC", version);
    catch(version = (version / " " - ({""}))[0]);
    if(!strlen(name))   name = "unknown";
    if(lower_case(os) == "compatible") os = "unknown";
    if(!search(os, "DreamPassport")) {
      sscanf(os, "%s/%s", name, version);
      os = "unknown";
    }
    sscanf(version, "%s-", version);
    sscanf(version, "%s)", version);
    switch(type) {
     case SUM_FULL:
      if(!work[name])
	work[name] = ([]);
      if(!work[name][version])
	work[name][version] = ([]);
      work[name][version][os] += agents[agent];
      break;
     case SUM_OS:
      work[os] += agents[agent];
      break;
     case SUM_OS_AGENT:
      if(!work[name])
	work[name] = ([]);
      work[name][os] += agents[agent];
      break;
     case SUM_VER:
      if(!work[name])
	work[name] = ([]);
      work[name][version] += agents[agent];
      break;
     case SUM_AGENT:
      work[name] += agents[agent];
      break;
    }
    //        if(strlen(name) < 3 || !strlen(version) || os == "unknown" ||
    //           os == "compatible")
#if 0
    if(!done[agent]) {
      done[agent]=1;
      write("-- %s:\n\t[%s] [%s] [%s]\n", agent, name, version, os);
    }
#endif
  }
  return work;
}

array do_match(array in, function filter, int negate)
{
  if(negate)
    return in - Array.filter(in, filter);
  return Array.filter(in, filter);
}

array(string)|string get_profile_list(void|int raw)
{
  array servers = indices(profiles);

  servers = 
    sort(Array.filter(servers,
		      lambda(string sname) {
			array st;
			if((st = file_stat(profile_master->savedir+sname)) &&
			   st[1] == -2)
			  return 1;
		      }));
  if(raw) return servers;
  string res;
  res = "<ul>";
  foreach(sort(servers||({})), string sname) {
    res += sprintf("<li><a href=\"%s/\">%s</a>",
		   sname, sname);
  }
  res += "</ul>";
  return res;
}

array|mapping|string view_log(string f, object id) {
  werror("view_log(%s)\n", f);
  array path = f / "/" - ({""});
  mapping v = id->variables;
  int to_exit, start, num;
  array names;
  object stats;
  string base = QUERY(mountpoint) +"stats/";
  string action = "", _date = "";
  string refocus = base, res;
  string extradiag;
  mapping gmap = ([]);
  if(!sizeof(path))
  {
    id->variables->title = "Select a Server";
    return get_profile_list();
  }
  string profile = path[0];
  if(!profiles[profile]) {
    id->variables->title = "Unknown profile: "+profile;
    return "There is no profile with the name "+profile+".";
  }
  path = path[1..];
  refocus += profile+"/redir/";
  base += profile+"/";
  while(!to_exit)
  {
    if(!sizeof(path))
    {
      path = ({ "year",  ctime(time())[20..23] });
      to_exit = 1;
    } else switch(path[0]) {
    case "year":      
    case "month":
    case "week":
    case "day":
      to_exit = 1;
      break;
    case "redir":
      array query = ({});
      if(v->type)
	query += ({ "type="+v->type });
      path = path[1..];
      if(v->view && strlen(v->view))
	switch(path[1]) {
	case "year": case "month": case "week": case "day":
	  path = ({v->view, "0"}) + path;
	  break;
	default:
	  if(path[0] != v->view) { // Change of view...
	    //	    if(search(query, "table") != -1 ||
	    //	       search(query, "export") != -1)
	    //	      query = ({}); // reset to default representation
	    path[0] = v->view;
	    path[1] = "0";
	  }
	}
      base += path*"/" +"/";
      if(v->match) query += ({ "match="+v->match });
      if(v->matchtype) query += ({ "matchtype="+v->matchtype });
      return http_redirect(base + (sizeof(query) ?
				   ("?"+query * "&"):""), id);
      
    default:
      base += path[0]+"/";
      refocus += path[0]+"/";
      if((string)((int)path[0]) == path[0])
	start = (int)path[0];
      else
	action = path[0];
      path = path[1..];
      break;
    }
  }
  
  if(sizeof(path)) 
    refocus += path * "/" + "/";
  array(int) t = Array.map(path[1..],
			   lambda(string s) {
			     int d; sscanf(s, "%d", d); return d; } );
  if(sizeof(t) == 3 && t[2] == -1)
    // Week -1 == week 1 next year
  {
    t[0]++;
    t[2] = 1;
  }
  LOCK(profile);

  gmap->load = gauge {
    switch(path[0])
    {
      // Load the correct statistics.
     case "year":
      if(views[action] && !QUERY(year) && views[action][2] & S_NOTYEAR)
	action = "pages_per_month";
      else
	action = replace(action, ({ "hour", "day" }), ({"month", "month" }));
     
      stats = Period.Year(t[0], profiles[profile]->method, action, QUERY(maxsize));
      _date = path[1];
      names = Array.transpose_old( ({ smonth_names,
				      indices(allocate(13))[1..] }) );
      break;
     case "month":
      action = replace(action, "hour", "day");
      action = replace(action, "month", "day");
      stats = Period.Month(@t[0..1], profiles[profile]->method, action, QUERY(maxsize));
      _date =  month_names[t[1] - 1] + ", "+path[1];

      array x = indices(allocate( lastdayofmonth(t[0], t[1]) +1))[1..];
      names = Array.transpose( ({ (array(string))x, x }) );
      break;
     case "week":
      action = replace(action, "hour", "day");
      action = replace(action, "month", "day");
    
      stats = Period.Week(t[0], t[1], profiles[profile]->method, action, QUERY(maxsize));
      _date = "Week "+ t[1] + ", "+t[0];
      names = weekdays(t[0], t[1]);
      break;
    
     case "day":
      action = replace(action, ({"month", "day"}), ({"hour", "hour"}));
      stats = Period.Day(@t, profiles[profile]->method, action);
      _date = (Calendar.ISO.Month(@t[..1])->day(t[2])->week_day_name() +", "+
	       (month_names[t[1] - 1])+ " "+t[2]);
      names = Array.transpose(({ Array.map(indices(allocate(24)),
					   lambda(int i){
					     return i < 10?"0"+i:""+i;
					   }), indices(allocate(24)) }));
      break;
    }
  };
  UNLOCK();
  id->variables->title = "Statistics for "+profile;
  res = sprintf("<a href=\"%s\"><h3>Select another server</h3></a><p>%s",
		QUERY(mountpoint), get_calendar(profile, base, path));
  res +=
    "<form action="+refocus+" method=post>"
    "<h4><select name=view>";
  if(!strlen(action))
    return http_redirect(refocus+"?view=pages_per_day");
  multiset allowed_views = (<>);
  
  foreach(view_names - (id->prestate->showall? ({}) : QUERY(hidden)),
	  string view)
  {
    if((search(view, "hour") != -1 && path[0] != "day")        ||
       (search(view, "day") != -1 &&
	(path[0] == "day" || path[0] == "year"))               ||
       (search(view, "month") != -1 && path[0] != "year")      ||
       (path[0] == "year" &&
	!QUERY(year) && views[view][2] & S_NOTYEAR))
      continue;
    
    allowed_views[view] = 1;
    res += sprintf("<option value=%s %s>%s\n",
		   view, view == action ? "selected":"",
		   views[view][0]);
  }

  res += "</select> ";
  object matchreg;
  v->matchtype = (int)v->matchtype;
  if(allowed_views[action]) {
    res += _date +" as <select name=type>";
    if(!v->type || search(views[action][1], v->type) == -1)
      v->type = views[action][1][0];
    foreach(views[action][1], string type)
      res += sprintf("<option value=%s %s>%s",
		     type, type == v->type ? "selected":"",
		     replace(type, "_", " "));
    res += "</select>";

    if(views[action][2] & S_MATCHBOX)
    {
      res += sprintf("<br><b>Only show entries <select name=matchtype>"
		     "<option value=0>matching<option %svalue=1>not matching"
		     "</select>: </b>"
		     "<input name=match size=30 value=\"%s\">\n",
		     v->matchtype ? "selected ":"",
		     (v->match || ""));
      if(v->match && strlen(v->match)) {
	if(catch(matchreg = Regexp(v->match)))
	  res += "<font size=-1 color=red>Currently entered is "
	    "incorrect!</font><br>";
      }
    }
  }
  res +=  "<input type=submit value=\"Select\"></h4>";
  mixed tmp, tmp2, tmp3, period;
  array sorts, arrows, counts;
  string total, entr;
  int voidme, other;
;
  
  if(stats) 
    switch(action)
    {
     case "hits_per_day":
      if(path[0] == "week") {
	arrows = ({ "Weekday", "Count" });
	sorts = ({ ({ "Weekday", "Hits", "Page Loads"}) });
      } else {
	arrows = ({ "Date", "Count" });
	sorts = ({ ({ "Date", "Hits", "Page Loads" }) });
      }
      
     case "hits_per_month":
      if(!sorts) {
	arrows = ({ "Month", "Count" });
	sorts = ({ ({ "Month", "Hits", "Page Loads",
		      "Normalized Hits", "Normalized Page Loads"}) });
	tmp2 = 1;
      }    

     case "hits_per_hour":
      if(!sorts) {
	arrows = ({ "Hour", "Count" });
	sorts = ({ ({ "Hour", "Hits", "Page Loads" }) });
	tmp2 = 0;
      }    
      counts = allocate(2);
      tmp = replace(action, "hits", "pages");
      extradiag = " neng ";
      foreach(names, array n) {
	if(tmp2)
	  sorts += ({ ({ n[0], (string)(int)stats[action][ n[1] ],
			 (string)(int)stats[tmp][ n[1] ],
			 (string)(int)stats->whits_per_month[ n[1] ],
			 (string)(int)stats->wpages_per_month[ n[1] ]
	  }) });
	else
	  sorts += ({ ({ n[0], (string)(int)stats[action][ n[1] ],
			 (string)(int)stats[tmp][ n[1] ] }) });
	
	if(stats[action][ n[1] ] > 0)
	  voidme++;
	counts[0] += stats[action][ n[1] ]/1000.0;
	counts[1] += stats[tmp][ n[1] ]/1000.0;
      }
      if(voidme > 1 && v->type != "table" && v->type != "export")
	sorts = voidsorts(sorts, tmp2? ({ 1, 2, 3, 4 }):({1,2}));
      total = sprintf("%s: %s hits and %s page loads.",
		      _date, sizetostr(counts[0], 1, 1),
		      sizetostr(counts[1], 1, 1));
      break;

      
     case "pages_per_day":
      if(path[0] == "week")
	sorts = ({ ({ "Weekday", "Page Loads" }) });
      else
	sorts = ({ ({ "Date", "Page Loads" }) });
     case "pages_per_month":
      if(!sorts) { 
	sorts = ({ ({ "Month", "Page Loads", "Normalized Page Loads" }) });
	tmp2 = 1;
      }
     case "pages_per_hour":
      if(!sorts) sorts = ({ ({ "Hour", "Page Loads" }) });
     case "hosts_per_day":
      if(!sorts) {
	if(path[0] == "week")
	  sorts = ({ ({ "Weekday", "Unique Hosts" }) });
	else
	  sorts = ({ ({ "Date", "Unique Hosts" }) });
	tmp3 = 1;
      }
     case "hosts_per_month":
      if(!sorts) { sorts = ({ ({ "Month", "Unique Hosts" }) }); tmp3 = 1; }
     case "hosts_per_hour":
      if(!sorts) { sorts = ({ ({ "Hour", "Unique Hosts" }) }); tmp3 = 1; }

      counts = allocate(1);

      foreach(names, array n) {
	if(tmp2)
	  sorts += ({ ({ n[0], (string)(int)stats[action][ n[1] ],
			 (string)(int)stats->wpages_per_month[ n[1] ]
	  }) });
	else 
	  sorts += ({ ({ n[0], (string)((int)stats[action][ n[1] ]) }) });
	counts[0] += stats[action][ n[1] ];
      }
      if(tmp3) {
	total = sprintf("%s: %s unique hosts.",
			_date, sizetostr(counts[0], 1));
      } else  {
	total = sprintf("%s: %s page loads.",
			_date, sizetostr(counts[0], 1));
      }
      extradiag = " neng ";
      break;

     case "kb_per_day":
      if(path[0] == "week")
	sorts = ({ ({ "Weekday", "Average bandwidth usage per day" }) });
      else
	sorts = ({ ({ "Date", "Average bandwidth usage per day" }) });
      tmp2 = 10800;
      tmp = action;
     case "kb_per_month":
      if(!sorts) {
	sorts = ({ ({ "Month", "Average bandwidth usage per month" }) });
	tmp2 = 1;
	tmp = "w"+action;
      }
     case "kb_per_hour":
      if(!sorts) {
	sorts = ({ ({ "Hour", "Average bandwidth usage per hour" }) });
	tmp2 = 450;
	tmp = action;
      }
      counts = allocate(2);
      foreach(names, array n) {
	sorts += ({ ({ n[0], (float)stats[tmp][ n[1] ]/tmp2 }) });
	if(stats[tmp][ n[1] ] > 0.0)
	  voidme ++;
	counts[0] += stats[action][ n[1] ];
      }
      counts[1] = unitfy(stats->avg_bandwidth);
      counts[1][1] = replace(counts[1][1], "B", "bit/s");
      sorts = Array.map(sorts,
			lambda(array a, int num) {
			  if(floatp(a[1])) {
			    a[1] = sprintf("%.2f", unisize(a[1], num));
			  }
			  return a;
			}, counts[1][2]);
      if(voidme > 1 && v->type != "table" && v->type != "export")
	sorts = voidsorts(sorts, ({ 1 }), "0.00");
      sorts[0][1] += " ("+counts[1][1]+")";
      arrows = ({ sorts[0][0], counts[1][1] });
      total = sprintf("Transferred %.2f %s (%.2f %s) during %s.",
		      @(unitfy(counts[0])[..1]),
		      (float)counts[1][0],
		      counts[1][1],
		      _date);
      break;

     case "codes":
      sorts = ({ ({ "Return Code" , "Hits", "Percentage" }) });
      if(sizeof(stats[action])) {
	period = get_period_total(values(stats[action])) || 1000000;
	foreach(sort(indices(stats[action])), int code) {
	  if(!err_msgs[code])
	    continue;
	  sorts += ({ ({ err_msgs[code], (string)stats[action][code],
			 sprintf("%.2f%%",
				 ((0.1 * stats[action][code]) / period)) }) });
	}
      }
      break;
#if 0
     case "auth_users":
      sorts = ({ ({ "Authenticated User",
		    "Number of Logins",  "Return Code" }) });
      tmp = ({});
      foreach(sort(indices(stats[action])), string user) {
	foreach(sort(indices(stats[action][user])), int code) {
	  tmp += ({ ({ user, stats[action][user][code], err_msgs[code] }) });
	}
      }
      sort(column(tmp, 1), tmp);
      sorts += reverse(tmp);
      tmp = 0;
      break;
#endif
     case "errorpages":
      sorts = ({ ({ "Num", "Path" , "Return Code", "Hits" }) });
      tmp = reverse(summarize_map(stats[action], 1));
      werror("%O\n", tmp);

     case "errefs":
      if(!sorts) {
	sorts = ({ ({ "Num", "Referrer" , "Error Page", "Hits" }) });
	tmp = reverse(summarize_map(stats[action], 1));
	tmp2 = 1;
      }
     case "refto":
      if(!sorts) {
	sorts = ({ ({ "Num", "Referrer" , "Page", "Hits" }) });
	tmp = reverse(summarize_map(stats[action], 1));
	tmp2 = 1;
      }
     case "agent_os":
      if(!sorts) {
	sorts = ({ ({ "Num", "Browser", "Operating System", "Count" }) });
	tmp = reverse(summarize_map(summarize_browsers(stats->agents,
						       SUM_OS_AGENT)));
      }
     case "agent_ver":
      if(!sorts) {
	sorts = ({ ({ "Num", "Browser", "Version", "Count" }) });
	tmp = reverse(summarize_map(summarize_browsers(stats->agents,
						       SUM_VER)));
      }
      if((num = sizeof(tmp)) > (MAXENTRY+10))
      {
	entr = "Entries "+(start+1)+" to "+
	  (min(num, start+MAXENTRY))+" of "+num+".<br>";
	string mydir = base + path*"/"+"/";
	if(start)
	  entr += sprintf(" <a href=%s>View %d to %d</a> - ", 
			  replace(mydir, action+"/"+start+"/", 
				  action+"/"+(start-MAXENTRY)+"/"), 
			  start - MAXENTRY + 1, min(start, num));
	if(start+MAXENTRY <num)
	  entr += sprintf(" <a href=%s>View %d to %d</a>.", 
			  replace(mydir, action+"/"+start+"/", 
				  action+"/"+(start+MAXENTRY)+"/"), 
			  start + MAXENTRY + 1, min(start+(MAXENTRY*2), num));
    	
      }
      for(int i = start; i < min(start+MAXENTRY, num); i++) {
	int set = 0;
	sorts += ({ ({ (string)(i + 1) ,
		       prettify(tmp[i][1], tmp2),
		       err_msgs[ tmp[i][0] ] ||
		       prettify((string)tmp[i][0]),
		       tmp[i][2] }) });
      }
      tmp = 0;
      break;
      
     case "refs":
      sorts = ({ ({ "Num", "Referrer URL" , "Hits", "Percentage" }) });
      tmp3 = 1;
     case "refsites":
      if(!sorts) {
	sorts = ({ ({ "Num", "Referrer Site" , "Hits", "Percentage" }) });
	tmp3 = 1;
      }
     case "domains":
      if(!sorts) sorts = ({ ({ "Num", "Domain" , "Hits", "Percentage" }) });
     case "sites":
      if(!sorts) sorts = ({ ({ "Num", "Host" , "Hits", "Percentage" }) });
     case "dirs":
      if(!sorts) sorts = ({ ({ "Num", "Directory" , "Hits", "Percentage" }) });
     case "redirs":
      if(!sorts) sorts = ({ ({ "Num", "Path" , "Hits", "Percentage" }) });
     case "agents":
      if(!sorts) sorts = ({ ({ "Num", "User Agent" , "Hits", "Percentage" }) });
     case "hits":
     case "pages":
      if(!sorts) sorts = ({ ({ "Num", "Page" , "Hits", "Percentage" }) });      
      other = stats[action]->Other;
      m_delete(stats[action], "Other");
      tmp = indices(stats[action]);
      gmap->filter = gauge {
	if(matchreg) {
	  tmp = do_match(tmp, matchreg->match, v->matchtype);
	  tmp2 = Array.map(tmp, lambda(mixed idx, mapping data)
				{ return data[idx]; }, stats[action]);
	} else 
	  tmp2 = values(stats[action]);
      };
      if(sizeof(tmp)) {
	period = get_period_total(tmp2);
	sorts[0][3] += sprintf("<br>(of %.0f)", period*1000);
	sorts[0][0] += "<br>";
	sorts[0][1] += "<br>";
	sorts[0][2] += "<br>";
      } else {
	tmp2 = ({});
	period = 1000000;
      }
      period += other;
      gmap->sort = gauge { 
	sort(tmp2, tmp);
      };
      tmp = reverse(tmp);
      tmp2 = start;
      if(start >= sizeof(tmp))
	start = 0;
      gmap->display = gauge {
	if((num = sizeof(tmp)) > (MAXENTRY+10))
	{
	  entr = "Entries "+(start+1)+" to "+
	    (min(num, start+MAXENTRY))+" of "+num+".<br>";
	  string mydir = base + path*"/"+"/";
	  if(v->match && strlen(v->match)) {
	    mydir += "?match="+v->match;
	    if(v->matchtype) mydir += "&matchtype="+v->matchtype;
	  }
	  if(start)
	    entr += sprintf(" <a href=%s>View %d to %d</a> - ", 
			    replace(mydir, action+"/"+tmp2+"/", 
				    action+"/"+(start-MAXENTRY)+"/"), 
			    start - MAXENTRY + 1, min(start, num));
	  if(start+MAXENTRY <num)
	    entr += sprintf(" <a href=%s>View %d to %d</a>.", 
			    replace(mydir, action+"/"+tmp2+"/", 
				    action+"/"+(start+MAXENTRY)+"/"), 
			    start + MAXENTRY + 1, min(start+(MAXENTRY*2), num));
    	
	}
	for(int i = start; i < min(start+MAXENTRY, num); i++) {
	  sorts += ({ ({ i + 1, prettify(tmp[i], tmp3),
			 (string)stats[action][ tmp[i] ],
			 sprintf("%.2f%%",
				 (0.1*((float)stats[action][ tmp[i] ] /
				       period)))
	  }) });
	}
      };
      if(other) 
	sorts += ({ ({ "", "not listed",
		       other,
		       sprintf("%.2f%%",(0.1*((float)other/period)))
	}) });
      break;
     case "common_os":
      sorts = ({ ({ "Num", "Operating System" , "Hits", "Percentage" }) });
      tmp2 = SUM_OS;
     case "agent":
      if(!sorts) {
	sorts = ({ ({ "Num", "Browser" , "Hits", "Percentage" }) });
	tmp2 = SUM_AGENT;
      }
      gmap->browser_summary = gauge {
	tmp2 = summarize_browsers(stats->agents, tmp2);
      };
      gmap->sort = gauge {
	if(sizeof(tmp2)) {
	  period = get_period_total(values(tmp2));
	} else
	  period = 1000000;
	tmp = indices(tmp2);
	sort(values(tmp2), tmp);
	tmp = reverse(tmp);
      };
      gmap->display = gauge {
	if((num = sizeof(tmp)) > (MAXENTRY+10))
	{
	  entr = "Entries "+(start+1)+" to "+
	    (min(num, start+MAXENTRY))+" of "+num+".<br>";
	  string mydir = base + path*"/"+"/";
	  if(start)
	    entr += sprintf(" <a href=%s>View %d to %d</a> - ", 
			    replace(mydir, action+"/"+start+"/", 
				    action+"/"+(start-MAXENTRY)+"/"), 
			    start - MAXENTRY + 1, min(start, num));
	  if(start+50 <num)
	    entr += sprintf(" <a href=%s>View %d to %d</a>.", 
			    replace(mydir, action+"/"+start+"/", 
				    action+"/"+(start+MAXENTRY)+"/"), 
			    start + MAXENTRY + 1, min(start+(MAXENTRY*2), num));
    	
	}
	for(int i = start; i < min(start+MAXENTRY, num); i++)
	  sorts += ({ ({ i + 1, prettify(tmp[i]), (string)tmp2[ tmp[i] ],
			 sprintf("%.2f%%",
				 (0.1*((float)tmp2[ tmp[i] ] /
				       period)))
	  }) });
      };
      break;

     case "topdomains":
      if(sizeof(stats[action])) 
	period = `+(@(({0})+values(stats[action])));
      else
	period = 1000000;
      sorts = ({ ({ "Country" , "Hits", "Percentage" }) });
      tmp = indices(stats[action]);
      sort(values(stats[action]), tmp);
      foreach(reverse(tmp), string page) 
	sorts += ({ ({ country_codes[page] || page,
		       (string)stats[action][page],
		       ((100 * stats[action][page]) / period)+"%" }) });
      break;
     
     case "agent_os_ver": 
      sorts = ({ ({ "Browser", "Version", "Operating System", "Count" }) });
      tmp = ({});
      gmap->browser_summary = gauge {
	tmp2 = summarize_browsers(stats->agents);
      };
      gmap->display = gauge {
	foreach(indices(tmp2), string browser) {
	  foreach(indices(tmp2[browser]), string ver) {
	    foreach(indices(tmp2[browser][ver]), string os) {
	      tmp += ({ ({ browser, ver, os, tmp2[browser][ver][os] }) });
	    }
	  }
	}
	sort(column(tmp, 3), tmp);
	sorts += reverse(tmp);
	tmp = tmp2 = 0;
      };
      break;

     case "sess_hour_len":
      arrows = ({ "Hour", "Minutes" });
      sorts = ({ ({ "Hour" , "Average session length" }) });
     case "sess_month_len":
      if(!sorts) {
	sorts = ({ ({ "Month" , "Average session length" }) });
	arrows = ({ "Month", "Minutes" });
	tmp2 = 1;
      }
     case "sess_day_len":
      if(!sorts) {
	if(path[0] == "week") {
	  arrows = ({ "Weekday", "Minutes" });
	  sorts = ({ ({ "Weekday", "Average session length"}) });
	} else {
	  sorts = ({ ({ "Date" , "Average session length" }) });
	  arrows = ({ "Date", "Minutes" });
	}
	tmp2 = 1;
      }
      counts = allocate(2);
      tmp = replace(action,
		    ({"hour_", "month_", "day_" }),
		    ({ "", "", ""}));
      foreach(names, array n) {
	sorts += ({ ({ n[0], sprintf("%.2f", (float)stats[tmp][ n[1]]) }) });
	if(stats[tmp][n[1]] > 0)// only count if there is any data.
	  counts[0]++;
	counts[1] += stats[tmp][n[1]];
      }
      if(counts[0] > 1 && v->type != "table" && v->type != "export")
	sorts = voidsorts(sorts, ({ 1 }), "0.00");
      if(counts[0]) 
	total = sprintf("Average sessions length for %s is %.2f minutes.",
			_date, counts[1] / counts[0]);   
      break;
     case "sessions_per_hour":
      arrows = ({ "Hour", "Average number of..." });
      sorts = ({ ({ "Hour" , "Sessions" }) });
     case "sessions_per_month":
      if(!sorts) {
	arrows = ({ "Month", "Average number of..." });
	sorts = ({ ({ "Month" , "Sessions", "Normalized Sessions" }) });
	tmp2 = 1;
      }
     case "sessions_per_day":
      extradiag = " neng ";
      if(!sorts) {
	arrows = ({ "Date", "Average number of..." });
	sorts = ({ ({ "Date" , "Sessions" }) });
      }
      counts = allocate(1);
      foreach(names, array n) {
	if(tmp2)
	  sorts += ({ ({ n[0], (string)stats[action][n[1]],
			 (string)stats->wsessions_per_month[n[1]]}) });
	else
	  sorts += ({ ({ n[0], (string)stats[action][n[1]] }) });
	if(stats[action][n[1]] > 0)
	  counts[0] += stats[action][n[1]];
      }
      if(counts[0] > 1 && v->type != "table" && v->type != "export")
	if(tmp2)
	  sorts = voidsorts(sorts, ({ 1, 2 }));
	else
	  sorts = voidsorts(sorts, ({ 1 }));
      total = sprintf("There were %s user sessions during %s.",
		      sizetostr(counts[0], 1), _date);
      break;
     case "sess_hour_hits":
      arrows = ({ "Hour", "Average number of..." });
      sorts = ({ ({ "Hour" , "Hits", "Page Loads", }) });
     case "sess_month_hits":
      if(!sorts) {
	sorts = ({ ({ "Month" , "Hits", "Page Loads", }) });
	arrows = ({ "Month", "Average number of..." });
	tmp2 = 1;
      }
     case "sess_day_hits":
      if(!sorts) {
	arrows = ({ "Date", "Average number of..." });
	sorts = ({ ({ "Date" , "Hits", "Page Loads", }) });
	tmp2 = 1;
      }

      tmp = replace(action, "hits", "pages");
      counts = allocate(3);
      foreach(names, array n) {
	sorts += ({ ({ n[0], (string)stats[action][ n[1] ],
		       (string)stats[tmp][ n[1] ] }) });
	if(stats[action][ n[1] ] > 0) // only count if there is any data.
	  counts[0]++;
	counts[1] += stats[action][ n[1] ];
	counts[2] += stats[tmp][ n[1] ];
      }
      if(counts[0] > 1 && v->type != "table" && v->type != "export")
	sorts = voidsorts(sorts, ({ 1, 2 }));
      if(counts[0])
	total = sprintf("Average per session is %.1f requests, %.1f pages for %s.",
			counts[1] / (float)counts[0],
			counts[2] / (float)counts[0], _date);
    }
  tmp = "";
  if(total)
    total = " name='"+total+"' ";
  else
    total = "";
  werror("Gauge Times: %O\n", gmap);
  if(sorts && sizeof(sorts) > 1) {
    switch(v->type)
    {
    case "line_chart":
    case "bar_chart":
    case "sumbars":
    case "normsumbars":
      if(!arrows)
	arrows = ({ sorts[0][0], sorts[0][1..]*" and " });
      res += sprintf("<diagram %s fontsize=12 %s legendfontsize=14 namesize=16 bgcolor=#ffffff vertgrid horgrid width=550 "
		     "height=300 notrans  textcolor=black "
		     "gridcolor=#319cce linewidth=2 type=%s>"
		     "<colors>#a00000\t#000090\t#f04040\t00a0ea</colors>"
		     "<xaxis quantity='%s'><yaxis quantity='%s'>"
		     "\n<legend>%s</legend>"
		     "\n<xnames>%s</xnames>"
		     "\n<data form=row>\n%s\n%s\n%s\n%s\n</data></diagram>",
		     total, extradiag ||"",
		     v->type - "_",
		     arrows[0], arrows[1],
		     sorts[0][1..] *"\t",
		     column(sorts[1..], 0) *"\t",
		     column(sorts[1..], 1) *"\t",
		     sizeof(sorts[0]) > 2 ?
		     column(sorts[1..], 2) *"\t" : "",
		     sizeof(sorts[0]) > 3 ?
		     column(sorts[1..], 3) *"\t" : "",
		     sizeof(sorts[0]) > 4 ?
		     column(sorts[1..], 4) *"\t" : "");

      break;

#if 0
    case "3D_pie_chart":
      tmp = "3D=25";
      v->type = "piechart";
    case "pie_chart":
      res += sprintf("<diagram %s notrans bgcolor=#ffffff vertgrid horgrid width=450 "
		     "height=350 textcolor=black  "
		     "gridcolor=#319cce linewidth=0 labelcolor=black type=%s %s>"

		     //		     "<xaxis quantity='%s'><yaxis quantity='%s'>"
		     "<legend>%s</legend>"
		     "<data form=row>%s</data></diagram>", total,
		     v->type - "_", tmp,
		     //		     sorts[0][0], sorts[0][1],
		     column(sorts[1..], 0) *"\t",
		     column(sorts[1..], 1) *"\t");
      
      break;
#endif      
    case "table":
      //      werror("%O\n", sorts);
      res += (entr||"")+"<p>"+html_table(sorts[0], sorts[1..]) + (entr||"");
      break;

     case "export":
      sorts = Array.map(sorts, lambda(array a) {
				 return ((array(string))a)*"\t";
			       });
      return http_string_answer(sorts * "\n", "text/plain");

    }
  } else
    res += "<h2>No statistics collected so far.</h2>";

  
  return res;
}

object profile_master;
mapping profiles;

array profstat;

void start(int n, object conf)
{
  module_dependencies(conf, ({ "obox", "business" }));
  profiles = ([]);
  profstat = file_stat(QUERY(profile));
  profile_master = Profile.Master(QUERY(profile));
  foreach(profile_master->profiles, object p)
    profiles[p->name] = p;
}



/* START AUTOGENERATED DEFVAR DOCS
**!
**! defvar: Mount Point
**! This is where the module will be inserted in the 
**!  type: TYPE_LOCATION
**!
**! defvar: Database Directory
**! The location of the output from the external summarizer.
**!  type: TYPE_DIR
**!
**! defvar: Profile File Name
**! The name of the profile configuration file to be used.
**!  type: TYPE_FILE
**!
**! defvar: Max Table Size
**! The maximum size for tables in the yearly, weekly and monthly views. Max table size for daily views is configured in the summarizer configuration file.
**!  type: TYPE_INT
**!
**! defvar: Show all Stats for Year View
**! If enabled, all statistics will be available in the yearly display. The default is to disable top pages, referrers and other stats that may require lots of memory and CPU to generate on larger sites. Use with caution. 
**!  type: TYPE_TOGGLE
**!
**! defvar: Excluded Profiles
**! A list of profiles to hide from the display.
**!  type: TYPE_STRING_LIST
**!
**! defvar: Hidden Stats
**! A list with statistic groups to hide unless the prestate showall is present. Hiding can be used to remove unnecessary statistic groups that display info you don't log or aren't interested in.
**!  type: TYPE_STRING_LIST
**!
*/
