/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
constant name= "Cache//Flush Caches";

// Simulate the behavior of the old flush action.
array oldcaches = ({ "The Module Cache", "The TTF Cache", "The Directory Cache" });

constant doc = ("Selectively flush caches in Caudium's caching engine.");

mixed page_0 ( object id, object conf ) {
  string ret = "<cvar type=\"select_multiple\" name=\"flush\">";
  ret += (indices(caudium->cache_manager->caches) + oldcaches) * ",";
  ret += "</cvar>";
  ret += "<help>\n<br />";
  foreach(indices(caudium->cache_manager->caches), string namespace) {
    string desc = caudium->cache_manager->get_cache(namespace)->cache_description();
    if (!desc) continue;
    ret += sprintf(
      "<b>%s</b><blockquote>%s</blockquote>\n",
      roxen_encode(namespace, "html"),
      roxen_encode(desc, "html")
    );
  }
  ret += "</help>";
  return html_border(ret);
}

mixed wizard_done ( object id, object conf ) {
  if ( ! id->variables->flush ) {
    return "<b>You didn't select any caches, what did you expect?</b>";
  }
  array checked = id->variables->flush / "\0";
  foreach(oldcaches, string name) {
    if (((multiset)checked)[name]) {
      checked -= ({ name });
      switch(name) {
      case "The Module Cache":
        caudium->allmodules = 0;
	caudium->module_stat_cache = ([]);
	break;
      case "The TTF Cache":
        rm(GLOBVAR(ConfigurationStateDir) + ".ttffontcache");
        break;
      case "The Directory Cache":
        foreach(caudium->configurations, object c)
	  if (c->modules["directories"] && (c=c->modules["directories"]->enabled)) {
	    catch{
	      c->_root->dest();
	      c->_root = 0;
	    };
	  }
        break;
      }
    }
  }
  foreach( checked, string namespace ) {
    caudium->cache_manager->get_cache( namespace )->flush();
  }
  return "<b>Caches Flushed:</b><ul><li>" + ((id->variables->flush / "\0") * "</li><li>") + "</li></ul>";
}

mixed handle( object id ) { return wizard_for( id, 0 ); }

