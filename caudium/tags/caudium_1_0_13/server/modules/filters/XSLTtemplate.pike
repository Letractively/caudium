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

//
//! module: XSLT Templates
//!  Allows for automatic execution of XSLT templates for using various 
//!  templates. You specify a template in your XML file by adding a
//!  <strong>&lt;!DOCTYPE [basename]&gt;</strong> where <strong>[basename]</strong> is a base file
//!  file name for the template. The module will then add the extension for the
//!  requested file. This allows you to fetch the same file with different
//!  templates by changing the extension.
//!  <strong>Example:</strong> accessing file.html with &lt;!DOCTYPE template&gt;
//!  will try to find a template named template_html.xsl and apply it to the
//!  file file.xml.
//!  <p>You can also override the template by adding <strong>__xsl=template.xsl</strong> to
//!  the query string. This can be useful if the file you want to make a
//!  template for printing w/o using a different extension.</p>
//!  <p>Another special feature is post-processing RXML-parsing.
//!  To post-process a document, use <strong>&lt;xsl:output&gt;</strong> with the
//!  media-type attribute set to <strong>rxml:real/type</strong>, ie <strong>rxml:text/html</strong>
//!  for an HTML document.</p>
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FIRST
//! cvs_version: $Id$
//

/*
 * XSLTtemplate.pike - XSLT template module for Caudium. Utilizes the
 * Sablotron XSLT Library available from http://www.gingerall.com/
 * Tries to be (semi-)compatible with mod_xslt for Apache.
 * Written by David Hedbor <david@hedbor.org>
 */

/* TODO: Caching, various RXML parsing options */

string cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_FIRST;
constant module_name = "XSLT Templates";
constant module_doc = 
"Allows for automatic execution of XSLT templates for using various "
"templates. You specify a template in your XML file by adding a "
"<b>&lt;!DOCTYPE [basename]&gt;</b> where <b>[basename]</b> is a base file "
"file name for the template. The module will then add the extension for the "
"requested file. This allows you to fetch the same file with different "
"templates by changing the extension. "
"<p><b>Example:</b> accessing file.html with &lt;!DOCTYPE template&gt; "
"will try to find a template named template_html.xsl and apply it to the "
"file file.xml.  "
"<p>You can also override the template by adding <b>__xsl=template.xsl</b> to "
"the query string. This can be useful if the file you want to make a "
"template for printing w/o using a different extension."
"<p>Another special feature is post-processing RXML-parsing. "
"To post-process a document, use <b>&lt;xsl:output&gt;</b> with the "
"media-type attribute set to <b>rxml:real/type</b>, ie <b>rxml:text/html</b> "
"for an HTML document.</p>"
#if !constant(PiXSL.Parser)
"<p><b><blink>ERROR</blink>: "
"<font color=red>The PiXSL.so pike-module is missing. This "
"module will not function correctly!</font></b></p>\n"
#endif
;
void create()
{
  defvar("stylesheet", "", "Default XSLT stylesheet", TYPE_FILE,
	 "The default style sheet to use when no other stylesheet is "
	 "found. This should be a full path in the real filesystem.");
  defvar("xsldir", "", "Template directory", TYPE_DIR,
         "If non-empty, this path in the real filesystem will be prepended "
	 "to all stylesheet names as specified in the DOCTYPE attribute. ");
  defvar("indexfile", "index.xml", "Index file name", TYPE_STRING,
         "The name of the file to use as the XML source file for directory "
	 "accesses. For example a request made to <i>/docs/</i> would result "
	 "in the file <i>/docs/index.xml</i> to be used with the default "
	 "setting. If this variable is the empty string, directory requests "
	 "will be ignored.");
  defvar("indexext", "html", "Index file extension", TYPE_STRING,
         "When a directory request (i.e <i>/docs/</i> without an explicit "
	 "file name) is received, the wanted extension (which is used to "
	 "locate the correct stylesheet) is unknown. This variable sets the "
	 "extension to be used in those cases. <b>Important:</b> "
	 "Do not prepend the extension with a dot!");
  defvar("xmlext", ".xml", "XML source file extension", TYPE_STRING,
         "The extension of the requested file is stripped and replaced with "
	 "this string to find the XML source file. I.e if the default value "
	 "<i>.xml</i> is used and the requested file is test.html, the "
	 "module would use the file test.xml as the XML source file. ");
  defvar("xslext", ".xsl", "XSLT stylesheet extension", TYPE_STRING,
         "The extension appended to the value specified in the &lt;!DOCTYPE> "
	 "attribute. This variable is not for the default template or "
	 "templates specified using the <i>&amp;__xsl=template</i> syntax.");
  defvar("showxml", 0, "Show raw XML files", TYPE_FLAG,
         "If this flag is set to Yes, requests for files ending will "
	 ".xml will result in the file being sent as back as text/xml "
	 "without trying to find and apply a stylesheet.");
}
#if constant(PiXSL.Parser)
#define ERROR(x) return http_string_answer("<html><head><title>XSLT Template error</title></head><body><p><b>XSLT Template error: "+ x +"</b><p></body></html>")
object regexp;
string xsldir;

