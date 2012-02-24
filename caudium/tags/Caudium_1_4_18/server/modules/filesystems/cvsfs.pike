/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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
//! module: CVS Filesystem
//!  This module allows you to access CVS repositories from within Caudium.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOCATION
//! cvs_version: $Id: cvsfs.pike,v 1.21 2005-01-03 17:04:45 kiwi Exp $
//
/*
 * Written by Niels M�ller 1997
 */

constant cvs_version = "$Id: cvsfs.pike,v 1.21 2005-01-03 17:04:45 kiwi Exp $";
constant thread_safe=1;

#include <module.h>
#include <caudium.h>

inherit "module";
inherit "caudiumlib";

#if constant(_static_modules)
/* New pike */
import Stdio;
import Array;
#else
#include <stdio.h>
#include <array.h>
#endif

constant module_type = MODULE_LOCATION;
constant module_name = "CVS File System";
constant module_doc  = "Accessing files under CVS control.";
constant module_unique = 0;

// #define CVSFS_DEBUG

string cvs_module_path = 0; /* Path in CVS repository */
string cvs_program, rlog_program, rcsdiff_program;

int cvs_initialized = 0;

int accesses, dirlists, errors;

string secure_path(string path)
{
  if (path && sizeof(path)) {
    string npath = ((combine_path(path, ".")/"/") - ({ "..", "" })) * "/";
    if (path[0] == '/')
      npath = "/" + npath;
#ifdef CVSFS_DEBUG
    roxen_perror(sprintf("secure_path(\"%s\") => \"%s\"\n", path, npath));
#endif /* CVSFS_DEBUG */
    return npath;
  }
  return path;
}

object|array run_cvs(string prog, string dir, int with_stderr, string ...args)
{
  object stdin = File();
  object stdout = File();
  object stderr = File();
  int id;
  object|array result;

  // report_debug("run_cvs: %s %s\n", prog, args * " "); 
  
  stdin->open("/dev/null", "r");
  if (with_stderr)
    result = ({ stdout->pipe(), stderr->pipe() });
  else
    {
      stderr->open("/dev/null", "w");
      result = stdout->pipe();
    }
  return (spawne(prog, args, (["PATH" : query("path") ]),
		 stdin, stdout, stderr, dir) > 0)
     ? result : 0;
}

mapping parse_modules_file(string modules)
{
  int i;
  array rows = map(replace(modules, "\t", " ") / "\n",
		   lambda (string row) { return (row / " ") - ({""}); } ) - ({ ({}) }) ;
// report_debug("parse_modules_file: %O\n", rows);
  return mkmapping(map(rows, lambda(array data) { return data[0]; }), rows);
}

string handle_cvs_comments_etc(string data)
{ /* This would be unnecessary if cvs co -c worked */
  int i=0;
  data = replace(data, "\\\n", " ");
  while ((i = search(data, "#", i)) != -1)
    {
      int end = search(data, "\n", i);
      if (end == -1)
	{
	  data = data[..i-1];
	  break;
	}
      else
	data = data[..i-1] + data[end..];
    }
  return data;
}
      	   
string lookup_cvs_module(string prog, string root, string module)
{
  /* cvs checkout -c is not eightbit clean. argh! */
  object f;
  string mods;

  if (! (prog && root && module))
    return 0;
  
  /* report_debug("lookup_cvs_module: prog = %O, root = %O, module=%O\n",
     prog, root, module);
     */
  f = run_cvs(prog, 0, 0, "-d", root, "checkout", "-p", "CVSROOT/modules");
  if (!f)
    return 0;

  // report_debug("Reading from cvs\n");
  mods = f->read(1000000);
  
  if (!strlen(mods))
    return 0;
  // report_debug("cvsmodules: " + mods + "\n");
  mods = handle_cvs_comments_etc(mods);
  // report_debug("cvsmodules: " + mods + "\n");
  
  array mod = parse_modules_file(mods)[module];
  
  if (!mod)
    return 0;
  // report_debug("Module: %O\n", mod);
  int index=1;
  while (mod[index][0] == '-') /* Skip flags */
    {
      if (sizeof(mod[index]) == 1)
	{ /* Stop processing options */
	  index++;
	  break;
	}
      if ( (<'d', 'i', 'o', 'e', 's', 't', 'u'>)[mod[index][1]] )
	index+=2;
      else
	index++;
    }
  return mod[index];
}

string locate_binary(array path, string name)
{
  string dir;
  Stdio.Stat info;
  foreach(path, dir)
    {
      string fname = dir + "/" + name;
      if ((info = file_stat(fname))
	  && (info[0] & 0111))
	return fname;
    }
  return 0;
}

