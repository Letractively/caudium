/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
 * Copyright � 1994-2000 Roxen Internet Software
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
 * $Id$
 *
 * The core of  Caudium.
 *
 * Per Hedbor, Henrik Grubbstr�m, Pontus Hagland, David Hedbor and others.
 */

//! file: base_server/caudium.pike
//!  Core routines of Caudium.
//
//! inherits: read_config
//! inherits: module_support
//! inherits: socket
//! inherits: disk_cache
//! inherits: language
//! inherits: color
//! inherits: fonts
//
//! cvs_version: $Id$

// ABS and suicide systems contributed freely by Francesco Chemolli

constant cvs_version = "$Id$";

object backend_thread;
object argcache;

// Some headerfiles
#define IN_ROXEN
#include <caudium.h>
#include <config.h>
#include <module.h>
#include <variables.h>

// Inherits
inherit "read_config";
#ifdef NO_DNS
inherit "dummy_hosts";
#else
inherit "hosts";
#endif
inherit "module_support";
inherit "socket";
inherit "disk_cache";
inherit "language";
inherit "color";
inherit "fonts";

// The datashuffler program
#if constant(spider.shuffle) && (defined(THREADS) || defined(__NT__))
constant pipe = (program)"smartpipe";
#else
constant pipe = Pipe.pipe;
#endif

// This is the real Caudium version. It should be changed before each
// release
constant __caudium_version__ = "1.0";
constant __caudium_build__ = "5";

#ifdef __NT__
constant real_version = "Caudium/"+__caudium_version__+"."+__caudium_build__+"-NT";
#else
constant real_version = "Caudium/"+__caudium_version__+"."+__caudium_build__;
#endif

#if _DEBUG_HTTP_OBJECTS
mapping httpobjects = ([]);
static int idcount;
int new_id(){ return idcount++; }
#endif

#ifdef MODULE_DEBUG
#define MD_PERROR(X)	perror X;
#else
#define MD_PERROR(X)
#endif /* MODULE_DEBUG */

// pids of the start-script and ourselves.
int startpid, roxenpid;
object caudium = this_object(), roxen=this_object(), current_configuration;

program Configuration;	/*set in create*/

array configurations = ({});
object main_configuration_port;
mapping allmodules, somemodules=([]);

// A mapping from ports (objects, that is) to an array of information
// about that port.  This will hopefully be moved to objects cloned
// from the configuration object in the future.
mapping portno = ([]);

// constant decode = caudium->decode;

// Function pointer and the root of the configuration interface
// object.
function build_root;
object root;

#ifdef THREADS
// This mutex is used by privs.pike and set_u_and_gid().
object euid_egid_lock = Thread.Mutex();

void stop_handler_threads(); // forward declaration
#endif /* THREADS */

int privs_level;
int die_die_die;

void stop_all_modules()
{
  foreach(configurations, object conf)
    conf->stop();
}

// Function that actually shuts down Caudium. (see low_shutdown).
private static void really_low_shutdown(int exit_code)
{
  // Die nicely.
#ifdef SOCKET_DEBUG
  roxen_perror("SOCKETS: really_low_shutdown\n"
	       "                        Bye!\n");
#endif

#ifdef THREADS
  stop_handler_threads();
#endif /* THREADS */

  // Don't use fork() with threaded servers.
#if constant(fork) && !constant(thread_create)

  // Fork, and then do a 'slow-quit' in the forked copy. Exit the
  // original copy, after all listen ports are closed.
  // Then the forked copy can finish all current connections.
  if(fork()) {
    // Kill the parent.
    add_constant("roxen", 0);	// Remove some extra refs...
    add_constant("caudium", 0);	// Remove some extra refs...

    exit(exit_code);		// Die...
  }
  // Now we're running in the forked copy.

  // FIXME: This probably doesn't work correctly on threaded servers,
  // since only one thread is left running after the fork().
#if efun(_pipe_debug)
  call_out(lambda() {  // Wait for all connections to finish
	     call_out(Simulate.this_function(), 20);
	     if(!_pipe_debug()[0]) exit(0);
	   }, 1);
#endif /* efun(_pipe_debug) */
  call_out(lambda(){ exit(0); }, 600); // Slow buggers..
  array f=indices(portno);
  for(int i=0; i<sizeof(f); i++)
    catch(destruct(f[i]));
#else /* !constant(fork) || constant(thread_create) */

  // FIXME:
  // Should probably attempt something similar to the above,
  // but this should be sufficient for the time being.
  add_constant("roxen", 0);	// Paranoia...
  add_constant("caudium", 0);	// Remove some extra refs...

  exit(exit_code);		// Now we die...

#endif /* constant(fork) && !constant(thread_create) */
}

// Shutdown Caudium
//  exit_code = 0	True shutdown
//  exit_code = -1	Restart
private static void low_shutdown(int exit_code)
{
  // Change to root user if possible ( to kill the start script... )
#if efun(seteuid)
  seteuid(getuid());
  setegid(getgid());
#endif
#if efun(setuid)
  setuid(0);
#endif
  stop_all_modules();
  
  if(main_configuration_port && objectp(main_configuration_port))
  {
    // Only _really_ do something in the main process.
    int pid;
    if (exit_code) {
      roxen_perror("Restarting Caudium.\n");
    } else {
      roxen_perror("Shutting down Caudium.\n");

      // This has to be refined in some way. It is not all that nice to do
      // it like this (write a file in /tmp, and then exit.)  The major part
      // of code to support this is in the 'start' script.
#ifndef __NT__
#ifdef USE_SHUTDOWN_FILE
      // Fallback for systems without geteuid, Caudium will (probably)
      // not be able to kill the start-script if this is the case.
      rm("/tmp/Caudium_Shutdown_"+startpid);

      object f;
      f = open("/tmp/Caudium_Shutdown_"+startpid, "wc");
      
      if(!f) 
	roxen_perror("cannot open shutdown file.\n");
      else f->write(""+getpid());
#endif /* USE_SHUTDOWN_FILE */

      // Try to kill the start-script.
      if(startpid != getpid())
      {
	kill(startpid, signum("SIGINTR"));
	kill(startpid, signum("SIGHUP"));
	kill(getppid(), signum("SIGINTR"));
	kill(getppid(), signum("SIGHUP"));
      }
#endif /* !__NT__ */
    }
  }

  call_out(really_low_shutdown, 5, exit_code);
}

// Perhaps somewhat misnamed, really...  This function will close all
// listen ports, fork a new copy to handle the last connections, and
// then quit the original process.  The 'start' script should then
// start a new copy of Caudium automatically.
mapping restart() 
{ 
  low_shutdown(-1);
  return ([ "data": replace(Stdio.read_bytes("etc/restart.html"),
			    ({"$docurl", "$PWD"}), ({caudium->docurl, getcwd()})),
		  "type":"text/html" ]);
} 

mapping shutdown() 
{
  low_shutdown(0);
  return ([ "data":replace(Stdio.read_bytes("etc/shutdown.html"),
			   ({"$docurl", "$PWD"}), ({caudium->docurl, getcwd()})),
	    "type":"text/html" ]);
} 

// This is called for each incoming connection.
private static void accept_callback( object port )
{
  object file;
  int q=QUERY(NumAccept);
  array pn=portno[port];
  
#ifdef DEBUG
  if(!pn)
  {
    destruct(port->accept());
    perror("$&$$& Garbage Collector bug!!\n");
    return;
  }
#endif
  while(q--)
  {
    catch { file = port->accept(); };
#ifdef SOCKET_DEBUG
    if(!pn[-1])
    {
      report_error("In accept: Illegal protocol handler for port.\n");
      if(file) destruct(file);
      return;
    }
    perror(sprintf("SOCKETS: accept_callback(CONF(%s))\n", 
		   pn[1]&&pn[1]->name||"Configuration"));
#endif
    if(!file)
    {
      switch(port->errno())
      {
       case 0:
       case 11:
	return;

       default:
#ifdef DEBUG
	perror("Accept failed.\n");
#if constant(real_perror)
	real_perror();
#endif
#endif /* DEBUG */
 	return;

       case 24:
        report_fatal(sprintf("Out of sockets (%d active). "
			     "Restarting server gracefully.\n",
			     sizeof(get_all_active_fd())));
	low_shutdown(-1);
	return;
      }
    }
#ifdef FD_DEBUG
    mark_fd( file->query_fd(), "Connection from "+file->query_address());
#endif
    pn[-1](file,pn[1]);
#ifdef SOCKET_DEBUG
    perror(sprintf("SOCKETS:   Ok. Connect on %O:%O from %O\n", 
		   pn[2], pn[0], file->query_address()));
#endif
  }
}

// handle function used when THREADS is not enabled.
void unthreaded_handle(function f, mixed ... args)
{
  f(@args);
}

function handle = unthreaded_handle;

/*
 * THREADS code starts here
 */
#ifdef THREADS

object do_thread_create(string id, function f, mixed ... args)
{
  object t = thread_create(f, @args);
  catch(t->set_name( id ));
  roxen_perror(id+" started\n");
  return t;
}

// Queue of things to handle.
// An entry consists of an array(function fp, array args)
static object (Thread.Queue) handle_queue = Thread.Queue();

// Number of handler threads that are alive.
static int thread_reap_cnt;

void handler_thread(int id)
{
  array (mixed) h, q;
  while(1)
  {
    if(q=catch {
      do {
	if((h=handle_queue->read()) && h[0]) {
	  h[0](@h[1]);
	  h=0;
	} else if(!h) {
	  // Caudium is shutting down.
	  werror("Handle thread ["+id+"] stopped\n");
	  thread_reap_cnt--;
	  return;
	}
      } while(1);
    }) {
      report_error("Uncaught error in handler thread: " +
		   describe_backtrace(q) +
		   "Client will not get any response from Caudium.\n");
      if (q = catch {h = 0;}) {
	report_error("Uncaught error in handler thread: " +
		     describe_backtrace(q) +
		     "Client will not get any response from Caudium.\n");
      }
    }
  }
}

void threaded_handle(function f, mixed ... args)
{
  // trace(100);
  handle_queue->write(({f, args }));
}

int number_of_threads;
void start_handler_threads()
{
  if (QUERY(numthreads) <= 1) {
    QUERY(numthreads) = 1;
    perror("Starting 1 thread to handle requests.\n");
  } else {
    perror("Starting "+QUERY(numthreads)+" threads to handle requests.\n");
  }
  for(; number_of_threads < QUERY(numthreads); number_of_threads++)
    do_thread_create( "Handle thread ["+number_of_threads+"]",
		   handler_thread, number_of_threads );
  if(number_of_threads > 0)
    handle = threaded_handle;
}

void stop_handler_threads()
{
  int timeout=30;
  perror("Stopping all request handler threads.\n");
  while(number_of_threads>0) {
    number_of_threads--;
    handle_queue->write(0);
    thread_reap_cnt++;
  }
  while(thread_reap_cnt) {
    if(--timeout<=0) {
      perror("Giving up waiting on threads!\n");
      return;
    }
    sleep(1);
  }
}

mapping accept_threads = ([]);
void accept_thread(object port,array pn)
{
  accept_threads[port] = this_thread();
  program port_program = pn[-1];
  mixed foo = pn[1];
  array err;
  object o;
  while(!die_die_die)
  {
    o = port->accept();
    err = catch {
      if(o) port_program(o,foo);
    };
    if(err)
      perror("Error in accept_thread: %O\n",describe_backtrace(err));
  }
}

#endif /* THREADS */



// Listen to a port, connected to the configuration 'conf', binding
// only to the netinterface 'ether', using 'requestprogram' as a
// protocol handled.

// If you think that the argument order is quite unintuitive and odd,
// you are right, the order is the same as the implementation order.

// Old spinners only listened to a port number, then the
// configurations came, then the need to bind to a specific
// ethernetinterface, and then the need to have more than one concurrent
// protocol (http, ftp, ssl, etc.)

object create_listen_socket(mixed port_no, object conf,
			    string|void ether, program requestprogram,
			    array prt)
{
  object port;
#ifdef SOCKET_DEBUG
  perror(sprintf("SOCKETS: create_listen_socket(%d,CONF(%s),%s)\n",
		 port_no, conf?conf->name:"Configuration port", ether));
#endif
  if(!requestprogram)
    error("No request handling module passed to create_listen_socket()\n");

  if(!port_no)
  {
    port = Stdio.Port( "stdin", accept_callback );
    port->set_id(port);
    if(port->errno())
    {
      report_error("Cannot listen to stdin.\n"
		   "Errno is "+port->errno()+"\n");
    }
  } else {
    port = Stdio.Port();
    port->set_id(port);
    if(!stringp(ether) || (lower_case(ether) == "any"))
      ether=0;
    if(ether)
      sscanf(ether, "addr:%s", ether);
#if defined(THREADS) && 0
    if(!port->bind(port_no, 0, ether))
#else
    if(!port->bind(port_no, accept_callback, ether))
#endif
    {
#ifdef SOCKET_DEBUG
      perror("SOCKETS:    -> Failed.\n");
#endif
      report_warning("Failed to open socket on "+ether+":"+port_no+
		     " (already bound?)\nErrno is: "+ port->errno()+"\n"
		     "Retrying...\n");
      sleep(1);
#if defined(THREADS) && 0
      if(!port->bind(port_no, 0, ether))
#else
      if(!port->bind(port_no, accept_callback, ether))
#endif
      {
	report_error("Failed to open socket on "+ether+":"+port_no+
		     " (already bound?)\nErrno is: "+ port->errno()+"\n");
	return 0;
      }
    }
  }
  portno[port]=({ port_no, conf, ether||"Any", 0, requestprogram });
#if defined(THREADS) && 0
  call_out(do_thread_create,0,"Accept thread ["+port_no+":"+(ether||"ANY]"),
	   accept_thread, port,portno[port]);
#endif
#ifdef SOCKET_DEBUG
  perror("SOCKETS:    -> Ok.\n");
#endif
  return port;
}


// The configuration interface is loaded dynamically for faster
// startup-time, and easier coding in the configuration interface (the
// Caudium environment is already finished when it is loaded)
object configuration_interface_obj;
int loading_config_interface;
int enabling_configurations;

object configuration_interface()
{
  if(enabling_configurations)
    return 0;
  if(loading_config_interface)
  {
    perror("Recursive calls to configuration_interface()\n"
	   + describe_backtrace(backtrace())+"\n");
  }
  
  if(!configuration_interface_obj)
  {
    perror("Loading configuration interface.\n");
    loading_config_interface = 1;
    array err = catch {
      configuration_interface_obj=((program)"mainconfig")();
      root = configuration_interface_obj->root;
      build_root = configuration_interface_obj->build_root;
    };
    loading_config_interface = 0;
    if(!configuration_interface_obj) {
      report_error(sprintf("Failed to load the configuration interface!\n%s\n",
			   describe_backtrace(err)));
    }
  }
  return configuration_interface_obj;
}

// Unload the configuration interface
void unload_configuration_interface()
{
  report_notice("Unloading the configuration interface\n");

  configuration_interface_obj = 0;
  loading_config_interface = 0;
  enabling_configurations = 0;
  build_root = 0;
  catch{root->dest();};
  root = 0;
}


// Create a new configuration from scratch.

// 'type' is as in the form. 'none' for a empty configuration.
int add_new_configuration(string name, string type)
{
  return configuration_interface()->low_enable_configuration(name, type);
}

// Call the configuration interface function. This is more or less
// equivalent to a virtual configuration with the configurationinterface
// mounted on '/'. This will probably be the case in future versions
#ifdef THREADS
object configuration_lock = Thread.Mutex();
#endif

mixed configuration_parse(mixed ... args)
{
#ifdef THREADS
  object key;
  catch(key = configuration_lock->lock());
#endif
  if(args)
    return configuration_interface()->configuration_parse(@args);
}

mapping(string:array(int)) error_log=([]);

string last_error="";

// Write a string to the configuration interface error log and to stderr.
void nwrite(string s, int|void perr, int|void type)
{
  last_error = s;
  if (!error_log[type+","+s]) {
    error_log[type+","+s] = ({ time() });
  } else {
    error_log[type+","+s] += ({ time() });
  }
  if(type>=1) roxen_perror(s);
}

// When was Caudium started?
int boot_time;
int start_time;

string version()
{
  return QUERY(identversion) ? real_version:"Caudium";
}

// The db for the nice '<if supports=..>' tag.
mapping (string:array (array (object|multiset))) supports;
private multiset default_supports = (< >);

private static inline array positive_supports(array from)
{
  array res = copy_value(from);
  int i;
  for(i=0; i<sizeof(res); i++)
    if(res[i][0] == '-')
      res[i] = 0;
  return res - ({ 0 });
}

private inline array negative_supports(array from)
{
  array res = copy_value(from);
  int i;
  for(i=0; i<sizeof(res); i++)
    if(res[i][0] != '-')
      res[i] = 0;
    else
      res[i] = res[i][1..];
  return res - ({ 0 });
}

private static mapping foo_defines = ([ ]);
// '#define' in the 'supports' file.
static private string current_section; // Used below.
// '#section' in the 'supports' file.

private void parse_supports_string(string what)
{
  string foo;
  
  array lines;
  int i;
  lines=replace(what, "\\\n", " ")/"\n"-({""});

  foreach(lines, foo)
  {
    array bar, gazonk;
    if(foo[0] == '#')
    {
      string file;
      string name, to;
      if(sscanf(foo, "#include <%s>", file))
      {
	if(foo=Stdio.read_bytes(file))
	  parse_supports_string(foo);
	else
	  report_error("Supports: Cannot include file "+file+"\n");
      } else if(sscanf(foo, "#define %[^ ] %s", name, to)) {
	name -= "\t";
	foo_defines[name] = to;
//	perror("#defining '"+name+"' to "+to+"\n");
      } else if(sscanf(foo, "#section %[^ ] {", name)) {
//	perror("Entering section "+name+"\n");
	current_section = name;
	if(!supports[name])
	  supports[name] = ({});
      } else if((foo-" ") == "#}") {
//	perror("Leaving section "+current_section+"\n");
	current_section = 0;
      } else {
//	perror("Comment: "+foo+"\n");
      }
      
    } else {
      int rec = 10;
      string q=replace(foo,",", " ");
      foo="";
      
      // Handle all defines.
      while((strlen(foo)!=strlen(q)) && --rec)
      {
	foo=q;
	q = replace(q, indices(foo_defines), values(foo_defines));
      }
      
      foo=q;
      
      if(!rec)
	perror("Too deep recursion while replacing defines.\n");
      
//    perror("Parsing supports line '"+foo+"'\n");
      bar = replace(foo, ({"\t",","}), ({" "," "}))/" " -({ "" });
      foo="";
      
      if(sizeof(bar) < 2)
	continue;
    
      if(bar[0] == "default")
	default_supports = aggregate_multiset(@bar[1..]);
      else
      {
	gazonk = bar[1..];
	mixed err;
	if (err = catch {
	  supports[current_section]
	    += ({ ({ Regexp(bar[0])->match,
		     aggregate_multiset(@positive_supports(gazonk)),
		     aggregate_multiset(@negative_supports(gazonk)),
	    })});
	}) {
	  report_error(sprintf("Failed to parse supports regexp:\n%s\n",
			       describe_backtrace(err)));
	}
      }
    }
  }
}

public void initiate_supports()
{
  supports = ([ 0:({ }) ]);
  foo_defines = ([ ]);
  current_section = 0;
  parse_supports_string(QUERY(Supports));
  foo_defines = 0;
}

array _new_supports = ({});

void done_with_caudium_net()
{
  string new, old;
  new = _new_supports * "";
  new = (new/"\r\n\r\n")[1..]*"\r\n\r\n";
  old = Stdio.read_bytes( "etc/supports" );
  
  if(strlen(new) < strlen(old)-200) // Error in transfer?
    return;
  
  if(old != new) {
    perror("Got new supports data from caudium.net\n");
    perror("Replacing old file with new data.\n");
    mv("etc/supports", "etc/supports~");
    Stdio.write_file("etc/supports", new);
    old = Stdio.read_bytes( "etc/supports" );
    if(old != new)
    {
      perror("FAILED to update the supports file.\n");
      mv("etc/supports~", "etc/supports");
    } else {
      initiate_supports();
    }
  }
#ifdef DEBUG
  else
    perror("No change to the supports file.\n");
#endif
}

void got_data_from_caudium_net(object this, string foo)
{
  if(!foo)
    return;
  _new_supports += ({ foo });
}

void connected_to_caudium_net(object port)
{
  if(!port) 
  {
#ifdef DEBUG
    perror("Failed to connect to caudium.net:80.\n");
#endif
    return 0;
  }
#ifdef DEBUG
  perror("Connected to caudium.net:80\n");
#endif
  _new_supports = ({});
  port->set_id(port);
  string v = version();
  if (v != real_version) {
    v = v + " (" + real_version + ")";
  }
  port->write("GET /supports HTTP/1.0\r\n"
	      "User-Agent: " + v + "\r\n"
	      "Host: caudium.net:80\r\n"
	      "Pragma: no-cache\r\n"
	      "\r\n");
  port->set_nonblocking(got_data_from_caudium_net,
			got_data_from_caudium_net,
			done_with_caudium_net);
}

public void update_supports_from_caudium_net()
{
  // FIXME:
  // This code has a race-condition, but it only occurs once a week...
  if(QUERY(next_supports_update) <= time())
  {
    if(QUERY(AutoUpdate))
    {
      async_connect("caudium.net", 80, connected_to_caudium_net);
#ifdef DEBUG
      perror("Connecting to caudium.net:80\n");
#endif
    }
    remove_call_out( update_supports_from_caudium_net );

  // Check again in one week.
    QUERY(next_supports_update)=3600*24*7 + time();
    store("Variables", variables, 0, 0);
  }
  call_out(update_supports_from_caudium_net, QUERY(next_supports_update)-time());
}

// Return a list of 'supports' values for the current connection.

public multiset find_supports(string from, void|multiset existing_sup)
{
  multiset (string) sup =  (< >);
  multiset (string) nsup = (< >);

  array (function|multiset) s;
  string v;
  array f;
  
  if(!existing_sup) existing_sup = (<>);
  
  if(!strlen(from) || from == "unknown")
    return default_supports|existing_sup;
 if(!(sup = cache_lookup("supports", from))) {
    sup = (<>);
    foreach(indices(supports), v)
    {
      if(!v || !search(from, v))
      {
	//  perror("Section "+v+" match "+from+"\n");
	f = supports[v];
	foreach(f, s)
	  if(s[0](from))
	  {
	    sup |= s[1];
	    nsup  |= s[2];
	  }
      }
    }
    if(!sizeof(sup))
    {
      sup = default_supports;
#ifdef DEBUG
      perror("Unknown client: \""+from+"\"\n");
#endif
    }
    sup -= nsup;
    cache_set("supports", from, sup);
  }
  return sup|existing_sup;
}

public void log(mapping file, object request_id)
{
  if(!request_id->conf) return; 
  request_id->conf->log(file, request_id);
}

// Support for unique user id's 
private object current_user_id_file;
private int current_user_id_number, current_user_id_file_last_mod;

private void restore_current_user_id_number()
{
  if(!current_user_id_file)
    current_user_id_file = open(configuration_dir + "LASTUSER~", "rwc");
  if(!current_user_id_file)
  {
    call_out(restore_current_user_id_number, 2);
    return;
  } 
  current_user_id_number = (int)current_user_id_file->read(100);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  perror("Restoring unique user ID information. (" + current_user_id_number 
	 + ")\n");
#ifdef FD_DEBUG
  mark_fd(current_user_id_file->query_fd(), "Unique user ID logfile.\n");
#endif
}


int increase_id()
{
  if(!current_user_id_file)
  {
    restore_current_user_id_number();
    return current_user_id_number+time();
  }
  if(current_user_id_file->stat()[2] != current_user_id_file_last_mod)
    restore_current_user_id_number();
  current_user_id_number++;
  //perror("New unique id: "+current_user_id_number+"\n");
  current_user_id_file->seek(0);
  current_user_id_file->write((string)current_user_id_number);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  return current_user_id_number;
}

public string full_status()
{
  int tmp;
  string res="";
  array foo = ({0.0, 0.0, 0.0, 0.0, 0});
  if(!sizeof(configurations))
    return "<B>No virtual servers enabled</B>\n";
  
  foreach(configurations, object conf)
  {
    if(!conf->sent
       ||!conf->received
       ||!conf->hsent)
      continue;
    foo[0] += conf->sent->mb()/(float)(time(1)-start_time+1);
    foo[1] += conf->sent->mb();
    foo[2] += conf->hsent->mb();
    foo[3] += conf->received->mb();
    foo[4] += conf->requests;
  }

  for(tmp = 1; tmp < 4; tmp ++)
  {
    if(foo[tmp] < 1024.0)     
      foo[tmp] = sprintf("%.2f MB", foo[tmp]);
    else
      foo[tmp] = sprintf("%.2f GB", foo[tmp]/1024.0);
  }

  int uptime = time()-start_time;
  int days = uptime/(24*60*60);
  int hrs = uptime/(60*60);
  int min = uptime/60 - hrs*60;
  hrs -= days*24;

  res = sprintf("<table>"
		"<tr><td><b>Version:</b></td><td colspan=2>%s</td></tr>\n"
		"<tr><td><b>Booted on:</b></td><td colspan=2>%s</td></tr>\n"
		"<tr><td><b>Time to boot:</b></td>"
		"<td>%d sec</td></tr>\n"
		"<tr><td><b>Uptime:</b></td>"
		"<td colspan=2>%d day%s, %02d:%02d:%02d</td></tr>\n"
		"<tr><td colspan=3>&nbsp;</td></tr>\n"
		"<tr><td><b>Sent data:</b></td><td>%s"
		"</td><td>%.2f Kbit/sec</td></tr><tr>\n",
		real_version, ctime(boot_time), start_time-boot_time,
		days, (days==1?"":"s"), hrs, min, uptime%60,
		foo[1], foo[0] * 8192.0);
  
  res += "<td><b>Sent headers:</b></td><td>"+ foo[2] +"</td></tr>\n";
	    
  tmp=(int)((foo[4]*600.0)/(uptime+1));

  res += (sprintf("<tr><td><b>Number of requests:</b></td>"
		  "<td>%8d</td><td>%.2f/min</td></tr>\n"
		  "<tr><td><b>Received data:</b></td>"
		  "<td>%s</td></tr>\n",
		  foo[4], (float)tmp/(float)10, foo[3]));
  
  return res +"</table>";
}


// These are now more or less outdated, the modules really _should_
// pass the information about the current configuration to caudium,
// to enable async operations. This information is in id->conf.
//
// In the future, most, if not all, of these functions will be moved
// to the configuration object. The functions will still be here for
// compatibility for a while, though.

#ifndef NO_COMPAT

public string *userlist(void|object id)
{
  object conf;

  if(id) {
    conf = current_configuration = id->conf;
  } else {
    // Hopefully this case never occurs.
    conf = current_configuration;
  }
  if(conf && conf->auth_module)
    return conf->auth_module->userlist();
  return 0;
}

public string *user_from_uid(int u, void|object id)
{
  object conf;
  if(id) {
    conf = current_configuration = id->conf;
  } else {
    // Hopefully this case never occurs.
    conf = current_configuration;
  }
  if(conf && conf->auth_module)
    return conf->auth_module->user_from_uid(u);
}

public string last_modified_by(object file, object id)
{
  int *s;
  int uid;
  mixed *u;
  
  if(objectp(file)) s = (array(int))file->stat();
  if(!s || sizeof(s)<5) return "A. Nonymous";
  uid=s[5];
  u=user_from_uid(uid, id);
  if(u) return u[0];
  return "A. Nonymous";
}

#endif /* !NO_COMPAT */

// FIXME 
private object find_configuration_for(object bar)
{
  object maybe;
  if(!bar) return configurations[0];
  foreach(configurations, maybe)
    if(maybe->otomod[bar]) return maybe;
  return configurations[-1];
}

// FIXME  
public array|string type_from_filename( string|void file, int|void to )
{
  mixed tmp;
  object current_configuration;
  string ext=extension(file);
    
  if(!current_configuration)
    current_configuration = find_configuration_for(Simulate.previous_object());
  if(!current_configuration->types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

  while(file[-1] == '/') 
    file = file[0..strlen(file)-2]; // Security patch? 
  
  if(tmp = current_configuration->types_fun(ext))
  {
    mixed tmp2,nx;
    if(tmp[0] == "strip")
    {
      tmp2=file/".";
      if(sizeof(tmp2) > 2)
	nx=tmp2[-2];
      if(nx && (tmp2=current_configuration->types_fun(nx)))
	tmp[0] = tmp2[0];
      else
	if(tmp2=current_configuration->types_fun("default"))
	  tmp[0] = tmp2[0];
	else
	  tmp[0]="application/octet-stream";
    }
    return to?tmp:tmp[0];
  } else {
    if(!(tmp=current_configuration->types_fun("default")))
      tmp=({ "application/octet-stream", 0 });
    return to?tmp:tmp[0]; // Per..
  }
  return 0;
}

#ifndef NO_COMPAT
  
#define COMPAT_ALIAS(X) mixed X(string file, object id){return id->conf->X(file,id);}

COMPAT_ALIAS(find_dir);
COMPAT_ALIAS(stat_file);
COMPAT_ALIAS(access);
COMPAT_ALIAS(real_file);
COMPAT_ALIAS(is_file);
COMPAT_ALIAS(userinfo);

public mapping|int get_file(object id, int|void no_magic)
{
  return id->conf->get_file(id, no_magic);
}

public mixed try_get_file(string s, object id, int|void status, int|void nocache)
{
  return id->conf->try_get_file(s,id,status,nocache);
}

#endif /* !NO_COMPAT */

int config_ports_changed = 0;

static string MKPORTKEY(array(string) p)
{
  if (sizeof(p[3])) {
    return(sprintf("%s://%s:%s/(%s)",
		   p[1], p[2], (string)p[0],
		   replace(p[3], ({"\n", "\r"}), ({ " ", " " }))));
  } else {
    return(sprintf("%s://%s:%s/",
		   p[1], p[2], (string)p[0]));
  }
}

// Is this only used to hold the config-ports?
// Seems like it. Changed to a mapping.
private mapping(string:object) configuration_ports = ([]);

// Used by openports.pike
array(object) get_configuration_ports()
{
  return(values(configuration_ports));
}

string docurl;

// I will remove this in a future version of caudium.
private program __p;
mapping my_loaded = ([]);
program last_loaded() { return __p; }

string last_module_name;

string filename(object|program o)
{
  if(objectp(o)) o = object_program(o);
  return my_loaded[(program)o]||last_module_name;
}

program my_compile_file(string file)
{
  return compile_file( file );
}

// ([ filename:stat_array ])
mapping(string:array) module_stat_cache = ([]);
object load(string s, object conf)   // Should perhaps be renamed to 'reload'. 
{
  string cvs;
  array st;
  object e = ErrorContainer();
  sscanf(s, "/cvs:%s", cvs);

//  perror("Module is "+s+"?");
  if(st=file_stat(s+".pike"))
  {
//    perror("Yes, compile "+s+"?");
    if((cvs?(__p=master()->cvs_load_file( cvs+".pike" ))
	:(__p=my_compile_file(s+".pike"))))
    {
//      perror("Yes.");
      my_loaded[__p]=s+".pike";
      module_stat_cache[s-dirname(s)]=st;
      return __p(conf);
    } else
      perror(s+".pike exists, but compilation failed.\n");
  }
  if(st = file_stat(s+".lpc"))
    if(cvs?(__p = master()->cvs_load_file( cvs+".lpc" )):
       (__p = my_compile_file(s+".lpc")))
    {
      my_loaded[__p] = s+".lpc";
      module_stat_cache[s-dirname(s)]=st;
      return __p(conf);
    } else
      perror(s+".lpc exists, but compilation failed.\n");
  if(st = file_stat(s+".module"))
    if(__p = load_module(s+".so"))
    {
      my_loaded[__p] = s+".so";
      module_stat_cache[s-dirname(s)] = st;
      return __p(conf);
    } else
      perror(s+".so exists, but compilation failed.\n");
  return 0; // FAILED..
}

array(string) expand_dir(string d)
{
  string nd;
  array(string) dirs=({d});

//perror("Expand dir "+d+"\n");
  catch {
    foreach((get_dir(d) || ({})) - ({"CVS"}) , nd) 
      if(file_stat(d+nd)[1]==-2)
	dirs+=expand_dir(d+nd+"/");
  }; // This catch is needed....
  return dirs;
}

array(string) last_dirs=0,last_dirs_expand;


object load_from_dirs(array dirs, string f, object conf)
{
  string dir;
  object o;

  if (dirs!=last_dirs)
  {
    last_dirs_expand=({});
    foreach(dirs, dir)
      last_dirs_expand+=expand_dir(dir);
  }

  foreach (last_dirs_expand,dir)
    if ( (o = load(dir+f, conf)) ) return o;

  return 0;
}
static int abs_started;
void restart_if_stuck (int force) 
{
#if constant(alarm)
  remove_call_out(restart_if_stuck);
  if (!(QUERY(abs_engage) || force))
    return;
  if(!abs_started) {
    abs_started = 1;
    roxen_perror("Anti-Block System Enabled.\n");
  }
  call_out (restart_if_stuck,10);
  signal(signum("SIGALRM"),
	 lambda( int n ) {
	   werror(sprintf("**** %s: ABS engaged!\n"
			  "Trying to dump backlog: \n",
			  ctime(time()) - "\n"));
	   catch {
	     // Catch for paranoia reasons.
	     describe_all_threads();
	   };
	   werror(sprintf("**** %s: ABS exiting caudium!\n\n",
			  ctime(time())));  
	   _exit(1); 	// It might now quit correctly otherwise, if it's
	   //  locked up
	 });
  alarm (60*QUERY(abs_timeout)+10);
#endif
}

void post_create () {
  if (QUERY(abs_engage))
    call_out (restart_if_stuck,10);
  if (QUERY(suicide_engage))
    call_out (restart,60*60*24*QUERY(suicide_timeout));
}

void create()
{
  ::create();
  
  catch
  {
    module_stat_cache = decode_value(Stdio.read_bytes(QUERY(ConfigurationStateDir) + ".module_stat_cache"));
    allmodules = decode_value(Stdio.read_bytes(QUERY(ConfigurationStateDir) + ".allmodules"));
  };
  add_constant("roxen", this_object()); /* Roxen compat */
  add_constant("caudium", this_object());
  add_constant("load",    load);
  add_constant("__caudium_version__", __caudium_version__);
  add_constant("__caudium_build__", __caudium_build__);
  
  Configuration = (program)"configuration";
  call_out(post_create,1); //we just want to delay some things a little
}


// This is the most likely URL for a virtual server. Again, this
// should move into the actual 'configuration' object. It is not all
// that nice to have all this code lying around in here.

private string get_my_url()
{
  string s;
#if efun(gethostname)
  s = (gethostname()/".")[0] + "." + query("Domain");
#else
  s = "localhost";
#endif
  s -= "\n";
  return "http://" + s + "/";
}

// Set the uid and gid to the ones requested by the user. If the sete*
// functions are available, and the define SET_EFFECTIVE is enabled,
// the euid and egid is set. This might be a minor security hole, but
// it will enable caudium to start CGI scripts with the correct
// permissions (the ones the owner of that script have).

int set_u_and_gid()
{
#ifndef __NT__
  string u, g;
  int uid, gid;
  array pw;
  
  u=QUERY(User);
  sscanf(u, "%s:%s", u, g);
  if(strlen(u))
  {
    if(getuid())
    {
      report_error ("It is only possible to change uid and gid if the server "
		    "is running as root.\n");
    } else {
      if (g) {
#if constant(getgrnam)
	pw = getgrnam (g);
	if (!pw)
	  if (sscanf (g, "%d", gid)) pw = getgrgid (gid), g = (string) gid;
	  else report_error ("Couldn't resolve group " + g + ".\n"), g = 0;
	if (pw) g = pw[0], gid = pw[2];
#else
	if (!sscanf (g, "%d", gid))
	  report_warning ("Can't resolve " + g + " to gid on this system; "
			  "numeric gid required.\n");
#endif
      }

      pw = getpwnam (u);
      if (!pw)
	if (sscanf (u, "%d", uid)) pw = getpwuid (uid), u = (string) uid;
	else {
	  report_error ("Couldn't resolve user " + u + ".\n");
	  return 0;
	}
      if (pw) {
	u = pw[0], uid = pw[2];
	if (!g) gid = pw[3];
      }

#ifdef THREADS
      object mutex_key;
      catch { mutex_key = euid_egid_lock->lock(); };
#if constant(_disable_threads)
      object threads_disabled = _disable_threads();
#endif
#endif

#if constant(seteuid)
      if (geteuid() != getuid()) seteuid (getuid());
#endif
#if constant(initgroups)
      catch {
	initgroups(pw[0], gid);
	// Doesn't always work - David.
      };
#endif

      string permanently = "";
      if (
#ifdef SET_EFFECTIVE
	QUERY(permanent_uid)
#else
	1
#endif
      ) {
	permanently = " permanently";
#if constant(setuid)
	if (g) {
#  if constant(setgid)
	  setgid(gid);
	  if (getgid() != gid) report_error ("Failed to set gid.\n"), g = 0;
#  else
	  report_warning ("Setting gid not supported on this system.\n");
	  g = 0;
#  endif
	}
	setuid(uid);
	if (getuid() != uid) report_error ("Failed to set uid.\n"), u = 0;
#else
	report_warning ("Setting uid not supported on this system.\n");
	u = g = 0;
#endif
      }
      else {
#if constant(seteuid)
	if (g) {
#  if constant(setegid)
	  setegid(gid);
	  if (getegid() != gid) report_error ("Failed to set effective gid.\n"), g = 0;
#  else
	  report_warning ("Setting effective gid not supported on this system.\n");
	  g = 0;
#  endif
	}
	seteuid(uid);
	if (geteuid() != uid) report_error ("Failed to set effective uid.\n"), u = 0;
#else
	report_warning ("Setting effective uid not supported on this system.\n");
	u = g = 0;
#endif
      }

      if (u) report_notice("Setting uid to "+uid+" ("+u+")"+
			   (g ? " and gid to "+gid+" ("+g+")" : "")+
			   permanently+".\n");
      return !!u;
    }
  }
#endif
  return 0;
}

static mapping __vars = ([ ]);

// These two should be documented somewhere. They are to be used to
// set global, but non-persistent, variables in Caudium. By using
// these functions modules can "communicate" with one-another. This is
// not really possible otherwise.
mixed set_var(string var, mixed to)
{
  return __vars[var] = to;
}

mixed query_var(string var)
{
  return __vars[var];
}


void reload_all_configurations()
{
  object conf;
  array (object) new_confs = ({});
  mapping config_cache = ([]);
  //  werror(sprintf("%O\n", caudium->config_stat_cache));
  int modified;

  report_notice("Reloading configuration files from disk\n");
  caudium->configs = ([]);
  caudium->setvars(caudium->retrieve("Variables", 0));
  caudium->initiate_configuration_port( 0 );

  foreach(caudium->list_all_configurations(), string config)
  {
    array err, st;
    foreach(caudium->configurations, conf)
    {
      if(lower_case(conf->name) == lower_case(config))
      {
	break;
      } else
	conf = 0;
    }
    if(!(st = caudium->config_is_modified(config))) {
      if(conf) {
	config_cache[config] = caudium->config_stat_cache[config];
	new_confs += ({ conf });
      }
      continue;
    }
    modified = 1;
    config_cache[config] = st;
    if(conf) {
      // Closing ports...
      if (conf->server_ports) {
	// Roxen 1.2.26 or later
	Array.map(values(conf->server_ports), conf->do_dest);
      } else {
	Array.map(indices(conf->open_ports), conf->do_dest);
      }
      conf->stop();
      conf->invalidate_cache();
      conf->modules = ([]);
      conf->create(conf->name);
    } else {
      if(err = catch
      {
	conf = caudium->enable_configuration(config);
      }) {
	report_error("Error while enabling configuration "+config+":\n"+
		     describe_backtrace(err)+"\n");
	continue;
      }
    }
    if(err = catch
    {
      conf->start();
      conf->enable_all_modules();
    }) {
      report_error("Error while enabling configuration "+config+":\n"+
		   describe_backtrace(err)+"\n");
      continue;
    }
    new_confs += ({ conf });
  }
    
  foreach(caudium->configurations - new_confs, conf)
  {
    modified = 1;
    report_notice("Disabling old configuration "+conf->name+"\n");
    if (conf->server_ports) {
      // Roxen 1.2.26 or later
      Array.map(values(conf->server_ports), conf->do_dest);
    } else {
      Array.map(indices(conf->open_ports), conf->do_dest);
    }
    conf->stop();
    destruct(conf);
  }
  if(modified) {
    caudium->configurations = new_confs;
    caudium->config_stat_cache = config_cache;
    caudium->unload_configuration_interface();
  }
}

object enable_configuration(string name)
{
  object cf = Configuration(name);
  configurations += ({ cf });
  current_configuration = cf;
  report_notice("Enabled the virtual server \""+name+"\".\n");
  
  return cf;
}


// return the URL of the configuration interface. This is not as easy
// as it sounds, unless the administrator has entered it somewhere.

public string config_url(void|object id)
{
  int p;
  string prot;
  string host;
  if(id && id->request_headers->host) {
    string p = ":80", url="/";
    prot = "http://";
    if(id->ssl_accept_callback) {
      // This is an SSL port. Not a great check, but what is one to do?
      p = ":443";
      prot = "https://";
    }
    return prot+id->request_headers->host+url;
  }  else if(strlen(QUERY(ConfigurationURL)-" "))
    return QUERY(ConfigurationURL)-" ";

  array ports = QUERY(ConfigPorts), port, tmp;

  if(!sizeof(ports)) return "CONFIG";

  foreach(ports, tmp)
    if(tmp[1][0..2]=="ssl") 
    {
      port=tmp; 
      break;
    }

  if(!port)
    foreach(ports, tmp)
      if(tmp[1]=="http") 
      {
	port=tmp; 
	break;
      }

  if(!port) port=ports[0];

  if(port[2] == "ANY")
//  host = quick_ip_to_host( port[2] );
// else
  {
#if efun(gethostname)
    host = gethostname();
#else
    host = "127.0.0.1";
#endif
  }

  switch(port[1][..2]) {
  case "ssl":
    prot = "https";
    break;
  case "ftp":
    prot = "ftp";
    break;
  default:
    prot = port[1];
    break;
  }
  p = port[0];

  return (prot+"://"+host+":"+p+"/");
}


// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.
  
int cache_disabled_p() { return !QUERY(cache);         }
int syslog_disabled()  { return QUERY(LogA)!="syslog"; }
int range_disabled_p() { return !QUERY(EnableRangeHandling);  }

class ImageCache
{
  string name;
  string dir;
  function draw_function;
  mapping data_cache = ([]); // not normally used.
  mapping meta_cache = ([]);


  static mapping meta_cache_insert( string i, mapping what )
  {
    return meta_cache[i] = what;
  }
  
  static string data_cache_insert( string i, string what )
  {
    return data_cache[i] = what;
  }

  static mixed frommapp( mapping what )
  {
    if( what[""] ) return what[""];
    return what;
  }

  static void draw( string name, object id )
  {
    mixed args = Array.map( Array.map( name/"$", argcache->lookup,
				       id->useragent), frommapp);
    mapping meta;
    string data;
    mixed reply = draw_function( @copy_value(args), id );

    if( arrayp( args ) )
      args = args[0];


    if( objectp( reply ) || (mappingp(reply) && reply->img) )
    {
      int quant = (int)args->quant;
      string format = lower_case(args->format || "gif");
      string dither = args->dither;
      object ct;
      object alpha;
      int true_alpha; 

      if( args->fs  || dither == "fs" )
	dither = "floyd_steinberg";

      if(  dither == "random" )
	dither = "random_dither";

      if( format == "jpg" ) 
        format = "jpeg";

      if(mappingp(reply))
      {
        alpha = reply->alpha;
        reply = reply->img;
      }
      
      if( args->gamma )
        reply = reply->gamma( (float)args->gamma );

      if( args["true-alpha"] )
        true_alpha = 1;

      if( args["opaque-value"] )
      {
        true_alpha = 1;
        int ov = (int)(((float)args["opaque-value"])*2.55);
        if( ov < 0 )
          ov = 0;
        else if( ov > 255 )
          ov = 255;
        if( alpha )
        {
          object i = Image.image( reply->xsize(), reply->ysize(), ov,ov,ov );
          i->paste_alpha( alpha, ov );
          alpha = i;
        }
        else
        {
          alpha = Image.image( reply->xsize(), reply->ysize(), ov,ov,ov );
        }
      }

      if( args->scale )
      {
        int x, y;
        if( sscanf( args->scale, "%d,%d", x, y ) == 2)
        {
          reply = reply->scale( x, y );
          if( alpha )
            alpha = alpha->scale( x, y );
        }
        else if( (float)args->scale < 3.0)
        {
          reply = reply->scale( ((float)args->scale) );
          if( alpha )
            alpha = alpha->scale( ((float)args->scale) );
        }
      }

      if( args->maxwidth || args->maxheight )
      {
        int x = (int)args->maxwidth, y = (int)args->maxheight;
        if( x && reply->xsize() > x )
        {
          reply = reply->scale( x, 0 );
          if( alpha )
            alpha = alpha->scale( x, 0 );
        }
        if( y && reply->ysize() > y )
        {
          reply = reply->scale( 0, y );
          if( alpha )
            alpha = alpha->scale( 0, y );
        }
      }

      if( quant || (format=="gif") )
      {
        int ncols = quant||id->misc->defquant||16;
        if( ncols > 250 )
          ncols = 250;
        ct = Image.colortable( reply, ncols );
        if( dither )
          if( ct[ dither ] )
            ct[ dither ]();
          else
            ct->ordered();
      }

      if(!Image[upper_case( format )] 
         || !Image[upper_case( format )]->encode )
        error("Image format "+format+" unknown\n");

      mapping enc_args = ([]);
      if( ct )
        enc_args->colortable = ct;
      if( alpha )
        enc_args->alpha = alpha;

      foreach( glob( "*-*", indices(args)), string n )
        if(sscanf(n, "%*[^-]-%s", string opt ) == 2)
          enc_args[opt] = (int)args[n];

      switch(format)
      {
#if constant(Image.GIF.encode)
       case "gif":
         if( alpha && true_alpha )
         {
           object ct=Image.colortable( ({ ({ 0,0,0 }), ({ 255,255,255 }) }) );
           ct->floyd_steinberg();
           alpha = ct->map( alpha );
         }
         if( catch {
           if( alpha )
             data = Image.GIF.encode_trans( reply, ct, alpha );
           else
             data = Image.GIF.encode( reply, ct );
         })
           data = Image.GIF.encode( reply );
         break;
#endif
       case "png":
         if( ct )
           enc_args->palette = ct;
         m_delete( enc_args, "colortable" );
       default:
        data = Image[upper_case( format )]->encode( reply, enc_args );
      }

      meta = ([ 
        "xsize":reply->xsize(),
        "ysize":reply->ysize(),
        "type":"image/"+format,
      ]);
    }
    else if( mappingp(reply) ) 
    {
      meta = reply->meta;
      data = reply->data;
      if( !meta || !data )
        error("Invalid reply mapping.\n"
              "Should be ([ \"meta\": ([metadata]), \"data\":\"data\" ])\n");
    }
    store_meta( name, meta );
    store_data( name, data );
  }


  static void store_meta( string id, mapping meta )
  {
    meta_cache_insert( id, meta );

    string data = encode_value( meta );
    Stdio.File f = Stdio.File(  dir+id+".i", "wct" );
    if(!f) 
    {
      report_error( "Failed to open image cache persistant cache file "+
                    dir+id+".i: "+strerror( errno() )+ "\n" );
      return;
    }
    f->write( data );
  }

  static void store_data( string id, string data )
  {
    Stdio.File f = Stdio.File(  dir+id+".d", "wct" );
    if(!f) 
    {
      data_cache_insert( id, data );
      report_error( "Failed to open image cache persistant cache file "+
                    dir+id+".d: "+strerror( errno() )+ "\n" );
      return;
    }
    f->write( data );
  }


  static mapping restore_meta( string id )
  {
    Stdio.File f;
    if( meta_cache[ id ] )
      return meta_cache[ id ];
    f = Stdio.File( );
    if( !f->open(dir+id+".i", "r" ) )
      return 0;
    return meta_cache_insert( id, decode_value( f->read() ) );
  }

  static mapping restore( string id )
  {
    string|object(Stdio.File) f;
    mapping m;
    if( data_cache[ id ] )
      f = data_cache[ id ];
    else 
      f = Stdio.File( );

    if(!f->open(dir+id+".d", "r" ))
      return 0;

    m = restore_meta( id );
    
    if(!m)
      return 0;

    if( stringp( f ) )
      return http_string_answer( f, m->type||("image/gif") );
    return caudiump()->http_file_answer( f, m->type||("image/gif") );
  }


  string data( string|mapping args, object id, int|void nodraw )
  {
    string na = store( args, id );
    mixed res;

    if(!( res = restore( na )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      res = restore( na );
    }
    if( res->file )
      return res->file->read();
    return res->data;
  }

  mapping http_file_answer( string|mapping data, object id, int|void nodraw )
  {
    string na = store( data,id );
    mixed res;
    if(!( res = restore( na )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      res = restore( na );
    }
    return res;
  }

  mapping metadata( string|mapping data, object id, int|void nodraw )
  {
    string na = store( data,id );
    if(!restore_meta( na ))
    {
      if(nodraw)
        return 0;
      draw( na, id );
      return restore_meta( na );
    }
    return restore_meta( na );
  }

  mapping tomapp( mixed what )
  {
    if( mappingp( what ))
      return what;
    return ([ "":what ]);
  }

  string store( array|string|mapping data, object id )
  {
    string ci;
    if( mappingp( data ) )
      ci = argcache->store( data );
    else if( arrayp( data ) )
      ci = Array.map( Array.map( data, tomapp ), argcache->store )*"$";
    else
      ci = data;
    return ci;
  }

  void set_draw_function( function to )
  {
    draw_function = to;
  }

  void create( string id, function draw_func, string|void d )
  {
    if(!d) d = caudiump()->QUERY(argument_cache_dir);
    if( d[-1] != '/' )
      d+="/";
    d += id+"/";

    mkdirhier( d+"foo");

    dir = d;
    name = id;
    draw_function = draw_func;
  }
}


class ArgCache
{
  static string name;
  static string path;
  static int is_db;
  static object db;

#define CACHE_VALUE 0
#define CACHE_SKEY  1
#define CACHE_SIZE  600
#define CLEAN_SIZE  100

#ifdef THREADS
  static Thread.Mutex mutex = Thread.Mutex();
# define LOCK() object __key = mutex->lock()
#else
# define LOCK() 
#endif

  static mapping (string:mixed) cache = ([ ]);

  void setup_table()
  {
    if(catch(db->query("select id from "+name+" where id=-1")))
      if(catch(db->query("create table "+name+" ("
                         "id int auto_increment primary key, "
                         "lkey varchar(80) not null default '', "
                         "contents blob not null default '', "
                         "atime bigint not null default 0)")))
        throw("Failed to create table in database\n");
  }

  void create( string _name, 
               string _path, 
               int _is_db )
  {
    name = _name;
    path = _path;
    is_db = _is_db;

    if(is_db)
    {
      db = Sql.sql( path );
      if(!db)
        error("Failed to connect to database for argument cache\n");
      setup_table( );
    } else {
      if(path[-1] != '/' && path[-1] != '\\')
        path += "/";
      path += replace(name, "/", "_")+"/";
      mkdirhier( path + "/tmp" );
      object test = Stdio.File();
      if (!test->open (path + "/.testfile", "wc"))
	error ("Can't create files in the argument cache directory " + path + "\n");
      else {
	test->close();
	rm (path + "/.testfile");
      }
    }
  }

  static string read_args( string id )
  {
    if( is_db )
    {
      mapping res = db->query("select contents from "+name+" where id='"+id+"'");
      if( sizeof(res) )
      {
        db->query("update "+name+" set atime='"+
                  time()+"' where id='"+id+"'");
        return res[0]->contents;
      }
      return 0;
    } else {
      if( file_stat( path+id ) )
        return Stdio.read_bytes(path+"/"+id);
    }
    return 0;
  }

  static string create_key( string long_key )
  {
    if( is_db )
    {
      array(mapping) data =
	db->query(sprintf("select id,contents from %s where lkey='%s'",
			  name,long_key[..79]));
      foreach( data, mapping m )
        if( m->contents == long_key )
          return m->id;

      db->query( sprintf("insert into %s (contents,lkey,atime) values "
                         "('%s','%s','%d')", 
                         name, long_key, long_key[..79], time() ));
      return create_key( long_key );
    } else {
      string _key=MIME.encode_base64(Crypto.md5()->update(long_key)->digest(),1);
      _key = replace(_key-"=","/","=");
      string short_key = _key[0..1];

      while( file_stat( path+short_key ) )
      {
        if( Stdio.read_bytes( path+short_key ) == long_key )
          return short_key;
        short_key = _key[..strlen(short_key)];
        if( strlen(short_key) >= strlen(_key) )
          short_key += "."; // Not very likely...
      }
      object f = Stdio.File( path + short_key, "wct" );
      f->write( long_key );
      return short_key;
    }
  }


  int key_exists( string key )
  {
    LOCK();
    if( !is_db ) 
      return !!file_stat( path+key );
    return !!read_args( key );
  }

  string store( mapping args )
  {
    LOCK();
    array b = values(args), a = sort(indices(args),b);
    string data = MIME.encode_base64(encode_value(({a,b})),1);

    if( cache[ data ] )
      return cache[ data ][ CACHE_SKEY ];

    if( sizeof( cache ) >= CACHE_SIZE )
    {
      array i = indices(cache);
      while( sizeof(cache) > CACHE_SIZE-CLEAN_SIZE ) {
        string idx=i[random(sizeof(i))];
        if(arrayp(cache[idx])) {
          m_delete( cache, cache[idx][CACHE_SKEY] );
          m_delete( cache, idx );
        }
        else {
          m_delete( cache, cache[idx] );
          m_delete( cache, idx );
        }
      }
    }

    string id = create_key( data );
    cache[ data ] = ({ 0, 0 });
    cache[ data ][ CACHE_VALUE ] = copy_value( args );
    cache[ data ][ CACHE_SKEY ] = id;
    cache[ id ] = data;
    return id;
  }

  mapping lookup( string id, void|string client)
  {
    LOCK();
    if(cache[id])
      return cache[cache[id]][CACHE_VALUE];

    string q = read_args( id );

    if(!q) error("Key does not exist! (Thinks "+ (client||"") +")\n");
    mixed data = decode_value(MIME.decode_base64( q ));
    data = mkmapping( data[0],data[1] );

    cache[ q ] = ({0,0});
    cache[ q ][ CACHE_VALUE ] = data;
    cache[ q ][ CACHE_SKEY ] = id;
    cache[ id ] = q;
    return data;
  }

  void delete( string id )
  {
    LOCK();
    if(cache[id])
    {
      m_delete( cache, cache[id] );
      m_delete( cache, id );
    }
    if( is_db )
      db->query( "delete from "+name+" where id='"+id+"'" );
    else
      rm( path+id );
  }
}


array(int) invert_color(array color )
{
  return ({ 255-color[0], 255-color[1], 255-color[2] });
}


mapping low_decode_image(string data, void|array tocolor)
{
  Image.image i, a;
  string format;
  if(!data)
    return 0; 

#if constant(Image.GIF._decode)  
  // Use the low-level decode function to get the alpha channel.
  catch
  {
    array chunks = Image.GIF._decode( data );

    // If there is more than one render chunk, the image is probably
    // an animation. Handling animations is left as an exercise for
    // the reader. :-)
    foreach(chunks, mixed chunk)
      if(arrayp(chunk) && chunk[0] == Image.GIF.RENDER )
        [i,a] = chunk[3..4];
    format = "GIF";
  };

  if(!i) catch
  {
    i = Image.GIF.decode( data );
    format = "GIF";
  };
#endif

#if constant(Image.JPEG) && constant(Image.JPEG.decode)
  if(!i) catch
  {
    i = Image.JPEG.decode( data );
    format = "JPEG";
  };

#endif

#if constant(Image.XCF) && constant(Image.XCF._decode)
  if(!i) catch
  {
    mixed q = Image.XCF._decode( data, ([
      "background":tocolor,
      ]));
    tocolor=0;
    format = "XCF Gimp file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PSD) && constant(Image.PSD._decode)
  if(!i) catch
  {
    mixed q = Image.PSD._decode( data, ([
      "background":tocolor,
      ]));
    tocolor=0;
    format = "PSD Photoshop file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PNG) && constant(Image.PNG._decode)
  if(!i) catch
  {
    mixed q = Image.PNG._decode( data );
    format = "PNG";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.BMP) && constant(Image.BMP._decode)
  if(!i) catch
  {
    mixed q = Image.BMP._decode( data );
    format = "Windows bitmap file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.TGA) && constant(Image.TGA._decode)
  if(!i) catch
  {
    mixed q = Image.TGA._decode( data );
    format = "Targa";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PCX) && constant(Image.PCX._decode)
  if(!i) catch
  {
    mixed q = Image.PCX._decode( data );
    format = "PCX";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XBM) && constant(Image.XBM._decode)
  if(!i) catch
  {
    mixed q = Image.XBM._decode( data, (["bg":tocolor||({255,255,255}),
                                    "fg":invert_color(tocolor||({255,255,255})) ]));
    format = "XBM";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XPM) && constant(Image.XPM._decode)
  if(!i) catch
  {
    mixed q = Image.XPM._decode( data );
    format = "XPM";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.TIFF) && constant(Image.TIFF._decode)
  if(!i) catch
  {
    mixed q = Image.TIFF._decode( data );
    format = "TIFF";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.ILBM) && constant(Image.ILBM._decode)
  if(!i) catch
  {
    mixed q = Image.ILBM._decode( data );
    format = "ILBM";
    i = q->image;
    a = q->alpha;
  };
#endif


#if constant(Image.PS) && constant(Image.PS._decode)
  if(!i) catch
  {
    mixed q = Image.PS._decode( data );
    format = "Postscript";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XWD) && constant(Image.XWD.decode)
  if(!i) catch
  {
    i = Image.XWD.decode( data );
    format = "XWD";
  };
#endif

#if constant(Image.HRZ) && constant(Image.HRZ._decode)
  if(!i) catch
  {
    mixed q = Image.HRZ._decode( data );
    format = "HRZ";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.AVS) && constant(Image.AVS._decode)
  if(!i) catch
  {
    mixed q = Image.AVS._decode( data );
    format = "AVS X";
    i = q->image;
    a = q->alpha;
  };
#endif

  if(!i)
    catch{
      i = Image.PNM.decode( data );
      format = "PNM";
    };

  if(!i) // No image could be decoded at all. 
    return 0;

  if( tocolor && i && a )
  {
    object o = Image.image( i->xsize(), i->ysize(), @tocolor );
    o->paste_mask( i,a );
    i = o;
  }

  return ([
    "format":format,
    "alpha":a,
    "img":i,
  ]);
}

mapping low_load_image(string f,object id)
{
  string data;
  object file, img;
  if(id->misc->_load_image_called < 5) 
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data)  return 0;
  return low_decode_image( data );
}

object load_image(string f,object id)
{
  mapping q = low_load_image( f, id );
  if( q ) return q->img;
  return 0;
}


private void define_global_variables( int argc, array (string) argv )
{
  int p;
  globvar("set_cookie", 0, "Set unique user id cookies", TYPE_FLAG,
	  "If set to Yes, all users of your server whose clients support "
	  "cookies will get a unique 'user-id-cookie', this can then be "
	  "used in the log and in scripts to track individual users.");

  globvar("set_cookie_only_once",1,"Set ID cookies only once",TYPE_FLAG,
	  "If set to Yes, Caudium will attempt to set unique user ID cookies "
	  "only upon receiving the first request (and again after some "
	  "minutes). Thus, if the user doesn't allow the cookie to be set, "
	  "he won't be bothered with multiple requests.",0,
	  lambda() {return !QUERY(set_cookie);});

  globvar("show_internals", 1, "Show the internals", TYPE_FLAG,
	  "Show 'Internal server error' messages to the user. "
	  "This is very useful if you are debugging your own modules "
	  "or writing Pike scripts.");
  
  globvar("RestoreConnLogFull", 0,
	  "Range: Log entire file length in restored connections",
	  TYPE_TOGGLE,
	  "If this toggle is enabled log entries for restored connections "
	  "will log the amount of sent data plus the restoration location. "
	  "Ie if a user has downloaded 100 bytes of a file already, and makes "
	  "a Range request fetching the remaining 900 bytes, the log entry "
	  "will log it as if the entire 1000 bytes were downloaded. "
	  "<p>This is useful if you want to know if downloads were successful "
	  "(the user has the complete file downloaded). The drawback is that "
	  "bandwidth statistics on the log file will be incorrect. The "
	  "statistics in Caudium will continue being correct.", 0,
	  range_disabled_p); 

  globvar("EnableRangeHandling", 1, "Range: Enable range handling",
	  TYPE_TOGGLE,
	  "Enable handling of the range headers. This allows browsers to "
	  "download partial files. Mostly used to continue interrupted "
	  "connections. It might be desirable to disable this feature since "
	  "some download programs like to open a number of connections each "
	  "downloading a separate part of a file.");	

  // Hidden variables (compatibility ones, or internal or too
  // dangerous
  /*  globvar("BS", 0, "Configuration interface: Compact layout",*/
  /*	  TYPE_FLAG|VAR_EXPERT,*/
  /*	  "Sick and tired of all those images? Set this variable to 'Yes'!");*/
  /*  globvar("BG", 1,  "Configuration interface: Background",*/
  /*	  TYPE_FLAG|VAR_EXPERT,*/
  /*	  "Should the background be set by the configuration interface?");*/

//   globvar("_v", CONFIGURATION_FILE_LEVEL, 0, TYPE_INT, 0, 0, 1);
  globvar("default_font_size", 32, 0, TYPE_INT, 0, 0, 1);


  globvar("default_font", "lucida", "Fonts: Default font", TYPE_FONT,
	  "The default font to use when modules request a font.");

  globvar("font_dirs", ({"../local/nfonts/", "nfonts/" }),
	  "Fonts: Font directories", TYPE_DIR_LIST,
	  "This is where the fonts are located.");

  globvar("logdirprefix", "../logs/", "Log directory prefix",
	  TYPE_DIR|VAR_MORE,
	  "This is the default file path that will be prepended to the log "
	  " file path in all the default modules and the virtual server.");
  

  // Cache variables. The actual code recides in the file
  // 'disk_cache.pike'
  
  globvar("cache", 0, "Proxy disk cache: Enabled", TYPE_FLAG,
	  "If set to Yes, caching will be enabled.");
  
  globvar("garb_min_garb", 1, "Proxy disk cache: Clean size", TYPE_INT,
	  "Minimum number of Megabytes removed when a garbage collect is done.",
	  0, cache_disabled_p);

  globvar("cache_minimum_left", 5, "Proxy disk cache: Minimum "
	  "available free space and inodes (in %)", TYPE_INT,
	  "If less than this amount of disk space or inodes (in %) is left, "
	  "the cache will remove a few files. This check may work "
	  "half-hearted if the diskcache is spread over several filesystems.",
	  0,
#if efun(filesystem_stat)
	  cache_disabled_p
#else
	  1
#endif /* filesystem_stat */
	  );
  
  globvar("cache_size", 25, "Proxy disk cache: Size", TYPE_INT,
	  "How many MB may the cache grow to before a garbage collect is done?",
	  0, cache_disabled_p);

  globvar("cache_max_num_files", 0, "Proxy disk cache: Maximum number "
	  "of files", TYPE_INT, "How many cache files (inodes) may "
	  "be on disk before a garbage collect is done ? May be left "
	  "zero to disable this check.",
	  0, cache_disabled_p);
  
  globvar("bytes_per_second", 50, "Proxy disk cache: Bytes per second", 
	  TYPE_INT,
	  "How file size should be treated during garbage collect. "
	  " Each X bytes counts as a second, so that larger files will"
	  " be removed first.",
	  0, cache_disabled_p);

  globvar("cachedir", "/tmp/caudium_cache/",
	  "Proxy disk cache: Base Cache Dir",
	  TYPE_DIR,
	  "This is the base directory where cached files will reside. "
	  "To avoid mishaps, 'caudium_cache/' is always prepended to this "
	  "variable.",
	  0, cache_disabled_p);

  globvar("hash_num_dirs", 500,
	  "Proxy disk cache: Number of hash directories",
	  TYPE_INT,
	  "This is the number of directories to hash the contents of the disk "
	  "cache into.  Changing this value currently invalidates the whole "
	  "cache, since the cache cannot find the old files.  In the future, "
	  " the cache will be recalculated when this value is changed.",
	  0, cache_disabled_p); 
  
  globvar("cache_keep_without_content_length", 1, "Proxy disk cache: "
	  "Keep without Content-Length", TYPE_FLAG, "Keep files "
	  "without Content-Length header information in the cache?",
	  0, cache_disabled_p);

  globvar("cache_check_last_modified", 0, "Proxy disk cache: "
	  "Refresh on Last-Modified", TYPE_FLAG,
	  "If set, refreshes files without Expire header information "
	  "when they have reached double the age they had when they got "
	  "cached. This may be useful for some regularly updated docs as "
	  "online newspapers.",
	  0, cache_disabled_p);

  globvar("cache_last_resort", 0, "Proxy disk cache: "
	  "Last resort (in days)", TYPE_INT,
	  "How many days shall files without Expires and without "
	  "Last-Modified header information be kept?",
	  0, cache_disabled_p);

  globvar("cache_gc_logfile",  "",
	  "Proxy disk cache: "
	  "Garbage collector logfile", TYPE_FILE,
	  "Information about garbage collector runs, removed and refreshed "
	  "files, cache and disk status goes here.",
	  0, cache_disabled_p);

  /// End of cache variables..
  
  globvar("docurl2", "http://www.roxen.com/documentation/context.pike?page=",
	  "Documentation URL", TYPE_STRING|VAR_MORE|VAR_EXPERT,
	  "The URL to prepend to all documentation urls throughout the "
	  "server. This URL should _not_ end with a '/'.");

  globvar("pidfile", "/tmp/caudium_pid", "PID file",
	  TYPE_FILE|VAR_MORE,
	  "In this file, the server will write out it's PID, and the PID "
	  "of the start script. $pid will be replaced with the pid, and "
	  "$uid with the uid of the user running the process.");

  globvar("identversion", 1, "Version numbers: Show Caudium Version Number ",
	  TYPE_FLAG, "The default behavior is to display the Caudium "
	  "version number in the Server field in HTTP responses. You can "
	  "disable it here for security reasons, since it might be easier "
	  "to crack a server if the exact version is known.");

  globvar("identpikever", 1, "Version numbers: Show Pike Version Number ",
          TYPE_FLAG, "The default behavior is to display the Pike "
	  "version number in the X-Got-Fish header in HTTP HEAD response. "
	  "You can disable it here for security reasons, since it might be "
	  "easier to exploit any possible bugs in the specific Pike version "
	  "used on your server.");

  globvar("DOC", 1, "Configuration interface: Help texts", TYPE_FLAG|VAR_MORE,
	  "Do you want documentation? (this is an example of documentation)");


  globvar("NumAccept", 1, "Number of accepts to attempt",
	  TYPE_INT_LIST|VAR_MORE,
	  "You can here state the maximum number of accepts to attempt for "
	  "each read callback from the main socket. <p> Increasing this value "
	  "will make the server "
	  "faster for users making many simultaneous connections to it, or"
	  " if you have a very busy server. <p> It won't work on some systems"
	  ", though, eg. IBM AIX 3.2<p> To see if it works, change this"
	  " variable, <b> but don't press save</b>, and then try connecting to"
	  " your server. If it works, come back here and press the save button"
	  ". <p> If it doesn't work, just restart the server and be happy "
	  "with having '1' in this field.<p>"
	  "The higher you set this value, the less load balancing between "
	  "virtual servers. (If there are 256 more or less simultaneous "
	  "requests to server 1, and one to server 2, and this variable is "
	  "set to 256, the 256 accesses to the first server might very well "
	  "be handled before the one to the second server.)",
	  ({ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));
  

  globvar("ConfigPorts", ({ ({ 22202, "http", "ANY", "" }) }),
	  "Configuration interface: Ports",
	  TYPE_PORTS,
	  "These are the ports through which you can configure the "
	  "server.<br>Note that you should at least have one open port, since "
	  "otherwise you won't be able to configure your server.");
  
  globvar("ConfigurationURL", 
	  "",
          "Configuration interface: URL", TYPE_STRING,
	  "The URL of the configuration interface. This is used to "
	  "generate redirects now and then (when you press save, when "
	  "a module is added, etc.).");
  
  globvar("ConfigurationPassword", "", "Configuration interface: Password", 
	  TYPE_PASSWORD|VAR_EXPERT,
	  "The password you will have to enter to use the configuration "
	  "interface. Please note that changing this password in the "
	  "configuration interface will _not_ require an additional entry "
	  "of the password, so it is easy to make a typo. It is recommended "
	  "that you use the <a href=/(changepass)/Globals/>form instead</a>.");
  
  globvar("ConfigurationUser", "", "Configuration interface: User", 
	  TYPE_STRING|VAR_EXPERT,
	  "The username you will have to enter to use the configuration "
	  "interface");
  
  globvar("ConfigurationIPpattern","*", "Configuration interface: IP-Pattern", 
	  TYPE_STRING|VAR_MORE,
	  "Only clients running on computers with IP numbers matching "
	  "this pattern will be able to use the configuration "
	  "interface.");

  globvar("ConfigurationStateDir","./", "Configuration interface: Status Directory",
          TYPE_DIR|VAR_MORE,
	  "Directory where the configuration interface keeps its state - module "
	  "cache, interface settings etc.");

  globvar("User", "", "Change uid and gid to", TYPE_STRING,
	  "When caudium is run as root, to be able to open port 80 "
	  "for listening, change to this user-id and group-id when the port "
	  " has been opened. If you specify a symbolic username, the "
	  "default group of that user will be used. "
	  "The syntax is user[:group].");

  globvar("permanent_uid", 0, "Change uid and gid permanently", 
	  TYPE_FLAG,
	  "If this variable is set, caudium will set it's uid and gid "
	  "permanently. This disables the 'exec script as user' fetures "
	  "for CGI, and also access files as user in the filesystems, but "
	  "it gives better security.");

  globvar("ModuleDirs", ({ "../local/modules/", "modules/" }),
	  "Module directories", TYPE_DIR_LIST,
	  "This is a list of directories where Caudium should look for "
	  "modules. Can be relative paths, from the "
	  "directory you started caudium, " + getcwd() + " this time."
	  " The directories are searched in order for modules.");
  
  globvar("Supports", "#include <etc/supports>\n", 
	  "Client supports regexps", TYPE_TEXT_FIELD|VAR_MORE,
	  "What do the different clients support?\n<br>"
	  "The default information is normally fetched from the file "+
	  getcwd()+"etc/supports, and the format is:<pre>"
	  //"<a href=$docurl/configuration/regexp.html>regular-expression</a>"
	  "regular-expression"
	  " feature, -feature, ...\n"
	  "</pre>"
	  "If '-' is prepended to the name of the feature, it will be removed"
	  " from the list of features of that client. All patterns that match"
	  " each given client-name are combined to form the final feature list"
	  ". See the file etc/supports for examples.");
  
  globvar("audit", 0, "Audit trail", TYPE_FLAG,
	  "If Audit trail is set to Yes, all changes of uid will be "
	  "logged in the Event log.");
  
#if efun(syslog)
  globvar("LogA", "file", "Logging method", TYPE_STRING_LIST|VAR_MORE, 
	  "What method to use for logging, default is file, but "
	  "syslog is also available. When using file, the output is really"
	  " sent to stdout and stderr, but this is handled by the "
	  "start script.",
	  ({ "file", "syslog" }));
  
  globvar("LogSP", 1, "Syslog: Log PID", TYPE_FLAG,
	  "If set, the PID will be included in the syslog.", 0,
	  syslog_disabled);
  
  globvar("LogCO", 0, "Syslog: Log to system console", TYPE_FLAG,
	  "If set and syslog is used, the error/debug message will be printed"
	  " to the system console as well as to the system log.",
	  0, syslog_disabled);
  
  globvar("LogST", "Daemon", "Syslog: Log type", TYPE_STRING_LIST,
	  "When using SYSLOG, which log type should be used.",
	  ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	     "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	  syslog_disabled);
  
  globvar("LogWH", "Errors", "Syslog: Log what", TYPE_STRING_LIST,
	  "When syslog is used, how much should be sent to it?<br><hr>"
	  "Fatal:    Only messages about fatal errors<br>"+
	  "Errors:   Only error or fatal messages<br>"+
	  "Warning:  Warning messages as well<br>"+
	  "Debug:    Debug messager as well<br>"+
	  "All:      Everything<br>",
	  ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	  syslog_disabled);
  
  globvar("LogNA", "Caudium", "Syslog: Log as", TYPE_STRING,
	  "When syslog is used, this will be the identification of the "
	  "Caudium daemon. The entered value will be appended to all logs.",
	  0, syslog_disabled);
#endif

#ifdef THREADS
  globvar("numthreads", 5, "Number of threads to run", TYPE_INT,
	  "The number of simultaneous threads caudium will use.\n"
	  "<p>Please note that even if this is one, Caudium will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i>");
#endif
  
  globvar("AutoUpdate", 1, "Update the supports database automatically",
	  TYPE_FLAG, 
	  "If set to Yes, the etc/supports file will be updated automatically "
	  "from caudium.net now and then. This is recomended, since "
	  "you will then automatically get supports information for new "
	  "clients, and new versions of old ones.");

  globvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);
  
#ifdef ENABLE_NEIGHBOURHOOD
  globvar("neighborhood", 0,
	  "Neighborhood: Register with other Caudium servers on the local network"
	  ,TYPE_FLAG|VAR_MORE,
	  "If this option is set, Caudium will automatically broadcast it's "
	  "existence to other Caudium servers on the local network.");

  globvar("neigh_tcp_ips",  ({}), "Neighborhood: TCP hosts",
  TYPE_STRING_LIST|VAR_MORE,
  "This is the list of direct host<-->host links to establish. "
  "The local host is always present (if the neighbourhood functionality "
  "is at all enabled).");


  globvar("neigh_ips",  ({lambda(){
			    catch {
			      mixed foo = gethostbyname(gethostname());
			      string n = reverse(foo[1][0]);
			      sscanf(n,"%*d.%s", n);
			      n=reverse(n)+".";
			      // Currently only defaults to C-nets..
			      return n+"255";
			    };
			    return "0.0.0.0";
			  }()}), "Neighborhood: Broadcast addresses", TYPE_STRING_LIST|VAR_MORE,
			  "");

  globvar("neigh_com", "", "Neighborhood: Server informational comment",
	  TYPE_TEXT|VAR_MORE, "A short string describing this server.");
#endif /* ENABLE_NEIGHBOURHOOD */  

  globvar("abs_engage", 0, "Anti-Block-System: Enable", TYPE_FLAG|VAR_MORE,
	  "If set, it will enable the anti-block-system. "
	  "This will restart the server after a configurable number of minutes if it "
	  "locks up. If you are running in a single threaded environment heavy calculations "
	  "will also halt the server. In multi-threaded mode bugs as eternal loops will not "
	  "cause the server to reboot, since only one thread is blocked. In general there is "
	  "no harm in having this option enabled. ");

  globvar("abs_timeout", 5, "Anti-Block-System: Timeout", TYPE_INT_LIST | VAR_MORE,
	  "If the server is unable to accept connection for this many "
	  "minutes, it will be restarted. You need to find a balance: "
	  "if set too low, the server will be restarted even if it's doing "
	  "legal things (like generating many images), if set too high you will "
	  "have long downtimes.",
	  ({1,2,3,4,5,10,15}),
	  lambda() {return !QUERY(abs_engage);}
	  );
	
  globvar ("suicide_engage",
	   0,
	   "Automatic Restart: Enable",
	   TYPE_FLAG|VAR_MORE,
	   "If set, Caudium will automatically restart after a configurable number "
	   "of days. Since Caudium uses a monolith, non-forking server "
	   "model the process tends to grow in size over time. This is mainly due to "
	   "heap fragmentation but also because of memory leaks."
	   );

  globvar("suicide_timeout",
	  7,
	  "Automatic Restart: Timeout",
	  TYPE_INT_LIST|VAR_MORE,
	  "Automatically restart the server after this many days.",
	  ({1,2,3,4,5,6,7,14,30}),
	  lambda(){return !QUERY(suicide_engage);}
	  );

  globvar("argument_cache_in_db", 0, 
         "Argument Cache: Store the argument cache in a mysql database",
         TYPE_FLAG|VAR_MORE,
         "If set, store the argument cache in a mysql "
         "database. This is very useful for load balancing using multiple "
         "caudium servers, since the mysql database will handle "
          " synchronization"); 

  globvar( "argument_cache_db_path", "mysql://localhost/caudium", 
          "Argument Cache: Database URL to use",
          TYPE_STRING|VAR_MORE,
          "The database to use to store the argument cache",
          0,
          lambda(){ return !QUERY(argument_cache_in_db); });

  globvar( "argument_cache_dir", "../argument_cache/", 
          "Argument Cache: Cache directory",
          TYPE_DIR|VAR_MORE,
          "The cache directory to use to store the argument cache."
          " Please note that load balancing is not available for most modules "
          " (such as gtext, diagram etc) unless you use a mysql database to "
          "store the argument caches",
          0,
          lambda(){ return QUERY(argument_cache_in_db); });

  setvars(retrieve("Variables", 0));

  for(p = 1; p < argc; p++)
  {
    string c, v;
    if(sscanf(argv[p],"%s=%s", c, v) == 2)
      if(variables[c])
	  variables[c][VAR_VALUE]=compile_string(
				      "mixed f(){ return"+v+";}")()->f();
      else
	perror("Unknown global variable: "+c+"\n");
  }
  docurl=QUERY(docurl2);
}


// Get the current domain. This is not as easy as one could think.

#ifdef __NT__
string get_tcpip_param(string val)
{
  foreach(({
    "SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters",
    "SYSTEM\\CurrentControlSet\\Services\\VxD\\MSTCP"
  }),string key)
  {
    catch {
      return RegGetValue(HKEY_LOCAL_MACHINE, key, val);
    };
  }
}
#endif

string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
  if (!l) {
    f = (QUERY(ConfigurationURL)/"://");
    if (sizeof(f) > 1) {
      t = (replace(f[1], ({ ":", "/" }), ({ "\0", "\0" }))/"\0")[0];
      f = t/".";
      if (sizeof(f) > 1) {
	s = f[1..]*".";
      }
    }
  }
#if efun(gethostbyname)
#if efun(gethostname)
  if(!s) {
    f = gethostbyname(gethostname()); // First try..
    if(f)
      foreach(f, f) {
	if (arrayp(f)) {
	  foreach(f, t) {
	    f = t/".";
	    if ((sizeof(f) > 1) &&
		(replace(t, ({ "0", "1", "2", "3", "4", "5",
				 "6", "7", "8", "9", "." }),
			 ({ "","","","","","","","","","","" })) != "")) {
	      t = f[1..]*".";
	      if(!s || strlen(s) < strlen(t))
		s=t;
	    }
	  }
	}
      }
  }
#endif
#endif
#ifdef __NT__
  s=get_tcpip_param("Domain")||"";
#else
  if(!s) {
    t = Stdio.read_bytes("/etc/resolv.conf");
    if(t) {
      if(!sscanf(t, "domain %s\n", s))
	if(!sscanf(t, "search %s%*[ \t\n]", s))
	  s="nowhere";
    } else {
      s="nowhere";
    }
  }
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown"; 
  }
#endif
  return s;
}


// Somewhat misnamed, since there can be more then one
// configuration-interface port nowdays. But, anyway, this function
// opens and listens to all configuration interface ports.

void initiate_configuration_port( int|void first )
{
  object o;
  array port;

  // Hm.
  if(!first && !config_ports_changed )
    return 0;
  
  config_ports_changed = 0;

  // First find out if we have any new ports.
  mapping(string:array(string)) new_ports = ([]);
  foreach(QUERY(ConfigPorts), port) {
    if ((< "ssl", "ssleay" >)[port[1]]) {
      // Obsolete versions of the SSL protocol.
      report_warning("Obsolete SSL protocol-module \""+port[1]+"\".\n"
		     "Converted to SSL3.\n");
      port[1] = "ssl3";
    }
    if ((< "ftp2" >)[port[1]]) {
      // Obsolete versions of the SSL protocol.
      report_warning("Obsolete FTP protocol-module \""+port[1]+"\"."
		     " Converted to FTP.\n");
      port[1] = "FTP";
    }
    string key = MKPORTKEY(port);
    if (!configuration_ports[key]) {
      report_notice(sprintf("New configuration port: %s\n", key));
      new_ports[key] = port;
    } else {
      // This is needed not to delete old unchanged ports.
      new_ports[key] = 0;
    }
  }

  // Then disable the old ones that are no more.
  foreach(indices(configuration_ports), string key) {
    if (zero_type(new_ports[key])) {
      report_notice(sprintf("Disabling configuration port: %s...\n", key));
      object o = configuration_ports[key];
      if (main_configuration_port == o) {
	main_configuration_port = 0;
      }
      m_delete(configuration_ports, key);
      mixed err;
      if (err = catch{
	destruct(o);
      }) {
	report_warning(sprintf("Error disabling configuration port: %s:\n"
			       "%s\n", key, describe_backtrace(err)));
      }
      o = 0;	// Be sure that there are no references left...
    }
  }

  current_configuration = 0;	// Compatibility...

  // Now we can create the new ports.
  foreach(indices(new_ports), string key)
  {
    port = new_ports[key];
    if (port) {
      array old = port;
      mixed erro;
      erro = catch {
	program requestprogram = (program)(getcwd()+"/protocols/"+port[1]);
	function rp;
	array tmp;
	if(!requestprogram) {
	  report_error("No request program for "+port[1]+"\n");
	  continue;
	}
	if(rp = requestprogram()->real_port)
	  if(tmp = rp(port, 0))
	    port = tmp;

	object privs;
	if(port[0] < 1024)
	  privs = Privs("Opening listen port below 1024");
	if(o=create_listen_socket(port[0],0,port[2],requestprogram,port)) {
	  report_notice(sprintf("Opening configuration port: %s\n", key));
	  if (!main_configuration_port) {
	    main_configuration_port = o;
	  }
	  configuration_ports[key] = o;
	} else {
	  report_error(sprintf("The configuration port %s "
			       "could not be opened\n", key));
	}
      };
      if (erro) {
	report_error(sprintf("Failed to open configuration port %s:\n"
			     "%s\n", key,
			     (stringp(erro)?erro:describe_backtrace(erro))));
      }
    }
  }
  if(!main_configuration_port)
  {
    report_error("No configuration ports could be created.\n"
		 "Is caudium already running?\n");
    if(first)
      exit( -1 );	// Restart.
  }
}
#include <stat.h>
// Find all modules, so a list of them can be presented to the
// user. This is not needed when the server is started.

void scan_module_dir(string d)
{
  if(sscanf(d, "%*s.pmod")!=0) return;
  MD_PERROR(("\n\nLooking for modules in "+d+" "));

  string file,path=d;
  mixed err;
  array q  = (get_dir( d )||({})) - ({".","..","CVS","RCS" });
  if(!sizeof(q)) {
    MD_PERROR(("No modules in here. Continuing elsewhere\n"));
    return;
  }
  if(search(q, ".no_modules")!=-1) {
    MD_PERROR(("No modules in here. Continuing elsewhere\n"));
    return;
  }
  MD_PERROR(("There are "+language("en","number")(sizeof(q))+" files.\n"));
  foreach( q, file )
  {
    object e = ErrorContainer();
    master()->set_inhibit_compile_errors(e);
    if ( file[0]!='.' && !backup_extension(file) && (file[-1]!='z'))
    {
      array stat = file_stat(path+file);
      if(!stat || (stat[ST_SIZE] < 0))
      {
	if(err = catch ( scan_module_dir(path+file+"/") ))
	  MD_PERROR((sprintf("Error in module rescanning directory code:"
			     " %s\n",describe_backtrace(err))));
      } else {
	MD_PERROR(("Considering "+file+" - "));
	if((module_stat_cache[path+file] &&
	    module_stat_cache[path+file][ST_MTIME])==stat[ST_MTIME])
	{
	  MD_PERROR(("Already tried this one.\n"));
	  continue;
	}
	module_stat_cache[path+file]=stat;
	
	switch(extension(file))
	{
	case "pike":
	case "lpc":
	  if(catch{
	    if((open(path+file,"r")->read(4))=="#!NO") {
	      MD_PERROR(("Not a module\n"));
	      file=0;
	    }
	  }) {
	    MD_PERROR(("Couldn't open file\n"));
	    file=0;
	  }
	  if(!file) break;
	case "mod":
	case "so":
	  string *module_info;
	  if (!(err=catch( module_info = lambda ( string file ) {
	    array foo;
	    object o;
	    program p;
	    if (catch(p = my_compile_file(file)) || (!p)) {
	      MD_PERROR((" compilation failed"));
	      throw("Compilation failed.\n");

	    }
	    // Set the module-filename, so that create in the
	    // new object can get it.
	    caudium->last_module_name = file;

	    array err = catch(o =  p());

	    caudium->last_module_name = 0;

	    if (err) {
	      MD_PERROR((" load failed"));
	      throw(err);
	    } else if (!o) {
	      MD_PERROR((" load failed"));
	      throw("Failed to initialize module.\n");
	    } else {
	      MD_PERROR((" load ok - "));
	      if (!o->register_module) {
		MD_PERROR(("register_module missing"));
		throw("No registration function in module.\n");
	      }
	    }

	    foo = o->register_module();
	    if (!foo) {
	      MD_PERROR(("registration failed.\n"));
	      return 0;
	    } else {
	      MD_PERROR(("registered."));
	    }
	    return({ foo[1], foo[2]+"<p><i>"+
		       replace(o->file_name_and_stuff(), "0<br>", file+"<br>")
		       +"</i>", foo[0] });
	  }(path + file)))) {
	    // Load OK
	    if (module_info) {
	      // Module load OK.
	      allmodules[ file-("."+extension(file)) ] = module_info;
	    } else {
	      // Disabled module.
	      report_notice(sprintf("Module %O is disabled.\n", path+file));
	    }
	  } else {
	    // Load failed.
	    module_stat_cache[path+file]=0;
#if 0
	    _master->errors += "\n";
	    if (arrayp(err)) {
	      _master->errors += path + file + ": " +
		describe_backtrace(err) + "\n";
	    } else {
	      _master->errors += path + file + ": " + err;
	    }
#endif
	  }
	}
	MD_PERROR(("\n"));
      }
    }
    master()->clear_compilation_failures();
    if(strlen(e->get())) {
      report_debug("Compilation errors found while scanning modules in "+
		   d+":\n"+ e->get()+"\n");
    }
    master()->set_inhibit_compile_errors(0);
  }
}

void rescan_modules()
{
  string file, path;
  mixed err;
  report_notice("Scanning module directories for modules");
  if (!allmodules) {
    allmodules=copy_value(somemodules);
  }

  foreach(QUERY(ModuleDirs), path)
  {
    array err;
    err = catch(scan_module_dir( path ));
    if(err) {
      report_error("While scanning module dir (\""+path+"\"): " +
		   describe_backtrace(err) + "\n");
    }
  }
  catch {
    rm(QUERY(ConfigurationStateDir) + ".module_stat_cache");
    rm(QUERY(ConfigurationStateDir) + ".allmodules");
    Stdio.write_file(QUERY(ConfigurationStateDir) + ".module_stat_cache", encode_value(module_stat_cache));
    Stdio.write_file(QUERY(ConfigurationStateDir) + ".allmodules", encode_value(allmodules));
  };
  report_notice("Done with module directory scan. Found "+
		sizeof(allmodules)+" modules.\n");
}

// ================================================= 
// Parse options to Caudium. This function is quite generic, see the
// main() function for more info about how it is used.

private string find_arg(array argv, array|string shortform, 
			array|string|void longform, 
			array|string|void envvars, 
			string|void def)
{
  string value;
  int i;

  for(i=1; i<sizeof(argv); i++)
  {
    if(argv[i] && strlen(argv[i]) > 1)
    {
      if(argv[i][0] == '-')
      {
	if(argv[i][1] == '-')
	{
	  string tmp;
	  int nf;
	  if(!sscanf(argv[i], "%s=%s", tmp, value))
	  {
	    if(i < sizeof(argv)-1)
	      value = argv[i+1];
	    else
	      value = argv[i];
	    tmp = argv[i];
	    nf=1;
	  }
	  if(arrayp(longform) && search(longform, tmp[2..]) != -1)
	  {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  } else if(longform && longform == tmp[2..]) {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  }
	} else {
	  if((arrayp(shortform) && search(shortform, argv[i][1..1]) != -1) 
	     || stringp(shortform) && shortform == argv[i][1..1])
	  {
	    if(strlen(argv[i]) == 2)
	    {
	      if(i < sizeof(argv)-1)
		value =argv[i+1];
	      argv[i] = argv[i+1] = 0;
	      return value;
	    } else {
	      value=argv[i][2..];
	      argv[i]=0;
	      return value;
	    }
	  }
	}
      }
    }
  }

  if(arrayp(envvars))
    foreach(envvars, value)
      if(getenv(value))
	return getenv(value);
  
  if(stringp(envvars))
    if(getenv(envvars))
      return getenv(envvars);

  return def;
}

// do the chroot() call. This is not currently recommended, since
// caudium dynamically loads modules, all module files must be
// available at the new location.

private void fix_root(string to)
{
#ifndef __NT__
  if(getuid())
  {
    perror("It is impossible to chroot() if the server is not run as root.\n");
    return;
  }

  if(!chroot(to))
  {
    perror("Caudium: Cannot chroot to "+to+": ");
#if efun(real_perror)
    real_perror();
#endif
    return;
  }
  perror("Root is now "+to+".\n");
#endif
}

void create_pid_file(string where)
{
#ifndef __NT__
  if(!where) return;
  where = replace(where, ({ "$pid", "$uid" }), 
		  ({ (string)getpid(), (string)getuid() }));

  rm(where);
  if(catch(Stdio.write_file(where, sprintf("%d\n%d", getpid(), getppid()))))
    perror("I cannot create the pid file ("+where+").\n");
#endif
}

// External multi-threaded data shuffler. This leaves caudium free to
// serve new requests. The file descriptors of the open files and the
// clients are sent to the program, then the shuffler just shuffles 
// the data to the client.
void shuffle(object from, object to,
	      object|void to2, function(:void)|void callback)
{
#if efun(spider.shuffle)
  if(!to2)
  {
    object p = pipe();
    p->input(from);
    p->set_done_callback(callback);
    p->output(to);
  } else {
#endif
    // 'smartpipe' does not support multiple outputs.
    object p = Pipe.pipe();
    if (callback) p->set_done_callback(callback);
    p->output(to);
    if(to2) p->output(to2);
    p->input(from);
#if efun(spider.shuffle)
  }
#endif
}


static private int _recurse;

// FIXME: Ought to use the shutdown code.
void exit_when_done()
{
  object o;
  int i;
  perror("Interrupt request received. Exiting,\n");
  die_die_die=1;
//   trace(9);
  if(++_recurse > 4)
  {
    roxen_perror("Exiting Caudium (spurious signals received).\n");
    stop_all_modules();
#ifdef THREADS
    stop_handler_threads();
#endif /* THREADS */
    add_constant("caudiump", 0);
    add_constant("caudium", 0);	
    add_constant("roxen", 0);	
    add_constant("roxenp", 0);	
    exit(-1);	// Restart.
    // kill(getpid(), 9);
    // kill(0, -9);
  }

  // First kill off all listening sockets.. 
  foreach(indices(portno)||({}), o)
  {
    catch { destruct(o); };
  }
  
  // Then wait for all sockets, but maximum 10 minutes.. 
  call_out(lambda() { 
    call_out(Simulate.this_function(), 5);
    if(!_pipe_debug()[0])
    {
      roxen_perror("Exiting Caudium (all connections closed).\n");
      stop_all_modules();
#ifdef THREADS
      stop_handler_threads();
#endif /* THREADS */
      add_constant("roxen", 0);	// Paranoia...
      add_constant("caudium", 0);	// Paranoia...
      exit(-1);	// Restart.
      perror("Odd. I am not dead yet.\n");
    }
  }, 0.1);
  call_out(lambda(){
    roxen_perror("Exiting Caudium (timeout).\n");
    stop_all_modules();
#ifdef THREADS
    stop_handler_threads();
#endif /* THREADS */
    add_constant("roxen", 0);	// Paranoia...
    add_constant("caudium", 0);	// Paranoia...
    exit(-1); // Restart.
  }, 600, 0); // Slow buggers..
}

void exit_it()
{
  perror("Recursive signals.\n");
  exit(-1);	// Restart.
}

#ifdef ENABLE_NEIGHBOURHOOD
object neighborhood;
#endif /* ENABLE_NEIGHBOURHOOD */


// Dump all threads to the debug log.
void describe_all_threads()
{
  array(mixed) all_backtraces;
#if constant(all_threads)
  all_backtraces = all_threads()->backtrace();
#else /* !constant(all_threads) */
  all_backtraces = ({ backtrace() });
#endif /* constant(all_threads) */

  werror("Describing all threads:\n");
  int i;
  for(i=0; i < sizeof(all_backtraces); i++) {
    werror(sprintf("Thread %d:\n"
		   "%s\n",
		   i+1,
		   describe_backtrace(all_backtraces[i])));
  }
}

// And then we have the main function, this is the oldest function in
// Caudium :) It has not changed all that much since Spider 2.0.
int main(int|void argc, array (string)|void argv)
{
  initiate_languages();
  mixed tmp;

  start_time = boot_time = time();

  add_constant("write", perror);

  report_notice("Starting Caudium\n");
  
#ifdef FD_DEBUG  
  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");
#endif

  configuration_dir =
    find_arg(argv, "d",({"config-dir","configuration-directory" }),
	     ({ "CAUDIUM_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  if(configuration_dir[-1] != '/')
    configuration_dir += "/";


  startpid = getppid();
  roxenpid = getpid();

  // Dangerous...
  if(tmp = find_arg(argv, "r", "root")) fix_root(tmp);

  argv -= ({ 0 });
  argc = sizeof(argv);

  perror("Restart initiated at "+ctime(time())); 

  define_global_variables(argc, argv);
#ifdef ENABLE_NEIGHBOURHOOD
  neighborhood = (object)"neighborhood";
#endif /* ENABLE_NEIGHBOURHOOD */

#if efun(syslog)
  init_logger();
#endif

  init_garber();
  initiate_supports();

  initiate_configuration_port( 1 );

  // Open all the ports before changing uid:gid in case permanent_uid is set.
  enabling_configurations = 1;
  configurations = ({});
  foreach(list_all_configurations(), string config)
  {
    array err;
    if(err=catch { enable_configuration(config)->start(0,0,argv);  })
      perror("Error while loading configuration "+config+":\n"+
	     describe_backtrace(err)+"\n");
  };

  set_u_and_gid();		// Running with the right uid:gid from this point on.

  create_pid_file(find_arg(argv, "p", "pid-file", "CAUDIUM_PID_FILE")
		  || QUERY(pidfile));

  roxen_perror("Initiating argument cache ... ");

  int id;
  string cp = QUERY(argument_cache_dir), na = "args";
  if( QUERY(argument_cache_in_db) )
  {
    id = 1;
    cp = QUERY(argument_cache_db_path);
    na = "argumentcache";
  }
  mixed e;
  e = catch( argcache = ArgCache(na,cp,id) );
  if( e )
  {
    report_error( "Failed to initialize the global argument cache:\n"
                  + (describe_backtrace( e )/"\n")[0]+"\n");
  }
  roxen_perror( "\n" );

  foreach(configurations, object config)
  {
    array err;
    if(err=catch { config->enable_all_modules();  })
      perror("Error while loading modules in configuration "+config->name+":\n"+
	     describe_backtrace(err)+"\n");
  };
  enabling_configurations = 0;

// Rebuild the configuration interface tree if the interface was
// loaded before the configurations was enabled (a configuration is a
// virtual server, perhaps the name should be changed internally as
// well.. :-)

  if(root)
  {
    destruct(configuration_interface());
    configuration_interface()->build_root(root);
  }

  call_out(update_supports_from_caudium_net,
	   QUERY(next_supports_update)-time());

#ifdef THREADS
  start_handler_threads();
  catch( this_thread()->set_name("Backend") );
  backend_thread = this_thread();
#if efun(thread_set_concurrency)
  thread_set_concurrency(QUERY(numthreads)+1);
#endif

#endif /* THREADS */

  // Signals which cause a restart (exitcode != 0)
  foreach( ({ "SIGINT" }), string sig) {
    catch { signal(signum(sig), exit_when_done); };
  }
  catch { signal(signum("SIGHUP"), reload_all_configurations); };
  // Signals which cause a shutdown (exitcode == 0)
  foreach( ({ "SIGTERM" }), string sig) {
    catch { signal(signum(sig), shutdown); };
  }
  // Signals which cause Caudium to dump the thread state
  foreach( ({ "SIGUSR1", "SIGUSR2", "SIGTRAP" }), string sig) {
    catch { signal(signum(sig), describe_all_threads); };
  }

  report_notice("Caudium started in "+(time()-start_time)+" seconds.\n");
#ifdef __RUN_TRACE
  trace(1);
#endif
  start_time=time();		// Used by the "uptime" info later on.
  return -1;
}

string diagnose_error(array from)
{

}

// Called from the configuration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
   case "ConfigPorts":
    config_ports_changed = 1;
    break;
   case "cachedir":
    if(!sscanf(value, "%*s/caudium_cache"))
    {
      object node;
      node = (configuration_interface()->root->descend("Globals", 1)->
	      descend("Proxy disk cache: Base Cache Dir", 1));
      if(node && !node->changed) node->change(1);
      mkdirhier(value+"caudium_cache/foo");
      call_out(set, 0, "cachedir", value+"caudium_cache/");
    }
    break;

   case "ConfigurationURL":
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return "The URL should follow this format: protocol://computer[:port]/";
    break;

   case "abs_engage":
    if (value)
      restart_if_stuck(1);
    else 
      remove_call_out(restart_if_stuck);
    break;

   case "suicide_engage":
    if (value) 
      call_out(restart,60*60*24*QUERY(suicide_timeout));
    else
      remove_call_out(restart);
    break;
  }
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: set_cookie
//! If set to Yes, all users of your server whose clients support cookies will get a unique 'user-id-cookie', this can then be used in the log and in scripts to track individual users.
//!  type: TYPE_FLAG
//!  name: Set unique user id cookies
//
//! defvar: set_cookie_only_once
//! If set to Yes, Caudium will attempt to set unique user ID cookies only upon receiving the first request (and again after some minutes). Thus, if the user doesn't allow the cookie to be set, he won't be bothered with multiple requests.
//!  type: TYPE_FLAG
//!  name: Set ID cookies only once
//
//! defvar: show_internals
//! Show 'Internal server error' messages to the user. This is very useful if you are debugging your own modules or writing Pike scripts.
//!  type: TYPE_FLAG
//!  name: Show the internals
//
//! defvar: RestoreConnLogFull
//! If this toggle is enabled log entries for restored connections will log the amount of sent data plus the restoration location. Ie if a user has downloaded 100 bytes of a file already, and makes a Range request fetching the remaining 900 bytes, the log entry will log it as if the entire 1000 bytes were downloaded. <p>This is useful if you want to know if downloads were successful (the user has the complete file downloaded). The drawback is that bandwidth statistics on the log file will be incorrect. The statistics in Caudium will continue being correct.
//!  type: TYPE_TOGGLE
//!  name: Range: Log entire file length in restored connections
//
//! defvar: EnableRangeHandling
//! Enable handling of the range headers. This allows browsers to download partial files. Mostly used to continue interrupted connections. It might be desirable to disable this feature since some download programs like to open a number of connections each downloading a separate part of a file.
//!  type: TYPE_TOGGLE
//!  name: Range: Enable range handling
//
//! defvar: default_font
//! The default font to use when modules request a font.
//!  type: TYPE_FONT
//!  name: Fonts: Default font
//
//! defvar: font_dirs
//! This is where the fonts are located.
//!  type: TYPE_DIR_LIST
//!  name: Fonts: Font directories
//
//! defvar: logdirprefix
//! This is the default file path that will be prepended to the log  file path in all the default modules and the virtual server.
//!  type: TYPE_DIR|VAR_MORE
//!  name: Log directory prefix
//
//! defvar: cache
//! If set to Yes, caching will be enabled.
//!  type: TYPE_FLAG
//!  name: Proxy disk cache: Enabled
//
//! defvar: garb_min_garb
//! Minimum number of Megabytes removed when a garbage collect is done.
//!  type: TYPE_INT
//!  name: Proxy disk cache: Clean size
//
//! defvar: cache_minimum_left
//! If less than this amount of disk space or inodes (in %) is left, the cache will remove a few files. This check may work half-hearted if the diskcache is spread over several filesystems.
//!  type: TYPE_INT
//!  name: Proxy disk cache: Minimum available free space and inodes (in %)
//
//! defvar: cache_size
//! How many MB may the cache grow to before a garbage collect is done?
//!  type: TYPE_INT
//!  name: Proxy disk cache: Size
//
//! defvar: cache_max_num_files
//! How many cache files (inodes) may be on disk before a garbage collect is done ? May be left zero to disable this check.
//!  type: TYPE_INT
//!  name: Proxy disk cache: Maximum number of files
//
//! defvar: bytes_per_second
//! How file size should be treated during garbage collect.  Each X bytes counts as a second, so that larger files will be removed first.
//!  type: TYPE_INT
//!  name: Proxy disk cache: Bytes per second
//
//! defvar: cachedir
//! This is the base directory where cached files will reside. To avoid mishaps, 'caudium_cache/' is always prepended to this variable.
//!  type: TYPE_DIR
//!  name: Proxy disk cache: Base Cache Dir
//
//! defvar: hash_num_dirs
//! This is the number of directories to hash the contents of the disk cache into.  Changing this value currently invalidates the whole cache, since the cache cannot find the old files.  In the future,  the cache will be recalculated when this value is changed.
//!  type: TYPE_INT
//!  name: Proxy disk cache: Number of hash directories
//
//! defvar: cache_keep_without_content_length
//! Keep files without Content-Length header information in the cache?
//!  type: TYPE_FLAG
//!  name: Proxy disk cache: Keep without Content-Length
//
//! defvar: cache_check_last_modified
//! If set, refreshes files without Expire header information when they have reached double the age they had when they got cached. This may be useful for some regularly updated docs as online newspapers.
//!  type: TYPE_FLAG
//!  name: Proxy disk cache: Refresh on Last-Modified
//
//! defvar: cache_last_resort
//! How many days shall files without Expires and without Last-Modified header information be kept?
//!  type: TYPE_INT
//!  name: Proxy disk cache: Last resort (in days)
//
//! defvar: cache_gc_logfile
//! Information about garbage collector runs, removed and refreshed files, cache and disk status goes here.
//!  type: TYPE_FILE
//!  name: Proxy disk cache: Garbage collector logfile
//
//! defvar: docurl2
//! The URL to prepend to all documentation urls throughout the server. This URL should _not_ end with a '/'.
//!  type: TYPE_STRING|VAR_MORE|VAR_EXPERT
//!  name: Documentation URL
//
//! defvar: pidfile
//! In this file, the server will write out it's PID, and the PID of the start script. $pid will be replaced with the pid, and $uid with the uid of the user running the process.
//!  type: TYPE_FILE|VAR_MORE
//!  name: PID file
//
//! defvar: identversion
//! The default behavior is to display the Caudium version number in the Server field in HTTP responses. You can disable it here for security reasons, since it might be easier to crack a server if the exact version is known.
//!  type: TYPE_FLAG
//!  name: Version numbers: Show Caudium Version Number 
//
//! defvar: identpikever
//! The default behavior is to display the Pike version number in the X-Got-Fish header in HTTP HEAD response. You can disable it here for security reasons, since it might be easier to exploit any possible bugs in the specific Pike version used on your server.
//!  type: TYPE_FLAG
//!  name: Version numbers: Show Pike Version Number 
//
//! defvar: DOC
//! Do you want documentation? (this is an example of documentation)
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Configuration interface: Help texts
//
//! defvar: NumAccept
//! You can here state the maximum number of accepts to attempt for each read callback from the main socket. <p> Increasing this value will make the server faster for users making many simultaneous connections to it, or if you have a very busy server. <p> It won't work on some systems, though, eg. IBM AIX 3.2<p> To see if it works, change this variable, <b> but don't press save</b>, and then try connecting to your server. If it works, come back here and press the save button. <p> If it doesn't work, just restart the server and be happy with having '1' in this field.<p>The higher you set this value, the less load balancing between virtual servers. (If there are 256 more or less simultaneous requests to server 1, and one to server 2, and this variable is set to 256, the 256 accesses to the first server might very well be handled before the one to the second server.)
//!  type: TYPE_INT_LIST|VAR_MORE
//!  name: Number of accepts to attempt
//
//! defvar: ConfigPorts
//! These are the ports through which you can configure the server.<br />Note that you should at least have one open port, since otherwise you won't be able to configure your server.
//!  type: TYPE_PORTS
//!  name: Configuration interface: Ports
//
//! defvar: ConfigurationURL
//! The URL of the configuration interface. This is used to generate redirects now and then (when you press save, when a module is added, etc.).
//!  type: TYPE_STRING
//!  name: Configuration interface: URL
//
//! defvar: ConfigurationPassword
//! The password you will have to enter to use the configuration interface. Please note that changing this password in the configuration interface will _not_ require an additional entry of the password, so it is easy to make a typo. It is recommended that you use the <a href=/(changepass)/Globals/>form instead</a>.
//!  type: TYPE_PASSWORD|VAR_EXPERT
//!  name: Configuration interface: Password
//
//! defvar: ConfigurationUser
//! The username you will have to enter to use the configuration interface
//!  type: TYPE_STRING|VAR_EXPERT
//!  name: Configuration interface: User
//
//! defvar: ConfigurationIPpattern
//! Only clients running on computers with IP numbers matching this pattern will be able to use the configuration interface.
//!  type: TYPE_STRING|VAR_MORE
//!  name: Configuration interface: IP-Pattern
//
//! defvar: ConfigurationStateDir
//! Directory where the configuration interface keeps its state - module cache, interface settings etc.
//!  type: TYPE_DIR|VAR_MORE
//!  name: Configuration interface: Status Directory
//
//! defvar: User
//! When caudium is run as root, to be able to open port 80 for listening, change to this user-id and group-id when the port  has been opened. If you specify a symbolic username, the default group of that user will be used. The syntax is user[:group].
//!  type: TYPE_STRING
//!  name: Change uid and gid to
//
//! defvar: permanent_uid
//! If this variable is set, caudium will set it's uid and gid permanently. This disables the 'exec script as user' fetures for CGI, and also access files as user in the filesystems, but it gives better security.
//!  type: TYPE_FLAG
//!  name: Change uid and gid permanently
//
//! defvar: ModuleDirs
//! This is a list of directories where Caudium should look for modules. Can be relative paths, from the directory you started caudium, 
//!  type: TYPE_DIR_LIST
//!  name: Module directories
//
//! defvar: Supports
//! What do the different clients support?
//!<br />The default information is normally fetched from the file 
//!  type: TYPE_TEXT_FIELD|VAR_MORE
//!  name: Client supports regexps
//
//! defvar: audit
//! If Audit trail is set to Yes, all changes of uid will be logged in the Event log.
//!  type: TYPE_FLAG
//!  name: Audit trail
//
//! defvar: LogA
//! What method to use for logging, default is file, but syslog is also available. When using file, the output is really sent to stdout and stderr, but this is handled by the start script.
//!  type: TYPE_STRING_LIST|VAR_MORE
//!  name: Logging method
//
//! defvar: LogSP
//! If set, the PID will be included in the syslog.
//!  type: TYPE_FLAG
//!  name: Syslog: Log PID
//
//! defvar: LogCO
//! If set and syslog is used, the error/debug message will be printed to the system console as well as to the system log.
//!  type: TYPE_FLAG
//!  name: Syslog: Log to system console
//
//! defvar: LogST
//! When using SYSLOG, which log type should be used.
//!  type: TYPE_STRING_LIST
//!  name: Syslog: Log type
//
//! defvar: LogWH
//! When syslog is used, how much should be sent to it?<br /><hr>Fatal:    Only messages about fatal errors<br />
//!  type: TYPE_STRING_LIST
//!  name: Syslog: Log what
//
//! defvar: LogNA
//! When syslog is used, this will be the identification of the Caudium daemon. The entered value will be appended to all logs.
//!  type: TYPE_STRING
//!  name: Syslog: Log as
//
//! defvar: numthreads
//! The number of simultaneous threads caudium will use.
//!<p>Please note that even if this is one, Caudium will still be able to serve multiple requests, using a select loop based system.
//!<i>This is quite useful if you have more than one CPU in your machine, or if you have a lot of slow NFS accesses.</i>
//!  type: TYPE_INT
//!  name: Number of threads to run
//
//! defvar: AutoUpdate
//! If set to Yes, the etc/supports file will be updated automatically from caudium.net now and then. This is recomended, since you will then automatically get supports information for new clients, and new versions of old ones.
//!  type: TYPE_FLAG
//!  name: Update the supports database automatically
//
//! defvar: neighborhood
//! If this option is set, Caudium will automatically broadcast it's existence to other Caudium servers on the local network.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Neighborhood: Register with other Caudium servers on the local network
//
//! defvar: neigh_tcp_ips
//! This is the list of direct host<-->host links to establish. The local host is always present (if the neighbourhood functionality is at all enabled).
//!  type: TYPE_STRING_LIST|VAR_MORE
//!  name: Neighborhood: TCP hosts
//
//! defvar: neigh_ips
//!  type: TYPE_STRING_LIST|VAR_MORE
//!  name: Neighborhood: Broadcast addresses
//
//! defvar: neigh_com
//! A short string describing this server.
//!  type: TYPE_TEXT|VAR_MORE
//!  name: Neighborhood: Server informational comment
//
//! defvar: abs_engage
//! If set, it will enable the anti-block-system. This will restart the server after a configurable number of minutes if it locks up. If you are running in a single threaded environment heavy calculations will also halt the server. In multi-threaded mode bugs as eternal loops will not cause the server to reboot, since only one thread is blocked. In general there is no harm in having this option enabled. 
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Anti-Block-System: Enable
//
//! defvar: abs_timeout
//! If the server is unable to accept connection for this many minutes, it will be restarted. You need to find a balance: if set too low, the server will be restarted even if it's doing legal things (like generating many images), if set too high you will have long downtimes.
//!  type: TYPE_INT_LIST|VAR_MORE
//!  name: Anti-Block-System: Timeout
//
//! defvar: suicide_engage
//! If set, Caudium will automatically restart after a configurable number of days. Since Caudium uses a monolith, non-forking server model the process tends to grow in size over time. This is mainly due to heap fragmentation but also because of memory leaks.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Automatic Restart: Enable
//
//! defvar: suicide_timeout
//! Automatically restart the server after this many days.
//!  type: TYPE_INT_LIST|VAR_MORE
//!  name: Automatic Restart: Timeout
//
//! defvar: argument_cache_in_db
//! If set, store the argument cache in a mysql database. This is very useful for load balancing using multiple caudium servers, since the mysql database will handle  synchronization
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Argument Cache: Store the argument cache in a mysql database
//
//! defvar: argument_cache_db_path
//! The database to use to store the argument cache
//!  type: TYPE_STRING|VAR_MORE
//!  name: Argument Cache: Database URL to use
//
//! defvar: argument_cache_dir
//! The cache directory to use to store the argument cache. Please note that load balancing is not available for most modules  (such as gtext, diagram etc) unless you use a mysql database to store the argument caches
//!  type: TYPE_DIR|VAR_MORE
//!  name: Argument Cache: Cache directory
//
