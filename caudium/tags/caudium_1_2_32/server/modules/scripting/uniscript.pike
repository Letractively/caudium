/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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

#include <module.h>
inherit "modules/scripting/cgi.pike";

//! module: Universal script parser
//!  This module provides extensions handling by misc script interpreters. 
//!  Scripts can be run as choosen user, or by owner. Module is based on
//!  CGI module.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FILE_EXTENSION
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";

constant module_type = MODULE_FILE_EXTENSION|MODULE_EXPERIMENTAL;
constant module_name = "Universal script parser";
constant module_doc  = "This module provides extensions handling by misc script interpreters. "
			"Scripts can be run as choosen user, or by owner. Module is based on "
			"CGI module.";
constant module_unique = 0;

#ifdef CGI_DEBUG
#define DWERROR(X)      report_debug(X)
#else /* !CGI_DEBUG */
#define DWERROR(X)
#endif /* CGI_DEBUG */

class CGIScript
{
  string command;
  array (string) arguments;
  Stdio.File stdin;
  Stdio.File stdout;
  // stderr is handled by run().
  mapping (string:string) environment;
  int blocking;

  string priority;   // generic priority
  object|int pid;       // the process id of the CGI script
  string tosend;   // data from the client to the script.
  Stdio.File ffd; // pipe from the client to the script
  object mid;

  mapping (string:int)    limits;
  int uid, gid;  
  array(int) extra_gids;

  void check_pid()
  {
    DWERROR("CGI:CGIScript::check_pid()\n");

    if(!pid || (objectp(pid) && pid->status()))
    {
      remove_call_out(kill_script);
      destruct();
      return;
    }
    call_out( check_pid, 0.1 );
  }

  Stdio.File get_fd()
  {
    DWERROR("CGI:CGIScript::get_fd()\n");

    // Send input to script..
    if(tosend)
      sendfile(tosend, stdin, lambda(int i,mixed q){ stdin=0; });
    else
    {
      stdin->close();
      stdin=0;
    }

    // And then read the output.
    if(!blocking)
    {
      Stdio.File fd = stdout;
      if( (command/"/")[-1][0..2] != "nph" )
        fd = CGIWrapper( fd,mid,kill_script )->get_fd();
      if( QUERY(rxml) )
        fd = RXMLWrapper( fd,mid,kill_script )->get_fd();
      stdout = 0;
      call_out( check_pid, 0.1 );
      return fd;
    }
    //
    // Blocking (<insert file=foo.cgi> and <!--#exec cgi=..>)
    // Quick'n'dirty version.
    // 
    // This will not be parsed. At all. And why is this not a problem?
    //   o <insert file=...> dicards all headers.
    //   o <insert file=...> does RXML parsing on it's own (automatically)
    //   o The user probably does not want the .cgi rxml-parsed twice, 
    //     even though that's the correct solution to the problem (and rather 
    //     easy to add, as well)
    //
    remove_call_out( kill_script );
    return stdout;
  }

  // HUP, PIPE, INT, TERM, KILL
  static constant kill_signals = ({ signum("HUP"), signum("PIPE"),
				    signum("INT"), signum("TERM"),
				    signum("KILL") });
  static constant kill_interval = 3;
  static int next_kill;

  void kill_script()
  {
    DWERROR(sprintf("CGI:CGIScript::kill_script()\n"
		    "next_kill: %d\n", next_kill));

    if(pid && !pid->status())
    {
      int signum = 9;
      if (next_kill < sizeof(kill_signals)) {
	signum = kill_signals[next_kill++];
      }
      if(pid->kill)  // Pike 0.7, for roxen 1.4 and later 
        pid->kill( signum );
      else
        kill( pid->pid(), signum); // Pike 0.6, for roxen 1.3 
      call_out(kill_script, kill_interval);
    }
  }

