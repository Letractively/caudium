/*
 * pop3.pike - A pop3 server for Caudium
 */

/*
 * Currently implemented [X] Totaly done / [/] Not complete / [ ] TODO
 * RFC 1081 adds :
 *
 * [X] USER username
 * [X] PASS password
 * [X] QUIT
 * [X] STAT		XXX Finish to implement deleted mail handling
 * [X] LIST [msg]	XXX Finish to implement deleted mail handling
 * [X] RETR msg		XXX Finish to implement deleted mail handling
 * [ ] DELE msg
 * [X] NOOP
 * [ ] LAST
 * [ ] RSET
 * Optional ones
 * [ ] TOP msg n
 * [ ] RPOP user
 *
 */

#include <module.h>
inherit "module";

constant cvs_version   = "$Id$";
constant thread_safe   = 1;
constant module_type   = MODULE_PROVIDER|MODULE_EXPERIMENTAL; 
constant module_name   = "POP3 Server Module";
constant module_doc    = "This module acts as a POP3 server for Caudium...<br />"
			 "<b>Note that this module is NOT finished yet</b>.<p>\n"
                         "Note that this module handles only Maildir++ "
                         "mailbox type.";
constant module_unique = 0;

#define POP3_DEBUG

#ifdef POP3_DEBUG
# define DW(X)		if(QUERY(debug)) werror("POP3: "+X+"\n");
#else
# define DW(X)		// No debug
#endif

// counters here
int tconnect=0;	// Total connections to this pop3 server
int to_cnt  =0;	// Timeout count
int quit_cnt=0;	// QUIT count
int help_cnt=0;	// HELP count
int user_cnt=0;	// USER count
int pass_cnt=0;	// PASS count

array msglist;	// Array of message files

static class POP3_Session
{
  inherit Protocols.Line.simple;

  class fake_id
  {
    // A fake id object to handle Caudium object there
    object conf;
    string raw_url = "pop3://";
    string method = "";
    string remote_addr;
    mapping(string:string) variables = ([]);
    mapping(string:string) cookies   = ([]);
    mapping(string:mixed) misc = ([]);
    multiset (string) prestate = (< >);
    multiset (string) config   = (< >);
    multiset (string) supports = (< >);
    array(string) client = ({ });
    array(string) referer= ({ });
    object my_fd;
    string realfile, virtfile; 
    string rest_query="";
    string raw;
    string query;
    string not_query;
    string extra_extension = "";  // special hack for the language module
    string data;
    array (int|string) auth;
    string rawauth, realauth;
  };

  object(fake_id) id = fake_id();

  static object conf;
  static object parent;

  static mapping(string:mixed) log_id;

  string username;	// The user login
  int loginok;		// We are logged
  int user_uid;		// uid
  int user_gid;		// gid
  string homedir;	// homedir
  string mdprefix="/Maildir/";	// Maildir prefix
  array msg_list;	// Cache / list of messages handled for this pop session

  // TODO: Deleted message list
  // array del_msg = ({ 1, 3 , 5 });
  // search (del_msg, 4);	-> -1 donc pas supprimé
  // search (del_msg, 1);	-> >=0 donc a supprimé

  static void log(string cmd, string not_query, int errcode, int|void sz)
  {
    log_id->method = cmd;
    log_id->not_query = not_query;
    log_id->time = time(1);
    // FIXME
//     conf->log(([ "error":errcode, "len":sz ]), log_id);
  }

  static void send(string s)
  {
    send_q->put(s);
    con->set_write_callback(write_callback);
  }


  static string bytestuff(string s)
  {
    // RFC 1939 doesn't explicitly say what quoting is to be used,
    // but it says something about bytestuffing lines beginning with '.',
    // so we use SMTP-style quoting.
    s = replace(s, "\r\n.", "\r\n..");
    if (s[..2] == ".\r\n") {
      s = "." + s;	// Not likely, but...
    }
    if (s[sizeof(s)-2..] != "\r\n") {
      s += "\r\n";
    }
    return(s);
  }

  static void handle_command(string line)
  {
    if (sizeof(line)) {
      array a = (line/" ");

      a[0] = upper_case(a[0]);
      function fun = this_object()["pop3_"+a[0]];
      if (!fun) {
	send(sprintf("-ERR %O: Not implemented yet.\r\n", a[0]));
	log(a[0], "", 501);
	return;
      }
      fun(a[1..]);
      return;
    } else {
      send("-ERR Expected command\r\n");
    }
  }

  static int timeout_sent;
  static void do_timeout()
  {
    if (!timeout_sent) {
      parent->to_cnt++;
      catch {
	send("-ERR closing connection - goodbye!\r\n");
      };
      catch {
	disconnect();
      };
      timeout_sent = 1;
      log("TIMEOUT", "", 200);

      touch_time();	// We want to send the timeout message...
      _timeout_cb();	// Restart the timeout timer.

      // Force disconnection in timeout/2 time
      // if the other end doesn't read any data.
      call_out(::do_timeout, timeout/2);
    } else {
      // No need to do anything...
      // We will be disconnected soon anyway by the ::do_timeout() call_out.
    }
  }

