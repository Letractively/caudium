
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002  The Caudium Group
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
   very simple virtual hosting module.
   
   create a directory structure like:
   
     hu/
        wormhole/
                 www/
     com/
         whatever/
                  www/
   
   place files in directories as you please. set searchpath to the root of this
   tree. sit back and relax.
   
   not too heavily tested, but works for me(tm).
   
   to bertrand, with love [*grin*].
*/


#include <module.h>

inherit "module";
inherit "caudiumlib";
inherit "modules/filesystems/filesystem";

constant module_type = MODULE_LOCATION;
constant module_name = "Simple Virtual Hosting Module";
constant module_doc  = "This module adds support for simple, zero-setup "
  "virtual hosting. All you need to do is create a directory tree, point "
  "this module at it's root, sit back, relax and enjoy the finer things in "
  "life.";
constant module_unique = 1;
constant cvs_version = "$Id$";

#define FILESYSTEM_DEBUG

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)
#define FILE_SIZE(X) (Stdio.file_size(X))

array find_dir( string f, object id )
{
  mixed ret;
  array dir;
  object privs;

#ifdef FILESYSTEM_DEBUG
  roxen_perror("FILESYSTEM: Request for dir \""+f+"\"\n");
#endif /* FILESYSTEM_DEBUG */

#ifndef THREADS
  if (((int)id->misc->uid) && ((int)id->misc->gid) &&
      (QUERY(access_as_user))) {
    // NB: Root-access is prevented.
    privs=Privs("Getting dir", (int)id->misc->uid, (int)id->misc->gid );
  }
#endif

  if(!(dir = get_dir( path + f ))) {
    privs = 0;
    return 0;
  }
  privs = 0;

  if (QUERY(no_symlinks) && contains_symlinks(path, f))
  {
     errors++;
     return 0;
  }

  if(!QUERY(dir))
    // Access to this dir is allowed.
    if(search(dir, ".www_browsable") == -1)
    {
      errors++;
      return 0;
    }

  // Access to this dir is not allowed.
  if(sizeof(dir & ({".nodiraccess",".www_not_browsable",".nodir_access"})))
  {
    errors++;
    return 0;
  }

  dirlists++;

  // Pass _all_ files, hide none.
  if(QUERY(tilde) && QUERY(.files)) /* This is quite a lot faster */
    return dir;

  return Array.filter(dir, dir_filter_function);
}


