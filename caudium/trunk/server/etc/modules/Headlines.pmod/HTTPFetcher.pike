/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 * Copyright © David Hedbor
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

//! HTTPFetcher.pike - sync and async fetching of http-files using
//! Protocols.HTTP.Query from Pike 7.x. Also has a usable url encoding
//! function.
//! $Id$

int timeout;

//! Encode string to HTML
//! @param what
//!  String to encode
//! @returns
//!  HTMLized string
string encode(string what)
{
  string loc = "";
  sscanf(what, "%s#%s", what, loc);
  if(strlen(loc))
    loc = "#"+loc;
  return replace(what, ({",", " ", "(", ")", "\"" }),
		 ({"%2C", "%20", "%28", "%28", "%22"})) + loc;
}

static private array split_url(string url)
{
  string host, file="";
  int port=80;
  sscanf(url, "http://%s/%s", host, file);
    
  if(!host)
    return ({0,0,0});
  file = encode(file);
  sscanf(host, "%s:%d", host, port);
  return ({ host, port, "/"+file });
}

//!
int async_fetch(string url, function ok, function fail, mixed extra)
{
  object http = Protocols.HTTP.Query();
  string host, file, host_header;
  int port;
  [ host, port, file ] = split_url(url);
  if(!host)
    return 0;
  http->set_callbacks(ok, fail, extra);
  if(timeout) http->timeout = timeout;
  if(port != 80)
    host_header = sprintf("%s:%d", host, port);
  http->async_request(host, port, "GET "+file+" HTTP/1.0",
		      ([ 
			"User-Agent":"PikeFetcher",
			"Host": host_header || host,
			"Content-Length": "0"
		      ]));
  return 1;
}

//! Async Fetch an URL
//! @param url
//!   Url to fetch
//! @returns
//!   The data from url
string fetch(string url)
{
  object http = Protocols.HTTP.Query();
  string host, file;
  int port;
  [ host, port, file ] = split_url(url);
  if(!host)
    return 0;
  http->thread_request(host, port, "GET "+file+" HTTP/1.0",
		       ([ 
			 "User-Agent":"PikeFetcher",
			 "Host": sprintf("%s:%d", host, port),
			 "Content-Length": "0"
		       ]));
    
  return http->data()||"";
}

