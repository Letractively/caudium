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
//
//! module: Dump ID module
//!  This module show the content of Caudium Id object
//!  a the end of the page (after a &lt;/body&gt; tag)
//!  when user add a "magic" prestate called "dumpid".
//!  <br />This module is really usefull for
//!  developers when they needs to find how internals are
//!  handled.
//! inherits: module
//! type: MODULE_PARSER
//! cvs_version: $Id$
#include <module.h> 
inherit "module"; 
//inherit "caudiumlib"; 
constant cvs_version	= "$Id$";
constant module_type	= MODULE_PARSER;
constant module_name	= "Dump ID module";
constant module_doc	= "This module show the content of Caudium Id object "
			  "a the end of the page (after a &lt;/body&gt; tag) "
			  "when user add a \"magic\" prestate called \"dumpid\"."
			  "<br />This module is really usefull for developers "
			  "when they needs to find how internals are handled.";
constant module_unique	= 1;
constant thread_safe	= 1;

string|int s_body(string tag_name, mapping args, object id, object file)
{ 
  if (args->_parsed)
    return 0;
 
  if (id->prestate->dumpid)
  {
    return(sprintf("<p><hr /><pre>ID:%O\n</pre></p></body _parsed>",
                   mkmapping(indices(id),values(id))));
  }
  else
    return 0;
} 

mapping query_tag_callers() 
{ 
  return (["/body":s_body, ]); 
} 

