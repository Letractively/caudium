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

/* Standard includes */

#include <module.h>
inherit "module";
inherit "caudiumlib";

static Filesystem.Tar tarfs;
static int req_files, req_dirs, req_stats;

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)


//! module: Tar Filesystem
//!  This module allows you to mount an uncompressed tar file as a virtual
//!  filesystem. You simply specify the path to the tar file you want to read,
//!  the mount point and optionally the base directory (if you only want part
//!  of the tar file to be accessible).
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOCATION
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";

constant thread_safe=1;	// Should be
constant module_type = MODULE_LOCATION;
constant module_name = "Tar Filesystem";
constant module_doc  =
#"This module allows you to mount an uncompressed tar file as a virtual 
filesystem. You simply specify the path to the tar file you want to read, 
the mount point and optionally the base directory (if you only want part 
of the tar file to be accessible).";

constant module_unique = 0;

void create () {
    defvar( "mountpoint", "/", "Filesystem mountpoint", TYPE_STRING,
	    "This is the location in the virtual file system where this "
	    "module will be mounted." );
    defvar( "tarfile", "PATH TO TAR FILE", "Tar file path", TYPE_FILE,
	    "The path to the tar file you want the module to serve "
	    "files from.");
    defvar( "basepath", "/", "Base directory", TYPE_STRING,
	    "Directory to be prepended to all requests to this file system "
	    "prior to accessing the tar file. This can be used to limit "
	    "access to a certain part of the tar file. Please note that this "
	    "variable has to begin with a / or no files will be found.");
}

/* The actual file system. If zero, no or an invalid tar file is specified. */
void start (int cnt, object conf) {
  if(QUERY(tarfile) == "PATH TO TAR FILE")
    return;
  catch {
    tarfs = Filesystem.Tar(QUERY(tarfile));
  };
  if(!tarfs) {
    report_error("Tar filesystem: failed to open specified tar file.\n");
    return;
  }
  if(!(tarfs = tarfs->cd(QUERY(basepath)))) {
    report_error("Tar filesystem: invalid base directory specified.\n");
    return;
  }
}
#define S(x) (x == 1 ? "" : "s")
string status() {
  if(!tarfs) return "No tar file currently loaded.";
  return sprintf("There have been %d file request%s, %d directory request%s "
		 "and %d file stats since the last reload.",
		 req_files, S(req_files),
		 req_dirs, S(req_dirs),
		 req_stats, S(req_stats));
  
}

string query_location () {
  return QUERY(mountpoint);
}

class WrapperFile
{
  static private int pos, len;
  static object my_fd;
  
  string read(int|void n)
  {
    if(!query_num_arg() || n>len-pos)
      n = len-pos;
    pos += n;
    return my_fd->read(n);
  }
  
  void create(string file, int start, int _len)
  {
    my_fd = Stdio.File(file, "r");
    my_fd->seek(start);
    len = _len;
  }
  void set_nonblocking() { return 0; };
  void set_blocking() { return 0; };
  void stat() { return 0; };
}


mixed find_file ( string path, object id )
{
  // We need to reopen the file for each request to avoid having to load
  // the entire file into memory before processing it. We also use a wrapper
  // so that the resulting file can be handled correctly on an extension basis.
  WrapperFile newfd;
  object fd, fdstat;

  req_files++;
  TRACE_ENTER("tarfs: find_file(\""+path+"\")", 0);
  if(!tarfs) {
    TRACE_LEAVE("no tar file loaded");
    return 0;
  }
  if(strlen(path) == 0) path = "."; // If path empty, set to current dir
  if(!(fdstat = tarfs->stat(path))) {
    TRACE_LEAVE("no such file or directory");
    return 0;
  }
  switch(id->method)
  {
   case "GET":
   case "HEAD":
   case "POST":
    if(fdstat->isdir()) {
      TRACE_LEAVE("is a directory");
      return -1; 
    }
    
    if(!fdstat->isreg()) {
      TRACE_LEAVE("not a regular file");
      return 0;
    }
    if(!fdstat->size) {
      TRACE_LEAVE("empty file");
      return 0;
    }
  
    if(path[ -1 ] == '/') {
      TRACE_LEAVE("trying to access a file with '/' appended");
      return 0;
    }
    fd = tarfs->open(path, "r");
    if(!fd) {
      TRACE_LEAVE("open failed");
      return 0;
    }
    newfd = WrapperFile(QUERY(tarfile), fd->tell(), fdstat->size);
    id->misc->stat = ({
      fdstat->mode,
      fdstat->size,
      fdstat->atime, 
      fdstat->mtime, 
      fdstat->ctime,
      fdstat->uid,
      fdstat->gid,
    });
      
    TRACE_LEAVE("");
    return newfd;
    
   default:
    TRACE_LEAVE("unsupported method ");
    return 0;
  }
}

void|array find_dir ( string path, object id ) {
  req_dirs++;
  TRACE_ENTER("tarfs: find_dir(\""+path+"\")", 0);
  if(!tarfs) {
    TRACE_LEAVE("no tar file loaded");
    return 0;
  }
  if(!strlen(path)) path = "./";
  array res = tarfs->get_dir(path);
  if(!res) {
    TRACE_LEAVE("failed");
    return 0;
  }
  for(int i = 0; i < sizeof(res); i++)
    res[i] = (res[i] / "/")[-1];
  TRACE_LEAVE("");
  return res;
}


void|string real_file ( string path, object id ) {
    return 0;
}

void|array stat_file( string path, object id )
{
  req_stats++;
  TRACE_ENTER("tarfs: stat_file(\""+path+"\")", 0);
  if(!tarfs) {
    TRACE_LEAVE("no tar file loaded");
    return 0;
  }
  object fdstat;
  if(!(fdstat = tarfs->stat(path))) {
    TRACE_LEAVE("no such file or directory");
    return 0;
  }
  TRACE_LEAVE("");
  return ({
    fdstat->mode,
    fdstat->isdir() ? -1 : fdstat->size,
    fdstat->atime, 
    fdstat->mtime, 
    fdstat->ctime,
    fdstat->uid,
    fdstat->gid,
  });
}


string query_name()
{
  return sprintf("<i>%s</i> mounted on <i>%s</i>",
		 query("tarfile"), query("mountpoint"));
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: mountpoint
//! This is the location in the virtual file system where this module will be mounted.
//!  type: TYPE_STRING
//!  name: Filesystem mountpoint
//
//! defvar: tarfile
//! The path to the tar file you want the module to serve files from.
//!  type: TYPE_FILE
//!  name: Tar file path
//
//! defvar: basepath
//! Directory to be prepended to all requests to this file system prior to accessing the tar file. This can be used to limit access to a certain part of the tar file. Please note that this variable has to begin with a / or no files will be found.
//!  type: TYPE_STRING
//!  name: Base directory
//
