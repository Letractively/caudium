/* HTTPFetcher.pike - sync and async fetching of http-files using
 * Protocols.HTTP.Query from Pike 0.7. Also has a usable url encoding
 * function.
 * 
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

int timeout;

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
			"User-Agent":"PikeFetcher/"+hversion,
			"Host": host_header || host,
			"Content-Length": "0"
		      ]));
  return 1;
}

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