  void return_error(string error, string command,
		    array(string) args)
  {
    send("-ERR "+error+"\r\n");
    log(command, args*" ", 400);
  }

  void create(object con, int timeout, object c, object p)
  {
    // Fake request id for logging purposes.
    log_id = ([
      "prot":"POP3",
      "remoteaddr":(con->query_address()/" ")[0],
      "cookies":([]),
    ]);

    parent = p;
    conf = c;

    log("CONNECT", con->query_address(), 200);

    ::create(con, timeout);

    send(sprintf("+OK %s POP3 server ready.\r\n",
		    caudium->version()));
  }

  // The commands to handle

  void pop3_HELP()
  {
    parent->help_cnt++;
    send("+OK Supported commands : ");
    foreach(sort(glob("pop3_*",indices(this_object()))), string command)
      send(command[5..]+" ");
    send("\r\n");
  }

  void pop3_NOOP()
  {
    send("+OK No-op to you too !\r\n");
  }

  void pop3_QUIT()
  {
    parent->quit_cnt++;
    send("+OK Bye cya later !\r\n");
    disconnect();
    log("QUIT","",200);
  }

  void pop3_USER(array(string) args)
  {
   if(sizeof(args) != 1) {
     return_error("Missing username argument","USER",args);
     return; 
   }
   parent->user_cnt++;
   send("+OK User name accepted, password please for user "+args[0]+".\r\n");
   username = args[0];
  }

  void pop3_PASS(array(string) args)
  {
   if(sizeof(args) != 1) {
     return_error("Missing password argument","PASS",args);
     return;
   }
   if(!username) {
     return_error("Unknown AUTHORIZATION state command","PASS",args);
     return;
   }
   if(!conf->auth_module) {
     return_error("Auth module not present","PASS",args);
     return;
   }
   parent->pass_cnt++;
   id->method = "LOGIN";
   id->realauth = username + ":" + args[0];
   id->auth = ({ 0, id->realauth });
   id->not_query = username;
   
   mixed err = catch {
     id->auth[0] = "Basic";
     id->auth = conf->auth_module->auth(id->auth, id);
   };
   if(err) {
     id->auth = 0;
     DW(sprintf("Authenfication error : %s\n", describe_backtrace(err)));
     return_error("Authentification error","PASS",args);
     return;
   }
   if(!id->auth || (id->auth[0] != 1)) {
     return_error("Bad login or password","PASS",args);
     id->auth = 0;
     return;
   }
   loginok = 1;

   array authdata = conf->auth_module->userinfo(username);
   user_uid = (int)authdata[2];
   user_gid = (int)authdata[3];
   //homedir = authdata[5];
   homedir = "/home/kiwi/.procmail/backup/";
   // Move new message to current message and setup the msg_list array to 
   // correct values.
   object privs;
   privs = Privs("Moving messages to 'cur/' directory");
   foreach(get_dir(homedir + "new/"), string foo)
   {
     int mailsize;
     string renameto = foo;
     if(!sscanf(foo,"%*s,S=%d",mailsize)) {
       array|int foo2 = file_stat(homedir + "new/" + foo, 1);
       if (arrayp(foo2)) {
         if (foo2[1] >0) renameto += sprintf(",S=%d",foo2[1]);
       }
     }
     mv(homedir+"new/"+foo,homedir+"cur/"+renameto);
     chown(homedir+"cur/"+renameto,user_uid,user_gid);
   }
   msg_list = get_dir(homedir+"cur/");
   if (privs) {
     destruct(privs);
   }
   send("+OK Password accepted, "+sizeof(msg_list)+" message(s).\r\n");
  }

  void pop3_STAT()
  {
   // TODO: remove deleted messages from this count
   int size = 0;
   foreach(msg_list, string foo) {
     int sizetmp;
     if (sscanf (foo,"%*s,S=%d",sizetmp))
       size += sizetmp;
   }
   if (size > 0)
    send("+OK "+(string)sizeof(msg_list)+" "+(string)size+"\r\n");
   else
    send("+OK "+(string)sizeof(msg_list)+"\r\n");
  }

  private int|string list(int msgid)
  {
    if(msgid > sizeof(msg_list))
      return 0;	// non existant msg id
    int sizemsg;
    sscanf(msg_list[msgid],"%*s,S=%d",sizemsg);
    return sprintf("%d %d",msgid+1, sizemsg);
  }
  
