/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2001 The Caudium Group
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
constant module_doc   = "Headline module for Caudium"
                        "<p>This module defines a new container <tt>"
			"&lt;hloutput&gt;</tt> that works like "
			"<tt>&lt;formoutput&gt;</tt> "
			"</p><p>Syntax for freshmeat is :<br><tt>"
			"&lt;hloutput site=freshmeat&gt;<br>"
			" New title : #title#<br>"
			" New url : #url#<br>"
			"&lt;/hloutput&gt;</tt></p>"
			"<p>Please see in <tt>Headlines.pmod/Sites.pmod/"
			"'sitename'.pike</tt> in constant names for"
			"remplacement names specific sites.</p>";
constant cvs_version  = "$Id$";
constant thread_safe  = 1;

mapping sites = ([]);
array sitecache = ({ });
int fetching=0;

void update_me(object me)
{
 array tempcache = ({ });
 sites[me->site] = me;
 fetching--;
 foreach(sitecache, array foo)
 {
   if(foo[0] != me->name) tempcache += ({ foo });
 }
 sitecache = tempcache;
 sitecache += ({ ({ me->name, time(), (array)me }) }); 
}

void create()
{
 defvar("updatemsg","Updating Headlines...", "Update message",TYPE_STRING,
        "Message to display when headlines are in updating process");
 defvar("timeout",600,"Timeout", TYPE_INT,
        "Timeout in seconds between each updates of the headlines. Note that "
	"a '0' values updates headlines at <b>EVERY</b> call of the tag. ");

}

//! container: hloutput
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
 string output = "<FALSE>";

 if(args->help) return "There is no help yet !";	// FIXME

// if(args->site) return "No sites yet!";		// FIXME

 id->misc->cacheable = 0;	// The content is not cachable =)

 if(args->site)
 {
  add_constant("log_event",lambda(mixed ... args) { } );
  add_constant("hversion", "1.0");
  add_constant("trim",Headlines.Tools()->trim);
  sites = mkmapping(Array.map(indices(Headlines.Sites), lower_case),
                              indices(Headlines.Sites));
  if(args->parse)
    args->site = parse_rxml(args->site, id, f, defines);

  
  if(sizeof(sitecache))
   foreach(sitecache, array foo)
   {
     if(foo[0] == lower_case(args->site))
     {
      // Do output before start a new update
      output = do_output_tag(args, foo[2], contents, id) + "<TRUE>";
      // Is it the time to update headlines ?
      if ( (foo[1] + QUERY(timeout)) < time() )
      {
        // Yes this is the time =)
	object me = Headlines.Sites[ sites [lower_case(args->site) ] ]();
	me->refetch(update_me);
      }
     }
     else
     {
       object me = Headlines.Sites[ sites [lower_case(args->site) ] ]();
       me->refetch(update_me);
     }
   }
   else
   {
     object me = Headlines.Sites[ sites [lower_case(args->site) ] ]();
     me->refetch(update_me);
   }
 }
 if (output == "<FALSE>") output = QUERY(updatemsg)+"<FALSE>";
 return (output);
}

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
        ""+String.implode_nicely(sort(values(sites)))+"<br>"
	"<b>Nb of cached entries :</b> " + (string) sizeof(sitecache);
}

mapping query_container_callers()
{ 
 return (["hloutput":headlineoutput ]);
}

