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

//
//! module: Per script and tag handler
//!  This module adds support for embedded Perl scripts in Caudium. It also
//!  provides a &lt;perl>&lt;/perl> container to make it possible to embed
//!  Perl code in RXML pages.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_EXPERIMENTAL|MODULE_FILE_EXTENSION|MODULE_PARSER
//! cvs_version: $Id$
//

#include <module.h>
inherit "module";
inherit "caudiumlib";

// Experimental Perl script and tag handler module originally
// written by Leif Stensson for Roxen Webserver. Ported to Caudium
// by Jan Legenhausen and David Hedbor. 

string cvs_version =
       "$Id$";

constant module_type = MODULE_EXPERIMENTAL|MODULE_FILE_EXTENSION|MODULE_PARSER;

constant module_name = "Perl support";
constant module_doc =
   "EXPERIMENTAL MODULE! This module provides a faster way of running "
   "Perl scripts with Caudium. "
   "The module also optionally provides a &lt;perl&gt;..&lt;/perl&gt; "
   "container to run Perl code from inside RXML pages."; 

constant thread_safe = 1;

static string recent_error = 0;
static int parsed_tags = 0, script_calls = 0, script_errors = 0;

static mapping handler_settings = ([ ]);


#ifdef THREADS
static object mutex = Thread.Mutex();
#endif

void create()
{
  defvar("extensions", ({ "pl", "perl" }), "Extensions", TYPE_STRING_LIST,
	 "List of URL extensions that should be taken to indicate that the "
	 "document is a Perl script.");

  defvar("showbacktrace", 0, "Show Backtraces", TYPE_FLAG,
	 "This setting decides whether to deliver a backtrace in the document "
	 "if an error is caught while a script runs.");

  defvar("tagenable", 0, "Enable Perl Tag", TYPE_FLAG,
	 "This setting decides whether to enable parsing of Perl code in "
	 "RXML pages, in &lt;perl&gt;..&lt;/perl&gt; containers.");

  defvar("scriptout", "HTML", "Script output", TYPE_MULTIPLE_STRING,
	 "How to treat script output. HTML means treat it as a plain HTML "
	 "document. RXML is similar, but passes it through the RXML parser "
	 "before returning it to the client. HTTP is the traditional CGI "
	 "output style, where the script is responsible for producing the "
	 "HTTP headers before the document, as well as the main document "
	 "data.",
         ({ "HTML", "RXML", "HTTP" })
	 );

  defvar("rxmltag", 0, "RXML-parse tag results", TYPE_FLAG,
	 "Allow RXML parsing of tag results.");
  
  defvar("bindir", "perl/bin", "Perl Helper Binaries", TYPE_DIR,
	 "Perl helper binaries directory.");

  defvar("parallel", 2, "Parallel scripts", TYPE_MULTIPLE_INT,
	 "Number of scripts/tags that may be evaluated in parallel. Don't set "
	 "this higher than necessary, since it may cause the server to block. "
	 "The default for this setting is 2.",
         ({ 1, 2, 3, 4, 5 }) );

#if constant(getpwnam)
  defvar("identity", "nobody:*", "Run Perl as...", TYPE_STRING,
	 "User and group to run Perl scripts and tags as. The default for "
	 "this option is `nobody:*'. Note that Caudium can't change user ID "
	 "unless it has sufficient permissions to do so. `*' means `use "
	 "same as Caudium'.");
#endif
}

string status()
{
  string s =
    "<b>Script calls</b>: " + script_calls + " <br />\n" +
    "<b>Script errors</b>: " + script_errors + " <br />\n" +
    "<b>Parsed tags</b>: "  + parsed_tags + " <br />\n";
  
#if constant(getpwnam)
  if (handler_settings->set_uid)
    s += sprintf("<b>Subprocess UID</b>: set uid=%O <br />\n",
		 handler_settings->set_uid);
  else
    s += "<b>Subprocess UID</b>: same as Caudium<br />\n";
#endif
  
  s += "<b>Helper script</b>: ";
  if (Stdio.File(QUERY(bindir)+"/perlrun", "r"))
    s += "found: " + QUERY(bindir)+"/perlrun <br />\n";
  else
    s += "not found.<br />\n";
  
  if (recent_error)
    s += "<b>Most recent error</b>: " + recent_error + " <br />\n";
  
  return s;
}

static object gethandler()
{
  return ExtScript.getscripthandler(QUERY(bindir)+"/perlrun",
                                    QUERY(parallel), handler_settings);
}

static void fix_settings()
{
  string u, g;
  mapping s = ([ ]);
  
#if constant(getpwnam)
  if (sscanf(QUERY(identity), "%s:%s", u, g) == 2)
  {
    array ua = getpwnam(u), ga = getgrnam(g);
    
    if (!ua) ua = getpwuid((int) u);
    if (!ga) ga = getgrgid((int) g);

    if (ua) s->set_uid = ua[2];
    if (ga) s->set_gid = ga[2];
  }
#endif

  handler_settings = s;
}

static void periodic()
{
  fix_settings();
  ExtScript.periodic_cleanup();
  call_out(periodic, 900);
}

