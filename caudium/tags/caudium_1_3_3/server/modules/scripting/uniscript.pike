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

#include <caudium.h>
#include <module.h>
inherit "module";
inherit "caudiumlib";

//! module: Universal script parser
//!  This module provides extensions handling by misc script interpreters. 
//!  Scripts can be run as choosen user, or by owner. Module is based on
//!  CGI module.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOCATION | MODULE_FILE_EXTENSION | MODULE_PARSER
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";

constant module_type = MODULE_FILE_EXTENSION;
constant module_name = "Universal script parser";
constant module_doc  = "This module provides extensions handling by misc script interpreters. "
			"Scripts can be run as choosen user, or by owner. Module is based on "
			"CGI module.";
constant module_unique = 0;

void sendfile( string data, object tofd, function done )
{
  object pipe = Caudium.nbio();
  pipe->write(data);
  pipe->set_done_callback(done, pipe);
  pipe->output(tofd);
}

Stdio.File open_log_file( string logfile )
{
  mapping m = localtime(time());
  m->year += 1900;	/* Adjust for years being counted since 1900 */
  m->mon++;		/* Adjust for months being counted 0-11 */
  if(m->mon < 10) m->mon = "0"+m->mon;
  if(m->mday < 10) m->mday = "0"+m->mday;
  if(m->hour < 10) m->hour = "0"+m->hour;
  logfile = replace(logfile,({"%d","%m","%y","%h" }),
                    ({ (string)m->mday, (string)(m->mon),
                       (string)(m->year),(string)m->hour,}));
  if(strlen(logfile))
  {
    object lf=Stdio.File( logfile, "wac");
    if(!lf) 
    {
      Stdio.mkdirhier(logfile);
      if(!(lf=Stdio.File( logfile, "wac")))
      {
        report_error("Failed to open logfile. ("+logfile+"): "
                     + strerror( errno() )+"\n");
        return 0;
      }
    }
    return lf;
  }
  return Stdio.stderr;
}

string trim( string what )
{
  sscanf(what, "%*[ \t]%s", what); what = reverse(what);
  sscanf(what, "%*[ \t]%s", what); what = reverse(what);
  return what;
}
#ifdef CGI_DEBUG
#define DWERROR(X)	report_debug(X)
#else /* !CGI_DEBUG */
#define DWERROR(X)
#endif /* CGI_DEBUG */

/*
** All this code to handle UID, GID and some other permission
** problems gracefully.
**
** Sometimes I really like single user systems like NT. :-)
**
*/
mapping pwuid_cache = ([]);
mapping cached_groups = ([]);

array get_cached_groups_for_user( int uid )
{
  if(cached_groups[ uid ] && cached_groups[ uid ][1]+3600>time(1))
    return cached_groups[ uid ][0];
  return (cached_groups[ uid ] = ({ get_groups_for_user( uid ), time(1) }))[0];
}

array lookup_user( string what )
{
  array uid;
  if(pwuid_cache[what]) return pwuid_cache[what];
  if(!strlen(what)) // Empty user, assume nobody
    what = "nobody";
  
  if((int)what)
    uid = getpwuid( (int)what );
  else
    uid = getpwnam( what );
  if(uid)
    return pwuid_cache[what] = ({ uid[2],uid[3] });
  report_warning("CGI: Failed to get user information for "+what+"\n");
  catch {
    return getpwnam("nobody")[2..3];
  };
  report_error("CGI: Failed to get user information for nobody! "
               "Assuming 65535,65535\n");
  return ({ 65535, 65535 });
}

array init_groups( int uid, int gid )
{
  if(!QUERY(setgroups))
    return ({});
  return get_cached_groups_for_user( uid )-({ gid });
}

