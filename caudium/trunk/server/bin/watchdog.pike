#!/usr/local/bin/pike06-zino
/* Caudium Watchdog       Copyright Idonex AB     1998
 *                                  Caudium Group 2003
 * Written by Peter Bortas <peter@idonex.se> in Mars -98
 * This version maintained by the caudium group <general@caudium.info>
 *
 */

#define RCDIR ""
#define RCFILE "dog.rc"
#define LOGFILE "doglog"
#define STD_REBOOT 240
#define STD_MAIN "/"

object nlog;
string pid;
mapping opts=([]);
array servers=({});

// Formatted timestamp
string timestamp( int time )
{
  mapping t = localtime( time );

  //No this is not a Y2k bug!!
  return sprintf( "[%d-%02d-%02d %02d:%02d:%02d]",
		  t->year+1900, t->mon+1, t->mday, t->hour, t->min, t->sec );
}

// Logger function.
void log( string message )
{
  //  nlog->add( ({ message }) );
  string logstring = timestamp(time(1)) +" "+ message;
  logstring += "\n";

  nlog->write( logstring );
  werror( logstring );
}

string table( array b )
{
  string ret = "";
  int first=1;
  foreach( b, array foo )
  {
    string t="";
    if( first )
      first=0;
    else
      t ="\t\t";
    foreach( foo, string tmp )
      t += tmp +"\t";
    
    ret += t +"\n";
  }
  return ret;
}

// Read the resource file
mapping read_rc(int|void nonull)
{
  mapping rc = ([]);
  string r = cpp(Stdio.read_bytes( RCFILE ));
  if(!r) return rc;
  int i;
  foreach(r/"\n", string l)
  {
    string var,type,value;
    i++;
    l = (replace(l, ({"\t","="}), ({" "," "}))/" "-({""}))*" ";
    if(!strlen(l) || l[0]=='#' || l==" ") continue;
    if(sscanf(l, "%s %s", var, value) != 2)
      rc[lower_case(l-" ")]=1;
    else if(rc[lower_case(var)])
      rc[lower_case(var)]+=(nonull?":":"\0")+value;
    else
      rc[lower_case(var)]=value;
  }
  return rc;
}

class Puppy
{
  //Server
  string name, ip;
  int port;

  //What
  string file;

  //Times
  int intervall, connect_timeout, read_timeout;

  //Alerts
  int nr_lowalert, nr_highalert;
  function action_lowalert, action_highalert;

  //States
  int down=0;        //Number of times mountpoints have been reported as down.
  int since=0;
  string reason="";

  //Various rc. passed on to the actions.
  mapping rc;

  //Mapping to keep a few states.
  // mp_unlike    Number of times mountpoints have been reported as diffrent
  //              from values stored on disk.
  // panic        Panic in progress.
  //mapping state = ([]);

  void ok(object f, string data)
  {
    remove_call_out( failed );
    f->set_nonblocking( 0, 0, 0 );
    f->close();
    if( down >= nr_lowalert )
    {
      int t=time();
      action_lowalert( "Reastablished contact with "+ name
		       + ", after "
		       + ((t-since)/3600)+"h"
		       + (((t-since)/60)%60)+"m.\n", rc, 1 );
    }
    down=0;
  }

  void failed(object f)
  {
    if (objectp(f)) destruct(f);
    
    if (!down++)
      since=time();
    else if (down==nr_lowalert)
    {
      int t=time();
      action_lowalert(
	    "WARNING! SERVER DOWN!\n\n"+name+" ("+ip+"), mountpoint \""+
	    file +"\" down, symptom:\n"+
	    reason+"\n\n"
	    "The server has been down for "+
	    ((t-since)/3600)+"h"+
	    (((t-since)/60)%60)+"m"+
	    ((t-since)%60)+"s.\n", rc);
    }
    else if(down==nr_highalert)
    {
      int t=time();
      action_highalert(
	    "PANIC! SERVER DOWN!\n\n"+name+" ("+ip+"), mountpoint \""+
	    file +"\" down, symptom:\n"+
	    reason +"\n\n"
	    "The server has been down for "+
	    ((t-since)/3600)+"h"+
	    (((t-since)/60)%60)+"m"+
	    ((t-since)%60)+"s.\n", rc);
    }

    /*
    else if ( !((down-nr_lowalert)%5) && down<nr_highalert )
    {
      int t=time();
      action_lowalert(
	    "WARNING! SERVER DOWN!\n\n"+name+" ("+ip+"), mountpoint \""+
	    file +"\" down, symptom:\n"+
	    reason +"\n\n"
	    "The server has been down for "+
	    ((t-since)/3600)+"h"+
	    (((t-since)/60)%60)+"m.\n", rc);
    }
    else if( down > nr_highalert )
    {
      int t=time();
      action_lowalert(
	    "PANIC! SERVER DOWN!\n\n"+name+" ("+ip+"), mountpoint \""+
	    file +"\" down, symptom:\n"+
	    reason +"\n\n"
	    "The server has been down for "+
	    ((t-since)/3600)+"h"+
	    (((t-since)/60)%60)+"m.\n", rc);
    }
    */
  }

  void connected(object f)
  {
    reason="connect, but no answer for "+ read_timeout +" seconds";
    f->set_nonblocking(ok,0,failed);
    f->write("GET / HTTP/1.0\r\n\r\n");
   
    remove_call_out(failed);
    call_out(failed,read_timeout,f);
  }

