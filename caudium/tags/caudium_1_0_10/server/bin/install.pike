#!bin/pike -m lib/pike/master.pike

/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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
 * name = "Caudium Install Script ";
 * doc = "Main part of the install script that is run upon installation of caudium";
 */

string cvs_version = "$Id$";

import Stdio;

array(int) caudium_fstat(string|object file, int|void nolink) {
  mixed st;
  if(objectp(file)) {
    if(file->stat)
      st = (array(int))file->stat();
    else
      throw("caudium_fstat: Object not a file.\n");
  }    
  else
    st = predef::file_stat(file, nolink);
  if(st) return (array(int))st;
  return 0;
}

#include <caudium.h>

#undef DEBUG
#undef DEBUG_LEVEL

string version = "1.0";

object stderr = File("stderr");

void roxen_perror(string format,mixed ... args)
{
  string s;
  if(sizeof(args)) format=sprintf(format,@args);
  if (format=="") return;
  stderr->write(format);
}


void report_error(string s)
{
  werror(s);
}

void report_fatal(string s)
{
  werror(s);
}

object caudiump()
{
  return this_object();
}

class Readline
{
#if constant(Stdio.Readline)
  inherit Stdio.Readline;
#endif

  void trap_signal(int n)
  {
    werror("Interrupted, exit.\r\n");
    destruct(this_object());
    exit(1);
  }

  void dumb(int on) {
#if constant(Stdio.Readline)
    get_input_controller()->dumb = on;
#else
    if(on) write(Process.popen("stty -echo"));
    else write(Process.popen("stty echo"));
#endif
  }
  
  void destroy()
  {
#if constant(Stdio.Readline)
    get_input_controller()->dumb = 0;
    ::destroy();
#endif
    signal(signum("SIGINT"));
  }

  private string safe_value(string r)
  {
    if(!r)
    {
      /* C-d? */
      werror("\nTerminal closed, exit.\n");
      destruct(this_object());
      exit(1);
    }
	
    return r;
  }
    

  string edit(string def, string prompt, mixed ... args)
  {
    
#if constant(Stdio.Readline)
    if(def)
      prompt += ": ";
    else prompt += " ";
    return safe_value(::edit(def||"", prompt, @args));
#else
    string res;
    if(def) prompt = "[1m" + prompt +" ["+def+"]:[0m ";
    else    prompt = "[1m" +prompt +"[0m ";
#if constant(readline)
    res = safe_value(readline(prompt));
#else
    write(prompt);
    res = gets();
#endif
    if(!strlen(res) && def) return def;
    return res;
#endif
  }
  
  void create(mixed ... args)
  {
    signal(signum("SIGINT"), trap_signal);
#if constant(Stdio.Readline)
    ::create(@args);
#endif
  }
}

string read_string(Readline rl, string prompt, string|void def)
{
  return rl->edit(def, prompt, ({ "bold" })) || "";
}

object|void open(string filename, string mode, int|void perm)
{
  object o;
  o = File();
  if(o->open(filename, mode, perm || 0666)) {
#ifdef DEBUG
    perror("Opened fd "+o->query_fd()+"\n");
#endif /* DEBUG */
    return o;
  }
  destruct(o);
}

void mkdirhier(string from, int|void mode)
{
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    if (query_num_arg() > 1) {
      mkdir(b+a, mode);
#if constant(chmod)
      array(int) stat = file_stat (b + a, 1);
      if (stat && stat[0] & ~mode)
	// Race here. Not much we can do about it at this point. :\
	catch (chmod (b+a, stat[0] & mode));
#endif
    }
    else mkdir(b+a);
    b+=a+"/";
  }
}

mapping(string:mixed) variables = ([ "audit":0 ]);

// We never need to change privileges...
mixed Privs(mixed ... args) { return 0; }

#define VAR_VALUE 0
#define IN_INSTALL 1
#include "../base_server/read_config.pike"