array verify_access( object id )
{
  array us;
  if(!getuid())
  {
    if(QUERY(user) && id->misc->is_user &&
       (us = file_stat(id->misc->is_user)) &&
       (us[5] >= 10))
    {
      // Scan for symlinks
      string fname = "";
      array a, b;
      foreach(id->misc->is_user/"/", string part) 
      {
        fname += part;
        if ((fname != "")) {
          if(((!(a = file_stat(fname, 1))) || ((< -3, -4 >)[a[1]])))
          {
            // Symlink or device encountered.
            // Don't allow symlinks from directories not owned by the
            // same user as the file itself.
            // Assume that symlinks from directories owned by users 0-9
	    // are safe.
	    // Assume that top-level symlinks are safe.
            if (!a || (a[1] == -4) ||
                (b && (b[5] != us[5]) && (b[5] >= 10)) ||
                !QUERY(allow_symlinks)) {
              error(sprintf("CGI: Bad symlink or device encountered: \"%s\"\n",
			    fname));
	    }
	    /* This point is only reached if a[1] == -3.
	     * ie symlink encountered, and QUERY(allow_symlinks) == 1.
	     */

	    // Stat what the symlink points to.
	    // NB: This can be fooled if root is stupid enough to symlink
	    //     to something the user can move.
	    a = file_stat(fname);
	    if (!a || a[1] == -4) {
	      error(sprintf("CGI: Bad symlink or device encountered: \"%s\"\n",
			    fname));
	    }
          }
	  b = a;
	}
        fname += "/";
      }
      us = us[5..6];
    } 
    else if(us)
      us = us[5..6];
    else
      us = lookup_user( QUERY(runuser) );
  } else
    us = ({ getuid(), getgid() });
  return ({ us[0], us[1], init_groups( us[0], us[1] ) });
}


/* Basic wrapper.
** 
**  This program sends everything from the fd given as argument to 
**  a new filedescriptor. The other end of that FD is available by
**  calling get_fd()
** 
**  The wrappers are used to parse the data from the CGI script in
**  several different ways.
** 
**  There is a reason for the abundant FD-use, this code must support
**  the following operation operation modes:
** 
** Non parsed no header parsing:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
** 
** Parsed no header parsing:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
** 
** Non parsed:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
** 
** Parsed:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
** 
**  Right now this is handled more or less automatically by the
**  Stdio.File module and the operating system. :-)
*/

class Wrapper 
{ 
  constant name="Wrapper";
  string buffer = ""; 
  Stdio.File fromfd, tofd, tofdremote; 
  object mid;
  mixed done_cb;

  int close_when_done;
  void write_callback() 
  {
    DWERROR("CGI:Wrapper::write_callback()\n");

    if(!strlen(buffer)) 
      return;
    int nelems = tofd->write( buffer ); 

    DWERROR(sprintf("CGI:Wrapper::write_callback(): write(%O) => %d\n",
		    buffer, nelems));

    if( nelems < 0 )
      // if nelems == 0, network buffer is full. We still want to continue.
    {
      buffer="";
      done(); 
    } else {
      buffer = buffer[nelems..]; 
      if(close_when_done && !strlen(buffer))
        destroy();
    }
  }

  void read_callback( mixed id, string what )
  {
    DWERROR(sprintf("CGI:Wrapper::read_callback(%O, %O)\n", id, what));

    process( what );
  }

  void close_callback()
  {
    DWERROR("CGI:Wrapper::close_callback()\n");

    done();
  }

  void output( string what )
  {
    DWERROR(sprintf("CGI:Wrapper::output(%O)\n", what));

    if(buffer == "" )
    {
      buffer=what;
      write_callback();
    } else
      buffer += what;
  }

  void destroy()
  {
    DWERROR("CGI:Wrapper::destroy()\n");

    catch(done_cb(this_object()));
    catch(tofd->set_blocking());
    catch(fromfd->set_blocking());
    catch(tofd->close());
    catch(fromfd->close());
    tofd=fromfd=0;
  }

  object get_fd()
  {
    DWERROR("CGI:Wrapper::get_fd()\n");

    /* Get rid of the reference, so that it gets closed properly
     * if the client breaks the connection.
     */
    object fd = tofdremote;
    tofdremote=0;

    return fd;
  }
  

