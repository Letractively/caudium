/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
#include <module.h>

inherit "wizard";
constant name= "Cache//Flush Caching Sub-System";

constant doc = ("Selectively flush caches in the caching engine.");

mixed page_0 ( object id, object mc ) {
  string select =
    "<table border=0>\n"
    "<tr><td colspan=2><h3>Cache</h3></td></tr>\n";
  foreach( indices( caudium->cache_manager->caches ), string namespace ) {
    string desc = caudium->cache_manager->get_cache( namespace )->cache_description();
    select +=
      sprintf( "<tr><td><input type=\"checkbox\" name=\"flush\" value=\"%s\"></td><td><b>%s</b></td></tr>\n", namespace, namespace );
    if ( desc )
      select += sprintf( "<tr><td></td><td>%s</td></tr>\n", desc );
    select += "<tr><td colspan=2><hr noshade /></td></tr>\n";
  }
  select += "</table>\n";
  return
    "<h2>Currently Running Caches</h2>\n"
    "<table border=1><tr><td>\n" +
    select +
    "</td></tr></table>\n"
    "<br />"
    "Please use the checkboxes above to select the cache, or caches "
    "which you wish to flush. Flushing a cache removes all data "
    "and metadata held in the cache, and may represent a short to "
    "medium term performance hit.<br />"
    "Please also note that any caches that are currently in a dormant "
    "state (ie; removed from RAM and stored out to disk) will not be "
    "present in this list. If the cache you are looking for is not "
    "listed above then try accessing the cache you want flushed - "
    "possibly by loading a page, etc."
    "<br />";
}

mixed wizard_done ( object id, object mc ) {
  if ( ! id->variables->flush ) {
    return "<b>You didn't select any caches, what did you expect?</b>";
  }
  array checked = id->variables->flush / "\0";
  foreach( checked, string namespace ) {
    caudium->cache_manager->get_cache( namespace )->flush();
  }
  return "<b>Caches Flushed:</b> " + ( checked * " " );
}

mixed handle( object id ) { return wizard_for( id, 0 ); }