void start() {
#if constant(PCRE.Regexp)
  regexp = PCRE.Regexp("(.*)\\.(.*)$", "S");
#else
  regexp = Regexp("(.*)\\.(.*)$");
#endif
  xsldir = QUERY(xsldir) == "" ? 0 : QUERY(xsldir);
}

mapping|int first_try(object id)
{
  string xsl, xml, xsl_name, xml_name;
  string|mapping res;
  object(PiXSL.Parser) parser;
  string content_type, charset;
  string basedir, basename, extension;
  if(id->not_query[-1] == '/') {
    if(strlen(QUERY(indexfile))) {
      basename = id->not_query + QUERY(indexfile);
      extension = QUERY(indexext);
    } else {
      return 0;
    }
  } else {
    array tmp;
    tmp = regexp->split(id->not_query);
    /* No extension found, we won't handle this one */
    if(!tmp || sizeof(tmp) < 2) return 0;
    basename = tmp[-2];
    extension = tmp[-1];
  }
  if ( (extension == "xml") && (QUERY(showxml)==1) ) 
    return 0; /* This passes on the request to the underlying filesystem */
  basedir = id->conf->real_file(dirname(id->not_query)+"/", id);
  if(!basedir) return 0; /* non-existing directory */
  basename = combine_path(basedir, predef::basename(basename));
    
  xml = Stdio.read_file(xml_name=basename+QUERY(xmlext));
  if(!xml) return 0; /* not for us... */
  if(id->variables->__xsl) {
    xsl_name = combine_path(basedir, id->variables->__xsl);
    xsl = Stdio.read_file(xsl_name);
    if(!xsl && xsldir) {
      xsl_name = combine_path(xsldir, id->variables->__xsl);
      xsl = Stdio.read_file(xsl_name);
    }      
    if(!xsl) {
      ERROR("Specified template '"+id->variables->__xsl+"' not found.");
    }
  } else {
    string tmp;
    sscanf(xml, "%*[\n\t\r ]%s", xml);
    sscanf(xml, "%*s<!DOCTYPE %s%*[ >]", tmp);
    if(!tmp) {
      if(strlen(QUERY(stylesheet))) {
	xsl_name = combine_path(basedir, QUERY(stylesheet));
	catch {
	  xsl = Stdio.read_file(xsl_name);
	};
	if(!xsl && xsldir) {
	  xsl_name = combine_path(xsldir, QUERY(stylesheet));
	  catch {
	    xsl = Stdio.read_file(xsl_name);
	  };
	}
      }
      if(!xsl) 
	ERROR("Missing template specification in XML source file and no "
	      "default template configured / found.");
    } else {
      xsl_name = combine_path(basedir, tmp+"_"+extension+QUERY(xslext));
      xsl = Stdio.read_file(xsl_name);
      if(!xsl && xsldir) {
	xsl_name = combine_path(xsldir, tmp+"_"+extension+QUERY(xslext));
	xsl = Stdio.read_file(xsl_name);
      }
      if(!xsl)
	ERROR("Couldn't find a wanted stylesheet '"+xsl_name+"'.");
    }
  }
  parser = PiXSL.Parser();
  parser->set_xsl_data(xsl);
  parser->set_xml_data(xml);
  parser->set_variables(id->variables);
  parser->set_base_uri(xsl_name);
  if(catch(res = parser->run())) {
    res = parser->error();
    if(!res) 
      ERROR("XSLT Parsing failed with unknown error.");
    else if(mappingp(res)) {
      int line = (int)res->line, sline, eline;
      string line_emph="";
      array lines;
      if(!res->URI) res->URI = "unknown file";
      if(search(res->URI, "xsl") != -1) {
	res->URI = "XSLT input <i>"+xsl_name+"</i>";
	if(line) lines = xsl / "\n";
      } else if(search(res->URI, "xml") != -1) {
	res->URI = "XML file <i>"+xml_name+"</i>";
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
      ERROR(sprintf("<b>%s:</b> XSLT Parsing failed with %serror code %s on<br>\n"
		    "line %s in %s:<br>\n%s<p>%s<br>\n<false>",
		    res->level||upper_case(res->msgtype||"ERROR"), 
		    res->module ? res->module + " " : "",
		    res->code || "???",
		    res->line || "???",
		    res->URI || "unknown file",
		    res->msg || "Unknown error", line_emph));
    }
  }
  charset = parser->charset();
  content_type = parser->content_type() || "text/html";
  if(content_type[..4] == "rxml:") {
    res = parse_rxml(res, id);
    content_type=content_type[5..];
  }
  if(charset)
    content_type += "; charset="+charset;
  return http_string_answer(res, content_type);
}

#endif

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: stylesheet
//! The default style sheet to use when no other stylesheet is found. This should be a full path in the real filesystem.
//!  type: TYPE_FILE
//!  name: Default XSLT stylesheet
//
//! defvar: xsldir
//! If non-empty, this path in the real filesystem will be prepended to all stylesheet names as specified in the DOCTYPE attribute. 
//!  type: TYPE_DIR
//!  name: Template directory
//
//! defvar: indexfile
//! The name of the file to use as the XML source file for directory accesses. For example a request made to <i>/docs/</i> would result in the file <i>/docs/index.xml</i> to be used with the default setting. If this variable is the empty string, directory requests will be ignored.
//!  type: TYPE_STRING
//!  name: Index file name
//
//! defvar: indexext
//! When a directory request (i.e <i>/docs/</i> without an explicit file name) is received, the wanted extension (which is used to locate the correct stylesheet) is unknown. This variable sets the extension to be used in those cases. <b>Important:</b> Do not prepend the extension with a dot!
//!  type: TYPE_STRING
//!  name: Index file extension
//
//! defvar: xmlext
//! The extension of the requested file is stripped and replaced with this string to find the XML source file. I.e if the default value <i>.xml</i> is used and the requested file is test.html, the module would use the file test.xml as the XML source file. 
//!  type: TYPE_STRING
//!  name: XML source file extension
//
//! defvar: xslext
//! The extension appended to the value specified in the &lt;!DOCTYPE> attribute. This variable is not for the default template or templates specified using the <i>&amp;__xsl=template</i> syntax.
//!  type: TYPE_STRING
//!  name: XSLT stylesheet extension
//
//! defvar: showxml
//! If this flag is set to Yes, requests for files ending will .xml will result in the file being sent as back as text/xml without trying to find and apply a stylesheet.
//!  type: TYPE_FLAG
//!  name: Show raw XML files
//