  CGIScript run()
  {
    DWERROR("CGI:CGIScript::run()\n");

    string interpreter = "";

    Stdio.File t, stderr;
    stdin  = Stdio.File();
    stdout = Stdio.File();
    switch( QUERY(stderr) )
    {
     case "main log file":
       stderr = Stdio.stderr;
       break;
     case "custom log file":
       stderr = open_log_file( query( "cgilog" ) );
       break;
     case "browser":
       stderr = stdout;
       break;
    }

    mapping options = ([
      "stdin":stdin,
      "stdout":(t=stdout->pipe()), /* Stdio.PROP_IPC| Stdio.PROP_NONBLOCKING */
      "stderr":(stderr==stdout?t:stderr),
      "cwd":dirname( command ),
      "env":environment,
      "noinitgroups":1,
    ]);
    stdin = stdin->pipe(); /* Stdio.PROP_IPC | Stdio.PROP_NONBLOCKING */

    if(!getuid())
    {
      if (uid >= 0) {
	options->uid = uid;
      } else {
	// Some OS's (HPUX) have negative uids in /etc/passwd,
	// but don't like them in setuid() et al.
	// Remap them to the old 16bit uids.
	options->uid = 0xffff & uid;
	
	if (options->uid <= 10) {
	  // Paranoia
	  options->uid = 65534;
	}
      }
      if (gid >= 0) {
	options->gid = gid;
      } else {
	// Some OS's (HPUX) have negative gids in /etc/passwd,
	// but don't like them in setgid() et al.
	// Remap them to the old 16bit gids.
	options->gid = 0xffff & gid;
	
	if (options->gid <= 10) {
	  // Paranoia
	  options->gid = 65534;
	}
      }
      options->setgroups = extra_gids;
      if( !uid && QUERY(warn_root_cgi) )
        report_warning( "CGI: Running "+command+" as root (as per request)" );
    }
    if(QUERY(nice))
    {
      m_delete(options, "priority");
      options->nice = QUERY(nice);
    }
    if( limits )
      options->rlimit = limits;

    interpreter = QUERY(interpreter);

    DWERROR(sprintf("%O\n%O\n%O\n", ({ interpreter, command }), arguments, options));

    Process.create_process( ({ interpreter, command }) + arguments, options );

//    if(!(pid = Process.create_process( ({ interpreter, command }) + arguments, options ))) 
//      error("Failed to create CGI process.\n");
//
//    DWERROR(sprintf("%O\n", indices(pid)));
//
//    if(QUERY(kill_call_out))
//      call_out( kill_script, QUERY(kill_call_out)*60 );
    return this_object();
  }


