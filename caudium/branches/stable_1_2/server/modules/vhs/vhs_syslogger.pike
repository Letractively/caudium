/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2005 The Caudium Group
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
 */
//! module: VHS - Syslogger module
//!  This module logs the accesses of each vitual in VHS using Syslog
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOGGER
//! cvs_version: $Id$

/* Based on user logging module */

constant cvs_version = "$Id$";
constant thread_safe = 1;

//#define VHSYSLOG_DEBUG 1

#ifdef VHSYSLOG_DEBUG
#define DW(x) werror("[VHS_syslogger] " + x + "\n")
#else
#define DW(x)
#endif

#define EW(x) werror("[VHS_syslogger]:(ERROR) " + x + "\n")

#include <module.h>
#include <config.h>
#include <syslog.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_LOGGER;
constant module_name = "VHS - Syslogger module";
constant module_doc  = "This module logs the accesses of each virtual in VHS using Syslog.";
constant module_unique = 1;

// Parse the logging format strings.
private inline string fix_logging(string s)
{
  string pre, post, c;
  sscanf(s, "%*[\t ]", s);
  s = replace(s, ({"\\t", "\\n", "\\r" }), ({"\t", "\n", "\r" }));
  // FIXME: This looks like a bug.
  // Is it supposed to strip all initial whitespace, or do what it does?
  //    /grubba 1997-10-03
  while(s[0] == ' ') s = s[1..];
  while(s[0] == '\t') s = s[1..];
  while(sscanf(s, "%s$char(%d)%s", pre, c, post)==3)
    s=sprintf("%s%c%s", pre, c, post);
  while(sscanf(s, "%s$wchar(%d)%s", pre, c, post)==3)
    s=sprintf("%s%2c%s", pre, c, post);
  while(sscanf(s, "%s$int(%d)%s", pre, c, post)==3)
    s=sprintf("%s%4c%s", pre, c, post);
  if(!sscanf(s, "%s$^%s", pre, post))
    s+="\n";
  else
    s=pre+post;
  return s;
}

// Really write an entry to the log.
private void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  if(fun) fun(replace(rest, "$host", host));
}

// Logging format support functions.
nomask private inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

nomask private inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

nomask private inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}

mapping (string:string) log_format = ([]);

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  log_format = ([]);
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
      log_format[(b/":")[0]] = fix_logging((b/":")[1..]*":");
  
  DW(sprintf("parse_logformat : %O",log_format));
}

private int is_log_local() { return QUERY(LogLocal); };

string create()
{

  defvar("LogFormat", 
 "404: $ip_number $referer - [$cern_date] \"$method $resource $protocol\" 404 - $virtname\n"
 "500: $ip_number ERROR - [$cern_date] \"$method $resource $protocol\" 500 - $virtname\n"
 "*: $ip_number - - [$cern_date] \"$method $resource $protocol\" $response $length $virtname"
	 ,

	 "Logging Format", 
	 TYPE_TEXT_FIELD,
	 
	 "What format to use for logging. The syntax is:\n"
	 "<pre>"
	 "response-code or *: Log format for that response acode<br /><br />"
	 "Log format is normal characters, or one or more of the "
	 "variables below:<br />"
	 "<br />"
	 "\\n \\t \\r       -- As in C, newline, tab and linefeed<br />"
	 "$char(int)     -- Insert the (1 byte) character specified by the integer.<br />"
	 "$wchar(int)    -- Insert the (2 byte) word specified by the integer.<br />"
	 "$int(int)      -- Insert the (4 byte) word specified by the integer.<br />"
	 "$^             -- Supress newline at the end of the logentry<br />"
	 "$ip_number     -- The remote ip number.<br />"
	 "$bin-ip_number -- The remote host id as a binary integer number.<br />"
	 "<br />"
	 "$cern_date     -- Cern Common Log file format date.<br />"
	 "$bin-date      -- Time, but as an 32 bit iteger in network byteorder<br />"
	 "<br />"
	 "$method        -- Request method<br />"
	 "$resource      -- Resource identifier<br />"
	 "$protocol      -- The protocol used (normally HTTP/1.0)<br />"
	 "$response      -- The response code sent<br />"
	 "$bin-response  -- The response code sent as a binary short number<br />"
	 "$length        -- The length of the data section of the reply<br />"
	 "$bin-length    -- Same, but as an 32 bit iteger in network byteorder<br />"
	 "$referer       -- the header 'referer' from the request, or '-'.<br />"
	 "$user_agent    -- the header 'User-Agent' from the request, or '-'.<br />"
	 "$agent_unquoted  -- the header 'User-Agent' from the request, or '-'.<br /><br />"
	 "$user          -- the name of the auth user used, if any<br />"
	 "$user_id       -- A unique user ID, if cookies are supported,<br />"
	 "                  by the client, otherwise '0'<br />"
	 "$virtname      -- virtual host name<br />"
	 "</pre>");

  defvar("LogLocal",1, "Log to local syslog ?", TYPE_FLAG,
         "If set, the syslogger module will log on local machine", 0);

  defvar("LogHost","localhost", "Host to log to",TYPE_STRING,
         "Hostname or IP to use to log using Syslog UDP protocol", 1, is_log_local);

  defvar("LogSP", 1, "Log PID", TYPE_FLAG,
	  "If set, the PID will be included in the syslog.", 0);
  
  defvar("LogST", "Local 1", "Log type", TYPE_STRING_LIST,
	  "Which log type should be used.",
	  ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	     "Local 4", "Local 5", "Local 6", "Local 7", "User" }) );
  
  defvar("Insert","1","Insert VHS name", TYPE_FLAG,
         "Insert VHS hostname at the begining of the line (before 200, or whatever");

  defvar("filename","1", "Use File from main VHS System as VHS Name", TYPE_FLAG,
         "If set, the VHS Hostname added at the begining of the line will be extracted from"
         " logpath constructed by the main vhs system module using a basename()", 1, lamdba() { return !QUERY(Insert); }; );
}

