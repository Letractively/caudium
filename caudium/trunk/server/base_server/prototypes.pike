/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

//! @appears RequestID
//! The RequestID object.
//! This module implements the base of most protocols and, at the same time, it is
//! what you access through the common @tt{id@} object in your modules,
//! tags etc.
class RequestID
{

#define MAGIC_ERROR

#ifdef MAGIC_ERROR
inherit "highlight_pike";
#endif
constant cvs_version = "$Id$";

#include <config.h>
private inherit "caudiumlib14";

// int first;
#if constant(gethrtime)
# define HRTIME() gethrtime()
# define HRSEC(X) ((int)((X)*1000000))
# define SECHR(X) ((X)/(float)1000000)
#else
# define HRTIME() (predef::time())
# define HRSEC(X) (X)
# define SECHR(X) ((float)(X))
#endif

#ifdef PROFILE
#define REQUEST_DEBUG
int req_time = HRTIME();
#endif

//#define REQUEST_DEBUG

#ifdef REQUEST_DEBUG
#define REQUEST_WERR(X)	roxen_perror((X)+"\n")
#else
#define REQUEST_WERR(X)
#endif

#ifdef FD_DEBUG
#define MARK_FD(X) catch{REQUEST_WERR(X); mark_fd(my_fd->query_fd(), (X)+" "+remoteaddr);}
#else
#define MARK_FD(X) REQUEST_WERR(X)
#endif

//! decode base64 string
constant decode        = MIME.decode_base64;

//! current time, see @[predef::time]
constant _time         = predef::time;

constant find_supports = caudium->find_supports;

//! the caudium version
constant version       = caudium->version;
constant _query        = caudium->query;
constant thepipe       = caudium->pipe;

int wanted_data, have_data, unread_data;

object conf;

#include <caudium.h>
#include <module.h>

#undef QUERY

#define QUERY(X)	_query( #X )

int time;

//! the raw url, as provided as part of the browser request string.
string raw_url;

int do_not_disconnect;

//! Variables available during the current request. The variables may come
//! from various sources - the @tt{query@} part of the URL which was used
//! to access the server, the &lt;set&gt; tag in the @tt{RXML@} source or
//! the Pike code in the modules or core server. Each index of the mapping
//! is a variable name.
mapping (string:string) variables       = ([ ]);

//! Miscellaneous variables used by both the core server and the modules -
//! you are free to add your own variables over here as long as you make
//! sure that they do not conflict with any of the existing ones.
//!
//! @note
//! TODO: add a list of predefined variables stored here.
mapping (string:mixed)  misc            = ([ ]);

//! The cookies read from the client at the start of the current request.
mapping (string:string) cookies         = ([ ]);

//! The current request headers as sent by the client.
mapping (string:string) request_headers = ([ ]);

//! The prestates (comma separated strings enclosed between parentheses)
//! present in the URL used to access the server for the current request.
multiset (string) prestate  = (< >);
multiset (string) internal  = (< >);

//! Config variables (comma separated strings enclosed between the angle
//! brackets) present in the URL used to access the server for the current
//! request.
multiset (string) config    = (< >);

//! Collect of the features supported by the client which initiated the
//! current request.
multiset (string) supports  = (< >);
multiset (string) pragma    = (< >);

//! The address of the remote client.
string remoteaddr;

//! The host name the request is headed for, from HTTP/1.1
string host;

#ifdef EXTRA_ROXEN_COMPAT
array  (string) client = ({"unknown"});
array  (string) referer;
#endif

//! The referring page for the current request (if the client sent it).
string referrer;

//! The user agent string describing the client (if the client sent it).
string useragent = "unknown";

//! This mapping contains the answer returned by the code which handles the
//! connection.
//!
//! @note
//! TODO: explain what's in the mapping
mapping file;

//! This is the default content charset sent in the Content-Type: header
string  content_charset = "iso-8859-1";

//! The current FD to client.
object my_fd; /* The client. */
object pipe;

// string range;

//! the protocol string being used, such as HTTP/1.0, etc.
string prot;

//! the protocol being spoken during this request, such as http, https, ftp.
string server_protocol="";

string clientprot;

//! the client request method, such as HEAD, GET, etc.
string method;

//! The realfile path on the disk.
string realfile;

//! The virtual file path on the disk.
string virtfile;

string rest_query="";

//! The Raw request (eg. request from client with all headers, etc...)
string raw=""; // Raw request

//! The Query of request (eg. part after the '?', ex: for /index.html?foo=test
//! in this case query = "foo=test")
string query;

//! The not query of request (eg. part before the '?', ex: for /index.html?foo=test
//! in this case not_query = "/index.html")
string not_query;

//! Used for language module.
string extra_extension = ""; // special hack for the language module
string data, leftovers;

//! The array containing the authentication information. The format in case
//! the authentication module is present is as follows:
//!
//! @array
//!  @elem int 0
//!   @i{successp@} - @tt{1@} if the authentication succeeded, @tt{0@}
//!   otherwise.
//!
//!  @elem string 1
//!   @i{username@} - the authenticated user name.
//!
//!  @elem string 2
//!   @i{password@} - the password user authenticated with.
//!
//!  @elem string 3
//!   @i{group@} - if this element is present (only in Caudium 1.3+) then it
//!   contains a comma-separated list of groups the user belongs to.
//! @endarray
//!
//! @deprecated
array (int|string) auth;
string rawauth, realauth;
string since;

//! description of user, if authenticated.
//! if not authenticated, this element will be 0 (zero).
int|mapping user=0;

private int cache_control_ok = 0;

//! Get the base portion of a URL
//! Returned string will end in "/" or will be "" if no base could
//!   be determined.
string url_base()
{
  string base;
  base=conf->query("MyWorldLocation");
  if(!base)
    base="";
  else if(base[sizeof(base)-1..]!="/")
    base+="/";
  return base;
}

//! Get a somewhat identical copy of this object, used when doing 
//! 'simulated' requests.
  object clone_me()
  {
    object c,t;
    c = object_program(t = this_object())(Stdio.File(), conf);

    // c->first = first;
    c->time = time;
    c->raw_url = raw_url;
    c->variables = copy_value(variables);
    c->misc = copy_value(misc);
    c->misc->orig = t;

    c->prestate = prestate;
    c->supports = supports;
    c->config = config;

    c->remoteaddr = remoteaddr;
    c->host = host;

#ifdef EXTRA_ROXEN_COMPAT
    c->client = client;
    c->referer = referer;
#endif
    c->useragent = useragent;
    c->referrer = referrer;

    c->pragma = pragma;

    c->cookies = cookies;
    c->my_fd = 0;
    c->prot = prot;
    c->clientprot = clientprot;
    c->method = method;
  
// realfile virtfile   // Should not be copied.  
    c->rest_query = rest_query;
    c->raw = raw;
    c->query = query;
    c->not_query = not_query;
    c->data = data;
    c->extra_extension = extra_extension;
    c->auth = auth;

    c->user = user;
    c->realauth = realauth;
    c->rawauth = rawauth;
    c->since = since;
    return c;
  }

  void create(object _fd, object _conf)
  {
    my_fd=_fd;
    conf=_conf;
    return;
  }
}

//! @appears Configuration
//! The Configuration object.
//! This module implements the base of the configuration object used by 
//! virtual servers.  This is the same object that you access through the 
//! common @tt{id->conf@} object in your modules, tags etc.
class Configuration
{

}

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
