/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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
//! module: Pike Tag
//!  Adds support for inline pike in documents.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
//! container: pike
//!  Compiles and executes the contents as Pike code. This tag is not always
//!  available, since it can be a security hazard.
//
//! attribute: help
//!  Show help for the tag
//
/*
 * The Pike Tag module.
 * Adds support for inline pike in documents.
 *
 * Example:
 *  <pike>
 *   return "Hello world!\n";
 *  </pike>
 */
 
constant cvs_version = "$Id$";
constant thread_safe=1;

inherit "caudiumlib";
inherit "module";
#include <module.h>;

constant module_type = MODULE_PARSER;
constant module_name = "Pike tag";
constant module_doc  = "This module adds a new tag, &lt;pike&gt;&lt;/pike&gt;. It makes"
	    " it possible to insert some pike code directly in the document."
	    "<br><img src=/image/err_2.gif align=left alt=\"\">"
	    "NOTE: This module should not be enabled if you allow anonymous"
	    " PUT!<br>\n"
	    "NOTE: Enabling this module is the same thing as letting your"
	    " users run programs with the same right as the server!"
	    "<p>Example:<p><pre>"
	    " &lt;pike&gt; "
	    "   return \"Hello world!\\n\";"
	    " &lt;/pike&gt;\n</pre>"
	    "<p>Arguments: Any, all arguments are passed to the script "
	    " in the mapping args. There are also a few helper functions "
	    "available, "
	    " output(string fmt, mixed ... args) is a fast way to add new"
	    " data to a dynamic buffer, flush() returns the contents of the"
	    " buffer as a string.  A flush() is done automatically if the"
	    " \"script\" does not return any data, thus, another way to write the"
	    " hello world script is <tt>&lt;pike&gt;output(\"Hello %s\n\", \"World\");&lt/pike&gt</tt><p>"
	    "The request id is available as id, all defines are available "
	    "in the mapping 'defines'. ";
constant module_unique = 1;

void create()
{
  defvar ("debugmode", "HTML text", "Error messages", TYPE_STRING_LIST,
	  "How to report errors (e.g. backtraces generated by the Pike code):\n"
	  "\n"
	  "<p><ul>\n"
	  "<li><i>Off</i> - Silent.</li>\n"
	  "<li><i>Log</i> - System debug log.</li>\n"
	  "<li><i>HTML comment</i> - Include in the generated page as an HTML comment.</li>\n"
	  "<li><i>HTML text</i> - Include in the generated page as normal text.</li>\n"
	  "</ul></p>\n",
	  ({"Off", "Log", "HTML comment", "HTML text"}));

  defvar("program_cache_limit", 256, "Program cache limit", TYPE_INT|VAR_MORE,
	 "Maximum size of the cache for compiled programs.");
}

string reporterr (string header, string prg, string dump)
{
  if (QUERY (debugmode) == "Off") return "";
  if(strlen(prg)) prg = "\n*** Begin program\n"+prg+"\n*** End Program\n\n";
  report_error (header + prg+dump + "\n");

  switch (QUERY (debugmode)) {
    case "HTML comment":
      return "\n<!-- " + html_encode_string(header + dump) + "\n-->\n";
    case "HTML text":
      return "\n<br><font color=red><b>" + html_encode_string (header) +
	"</b></font><pre>\n" + html_encode_string (dump) + "</pre><br>\n";
    default:
      return "";
  }
}

// Helper functions, to be used in the pike script.
// output(string fmt, mixed ... args) is a fast way to add new
// data to a dynamic buffer, flush() returns the contents of the
// buffer as a string.  A flush() is done automatically if the
// "script" does not return any data, thus, another way to write the
// hello world script is <pike>output("Hello %s\n", "World");</pike>
inline private nomask string functions()
{
  return 
    "inherit \"caudiumlib\";\n"
    "\n"
    "array data = ({});\n\n"
    "int output(mixed ... args) {\n"
    "if(sizeof(args) > 1) data += ({ sprintf(@args) }); else data += args;\n"
    "return 0;\n"
    "}\n\n"
    "string flush() {\n"
    "  string r;\n"
    "  r=data*\"\";\n"
    "  data = ({});\n"
    "  return r;\n"
    "}\n"
    "constant seteuid=0;\n"
    "constant setegid=0;\n"
    "constant setuid=0;\n"
    "constant setgid=0;\n"
    "constant call_out=0;\n"
    "#0 \"piketag\"\n"
    ;
    
}