  void pop3_LIST(array(string) args)
  {
   if(sizeof(args) >1) {
     return_error("Too mutch arguments.","LIST",args);
     return;
   }
   if(sizeof(args) ==1) {
     // TODO: do not count marked as deleted messages
     int msgid;
     if(sscanf(args[0],"%d",msgid)) {
       if(msgid==0) {
         return_error("No such message.","LIST",args);
         return;
       }
       msgid--;
       int|string output;
       output = list(msgid);
       if(stringp(output)) {
        send("+OK "+output+"\r\n");
        return;
       }
       else {
        return_error("No such message "+(string)msgid+".","LIST",args);
        return;
       }
     }
     else {
       return_error("No such message.","LIST",args);
       return;
     }
   }
   // Now this is for all mails
   // FIXME: send only non deleted mails
   send("+OK Mailbox scan listings follows\r\n");
   int nb=1;
   foreach(msg_list, string foo) {
     int|string output;
     output = list(nb-1);
     if(stringp(output)) 
      send(output+"\r\n");
     nb++;
   }
   send(".\r\n");
   return;
  }
  
  void pop3_RETR(array(string) args)
  {
    if(sizeof(args) >1) {
      return_error("Too mutch arguments.","RETR",args);
      return;
    }
    if(sizeof(args) ==0) {
      return_error("Argument missing.","RETR",args);
      return;
    }
    // Now we can send the message
    // FIXME: read only non deleted mails
    // FIXME: handle flags
    int msgid;
    if(sscanf(args[0],"%d",msgid)) {
      if(msgid==0) {
        return_error("No such message.","RETR",args);
        return;
      }
      msgid--;
      int|string msginfo=list(msgid);
      if(stringp(msginfo)) { 
        send("+OK "+(msginfo/" ")[1]+" octets\r\n");
      }
      object privs;
      string themail;
      privs = Privs("Reading a message on the disk");
      seteuid(user_uid);
      setegid(user_gid);
      themail = Stdio.read_bytes(homedir+"cur/"+msg_list[msgid]);
      if (privs) 
       destruct(privs);
      send(themail+"\r\n.\r\n");
      return;
    }
    else {
      return_error("No such message.","RETR",args);
      return;
    }
  }
};

static object conf;

static object port;

static void got_connection()
{
  object con = port->accept();

  tconnect ++;
  // Start a new session.
  POP3_Session(con, QUERY(timeout), conf, this_object());
}

static void init()
{
  int portno = QUERY(port) || Protocols.Ports.tcp.pop3;
  string host = 0; // QUERY(host);

  port = 0;
  object newport = Stdio.Port();
  object privs;

  if (portno < 1024) {
    privs = Privs("Opening port below 1024 for POP3.\n");
  }

  mixed err;
  int res;
  err = catch {
    if (host)
      res = newport->bind(portno, got_connection, host);
    else
      res = newport->bind(portno, got_connection);
  };

  if (privs) {
    destruct(privs);
  }

  if (err) {
    throw(err);
  }

  if (!res) {
    throw(({ sprintf("POP3: Failed to bind to port %d\n", portno),
	     backtrace() }));
  }

  port = newport;
}


/*
 * Caudium Module Interface
 */

void destroy()
{
  if (port)
    destruct(port);
}


#if 0
array(string)|multiset(string)|string query_provides()
{
  return(< "nntp_protocol" >);
}
#endif

void create()
{
#ifdef POP3_DEBUG
  defvar("debug",1,"Debug",TYPE_FLAG,"Debug into Caudium Error log");
#endif
  defvar("port", Protocols.Ports.tcp.pop3, "POP3 port number",
	 TYPE_INT | VAR_MORE,
	 "Portnumber to listen to.<br>\n"
	 "Usually " + Protocols.Ports.tcp.pop3 + ".\n");

  // Enable this later.
  defvar("timeout", 10*60, "Timeout", TYPE_INT | VAR_MORE,
	 "Idle time before connection is closed (seconds).<br>\n"
	 "Zero or negative to disable timeouts.");
}

void start(int i, object c)
{
  if (c) {
    conf = c;

    mixed err;
    err = catch {
      if (!port) {
	init();
      }
    };
    if (err) {
      report_error(sprintf("POP3: Failed to initialize the server:\n"
			   "%s\n", describe_backtrace(err)));
    }
  }
}

void stop()
{
  destroy();
}

string query_name()
{
  return(sprintf("pop3://%s:%d/", gethostname(), QUERY(port)));
}

string status()
{
  return "<b>Total POP3 connections :</b>"+(string)tconnect+"<br />"
         "<b>Total Timeouts : </b>"+(string)to_cnt+"<br />";

}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: debug
//! Debug into Caudium Error log
//!  type: TYPE_FLAG
//!  name: Debug
//
//! defvar: port
//! Portnumber to listen to.<br />
//!Usually 
//!  type: TYPE_INT|VAR_MORE
//!  name: POP3 port number
//
//! defvar: timeout
//! Idle time before connection is closed (seconds).<br />
//!Zero or negative to disable timeouts.
//!  type: TYPE_INT|VAR_MORE
//!  name: Timeout
//
