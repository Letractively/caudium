/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

/*
 * $Id$
 *
 * Caudium bootstrap program.
 *
 */

// Sets up the caudium environment. Including custom functions like spawne().

//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private static object new_master;

constant cvs_version="$Id$";

// Macro to throw errors
//#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

#include <caudium.h>
#undef file_stat
// The privs.pike program
program Privs;

#define perror roxen_perror
private static int perror_status_reported=0;

int pid = getpid();
Stdio.File stderr = Stdio.File("stderr");

mapping(int:string) pwn=([]);
string pw_name(int uid)
{
#if !constant(getpwuid)
  return "uid #"+uid;
#else
  if(pwn[uid]) return pwn[uid];
  array tmp = getpwuid(uid);
  if(tmp) return pwn[uid] = (string)tmp[0];
  return pwn[uid] = "uid #"+uid;
#endif
}

#if !constant(getppid)
int getppid()
{
  return -1;
}
#endif

#if constant(syslog)
#define  LOG_CONS   (1<<0)
#define  LOG_NDELAY (1<<1)
#define  LOG_PERROR (1<<2)
#define  LOG_PID    (1<<3)

#define  LOG_AUTH    (1<<0)
#define  LOG_AUTHPRIV (1<<1)
#define  LOG_CRON    (1<<2)
#define  LOG_DAEMON  (1<<3)
#define  LOG_KERN    (1<<4)
#define  LOG_LOCAL  (1<<5)
#define  LOG_LOCAL1  (1<<6)
#define  LOG_LOCAL2  (1<<7)
#define  LOG_LOCAL3  (1<<8)
#define  LOG_LOCAL4  (1<<9)
#define  LOG_LOCAL5  (1<<10)
#define  LOG_LOCAL6  (1<<11)
#define  LOG_LOCAL7  (1<<12)
#define  LOG_LPR     (1<<13)
#define  LOG_MAIL    (1<<14)
#define  LOG_NEWS    (1<<15)
#define  LOG_SYSLOG  (1<<16)
#define  LOG_USER    (1<<17)
#define  LOG_UUCP    (1<<18)

#define  LOG_EMERG   (1<<0)
#define  LOG_ALERT   (1<<1)
#define  LOG_CRIT    (1<<2)
#define  LOG_ERR     (1<<3)
#define  LOG_WARNING (1<<4)
#define  LOG_NOTICE  (1<<5)
#define  LOG_INFO    (1<<6)
#define  LOG_DEBUG   (1<<7)
int use_syslog, loggingfield;
#endif

#ifdef FD_DEBUG
mapping fd_marker = ([]);
#endif
mixed mark_fd(int fd, mixed|void marker) {
#ifdef FD_DEBUG
  if(marker) fd_marker[fd] = marker;
  else return fd_marker[fd];
#endif
  
}

/*
 * Some efuns used by Caudium
 */

array(int) caudium_fstat(string|Stdio.File file, int|void nolink) {
  mixed st;
  if(objectp(file)) {
    if(file->stat)
      st = (array(int))([object(Stdio.File)]file)->stat();
    else
      throw("caudium_fstat: Object not a file.\n");
  }    
  else
    st = file_stat((string)file, nolink);
  if(st) return (array(int))st;
  return 0;
}

// Used to print error/debug messages
void roxen_perror(string format,mixed ... args)
{
  int t = time();

  if (perror_status_reported < t) {
    stderr->write("[1mCaudium is alive!\n"
		  "   Time: "+ctime(t)+
		  "   pid: "+pid+"   ppid: "+getppid()+
#if constant(geteuid)
		  (geteuid()!=getuid()?"   euid: "+pw_name(geteuid()):"")+
#endif
		  "   uid: "+pw_name(getuid())+"[0m\n");
    perror_status_reported = t + 60;	// 60s delay.
  }

  string s;
  spider;
  if(sizeof(args)) format=sprintf(format,@args);
  if (format=="") return;

#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    foreach(format/"\n"-({""}), string message)
      syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
#endif
  stderr->write(format);
}

// Make a directory hierachy
int mkdirhier(string from, int|void mode)
{
  int r = 1;
  string a, b;
  array(string) f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    if (query_num_arg() > 1) {
      mkdir(b+a, mode);
#if constant(chmod)
      array(int) stat = caudium_fstat (b + a, 1);
      if (stat && stat[0] & ~mode)
	// Race here. Not much we can do about it at this point. :\
	catch (chmod (b+a, stat[0] & mode));
#endif
    }
    else
      // 0.6 defaults umask to 0770 for some reason. (This will still
      // be modified with the process umask.)
      mkdir(b+a, 0777);
    b+=a+"/";
  }
  if(!r)
    return (caudium_fstat(from)||({0,0}))[1] == -2;
  return 1;
}

