/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
 * $Id$
 */

/*
 * Authors : David Gourdelier <vida@caudium.net>
 */
 
constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER; 
constant module_name = "Sscanf container";
constant module_doc  = "Adds the &lt;sscanf&gt; &lt;/sscanf&gt; container."
	       " This allow you to have scanf like in RXML. "
	       "Example:<pre>"
	       "&lt;sscanf format=\"%s.%s\" args=\"1arg, 2arg\"&gt;\n"
	       "  &lt;content&gt;\n"
	       "    string1.string2\n"
	       "  &lt;/content&gt;\n"
	       "  &lt;args&gt;\n"
	       "    first string : #1arg# second string : #2arg#\n"
	       "  &lt;/args&gt;\n"
	       "&lt;/sscanf&gt;\n"
	       "</pre>";
constant module_unique = 1;

void create()
{
}

class Content 
{
  string content;
};

string container_sscanf(string tag_name, mapping args, string contents, object id)
{
  string out;
  if(args->help)
    return module_doc;
  if(!args->format)
    return "Sscanf: Missing format, giving up";
  if(!args->args)
    return "Sscanf: You must give the args argument";
  array(string) lvalues = Array.map(args->args / ",",
    lambda(string arg) { return String.trim_all_whites(arg); });
  object Cont = Content();
  out = parse_html(contents,
      	           ([ ]),
  	           ([
		     "content": container_sscanf_content,
		     "args": container_sscanf_args 
		    ]),
	           id, Cont, args->format, lvalues);
  return out;
}

string container_sscanf_content(string tag_name, mapping args, string contents, object id, object Cont)
{
  Cont->content = contents;
  return "";
}

string container_sscanf_args(string tag_name, mapping args, string contents, object id, object Cont, string format, array(string) lvalues)
{
  string out;
  if(!Cont->content)
    return "Sscanf: You must give a content container";
  string content = Cont->content;
  array result = array_sscanf(content, format);
  if(sizeof(result) == 0)
    return "<!-- Sscanf: didn't match any results -->\n";
  if(sizeof(result) != sizeof(lvalues))
    return sprintf("<! -- Sscanf: Wrong number of arguments (%d) for format %O -->", 
      sizeof(result), format);
  mapping outlet = mkmapping(lvalues, result);
  out = do_output_tag(args, ({ outlet }), contents, id);
  return out;
}

mapping query_container_callers()
{
  return ([ "sscanf" : container_sscanf ]);
}