void setglobvar(string var, mixed value)
{
  mapping v;
  v = retrieve("Variables", 0);
  v[var] = value;
  store("Variables", v, 1, 0);
}


int run(string file,string ... foo)
{
  string path;
  if(search(file,"/") != -1)
    return exece(combine_path(getcwd(),file),foo);

  path=getenv("PATH");

  foreach(path/":",path)
    if(file_stat(path=combine_path(path,file)))
      return exece(path, foo);

  return 69;
}

int verify_port(string port)
{
  int ret, try;
  object p;
  if(!strlen(port) || sizeof(port/"" - "1234567890"/"")) {
     return 0;
  } else
    sscanf(port, "%d", try);
  p = Stdio.Port();
  ret = p->bind(try);
  destruct(p);
  return ret;  
}

int getport()
{
  object p;
  int port;
  int tries;

  p = Stdio.Port();

  for (tries = 8192; tries--;) {
    if (p->bind(port = 10000 + random(10000))) {
      destruct(p);
      return(port);
    }
  }
  write("Failed to find a free port (tried 8192 different)\n"
	"Pike's socket-implementation might be broken on this architecture.\n"
	"Please run \"make verify\" in the Pike build-tree to test Pike.\n");
  destruct(p);
  return(0);
}


private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
#if constant(gethostbyname) && constant(gethostname)
    f = gethostbyname(gethostname()); /* First try.. */
    if(f)
      foreach(f, f)
	if(arrayp(f))
	{
	  foreach(f, t)
	    if(search(t, ".") != -1 && !(int)t)
	      if(!s || strlen(s) < strlen(t))
		s=t;
	} else
	  if(search((t=(string)f), ".") != -1 && !(int)t)
	    if(!s || strlen(s) < strlen(t))
	      s=t;
#endif
    if(!s)
    {
      t = read_bytes("/etc/resolv.conf");
      if(t) 
      {
	if(sscanf(t, "%*sdomain%*[ \t]%s\n", s)!=3)
	  if(sscanf(t, "%*ssearch%*[ \t]%[^ ]", s)!=3)
	    s="nowhere";
      } else {
	s="nowhere";
      }
      s = "host."+s;
    }

  sscanf(s, "%*s.%s", s);
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown"; 
  }
  return s;
}