void start()
{ fix_settings();
  call_out(periodic, 900);
}

mixed handle_file_extension(Stdio.File file, string ext, object id)
{
  object h = gethandler();

  if (id->realfile && stringp(id->realfile)) {
    array result;

    NOCACHE();

    if (!h) return http_string_answer("<h1>Script support failed.</h1>");

    mixed bt = catch (result = h->run(id->realfile, id));

    ++script_calls;

    if (bt)
    {
      ++script_errors;
      report_error("Perl script `" + id->realfile + "' failed.\n");
      if (QUERY(showbacktrace))
        return http_string_answer("<h1>Script Error!</h1>\n<pre>" +
				  describe_backtrace(bt) + "\n</pre>");
      else
        return http_string_answer("<h1>Script Error!</h1>");
    }
    else if (sizeof(result) > 1) {
      string r = result[1];
      //      werror("Result: " + sprintf("%O", r) + "\n");
      if (r == "") r = " "; // Some browsers don't like null answers.
      if (!stringp(r)) r = "(not a string)";
      switch (QUERY(scriptout))
      {
       case "RXML":
	return http_rxml_answer(r, id);
       case "HTML":
	return http_string_answer(r);
       case "HTTP":
	id->my_fd->write("HTTP/1.0 200 OK\r\n");
	id->my_fd->write(r);
	id->my_fd->close();
	return http_pipe_in_progress();
       default:
	return http_string_answer("SCRIPT ERROR: "
				  "bad output mode configured.\n");
      }
    } else {
      return http_string_answer(sprintf("RESULT: %O", result));
    }
  }

  return http_string_answer("FOO!");

  return 0;
}

mixed tag_perl(string tag, mapping attr, string contents, object id)
{
  if (!QUERY(tagenable))
    return ({"&lt;perl>...&lt;/perl> tag not enabled in this server."});

  object h = gethandler();
  
  if (!h)
    return ({"Embedded Perl support unavailable."});

  NOCACHE();
  
  array result;
  ++parsed_tags;
  result = h->eval(contents, id);

  if (result && sizeof(result) > 1)
  {
    if (result[0] < 0 || !stringp(result[1]))
      return ({ "SCRIPT ERROR: " + sprintf("%O", result[1]) });
    else if (QUERY(rxmltag)) {
      return result[1];
    } else {
      return ({ result[1] });
    }
  } else {
    return ({ sprintf("SCRIPT ERROR: bad result: %O", result) });
  }
}

/* Processing instruction call method */
string pi_perl(string tag, mixed ... args)
{
  return tag_perl(tag, ([]), @args);
}

mapping query_container_callers()
{
  return ([ "perl": tag_perl ]);
}

mapping query_pi_callers()
{
  return ([ "?perl": pi_perl ]);
}

array(string) query_file_extensions()
{
  return QUERY(extensions);
}

#ifdef manual
constant tagdoc=([
"?perl":#"<desc pi='pi'><p><short hide='hide'>
 Perl processing instruction tag.</short>This processing intruction
 tag allows for evaluating Perl code directly in the document.</p>

 <p>Note: Read the installation and configuration documentation in the
 Administration manual to set up the Perl support properly. If the
 correct parameters are not set the Perl code might not work properly
 or security issues might arise.</p>

 <p>There is also a <tag>perl</tag>...<tag>/perl</tag> container tag
 available.</p>
</desc>",

  ]);
#endif


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: extensions
//! List of URL extensions that should be taken to indicate that the document is a Perl script.
//!  type: TYPE_STRING_LIST
//!  name: Extensions
//
//! defvar: showbacktrace
//! This setting decides whether to deliver a backtrace in the document if an error is caught while a script runs.
//!  type: TYPE_FLAG
//!  name: Show Backtraces
//
//! defvar: tagenable
//! This setting decides whether to enable parsing of Perl code in RXML pages, in &lt;perl&gt;..&lt;/perl&gt; containers.
//!  type: TYPE_FLAG
//!  name: Enable Perl Tag
//
//! defvar: scriptout
//! How to treat script output. HTML means treat it as a plain HTML document. RXML is similar, but passes it through the RXML parser before returning it to the client. HTTP is the traditional CGI output style, where the script is responsible for producing the HTTP headers before the document, as well as the main document data.
//!  type: TYPE_MULTIPLE_STRING
//!  name: Script output
//
//! defvar: rxmltag
//! Allow RXML parsing of tag results.
//!  type: TYPE_FLAG
//!  name: RXML-parse tag results
//
//! defvar: bindir
//! Perl helper binaries directory.
//!  type: TYPE_DIR
//!  name: Perl Helper Binaries
//
//! defvar: parallel
//! Number of scripts/tags that may be evaluated in parallel. Don't set this higher than necessary, since it may cause the server to block. The default for this setting is 2.
//!  type: TYPE_MULTIPLE_INT
//!  name: Parallel scripts
//
//! defvar: identity
//! User and group to run Perl scripts and tags as. The default for this option is `nobody:*'. Note that Caudium can't change user ID unless it has sufficient permissions to do so. `*' means `use same as Caudium'.
//!  type: TYPE_STRING
//!  name: Run Perl as...
//