/*
 * PDB support
 */
object db;
mapping(string:object) dbs = ([ ]);

#if constant(thread_create)
static private inherit Thread.Mutex:db_lock;
#endif

object open_db(string id)
{
#if constant(thread_create)
  object key = db_lock::lock();
#endif
#if constant(myPDB)
  if(!db) db = myPDB->db("pdb_dir", "wcCr"); //myPDB ignores 2nd arg.
#else
  if(!db) db = PDB->db("pdb_dir", "wcCr");
#endif
  if(dbs[id]) return dbs[id];
  return dbs[id] = [object]db[id];
}


// Help function used by low_spawne()
mapping(string:string) make_mapping(array(string) f)
{
  mapping(string:string) foo=([ ]);
  string s, a, b;
  foreach(f, s)
  {
    sscanf(s, "%s=%s", a, b);
    foo[a]=b;
  }
  return foo;
}


// Caudium itself
object caudium;

// The function used to report notices/debug/errors etc.

function(string,int|void,int|void:void) nwrite = stderr->write;


/*
 * Code to get global configuration variable values from Caudium.
 */
#define VAR_VALUE 0

mixed query(string arg) 
{
  if(!caudium)
    error("No caudium object!\n");
  if(!caudium->variables)
    error("No caudium variables!\n");
  if(!caudium->variables[arg])
    error("Unknown variable: "+arg+"\n");
  return caudium->variables[arg][VAR_VALUE];
}

// used for debug messages. Sent to the configuration interface and STDERR.
void init_logger()
{
#if constant(syslog)
  int res;
  use_syslog = !! (query("LogA") == "syslog");

  switch(query("LogST"))
  {
   case "Daemon":    res = LOG_DAEMON;    break;
   case "Local 0":   res = LOG_LOCAL;     break; 
   case "Local 1":   res = LOG_LOCAL1;    break;
   case "Local 2":   res = LOG_LOCAL2;    break;
   case "Local 3":   res = LOG_LOCAL3;    break;
   case "Local 4":   res = LOG_LOCAL4;    break;
   case "Local 5":   res = LOG_LOCAL5;    break;
   case "Local 6":   res = LOG_LOCAL6;    break;
   case "Local 7":   res = LOG_LOCAL7;    break;
   case "User":      res = LOG_USER;      break;
  }
  
  loggingfield=0;
  switch(query("LogWH"))
  { /* Fallthrouh intentional */
   case "All":
    loggingfield = loggingfield | LOG_INFO | LOG_NOTICE;
   case "Debug":
    loggingfield = loggingfield | LOG_DEBUG;
   case "Warnings":
    loggingfield = loggingfield | LOG_WARNING;
   case "Errors":
    loggingfield = loggingfield | LOG_ERR;
   case "Fatal":
    loggingfield = loggingfield | LOG_EMERG;
  }

  closelog();
  openlog(query("LogNA"), (query("LogSP")*LOG_PID)|(query("LogCO")*LOG_CONS),
	  res); 
#endif
}

// Print a debug message
void report_debug(string message, mixed ... args)
{
  if(sizeof(args)) message = sprintf(message, @args);
  nwrite(message,0,2);
#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    foreach(message/"\n", message)
      syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
#endif
}

// Print a warning
void report_warning(string message, mixed ... args)
{
  if(sizeof(args)) message = sprintf(message, @args);
  nwrite(message,0,2);
#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    foreach(message/"\n", message)
      syslog(LOG_WARNING, replace(message+"\n", "%", "%%"));
#endif
}

// Print a notice
void report_notice(string message, mixed ... args)
{
  if(sizeof(args)) message = sprintf(message, @args);
  nwrite(message,0,1);
#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    foreach(message/"\n", message)
      syslog(LOG_NOTICE, replace(message+"\n", "%", "%%"));
#endif
}

// Print an error message
void report_error(string message, mixed ... args)
{
  if(sizeof(args)) message = sprintf(message, @args);
  nwrite(message,0,3);
#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    foreach(message/"\n", message)
      syslog(LOG_ERR, replace(message+"\n", "%", "%%"));
#endif
}

// Print a fatal error message
void report_fatal(string message, mixed ... args)
{
  if(sizeof(args)) message = sprintf(message, @args);
  nwrite(message,0,3);
#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    foreach(message/"\n", message)
      syslog(LOG_EMERG, replace(message+"\n", "%", "%%"));
#endif
}

// Pipe open 
string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  Stdio.File p;
  Stdio.File f;

  f = Stdio.File();
#if constant(Stdio.PROP_IPC)
  p = f->pipe(Stdio.PROP_IPC);
#else
  p = f->pipe();
#endif
  if(!p) 
    error("Popen failed. (couldn't create pipe)\n");

  mapping(string:mixed) opts = ([
    "env": (env || getenv()),
    "stdout":p,
  ]);

  if (!getuid()) {
    switch(query_num_arg()) {
    case 4:
      opts->gid = gid;
    case 3:
      opts->uid = uid;
      break;
    }
  }
#if constant(Process.Process)
  Process.Process proc;
#else
  object proc;
#endif
  proc = Process.create_process( ({"/bin/sh", "-c", s }), opts );
  p->close();
  destruct(p);

  if (proc) 
  {
    string t = f->read(0x7fffffff);
    f->close();
    destruct(f);
    return t;
  }
  p->close();
  destruct(f);
  return 0;
}

int low_spawne(string s, array args,
	       mapping(string:string)|array(string) env,
	       Stdio.File stdin, Stdio.File stdout, Stdio.File stderr,
	       void|string wd)
{
  object p;
  int pid;
  string t;

  if(arrayp(env))
    env = make_mapping([array(string)]env);
  if(!mappingp(env)) 
    env=([]);
  
  
  stdin->dup2(Stdio.File("stdin"));
  stdout->dup2(Stdio.File("stdout"));
  stderr->dup2(Stdio.File("stderr"));
  if(stringp(wd) && sizeof(wd))
    cd(wd);
  exece(s, args, [mapping(string:string)]env);
  perror(sprintf("Spawne: Failed to exece %s\n", s));
  exit(99);
}

// Create a process
int spawne(string s, array(string) args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd, void|array (int) uid)
{
  int pid;
  array(int) olduid = allocate(2);

  int u, g;
  if(uid) { u = uid[0]; g = uid[1]; } else
#if constant(geteuid)
  { u=geteuid(); g=getegid(); }
#else
  ;
#endif
#if constant(Process.Process)
  Process.Process proc;
#else
  object proc;
#endif
  proc = Process.create_process(({ s }) + (args || ({})), ([
    "toggle_uid":1,
    "stdin":stdin,
    "stdout":stdout,
    "stderr":stderr,
    "cwd":wd,
    "env":env,
    "uid":u,
    "gid":g,
  ]));
  if (proc) {
    return(proc->pid());
  }
  return(-1);
}

// Start a new Pike process with the same configuration as the current one
int spawn_pike(array(string) args, void|string wd, object|void stdin,
		  object|void stdout, object|void stderr)
{
  string cwd = getcwd();
  string pikebin = combine_path(cwd, [string]new_master->_pike_file_name ||
				"bin/pike");
  string mast = combine_path(cwd, [string]new_master->_master_file_name ||
			     "../pike/src/lib/master.pike");
  array preargs = ({ });

  if (caudium_fstat(mast))
    preargs += ({ "-m"+mast });
#if constant(Process.Process)
  Process.Process proc;
#else
  object proc;
#endif
  proc = Process.create_process(({ pikebin }) + preargs + args, ([
    "toggle_uid":1,
    "stdin":stdin,
    "stdout":stdout,
    "stderr":stderr,
    "cwd":wd,
    "env":getenv() + ([
      "PIKE_INCLUDE_PATH": new_master->pike_include_path * ":",
      "PIKE_MODULE_PATH": new_master->pike_module_path * ":",
      "PIKE_PROGRAM_PATH": new_master->pike_program_path * ":",
    ]),
  ]));

  if (proc) {
    return(proc->pid());
  }
  return -1;
}


// Add a few cache control related efuns
static private void initiate_cache()
{
  object cache;
  cache=((program)"base_server/cache")();
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_clear", cache->cache_clear);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache", cache);
  add_constant("capitalize", lambda(string s){return upper_case(s[0..0])+s[1..];});
}

class _error_handler {
  void compile_error(string a,int b,string c);
  void compile_warning(string a,int b,string c);
}
array(_error_handler) compile_error_handlers = ({});
void push_compile_error_handler( _error_handler q )
{
  compile_error_handlers = ({q})+compile_error_handlers;
}

void pop_compile_error_handler()
{
  compile_error_handlers = compile_error_handlers[1..];
}

class LowErrorContainer
{
  string d;
  string errors="", warnings="";
  string get()
  {
    return errors;
  }
  string get_warnings()
  {
    return warnings;
  }

  void print_warnings(string prefix) {
    if(warnings && strlen(warnings))
      report_warning(prefix+"\n"+warnings);
  }
  void got_error(string file, int line, string err, int|void is_warning)
  {
    if (file[..sizeof(d)-1] == d) {
      file = file[sizeof(d)..];
    }
    if( is_warning)
      warnings+= sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
    else
      errors += sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
  }
  void compile_error(string file, int line, string err)
  {
    got_error(file, line, "Error: " + err);
  }
  void compile_warning(string file, int line, string err)
  {
    got_error(file, line, "Warning: " + err, 1);
  }
  void create()
  {
    d = getcwd();
    if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
      d += "/";
  }
}

class ErrorContainer
{
  inherit LowErrorContainer;

  void compile_error(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_error( file,line, err );
    else
      ::compile_error(file,line,err);
  }
  void compile_warning(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_warning( file,line, err );
    else
      ::compile_warning(file,line,err);
  }
}


// privs.pike placeholder during bootstrap.
class myprivs
{
  program privs;
  object master;
    
  void create(object m)
  {
    master = m;
  }

  object `()(mixed ... args)
  {
    if(!privs) privs = master->Privs;
    if(!privs) return 0;
    return privs(@args);
  }
}

// Don't allow cd() unless we are in a forked child.
class restricted_cd
{
  int locked_pid = getpid();
  int `()(string path)
  {
    if (locked_pid == getpid()) {
      throw(({ "Use of cd() is restricted.\n", backtrace() }));
    }
    return cd(path);
  }
}

// Place holder.
class empty_class {
  void create(mixed ... args) {
  }
};

// Fallback efuns.
#if !constant(getuid)
int getuid(){ return 17; }
int getgid(){ return 42; }
#endif
#if !constant(gethrtime)
int gethrtime()
{
  return (time()*1000000);
}
#endif

// Load Caudium for real
object really_load_caudium()
{
  int start_time = gethrtime();
  werror("Loading Caudium ... ");
  object res;
  object ee = ErrorContainer();
  master()->set_inhibit_compile_errors(ee);
  array err = catch {
    res = ((program)"caudium")();
  };
  master()->set_inhibit_compile_errors(0);
  if(strlen(ee->get())) {
    werror("error:\n%s\n", ee->get());
    exit(1);
  } else if(err) {
    werror(describe_backtrace(err));
    exit(1);
  }
  ee->print_warnings("compilation warnings:");
		 
  roxen_perror("done in "+sprintf("%4.3fs\n", (gethrtime()-start_time)/1000000.0));
  return res;
}

// Debug function to trace calls to destruct().
#ifdef TRACE_DESTRUCT
void trace_destruct(mixed x)
{
  roxen_perror(sprintf("DESTRUCT(%O)\n%s\n",
		       x, describe_backtrace(backtrace())));
  destruct(x);
}
#endif /* TRACE_DESTRUCT */

// Set up efuns and load Caudium.
void load_caudium()
{
  add_constant("ErrorContainer", ErrorContainer);
  add_constant("cd", restricted_cd());
#ifdef TRACE_DESTRUCT
  add_constant("destruct", trace_destruct);
#endif /* TRACE_DESTRUCT */
#if !constant(getppid)
  add_constant("getppid", getppid);
#endif
#if !constant(getuid)
  add_constant("getuid", getuid);
  add_constant("getgid", getgid);
#endif
#if !constant(gethostname)
  add_constant("gethostname", lambda() { return "localhost"; });
#endif
  
  // Attempt to resolv cross-references...
  if(!getuid())
    add_constant("Privs", myprivs(this_object()));
  else  // No need, we are not running as root.
    add_constant("Privs", (Privs=empty_class));
  caudium = really_load_caudium();
  if(!getuid())
  {
    add_constant("roxen_pid", getpid());
    Privs = ((program)"privs");
    add_constant("Privs", Privs);
  }

  perror("Caudium version "+caudium->cvs_version+"\n"
	 "Caudium release "+caudium->real_version+"\n");
  nwrite = caudium->nwrite;
}

// Code to trace fd usage.
#ifdef FD_DEBUG
class mf
{
  inherit Stdio.File;

  mixed open(string what, string mode)
  {
    int res;
    res = ::open(what,mode);
    if(res)
    {
      string file;
      int line;
      sscanf(((describe_backtrace(backtrace())/"\n")[2]-(getcwd()+"/")),
	     "%*s line %d in %s", line, file);
      mark_fd(query_fd(), file+":"+line+" open(\""+ what+"\", "+mode+")");
    }
    return res;
  }

  void destroy()
  {
    catch { mark_fd(query_fd(),"CLOSED"); };
  }  

  int close(string|void what)
  {
    destroy();
    if (what) {
      return ::close(what);
    }
    return ::close();
  }
}
#else
constant mf = Stdio.File;
#endif

// open() constant.
object|void open(string filename, string mode, int|void perm)
{
  object o;
  o=mf();
  if(!(o->open(filename, mode, perm||0666))) {
    // EAGAIN, ENOMEM, ENFILE, EMFILE, EAGAIN(FreeBSD)
    if ((< 11, 12, 23, 24, 35 >)[o->errno()]) {
      // Let's see if the garbage-collector can free some fd's
      gc();
      // Retry...
      if(!(o->open(filename, mode, perm||0666))) {
	destruct(o);
	return;
      }
    } else {
      destruct(o);
      return;
    }
  }

  // FIXME: Might want to stat() here to check that we don't open
  // devices...
  return o;
}

// Make a $PATH-style string
string make_path(string ... from)
{
  return Array.map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
    //return combine_path(b,a);
  }, getcwd())*":";
}

#if !constant(String.common_prefix)
string common_prefix(array(string) strs)
{
  if(!sizeof(strs))
    return "";

  string strs0 = strs[0];
  int n, i;
  
  catch
  {
    for(n = 0; n < sizeof(strs0); n++)
      for(i = 1; i < sizeof(strs); i++)
	if(strs[i][n] != strs0[n])
	  return strs0[0..n-1];
  };

  return strs0[0..n-1];
}
#endif


// Caudium bootstrap code.
int main(mixed ... args)
{
  int start_time = gethrtime();
  string path = make_path("base_server", "etc/include", ".");
  roxen_perror(version()+"\n");
  roxen_perror("Caudium loader version "+cvs_version+"\n");
  roxen_perror("Caudium started on "+ctime(time()));	// ctime has an lf.
  master()->putenv("PIKE_INCLUDE_PATH", path);
  foreach(path/":", string p) {
    add_include_path(p);
    add_program_path(p);
  }

  replace_master(new_master=(((program)"etc/caudium_master.pike")()));
#if !constant(has_value)
  add_constant("has_value", lambda(mixed haystack, mixed needle) {
			      return search(haystack, needle) != -1;
			    });
#endif
#if !constant(String.common_prefix)
  add_constant("common_prefix", common_prefix);
#else
  add_constant("common_prefix", String.common_prefix);
#endif
  add_constant("fish_version", version());
  add_constant("open_db", open_db);
  add_constant("do_destruct", lambda(object o) {
				if(o&&objectp(o))  destruct(o);
			      });				
  //  add_constant("error", lambda(string s){error(s);});
  add_constant("spawne",spawne);
  add_constant("caudium_fstat", caudium_fstat);
  add_constant("spawn_pike",spawn_pike);
  add_constant("perror",perror);
  add_constant("roxen_perror",perror);
  add_constant("popen",popen);
  add_constant("roxen_popen",popen);
  add_constant("caudiump", lambda() { return caudium; });
  add_constant("roxenp", lambda() { return caudium; });
  add_constant("report_notice", report_notice);
  add_constant("report_debug", report_debug);
  add_constant("report_warning", report_warning);
  add_constant("report_error", report_error);
  add_constant("report_fatal", report_fatal);
  add_constant("init_logger", init_logger);
  add_constant("open", open);
  add_constant("mkdirhier", mkdirhier);
#if !constant(http_decode_string) && constant(_Roxen.http_decode_string)
  add_constant("http_decode_string", _Roxen.http_decode_string);
#endif
  

  add_constant("mark_fd", mark_fd);

  initiate_cache();
  load_caudium();
  int retval = caudium->main(@args);
  perror_status_reported = 0;
  roxen_perror("\n-- Total boot time %4.3f seconds ---------------------------\n\n",
	       (gethrtime()-start_time)/1000000.0);
  return(retval);
}
