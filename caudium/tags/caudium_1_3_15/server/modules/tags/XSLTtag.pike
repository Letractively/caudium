/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

//
//! module: XSLT Tag
//!  Implements a tag that applies the specified (or the default) stylesheet
//!  to its contents.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//

/*
 * XSLTtag.pike - XSLT Tag for Caudium. Utilizes the Sablotron XSLT Library
 *                available from http://www.gingerall.com/
 * Originally written by David Hedbor <david@hedbor.org>
 * Fixes for virtual filesystem storage, and Caudium 1.3 caching by
 *   James Tyson.
 */

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";
inherit "cachelib";

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
"<font color=red>The PiXSL.so pike-module is missing.</font>"
#endif
#if !constant(libxslt.Parser)
"<p><b><blink>ERROR</blink>: "
"<font color=red>The libxslt.so pike-module is missing.</font>"
#endif
#if !constant(PiXSL.Parser) && !constant(libxslt.Parser)
"This module will not function correctly!</font></b>\n"
#endif
;
object cache;

void create()
{
  defvar("baseuri", "", "Default Base URI", TYPE_DIR,
	 "Default base URI to use when resolving includes in the XSL "
	 "stylesheets. Can be overridden by the baseuri attribute to "
	 "the xslt tag.\n");
  defvar("stylesheet", "", "Default XSLT Stylesheet", TYPE_FILE,
	 "The default style sheet to use when the stylesheet attribute is "
	 "omitted. Uses the same file:, virt: and var: syntax as the age.\n");
  defvar("use_xslt", 0, "Use libxslt Library ?", 
	 TYPE_FLAG,"If set the libxslt library will be used !");
}

void start() {
  cache = caudium->cache_manager->get_cache( this_object() );
}

#define ERROR(x) return "<p><b>XSLT Error: " x "</b><p><false>";

class MyFile {
  string fname;
  void create(string name) { fname = name; }
};

object myID;

int match_include(string fname)
{
  string inc_name;

  if ( sscanf(fname, "file://%s", inc_name) > 0 ) {
    string content;
    
    mixed err = catch {
      content = myID->conf->try_get_file(inc_name, myID);
    };
    if ( err != 0 )
      werror("Error on match_include...\n"+sprintf("%O\n",err));
    
    return content != 0;
  }
  return 0;
}

object open_include(string fname)
{
  sscanf(fname, "file://%s", fname);
  return MyFile(fname);
}

string|int read_include(object obj)
{
  if (!objectp(obj)) 
    return 0;

  string content = myID->conf->try_get_file(obj->fname, myID);
  return content;
}

void close_include(object id, object obj)
{
}

void cache_retrieve_template( string curl, object id ) {
  string type, uri,xsl;
  if ( sscanf( curl, "%s:/%s", type, uri ) != 2 ) {
    uri = curl;
    type = "test";
  }
  if (type == "test") {
    if (Stdio.exist(uri)&&Stdio.is_file(uri))
      type = "file";
    else
      type = "virt";
  }
  switch(type) {
  case "file":
    if (Stdio.exist(uri)&&Stdio.is_file(uri))
      xsl = Stdio.read_file(uri);
    else
      xsl = "<b>ERROR:</b> XSL Template Not Found";
    break;
  case "virt":
    xsl = id->conf->try_get_file(uri,id);
    if (!xsl)
      xsl = "<b>ERROR:</b> XSL Template Not Found";
    break;
  }
  cache->store( cache_string( xsl, curl ) );
}

string container_xslt(string tag, mapping args, string xml, object id)
{
  string xsl, type, key;
  string|mapping res;
  object parser;
  string content_type, charset;
  if(!args->stylesheet) args->stylesheet = QUERY(stylesheet);
  if(!args->baseuri) args->baseuri = QUERY(baseuri);
  if(!strlen(args->baseuri)) m_delete(args, "baseuri");
  
  if(args->baseuri) {
    if ( sscanf(args->baseuri, "%s:%s", type, key) != 2 ) {
      key = args->baseuri;
      type = "file";
    }
    switch(type) {
     case "virt":  
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

  string curl;
  if (args->baseuri)
    curl = sprintf("%s:/%s", type, Stdio.append_path(args->baseuri, key));
  else
    curl = sprintf("%s:/%s", type, key);

  switch(type) {
  case "virt":
  case "file":
    xsl = cache->retrieve(curl, cache_retrieve_template, ({curl, id}));
    break;
  case "var":
    xsl = id->variables[key];
    break;
  default:
    ERROR("Invalid stylesheet method. Valid methods are file:, virt: and var:");
  }

  if(!xsl) 
    ERROR("Couldn't read XSLT stylesheet:");
  if ( stringp(args->xmlfile) ) {
      xml = Stdio.read_file(args->xmlfile); // well well well
  }
  sscanf(xml, "%*[\n\t\r ]%s", xml);

#if constant(PiXSL.Parser) && constant(libxslt.Parser)
  if ( QUERY(use_xslt) ) 
    parser = libxslt.Parser();
  else
    parser = PiXSL.Parser();
#elseif constant(PiXSL.Parser)
  parser = PiXSL.Parser();
#elseif constant(libxslt.Parser)
  parser = libxslt.Parser();
  parser->set_include_callbacks(
	    match_include, open_include, read_include, close_include);
  foreach(indices(id->variables), string v) {
      id->variables[v] = "\""+id->variables[v] + "\"";
  }
#endif
  if(args->baseuri) 
    parser->set_base_uri(args->baseuri);

  parser->set_xsl_data(xsl);
  parser->set_xml_data(xml);
  parser->set_variables(id->variables);

  mixed err;
  err = catch {
    res = parser->run();
  };

  if ( err != 0 ) {
    res = parser->error();

    if(mappingp(res)) {
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
	      _Roxen.html_encode_string(lines[i])+"</font></b><br>";
	  } else {
	    line_emph += "<b>"+(i+1)+"</b>: "+
	      _Roxen.html_encode_string(lines[i])+"<br>";
	  }
	}
      }
      else if ( !objectp(res) ) 
      {
	werror("Error on XSL:\n"+sprintf("%O\n", err)+"\n");
	return "<b>ERROR:</b><XSLT Parsing failed with unknown error.<false>";
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
  werror("Result:\n"+res);
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

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: baseuri
//! Default base URI to use when resolving includes in the XSL stylesheets. Can be overridden by the baseuri attribute to the xslt tag.
//!
//!  type: TYPE_DIR
//!  name: Default Base URI
//
//! defvar: stylesheet
//! The default style sheet to use when the stylesheet attribute is omitted. Uses the same file:, virt: and var: syntax as the age.
//!
//!  type: TYPE_FILE
//!  name: Default XSLT Stylesheet
//
//! defvar: use_xslt
//! If set the libxslt library will be used !
//!  type: TYPE_FLAG
//!  name: Use libxslt Library ?
//