  void create( Stdio.File _f, object _m, mixed _done_cb )
  {
    DWERROR("CGI:Wrapper()\n");

    fromfd = _f;
    mid = _m;
    done_cb = _done_cb;
    tofdremote = Stdio.File( );
    tofd = tofdremote->pipe( );// Stdio.PROP_NONBLOCK );

    if (!tofd) {
      // FIXME: Out of fd's?
    }

    fromfd->set_nonblocking( read_callback, 0, close_callback );
    
#ifdef CGI_DEBUG
    function read_cb = class
    {
      void read_cb(mixed id, string s)
      {
	DWERROR(sprintf("CGI:Wrapper::tofd->read_cb(%O, %O)\n", id, s));
      }
      void destroy()
      {
	DWERROR(sprintf("CGI:Wrapper::tofd->read_cb Zapped from:\n"
			"%s\n", describe_backtrace(backtrace())));
      }
    }()->read_cb;
#else /* !CGI_DEBUG */
    function read_cb = lambda(){};
#endif /* CGI_DEBUG */
    catch { tofd->set_nonblocking( read_cb, write_callback, destroy ); };
  }


  // override these to get somewhat more non-trivial behaviour
  void done()
  {
    DWERROR("CGI:Wrapper::done()\n");

    if(strlen(buffer))
      close_when_done = 1;
    else
      destroy();
  }

  void process( string what )
  {
    DWERROR(sprintf("CGI:Wrapper::process(%O)\n", what));

    output( what );
  }
}

/* CGI wrapper.
**
** Simply waits until the headers has been received, then 
** parse them according to the CGI specification, and send
** them and the rest of the data to the client. After the 
** headers are received, all data is sent as soon as it's 
** received from the CGI script
*/
class CGIWrapper
{
  inherit Wrapper;
  constant name="CGIWrapper";

  string headers="";

  void done()
  {
    if(strlen(headers))
    {
      string tmphead = headers;
      headers = "";
      output( tmphead );
    }
    ::done();
  }

  string handle_headers( string headers )
  {
    DWERROR(sprintf("CGI:CGIWrapper::handle_headers(%O)\n", headers));

    string result = "", post="";
    string code = "200 OK";
    int ct_received = 0, sv_received = 0;
    foreach((headers-"\r") / "\n", string h)
    {
      string header, value;
      sscanf(h, "%s:%s", header, value);
      if(!header || !value)
      {
        // Heavy DWIM. For persons who forget about headers altogether.
        post += h+"\n";
        continue;
      }
      header = trim(header);
      value = trim(value);
      switch(lower_case( header ))
      {
       case "status":
         code = value;
         break;

       case "content-type":
         ct_received=1;
         result += header+": "+value+"\r\n";
         break;

       case "server":
         sv_received=1;
         result += header+": "+value+"\r\n";
         break;

       case "location":
         code = "302 Redirection";
         result += header+": "+value+"\r\n";
         break;

       default:
         result += header+": "+value+"\r\n";
         break;
      }
    }
    if(!sv_received)
      result += "Server: "+caudium.version()+"\r\n";
    if(!ct_received)
      result += "Content-Type: text/html\r\n";
    return "HTTP/1.0 "+code+"\r\n"+result+"\r\n"+post;
  }

  int parse_headers( )
  {
    DWERROR("CGI:CGIWrapper::parse_headers()\n");

    int pos, skip = 4;

    pos = search(headers, "\r\n\r\n");
    if(pos == -1) {
      // Check if there's a \n\n instead.
      pos = search(headers, "\n\n");
      if(pos == -1) {
	// Still haven't found the end of the headers.
	return 0;
      }
      skip = 2;
    } else {
      // Check if there's a \n\n before the \r\n\r\n.
      int pos2 = search(headers[..pos], "\n\n");
      if(pos2 != -1) {
	pos = pos2;
	skip = 2;
      }
    }

    output( handle_headers( headers[..pos-1] ) );
    output( headers[pos+skip..] );
    headers="";
    return 1;
  }

