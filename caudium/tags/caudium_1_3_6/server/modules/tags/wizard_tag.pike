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
 */

/*
 * Wizard tag module, mainly written by Per Hedbor.
 */

//! module: Advanced Wizard
//!  This module contains code that implements basic wizard dialogs.
//! type: MODULE_PARSER
//! cvs_version: $Id$ 
//
//! tag: wizard
//!  Defines a new wizard.
//! attribute: title
//!  Set title of the new wizard.
//! attribute: cancel
//! attribute: ok-label
//!  Set the text of the OK button.
//! attribute: cancel-label
//!  Set the text of the cancel button.
//! attribute: done
//! attribute: formname
//!  Set the name attribute of the generated form. Useful for DHTML.
//
//! container: page
//!  Creates a new wizard page.
//! attribute: name
//!  Optional attribute to set the page name.
//!
//!
//! container: done
//!  contents displayed at completion of all other pages.

constant cvs_version = "$Id$";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

constant module_type = MODULE_PARSER;
constant module_name = "Wizard generator";
constant module_doc  = "Generates wizards<p>See &lt;wizard help&gt; for more information\n";
constant module_unique = 1;

string internal_page(string t, mapping args, string contents, mixed f,
		     mapping d)
{
  f->pages +=({({contents, 1})});
}

string internal_verify(string t, mapping args, string contents, mixed f,
                     mapping d)
{
  f->verify +=({({contents, 1})});
}


string internal_done(string t, mapping args, string contents, mixed f,
		     mapping d)
{
  f->done=contents;
}

string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') return file;
  file = combine_path(dirname(id->not_query) + "/",  file);
  return file;
}

string old_pike = "";
object old_wizard = 0;

string tag_verify_message(string t, mapping args, string contents, object id,
                  object file, mapping defines)
{
  if(id->misc->wizardpagefailed)
     return contents;
}

string tag_wizard(string t, mapping args, string contents, object id,
		  object file, mapping defines)
{
  if(!id->misc->line)
    id->misc->line=-1;
  if(args->formname) id->misc->wizardformname=args->formname;

  mapping f = ([ "pages":({}), "verify":({}) ]);
  string pike = ("inherit \"wizard\";\n" +
#if (__VERSION__ >= 0.6)
		 sprintf("# "+id->misc->line+" %O\n"
			 "string name = %O;\n",
			 id->not_query, (args->name||"unnamed"))
#else
		 "# "+id->misc->line+" \""+id->not_query+"\"\n"
		 "string name=\""+(args->name||"unnamed") + "\";\n"
#endif /* __VERSION__ >= 0.6 */
		 );
  int p;
  foreach(glob("*-label", indices(args)), string a)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+id->misc->line+" %O\n",
		    id->not_query);
    pike += sprintf("  string "+replace(replace(a,"-","_"),({"(",")","+",">"}),
					({"","","",""}))+ 
		    " = %O;\n", args[a]);
#else
    pike += ("# "+id->misc->line+" \""+id->not_query+"\"\n");
    pike += "  string "+replace(replace(a,"-","_"),({"(",")","+",">"}),
				({"","","",""}))+ 
      " = \""+replace(args[a], ({"\"","\n","\r", "\\"}), 
		      ({"\\\"", "\\n", "\\r", "\\\\"}))+"\";\n";
#endif /* __VERSION__ >= 0.6 */
  }


  if(args->ok)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+id->misc->line+" %O\n", id->not_query);
    pike += sprintf("mixed wizard_done(object id)\n"
		    "{\n"
		    "  id->not_query = %O;\n\""+
		    "  return caudium->get_file( id );\n"
		    "}\n\n",
		    fix_relative(args->ok, id));
#else
    pike += ("# "+id->misc->line+" \""+id->not_query+"\"\n");
    pike += ("mixed wizard_done(object id)\n"
	     "{\n"
	     "  id->not_query = \""+
	     fix_relative(replace(args->ok, ({"\"","\n","\r", "\\"}), 
				  ({"\\\"", "\\n", "\\r", "\\\\"})),id)+"\";\n"
	     "  return caudium->get_file( id );\n"
	     "}\n\n");
#endif /* __VERSION__ >= 0.6 */
  }

  parse_html(contents,
		   ([]),
		   ([ "page":internal_page,
		      "verify": internal_verify,
		      "done":internal_done ]), 
		   f);
  if (f->done && !args->ok) {
#if __VERSION__ >= 0.6
    pike += sprintf("mixed wizard_done(object id)\n"
		    "{\n"
		    "  return parse_rxml(%O, id);\n"
		    "}\n", f->done);
#else
    pike += ("mixed wizard_done(object id)\n"
	     "{\n"
	     "  return parse_rxml(\""+replace(f->done,
					      ({"\"","\n","\r", "\\"}), 
					      ({"\\\"", "\\n", "\\r", "\\\\"}))+
	     "\",id);\n"
	     "}\n");
#endif /* __VERSION__ >= 0.6 */
  }
  foreach(f->pages, array q)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+q[1]+" %O\n", id->not_query);
    pike += sprintf("string page_"+p+"(object id) {" +
		    "  return %O;\n"
		    "}\n", q[0]);
#else
    pike += ("# "+q[1]+" \""+id->not_query+"\"\n");
    pike += ("string page_"+p+"(object id) {" +
	     "return \""+replace(q[0], ({"\"","\n","\r", "\\"}), 
				 ({"\\\"", "\\n", "\\r", "\\\\"}))+"\";}\n");
#endif /* __VERSION__ >= 0.6 */
    p++;
  }
  p=0;
  foreach(f->verify, array q)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+q[1]+" %O\n", id->not_query);
    pike += sprintf("mixed verify_"+p+"(object id) {" +
                    "%s\n"
                    "}\n", q[0]);
#else
    pike += ("# "+q[1]+" \""+id->not_query+"\"\n");
    pike += ("string verify_"+p+"(object id) {" +
             "return \""+replace(q[0], ({"\"","\n","\r", "\\"}),
                                 ({"\\\"", "\\n", "\\r", "\\\\"}))+"\";}\n");
#endif /* __VERSION__ >= 0.6 */
    p++;
  }
  object w;
  if(pike == old_pike)
    w = old_wizard;
  else
  {
    old_wizard = w = compile_string(pike)();
    old_pike = pike;
  }


  mixed res = w->wizard_for(id,fix_relative(args->cancel||args->done||"",id));

  if(mappingp(res))
  {
    defines[" _error"] = res->error;
    defines[" _extra_heads"] = res->extra_heads;
    return res->data||(res->file&&res->file->read())||"";
  }
  return res;
}


mapping query_container_callers()
{
  return ([ "wizard" : tag_wizard ]);
}

void start()
{
  
} 
