/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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
 * XSLTtag.pike - XSLT Tag for Caudium. Utilizes the Sablotron XSLT Library
 *                available from http://www.gingerall.com/
 * Written by David Hedbor <david@hedbor.org>
 */

string cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";


array register_module()
{
  return
  ({
    MODULE_PARSER,
    "XSLT Tag",
    "Implements a tag that applies the specified (or the default) stylesheet "
    "to its contents. Syntax: <p><blockquote><b>"
    "&lt;xslt [stylesheet='file:fullpath|virt:virtual|var:varname'] "
    "[baseuri='file:base|virt:base']&gt;DATA&lt;/xslt&gt;"
    "</b></blockquote><p>"
    "In the syntax, the file:, virt: and var: is used to specify the source. "
    "<b>file:</b> is a file in the real file system, <b>virt:</b> is a file "
    "in Caudium's virtual filesystem and <b>var:</b> is a variable in the "
    "id->variables mapping. If the parsing fails, <false> is returned. "
    "At this point the error messages only gets printed to the Caudium "
    "debug log. Also note that at this point only file URIs are "
    "accepted for both the XSL path and the base URI."
#if !constant(PiXSL.parse)
    "<p><b><blink>ERROR</blink>: "
    "<font color=red>The PiXSL.so pike-module is missing. This "
    "module will not function correctly!</font></b>\n"
#endif

    , 0, 1
  });
}

void create()
{
  defvar("baseuri", "", "Default Base URI", TYPE_DIR,
	 "Default base URI to use when resolving includes in the XSL "
	 "stylesheets. Can be overridden by the baseuri attribute to "
	 "the xslt tag.\n");
  defvar("stylesheet", "", "Default XSLT Stylesheet", TYPE_FILE,
	 "The default style sheet to use when the stylesheet attribute is "
	 "omitted. Uses the same file:, virt: and var: syntax as the age.\n");
}

#if constant(PiXSL.parse)
#define ERROR(x) return "<p><b>XSLT Error: " x "</b><p><false>";

string container_xslt(string tag, mapping args, string xml, object id)
{
  string xsl, type, key, res;
  if(!args->stylesheet) args->baseuri = QUERY(stylesheet);
  if(!args->baseuri) args->baseuri = QUERY(baseuri);
  if(!strlen(args->baseuri)) m_delete(args, "baseuri");
  
  if(args->baseuri) {
    sscanf(args->baseuri, "%s:%s", type, key);
    if(!key || !type)
      ERROR("Incorrect baseuri specification");
    switch(type) {
     case "virt":  key = id->realfile(key, id);
     case "file":
      args->baseuri = key;
      break;
     default:
      ERROR("Invalid baseuri method. Valid methods are file: and virt:");
    }
  }
  
  sscanf(args->stylesheet, "%s:%s", type, key);
  if(!key || !type)
    ERROR("Incorrect or missing stylesheet");
  switch(type) {
   case "virt":
    key = id->realfile(key, id);
   case "file":
    xsl = Stdio.read_file(key);
    if(!args->baseuri) 
      args->baseuri = dirname(key);
    break;
   case "var":
    xsl = id->variables[key];
    break;
    
   default:
    ERROR("Invalid stylesheet method. Valid methods are file:, virt: and var:");
  }
  if(!xsl)
    ERROR("Couldn't read XSLT stylesheet");
  sscanf(xml, "%*[\n\t\r ]%s", xml);
  if(args->baseuri) 
    res = PiXSL.parse(xsl, xml, args->baseuri);
  else 
    res = PiXSL.parse(xsl, xml);
  if(!res) return  "<false>";
  return res+"<true>";
}

mapping query_container_callers()
{
  return ([ "xslt": container_xslt,
  ]);
} 


mapping query_tag_callers()
{
  return ([
  ]);
  
} 
#endif
