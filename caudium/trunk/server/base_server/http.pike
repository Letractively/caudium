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
**! file: base_server/http
**!  This file implements various helper functions related to the HTTP
**!  protocol. It is inherited by roxenlib, so inheriting roxenlib is 
**!  enough to get access to these functions. 
**!
**! cvs_version: $Id$
*/

#include <config.h>

#if !constant(caudium)
#define caudium caudiump()
#endif

string http_date(int t);

#include <variables.h>

/*
**! method: string http_res_to_string( mapping file, object id )
**!   Convert the file result sent in the first argument to a HTTP
**!   response header (what you would get for a HEAD request on the
**!   resource.
**! arg: mapping file
**!   The file mapping (this is what you http_string_answer etc generates).
**! arg: object id
**!   The request object.
**! returns:
**!   The HTTP header string.
**! name: http_res_to_string - convert file result to HTTP header
*/

string http_res_to_string( mapping file, object id )
{
  mapping heads=
    ([
      "Content-type":file["type"],
      "Server":replace(id->version(), " ", "·"),
      "Date":http_date(id->time)
      ]);
    
  if(file->encoding)
    heads["Content-Encoding"] = file->encoding;
    
  if(!file->error) 
    file->error=200;
    
  if(file->expires)
      heads->Expires = http_date(file->expires);

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=id->misc->stat))
	file->stat = (int *)file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];
      
      heads["Last-Modified"] = http_date(fstat[3]);
    }
    if(stringp(file->data)) 
      file->len += strlen(file->data);
  }

  if(mappingp(file->extra_heads)) 
    heads |= file->extra_heads;

  if(mappingp(id->misc->moreheads))
    heads |= id->misc->moreheads;
    
  array myheads=({id->prot+" "+(file->rettext||errors[file->error])});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach(heads[h], string tmp)
	myheads += ({ `+(h,": ", tmp)});
    else
      myheads +=  ({ `+(h, ": ", heads[h])});
  

  if(file->len > -1)
    myheads += ({"Content-length: " + file->len });
  string head_string = (myheads+({"",""}))*"\r\n";

  if(id->conf) {
    id->conf->hsent+=strlen(head_string||"");
    if(id->method != "HEAD")
      id->conf->sent+=(file->len>0 ? file->len : 1000);
  }
  if(id->method != "HEAD")
    head_string+=(file->data||"")+(file->file?file->file->read(0x7ffffff):"");
  return head_string;
}

/*
**! method: mapping http_low_answer( int errno, string data )
**!   Return a response mapping with the error and data specified. The
**!   error is infact the status response, so '200' is HTTP Document
**!   follows, and 500 Internal Server error, etc. The content type will
**!   always be text/plain
**! arg: int errno
**!   The HTTP error code to use in the reply.
**! arg: string data
**!   The data to return.
**! returns:
**!   The HTTP respone mapping.
**! name: http_low_answer - return a response mapping with the specified info
*/
mapping http_low_answer( int errno, string data )
{
  if(!data) data="";
#ifdef HTTP_DEBUG
  perror("HTTP: Return code "+errno+" ("+data+")\n");
#endif  
  return 
    ([ 
      "error" : errno,
      "data"  : data,
      "len"   : strlen( data ),
      "type"  : "text/html",
      ]);
}

/*
**! method: mapping http_pipe_in_progress( )
**!   Returns a response mapping that tells Caudium that this request
**!   is in progress and that sending of data, closing the connection
**!   and such will be handled by the module. If this is used and you 
**!   fail to close connections correctly, FD leaking will be the result. 
**! returns:
**!   The HTTP respone mapping.
**! name: http_pipe_in_progress - return a response mapping 
*/
mapping http_pipe_in_progress()
{
#ifdef HTTP_DEBUG
  perror("HTTP: Pipe in progress\n");
#endif  
  return ([ "file":-1, "pipe":1, ]);
}

static string parse_rxml(string what, object id,
			 void|object file, 
			 void|mapping defines);

/*
**! method: string http_rxml_answer(string rxml, object id, void|object(Stdio.File) file, string|void type)
**!   Convenience function to use in Caudium modules and Pike scripts. When you
**!   just want to return a string of data, with an optional type, this is the
**!   easiest way to do it if you don't want to worry about the internal
**!   Caudium structures. This function creates a response mapping containing the
**!   RXML parsed data you send to it.
**! arg: string rxml
**!   The text to RXML parse and return.
**! arg: object id
**!   The request id object.
**! arg: void|object(Stdio.File) file
**!   An optional file descriptor to return // FIXME //
**! arg: void|string type
**!   Optional file type, like text/html or application/octet-stream
**! returns:
**!   The http response mapping with the parsed data.
**! name: http_rxml_answer - parse and return the specified data
*/
mapping http_rxml_answer( string rxml, object id, 
                          void|object(Stdio.File) file, string|void type )
{
  rxml = parse_rxml(rxml, id, file);
  return (["data":rxml,
	   "type":(type||"text/html"),
	   "stat":id->misc->defines[" _stat"],
	   "error":id->misc->defines[" _error"],
	   "rettext":id->misc->defines[" _rettext"],
	   "extra_heads":id->misc->defines[" _extra_heads"],
	   ]);
}


/*
**! method: mapping http_string_answer( string text, string|void type )
**!   Return a response mapping with the text and the specified content type.
**!   If the content type argument is left out, text/html will be used.
**! arg: string text
**!   The data string.
**! arg: string|void
**!   The optional content type to override the default text/html.
**! returns:
**!   The HTTP respone mapping.
**! name: http_string_answer - return a response mapping as specified
*/
mapping http_string_answer(string text, string|void type)
{
#ifdef HTTP_DEBUG
  perror("HTTP: String answer ("+(type||"text/html")+")\n");
#endif  
  return ([ "data":text, "type":(type||"text/html") ]);
}

/*
**! method: mapping http_file_answer( object fd, string|void type, int|void len)
**!   Return a response mapping with the specified file descriptior using the
**!   specified content type and length.
**! arg: object fd
**!   The file descriptor object. This can be a an ordinary file, a socket etc.
**! arg: string|void type
**!   The optional content type to override the default text/html.
**! arg: int|void len
**!   The number of bytes of data to read from the object. The default is to
**!   read until EOF
**! returns:
**!   The HTTP respone mapping.
**! name: http_file_answer - return a response mapping as specified
*/
mapping http_file_answer(object fd, string|void type, void|int len)
{
  return ([ "file":fd, "type":(type||"text/html"), "len":len ]);
}

constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

/*
**! method: string cern_http_date(int t)
**!   Return the specified date (as returned by time()) formatted in the
**!   common log file format, which is "DD/MM/YYYY:HH:MM:SS [+/-]TZTZ". 
**! arg: int t
**!   The time in seconds since the 00:00:00 UTC, January 1, 1970.
**! returns:
**!   The date in the common log file format.
**!   Example: 02/Aug/2000:22:36:27 -0700
**! name: cern_http_date - return a date in the common log file format
*/
string cern_http_date(int t)
{
  string c;
  mapping lt = localtime(t);
  int tzh = lt->timezone/3600 - lt->isdst;

  if(tzh > 0)
    c="-";
  else {
    tzh = -tzh;
    c="+";
  }

#if 1
  return(sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
		 lt->mday, months[lt->mon], 1900+lt->year,
		 lt->hour, lt->min, lt->sec, c, tzh));
#else
  string s = ctime(t);
  
  return sprintf("%02d/%s/%s:%s %s%02d00", (int)s[8..9], s[4..6], s[20..23], 
		 s[11..18], c ,tzh);
#endif /* 1 */
}

/* Returns a http_date, as specified by the HTTP-protocol standard. 
 * This is used for logging as well as the Last-Modified and Time
 * heads in the reply.  */


/*
**! method: string http_date(int t)
**!   Return the specified date (as returned by time()) formatted in the
**!   HTTP-protocol standard date format. Used in for example the Last-Modified
**!   header.
**! arg: int t
**!   The time in seconds since the 00:00:00 UTC, January 1, 1970.
**! returns:
**!   The date in the HTTP standard date format.
**!   Example: Thu, 03 Aug 2000 05:40:39 GMT
**! name: cern_http_date - return a date in the HTTP standard format
*/
string http_date(int t)
{
#if constant(gmtime)
  mapping l = gmtime( t );
#else
  mapping l = localtime(t);
  t += l->timezone - 3600*l->isdst;
  l = localtime(t);
#endif
  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		 days[l->wday], l->mday, months[l->mon], 1900+l->year,
		 l->hour, l->min, l->sec));

}


/*
**! method: string http_encode_string(string s)
**!   HTTP encode the specified string and return it. This means replacing
**!   the following characters to the %XX format: null (char 0), space, tab,
**!   carriage return, newline, percent and single and double quotes.
**! arg: string s
**!   The string to encode.
**! returns:
**!   The HTTP encoded string.
**! name: http_encode_string - HTTP encode a string
*/
string http_encode_string(string f)
{
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22"}));
}