int loggingfield;	// Set the stuff for logginf

string start()
{
  object f;
  parse_log_formats();

  switch(QUERY(LogST))
  {
   case "Daemon":    loggingfield = LOG_DAEMON;    break;
   case "Local 0":   loggingfield = LOG_LOCAL;     break; 
   case "Local 1":   loggingfield = LOG_LOCAL1;    break;
   case "Local 2":   loggingfield = LOG_LOCAL2;    break;
   case "Local 3":   loggingfield = LOG_LOCAL3;    break;
   case "Local 4":   loggingfield = LOG_LOCAL4;    break;
   case "Local 5":   loggingfield = LOG_LOCAL5;    break;
   case "Local 6":   loggingfield = LOG_LOCAL6;    break;
   case "Local 7":   loggingfield = LOG_LOCAL7;    break;
   case "User":      loggingfield = LOG_USER;      break;
  }
   
  // We use LOG_NOTICE per default
  loggingfield = loggingfield | LOG_NOTICE;
  
  if(QUERY(LogSP)) 
    loggingfield = loggingfield | LOG_PID;

  DW(sprintf("loggingfield -> : %x",loggingfield));
}

void localsyslog (string data) 
{
  // This is heavy stuff... we open and close syslog everytime
  // but this is need because we don't want blocking IO.

  DW(sprintf("Local : %s",data));
  syslog(loggingfield, data);
}

void hostsyslog(string data)
{
  // more simple... :p
  DW(sprintf("Remote : %s",data));
  Protocols.Syslog.remote(loggingfield, data, QUERY(LogHost));
}

static void do_log(mapping file, object request_id, function log_function)
{
  string a;
  string form;
  function f;

  if (!(form=log_format[(string)file->error]))
     form = log_format["*"];

  DW(sprintf("To log (1)-> : %O",form));
  
  if(!form) return;
  
  form=replace(form, 
	       ({ 
		 "$ip_number", "$bin-ip_number", "$cern_date",
		 "$bin-date", "$method", "$resource", "$protocol",
		 "$response", "$bin-response", "$length", "$bin-length",
		 "$referer", "$user_agent", "$agent_unquoted", "$user", "$user_id", "$virtname",
	       }), ({
		 (string)request_id->remoteaddr,
		 host_ip_to_int(request_id->remoteaddr),
		 cern_http_date(time(1)),
		 unsigned_to_bin(time(1)),
		 (string)request_id->method,
		 http_encode_string(request_id->not_query+
				    (request_id->query?"?"+request_id->query:
				     "")),
		 (string)request_id->prot,
		 (string)(file->error||200),
		 unsigned_short_to_bin(file->error||200),
		 (string)(file->len>=0?file->len:"?"),
		 unsigned_to_bin(file->len),
		 (string)(request_id->referrer||"-"),
		 http_encode_string(request_id->useragent||"-"),
		 request_id->useragent||"-",
		 extract_user(request_id->realauth),
		 (string)request_id->cookies->CaudiumUserID,
		 (string)request_id->misc->host,
	       }) );
  
  DW(sprintf("To log (2)-> : %O",form));
    if(QUERY(Insert))
      if(QUERY(filename))
        form = request_id->misc->vhs->logpath?basename((string)request_id->misc->vhs->logpath):"unknown" + " " + form;
      else
        form = request_id->misc->host?(string)request_id->misc->host:"unknown" + " " + form;
    log_function(form);
}

