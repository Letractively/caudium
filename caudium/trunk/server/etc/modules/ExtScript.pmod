// ExtScript.pmod -- external script handler for Roxen, originally
// ported to Caudium by Jan Legenhausen.
//
// Originally by Leif Stensson <leif@roxen.com>, June/July 2000.
//
// $Id$

//! External script handler for Roxen and Caudium. Used for "mod_perl"
//! like extension

//!
mapping scripthandlers = ([ ]);

//!
static void diag(string x)
{ // report_debug(x);
}

//!
class Handler
{ object  proc;
  object  pipe;
  object  pipe_other;
  string  binpath;
  mapping settings;
  int     runcount = 0;
  int     timeout;
#if constant(Thread.Mutex)
  object  mutex = Thread.Mutex();
#endif

  //!
  void terminate()
  {
#if constant(Thread.Mutex)
    object lock = mutex ? mutex->lock() : 0;
#endif
    if (proc && !proc->status() && pipe)
    {
      // send 'exit' command to subprocess
      pipe->write("X");
    }
  }

  //!
  int busy()
  {
#if constant(Thread.Mutex)
    if (mutex)
    { if (mutex->trylock()) return 0;
      return 1;
    }
#endif
    return 0;
  }

  //!
  int procstat()
  { return proc ? proc->status() : -1;
  }

  //!
  int probe()
  { return timeout < time(0);
  }

  //!
  static void putvar(string vtype, string vname, string vval)
  { pipe->write(sprintf("%s%c%s%c%c%c", vtype, strlen(vname), vname,
          strlen(vval)/65536, strlen(vval)/256, strlen(vval) & 255));
    pipe->write(vval);
  }

  //!
  static string launch_process(string how)
  { /* must have locked the mutex to call this function */

    if (proc && proc->status() == 0)
      return 0;

    pipe = Stdio.File();
    pipe_other = pipe->pipe();
    diag("(L1)");

    mapping opts = ([ "fds": ({ pipe_other }) ]);
    if (settings->set_uid) opts["set_uid"] = settings->set_uid;

    runcount = 0; pipe_other = 0;

    if (catch
        (proc = Process.create_process( ({ binpath, "--cmdsocket=3" }), opts))
       )
    { diag("(LError)"); 
      return "unable to start helper process";
    }

    diag("(LOk)");
    return 0;
  }