string find_binaries(array path, array|void extra)
{
  string prog;

  cvs_program = locate_binary(path, "cvs");
  // report_debug("cvs program located as: %s\n", cvs_program || "");
  rlog_program = locate_binary(path, "rlog");
  // report_debug("rlog program located as: %s\n", rlog_program || "");
  rcsdiff_program = locate_binary(path, "rcsdiff");
  // report_debug("rcsdiff program located as: %s\n", rcsdiff_program ||"");

  if (!cvs_program)
    return "No cvs program found.";
  if (!rlog_program)
    return "No rlog program found.";
  if (!rcsdiff_program) "No rcsdiff program found.";

  if (extra)
    foreach(extra, prog)
      if (!locate_binary(path, prog))
	return ("No " + prog + " program found.");
  return 0;
}

string find_cvs_dir(string path)
{
  path = secure_path(path);
  array(string) components = path / "/";
  string subpath = components[1..] * "/";
  if (strlen(components[0])) {
    // report_debug("Looking for cvs submodule.\n");
    string name =
      lookup_cvs_module(cvs_program, query("cvsroot"),
			components[0] );
    // report_debug("components = %O\n", components);
    if (! (name && strlen(name) ))
      return "Module not found in CVS";
    if (!file_stat(query("cvsroot") + name))
      return "No such subdirectory"; 
    cvs_module_path = combine_path(name, subpath);
  } else {
    if (!file_stat(combine_path(query("cvsroot"), subpath)))
      return "No such directory";
    cvs_module_path = subpath;
  }
  // report_debug("Using path '%s'\n", cvs_module_path);
  return 0;
}

string query_name()
{
  return sprintf("<i>%s</i> mounted on <i>%s</i>",
		 query("cvsmodule"),
		 query("location"));
}

void create()
{
  /* defvar()'s */
  defvar("location", "/CVS", "Mount point", TYPE_LOCATION,
	 "This is where the module will be inserted in the "
	 "name space of your server.");
  defvar("cvsroot", "/usr/local/cvs",
	 "CVS repository", TYPE_DIR, "Where CVS stores its files.");
  defvar("path", "/usr/bin:/usr/local/bin:/usr/gnu/bin", "Path for locating binaries",
	 TYPE_STRING, "Colon separated list of directories to search for the cvs "
	 "and rcs binaries.");
  defvar("cvsmodule", "NONE", "CVS (sub)module", TYPE_STRING,
	 "There are two ways to specify which directory tree in\n"
	 "the repository is to be mounted:\n"
	 "<dl><dt><tt>module/subdirectory</tt></dt>\n"
	 "<dd>where <tt>module</tt> is a module "
	 "defined in the CVS repository, and <tt>subdirectory</tt> "
	 "is a (possibly empty) path to a subdirectory of the module.</dd>\n"
	 "<dt><tt>/path</tt></dt>\n"
	 "<dd>where <tt>path</tt> is the full path to a directory,\n"
	 "starting at the cvs root. I.e., the module database\n"
	 "in the CVS repository is not used.</dd></dl>\n");
}

#if !constant(_static_modules)
string query_location() { return query("location"); }
#endif

string|void check_variable(string name, string value)
{
  string path;
  // report_debug("Trying to set '" + name + "' = '" + value + "'\n");
  switch(name)
  {
  case "cvsmodule":
  {
    if (!cvs_initialized)
      find_binaries(query("path") / ":");
    cvs_initialized = 1;
    return find_cvs_dir(value);
  }
  case "path":
    return find_binaries(value / ":",
			 ({"rcs", "co"}) );
  default:
    return 0;
  }
}
  
void start()
{
  if (!cvs_initialized)
  {
    find_binaries(query("path") / ":");
    find_cvs_dir(query("cvsmodule"));
    cvs_initialized = 1;
  }
}

string status()
{
  return "<h2> Accesses to this filesystem</h2>" +
    (accesses ? ("<b>Normal files</b>: " + (string) accesses + "<br>")
     : "No file accesses<br>") +
    (errors ? ("<b>Errors</b>: " + (string) errors + "<br>") : "") +
    (dirlists ? ("<b>Directories</b>: " + (string) dirlists + "<br>") : "");
}

mixed stat_file(string name, object id)
{
  // report_debug("file_stat: Looking for '%s'\n", name);
  // Strip .. and .
  name = secure_path(name);
  name = combine_path(query("cvsroot"), cvs_module_path + "/" + name);
  return file_stat(name + ",v") || file_stat(name);
}

