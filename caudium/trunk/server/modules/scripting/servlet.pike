/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2003 The Caudium Group
 * Copyright © 1999-2001 Roxen Internet Software
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
 */
/*
 * $Id$
 */

//
//! module: Java Servlet bridge
//!  An interface to Java <a href="http://java.sun.com/products/servlet/index.html"
//!  Servlets</a>.
//! inherits: module
//! inherits: http
//! type: MODULE_FILE_EXTENSION | MODULE_LOCATION
//! cvs_version: $Id$
//

#include <module.h>
inherit "module";
inherit "http";

constant cvs_version   = "$Id$";
constant module_type   = MODULE_LOCATION | MODULE_FILE_EXTENSION;
constant module_name   = "Java Servlet bridge";
constant module_unique = 0;
constant thread_safe   = 1;
#if constant(Java)
constant module_doc    = "An interface to Java <a href=\"http://java.sun.com/"
                         "products/servlet/index.html""\">Servlets</a>.";

object servlet;
string status_info="";

#if constant(Servlet.servlet)

void stop()
{
  if(servlet) {
    destruct(servlet);
    servlet = 0;
  }
}

static mapping(string:string) make_initparam_mapping()
{
  mapping(string:string) p = ([]);
  string n, v;
  foreach(query("parameters")/"\n", string s)
    if(2==sscanf(s, "%[^=]=%s", n, v))
      p[n]=v;
  return p;
}

void start(int x, object conf)
{
  if(x == 2)
    stop();
  else if(x != 0)
    return;

  if(query("classname")=="NONE") {
    status_info = "No servlet class selected";
    return;
  }

  mixed exc = catch(servlet = Servlet.servlet(query("classname"),
					      query("codebase")-({""})));
  status_info="";
  if(exc)
  {
    report_error("Servlet: %s\n",exc[0]);
    status_info=sprintf("<pre>%s</pre>",exc[0]);
  }
  else
  {
    if(servlet)
      exc= catch(servlet->init(Servlet.conf_context(conf), make_initparam_mapping()));
    if(exc)
    {
      report_error("Servlet: %s\n", exc[0]);
      status_info=sprintf("<pre>%s</pre>",exc[0]);
    }
  }
}

string status()
{
  return (servlet?
	  servlet->info() || "<i>No servlet information available</i>" :
	  "<font color=red>Servlet not loaded</font>"+"<br>"+
	  status_info);
}

string query_name()
{
  if(query("ex"))
    return sprintf("Servlet %s handling extension %s",
		   query("classname"), query("ext")*", ");
  else
    return sprintf("Servlet %s mounted on %s",
		   query("classname"), query("location"));
}

class RXMLParseWrapper
{
  static object _file;
  static object _id;
  static string _data;

  int write(string data)
  {
    _data += data;
    return strlen(data);
  }

  int close(void|string how)
  {
    _file->write(parse_rxml(_data,_id));
    _data="";
    return _file->close(how);
  }