  static int mode;
  void process( string what )
  {
    DWERROR(sprintf("CGI:CGIWrapper::process(%O)\n", what));

    switch( mode )
    {
     case 0:
       headers += what;
       if(parse_headers( ))
         mode++;
       break;
     case 1:
       output( what );
    }
  }
}

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
  object pid;       // the process id of the CGI script
  string tosend;   // data from the client to the script.
  Stdio.File ffd; // pipe from the client to the script
  object mid;

  mapping (string:int)    limits;
  int uid, gid;  
  array(int) extra_gids;

  void check_pid()
  {
    DWERROR("CGI:CGIScript::check_pid()\n");

    if(!pid || pid->status())
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
      sendfile( tosend, stdin, lambda(int i,mixed q){ stdin=0;});
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

mapping(string:string) global_env = ([]);
void start(int n, object conf)
{
  DWERROR("CGI:start()\n");

  module_dependencies(conf, ({ "pathinfo" }));
  if(conf)
  {
    string tmp=conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    global_env["SERVER_NAME"]=tmp;
    global_env["SERVER_SOFTWARE"]=caudium.version();
    global_env["GATEWAY_INTERFACE"]="CGI/1.1";
    global_env["SERVER_PROTOCOL"]="HTTP/1.0";
    global_env["SERVER_URL"]=conf->query("MyWorldLocation");

    array us = ({0,0});
    foreach(query("extra_env")/"\n", tmp)
      if(sscanf(tmp, "%s=%s", us[0], us[1])==2)
        global_env[us[0]] = us[1];
  }
}

array stat_file( string f, object id )
{
  DWERROR("CGI:stat_file()\n");

  return file_stat( real_file( f, id ) );
}

string real_file( string f, object id )
{
  DWERROR("CGI:real_file()\n");

  return combine_path( QUERY(searchpath), f );
}

mapping handle_file_extension(object o, string e, object id)
{
  DWERROR("CGI:handle_file_extension()\n");

  return http_stream( CGIScript( id )->run()->get_fd() );
}

/*
** Variables et. al.
*/
array (string) query_file_extensions()
{
  return QUERY(ext);
}

int run_as_user_enabled() { return (getuid() || !QUERY(user)); }
void create(object conf)
{
  defvar("env", 0, "Pass environment variables", TYPE_FLAG|VAR_MORE,
	 "If this is set, all environment variables caudium has will be "
         "passed to CGI scripts, not only those defined in the CGI/1.1 standard. "
         "This includes PATH. (For a quick test, try this script with "
	 "and without this variable set:"
	 "<pre>"
	 "#!/bin/sh<br><br>"
         "echo Content-type: text/plain<br>"
	 "echo ''<br>"
	 "env<br>"
	 "</pre>");

  defvar("extra_env", "", "Extra environment variables", TYPE_TEXT_FIELD|VAR_MORE,
	 "Extra variables to be sent to the script, format:<pre>"
	 "NAME=value\n"
	 "NAME=value\n"
	 "</pre>Please note that normal CGI variables will override these.");

  defvar("Enhancements", 1, "Caudium CGI Variables", TYPE_FLAG|VAR_MORE,
	 "Add the extra Caudium environment variables which are: <dl>\n"
	 "<dt><b>COOKIE_[name]</b></dt>"
	 "<dd>The cookie named [name].</dd>"
	 "<dt><b>VAR_[name]</b></dt>"
	 "<dd>The form variable named [name].</dd>"
	 "<dt><b>PRESTATE_[name]</b></dt>"
	 "<dd>The prestate [name].</dd>"
	 "<dt><b>SUPPORTS_[name]</b></dt>"
	 "<dd>The all applicable 'supports' vars.</dd>"
	 "<dt><b>COOKIES, VARIABLES, PRESTATES, SUPPORTS</b></dt>"
	 "<dd>Space-separated lists of all COOKIE_, VAR_, PRESTATE_ and "
	 "SUPPORTS_ variables set. </dd></dl>"
	 "<p>Sometimes this breaks scripts and you might want to disable "
	 "this option.</p>");
	 
  defvar("interpreter", "/usr/bin/php3", "interpreter path", TYPE_LOCATION, 
	 "Path to interpreter executable");

  defvar("ext", ({"php",}), "script extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be parsed by " +
	 "given interpreter.");

  defvar("stderr","main log file",	 
	 "Log CGI errors to...", TYPE_STRING_LIST,
	 "By changing this variable you can select where error messages "
	 "(which means all text written to stderr) from "
	 "CGI scripts should be sent. By default they will be written to the "
	 "main log file - logs/debug/[name-of-configdir].1. You can also "
	 "choose to send the error messages to a special log file or to the "
	 "browser.\n",
	 ({ "main log file",
	    "custom log file",
	    "browser" }));

  defvar("cgilog", GLOBVAR(logdirprefix)+
	 short_name(conf? conf->name:".")+"/cgi.log", 
	 "Log file", TYPE_STRING,
	 "Where to log errors from CGI scripts. You can also choose to send "
	 "the errors to the browser or to the main Caudium log file. "
	 " Some substitutions of the file name will be done to allow "
	 "automatic rotating:"
	 "<pre>"
	 "%y    Year  (i.e. '1997')\n"
	 "%m    Month (i.e. '08')\n"
	 "%d    Date  (i.e. '10' for the tenth)\n"
	 "%h    Hour  (i.e. '00')\n</pre>", 0,
	 lambda() { return (QUERY(stderr) != "custom log file"); });

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG|VAR_MORE,
	 "If set, the raw, unparsed, user info will be sent to the script, "
	 " in the HTTP_AUTHORIZATION environment variable. This is not "
	 "recommended, but some scripts need it. Please note that this "
	 "will give the scripts access to the password used.");

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG|VAR_MORE,
	 "If set, the variable REMOTE_PASSWORD will be set to the decoded "
	 "password value.");

  defvar("priority", "normal", "Limits: Priority", TYPE_STRING_LIST,
         "The priority, in somewhat general terms (for portability, this works on "
         " all operating systems). 'realtime' is not recommended for CGI scripts. "
         "On most operating systems, a process with this priority can "
         "monopolize the CPU and IO resources, even preemtping the kernel "
         "in some cases.",
         ({
           "lowest",
           "low",
           "normal",
           "high",
           "higher",
           "realtime",
         }) 
         ,lambda(){return QUERY(nice);}
         );
  
  defvar("warn_root_cgi", 1, "Warn for CGIs executing as root", TYPE_FLAG,
	 "If this flag is set, a warning will be issued to the event and "
         " debug log when a script is run as the root user. This will "
         "only happend if the 'Run scripts as' variable is set to root (or 0)",
         0, getuid);

  defvar("runuser", "nobody", "Run scripts as", TYPE_STRING,
	 "If you start Caudium as root, and this variable is set, CGI scripts "
	 "will be run as this user. You can use either the user name or the "
	 "UID. Note however, that if you don't have a working user database "
	 "enabled, only UID's will work correctly. If unset, scripts will "
	 "be run as nobody.", 0, getuid);

  defvar("runowner", 1, "Run scripts as", TYPE_FLAG,
	 "If enabled, scripts are run as owner.", 0, getuid);

  defvar("user", 1, "Run user scripts as owner", TYPE_FLAG,
	 "If set, scripts in the home-dirs of users will be run as the "
	 "user. This overrides the Run scripts as variable.", 0, getuid);

  defvar("setgroups", 1, "Set the supplementary group access list", TYPE_FLAG,
	 "If set, the supplementary group access list will be set for "
	 "the CGI scripts. This can slow down CGI-scripts significantly "
	 "if you are using eg NIS+. If not set, the supplementary group "
	 "access list will be cleared.");

  defvar("allow_symlinks", 1, "Allow symlinks", TYPE_FLAG,
	 "If set, allows symbolic links to binaries owned by the directory "
	 "owner. Other symlinks are still disabled.<br>\n"
	 "NOTE : This option only has effect if scripts are run as owner.",
	 0, run_as_user_enabled);

  defvar("nice", 0, "Limits: Nice value", TYPE_INT,
	 "The nice level to use when running scripts. "
	 "20 is nicest, and 0 is the most aggressive available to "
	 "normal users. Defining the Nice value to anyting but 0 will override"
         " the 'Priority' setting.");

  defvar("coresize", 0, "Limits: Core dump size", TYPE_INT,
	 "The maximum size of a core-dump, in 512 byte blocks."
	 " -2 is unlimited.");

  defvar("maxtime", 60, "Limits: Maximum CPU time", TYPE_INT_LIST,
	 "The maximum CPU time the script might use in seconds. -2 is unlimited.",
	 ({ -2, 10, 30, 60, 120, 240 }));

  defvar("datasize", -2, "Limits: Memory size", TYPE_INT,
	 "The maximum size of the memory used, in Kb. -2 is unlimited.");

  defvar("nproc", 10, "Limits: Max procs", TYPE_INT,
	 "Maximum nuber of user process.");

  defvar("filesize", -2, "Limits: Maximum file size", TYPE_INT,
	 "The maximum size of any file created, in 512 byte blocks. -2 "
	 "is unlimited.");

  defvar("open_files", 64, "Limits: Maximum number of open files",
	 TYPE_INT_LIST,
	 "The maximum number of files the script can keep open at any time. "
         "It is not possible to set this value over the system maximum. "
         "On most systems, there is no limit, but some unix systems still "
         "have a static filetable (Linux and *BSD, basically).",
	 ({64,128,256,512,1024,2048}));

  defvar("stack", -2, "Limits: Stack size", TYPE_INT,
	 "The maximum size of the stack used, in kilobytes. -2 is unlimited.");

  defvar("kill_call_out", 5, "Limits: Time before killing scripts",
	 TYPE_INT_LIST|VAR_MORE,
	 "The maximum real time the script might run in minutes before it's "
	 "killed. 0 means unlimited.", ({ 0, 1, 2, 3, 4, 5, 7, 10, 15 }));
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: env
//! If this is set, all environment variables caudium has will be passed to CGI scripts, not only those defined in the CGI/1.1 standard. This includes PATH. (For a quick test, try this script with and without this variable set:<pre>#!/bin/sh<br /><br />echo Content-type: text/plain<br />echo ''<br />env<br /></pre>
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Pass environment variables
//
//! defvar: extra_env
//! Extra variables to be sent to the script, format:<pre>NAME=value
//!NAME=value
//!</pre>Please note that normal CGI variables will override these.
//!  type: TYPE_TEXT_FIELD|VAR_MORE
//!  name: Extra environment variables
//
//! defvar: Enhancements
//! Add the extra Caudium environment variables which are: <dl>
//!<dt><b>COOKIE_[name]</b></dt><dd>The cookie named [name].</dd><dt><b>VAR_[name]</b></dt><dd>The form variable named [name].</dd><dt><b>PRESTATE_[name]</b></dt><dd>The prestate [name].</dd><dt><b>SUPPORTS_[name]</b></dt><dd>The all applicable 'supports' vars.</dd><dt><b>COOKIES, VARIABLES, PRESTATES, SUPPORTS</b></dt><dd>Space-separated lists of all COOKIE_, VAR_, PRESTATE_ and SUPPORTS_ variables set. </dd></dl><p>Sometimes this breaks scripts and you might want to disable this option.</p>
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Caudium CGI Variables
//
//! defvar: interpreter
//! Path to interpreter executable
//!  type: TYPE_LOCATION
//!  name: interpreter path
//
//! defvar: ext
//! All files ending with these extensions, will be parsed by 
//!  type: TYPE_STRING_LIST
//!  name: script extensions
//
//! defvar: stderr
//! By changing this variable you can select where error messages (which means all text written to stderr) from CGI scripts should be sent. By default they will be written to the main log file - logs/debug/[name-of-configdir].1. You can also choose to send the error messages to a special log file or to the browser.
//!
//!  type: TYPE_STRING_LIST
//!  name: Log CGI errors to...
//
//! defvar: rawauth
//! If set, the raw, unparsed, user info will be sent to the script,  in the HTTP_AUTHORIZATION environment variable. This is not recommended, but some scripts need it. Please note that this will give the scripts access to the password used.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Raw user info
//
//! defvar: clearpass
//! If set, the variable REMOTE_PASSWORD will be set to the decoded password value.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Send decoded password
//
//! defvar: priority
//! The priority, in somewhat general terms (for portability, this works on  all operating systems). 'realtime' is not recommended for CGI scripts. On most operating systems, a process with this priority can monopolize the CPU and IO resources, even preemtping the kernel in some cases.
//!  type: TYPE_STRING_LIST
//!  name: Limits: Priority
//
//! defvar: warn_root_cgi
//! If this flag is set, a warning will be issued to the event and  debug log when a script is run as the root user. This will only happend if the 'Run scripts as' variable is set to root (or 0)
//!  type: TYPE_FLAG
//!  name: Warn for CGIs executing as root
//
//! defvar: runuser
//! If you start Caudium as root, and this variable is set, CGI scripts will be run as this user. You can use either the user name or the UID. Note however, that if you don't have a working user database enabled, only UID's will work correctly. If unset, scripts will be run as nobody.
//!  type: TYPE_STRING
//!  name: Run scripts as
//
//! defvar: runowner
//! If enabled, scripts are run as owner.
//!  type: TYPE_FLAG
//!  name: Run scripts as
//
//! defvar: user
//! If set, scripts in the home-dirs of users will be run as the user. This overrides the Run scripts as variable.
//!  type: TYPE_FLAG
//!  name: Run user scripts as owner
//
//! defvar: setgroups
//! If set, the supplementary group access list will be set for the CGI scripts. This can slow down CGI-scripts significantly if you are using eg NIS+. If not set, the supplementary group access list will be cleared.
//!  type: TYPE_FLAG
//!  name: Set the supplementary group access list
//
//! defvar: allow_symlinks
//! If set, allows symbolic links to binaries owned by the directory owner. Other symlinks are still disabled.<br />
//!NOTE : This option only has effect if scripts are run as owner.
//!  type: TYPE_FLAG
//!  name: Allow symlinks
//
//! defvar: nice
//! The nice level to use when running scripts. 20 is nicest, and 0 is the most aggressive available to normal users. Defining the Nice value to anyting but 0 will override the 'Priority' setting.
//!  type: TYPE_INT
//!  name: Limits: Nice value
//
//! defvar: coresize
//! The maximum size of a core-dump, in 512 byte blocks. -2 is unlimited.
//!  type: TYPE_INT
//!  name: Limits: Core dump size
//
//! defvar: maxtime
//! The maximum CPU time the script might use in seconds. -2 is unlimited.
//!  type: TYPE_INT_LIST
//!  name: Limits: Maximum CPU time
//
//! defvar: datasize
//! The maximum size of the memory used, in Kb. -2 is unlimited.
//!  type: TYPE_INT
//!  name: Limits: Memory size
//
//! defvar: nproc
//! Maximum nuber of user process.
//!  type: TYPE_INT
//!  name: Limits: Max procs
//
//! defvar: filesize
//! The maximum size of any file created, in 512 byte blocks. -2 is unlimited.
//!  type: TYPE_INT
//!  name: Limits: Maximum file size
//
//! defvar: open_files
//! The maximum number of files the script can keep open at any time. It is not possible to set this value over the system maximum. On most systems, there is no limit, but some unix systems still have a static filetable (Linux and *BSD, basically).
//!  type: TYPE_INT_LIST
//!  name: Limits: Maximum number of open files
//
//! defvar: stack
//! The maximum size of the stack used, in kilobytes. -2 is unlimited.
//!  type: TYPE_INT
//!  name: Limits: Stack size
//
//! defvar: kill_call_out
//! The maximum real time the script might run in minutes before it's killed. 0 means unlimited.
//!  type: TYPE_INT_LIST|VAR_MORE
//!  name: Limits: Time before killing scripts
//