  //!
  static array do_helper(string how, string arg, object id, void|mapping opts)
  {
#if constant(Thread.Mutex)
    object lock = mutex ? mutex->lock() : 0;
#endif
    timeout = time(0) + 190;

    if (!proc || proc->status() != 0)
    {
      string err = launch_process("helper");
      if (err) return ({ -1, err });

      pipe->write("QP"); // send 'ping'
      string res = pipe->read(4);
      if (!stringp(res) || sizeof(res) < 4 || res[0] != '=')
      { proc = 0; pipe = 0;
        return
           ({ -1, sprintf("external process didn't respond (Got: %O)", res) });
      }

      diag("(NewSubprocess)");
      if (how == "run")
        putvar("L", "cd", dirname(arg));
      if (mappingp(settings))
        foreach( ({ "libdir", "cd" }), string s)
          if (settings[s] && stringp(settings[s]))
            putvar("L", s, settings[s]);
    }

    if (id)
    { int len, returncode = 200;
      mixed tmp;

      diag("{");
      // Reset script variables.
      pipe->write("R");

      // Environment variables.
      putvar("E", "GATEWAY_INTERFACE", "Caudium-Perl/0.9");

      foreach( ({ ({ "remoteaddr", "REMOTE_ADDR" }),
                  ({ "not_query", "PATH_INFO" }),
                  ({ "raw_url", "DOCUMENT_URI" }),
                  ({ "not_query", "DOCUMENT_NAME" }),
                  ({ "method", "REQUEST_METHOD" }),
                  ({ "prot", "SERVER_PROTOCOL" }),
                  ({ "realfile", "SCRIPT_FILENAME" })
               }), array x)
          if (stringp(id[x[0]]))
                putvar("E", x[1], id[x[0]]);

      foreach( ({ ({ "accept", "HTTP_ACCEPT" }),
                  ({ "connection", "HTTP_CONNECTION" }),
                  ({ "referer", "HTTP_REFERER" }),
                  ({ "user-agent", "HTTP_USER_AGENT" }),
                  ({ "pragma",     "HTTP_PRAGMA" }),
                  ({ "host", "HTTP_HOST" })
               }), array x)
          if (stringp(id->request_headers[x[0]]))
                putvar("E", x[1], id->request_headers[x[0]]);
	  if(tmp = caudium->real_file("/", id))
		putvar("E", "DOCUMENT_ROOT", tmp);

      // Transfer Roxen-internal request info.
      foreach( ({ "query", "not_query", "raw", "remoteaddr", "realfile",
                  "virtfile", "prot", "method", "rawauth", "realauth",
                  "raw_url" }),
               mixed v)
        if (stringp(v) && stringp(id[v]) && strlen(id[v]) < 1000000)
           putvar("I", v, id[v]);
      if (arrayp(id->auth) && sizeof(id->auth) > 1)
      {
        if (stringp(id->auth[0]) && stringp(id->auth[1]))
        { putvar("I", "auth_type", id->auth[0]);
          putvar("E", "AUTH_TYPE", id->auth[0]);
          array arr = id->auth[1] / ":";
          putvar("I", "auth_user", arr[0]);
          putvar("E", "REMOTE_USER", arr[0]);
          if (sizeof(arr) > 1) putvar("I", "auth_passwd", arr[1]);
        }
        else if (sizeof(id->auth) == 3 && intp(id->auth[0]))
        { putvar("I", "auth_type", "Basic");
          putvar("E", "AUTH_TYPE", "Basic");
          if (stringp(id->auth[1]))
          { putvar("I", "auth_user", id->auth[1]);
            putvar("E", "REMOTE_USER", id->auth[1]);
	    putvar("E", "REMOTE_PASSWORD", (id->realauth/":")[1]);
          }
          if (stringp(id->auth[2])) putvar("I", "auth_passwd", id->auth[2]);
        }
      }

      if (stringp(id->query))
        putvar("E", "QUERY_STRING", id->query);

      // Transfer explicit environment variables.
      mapping ee = id->misc->explicit_script_env;
      if (mappingp(ee))
        foreach(indices(ee), mixed v)
          if (stringp(v) && stringp(ee[v]) && strlen(ee[v]) < 25000)
            putvar("E", v, ee[v]);

      // Transfer request headers
      array hd;
      foreach( indices(hd = id->request_headers), mixed v)
        if (stringp(v) && stringp(hd[v]) && strlen(hd[v]) < 1000000)
           putvar("H", v, hd[v]);

      // Transfer FORMs variables.
      array va;
      foreach(indices(va = id->variables), mixed v)
        if (stringp(v) && stringp(va[v]) && strlen(va[v]) < 1000000)
           putvar("F", v, va[v]);

      // ping - check if subprocess is still alive
      pipe->write("QP");
      string res = pipe->read(4);
      if (!stringp(res) || sizeof(res) != 4 || res[0] != '=' || res[3] != 0)
      { pipe = 0; proc = 0; diag("@");
#if constant(Thread.Mutex)
        lock = 0;
#endif
        if (!opts || !opts->retry)
          return do_helper(how, arg, id,
                             (opts ? opts : ([ ])) + ([ "retry": 1 ]) );
        else
          return ({ -1, "Failed to start subprocess" });
      }

      // start operation
      diag("$");
      len = strlen(arg);
      pipe->write(sprintf("%c%c%c%c%s", how == "eval" ? 'C' : 'S',
                   len/65536, len/256, len&255, arg));
      string output = "";

      while (sizeof(res = pipe->read(1)) > 0)
      { diag("."+res);
        if (res == "a") continue;
        else if (res == "X") { return ({ -1, "SCRIPT ERROR (1)" });}
        else if (res == "+" || res == "*" || res == "?" || res == "=")
        { string tmp = pipe->read(3);
          len = tmp[1]*256 + tmp[2];
          diag("<");
          tmp = pipe->read(len);
          diag(">");
          if (stringp(tmp))
          { if (res == "=")
            { array arr = tmp / "=";
              if (arr[0] == "RETURNCODE")
                if (sscanf(arr[1], "%d", returncode) != 1)
                  returncode = 200;
            }
            else if (res == "?")
            { return ({ -1, tmp });
            }
            else output += tmp;
          }
          if (res == "*" || res == "?") break;
        }
        /* else ... support queries from script ... */
      }
      diag("<Done.>");
      if (res == "" || res == 0)
	if (output == "")
           return ({ -1, "SCRIPT I/O ERROR (2)" });

      if (++runcount > 5000) proc = 0, pipe = 0;

      diag("}");

      return ({ returncode, output });
    }
    else return ({ -1, "[Internal error?]" });
  }