  mixed `->(string n)
  {
    return ::`->(n) || predef::`->(_file, n);
  }

  void create(object file, object id)
  {
    _file = file;
    _id = id;
    _data = "";
  }
}

mixed find_file( string f, object id )
{
  if(!servlet || query("ex"))
    return 0;

  if(id->my_fd == 0 && id->misc->trace_enter)
    ; /* In "Resolve path...", kluge to avoid backtrace. */
  else {
    id->my_fd->set_read_callback(0);
    id->my_fd->set_close_callback(0);
    id->my_fd->set_blocking();
    id->misc->servlet_path = query("location");
    id->misc->path_info = f;
    id->misc->mountpoint = "";
    if(query("rxml"))
      id->my_fd = RXMLParseWrapper(id->my_fd, id);
    servlet->service(id);
  }

  return http_pipe_in_progress();
}

mixed handle_file_extension(object o, string e, object id)
{
  if(!servlet || !query("ex"))
    return 0;
  
  if(id->my_fd == 0 && id->misc->trace_enter)
    ; /* In "Resolve path...", kluge to avoid backtrace. */
  else {
    id->my_fd->set_read_callback(0);
    id->my_fd->set_close_callback(0);
    id->my_fd->set_blocking();
    id->misc->path_info = id->not_query;
    id->misc->mountpoint = "/";
    if(query("rxml"))
      id->my_fd = RXMLParseWrapper(id->my_fd, id);
    servlet->service(id);
  }

  return http_pipe_in_progress();
}

#else

// Do not dump to a .o file if no Java is available, since it will then
// not be possible to get it later on without removal of the .o file.
constant dont_dump_program = 1; 

string status()
{
  return 
#"<font color='red'>Java 2 is not available in this Caudium.<p>
  To get Java 2:
  <ol>
    <li> Download and install Java
    <li> Restart Caudium
  </ol></font>";
}

mixed find_file( string f, object id )
{
  return http_string_answer( status(), "text/html" );
}

int|mapping handle_file_extension(object o, string e, object id)
{
  return http_string_answer( status(), "text/html" );
}


#endif

string|void check_value( string s, string|array(string) value )
{
  if(s=="codebase")
  {  
    if(stringp(value))
      value = ({ value });
    string warn = "";
    foreach( value-({""}), string val ) 
    {
      array s = (array)predef::file_stat( val );
      Stdio.File f = Stdio.File();
      if( !s )
        warn += val+" does not exist\n";
      else if( s[ 1 ] == -2 )
	;
      else if( !(f->open( val, "r" )) )
        warn += "Can't read "+val+"\n";
      else 
      {
	if( f->read(2) != "PK" )
	  warn += val+" is not a JAR file\n";
	f->close();
      }
    }
    if( strlen( warn ) )
      return (warn);
    return;
  }
}

array(string) query_file_extensions()
{
  return (query("ex")? query("ext") : ({}));
}

void create()
{
  defvar("ex", 0, "File extension servlet", TYPE_FLAG,
	 "Use a servlet mapping based on file extension rather than "
	 "path location.");

  defvar("location", "/servlet/NONE", "Servlet location", TYPE_LOCATION,
	 "This is where the servlet will be inserted in the "
	 "namespace of your server.", 0,
	 lambda() { return query("ex"); });

  defvar("ext", ({}), "Servlet extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be handled by "+
	 "this servlet.", 0,
	 lambda() { return !query("ex"); });
  
  defvar("codebase", ({"servlets"}), "Class path", TYPE_FILE_LIST,
				    "Any number of directories and/or JAR "
				    "files from which to load the servlet "
				    "and its support classes." );
  
  defvar("classname", "NONE", "Class name", TYPE_STRING,
	 "The name of the servlet class to use.");

  defvar("parameters", "", "Parameters", TYPE_TEXT,
	 "Parameters for the servlet on the form "
	 "<tt><i>name</i>=<i>value</i></tt>, one per line.");

  defvar("rxml", 0, "Parse RXML in servlet output", TYPE_FLAG|VAR_MORE,
	 "If this is set, the output from the servlet handled by this "
         "module will be RXML parsed. NOTE: No data will be returned to the "
         "client until the output is fully parsed.");
}

#else /* constant(Java)
constant module_doc  = "An interface to Java <a href=\"http://java.sun.com/"
                       "products/servlet/index.html""\">Servlets</a>."
                       "<br/><b>Your system is lacking for Java support in "
                       "in Pike. Please check you have correctly installed "
                       "Java support for your running pike.";
#endif

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: ex
//! Use a servlet mapping based on file extension rather than path location.
//!  type: TYPE_FLAG
//!  name: File extension servlet
//
//! defvar: location
//! This is where the servlet will be inserted in the namespace of your server.
//!  type: TYPE_LOCATION
//!  name: Servlet location
//
//! defvar: ext
//! All files ending with these extensions, will be handled by 
//!  type: TYPE_STRING_LIST
//!  name: Servlet extensions
//
//! defvar: codebase
//! Any number of directories and/or JAR files from which to load the servlet and its support classes.
//!  type: TYPE_FILE_LIST
//!  name: Class path
//
//! defvar: classname
//! The name of the servlet class to use.
//!  type: TYPE_STRING
//!  name: Class name
//
//! defvar: parameters
//! Parameters for the servlet on the form <tt><i>name</i>=<i>value</i></tt>, one per line.
//!  type: TYPE_TEXT
//!  name: Parameters
//
//! defvar: rxml
//! If this is set, the output from the servlet handled by this module will be RXML parsed. NOTE: No data will be returned to the client until the output is fully parsed.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Parse RXML in servlet output
//