  void create( object id )
  {
    DWERROR("CGI:CGIScript()\n");

    mid = id;

#ifndef THREADS
    if(id->misc->orig) // An <insert file=...> operation, and we have no threads.
      blocking = 1;
#else
    if(id->misc->orig && this_thread() == caudium.backend_thread)
      blocking = 1; 
    // An <insert file=...> and we are 
    // currently in the backend thread.
#endif
    if(!id->realfile)
    {
      id->realfile = id->conf->real_file( id->not_query, id );
      if(!id->realfile)
        error("No real file associated with "+id->not_query+
              ", thus it's not possible to run it as a CGI script.\n");
    }
    command = id->realfile;

#define LIMIT(L,X,Y,M,N) if(query(#Y)!=N){if(!L)L=([]);L->X=query(#Y)*M;}
    [uid,gid,extra_gids] = verify_access( id );
    LIMIT( limits, core, coresize, 1, -2 );
    LIMIT( limits, cpu, maxtime, 1, -2 );
    LIMIT( limits, fsize, filesize, 1, -2 );
    LIMIT( limits, nofile, open_files, 1, 0 );
    LIMIT( limits, stack, stack, 1024, -2 );
    LIMIT( limits, data, datasize, 1024, -2 );
    LIMIT( limits, map_mem, datasize, 1024, -2 );
    LIMIT( limits, mem, datasize, 1024, -2 );
    LIMIT( limits, nproc, nproc, 1, -2 );
#undef LIMIT

    if (QUERY(runowner))
    {
       array(int) statres = file_stat(id->realfile);
       if (statres[5] >= 100) uid = statres[5];
       if (statres[6] >= 100) gid = statres[5];
    }

    environment =(QUERY(env)?getenv():([]));
    environment |= global_env;
    environment |= build_env_vars( id->realfile, id, id->misc->path_info );
    if(QUERY(Enhancements))
      environment |= build_caudium_env_vars(id);
    if(id->misc->ssi_env)
      environment |= id->misc->ssi_env;
    // I assume that all scripts are internal redirected.
    // Is this good idea ? Without this PHP4 CGI version won't work
    // if(id->misc->is_redirected)
      environment["REDIRECT_STATUS"] = "1";
      environment["PATH_TRANSLATED"] = environment["SCRIPT_FILENAME"];
    if(id->rawauth && QUERY(rawauth))
      environment["HTTP_AUTHORIZATION"] = (string)id->rawauth;
    else
      m_delete(environment, "HTTP_AUTHORIZATION");
    if(QUERY(clearpass) && id->auth && id->realauth ) {
      // Already set in caudiumlib.pike
      //      environment["REMOTE_USER"] = (id->realauth/":")[0];
      environment["REMOTE_PASSWORD"] = (id->realauth/":")[1];
    } else {
      m_delete(environment, "REMOTE_PASSWORD");
    }
    if (id->rawauth) {
      environment["AUTH_TYPE"] = (id->rawauth/" ")[0];
    }

    if(environment->INDEX)
      arguments = Array.map(environment->INDEX/"+", http_decode_string);
    else
      arguments = ({});

    tosend = id->data;
    ffd = id->my_fd;
  }
}

mapping handle_file_extension(object o, string e, object id)
{
  DWERROR("CGI:handle_file_extension()\n");

  return http_stream( CGIScript( id )->run()->get_fd() );
}

void create(object conf)
{
  ::create(conf);
  killvar("rxml");

  defvar("rxml", 0, "Parse RXML in uni-scripts", TYPE_FLAG,
         "If this is set, the output from uni-scripts handled by this "
         "module will be RXML parsed. NOTE: No data will be returned to the "
         "client until the uni-script is fully parsed.",0,getuid);

  killvar("location");
  killvar("searchpath");
  killvar("ls");
  killvar("ex");
  killvar("ext");
  killvar("cgi_tag");
  killvar("noexec");

  defvar("interpreter", "/usr/bin/php3", "Interpreter path", TYPE_LOCATION, 
	 "Path to interpreter executable");

  defvar("ext", ({"php",}), "Script extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be parsed by " +
	 "given interpreter.");

  defvar("runowner", 1, "Run scripts as owner", TYPE_FLAG,
	 "If enabled, scripts are run as owner.", 0, getuid);

  defvar("nproc", 10, "Limits: Max procs", TYPE_INT,
	 "Maximum nuber of user process.");

}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: rxml
//! If this is set, the output from uni-scripts handled by this module will be RXML parsed. NOTE: No data will be returned to the client until the uni-script is fully parsed.
//!  type: TYPE_FLAG
//!  name: Parse RXML in uni-scripts
//
//! defvar: interpreter
//! Path to interpreter executable
//!  type: TYPE_LOCATION
//!  name: Interpreter path
//
//! defvar: ext
//! All files ending with these extensions, will be parsed by 
//!  type: TYPE_STRING_LIST
//!  name: Script extensions
//
//! defvar: runowner
//! If enabled, scripts are run as owner.
//!  type: TYPE_FLAG
//!  name: Run scripts as owner
//
//! defvar: nproc
//! Maximum nuber of user process.
//!  type: TYPE_INT
//!  name: Limits: Max procs
//

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */

