/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
constant name= "Cache//Cache Status";

constant doc = ("Show information about the Caudium's caching engine.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

mixed page_0(object id, object mc) {
  string ret = 
    "<table border=0><tr>\n"
    "<td bgcolor=\"#eeeeff\" colspan=4><h3>Overall</h3></td>"
    "<td bgcolor=\"#eeeeff\" colspan=3><h3>Fast Cache</h3></td>"
    "<td bgcolor=\"#eeeeff\" colspan=3><h3>Slow Cache</h3></td>"
    "</tr>\n<tr>\n"
    "<td bgcolor=\"#eeeeff\"><b>Name</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Objects</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Hits</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Misses</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Objects</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Hits</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Misses</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Objects</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Hits</b></td>"
    "<td bgcolor=\"#eeeeff\"><b>Misses</b></td>"
    "</tr>\n";
  foreach(sort(indices((mapping)caudium->cache_manager->status())), string namespace) {
    mapping status = ((mapping)caudium->cache_manager->status())[namespace];
    ret += sprintf(
      "<tr>\n"
      "<td bgcolor=\"#eeeeff\">%s</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "<td bgcolor=\"#eeeeff\">%d</td>"
      "</tr>\n",
      roxen_encode(namespace, "html"),
      status->total_object_count,
      status->total_hits,
      status->total_misses,
      status->fast_object_count,
      status->fast_hits,
      status->fast_misses,
      status->slow_object_count,
      status->slow_hits,
      status->slow_misses
    );
    string desc = caudium->cache_manager->get_cache(namespace)->cache_description();
    if (desc)
      ret += sprintf(
        "<help><tr>\n"
        "<td bgcolor=\"#eeeeff\" colspan=10><i>%s</i></td>"
        "</tr></help>\n",
        roxen_encode(desc, "html")
      );
  }
  ret += "</table>\n";
  return html_border(ret);
}

int verify_0() {
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }
