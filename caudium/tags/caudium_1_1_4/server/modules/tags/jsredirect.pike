/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © ???? Bill Welliver <hww3@riverweb.com>
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

//! module: JS Redirect
//!  Creates JavaScript powered dropdown redirect widgets.<br />
//!  &lt;JSRedirect&gt; takes the jsenabled option <br />
//!  &lt;Option&gt; takes the url=destination option &lt;/Option&gt;<br />
//!  &lt;/JSRedirect&gt;
//! type: MODULE_PARSER
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

#include <module.h>
#include <process.h>
inherit "module";
inherit "caudiumlib";

constant module_type  = MODULE_PARSER;
constant module_name  = "JS Redirect";
constant module_doc   = "Creates JavaScript powered dropdown redirect widgets."
                        "<br />&lt;JSRedirect&gt; takes the jsenabled option "
			"<br />&lt;Option&gt; takes the url=destination option "
			"&lt;/Option&gt;<br />"
			"&lt;/JSRedirect&gt;";
constant cvs_version  = "$Id$";
constant thread_safe  = 1;

string container_option(string tag_name, mapping arguments,
		string contents,object id, object file, mapping defines)
  {
  string retval="";
  if(arguments->_parsed) return retval;
  if(!id->misc->jsredirect) id->misc->jsredirect=({});
  if(!id->misc->jsrurls) id->misc->jsrurls=([]);
  contents=contents-"\n";
  id->misc->jsredirect+=({contents});
  id->misc->jsrurls+=([contents:(arguments->url||"")]);
  return retval;
  }

int i;
mixed container_jsredirect(string tag_name, mapping arguments,
			string contents, object id,
			mapping defines)
{
if(arguments->preparse)
contents = parse_rxml(contents, id);
contents = parse_html(contents,([]),([ "option":container_option ]), id );
   i++;
string retval="";
retval+="<script language=\"javascript\">\n<!--\n"
	"	function MakeArray() {\n"
        "	var lngth = MakeArray.arguments.length;\n"
        "	for ( i = 0 ; i < lngth ; i++ ) { this[i]=MakeArray.arguments[i] }\n"
	"	}\n"
	"function switch_page"+i+"()\n"
	"  {\n"
        "  var select = eval(document.jsredirect"+i+".jsredirect"+i+".selectedIndex);\n"

        "if( (select > 0) && (select < "+(sizeof(id->misc->jsredirect))
		+") )\n"
        "  {\n"
        "  var i=new MakeArray(";
for(int o=0; o<sizeof(id->misc->jsredirect); o++){
  	retval+="    '"+id->misc->jsrurls[id->misc->jsredirect[o]]+"'\n";
  if((o+1)!=sizeof(id->misc->jsredirect)) retval+=",";
  }

retval+="    )\n"
        "    location=i[document.jsredirect"+i+".jsredirect"+i+".selectedIndex];\n"
        "  }\n"
	"}\n"
	"// -->\n</script>\n";
retval+="<form name=jsredirect"+i+">\n";
retval+="<select name=\"jsredirect"+i+"\" onchange='switch_page"+i+"();'>\n";
for(int o=0; o<sizeof(id->misc->jsredirect); o++)
  retval+="<option _parsed=1>"+id->misc->jsredirect[o]+"\n";
retval+="</select>\n";
if(arguments->jsenabled) retval+="<font size=1>JavaScript Enabled</font>\n"; retval+="</form>\n";
return retval;

}

void start()
{
  i=0;
}

mapping query_container_callers()
{ 
 return (["jsredirect":container_jsredirect ]);
}