inline string format_log(object id, mapping file)
{
  return sprintf("%s %s %s [%s] \"%s %s %s\" %s %s\n",
		 caudium->quick_ip_to_host(id->remoteaddr),
		 (string)(id->referrer||"-"), 
		 replace(id->useragent ," ","%20"),
		 cern_http_date(id->time),
		 (string)id->method, (string)id->raw_url,
		 (string)id->prot,   (string)file->error,
		 (string)(file->len>=0?file->len:"?"));
}

mixed log(object id, mapping file)
{
  if (!id->misc->vhs || !id->misc->vhs->logpath) return 0;

  DW("Logging engaged.");
 
  if(QUERY(LogLocal))
   do_log(file, id, localsyslog);
  else 
   do_log(file, id,  hostsyslog);

}




/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: LogFormat
//! What format to use for logging. The syntax is:
//!<pre>response-code or *: Log format for that response acode<br /><br />Log format is normal characters, or one or more of the variables below:<br /><br />\n \t \r       -- As in C, newline, tab and linefeed<br />$char(int)     -- Insert the (1 byte) character specified by the integer.<br />$wchar(int)    -- Insert the (2 byte) word specified by the integer.<br />$int(int)      -- Insert the (4 byte) word specified by the integer.<br />$^             -- Supress newline at the end of the logentry<br />$ip_number     -- The remote ip number.<br />$bin-ip_number -- The remote host id as a binary integer number.<br /><br />$cern_date     -- Cern Common Log file format date.<br />$bin-date      -- Time, but as an 32 bit iteger in network byteorder<br /><br />$method        -- Request method<br />$resource      -- Resource identifier<br />$protocol      -- The protocol used (normally HTTP/1.0)<br />$response      -- The response code sent<br />$bin-response  -- The response code sent as a binary short number<br />$length        -- The length of the data section of the reply<br />$bin-length    -- Same, but as an 32 bit iteger in network byteorder<br />$referer       -- the header 'referer' from the request, or '-'.<br />$user_agent    -- the header 'User-Agent' from the request, or '-'.<br />$agent_unquoted  -- the header 'User-Agent' from the request, or '-'.<br /><br />$user          -- the name of the auth user used, if any<br />$user_id       -- A unique user ID, if cookies are supported,<br />                  by the client, otherwise '0'<br />$virtname      -- virtual host name<br /></pre>
//!  type: TYPE_TEXT_FIELD
//!  name: Logging Format
//
//! defvar: LogLocal
//! If set, the syslogger module will log on local machine
//!  type: TYPE_FLAG
//!  name: Log to local syslog ?
//
//! defvar: LogHost
//! Hostname or IP to use to log using Syslog UDP protocol
//!  type: TYPE_STRING
//!  name: Host to log to
//
//! defvar: LogSP
//! If set, the PID will be included in the syslog.
//!  type: TYPE_FLAG
//!  name: Log PID
//
//! defvar: LogST
//! Which log type should be used.
//!  type: TYPE_STRING_LIST
//!  name: Log type
//
//! defvar: LogNA
//! When syslog is used, this will be the identification of the Caudium daemon. The entered value will be appended to all logs.
//!  type: TYPE_STRING
//!  name: Log as
//
//! defvar: Insert
//! Insert VHS hostname at the begining of the line (before 200, or whatever
//!  type: TYPE_FLAG
//!  name: Insert VHS name
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

