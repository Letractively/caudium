#!bin/pike -m lib/pike/master.pike

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
 * name = "Caudium Install Script ";
 * doc = "Main part of the install script that is run upon installation of caudium";
 */

string cvs_version = "$Id$";

import Stdio;
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

int verify_port(int try)
{
  int ret;
  object p;
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
	"Please run \"make verify\" in the build-tree to check pike.\n");
  destruct(p);
  return(0);
}

string gets(void|int sp)
{
// #if efun(readline)
//   return readline("");
// #else
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
// #endif
}

private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
#if efun(gethostbyname) && efun(gethostname)
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

void main(int argc, string *argv)
{
  string host, client, log_dir, domain;
  mixed tmp;
  int port, configuration_dir_changed, logdir_changed;
  string prot_prog = "http";
  string prot_spec = "http://";
  string prot_extras = "";

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

  configuration_dir = find_arg(argv, "d", ({ "config-dir",
					       "config",
					       "configurations",
					       "configuration-directory" }),
			       ({ "CAUDIUM_LOGDIR" }),
			       "../configurations");
  
  log_dir = find_arg(argv, "l", ({ "log-dir",
				     "log-directory", }),
		     ({ "CAUDIUM_CONFIGDIR", "CONFIGURATIONS" }),
		     "../logs/");

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

#ifndef __NT__
    config_env(envobj);
#endif

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
	"              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m\n"
	"On all questions, press return to use the default value.\n\n"
	"Enter the full hostname of your computer (hostname.domain).\n"
	"[1mFull Hostname [ "+host+" ][0m: ");
  tmp = gets();

  if(strlen(tmp))
    host=tmp;

  while(1)
  {
    port = getport();
    write("[1mConfiguration Interface Port Number [ "+port+" ][0m: ");
    tmp = gets();
    if(strlen(tmp))
      tmp = (int)tmp;
    else
      break;
    
    if(verify_port((int)tmp)) {
      port=tmp;
      break;
    }
    
    if(getuid() != 0 && tmp < 1000)
      write("You need to be superuser to open a port under 1000. ");
    else
      write("That port number is already used or invalid. ");
    write("Choose another one.\n");
  }

  while(1)
  {
    write("[1mConfigurations Directory [ "+configuration_dir+" ][0m: ");
    tmp = gets();
    if(strlen(tmp))
      configuration_dir = tmp;
    if(configuration_dir[-1] != '/')
      configuration_dir += "/";
    if(sizeof(list_all_configurations())) 
      write("Caudium is already installed in that directory! "
	    "Choose another one.\n");
    else 
      break;
  }
  write("[1mLog Directory [ "+log_dir+" ][0m: ");
  tmp = gets();
  if(strlen(tmp))
    log_dir = tmp;
  if(log_dir[-1] != '/')
    log_dir += "/";
      
  if(log_dir != "../logs/")
    logdir_changed = 1;

  if(configuration_dir != "../configurations" && 
     configuration_dir != "../configurations/")
    configuration_dir_changed = 1;

  mkdirhier("../local/modules/");

  int have_gmp = 0;
  catch(have_gmp = sizeof(indices(master()->resolv("Gmp"))));
  int have_crypto = 0;
  catch(have_crypto = sizeof(indices(master()->resolv("_Crypto"))));
  int have_ssl3 = 0;
  have_ssl3 = file_stat("protocols/ssl3.pike") != 0;

  if (have_gmp && have_crypto && have_ssl3) {
    write("[1mUse SSL3 (https://) for the configuration-interface [Y/n][0m? ");
    tmp = gets() - " ";
    if (!strlen(tmp) || lower_case(tmp)[0] != 'n') {
      prot_prog = "ssl3";
      prot_spec = "https://";
      prot_extras = "cert-file demo_certificate.pem";

      write("Using SSL3 with the demo certificate \"demo_certificate.pem\".\n"
	    "It is recommended that you change the certificate to one of your own.\n");
    }
  } else {
    if (have_crypto && have_ssl3) {
      write("[1mNo Gmp-module -- using http for the configuration-interface[0m.\n");
    } else {
      write("[1mExport version -- using http for the configuration-interface[0m.\n");
    }
  }

  if( file_stat("manual") && file_stat("manual")[1] == -2 )
  {
    if( file_stat("manual/parsed.tar") ) {
      write("\nInstalling parsed manual...\n");
      Process.popen("/bin/sh -c 'cd manual && tar xf parsed.tar"
		    " && rm parsed.tar'");
    }
    if( file_stat("manual/unparsed.tar") ) {
      write("\nInstalling unparsed manual...\n");
      Process.popen("/bin/sh -c 'cd manual && tar xf unparsed.tar"
		    " && rm unparsed.tar'");
    }
  }

  write(sprintf("\nStarting Caudium on %s%s:%d/ ...\n\n",
		prot_spec, host, port));
  
  setglobvar("_v",  CONFIGURATION_FILE_LEVEL);
  setglobvar("ConfigPorts", ({ ({ port, prot_prog, "ANY", prot_extras }) }));
  setglobvar("ConfigurationURL",  prot_spec+host+":"+port+"/");
  setglobvar("logdirprefix", log_dir);

  write(Process.popen("./start "
		      +(configuration_dir_changed?
			"--config-dir="+configuration_dir
			+" ":"")
		      +(logdir_changed?"--log-dir="+log_dir+" ":"")
		      +argv[1..] * " "));
  
  if(configuration_dir_changed || logdir_changed)
    write("\nAs you use non-standard directories for the configuration \n"
	  "and/or the logging, you must remember to start the server using\n"
	  "the correct options. Run './start --help' for more information.\n");
  
  sleep(4);
  
  write("\nCaudium is configured using a forms capable World Wide Web\n"
	"browser. Enter the name of the browser to start, including\n"
	"needed (if any) command line options.\n\n"
	"If you are going to configure remotely, or already have a browser\n"
	"running, just press return.\n\n"
	"[1mWWW Browser: [0m");
  
  tmp = gets(1);
  if(strlen(tmp))
    client = tmp;
  if(client)
  {
    if (prot_prog == "ssl3") {
      write("Waiting for SSL3 to initialize...\n");
      sleep(40);
    } else {
      sleep(10);
    }
    write("Running "+ client +" "+ prot_spec+host+":"+port+"/\n");
    run((client/" ")[0], @(client/" ")[1..100000], 
	prot_spec+host+":"+port+"/");
  } else
    write("\nTune your favourite browser to "+prot_spec+host+":"+port+"/\n");
}