mapping(string:string|int) parse_prestate(multiset|array prestates)
{
  if (multisetp(prestates)) {
    prestates = indices(prestates);
  }

  return(mkmapping(map(prestates, lambda (string s) {
    return(lower_case((s/"=")[0]));
  } ), map(prestates, lambda (string s) {
    array(string) t = s/"=";
    if (sizeof(t) > 1) {
      return(t[1..]*"=");
    } else {
      return(1);
    }
  } )));
}

object|mapping|int find_file(string name, object id)
{
  array(string) extra_args = ({});
  mapping(string:string|int) prestates = parse_prestate(id->prestate);

#ifdef CVSFS_DEBUG
  roxen_perror(sprintf("cvs->find_file: Looking for '%s'\n", name));
#endif /* CVSFS_DEBUG */

  if (cvs_module_path && sizeof(cvs_module_path)) {
    name = secure_path(name);
    string fname = combine_path(query("cvsroot"),
				cvs_module_path + "/" + name);
    int is_text = 0;

#ifdef CVSFS_DEBUG
    roxen_perror("Real file '" + fname + "'\n");
#endif /* CVSFS_DEBUG */

    if (file_stat(fname + ",v")) {
      object f;

      is_text = prestates->raw;

      if (stringp(prestates->revision)) {
	extra_args += ({ "-r"+prestates->revision });
      }

      if (prestates->log) {
	f = run_cvs(rlog_program, 0, 0,
		    @extra_args, fname + ",v" );
	is_text = 1;
      } else if (stringp(prestates->diff) &&
		 stringp(prestates->revision)) {
	
	extra_args += ({ "-r"+prestates->diff });

	f = run_cvs(rcsdiff_program, 0, 0,
		    @extra_args, fname + ",v" );
	is_text = 1;
      } else {
	f = run_cvs(cvs_program, 0, 0,
		    "-d", query("cvsroot"), "checkout", "-p",
		    @extra_args,
		    combine_path(cvs_module_path + "/" + name, "."));
      }
      if (f)
	accesses++;
      return is_text ? Caudium.HTTP.file_answer(f, "text/plain") : f;
    }
    else {
      Stdio.Stat stat = file_stat(fname + "/.");
      if (stat && (stat[1] < 0)) {
#ifdef CVSFS_DEBUG
	roxen_perror("CVS: \"" + fname + "\" is a directory.\n");
#endif /* CVSFS_DEBUG */
	return -1;
      }
    }
  }

#ifdef CVSFS_DEBUG
  roxen_perror("CVS: file \"" + name + "\" not found.\n");
#endif /* CVSFS_DEBUG */
  return 0;
}

string try_get_file(string name, object id)
{
  object|string|int res = find_file(name, id);
  if (objectp(res))
    return res->read();
  else if (stringp(res))
    return res;
  else return 0;
}

array find_dir(string name, object id)
{
  Stdio.Stat info;
  string fname = combine_path(query("cvsroot"),
			      cvs_module_path + "/" + secure_path(name));
  // report_debug("find_dir: Looking for '%s'\n", name);

  if (cvs_module_path
      && (info = file_stat(fname))
      && (info[1] == -2))
    {
      array dir = get_dir(fname);
      if (dir)
	dir = map(dir, lambda(string entry) {
	  return (entry[strlen(entry)-2..] == ",v")
	    ? entry[..strlen(entry)-3] : entry;
	});
      return dir - ({ "Attic" });
    }
  return 0;
}
	  
  

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: location
//! This is where the module will be inserted in the name space of your server.
//!  type: TYPE_LOCATION
//!  name: Mount point
//
//! defvar: cvsroot
//! Where CVS stores its files.
//!  type: TYPE_DIR
//!  name: CVS repository
//
//! defvar: path
//! Colon separated list of directories to search for the cvs and rcs binaries.
//!  type: TYPE_STRING
//!  name: Path for locating binaries
//
//! defvar: cvsmodule
//! There are two ways to specify which directory tree in
//!the repository is to be mounted:
//!<dl><dt><tt>module/subdirectory</tt></dt>
//!<dd>where <tt>module</tt> is a module defined in the CVS repository, and <tt>subdirectory</tt> is a (possibly empty) path to a subdirectory of the module.</dd>
//!<dt><tt>/path</tt></dt>
//!<dd>where <tt>path</tt> is the full path to a directory,
//!starting at the cvs root. I.e., the module database
//!in the CVS repository is not used.</dd></dl>
//!
//!  type: TYPE_STRING
//!  name: CVS (sub)module
//