// Preamble
private nomask inline string pre(string what)
{
  if(search(what, "parse(") != -1)
    return functions();
  if(search(what, "return") != -1)
    return functions() + 
    "string|int parse(object id, mapping defines, object file, mapping args) { ";
  else
    return functions() +
    "string|int parse(object id, mapping defines, object file, mapping args) { return ";
}

// Will be added at the end...
private nomask inline string post(string what) 
{
  if(search(what, "parse(") != -1)
    return "";
  if (!strlen(what) || what[-1] != ';')
    return ";}";
  else
    return "}";
}

private static mapping(string:program) program_cache = ([]);

// Compile and run the contents of the tag (in s) as a pike
// program. 
string tag_pike(string tag, mapping m, string s, object request_id,
		object file, mapping defs)
{
  program p;
  object o, e;
  string res;
  mixed err;
  if(m->help) return module_doc;

  request_id->misc->cacheable=0;

#if constant(set_max_eval_time)
  if(err = catch {
    set_max_eval_time(2);
#endif
    e = ErrorContainer();
    master()->set_inhibit_compile_errors(e);
    err = catch {
      s=pre(s)+s+post(s);
      p = program_cache[s];

      if (!p) {
	// Not in the program cache.

	p = compile_string(s, "Pike-tag");

	if (sizeof(program_cache) > QUERY(program_cache_limit)) {
	  array a = indices(program_cache);
	  int i;

	  // Zap somewhere between 25 & 50% of the cache.
	  for(i = QUERY(program_cache_limit)/2; i > 0; i--) {
	    m_delete(program_cache, a[random(sizeof(a))]);
	  }
	}

	program_cache[s] = p;
      }
    };
    master()->set_inhibit_compile_errors(0);
    master()->clear_compilation_failures();
    if(!p)
    {
      if(strlen(e->get())) {
	return reporterr(sprintf("Error compiling <pike> tag in %O:\n", 
				 request_id->not_query),
			 s, e->get());
      }
      throw(err);
    }

    if(err = catch{
      res = (o=p())->parse(request_id, defs, file, m);
    })
    {
      return (res || "") + (o && o->flush() || "") +
	reporterr ("Error in <pike> tag in " + request_id->not_query + ":\n",
		   s, (describe_backtrace (err) / "\n")[0..1] * "\n");
    }
#if constant(set_max_eval_time)
    remove_max_eval_time(); // Remove the limit.
  })
  {
    return (res || "") + (o && o->flush() || "") +
      reporterr (err[0] + " for <pike> tag in " + request_id->not_query + "\n", s, "");
    remove_max_eval_time(); // Remove the limit.
  }
#endif

  res = (res || "") + (o && o->flush() || "");

  if(o) destruct(o);

  return res;
}

mapping query_container_callers()
{
  return ([ "pike":tag_pike ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: debugmode
//! How to report errors (e.g. backtraces generated by the Pike code):
//!
//!<p><ul>
//!<li><i>Off</i> - Silent.</li>
//!<li><i>Log</i> - System debug log.</li>
//!<li><i>HTML comment</i> - Include in the generated page as an HTML comment.</li>
//!<li><i>HTML text</i> - Include in the generated page as normal text.</li>
//!</ul></p>
//!
//!  type: TYPE_STRING_LIST
//!  name: Error messages
//
//! defvar: program_cache_limit
//! Maximum size of the cache for compiled programs.
//!  type: TYPE_INT|VAR_MORE
//!  name: Program cache limit
//