  //!
  array run(string path, object id)
  { return do_helper("run", path, id);
  }

  //!
  array eval(string expr, object id)
  { return do_helper("eval", expr, id);
  }

  //!
  void create(string helper_program_path, void|mapping settings0)
  { binpath = helper_program_path;
    settings = settings0 ? settings0 : ([ ]);
    proc = 0; pipe = 0;
    timeout = time(0) + 300;
  }
}

#if constant(Thread.Mutex)
object dispatchmutex = Thread.Mutex();
#endif

//!
static int lastobjdiag = 0;

//!
static void objdiag()
{ if (lastobjdiag > time(0)-25) return;
  lastobjdiag = time(0);
  diag("Subprocess status:\n");
  foreach(indices(scripthandlers), string binpath)
  { mapping m = scripthandlers[binpath];
    string line = "  " + binpath;
    int     n = 0;
    foreach(m->handlers, object h)
      if (h)
        line += "  H" + (++n) + "=" + h->procstat();
    diag(line + "\n");
  }
}

//!
static int lastcleanup = 0;

//!
void periodic_cleanup()
{ int now = time(0);
  if (lastcleanup+42 < now)
  { lastcleanup = now;
    foreach(indices(scripthandlers), string binpath)
    { mapping m = scripthandlers[binpath];
      if (m->expire < now)
      {
#if constant(Thread.Mutex)
        object lock = m->mutex->lock();
#endif
  	diag("(Z)");
  	if (m->handlers[0])
  	{ if (m->handlers[0]->probe())
  	  { diag("(*T*)");
  	    m->handlers[0]->terminate();
  	  }
  	}
  
  	if (sizeof(m->handlers) > 1)
  	   m->handlers = m->handlers[1..];
  	else
  	   m->handlers = ({ 0 });
  	now = time(0);
  	m->expire   = now+600/(2+sizeof(m->handlers));
#if constant(Thread.Mutex)
  	lock = 0;
#endif
      }
    }
  }
  call_out(periodic_cleanup, 50);
  objdiag();
}

//!
object getscripthandler(string binpath, void|int multi, void|mapping settings)
{ mapping m;
  object  h;
  object  lock;
  int     i;

  if (!intp(multi) || multi < 1) multi = 1;

  objdiag();

  if (!(m = scripthandlers[binpath])) 
  {
#if constant(Thread.Mutex)
    lock = dispatchmutex->lock();
#endif
    scripthandlers[binpath] = m =
       ([ "handlers": ({ Handler(binpath) }),
          "expire": time(0) + 600,  
#if constant(Thread.Mutex)
          "mutex": Thread.Mutex(),
#endif
          "binpath": binpath
        ]);
  }

#if constant(Thread.Mutex)
  lock = m->mutex->lock();
#endif
  for(i = 0; i < multi && i < sizeof(m->handlers); ++i)
    if (h = m->handlers[i])
    { if (!h->busy())
      { if (!h->procstat())
          return h;
        else return h;
      }
    }

  for(i = 0; i < sizeof(m->handlers); ++i)
    if (m->handlers[i] == 0)
      return m->handlers[i] = Handler(binpath);

  if (i < multi && multi < 10) // Another handler.
  { m->handlers += ({ h = Handler(binpath, settings) });
    return h;
  }

  return m->handlers[random(sizeof(m->handlers))];
}

