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
/*
 * $Id$
 */

inherit "wizard";
constant name= "Status//Access / request status";

constant doc = ("Shows the amount of data handled since last restart.");

constant more=0;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

mixed page_0(object id, object mc)
{
  return sprintf("<h2>Server Overview</h2>"
		 "This is the summary status of all virtual servers. "
		 "Click <b>[Next->]</b> to see the statistics for each "
		 "individual server, or <b>[Cancel]</b> to return to the "
		 "previous menu.<p>%s", 
		 caudium->full_status());
}

mixed page_1(object id)
{
  string res="";
  foreach(Array.sort_array(caudium->configurations,
			   lambda(object a, object b) {
			     return a->requests < b->requests;
			   }), object o) {
    if(!o->requests)
      continue;
    res += sprintf("<h3><a href=%s>%s</a><br>%s</h3>\n",
		   o->query("MyWorldLocation"),
		   o->name,
		   replace(o->status(), "<table>", "<table cellpadding=4>"));
  }
  if(!strlen(res))
    return "<b>There are no active virtual servers.</b>";
  return
    "<b>These are all active virtual servers. They are sorted by the "
    "number of requests they have received - the most active being first. "
    "Servers which haven't received any requests are not listed.</b>" +
    res;
}

int verify_1(object id)
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }

