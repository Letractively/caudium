/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

//
//! module: User logger
//!  This module logs the accesses of each user in their home dirs if
//!  they create a file named 'AccessLog' in that directory, and allow
//!  write access for roxen.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_LOGGER
//! cvs_version: $Id$
//

/*
 * This module logs the accesses of each user in their home dirs if
 * they create a file named 'AccessLog' in that directory, and allow
 * write access for roxen.
 */

constant cvs_version = "$Id$";
constant thread_safe=1;


#include <module.h>
#include <config.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_LOGGER;
constant module_name = "User logger";
constant module_doc  = "This module logs the accesses of each user in their home dirs "
	     "if they create a file named 'AccessLog' (or whatever is configurated in the configuration interface) in that directory, and "
	     "allow write access for roxen.";
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

mapping (string:string) log_format = ([]);

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  log_format = ([]);
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
      log_format[(b/":")[0]] = fix_logging((b/":")[1..]*":");
}



string create()
{
  defvar("num", 5, "Maximum number of open user logfiles.", TYPE_INT|VAR_MORE,
	 "How many logfiles to keep open for speed (the same user often has "
	 " her files accessed many times in a row)");

  defvar("delay", 600, "Logfile garb timeout", TYPE_INT|VAR_MORE,
	 "After how many seconds should the file be closed?");

  defvar("block", 0, "Only log in userlog", TYPE_FLAG,
	 "If set, no entry will be written to the normal log.\n");

  defvar("LogFormat", 
 "404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
 "500: $host ERROR - [$cern_date] \"$method $resource $protocol\" 500 -\n"
 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length"
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
	 "$host          -- The remote host name, or ip number.<br />"
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
      "$user_agent    -- the header 'User-Agent' from the request, or '-'.<br /><br />"
	 "$user          -- the name of the auth user used, if any<br />"
	 "$user_id       -- A unique user ID, if cookies are supported,<br />"
	 "                  by the client, otherwise '0'<br />"
	 "</pre>");

  
  defvar("Logs", ({ "/~%s/" }), "Private logs", TYPE_STRING_LIST,
	 "These directories want their own log files."
	 "Either use a specific path, or a pattern, /foo/ will check "
         "/foo/AccessLog, /users/%s/ will check for an AccessLog in "
         "all subdirectories in the users directory. All filenames are "
         "in the virtual filesystem, not the physical one.\n");

  defvar("AccessLog", "AccessLog", "AccessLog filename", TYPE_STRING,
	 "The filename of the access log file.");
}


class CacheFile {
  inherit Stdio.File;
  string file;
  int ready = 1, d, n;
  object next;
  object master;
#ifdef THREADS
  object mutex;
#endif

  void move_this_to_tail();

  void timeout()
  {
    close();
    ready = 1;
    move_this_to_tail();
  }

  void wait()
  {
    remove_call_out(timeout);
  }
  
  int open(string s, string|void mode)
  {
    int st;
    st = File::open(s, "wa");
    file = s;
    ready = !st;
    // call_out(timeout, d);     Removed by davidk
    return st;
  }
  
  string status()
  {
    return ((ready?"Free (closed) cache file ("+n+").\n"
	     :"Open: "+file+" ("+n+")"+"\n") +
	    (next?next->status():""));
  }

  void move_this_to_head()
  {
    object tmp, tmp2;
#ifdef THREADS
    object key = mutex?mutex->lock():0;
#endif
    tmp2 = tmp = master->cache_head;

    if(tmp == this_object()) return;

    master->cache_head = this_object();
    while(tmp && (tmp->next != this_object()))
      tmp = tmp->next;
    if(tmp)
      tmp->next = next;
    next = tmp2;
  }

  void move_this_to_tail()
  {
    object tmp;
#ifdef THREADS
    object key = mutex?mutex->lock():0;
#endif

    if(this_object() == master->cache_head)
    {
      master->cache_head = next;
      tmp = next;
    }
    else
    {
      tmp = master->cache_head;
      while(tmp->next != this_object())
	tmp = tmp->next;
      tmp->next = next;
    }

    // Now this_object() is removed.
    while (tmp->next)
      tmp = tmp->next;
    tmp->next = this_object();
    next = 0;
  }

  void write(string s)
  {
    move_this_to_head();
    remove_call_out(timeout);
    call_out(timeout, d);
    if(ready)
      report_debug("home_logger: Trying to write to a closed file "+file+"\n");
    else
      ::write(s);
  }

  void create(int num, int delay, object m, object mu)
  {
#ifdef THREADS
    mutex = mu;
#endif
    n = num;
    d = delay;
    master = m;
    if(num > 1)
      next = object_program(this_object())(--num, delay, m, mu );
  }

  void destroy()
  {
    remove_call_out(timeout);
    if(next) destruct(next);
  }
};


object cache_head;
#ifdef THREADS
object mutex  = Thread.Mutex();
#else
object mutex;
#endif

string start()
{
  object f;
  if(cache_head) destruct(cache_head);
  cache_head = CacheFile(QUERY(num), QUERY(delay), this_object(), mutex);
  parse_log_formats();
}

static void do_log(mapping file, object request_id, function log_function)
{
  string a;
  string form;
  function f;

  if(!log_function) return;// No file is open for logging.

  if(!(form=log_format[(string)file->error]))
    form = log_format["*"];
  
  if(!form) return;
  int|mapping user=request_id->get_user();
  form=replace(form, 
	       ({ 
		 "$ip_number", "$bin-ip_number", "$cern_date",
		 "$bin-date", "$method", "$resource", "$protocol",
		 "$response", "$bin-response", "$length", "$bin-length",
		 "$referer", "$user_agent", "$user", "$user_id",
	       }), ({
		 (string)request_id->remoteaddr,
		 host_ip_to_int(request_id->remoteaddr),
		 Caudium.HTTP.cern_date(request_id->time),
		 unsigned_to_bin(time(1)),
		 (string)request_id->method,
		 Caudium.http_encode_string(request_id->not_query+
				    (request_id->query?"?"+request_id->query:
				     "")),
		 (string)request_id->prot,
		 (string)(file->error||200),
		 unsigned_short_to_bin(file->error||200),
		 (string)(file->len>=0?file->len:"?"),
		 unsigned_to_bin(file->len),
		 (string)(request_id->referrer||"-"),
		 Caudium.http_encode_string(request_id->useragent),
		 (user?user->username:"-"),
		 (string)request_id->cookies->CaudiumUserID,
	       }) );
  
  if(search(form, "host") != -1)
    caudium->ip_to_host(request_id->remoteaddr, write_to_log, form,
		      request_id->remoteaddr, log_function);
  else
    log_function(form);
}


string status()
{
 if (!cache_head)
   start();
 if (!cache_head)
 {
   werror("logger.lpc->status(): cache_head = 0\n");
   return "Error";
 }
  return "Logfile cache status:\n<pre>\n" + cache_head->status() + "</pre>";
}

object find_cache_file(string f)
{
#ifdef THREADS
  object key = mutex->lock();
#endif
  if(!cache_head)
    start();
  
  object c = cache_head;
  do {
    if((c->file == f) && !c->ready)
      return c;

    if(c->ready)
    {
      if(c->open(f))
	return c;
      return 0;
    }
  } while(c->next && (c=c->next));

  c->close();
  if(c->open(f))
    return c;
  return 0;
}

mapping cached_homes = ([]);

string home(string of, object id)
{
  string f;
  string|int l;
  foreach(QUERY(Logs), l)
  {
    if(!search(of, l))
    {
      if(cached_homes[l] && !(cached_homes[l] == -1 && id->pragma["no-cache"]))
	return (l = cached_homes[l]) == -1?0:l;
      f=l;
      l=caudium->real_file(l+QUERY(AccessLog), id);
      if(l) cached_homes[f]=l;
      else cached_homes[f]=-1;
      return l;
    }
    else if(sscanf(of, l, f))
    {
      catch{f=sprintf(l,f);};
      if(cached_homes[f] && !(cached_homes[f]==-1 && id->pragma["no-cache"]))
	return (l=cached_homes[f])==-1?0:l;
      l=caudium->real_file(f+QUERY(AccessLog), id);
      if(l) cached_homes[f]=l;
      else cached_homes[f]=-1;
      return l;
    }
  }
}



inline string format_log(object id, mapping file)
{
  return sprintf("%s %s %s [%s] \"%s %s %s\" %s %s\n",
		 caudium->quick_ip_to_host(id->remoteaddr),
		 (string)(id->referrer||"-"), 
		 replace(id->useragent ," ","%20"),
		 Caudium.HTTP.cern_date(id->time),
		 (string)id->method, (string)id->raw_url,
		 (string)id->prot,   (string)file->error,
		 (string)(file->len>=0?file->len:"?"));
}

mixed log(object id, mapping file)
{
  string s;
  object fnord;

  if((s = home(id->not_query, id)) && 
     (fnord=find_cache_file(s)))
  {
    fnord->wait(); // Tell it not to die
    do_log(file,id,fnord->write);
  }
  if(QUERY(block) && fnord)
    return 1;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: num
//! How many logfiles to keep open for speed (the same user often has  her files accessed many times in a row)
//!  type: TYPE_INT|VAR_MORE
//!  name: Maximum number of open user logfiles.
//
//! defvar: delay
//! After how many seconds should the file be closed?
//!  type: TYPE_INT|VAR_MORE
//!  name: Logfile garb timeout
//
//! defvar: block
//! If set, no entry will be written to the normal log.
//!
//!  type: TYPE_FLAG
//!  name: Only log in userlog
//
//! defvar: LogFormat
//! What format to use for logging. The syntax is:
//!<pre>response-code or *: Log format for that response acode<br /><br />Log format is normal characters, or one or more of the variables below:<br /><br />\n \t \r       -- As in C, newline, tab and linefeed<br />$char(int)     -- Insert the (1 byte) character specified by the integer.<br />$wchar(int)    -- Insert the (2 byte) word specified by the integer.<br />$int(int)      -- Insert the (4 byte) word specified by the integer.<br />$^             -- Supress newline at the end of the logentry<br />$host          -- The remote host name, or ip number.<br />$ip_number     -- The remote ip number.<br />$bin-ip_number -- The remote host id as a binary integer number.<br /><br />$cern_date     -- Cern Common Log file format date.<br />$bin-date      -- Time, but as an 32 bit iteger in network byteorder<br /><br />$method        -- Request method<br />$resource      -- Resource identifier<br />$protocol      -- The protocol used (normally HTTP/1.0)<br />$response      -- The response code sent<br />$bin-response  -- The response code sent as a binary short number<br />$length        -- The length of the data section of the reply<br />$bin-length    -- Same, but as an 32 bit iteger in network byteorder<br />$referer       -- the header 'referer' from the request, or '-'.<br />$user_agent    -- the header 'User-Agent' from the request, or '-'.<br /><br />$user          -- the name of the auth user used, if any<br />$user_id       -- A unique user ID, if cookies are supported,<br />                  by the client, otherwise '0'<br /></pre>
//!  type: TYPE_TEXT_FIELD
//!  name: Logging Format
//
//! defvar: Logs
//! These directories want their own log files.Either use a specific path, or a pattern, /foo/ will check /foo/AccessLog, /users/%s/ will check for an AccessLog in all subdirectories in the users directory. All filenames are in the virtual filesystem, not the physical one.
//!
//!  type: TYPE_STRING_LIST
//!  name: Private logs
//
//! defvar: AccessLog
//! The filename of the access log file.
//!  type: TYPE_STRING
//!  name: AccessLog filename
//
