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

mixed page_1 ( object id, object mc ) {
  if ( ! id->variables->flush ) {
    return "<b>You didn't select any caches, what did you expect?</b>";
  }
  array checked = id->variables->flush / "\0";
  foreach( checked, string namespace ) {
    caudium->cache_manager->get_cache( namespace )->flush();
  }
  return "<b>Caches Flushed:</b> " + ( checked * " " );
}












/*

mixed page_0(object id, object mc)
{
  return ("<font size=+1>Which caches do you want to flush?</font><p>"
	  "<var name=module_cache type=checkbox> The module cache<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the module cache (used to describe "
	  "modules on the 'add module' page)"
	  "</blockquote></help>"
	  "<var name=user_cache type=checkbox> The user cache<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the user and password cache in all "
	  "virtual servers."
	  "</blockquote></help>"
	  "<var default=1 name=memory_cache type=checkbox> The memory cache<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the memory cache (the one described "
	  "under the Actions -> Cache -> Cache status)."
	  "</blockquote></help>"
	  "<var default=1 name=dir_cache type=checkbox> Directory caches<br>\n"
	  "<help><blockquote>"
	  "Force a flush of all directory module caches."
	  "</blockquote></help>"
	  "<var default=0 name=gtext_cache type=checkbox> Graphical text caches<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the graphical text cache."
	  "</blockquote></help>"
	  "<var default=0 name=ttf_cache type=checkbox> TTF caches<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the TTF font cache."
	  "</blockquote></help>");
}

#define CHECKED(x) (id->variables->x != "0")

mixed page_1(object id, object mc)
{
  string ret = "";
  if(CHECKED(user_cache))   ret += "The userdb cache<br>";
  if(CHECKED(memory_cache)) ret += "The memory cache<br>";    
  if(CHECKED(dir_cache))    ret += "The directory cache<br>";
  if(CHECKED(module_cache)) ret += "The module cache<br>";
  if(CHECKED(gtext_cache)) ret += "The graphical text cache<br>";
  if(CHECKED(ttf_cache)) ret += "The TTF font cache<br>";
  if(!strlen(ret))
    ret = "No items selected!";

  return  "To flush the following caches press 'OK':\n<p>"+ ret;
}

string text_andify( array(string) info )
{
  int i=0;
  int l=sizeof(info);
  string ret;

  foreach( info, string item )
  {
    i++;
    if(i==1) ret = item;
    else
      if(i==l) ret += " and "+ item;
      else ret += ", "+ item;
  }

  return ret;
}

mixed wizard_done(object id, object mc)
{
  array(string) info= ({ });
  
  if(CHECKED(user_cache))
  {
    info += ({ "the userdb" });
    foreach(caudium->configurations, object c)
      if(c->modules["userdb"] && c->modules["userdb"]->master)
	c->modules["userdb"]->master->read_data();
  }
  
  if(CHECKED(memory_cache))
  {
    info += ({ "the memory cache" });
    function_object(cache_set)->cache = ([]);
  }

  if(CHECKED(gtext_cache))
  {
    info += ({ "the graphical text cache" });
    foreach(caudium->configurations, object c)
    {
      if(c->modules["graphic_text"] && 
	 (c=c->modules["graphic_text"]->enabled))
      {
	catch{
	  foreach(get_dir(c->query("cache_dir")), string d)
	    rm(c->query("cache_dir")+d);
	};
      }
    }
  }

  if(CHECKED(dir_cache))
  {
    info += ({ "the directory cache" });
  foreach(caudium->configurations, object c)
    if(c->modules["directories"] && (c=c->modules["directories"]->enabled))
    {
      catch{
	c->_root->dest();
	c->_root = 0;
      };
    }
  }
  
  if(CHECKED(module_cache))
  {
    info += ({ "the module cache" });
    caudium->allmodules=0;
    caudium->module_stat_cache=([]);
  }

  if(CHECKED(ttf_cache))
  {
    info += ({ "the TTF cache" });
    
    rm(GLOBVAR(ConfigurationStateDir) + ".ttffontcache");
  }
  
  if(info)
    report_notice("Flushed "+ text_andify(info) +".");
}
*/


mixed handle(object id) { return wizard_for(id,0); }

