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
"for an HTML document. "
#if !constant(PiXSL.Parser)
"<p><b><blink>ERROR</blink>: "
"<font color=red>The PiXSL.so pike-module is missing. This "
"module will not function correctly!</font></b>\n"
#endif
;
void create()
{
#if 0
  defvar("baseuri", "", "Default Base URI", TYPE_DIR,
	 "Default base URI to use when resolving includes in the XSL "
	 "stylesheets. Can be overridden by the baseuri attribute to "
	 "the xslt tag.\n");
  defvar("stylesheet", "", "Default XSLT Stylesheet", TYPE_FILE,
	 "The default style sheet to use when the stylesheet attribute is "
	 "omitted. Uses the same file:, virt: and var: syntax as the age.\n");
#endif
}

#if constant(PiXSL.Parser)
#define ERROR(x) return http_string_answer("<html><head><title>XSLT Template error</title></head><body><p><b>XSLT Template error: "+ x +"</b><p></body></html>")
object regexp;
void start() {
#if constant(PCRE.Regexp)
  regexp = PCRE.Regexp("(.*)\\.(.*)$", "S");
#else
  regexp = Regexp("(.*)\\.(.*)$");
#endif
}

mapping|int first_try(object id)
{
  string xsl, xml, xsl_name, xml_name;
  string|mapping res;
  object(PiXSL.Parser) parser;
  string content_type, charset;
  string basename, extension;
  if(id->not_query[-1] == '/') {
    basename = id->not_query + "index.xml";
    extension = "html";
  } else {
    array tmp;
    tmp = regexp->split(id->not_query);
    /* No extension found, we won't handle this one */
    if(!tmp || sizeof(tmp) < 2) return 0;
    basename = tmp[-2];
    extension = tmp[-1];
  }
  catch {
    xml = Stdio.read_file(id->conf->real_file(xml_name=basename+".xml", id) ||"");
  };
  if(!xml) return 0; /* not for us... */
  if(id->variables->__xsl) {
    xsl_name = combine_path(dirname(basename), id->variables->__xsl);
    catch {
      xsl = Stdio.read_file(id->conf->real_file(xsl_name, id));
    };
    if(!xsl)
      ERROR("Specified template '"+id->variables->__xsl+"' not found.");
  } else {
    string tmp;
    sscanf(xml, "%*[\n\t\r ]%s", xml);
    sscanf(xml, "%*s<!DOCTYPE %s%*[ >]", tmp);
    if(!tmp) 
      ERROR("Missing template specification in XML source file.");
    xsl_name = combine_path(dirname(id->not_query), tmp+"_"+extension+".xsl");
    catch {
      xsl = Stdio.read_file(id->conf->real_file(xsl_name, id));
    };
    if(!xsl)
      ERROR("Wanted template '"+tmp+"' not found.");
  }  
  parser = PiXSL.Parser();
  parser->set_xsl_data(xsl);
  parser->set_xml_data(xml);
  parser->set_variables(id->variables);
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
	res->URI = "XML file <i>"+xsl_name+"</i>";
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