/*
**! method: string http_encode_cookie(string s)
**!   Encode the specified string in as to the HTTP cookie standard.
**!   The following characters will be replaced: = , ; % :
**! arg: string s
**!   The string to encode.
**! returns:
**!   The HTTP cookie encoded string.
**! name: http_encode_cookie - HTTP cookie encode a string
*/
string http_encode_cookie(string f)
{
  return replace(f, ({ "=", ",", ";", "%", ":" }),
		 ({ "%3d", "%2c", "%3b", "%25", "%3A" }));
}

/*
**! method: string http_encode_url(string s)
**!   URL encode the specified string and return it. This means replacing
**!   the following characters to the %XX format: null (char 0), space, tab,
**!   carriage return, newline, and % ' " # & ? = / : +
**! arg: string s
**!   The string to encode.
**! name: http_encode_url - URL encode a string
**! returns:
**!   The URL encoded string.
*/
string http_encode_url (string f)
{
  return replace (f, ({"\000", " ", "\t", "\n", "\r", "%", "'", "\"", "#",
		       "&", "?", "=", "/", ":", "+"}),
		  ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22", "%23",
		    "%26", "%3f", "%3d", "%2f", "%3a", "%2b"}));
}

/*
**! method: string http_caudium_config_cookie(string from)
**!   Make a configuration cookie. This is is not a function ment to
**!   be used by the average user.
**! arg: string from
**!   The cookie value to encode and put in the cookie.
**! name: http_caudium_config_cookie - make a config cookie
**! returns:
**!   The cookie value.
*/
string http_caudium_config_cookie(string from)
{
  return "CaudiumConfig="+http_encode_cookie(from)
    +"; expires=" + http_date (3600*24*365*2 + time (1)) + "; path=/";
}
function(string:string) http_roxen_config_cookie = http_caudium_config_cookie;


/*
**! method: string http_caudium_id_cookie()
**!   Make a unique user id cookie. This is an internal function which is used
**!   to set a cookie for all visitors
**! name: http_caudium_id_cookie - make a unique user cookie
**! returns:
**!   The cookie value.
*/
string http_caudium_id_cookie()
{
  return sprintf("CaudiumUserID=0x%x; expires=" +
		 http_date (3600*24*365*2 + time (1)) + "; path=/",
		 caudium->increase_id());
}
function(string:string) http_roxen_id_cookie = http_caudium_id_cookie;

static string add_pre_state( string url, multiset state )
{
  if(!url)
    error("URL needed for add_pre_state()\n");
  if(!state || !sizeof(state))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/(" + sort(indices(state)) * "," + ")" + url ;
}

/* Simply returns a http-redirect message to the specified URL.  */
mapping http_redirect( string url, object|void id )
{
  if(url[0] == '/')
  {
    if(id)
    {
      url = add_pre_state(url, id->prestate);
      if(id->misc->host) {
	string p = ":80", prot = "http://";
	array h;
	if(id->ssl_accept_callback) {
	  // This is an SSL port. Not a great check, but what is one to do?
	  p = ":443";
	  prot = "https://";
	}
	h = id->misc->host / p  - ({""});
	if(sizeof(h) == 1)
	  // Remove redundant port number.
	  url=prot+h[0]+url;
	else
	  url=prot+id->misc->host+url;
      } else
	url = id->conf->query("MyWorldLocation") + url[1..];
    }
  }
#ifdef HTTP_DEBUG
  perror("HTTP: Redirect -> "+http_encode_string(url)+"\n");
#endif  
  return http_low_answer( 302, "") 
    + ([ "extra_heads":([ "Location":http_encode_string( url ) ]) ]);
}

mapping http_stream(object from)
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}


mapping http_auth_required(string realm, string|void message)
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
#ifdef HTTP_DEBUG
  perror("HTTP: Auth required ("+realm+")\n");
#endif  
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

#ifdef API_COMPAT
mapping http_auth_failed(string realm)
{
#ifdef HTTP_DEBUG
  perror("HTTP: Auth failed ("+realm+")\n");
#endif  
  return http_low_answer(401, "<h1>Authentication failed.\n</h1>")
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}
#else
function http_auth_failed = http_auth_required;
#endif


mapping http_proxy_auth_required(string realm, void|string message)
{
#ifdef HTTP_DEBUG
  perror("HTTP: Proxy auth required ("+realm+")\n");
#endif  
  if(!message)
    message = "<h1>Proxy authentication failed.\n</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}
 