  void watchdog()
  {
    werror( "watchdog...("+ intervall +")\n" );
    call_out(watchdog,intervall);
    
    object f=Stdio.File();
    f->open_socket();
    f->set_id(f);
    f->set_nonblocking( 0, connected, failed );
    reason="failed to connect or timed out ("+connect_timeout+"s) ";
    f->connect(ip,port); // test server
    call_out(failed,connect_timeout,f);
  }

  void create(string _name, string _server, int _port, string _file,
	      int _intervall, int _connect_timeout, int _read_timeout,
	      int _nr_lowalert, function _action_lowalert,
	      int _nr_highalert, function _action_highalert, mapping _rc)
  {
    name=_name;
    ip=_server;
    port=_port;
    file=_file;
    
    intervall=_intervall;
    connect_timeout=_connect_timeout;
    read_timeout=_read_timeout;
    
    action_lowalert=_action_lowalert;
    action_highalert=_action_highalert;
    nr_lowalert=_nr_lowalert;
    nr_highalert=_nr_highalert;
   
    rc=_rc;

    call_out( watchdog, 0 );
  }
}


void dot()
{
  write( "." );
  call_out( dot, 1 );
}

// Restart the server.
void action_restart( string message, mapping rc, void|int standdown )
{
  log( message );

  werror( sprintf("server: %s, port: %d", rc->server, rc->serverport) );
  if( pid && (int)pid > 1)
  {
    log( "Sending signal SIGHUP to server ("+pid+")" );
    kill( (int)pid, signum("SIGHUP") );
    sleep(5);
    log( "Sending signal SIGKILL to server ("+pid+")" );
    kill( (int)pid, signum("SIGKILL") );
  } else if( (int)pid < 2 )
    log( "WARNING: PID is 0 or 1. Admin intervention nessesary." );
  else
    log( "No server process." );

}

// Dummy action-function  *FIXME*
void action_dummy( string message, mapping rc, void|int standdown )
{
  log( message );
}

// Give the right action-function from the resource
function get_function( string actions )
{
  switch( actions )
  {
   case "r":
     log("Startup: Killer initiated.");
     return action_restart;
     //     return action_dummy;
     break;
   case "l":
     log("Startup: Logger initiated.");
     return action_dummy;
     break;
   default:
     log("Startup: Unknown action in resource.");
     return action_dummy;
     break;
  }
}

//Get a list of servers and ports.
array get_servers()
{
  array srvs=({});
  object config_dir=Config.Files.Dir(opts->config_dir);
  if(!config_dir) 
  {
    werror("unable to open config dir.\n");
    exit(1);
  }
  foreach(config_dir->list_files(), mapping cf)
  {
    mapping cfg=Config.Files.File(config_dir, 
      cf->name)->retrieve_region("spider");
    werror(sprintf("%O", cfg));
  }

  return srvs;
}

//Preparse the resources
mapping refine_rc( mapping rc )
{
  mapping files = ([]);

  werror( sprintf("foo: %O\n", rc->file));
  foreach( rc->file / "\0", string bar )
  {
    array gaz = bar/":";
    werror( sprintf("refine: %O\n", gaz) );
    files[ gaz[0] ] = ([ "lowtime":(int)gaz[1],
			 "lowaction":gaz[2],
			 "hightime":(int)gaz[3],
			 "highaction":gaz[4] ]);
  }

  array saker =
    ({ "serverport", "intervall", "readtimeout", "connecttimeout" });
  foreach( saker, string sak )
    rc[sak] = (int)rc[sak];

  rc->file = files;

  if (rc->lsof)
    rc->lsofwargs = sprintf("%s -i -P -n -b -F cLpPnf", rc->lsof);

  return rc;
}

// Main loop. check the URLs regurlarly and call actionfunctions if
// something goes wrong.
int main(int argc, array (string) argv)
{
  mapping rc;

  array o=Getopt.find_all_options(
    argv, ({ ({"pid_file", Getopt.HAS_ARG, ({"--pid_file"}), 0, 0}),
      ({"config_dir", Getopt.HAS_ARG, ({"--config_dir"}) }) }), 0, 0
    );
  foreach(o, array xo)
    opts[xo[0]]=xo[1];

  if(!(opts && opts->pid_file && opts->config_dir))
  {
    werror("no pid file / config dir specified.\n");
    exit(1);
  }
  else 
    werror(sprintf("%O\n", opts));
    pid=Stdio.read_file(opts->pid_file);

  if(!(pid && sscanf(pid, "%d", int tmp)))
  {
    werror("invalid contents of pid file " + opts->pid_file + "\n");
    exit(1);
  }
  if(!file_stat(opts->config_dir))
  {
    werror("config dir does not exist " + opts->config_dir + "\n");
    exit(1);
  }

  rc = refine_rc( read_rc() );
  servers = get_servers(opts->config_dir);

  write( sprintf("rc: %O\n", rc) );
  write( sprintf("servers: %O\n", servers) );

  // Debugdots
  //  call_out( dot, 1 );

  // Unnessesay complication for this log
  //  nlog = LogView.Bucket.log( LOGFILE, ({ "event" }), "Watchdog");
  nlog = Stdio.File( LOGFILE, "wc" );

  // Make a puppy go play with each of the mountpoints.
  foreach(servers, string srv )
  {
    array x=srv/":";

    log( "Startup: Initiating mountpoint "+ x[0] + ":" + x[1] +":");
    Puppy( rc->servername, x[0], x[1], needle,
	   rc->intervall, rc->connecttimeout, rc->readtimeout,
	   rc->file[needle]->lowtime,
	   get_function( rc->file[needle]->lowaction ),
	   rc->file[needle]->hightime,
	   get_function( rc->file[needle]->highaction ),
	   rc );
  }

  // Return a negative value to loop in the backend.
  return -17;
}
