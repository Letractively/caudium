/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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

/* $Id$ */

#include <config.h>

#ifndef ENABLE_NEIGHBOURHOOD
constant action_disabled = 1;
#else /* ENABLE_NEIGHBOURHOOD */
inherit "wizard";

string name = "Neighbourhood//Roxen Neighbourhood...";
string doc = "Action for showing the status of other Roxen servers";

string sv(mixed in)
{
  if(!in) return "?";
  in = (string) in;
  sscanf(in, "%*s/%s", in);
  in = replace(in, "alpha", "a");
  in = replace(in, "beta", "ß");
  return in;
}

string show_servers(string c,array s)
{
  array res =({});
  if(strlen(c)) c+="<br>";
  foreach(s, mixed v)
  {
    if(arrayp(v))
      res += ({"<a href="+v[1]+">"+v[0]+"</a>"});
    else
      res += ({"<a href="+v+">"+v+"</a>"});
  }
  return c+String.implode_nicely(res)+"<p>";
}

string time_interval(int s)
{
  string r = "";

  int d = s/3600/24;
  int y = d/365;
  int h = (s/3600)%24;
  d %= 365;

  if(y) r += sprintf("%dy ", y);
  if(d||y) r += sprintf("%dd ", d);
  if(d||h) r += sprintf("%dh ", h);
  return r + ((s>7200)?"":sprintf("%2d min", (s%3600)/60));
}

string page_0()
{
  array sn = indices(neighborhood);
  sort(Array.map(sn, lambda(string s)
		 { return neighborhood[s]->host+":"+
		          getpwuid(neighborhood[s]->uid)[0]+":"+
		          neighborhood[s]->config_url; }), sn);
  return "A red line indicates that the server is constantly restarting. "
	  "An orange line indicates that the server is not sending any "
	  "information about its presence anymore.<p>" +
          html_table(({"Config URL", "User", "Host", "Uptime",
		      "Last Reboot", "PID", "PPID", "Version" }),
		    Array.map(sn, lambda(string s) {
     mapping ns = neighborhood[s];
     int vanished = ns->rec_time && ((time() - ns->rec_time) > 600);
     int re=ns->seq_reboots;
     string ER="",RE="";
     if(vanished) {
       RE="<font color=orange><b>";
       ER="</b></font>";
     } else if(re>1) {
       RE="<font color=red><b>";
       ER="</b></font>";
     } 
     return({  "<a href='"+s+"'>"+s+"</a></font>",
	       RE+getpwuid(ns->uid)[0]+ER,
	       RE+ns->host+ER,
	       RE+(vanished?"(down since "+
		   time_interval(time()-ns->rec_time)+"???)":
		   time_interval(time()-ns->last_reboot))+ER,
	       RE+roxen->language("en","date")(ns->last_reboot)+ER,
	       RE+sv(ns->pid)+ER,
	       RE+sv(ns->ppid)+ER,
	       RE+sv(ns->version)+ER}) +
       (ns->comment && strlen(ns->comment)?
		 ({({"<img src=/image/unit.gif height=1 width=20>"
		     "<font size=-1>"+ns->comment
		       +"</font>"})}):({}));
    }));
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
#endif /* ENABLE_NEIGHBOURHOOD */
