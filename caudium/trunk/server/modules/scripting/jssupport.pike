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
#ifdef THREADS
inherit Thread.Mutex;
#endif

#define JSERR(CODE, SHORT, LONG)  id->conf->http_error->handle_error(CODE, SHORT, LONG, id)
void create()
{
  defvar("exts", ({ "js", "jsc" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse as stand-alone JavaScripts");
  defvar("securefile", 0, "Security: Allow file accesses", TYPE_FLAG,
	 "Should JavaScript code be allowed to read and write files? "
	 "Generally this is not recommended since all file accesses would be "
	 "made as the user running the webserver.");
  defvar("securesystem", 0, "Security: Allow dangerous system calls", TYPE_FLAG,
	 "Should JavaScript code be allowed to call various dangerous system "
	 "calls like chdir() and popen()? This is only advisable if the you "
	 "trust everyone that write JavaScript code, and if you really need "
	 "these features. Better safe than sorry.");

  defvar("maxfd", 32, "Security: Max file descriptors per interpreter",
	 TYPE_INT, "The maximum number of file descriptors an interpreter "
	 "should be allowed to have open at any time.");

  /*
} else if(OPT_IS("secure_builtin_system")) {
    options.secure_builtin_system = !IS_ZERO(sval);
  } else if(OPT_IS("annotate_assembler")) {
    options.annotate_assembler = !IS_ZERO(sval);
  } else if(OPT_IS("debug_info")) {
    options.debug_info = !IS_ZERO(sval);
  } else if(OPT_IS("executable_bc_files")) {
    options.executable_bc_files = !IS_ZERO(sval);
  } else if(OPT_IS("warn_unused_argument")) {
    options.warn_unused_argument = !IS_ZERO(sval);
  } else if(OPT_IS("warn_unused_variable")) {
    options.warn_unused_variable = !IS_ZERO(sval);
  } else if(OPT_IS("warn_undef")) {
    options.warn_undef = !IS_ZERO(sval);
  } else if(OPT_IS("warn_shadow")) {
    options.warn_shadow = !IS_ZERO(sval);
  } else if(OPT_IS("warn_with_clobber")) {
    options.warn_with_clobber = !IS_ZERO(sval);
  } else if(OPT_IS("warn_missing_semicolon")) {
    options.warn_missing_semicolon = !IS_ZERO(sval);
  } else if(OPT_IS("warn_strict_ecma")) {
    options.warn_strict_ecma = !IS_ZERO(sval);
  } else if(OPT_IS("warn_deprecated")) {
    options.warn_deprecated = !IS_ZERO(sval);
  } else if(OPT_IS("optimize_peephole")) {
    options.optimize_peephole = !IS_ZERO(sval);
  } else if(OPT_IS("optimize_jumps_to_jumps")) {
    options.optimize_jumps_to_jumps = !IS_ZERO(sval);
  } else if(OPT_IS("optimize_bc_size")) {
    options.optimize_bc_size = !IS_ZERO(sval);
  } else if(OPT_IS("optimize_heavy")) {
    options.optimize_heavy = !IS_ZERO(sval);
  } else if(OPT_IS("fd_count")) {
    if(sval->type == T_INT)
      options.fd_count = sval->u.integer;
  } 
}
  */
}

private mapping options;
private mapping byte_code_cache;
private JavaScript.Interpreter compile_interpreter;
private string parse_byte_code;

void start() {
  byte_code_cache = ([]);

  options = ([]);
  options->secure_builtin_file   = !QUERY(securefile);
  options->secure_builtin_system = !QUERY(securesystem);
  options->fd_count = QUERY(maxfd);
  compile_interpreter = JavaScript.Interpreter(0, options);  
  options->no_compiler = 1;
  parse_byte_code = compile_interpreter->compile("parse();");
}

string comment()
{
  return "JS Extensions "+QUERY(exts)*" ";
}

array (string) query_file_extensions()
{
  return QUERY(exts);
}

void add_var_scopes(object id, JavaScript.Interpreter js)
{
  if(!id->misc->scopes && id->conf->parse_module) {
    id->misc->scopes = mkmapping(indices(id->conf->parse_module->scopes),
				 values(id->conf->parse_module->scopes)->clone());
  } else {
    id->misc->scopes = ([]);
  }
  foreach(indices(id->misc->scopes), string name) {
    js->add_scope(name == "var" ? "vars" : name,
		  get_scope_var, set_scope_var);
  }
}

string js_to_byte_code(string js, int reload)
{
  string bc, key;
#ifdef THREADS
  object mtx;
#endif

  key = strlen(js)+":";
#if constant(Mhash.hash_md5)
  key += Mhash.hash_md5(js);
#elif constant(Crypto.md5)
  object md5 = Crypto.md5();
  md5->update(js);
  key += md5->digest();
#else
  key += js[..50]+hash(js); /* GUCK! */
#endif
  
  if(!reload) {
    bc = cache_lookup("js_byte_code", key);
    if(bc) return bc;
  }
#ifdef THREADS
  mtx = lock();
#endif
  bc = compile_interpreter->compile(js);
#ifdef THREADS
  destruct(mtx);
#endif
  cache_set("js_byte_code", key, bc);
  return bc;
}

mapping handle_file_extension(object f, string e, object id)
{
  JavaScript.Interpreter js;
  mixed eval_ret, ret;
  mixed err;
  NOCACHE();
  js = JavaScript.Interpreter(id, options);
  add_var_scopes(id, js);
  err = catch {
    eval_ret = js->execute(js_to_byte_code(f->read(), id->pragma["no-cache"]));
  };
  if(err) {
    report_error("An error occured when evaluating JavaScript.\n"+
		 describe_backtrace(err));
    return JSERR(500, "Internal Server Error",
		 "An error occured when evaluating JavaScript. This is the "
		 "reported problem:<p>"
		 "<pre>"+err[0]+"</pre>");
  }
  if(!eval_ret) {
    catch {
      ret = js->execute(parse_byte_code);
    };
    if(arrayp(ret) && sizeof(ret) == 2 && stringp(ret[0]) && stringp(ret[1])) {
      // Data returned from the parse function. If it's an array with two strings
      // the first entry is data and the second content type. Otherwise use
      // default handle.
      return http_string_answer(@ret);
    }
    eval_ret = ret;
  }
  if(!eval_ret) {
    return JSERR(500, "Internal Server Error",
		 "The JavaScript script returned no data.");
  } else if(stringp(eval_ret))
    return http_string_answer(eval_ret);
  else
    return http_string_answer(sprintf("%O", eval_ret), "text/plain");
}