mixed find_file( string f, object id )
{
  TRACE_ENTER("find_file(\""+f+"\")", 0);

  object o;
  int size, code;
  string tmp;
  string oldf = f;
  object privs;
  array|object st;

#ifdef FILESYSTEM_DEBUG
  roxen_perror("FILESYSTEM: Request for file \""+f+"\"\n");
#endif /* FILESYSTEM_DEBUG */

  f = combine_path(path, reverse(id->request_headers->host / ".") * "/", f );
#ifdef FILESYSTEM_DEBUG
  perror("SIMPLE VHOST MATCHER: f is now " + f + "\n");
#endif

  size = FILE_SIZE( f );

  /*
   * FIXME: Should probably move path-info extraction here.
   * 	/grubba 1998-08-26
   */

  switch(id->method)
  {
   case "GET":
   case "HEAD":
   case "POST":
  
    switch(-size)
    {
     case 1:
     case 3:
     case 4:
      TRACE_LEAVE("No file");
      return 0; /* Is no-file */

     case 2:
      TRACE_LEAVE("Is directory");
      return -1; /* Is dir */

     default:
      if(f[ -1 ] == '/') /* Trying to access file with '/' appended */
      {
	/* Neotron was here. I changed this to always return 0 since
	 * CGI-scripts with path info = / won't work otherwise. If
	 * someone accesses a file with "/" appended, a 404 no such
	 * file isn't that weird. Both Apache and Netscape return the
	 * accessed page, resulting in incorrect links from that page.
	 *
	 * FIXME: The proper way to do this would probably be to set path info
	 *   here, and have the redirect be done by the extension modules,
	 *   or by the protocol module if there isn't any extension module.
	 *	/grubba 1998-08-26
	 */
	return 0; 
      }

      if(!id->misc->internal_get && !QUERY(.files)
	 && (tmp = (id->not_query/"/")[-1])
	 && tmp[0] == '.') {
	TRACE_LEAVE("Is .-file");
	return 0;
      }
#ifndef THREADS
      if (((int)id->misc->uid) && ((int)id->misc->gid) &&
	  (QUERY(access_as_user))) {
	// NB: Root-access is prevented.
	privs=Privs("Getting file", (int)id->misc->uid, (int)id->misc->gid );
      }
#endif

      TRACE_ENTER("Opening file \"" + f + "\"", 0);
      o = open( f, "r" );

#ifndef THREADS
      privs = 0;
#endif

      if(!o || (QUERY(no_symlinks) && (contains_symlinks(path, oldf))))
      {
         errors++;
         report_error("Open of " + f + " failed. Permission denied.\n");

         TRACE_LEAVE("");
         TRACE_LEAVE("Permission denied.");
         return (http_error_answer (id, 403, 0, 
                  "File exists, but access forbidden by user"));
      }

      id->realfile = f;
      TRACE_LEAVE("");
      accesses++;
#ifdef COMPAT
      if(QUERY(html)) {/* Not very likely, really.. */
	TRACE_LEAVE("Compat return");
	return ([ "type":"text/html", "file":o, ]);
      }
#endif
      TRACE_LEAVE("Normal return");
      return o;
    }
    break;
  
   case "MKDIR":
    if(!QUERY(method_mkdir))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MKDIR disallowed (method disabled)");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MKDIR: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'MKDIR' denied</h1>");
    }
    mkdirs++;

    if (((int)id->misc->uid) && ((int)id->misc->gid) &&
	(QUERY(access_as_user))) {
      // NB: Root-access is prevented.
      privs=Privs("Creating directory",
		  (int)id->misc->uid, (int)id->misc->gid );
    }

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error("Creation of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("MKDIR: Contains symlinks. Permission denied");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    TRACE_ENTER("MKDIR: Accepted", 0);

    int code = mkdir( f );

    privs = 0;
    if (code) {
      chmod(f, dirperm & ~(id->misc->umask || default_umask));
      TRACE_LEAVE("MKDIR: Success");
      TRACE_LEAVE("Success");
      return http_string_answer("Ok");
    } else {
      TRACE_LEAVE("MKDIR: Failed");
      TRACE_LEAVE("Failure");
      return 0;
    }

    break;

   case "PUT":
    if(!QUERY(put))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("PUT disallowed");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("PUT: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'PUT' files denied</h1>");
    }
    puts++;
    

    if (((int)id->misc->uid) && ((int)id->misc->gid) &&
	(QUERY(access_as_user))) {
      // NB: Root-access is prevented.
      privs=Privs("Saving file", (int)id->misc->uid, (int)id->misc->gid );
    }

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error("Creation of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("PUT: Contains symlinks. Permission denied");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    TRACE_ENTER("PUT: Accepted", 0);
    if(QUERY(keep_old_perms))
      st = file_stat(f);
    rm( f );
    Stdio.mkdirhier( dirname(f) );
    
    object to = open(f, "wct");
    
    privs = 0;

    if(!to)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("PUT: Open failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    /* Set permission or use the previous permissions */
    if(st) chmod(f, st[0]);
    else   chmod(f, fileperm & ~(id->misc->umask || default_umask));
    putting[id->my_fd]=id->misc->len;
    if(id->data && strlen(id->data))
    {
      putting[id->my_fd] -= strlen(id->data);
      to->write( id->data );
    }
    if(!putting[id->my_fd]) {
      TRACE_LEAVE("PUT: Just a string");
      TRACE_LEAVE("Put: Success");
      return http_string_answer("Ok");
    }

    if(id->clientprot == "HTTP/1.1") {
      id->my_fd->write("HTTP/1.1 100 Continue\r\n\r\n");
    }
    id->my_fd->set_id( ({ to, id->my_fd }) );
    id->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    TRACE_LEAVE("PUT: Pipe in progress");
    TRACE_LEAVE("PUT: Success so far");
    return http_pipe_in_progress();
    break;

  case "APPE":
    if(!QUERY(put)&&!QUERY(appe))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("APPE disallowed");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("APPE: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'APPE' files denied</h1>");
    }
    appes++;
    
    object privs;

// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid) &&
      (QUERY(access_as_user))) {
      // NB: Root-access is prevented.
      privs=Privs("Saving file", (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error("Creation of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("PUT: Contains symlinks. Permission denied");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    TRACE_ENTER("APPE: Accepted", 0);

    Stdio.mkdirhier( f );

    to = open(f, "arw");
    
    privs = 0;

    if(!to)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE(sprintf("APPE: Open (%s, wa) failed",f));
      TRACE_LEAVE("Failure");
      return 0;
    }
    chmod(f, 0666 & ~(id->misc->umask || 022));
    putting[id->my_fd]=id->misc->len;
    if(id->data && strlen(id->data))
    {
      putting[id->my_fd] -= strlen(id->data);
      to->write( id->data );
    }
    if(!putting[id->my_fd]) {
      TRACE_LEAVE("PUT: Just a string");
      TRACE_LEAVE("Put: Success");
      return http_string_answer("Ok");
    }

    if(id->clientprot == "HTTP/1.1") {
      id->my_fd->write("HTTP/1.1 100 Continue\r\n");
    }
    id->my_fd->set_id( ({ to, id }) );
    id->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    TRACE_LEAVE("APPE: Pipe in progress");
    TRACE_LEAVE("APPE: Success so far");
    return http_pipe_in_progress();
    break;

   case "CHMOD":
    // Change permission of a file. 
    
    if(!QUERY(method_chmod))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("CHMOD disallowed");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("CHMOD: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'CHMOD' files denied</h1>");
    }
    
    // #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("CHMODing file", (int)id->misc->uid, (int)id->misc->gid );
    }
    // #endif
    
    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("CHMOD: Contains symlinks. Permission denied");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    chmods++;

    TRACE_ENTER("CHMOD: Accepted", 0);

#ifdef DEBUG
    report_notice(sprintf("CHMODing file "+f+" to 0%o\n", id->misc->mode));
#endif
    array err = catch(chmod(f, id->misc->mode & 0777));
    privs = 0;
    
    if(err)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("CHMOD: Failure");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("CHMOD: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");
    
   case "MV":
    // This little kluge is used by ftp2 to move files. 
    
    if(!QUERY(method_mv))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed");
      return 0;
    }    
    if(!QUERY(delete) && size != -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed (DELE disabled, can't overwrite file)");
      return 0;
    }

    if(size < -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV: Cannot overwrite directory");
      return 0;
    }

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MV: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'MV' files denied</h1>");
    }
    string movefrom;
    if(!id->misc->move_from ||
       !(movefrom = id->conf->real_file(id->misc->move_from, id))) {
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MV: No source file");
      return 0;
    }
    moves++;
    
    // #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Moving file", (int)id->misc->uid, (int)id->misc->gid );
    }
    // #endif
    
    if (QUERY(no_symlinks) &&
	((contains_symlinks(path, oldf)) ||
	 (contains_symlinks(path, id->misc->move_from)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MV: Contains symlinks. Permission denied");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    TRACE_ENTER("MV: Accepted", 0);

    /* Clear the stat-cache for this file */

#ifdef DEBUG
    report_notice("Moving file "+movefrom+" to "+ f+"\n");
#endif /* DEBUG */

    code = mv(movefrom, f);
    privs = 0;

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MV: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MV: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");

   case "MOVE":
    // This little kluge is used by NETSCAPE 4.5
     
    if(!QUERY(method_mv))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE disallowed");
      return 0;
    }    
    if(size == -1)
    {
      id->misc->error_code = 404;
      TRACE_LEAVE("MOVE failed (no such file)");
      return 0;
    }

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MOVE: Permission denied");
      return http_auth_required("foo",
                                "<h1>Permission to 'MOVE' files denied</h1>");
    }

    if(!sizeof(id->misc["new-uri"] || "")) { 
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MOVE: No dest file");
      return 0;
    }
    string mountpoint = QUERY(mountpoint);
    string moveto = combine_path(mountpoint + "/" + oldf + "/..",
				 id->misc["new-uri"]);

    if (moveto[..sizeof(mountpoint)-1] != mountpoint) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE: Dest file on other filesystem.");
      return(0);
    }
    moveto = path + moveto[sizeof(mountpoint)..];

    size = FILE_SIZE(moveto);

    if(!QUERY(delete) && size != -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE disallowed (DELE disabled, can't overwrite file)");
      return 0;
    }
 
    if(size < -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE: Cannot overwrite directory");
      return 0;
    }

    // #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Moving file", (int)id->misc->uid, (int)id->misc->gid );
    }
    // #endif

    if (QUERY(no_symlinks) &&
        ((contains_symlinks(path, f)) ||
         (contains_symlinks(path, moveto)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MOVE: Contains symlinks. Permission denied");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    TRACE_ENTER("MOVE: Accepted", 0);

    moves++;

    /* Clear the stat-cache for this file */
#ifdef DEBUG
    report_notice("Moving file " + f + " to " + moveto + "\n");
#endif /* DEBUG */

    code = mv(f, moveto);

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MOVE: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MOVE: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");

   case "COPY":
    if(!QUERY(copy) )
	return http_error_answer(id, 405, "Copy disallowed");
    id->misc->destination = path + id->misc->destination;
    size = FILE_SIZE(id->misc->destination);
    if ( size != -1 && id->misc->overwrite != "T" )
	return http_error_answer(id, 403, "Forbidden");
    if(QUERY(check_auth) && (!id->auth || !id->auth[0]))
	return http_auth_required("copy", "Permission to 'COPY' files denied");
    if(QUERY(no_symlinks) && 
       (contains_symlinks(path, f) || 
	contains_symlinks(path,id->misc->destination)))
	return http_error_answer(id, 403, "Forbidden");
    if ( !stringp(id->misc->destination) ) 
	return http_error_answer(id, 403, "No destination");
	
    accesses++;
    report_notice("COPYING the file "+f+" to " + id->misc->destination + "\n");
    if ( ((int)id->misc->uid) && ((int)id->misc->gid) ) 
	privs = Privs("Copying file", (int)id->misc->uid,(int) id->misc->gid);
    if ( f == id->misc->destination || !Stdio.cp(f, id->misc->destination) ) {
	privs = 0;
	return http_error_answer(id, 403, "Forbidden");
    }
    privs = 0;
    TRACE_LEAVE("COPY: Success");
    return http_error_answer(id, 201, "Created"); // hmm, error answer ?
    break;
	
   case "DELETE":
    if(!QUERY(delete) || size==-1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Disabled");
      return 0;
    }
    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("DELETE: Permission denied");
      return (http_error_answer (id, 403, 0, "Permission to DELETE file denied"));
    }

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      errors++;
      report_error("Deletion of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("DELETE: Contains symlinks");
      return (http_error_answer (id, 403, 0, "Permission denied."));
    }

    report_notice("DELETING the file "+f+"\n");
    accesses++;

    if (((int)id->misc->uid) && ((int)id->misc->gid) &&
	(QUERY(access_as_user))) {
      // NB: Root-access is prevented.
      privs=Privs("Deleting file", id->misc->uid, id->misc->gid );
    }

    /* Clear the stat-cache for this file */

    if(!rm(f))
    {
      privs = 0;
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Failed");
      return 0;
    }
    privs = 0;
    deletes++;
    TRACE_LEAVE("DELETE: Success");
    return http_low_answer(200,(f+" DELETED from the server"));

   default:
    TRACE_LEAVE("Not supported");
    return 0;
  }
  report_error("Not reached..\n");
  TRACE_LEAVE("Not reached");
  return 0;
}

  
