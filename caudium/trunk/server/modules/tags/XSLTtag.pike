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

constant module_type = MODULE_PARSER;
constant module_name = "XSLT Tag";
constant module_doc = 
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
#if !constant(PiXSL.Parser)
"<p><b><blink>ERROR</blink>: "
"<font color=red>The PiXSL.so pike-module is missing. This "
"module will not function correctly!</font></b>\n"
#endif
;
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

#if constant(PiXSL.Parser)
#define ERROR(x) return "<p><b>XSLT Error: " x "</b><p><false>";

string container_xslt(string tag, mapping args, string xml, object id)
{
  string xsl, type, key;
  string|mapping res;
  object(PiXSL.Parser) parser;
  string content_type, charset;
  if(!args->stylesheet) args->stylesheet = QUERY(stylesheet);
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
    key = id->conf->realfile(key, id);
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

  parser = PiXSL.Parser();
  if(args->baseuri) 
    parser->set_base_uri(args->baseuri);
  parser->set_xsl_data(xsl);
  parser->set_xml_data(xml);
  parser->set_variables(id->variables);
  if(catch(res = parser->run())) {
    res = parser->error();
    if(!res)
      return  "<b>ERROR:</b> XSLT Parsing failed with unknown error.<false>";
    else if(mappingp(res)) {
      int line = (int)res->line, sline, eline;
      string line_emph="";
      array lines;
      if(!res->URI) res->URI = "unknown file";
      if(search(res->URI, "xsl") != -1) {
	res->URI = "XSLT input <i>"+args->stylesheet+"</i>";
	if(line) lines = xsl / "\n";
      } else if(search(res->URI, "xml") != -1) {
	res->URI = "XML source data";
	if(line) lines = xml / "\n";
      }
      if(lines) {
	line--;
	sline = max(line - 3, 0);
	eline = min(sizeof(lines), sline + 7);
	line_emph="<h3>Extract of incorrect line</h3>";
	for(int i = sline; i < eline; i++) {
	  if(i == line) {
	    line_emph += "<b>"+(i+1)+": <font size=+3>"+
	      html_encode_string(lines[i])+"</font></b><br>";
	  } else {
	    line_emph += "<b>"+(i+1)+"</b>: "+
	      html_encode_string(lines[i])+"<br>";
	  }
	}
      }
      return 
	sprintf("<b>%s:</b> XSLT Parsing failed with %serror code %s on<br>\n"
		"line %s in %s:<br>\n%s<p>%s<br>\n<false>",
		res->level||upper_case(res->msgtype||"ERROR"), 
		res->module ? res->module + " " : "",
		res->code || "???",
		res->line || "???",
		res->URI || "unknown file",
		res->msg || "Unknown error", line_emph);
    }
  }
  charset = parser->charset();
  content_type = parser->content_type() || "text/html";
  if(charset)
    content_type += "; charset="+charset;
  id->misc->_content_type = content_type;
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

/* START AUTOGENERATED DEFVAR DOCS
**!
**! defvar: Default Base URI
**! Default base URI to use when resolving includes in the XSL stylesheets. Can be overridden by the baseuri attribute to the xslt tag.
**!
**!  type: TYPE_DIR
**!
**! defvar: Default XSLT Stylesheet
**! The default style sheet to use when the stylesheet attribute is omitted. Uses the same file:, virt: and var: syntax as the age.
**!
**!  type: TYPE_FILE
**!
*/
