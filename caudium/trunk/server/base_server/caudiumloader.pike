/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
 */
/*
 * $Id$
 */

//! Caudium bootstrap program: sets up the caudium environment.
//! Including custom functions like spawne().
//! @note
//!   This file uses replace_master(). This implies that the
//!   master() efun when used in this file will return the old
//!   master and not the new one.

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

object _cache_manager;

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


// Used by the some compatibility functions...
#if !constant(strftime)
string strftime(string fmt, int t)
{
  mapping lt = localtime(t);
  array a = fmt/"%";
  int i;
  for (i=1; i < sizeof(a); i++) {
    if (!sizeof(a[i])) {
      a[i] = "%";
      i++;
      continue;
    }
    string res = "";
    switch(a[i][0]) {
    case 'a':	// Abbreviated weekday name
      res = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" })[lt->wday];
      break;
    case 'A':	// Weekday name
      res = ({ "Sunday", "Monday", "Tuesday", "Wednesday",
	       "Thursday", "Friday", "Saturday" })[lt->wday];
      break;
    case 'b':	// Abbreviated month name
    case 'h':	// Abbreviated month name
      res = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
	       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" })[lt->mon];
      break;
    case 'B':	// Month name
      res = ({ "January", "February", "March", "April", "May", "June",
	       "July", "August", "September", "October", "November", "December" })[lt->mon];
      break;
    case 'c':	// Date and time
      res = strftime(sprintf("%%a %%b %02d  %02d:%02d:%02d %04d",
			     lt->mday, lt->hour, lt->min, lt->sec, 1900 + lt->year), t);
      break;
    case 'C':	// Century number; 0-prefix
      res = sprintf("%02d", 19 + lt->year/100);
      break;
    case 'd':	// Day of month [1,31]; 0-prefix
      res = sprintf("%02d", lt->mday);
      break;
    case 'D':	// Date as %m/%d/%y
      res = strftime("%m/%d/%y", t);
      break;
    case 'e':	// Day of month [1,31]; space-prefix
      res = sprintf("%2d", lt->mday);
      break;
    case 'H':	// Hour (24-hour clock) [0,23]; 0-prefix
      res = sprintf("%02d", lt->hour);
      break;
    case 'I':	// Hour (12-hour clock) [1,12]; 0-prefix
      res = sprintf("%02d", 1 + (lt->hour + 11)%12);
      break;
    case 'j':	// Day number of year [1,366]; 0-prefix
      res = sprintf("%03d", lt->yday);
      break;
    case 'k':	// Hour (24-hour clock) [0,23]; space-prefix
      res = sprintf("%2d", lt->hour);
      break;
    case 'l':	// Hour (12-hour clock) [1,12]; space-prefix
      res = sprintf("%2d", 1 + (lt->hour + 11)%12);
      break;
    case 'm':	// Month number [1,12]; 0-prefix
      res = sprintf("%02d", lt->mon + 1);
      break;
    case 'M':	// Minute [00,59]
      res = sprintf("%02d", lt->min);
      break;
    case 'n':	// Newline
      res = "\n";
      break;
    case 'p':	// a.m. or p.m.
      if (lt->hour < 12) {
	res = "a.m.";
      } else {
	res = "p.m.";
      }
      break;
    case 'r':	// Time in 12-hour clock format with %p
      res = strftime("%l:%M %p", t);
      break;
    case 'R':	// Time as %H:%M
      res = sprintf("%02d:%02d", lt->hour, lt->min);
      break;
    case 'S':	// Seconds [00,61]
      res = sprintf("%02", lt->sec);
      break;
    case 't':	// Tab
      res = "\t";
      break;
    case 'T':	// Time as %H:%M:%S
      res = sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'u':	// Weekday as a decimal number [1,7], Sunday == 1
      res = sprintf("%d", lt->wday + 1);
      break;
    case 'w':	// Weekday as a decimal number [0,6], Sunday == 0
      res = sprintf("%d", lt->wday);
      break;
    case 'x':	// Date
      res = strftime("%a %b %d %Y", t);
      break;
    case 'X':	// Time
      res = sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'y':	// Year [00,99]
      // FIXME: Does this handle negative years.
      res = sprintf("%02d", lt->year % 100);
      break;
    case 'Y':	// Year [0000.9999]
      res = sprintf("%04d", 1900 + lt->year);
      break;

    case 'U':	/* FIXME: Week number of year as a decimal number [00,53],
		 * with Sunday as the first day of week 1
		 */
      break;
    case 'V':	/* Week number of the year as a decimal number [01,53],
		 * with  Monday  as  the first day of the week.  If the
		 * week containing 1 January has four or more  days  in
		 * the  new  year, then it is considered week 1; other-
		 * wise, it is week 53 of the previous  year,  and  the
		 * next week is week 1
		 */
      break;
   case 'W':	/* FIXME: Week number of year as a decimal number [00,53],
		 * with Monday as the first day of week 1
		 */
      break;
    case 'Z':	/* FIXME: Time zone name or abbreviation, or no bytes if
		 * no time zone information exists
		 */
      break;
    default:
      // FIXME: Some kind of error indication?
      break;
    }
    a[i] = res + a[i][1..];
  }
  return(a*"");
}
#endif /* !constant(strftime) */

//!
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

//! Used to print error/debug messages
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


//! Help function used by low_spawne()
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


//! Caudium itself
object caudium;

//! The function used to report notices/debug/errors etc.
function(string,int|void,int|void:void) nwrite = stderr->write;


#define VAR_VALUE 0

//! Code to get global configuration variable value from Caudium.
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

//! used for debug messages. Sent to the configuration interface and STDERR.
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

//! @appears report_debug
//! Print a debug message in the servers's debug log.
//! Shares argument prototype with @[sprintf()]
//! @seealso
//!  @[report_warning] @[report_notice] @[report_error]
//!  @[report_fatal]
void report_debug(string message, mixed ... args)
{
  mixed error;
  
  error = catch {
    if(sizeof(args)) 
      message = sprintf(message, @args);
  };
  
  if (error)
    nwrite("Warning: exception caught in report_debug. Cannot print the requested message.\n", 0, 2);
  else
    nwrite(message,0,2);

#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    if (!error) {
      foreach(message/"\n", message)
        syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
    } else {
      syslog(LOG_WARNING, "Warning: exception caught in report_debug. Cannot print the requested message.\n");
    }
#endif
}

//! @appears report_warning
//! Print a warning messages, that will show up in the server's debug log and
//! in the even logs, aloing with the yellow exclamation mark warning sign.
//! Shares argument prototype with @[sprintf()]
//! @seealso
//!  @[report_debug] @[report_notice] @[report_error] @[report_fatal]
void report_warning(string message, mixed ... args)
{
  mixed error;
  
  error = catch {
    if(sizeof(args)) 
      message = sprintf(message, @args);
  };
  
  if (error)
    nwrite("Warning: exception caught in report_warning. Cannot print the requested message.\n", 0, 2);
  else
    nwrite(message,0,2);

#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    if (!error) {
      foreach(message/"\n", message)
        syslog(LOG_WARNING, replace(message+"\n", "%", "%%"));
    } else {
      syslog(LOG_WARNING, "Warning: exception caught in report_warning. Cannot print the requested message.\n");
    }
#endif
}

//! @appears report_notice
//! Print a notice message of some sort for the servers's debug log and event
//! logs, along with the blue informational notification sign. Share argument
//! prototype from @[sprintf()].
//! @seealso
//!  @[report_debug] @[report_warning] @[report_error] @[report_fatal]
void report_notice(string message, mixed ... args)
{
  mixed error;
  
  error = catch {
    if(sizeof(args)) 
      message = sprintf(message, @args);
  };
  
  if (error)
    nwrite("Warning: exception caught in report_notice. Cannot print the requested message.\n", 0, 1);
  else
    nwrite(message,0,1);

#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    if (!error) {
      foreach(message/"\n", message)
        syslog(LOG_NOTICE, replace(message+"\n", "%", "%%"));
    } else {
      syslog(LOG_WARNING, "Warning: exception caught in report_notice. Cannot print the requested message.\n");
    }
#endif
}

//! @appears report_error
//! Print an error message, that will show up in the server's debug log
//! and in the even logs, along with the red exclamation mark sign. Shares
//! argument prototype with @[sprintf()]
//! @seealso
//!  @[report_debug] @[report_warning] @[report_notice] @[report_fatal]
void report_error(string message, mixed ... args)
{
  mixed error;
  
  error = catch {
    if(sizeof(args)) 
      message = sprintf(message, @args);
  };

  if (error)
    nwrite("Warning: exception caught in report_error. Cannot print the requested message.\n", 0, 3);
  else  
    nwrite(message,0,3);

#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    if (!error) {
      foreach(message/"\n", message)
        syslog(LOG_ERR, replace(message+"\n", "%", "%%"));
    } else {
      syslog(LOG_WARNING, "Warning: exception caught in report_error. Cannot print the requested message.\n");
    }
#endif
}

//! @appears report_fatal
//! Print a fatal error message. Shares argument prototype with @[sprintf()]
//! @seealso
//! @[report_debug] @[report_warning] @[report_notice] @[report_error]
void report_fatal(string message, mixed ... args)
{
  mixed error;
  
  error = catch {
    if(sizeof(args)) 
      message = sprintf(message, @args);
  };
  
  if (error)
    nwrite("Warning: exception caught in report_fatal. Cannot print the requested message.\n", 0, 3);
  else
    nwrite(message,0,3);

#if constant(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    if (!error) {
      foreach(message/"\n", message)
        syslog(LOG_EMERG, replace(message+"\n", "%", "%%"));
  } else {
      syslog(LOG_WARNING, "Warning: exception caught in report_fatal. Cannot print the requested message.\n");
    }
#endif
}

//! @appears popen
//! Starts the specified process and returns a string with the result.
//! Mostly a compatibility function, uses Process.create_process in new
//! programs
//! @param s
//!  The process to start
//! @param env
//!  Optional environment vars
//! @param uid
//!  Optional uid to run with.
//! @param gid
//!  Optional gid to run with.
//! @fixme 
//!   Compat call 
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
  mixed err = catch {
    proc = Process.create_process( ({"/bin/sh", "-c", s }), opts );
  };
  if (err) {
    perror("Cannot Process.popen() : %O\n",err);
    proc = 0;
  }
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

//!
//! @fixme
//!  Document this.
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

//! @appears spawne
//! Create a process
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

//! @appears spawn_pike
//! Start a new Pike process with the same configuration as the current one
int spawn_pike(array(string) args, void|string wd, object|void stdin,
               object|void stdout, object|void stderr)
{
  string cwd = getcwd();
  string pikebin = combine_path(cwd, [string]new_master->_pike_file_name ||
                                "bin/caudium");
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

//! Add a few cache control related efuns
object cache_manager() {
  if (! objectp( _cache_manager ) ) {
    _cache_manager = Cache.Manager(); 
  }
  return _cache_manager;
}
 
static private void initiate_cache()
{
  object cache=Cache.Compatible( cache_manager() );
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_clear", cache->cache_clear);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache", cache);
  add_constant("capitalize", lambda(string s){return upper_case(s[0..0])+s[1..];});
}

//!
class _error_handler {

  //!
  void compile_error(string a,int b,string c);

  //!
  void compile_warning(string a,int b,string c);
}

array(_error_handler) compile_error_handlers = ({});

//!
void push_compile_error_handler( _error_handler q )
{
  compile_error_handlers = ({q})+compile_error_handlers;
}

//!
void pop_compile_error_handler()
{
  compile_error_handlers = compile_error_handlers[1..];
}

//!
class LowErrorContainer
{
  string d;
  string errors="", warnings="";
  string get()
  {
    return errors;
  }

  //!
  string get_warnings()
  {
    return warnings;
  }

  //!
  void print_warnings(string prefix) {
    if(warnings && strlen(warnings))
      report_warning(prefix+"\n"+warnings);
  }

  //!
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

  //!
  void compile_error(string file, int line, string err)
  {
    got_error(file, line, "Error: " + err);
  }
 
  //!
  void compile_warning(string file, int line, string err)
  {
    got_error(file, line, "Warning: " + err, 1);
  }

  //!
  void create()
  {
    d = getcwd();
    if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
      d += "/";
  }
}

//! @appears ErrorContainer
class ErrorContainer
{
  inherit LowErrorContainer;

  //!
  void compile_error(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_error( file,line, err );
    else
      ::compile_error(file,line,err);
  }

  //!
  void compile_warning(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_warning( file,line, err );
    else
      ::compile_warning(file,line,err);
  }
}


//! privs.pike placeholder during bootstrap.
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

//! @decl in cd(string path)
//! @appears cd
//! Overloads the Pike cd function.
//! Don't allow cd() unless we are in a forked child.

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

//! Place holder.
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

//! Load Caudium for real
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

#ifdef TRACE_DESTRUCT
//! @appears destruct
//! Overload the Pike destruct function. If the webserver is
//! started with the TRACE_DESTRUCT define set, all destruct
//! call will be logged in the debug log.
void trace_destruct(mixed x)
{
  report_debug("DESTRUCT(%O)\n%s\n",
               x, describe_backtrace(backtrace()));
  destruct(x);
}
#endif /* TRACE_DESTRUCT */

//! Set up efuns and load Caudium.
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

#ifdef FD_DEBUG
//! Code to trace fd usage.
class mf
{
  inherit Stdio.File;

  //!
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

  //!
  void destroy()
  {
    catch { mark_fd(query_fd(),"CLOSED"); };
  }  

  //!
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

//! open() constant.
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

//! Make a $PATH-style string
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


//! Caudium bootstrap code.
int main(int argc, array(string) argv)
{
  // a hack for Pike 7.4+ installed in the traditional way
  // without this you will get a nice, long, voluminous
  // backtrace...
  object hack = Calendar.now();

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
#if !constant(strftime)
  add_constant("strftime", strftime);
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
  add_constant("mark_fd", mark_fd);

  initiate_cache();
  load_caudium();
  caudium->cache_manager = cache_manager();
  cache_manager()->caudium = caudium;
  int retval = caudium->main(argc, argv);
  perror_status_reported = 0;
  roxen_perror("\n-- Total boot time %4.3f seconds ---------------------------\n\n",
               (gethrtime()-start_time)/1000000.0);
  return(retval);
}

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
