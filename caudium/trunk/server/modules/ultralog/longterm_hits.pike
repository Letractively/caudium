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

/* Longterm hits. An example "ultralog plugin module". Very possibly defunct
 */
   
constant cvs_version = "$Id$";

#include <module.h>
inherit "module";
inherit "caudiumlib";
import UltraLog;
constant months = ({ 
  ({ 1, "January" }),
  ({ 2, "Febrary" }),
  ({ 3, "March" }),
  ({ 4, "April" }),
  ({ 5, "May" }),
  ({ 6, "June" }),
  ({ 7, "July" }),
  ({ 8, "August" }),
  ({ 9, "September" }),
  ({ 10, "October" }),
  ({ 11, "November" }),
  ({ 12 , "December" }) });

void create()
{
}

string month_list(int m)
{
  string out = "";
  foreach(months, array mon)
    if(mon[0] == m)
      out += sprintf("<option selected value=%d>%s", @mon);
    else
      out += sprintf("<option value=%d>%s", @mon);
  return out;
}
string mklist(array what, string sel)
{
  string out = "";
  foreach(what, string opt)
    if(opt == sel)
      out += sprintf("<option selected>%s", opt);
    else
      out += sprintf("<option>%s", opt);
  return out;
}

constant description = "Get monthly hits / page load statistics during a longer time period than a year.";
constant name = "UltraStats Longterm Hits / Page loads ";

string query_provides() { return "ultrareporter"; }
string query_report_name() { return "ul_long"; }

constant module_type = MODULE_PROVIDER;
constant module_name = "UltraLog: Long Term Monthly Hit Statistics ";
constant module_doc =
"A plugin module for Ultraparse to display monthly hit / page load "
"statistics for a custom time period.";

#define OK(x) (id->variables->x && strlen(id->variables->x))
mixed view_report(string f, object id, object ultralog)
{
  int fmonth, tmonth, fyear, tyear;
  array path = f / "/" - ({""});
  string base =
    ultralog->query("mountpoint")+"reports/"+ query_report_name() +"/";
  string res = "";
  id->variables->title = "Long Term Hit Statistics";
  mapping lt = localtime(time());
  fmonth = (int)id->variables->fmonth || lt->mon+1;
  tmonth = (int)id->variables->tmonth || lt->mon+1;
  fyear = (int)id->variables->fyear || lt->year+1900;
  tyear = (int)id->variables->tyear || lt->year+1900;
  res = "<form method=get><pre>"
      "From:    <select name=fmonth>"+month_list(fmonth)+"</select> in the year of <input name=fyear size=4 maxsize=4 value="+fyear+"><br>"
      "To:      <select name=tmonth>"+month_list(tmonth)+"</select> in the year of <input name=tyear size=4 maxsize=4 value="+tyear+"><br>"
      "Profile: <select name=profile>" +
    (mklist(ultralog->get_profile_list(1), id->variables->profile))+
      "</select><br><input type=submit value=\"Show Table\">"
    "<input type=submit name=dump value=\"Line Chart\">"
    "<input type=submit name=dump value=\"Bar Chart\"></pre></form>";
  if((fyear*10000+fmonth*100) > (tyear*10000+tmonth*100) ||
     fyear < 1990 || tyear < 1990 || fmonth < 1 || fmonth > 12 || tmonth < 1 ||
     tmonth > 12)
    return res + "<h3>The dates you entered are not valid.</h3>";
  
  if(!OK(profile))
    return res;
  object fdateobj = Calendar.ISO.Month(fyear,fmonth);
  object tdateobj = Calendar.ISO.Month(tyear,tmonth);
  //  write("From: %s, To: %s\n", fdate->iso_name(), tdate->iso_name());
  object cstat;
  string mres ="";
  if(id->variables->dump)
    mres = "Year/Month\tHits\tPage Loads\n";
  else {
    mres += "<tablify nice>Year-Month\tHits\tPage Loads\n";
  }
  tdateobj = tdateobj->next();
  mapping total=([]);
  do  {
    mapping cached = ([]), clicks = ([]);
    cstat = ultralog->get_statistics(id->variables->profile, "month",
				     "hits_per_day", ({ fdateobj->y,
							fdateobj->m,
				     }));
    mres +=  sprintf("%4d-%02d\t%d\t%d\n", fdateobj->y,
		       fdateobj->m,
		    `+(@cstat->hits_per_day),
		    `+(@cstat->pages_per_day));

    fdateobj = fdateobj->next();
  } while(fdateobj != tdateobj);
  //  res += "Total";
  //  foreach(all, string what)
  //    res += "\t"+total[what];
  //  res += "\n";
  if(id->variables->dump) {
    id->variables->dump = lower_case(id->variables->dump - " ");
    array sorts = Array.map(mres / "\n" - ({""}), `/, "\t");
    return res+sprintf("<diagram fontsize=12 eng width=600 height=350 legendfontsize=14 namesize=16 "
		       "bgcolor=#ffffff vertgrid horgrid notrans  textcolor=black xnamesvert "
		       "gridcolor=#319cce linewidth=2 type="+id->variables->dump+">"
		       "<colors>#a00000\t#000090\t#f04040\t00a0ea</colors>"
		       "<xaxis quantity='Year-Month'>"
		       "<yaxis quantity='Hits / Page Loads'>"
		       "\n<legend>%s</legend>"
		       "\n<xnames>%s</xnames>"
		       "\n<data xnamesvert form=row>%s\n%s</data></diagram>",
		       sorts[0][1..]*"\t",
		       column(sorts[1..], 0)*"\t",
		       column(sorts[1..], 1)*"\t",
		       column(sorts[1..], 2)*"\t");
    return http_string_answer(res);
  }
  return res+mres+"</tablify>";
}


void|string load_period_data(object cstat, array date, string period,
			     mapping saveinme,   string profile, 
			     object ultralog)
{
  object stat;
  object cat;
  int ok;
  mapping out = ([]);
  stat = ultralog->get_statistics(profile, period,"redirs", date);
  if(stat) {
    foreach(indices(stat->redirs), string url)
    {
      int uid, destuid;
      string ix, rdata, dest;
      if(sscanf(url, "/RG%[XI]/%s/%s", ix, rdata, dest) == 3) {
	if(ix != "I")
	  continue;
	switch(rdata[..2]) {
	 case "CAT":
	 case "LVE":
	 case "STA":
	 case "RCH":
	  array rparts = rdata / ".";
	  if(sizeof(rparts) < 5) continue;
	  if(sscanf(rparts[1], "%d-%*s", uid) &&
	     sscanf(rparts[4], "catID=%d", destuid))
	  {
	    out[sprintf("%d\t%d", uid, destuid)] += stat->redirs[url];
	  }
	}
      }
    }
    destruct(stat);
  }
  saveinme->report_redircats = out;
}