string find_arg(array argv, array|string shortform, 
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
	  if(arrayp(longform) && search(longform, tmp[2..1000]) != -1)
	  {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  } else if(longform && longform == tmp[2..10000]) {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  }
	}
	if((arrayp(shortform) && ((search(shortform, argv[i][1..1]) != -1)))
	   || (stringp(shortform) && (shortform == argv[i][1..1])))
	{
	  if(strlen(argv[i]) == 2)
	  {
	    if(i < sizeof(argv)-1)
	      value =argv[i+1];
	    argv[i] = argv[i+1] = 0;
	    return value;
	  } else {
	    value=argv[i][2..100000];
	    argv[i]=0;
	    return value;
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

class Environment
{
  static string filename;
  static mapping(string:array(string)) env, oldenv;

  static void read()
  {
    string var, def;
    multiset(string) exports = (<>);
    env = ([]);
    oldenv = ([]);
    object f = open(filename, "r");
    if(!f)
      return;
    foreach(f->read()/"\n", string line)
      if(sscanf(line-"\r", "%[A-Za-z0-9_]=%s", var, def)==2)
      {
	string pre, post;
	if(2==sscanf(def, "%s${"+var+"}%s", pre, post) ||
	   2==sscanf(def, "%s$"+var+"%s", pre, post))
	{
	  if(pre=="")
	    pre = 0;
	  else if(pre[-1]==':')
	    pre = pre[..sizeof(pre)-2];
	  else if(2==sscanf(reverse(pre), "}:+:%*[^{]{$%s", pre))
	    pre = reverse(pre);
	  if(post=="")
	    post = 0;
	  else if(post[0]==':')
	    post = post[1..];
	  else 
	    sscanf(post, "${%*[^:}]:+:}%s", post);
	  env[var] = ({ pre, 0, post });
	}
	else
	  env[var] = ({ 0, def, 0 });
      }
      else if(sscanf(line, "export %s", var))
	foreach((replace(var, ({"\t","\r"}),({" "," "}))/" ")-({""}), string v)
	  exports[v] = 1;
    foreach(indices(env), string e)
      if(!exports[e])
	m_delete(env, e);
    oldenv = copy_value(env);
  }

  static void write()
  {
    object f = open(filename, "cwt");
    if(!f) {
      perror("Failed to write "+filename+"\n");
      return;
    }
    f->write("# This file is automatically generated by "
	     "the Caudium install script.\n");
    f->write("# Edit it at your own risk.  :-)\n\n");
    foreach(sort(indices(env)), string var)
    {
      array(string) v = env[var];
      if(v && (v[0]||v[1]||v[2]))
      {
	f->write(var+"=");
	if(v[1])
	  f->write((v[0]? v[0]+":":"")+v[1]+(v[2]? ":"+v[2]:""));
	else if(!v[0])
	  // Append only
	  f->write("${"+var+"}${"+var+":+:}"+v[2]);
	else if(!v[2])
	  // Prepend only
	  f->write(v[0]+"${"+var+":+:}${"+var+"}");
	else
	  // Prepend and append
	  f->write(v[0]+"${"+var+":+:}${"+var+"}:"+v[2]);
	f->write("\nexport "+var+"\n");
      }
    }
    f->close();
  }

  static int changed()
  {
    return !equal(env, oldenv);
  }

  void append(string var, string val)
  {
    array(string) v = env[var];
    if(!v)
      v = env[var] = ({ 0, 0, 0 });
    foreach(val/":", string comp)
      if((!v[2]) || search(v[2]/":", comp)<0)
	v[2] = (v[2]? v[2]+":":"")+comp;
  }

  void prepend(string var, string val)
  {
    array(string) v = env[var];
    if(!v)
      v = env[var] = ({ 0, 0, 0 });
    foreach(val/":", string comp)
      if((!v[0]) || search(v[0]/":", comp)<0)
	v[0] = comp+(v[0]? ":"+v[0]:"");
  }

  void set(string var, string val)
  {
    array(string) v = env[var];
    if(!v)
      v = env[var] = ({ 0, 0, 0 });
    v[1] = val;
  }

  string get(string var)
  {
    array(string) v = env[var];
    return v && (v-({0}))*":";
  }

  int finalize()
  {
    if(!changed())
      return 0;
    write();
    return 1;
  }

  void create(string fn)
  {
    filename = fn;
    read();
  }

}

void config_env(object(Environment) env)
{
  write("[1m               Caudium Environment Setup\n"
	"               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m\n\n"
	"Please wait while checking your system...\n\n");
  string dir = "etc/env.d";
  foreach(glob("*.pike", get_dir(dir)||({})), string e)
  {
    program p = compile_file(dir+"/"+e);
    object eo = p();
    if(eo)
      eo->run(env);
  }
}

string gets(void|int sp)
{
  string s="", tmp;
  
  while((tmp = stdin -> read(1)))
    switch(tmp)
    {
    case "\010":
      s = s[0..strlen(s) - 2];
      break;

    case " ":  case "\t":  case "\r":
      if(!sp)
	while((stdin -> read(1)) != "\n") 
	  ;
      else {
	s += tmp;
	break;
      }
    case "\n":
      // Truncate any terminating spaces.
      while (sizeof(s) && (s[-1] == ' ')) {
	s = s[..sizeof(s)-2];
      }
      return s;
	
    default:
      s += tmp;
    }
}
void main(int argc, string *argv)
{
  string host, client, log_dir, domain, var_dir, user, pass, pass2;
  mixed tmp;
  int port, configuration_dir_changed, logdir_changed;
  string prot_prog = "http";
  string prot_spec = "http://";
  string prot_extras = "";
  Readline rl = Readline();

  add_constant("roxen", this_object());
  add_constant("perror", roxen_perror);
  add_constant("roxen_perror", roxen_perror);
  add_constant("gets", gets);
  if(find_arg(argv, "?", "help"))
  {
    perror(sprintf("Syntax: %s [-d DIR|--config-dir=DIR] [-l DIR|--log-dir=DIR] [--no-env-setup]\n"
		   "This program will set some initial variables in Caudium.\n"
		   , argv[0]));
    exit(0);
  }

  if(find_arg(argv, "v", "version"))
  {
    perror("Caudium Install version "+cvs_version+"\n");
    exit(0);
  }

  configuration_dir =
    find_arg(argv, "d", ({ "config-dir", "config",
			   "configuration-directory" }),
	     ({ "CAUDIUM_CONFIGDIR", "CONFIGURATIONS" }),
	     "../configurations");
  
  log_dir = find_arg(argv, "l", ({ "log-dir", "log-directory", }),
		     ({ "CAUDIUM_LOGDIR" }),
		     "../logs/");
  var_dir = find_arg(argv, "l", ({ "var-dir","var-directory", }),
		     ({ "CAUDIUM_VARDIR" }),
		     "../var/");

  write(Process.popen("clear"));
  host=gethostname();
  domain = get_domain();
  if(search(host, domain) == -1)
    host += "."+domain;
  if(sscanf(host, "%s.0", tmp))
    host=tmp;

  if(!find_arg(argv, 0, "no-env-setup"))
  {
    object envobj = Environment("etc/environment");

    config_env(envobj);

    if(envobj->finalize()) {
      if(find_arg(argv, 0, "recheck-env")) {
	write("Environment has changed.\n");
	exit(0);
      }
      write("Environment has changed.  Rerunning install script.\n");
      Process.system("./start " + argv[1..] * " " +
		     " --no-env-setup --once --program bin/install.pike");
      exit(0);
    } else {
      if(find_arg(argv, 0, "recheck-env")) {
	write("Environment not changed.\n");
	exit(0);
      }
      write(Process.popen("clear"));
    }
  }

  write("[1m              Caudium Installation Script\n"
	"              ^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m\n");
  do { 
    write("\n   Enter the full hostname of your computer (hostname.domain).\n\n");
    tmp = read_string(rl, "Full Hostname", host);

    if(strlen(tmp))
      host=tmp;

    write("\n   Enter the port number for the configuration interface.\n\n");
    while(1)
    {
      port = getport();
      tmp = read_string(rl, "Port Number",
			(string)port);
      if(!strlen(tmp))
	continue;
    
      if(verify_port(tmp)) {
	port=(int)tmp;
	break;
      }
    
      if(getuid() != 0 && port < 1000)
	write("\n   You need to be superuser to open a port under 1000. ");
      else
	write("\n   That port number is already used or invalid. ");
      write("Choose another one.\n\n");
    }

    write("\n   Enter the directory where Caudium will store its configuration files.\n\n");
    while(1)
    {
      tmp = read_string(rl, "Configurations Directory",
			configuration_dir);
    
      if(strlen(tmp))
	configuration_dir = tmp;
      if(configuration_dir[-1] != '/')
	configuration_dir += "/";
      if(sizeof(list_all_configurations())) 
	write("\n   Caudium is already installed in that directory! "
	      "Choose another one.\n\n");
      else 
	break;
    }
    write("\n   Please select a directory where Caudium can store various"
	  "\n   configuration interface options.\n\n");
    tmp = read_string(rl, "State Directory", var_dir);

    if(strlen(tmp)) var_dir = tmp;
    if(var_dir[-1] != '/')
      var_dir += "/";

    write("\n   Please select the directory where Caudium logs will be "
	  "stored.\n\n");

    tmp = read_string(rl, "Log Directory", log_dir);

    if(strlen(tmp))
      log_dir = tmp;
    if(log_dir[-1] != '/')
      log_dir += "/";
      
    if(log_dir != "../logs/")
      logdir_changed = 1;

    if(configuration_dir != "../configurations" && 
       configuration_dir != "../configurations/")
      configuration_dir_changed = 1;

      write("\n   Please enter a name for the configuration interface"
	    "\n   administrator user.\n\n");
    do
    {
      user = read_string(rl, "Administrator User Name", "admin");
    } while(((search(user, "/") != -1) || (search(user, "\\") != -1)) &&
	    write("  User name may not contain slashes.\n\n"));

      write("\n   Please select a password with one or more characters. "
	    "You will\n   be asked to type the password twice for "
	    "verification.\n\n");
    do
    {
      rl->dumb(1);
      pass = read_string(rl, "Administrator Password:", 0);
      if(!strlen(pass)) {
	write("\n\n   You need to enter a password with one or more characters.\n\n");
	pass = 0;
      } else {
	pass2 = read_string(rl, "(again)", 0);
	rl->dumb(0);
	write("\n");
	if(pass != pass2) {
	  write("\n   The passwords didn't match. Try again.\n\n");
	  pass = 0;
	}
      }
    } while(!pass);

#if !defined(__MAJOR__) || __MAJOR__ < 7
    write("\nSSL3 with Pike 0.6 not supported -- using the http protocol.\n\n");
#else
    /* SSL Checks */
    int have_gmp = 0;
    catch(have_gmp = sizeof(indices(master()->resolv("Gmp"))));
    int have_crypto = 0;
    catch(have_crypto = sizeof(indices(master()->resolv("_Crypto"))));
    write("\n");
    if (have_gmp && have_crypto) {
      tmp = read_string(rl, "Use SSL3 (https://) for the configuration interface [Y/n]?", 0) - " ";
      
      if (!strlen(tmp) || lower_case(tmp)[0] != 'n') {
	prot_prog = "ssl3";
	prot_spec = "https://";
	prot_extras = "cert-file demo_certificate.pem";
	
	write("\n   Using SSL3 with the demo certificate \"demo_certificate.pem\"."
	      "\n   It is recommended that you change the certificate to one of your own.\n\n");
      }
    } else {
      if (have_crypto) {
	write("\n   [1mNo Gmp-module  -- using http for the configuration-interface[0m.\n");
      } else {
	write("\n   [1mCrypto module module missing -- using the http protocol[0m.\n");
      }
    }
#endif
  } while( strlen( tmp = read_string(rl, "Are the settings above correct [Y/n]?", 0) ) && lower_case(tmp)[0]=='n' );


  mkdirhier("../local/modules/");

  write(sprintf("\nStarting Caudium on %s%s:%d/ ...\n\n",
		prot_spec, host, port));
  
  setglobvar("_v",  CONFIGURATION_FILE_LEVEL);
  setglobvar("ConfigPorts", ({ ({ port, prot_prog, "ANY", prot_extras }) }));
  setglobvar("ConfigurationURL",  prot_spec+host+":"+port+"/");
  setglobvar("logdirprefix", log_dir);
  setglobvar("ConfigurationStateDir", var_dir);
  setglobvar("ConfigurationUser", user);
  setglobvar("ConfigurationPassword", crypt(pass));
  
  Process.popen("./start "
		+(configuration_dir_changed?
		  "--config-dir="+configuration_dir
		  +" ":"")
		+(logdir_changed?"--log-dir="+log_dir+" ":"")
		+argv[1..] * " ");
  
  if(configuration_dir_changed || logdir_changed)
    write("\nAs you use non-standard directories for the configuration \n"
	  "and/or the logging, you must remember to start the server using\n"
	  "the correct options. Run './start --help' for more information.\n");
  
  sleep(4);
  
  write("\nYour Caudium server configuration interface is now configured.\n"
	"Tune your favourite browser to "+prot_spec+host+":"+port+"/ to \n"
	"continue setting up your server.\n");
}
