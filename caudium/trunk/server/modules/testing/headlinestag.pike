/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

//! module: Headlines module
//!  Headline module for Caudium
//! type: MODULE_PARSER
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

#include <module.h>
#include <process.h>
inherit "module";
inherit "caudiumlib";

constant module_type  = MODULE_PARSER;
constant module_name  = "Headline module";
constant module_doc   = "Headline module for Caudium";
constant cvs_version  = "$Id$";
constant thread_safe  = 1;

mapping sites = ([]);
array sitecache = ({ });
int fetching=0;

void update_me(object me)
{
 array tempcache = ({ });
 werror("Headline : Updated %s.\n", me->site);
 sites[me->site] = me;
 fetching--;
 foreach(sitecache, array foo)
 {
   if(foo[0] != me->site) tempcache += ({ foo });
 }
 sitecache = tempcache;
 sitecache += ({ ({ me->site, time(), (array)me }) }); 
}

//! container: headlineoutput
//!  Dump the headlines a la "formoutput"
//! arg: quote
//!  Changes the quote from default '#' to another type
//! arg: site
//!  Dumps the headline from site definied
//! arg: parse
//!  RXML parse the site option before executing the module
string headlineoutput(string tag_name, mapping args, string contents,
                      object id, object f, mapping defines, object fd)
{
 if(args->help) return "There is no help yet !";	// FIXME

// if(args->site) return "No sites yet!";		// FIXME

 id->misc->cacheable = 0;	// The content is not cachable =)

 if(args->site)
 {
  if(args->parse)
    args->site = parse_rxml(args->site, id, f, defines);
  
  if(sizeof(sitecache))
   foreach(sitecache, array foo)
   {
     if(foo[0] == lower_case(args->site))
      return "Is in cache";
     else
     {
       object me = Headlines.Sites[ sites [lower_case(args->site) ] ]();
       me->refetch(update_me);
       return "Refreshing...";
     }
   }
   else
   {
     object me = Headlines.Sites[ sites [lower_case(args->site) ] ]();
     me->refetch(update_me);
     return "Refreshing...2";
   }
 }
}

//void start()
//{
//}

string status()
{
 mapping sites;
 add_constant("log_event",lambda(mixed ... args) { } );
 add_constant("hversion", "1.0");
 add_constant("trim",Headlines.Tools()->trim);
 sites = mkmapping(Array.map(indices(Headlines.Sites), lower_case),
                             indices(Headlines.Sites));
 object me = Headlines.Sites[ sites[ lower_case("GCU") ] ]();
 return "<b>Sites currently supported :</b><br />"
        ""+String.implode_nicely(sort(values(sites)));
}

mapping query_container_callers()
{ 
 return (["headlineoutput":headlineoutput ]);
}

