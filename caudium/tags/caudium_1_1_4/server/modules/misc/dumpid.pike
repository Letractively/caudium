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
//! module: Dump ID and Conf module
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
inherit "caudiumlib"; 
constant cvs_version	= "$Id$";
constant module_type	= MODULE_PARSER;
constant module_name	= "Dump ID and Conf module";
constant module_doc	= "This module shows the contents of the Caudium Id object "
                          "and/or of the current config object displaying them "
			  "a the end of the page (after the &lt;/body&gt; tag) if "
			  "the user adds \"magic\" prestates called <code>dumpid</code> and "
			  "<code>dumpconf</code>, respectively.<br/>"
			  "This module is really useful for developers "
			  "when they need to find how internals are handled and what "
			  "information is stored in the internal Caudium structures. ";
constant module_unique	= 1;
constant thread_safe	= 1;

string|int s_body(string tag_name, mapping args, object id, object file)
{ 
  string   retid = 0;
  string   retconf = 0;
  
  if (args->_parsed)
    return 0;
 
  if (id->prestate->dumpid)
  {
    string tmp = sprintf("%O", mkmapping(indices(id),values(id)));
    retid = sprintf("<strong>Request ID:</strong><br><pre>%s\n</pre></p>",
                    html_encode_string(tmp));
  }
  
  if (id->prestate->dumpconf && id->conf)
  {
    string tmp = sprintf("%O", mkmapping(indices(id->conf),values(id->conf)));
    retconf = sprintf("<strong>Request ID Config:</strong><br><pre>%s\n</pre></p>",
                     html_encode_string(tmp));
  }
  
  if (!retid && !retconf)
     return 0;
     
  string ret = "";
  string retnav = "";
  
  if (retid)
     retnav = sprintf("<a href='#reqid'>Request ID data</a>");
  if (retconf)
     retnav += sprintf(" | <a href='#reqconf'>Request Config data</a>");
     
  if (retid)
     ret = sprintf("<a name='reqid'>&nbsp;</a><p><hr /><center>%s</center><br />%s", retnav, retid);
  
  if (retconf)
     ret += sprintf("<a name='reqconf'>&nbsp;</a><p><hr /><center>%s</center><br />%s", retnav, retconf);;
     
  ret += "</body _parsed>";
  
  return ret;
} 

mapping query_tag_callers() 
{ 
  return (["/body":s_body, ]); 
} 

