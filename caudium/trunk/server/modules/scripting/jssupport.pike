/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

//
//! module: JavaScript support
//!  Early support for inline and stand-alone javascripts. Today the only
//!  way to output data is through a return statement. If you return zero, null
//!  or undefined (which all end up being zero in Pike at the moment),
//!  no output will be written. For future compatibility, return false
//!  if you don't want any output.
//!
//!  <p>The syntax for using JavaScript in your pages is <?js ?> with the
//!  XML-compliant parser and <js></js> with the old-style parser. Javascripts,
//!  both inline and standalone, are much safer than pike scripts. You don't
//!  have access to any dangerous functionality. Of course, you can always
//!  write eternal loops etc.</p>
//!
//!  <p>To exchange data with other parts of Caudium (read and write), you can
//!  use any available variable scope using the same syntax. I.e to retrieve
//!  a form variable, you would have the JS code 'form.varname'. You can set
//!  variables (in writable scopes) the same way using the form.varname=value
//!  syntax. It should be noted that you can set variables to integers, floats
//!  and arrays from JavaScript. Doing this might cause problems in other
//!  parts of Caudium and should be avoided for now.</p>
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FILE_EXTENSION | MODULE_PARSER
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";

constant thread_safe=1;

inherit "module";
inherit "caudiumlib";
#include <module.h>
#include <config.h>

constant module_type = MODULE_FILE_EXTENSION | MODULE_PARSER;
constant module_name = "JavaScript support";
constant module_doc  = #"
way to output data is through a return statement. If you return zero, null
or undefined (which all end up being zero in Pike at the moment),
no output will be written. For future compatibility, return false
if you don't want any output.

<p>The syntax for using JavaScript in your pages is <?js ?> with the
XML-compliant parser and <js></js> with the old-style parser. Javascripts,
both inline and standalone, are much safer than pike scripts. You don't
have access to any dangerous functionality. Of course, you can always
write eternal loops etc.</p>

<p>To exchange data with other parts of Caudium (read and write), you can
use any available variable scope using the same syntax. I.e to retrieve
a form variable, you would have the JS code 'form.varname'. You can set
variables (in writable scopes) the same way using the form.varname=value
syntax. It should be noted that you can set variables to integers, floats
and arrays from JavaScript. Doing this might cause problems in other
parts of Caudium and should be avoided for now.</p> ";
constant module_unique = 0;


#define JSERR(CODE, SHORT, LONG)  id->conf->http_error->handle_error(CODE, SHORT, LONG, id)
void create()
{
  defvar("exts", ({ "js", "jsc" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse as stand-alone JavaScripts");
}

string comment()
{
  return "JS Extensions "+QUERY(exts)*" ";
}

array (string) query_file_extensions()
{
  werror("Queried extensions: %O\n", QUERY(exts));
  return QUERY(exts);
}

void add_var_scopes(object id, JavaScript.Interpreter js)
{
  if(!id->misc->scopes && id->conf->parse_module) {
    id->misc->scopes =
      mkmapping(indices(id->conf->parse_module->scopes),
		values(id->conf->parse_module->scopes)->clone());
  }
  foreach(indices(id->misc->scopes), string name) {
    js->add_scope(name == "var" ? "vars" : name, get_scope_var, set_scope_var);
  }
}
mapping handle_file_extension(object f, string e, object id)
{
  JavaScript.Interpreter js;
  mixed eval_ret, ret;
  mixed err;
  string js_source = f->read();
  NOCACHE();
  js = JavaScript.Interpreter(id);
  add_var_scopes(id, js);
  err = catch {
    eval_ret = js->eval(js_source);
  };
  if(err) {
    return JSERR(500, "Internal Server Error",
		 "An error occured when evaluating JavaScript. This is the "
		 "reported problem:<p>"
		 "<pre>"+err[0]+"</pre>");
  }
  catch {
    ret = js->eval("parse();");
  };

  if(arrayp(ret) && sizeof(ret) == 2 && stringp(ret[0]) && stringp(ret[1])) {
    // Data returned from the parse function. If it's an array with two strings
    // the first entry is data and the second content type. Otherwise use
    // default handle.
    return http_string_answer(@ret);
  }
  if(!ret) ret = eval_ret;
  if(!ret) {
    return JSERR(500, "Internal Server Error",
		 "The JavaScript script returned no data.");
  }
  else if(stringp(ret))
    return http_string_answer(ret);
  else
    return http_string_answer(sprintf("%O", ret), "text/plain");
}
