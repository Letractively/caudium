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
 * $Id$
 */

constant cvs_version = "$Id$";

inherit RequestID;
private inherit "caudiumlib";

// HTTP protocol module.
#include <config.h>
#include <module.h>
#include <variables.h>

#undef QUERY
#define QUERY(X)  _query( #X )

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

private int cache_control_ok = 0;

// Parse a HTTP/1.1 HTTP/1.0 or 0.9 request, including form data and
// state variables.  Return 0 if more is expected, 1 if done, and -1
// if fatal error.

private void setup_pipe()
{
  if(!my_fd) 
  {
    end();
    return;
  }
  if(!pipe) pipe=thepipe();
}

void send(string|object what, int|void len)
{
#ifdef REQUEST_DEBUG
  roxen_perror(sprintf("send(%O, %O)\n", what, len));
#endif /* REQUEST_DEBUG */

  if(!what) return;
  if(!pipe) setup_pipe();
  if(!pipe) return;
  if(stringp(what))  pipe->write(what);
  else               pipe->input(what,len);
}

//! Parse the passed string and look for the query part of the URL (the
//! part that follows a question mark)
//!
//! @param f
//!  The string to parse
string scan_for_query( string f )
{
  if(sscanf(f,"%s?%s", f, query) == 2)
  {
    string v, a, b;
#if constant(Caudium.parse_query_string)
    Caudium.parse_query_string(query, variables);
#else
#error The Caudium.so module is missing!
#endif
  }
  return f;
}

private int really_set_config(array mod_config)
{
  string url, m;
  string base;
  base = conf->query("MyWorldLocation")||"/";
  if(supports->cookies)
  {
#ifdef REQUEST_DEBUG
    perror("Setting cookie..\n");
#endif
    if(mod_config)
      foreach(mod_config, m)
	if(m[-1]=='-')
	  config[m[1..]]=0;
	else
	  config[m]=1;
      
    if(sscanf(replace(raw_url,({"%3c","%3e","%3C","%3E" }),
		      ({"<",">","<",">"})),"/<%*s>/%s",url)!=2)
      url = "/";

    if ((base[-1] == '/') && (strlen(url) && url[0] == '/')) {
      url = base + url[1..];
    } else {
      url = base + url;
    }

    my_fd->write(prot + " 302 Config in cookie!\r\n"
		 "Set-Cookie: "
		  + http_caudium_config_cookie(indices(config) * ",") + "\r\n"
		 "Location: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  } else {
#ifdef REQUEST_DEBUG
    perror("Setting {config} for user without Cookie support..\n");
#endif
    if(mod_config)
      foreach(mod_config, m)
	if(m[-1]=='-')
	  prestate[m[1..]]=0;
	else
	  prestate[m]=1;
      
    if (sscanf(replace(raw_url, ({ "%3c", "%3e", "%3C", "%3E" }), 
		       ({ "<", ">", "<", ">" })),   "/<%*s>/%s", url) == 2) {
      url = "/" + url;
    }
    if (sscanf(replace(url, ({ "%28", "%29" }), ({ "(", ")" })),
	       "/(%*s)/%s", url) == 2) {
      url = "/" + url;
    }

    url = add_pre_state(url, prestate);

    if (base[-1] == '/') {
      url = base + url[1..];
    } else {
      url = base + url;
    }

    my_fd->write(prot + " 302 Config In Prestate!\r\n"
		 "\r\nLocation: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  }
  return 2;

}


//! handle the encryption of the body data
//! this is usually just the case for the POST method
void handle_body_encoding(int content_length)
{
  string content_type =lower_case(
    (((request_headers["content-type"]||"")+";")/";")[0]-" "); 
  switch(content_type)
  {
    default: // Normal form data.
      string v;
      if ( method != "POST" )
	return; // no encoding if not POST method
      if(content_length < 200000)
	Caudium.parse_query_string(replace(data, ({ "\n", "\r"}),
					   ({"", ""})), variables);
      break;
      
    case "multipart/form-data":
      object messg = MIME.Message(data, request_headers);
      foreach(messg->body_parts||({}), object part) {
	if(part->disp_params->filename) {
	  variables[part->disp_params->name]=part->getdata();
	  string fname=part->disp_params->filename;
	  if( part->headers["content-disposition"] ) {
	    array fntmp=part->headers["content-disposition"]/";";
	    if( sizeof(fntmp) >= 3 && search(fntmp[2],"=") != -1 ) {
	      fname=((fntmp[2]/"=")[1]);
	      fname=fname[1..(sizeof(fname)-2)];
	    }
	  }
	  variables[part->disp_params->name+".filename"]=fname;
		
	  if(!misc->files)
	    misc->files = ({ part->disp_params->name });
	  else
	    misc->files += ({ part->disp_params->name });
	} 
	else {
	  if(variables[part->disp_params->name])
	    variables[part->disp_params->name] += "\0" + part->getdata();
	  else
	    variables[part->disp_params->name] = part->getdata();
	}
      }
      break;
  }
}

private static mixed f, line;
static int last_search;
private int parse_got()
{
  multiset (string) sup;
  array mod_config;
  string a, b, linename, contents, s;
  int config_in_url;

  REQUEST_WERR(sprintf("HTTP: parse_got(%O)", raw));
  //  caudium->httpobjects[my_id] = "Parsed data...";
  if (!method) {  // Haven't parsed the first line yet.
    int start;
    // We check for \n only if \r\n fails, since Netscape 4.5 sends
    // just a \n when doing a proxy-request.
    // example line:
    //   "CONNECT mikabran:443 HTTP/1.0\n"
    //   "User-Agent: Mozilla/4.5 [en] (X11; U; Linux 2.0.35 i586)"
    // Die Netscape, die! *grumble*
    // Luckily the solution below shouldn't ever cause any slowdowns
    //
    // Note by Neo:  Rewrote the sscanf code to use search with a memory.
    // The reason is that otherwise it's really, REALLY easy to lock up
    // a Caudium server by sending a request that either has no newlines at all
    // or has infinite sized headers. With this version, Caudium doesn't die but
    // it does suck up data ad finitum - a configurable max GET request size and
    // also a max GET+headers would be nice. 

    if((start = search(raw[last_search..], "\n")) == -1) {
      last_search = max(strlen(raw) - 3, 4);
      REQUEST_WERR(sprintf("HTTP: parse_got(%O): Not enough data.", raw));
      return 0;
    } else {
      start += last_search;
      last_search = 0;
      if(!start) {
	REQUEST_WERR(sprintf("HTTP: parse_got(%O): malformed request.", raw));
	return 1; // malformed request
      }
    }
    if (raw[start-1] == '\r') {
      line = raw[..start-2];
    } else {
      // Kludge for Netscape 4.5 sending bad requests.
      line = raw[..start-1];
    }
    if(strlen(line) < 4)
    {
      // Incorrect request actually - min possible (HTTP/0.9) is "GET /"
      // but need to support PING of course!

      REQUEST_WERR(sprintf("HTTP: parse_got(%O): Malformed request.", raw));
      return 1;
    }

    string trailer, trailer_trailer;
    switch(sscanf(line+" ", "%s %s %s %s %s",
		  method, f, clientprot, trailer, trailer_trailer))
    {
    case 5:
      // Stupid sscanf!
      if (trailer_trailer != "") {
	// Get rid of the extra space from the sscanf above.
	trailer += " " + trailer_trailer[..sizeof(trailer_trailer)-2];
      }
      /* FALL_THROUGH */
    case 4:
      // Got extra spaces in the URI.
      // All the extra stuff is now in the trailer.

      // Get rid of the extra space from the sscanf above.
      trailer = trailer[..sizeof(trailer) - 2];
      f += " " + clientprot;

      // Find the last space delimiter.
      int end;
      if (!(end = (search(reverse(trailer), " ") + 1))) {
        // Just one space in the URI.
        clientprot = trailer;
      } else {
        f += " " + trailer[..sizeof(trailer) - (end + 1)];
        clientprot = trailer[sizeof(trailer) - end ..];
      }
      /* FALL_THROUGH */
    case 3:
      // >= HTTP/1.0

      prot = clientprot;
      //      method = upper_case(p1);
      if(!(< "HTTP/1.0", "HTTP/1.1" >)[prot]) {
	// We're nice here and assume HTTP even if the protocol
	// is something very weird.
	prot = "HTTP/1.1";
      }
      // Do we have all the headers?
      if ((end = search(raw[last_search..], "\r\n\r\n")) == -1) {
	// No, we still need more data.
	REQUEST_WERR("HTTP: parse_got(): Request is still not complete.");
	last_search = max(strlen(raw) - 5, 0);
	return 0;
      }
      
      if (prot == "HTTP/1.1")
        cache_control_ok = 1;

      end += last_search;
      last_search = 0;
      data = raw[end+4..];
      s = raw[sizeof(line)+2..end-1];
      // s now contains the unparsed headers.
      break;

    case 2:
#ifdef SUPPORT_HTTP_09
     // HTTP/0.9
      clientprot = prot = "HTTP/0.9";
      method = "GET"; // 0.9 only supports get.
      s = data = ""; // no headers or extra data...
      break;
#endif     
    default:
      // Invalid request
     method = "UNKNOWN";
     clientprot = prot = "HTTP/1.0";
     REQUEST_WERR("HTTP: Unknown / unsupported protocol.");
     return 1;
    }
  } else {
    // HTTP/1.0 or later
    // Check that the request is complete
    int end;
    if ((end = search(raw[last_search..], "\r\n\r\n")) == -1) {
      // No, we still need more data.
      REQUEST_WERR("HTTP: parse_got(): Request is still not complete.");
      last_search = max(strlen(raw) - 5, 0);
      return 0;
    }
    end += last_search;
    data = raw[end+4..];
    s = raw[sizeof(line)+2..end-1];
  }
  raw_url    = f;
  time       = _time(1);
  
  REQUEST_WERR(sprintf("RAW_URL:%O", raw_url));

  if(sscanf(f,"%s?%s", f, query) == 2)
    Caudium.parse_query_string(query, variables);
  
  REQUEST_WERR(sprintf("After query scan:%O", f));

  f = _Roxen.http_decode_string( f );

  /* Fix %00 (NULL) bug */
  sscanf( f, "%s\0", f );
  if ((sscanf(f, "/<%s>/%s", a, f)==2) || (sscanf(f, "/%%3C%s%%3E%s", a, f)==2))
  {
    config_in_url = 1;
    mod_config = (a/",");
    f = "/"+f;
  }

  REQUEST_WERR(sprintf("After cookie scan:%O", f));

#if 0  
  if ((sscanf(f, "/(%s)/%s", a, f)==2) && strlen(a))
  {
    prestate = aggregate_multiset(@(a/","-({""})));
    f = "/"+f;
  }
#else
  f = Caudium.parse_prestates(f, prestate, internal);
  REQUEST_WERR(sprintf("prestate == %O\ninternal == %O\n",
                       prestate, internal));
#endif

  REQUEST_WERR(sprintf("After prestate scan:%O", f));

  not_query = simplify_path(f);

  REQUEST_WERR(sprintf("After simplify_path == not_query:%O", not_query));

  if(sizeof(s)) {
#if constant(Caudium.parse_headers)
    request_headers = Caudium.parse_headers(s);
    foreach(indices(request_headers), string linename) {
      array(string) y;
      switch(linename) {
       case "content-length":
	
	 // read the data on every request, even though some methods 
	 // dont require request bodies
	 misc->len = (int)(request_headers[linename]-" ");
	 if(!misc->len) continue;
	
	 // only the POST method should have a body
	 // read the data in any case though
	 if(!data) data="";
	 int l = misc->len;
	 
	 if ( objectp(conf) ) {
	   int conf_size = conf->query("PostBodySize");
	   if ( conf_size < 0 )
	     wanted_data = l;
	   else
	     wanted_data = min(l, conf_size);
	 }
	 else
	   wanted_data = min(l, POST_MAX_BODY_SIZE);
	 have_data=strlen(data);
	 
	 if( have_data < wanted_data )
	 {
	   if ( clientprot = "HTTP/1.1" )
	     my_fd->write("HTTP/1.1 100 Continue\r\n\r\n");
	     REQUEST_WERR("HTTP: parse_request(): More data needed.");
	     return 0;
	 }
	 if ( wanted_data < l ) {
	   unread_data = l - have_data;
	   REQUEST_WERR("HTTP: parsing, ignoring next " + unread_data +
			" bytes of request body.");
	 }
	 leftovers = data[l..];
	 data = data[..l-1];
	 handle_body_encoding(l);
	 wanted_data = 0;
	 break;
       case "authorization":
	rawauth = request_headers[linename];
	y = rawauth / " ";
	if(sizeof(y) < 2) break;

        low_handle_authorization(y);

	break;
	  
       case "proxy-authorization":
	y = request_headers[linename] / " ";
	if(sizeof(y) < 2)
	  break;
	y[1] = decode(y[1]);

        // note: can we modify this to use low_handle_authorization()?
	if(conf && conf->auth_module)
        {
          if(y[0]=="Basic") // we can handle basic authentication right now.
          {
            int res;
            array a=y[1]/":";
            res = conf->auth_module->authenticate(a[0], a[1]);
            if(res==1) // successful authentication
            {
               misc->proxyauth=({1, a[0], 0});
            }
            else // failed authentication
            {
               misc->proxyauth=({0, a[0], a[1]});
            }
          }
        }
        else // we don't have an authentication handler, so provide the raw data.
          misc->proxyauth=y;
	break;
	  
       case "pragma":
	pragma |= aggregate_multiset(@replace(request_headers[linename],
					      " ", "")/ ",");
	break;

       case "user-agent":
	sscanf(useragent = request_headers[linename], "%s via", useragent);
#ifdef EXTRA_ROXEN_COMPAT
	client = (useragent/" ") - ({ "" });
#endif
	break;

       case "referer":
#ifdef EXTRA_ROXEN_COMPAT
	referer = request_headers[linename]/" ";
#endif
	referrer = request_headers[linename];
	break;
	    
       case "extension":
#ifdef DEBUG
	perror("Client extension: "+request_headers[linename]+"\n");
#endif
	break;
       case "request-range":
	if(GLOBVAR(EnableRangeHandling)) {
	  contents = lower_case(request_headers[linename]-" ");
	  if(!search(contents, "bytes")) 
	    // Only care about "byte" ranges.
	    misc->range = contents[6..];
	}
	break;
	    
       case "range":
	if(GLOBVAR(EnableRangeHandling)) {
	  contents = lower_case(request_headers[linename]-" ");
	  if(!misc->range && !search(contents, "bytes"))
	    // Only care about "byte" ranges. Also the Request-Range header
	    // has precedence since Stupid Netscape (TM) sends both but can't
	    // handle multipart/byteranges but only multipart/x-byteranges.
	    // Duh!!!
	    misc->range = contents[6..];
	}
	break;

       case "connection":
	request_headers[linename] = lower_case(request_headers[linename]);
#ifndef EXTRA_ROXEN_COMPAT
	break;
#endif
       case "content-type":
#ifdef EXTRA_ROXEN_COMPAT
        array ct_parts = request_headers[linename] / ";";
        ct_parts[0] = lower_case(ct_parts[0]);
        misc[linename] = ct_parts * ";";
#endif
	break;

       case "accept-encoding":
        if(search(request_headers[linename], "gzip") != -1)
          supports["autogunzip"] = 1;
        if(search(request_headers[linename], "deflate") != -1)
          supports["autoinflate"] = 1;
        if(search(request_headers[linename], "compress") != -1)
          supports["autouncompress"] = 1;
       case "accept":
       case "accept-charset":
       case "accept-language":
       case "session-id":
       case "message-id":
       case "from":
	if(misc[linename])
	  misc[linename] += (request_headers[linename]-" ") / ",";
	else
	  misc[linename] = (request_headers[linename]-" ") / ",";
	break;

       case "cookie": /* This header is quite heavily parsed */
	string c;
	contents = misc->cookies = request_headers[linename];
	if (!sizeof(contents)) {
	  // Needed for the new Pike 0.6
	  break;
	}
	foreach(((contents/";") - ({""})), c)
	{
	  string name, value;
	  while(sizeof(c) && c[0]==' ') c=c[1..];
	  if(sscanf(c, "%s=%s", name, value) == 2)
	  {
	    value=_Roxen.http_decode_string(value);
	    name=_Roxen.http_decode_string(name);
	    cookies[ name ]=value;
	    if(name == "CaudiumConfig" && strlen(value))
	    {
	      array tmpconfig = value/"," + ({ });
	      string m;

	      if(mod_config && sizeof(mod_config))
		foreach(mod_config, m)
		  if(!strlen(m))
		  { continue; } /* Bug in parser force { and } */
		  else if(m[0]=='-')
		    tmpconfig -= ({ m[1..] });
		  else
		    tmpconfig |= ({ m });
	      mod_config = 0;
	      config = aggregate_multiset(@tmpconfig);
	    }
	  }
	}
	break;

       case "host":
	host = lower_case(request_headers[linename]);
#ifdef EXTRA_ROXEN_COMPAT
       case "proxy-connection":
       case "security-scheme":
       case "via":
       case "cache-control":
       case "negotiate":
       case "forwarded":
	misc[linename] = request_headers[linename];
#endif
	break;	    

       case "if-modified-since":
	since = request_headers[linename];
	break;
      }
    }
#endif
  }
  if(prestate->nocache) {
    // This allows you to "reload" a page with MSIE by setting the
    // (nocache) prestate.
    pragma["no-cache"] = 1;
    misc->cacheable = 0;
  }
#ifdef ENABLE_SUPPORTS    
  if(useragent == "unknown") {
    supports = find_supports("", supports); // This makes it somewhat faster.
  } else 
    supports = find_supports(lower_case(useragent), supports);
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif

#ifdef EXTRA_ROXEN_COMPAT
  if(!referer) referer = ({ });
#endif
  
  if(misc->proxyauth) {
    // The Proxy-authorization header should be removed... So there.
    mixed tmp1,tmp2;    
    foreach(tmp2 = (raw / "\n"), tmp1) {
      if(!search(lower_case(tmp1), "proxy-authorization:"))
	tmp2 -= ({tmp1});
    }
    raw = tmp2 * "\n"; 
  }

  if(config_in_url) {
    return really_set_config( mod_config );
  }
  if(!supports->cookies)
    config = prestate;
  else
    if(conf
       && QUERY(set_cookie)
       && !cookies->CaudiumUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT")
    {
      if (!(QUERY(set_cookie_only_once) &&
	    cache_lookup("hosts_for_cookie",remoteaddr))) {
	misc->moreheads = ([ "Set-Cookie": http_caudium_id_cookie(), ]);
      }
      if (QUERY(set_cookie_only_once))
	cache_set("hosts_for_cookie",remoteaddr,1);
    }
  return -1;	// Done.
}

void disconnect()
{
  file = 0;
  MARK_FD("my_fd in HTTP disconnected?");
  if(do_not_disconnect) return;
  destruct();
}

void end(string|void s, int|void keepit)
{
  pipe = 0;
#ifdef PROFILE
  if(conf)
  {
    float elapsed = SECHR(HRTIME()-req_time);
    string nid =
#ifdef FILE_PROFILE
      not_query
#else
      dirname(not_query)
#endif
      ;
    array p;
    if(!(p=conf->profile_map[nid]))
      p = conf->profile_map[nid] = ({0,0.0,0.0});
    conf->profile_map[nid][0]++;
    p[1] += elapsed;
    if(elapsed > p[2]) p[2]=elapsed;
  }
#endif

#ifdef KEEP_ALIVE
  if(keepit &&
     (!(file->raw || file->len <= 0))
     && (request_headers->connection == "keep-alive" ||
	 (prot == "HTTP/1.1" && request_headers->connection != "close"))
     && my_fd)
  {
    // Now.. Transfer control to a new http-object. Reset all variables etc..
    object o = object_program(this_object())(my_fd, conf);
    o->remoteaddr = remoteaddr;
    o->supports = supports;
    o->unread_data = unread_data;
#ifdef EXTRA_ROXEN_COMPAT
    o->client = client;
#endif
    o->useragent = useragent;
    MARK_FD("HTTP kept alive");
    object fd = my_fd;
    my_fd=0;
    if(s) leftovers += s;
    while(sscanf(leftovers, "\r\n%s", leftovers))
      ; // Remove beginning newlines..
    o->chain(fd,conf,leftovers);
    disconnect();
    return;
  }
#endif

  if(objectp(my_fd))
  {
    MARK_FD("HTTP closed");
    catch {
      my_fd->set_close_callback(0);
      my_fd->set_read_callback(0);
      my_fd->set_blocking();
      if(s) my_fd->write(s);
      my_fd->close();
    };
    my_fd = 0;
  }
  disconnect();  
}

static void do_timeout()
{
  // werror("do_timeout() called, time="+time+"; time()="+_time()+"\n");
  int elapsed = _time()-time;
  if(time && elapsed >= 30)
  {
    MARK_FD("HTTP timeout");
    // Do not under any circumstances send any data as a reply here.
    // This is an easy reason why: It breaks keep-alive totaly.
    // It is not a very good idea to do that, since it might be enabled
    // per deafult any century now..
    end("");
  } else {
    // premature call_out... *�#!"
    call_out(do_timeout, 10);
    MARK_FD("HTTP premature timeout");
  }
}

static string last_id, last_from;
string get_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(5000);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" (version "+id+")";
  };
  last_id = "";
  return "";
}

void add_id(array to)
{
  foreach(to[1], array q)
    if(stringp(q[0]))
      q[0]+=get_id(q[0]);
}

string link_to(string file, int line, int eid, int qq)
{
  if(file[0]!='/') file = combine_path(getcwd(), file);
  return ("<a href=\"/(old_error,find_file)/error?"+
	  "file="+Caudium.http_encode_string(file)+"&"
	  "off="+qq+"&"
	  "error="+eid+"&"
	  "line="+line+"#here\">");
}

//! low handle authentication
//! @param y
//!    an array containing authentication string ala http authorization 
//!    header. Element 0 is a string describing the authentication type,
//!    typically "Basic", which is all we handle right now.
//!    element 2 is a base64 encoded string containing username:password
//!
//! @returns
//!    nothing, but will set user and auth if authentication was successful.
void low_handle_authorization(array y)
{
  if(sizeof(y)!=2) return;

  // y[0] == auth type, typically "Basic"
  // y[1] == username:password
  y[1]     = decode(y[1]);
  realauth = y[1];
  if(conf && conf->auth_module)
  {
    if(y[0]=="Basic") // we can handle basic authentication right now.
    {
      int res;
       array a=y[1]/":";
       res = conf->auth_module->authenticate(a[0], a[1]);
       if(res==1) // successful authentication
       {
         auth=({1, a[0], 0});
         // should we really do this? will caching be fast enough?
         user=conf->auth_module->user_info(a[0]);
        }
        else // failed authentication
        {
          auth=({0, a[0], a[1]});
        }
      }
    }
    else // we don't have an authentication handler, so just give 'em the raw data.
      auth = y;
  return;
}

string format_backtrace(array bt, int eid)
{
  // first entry is always the error, 
  // second is the actual function, 
  // rest is backtrace.

  string reason = caudium->diagnose_error( bt );
  if(sizeof(bt) == 1) // No backtrace?!
    bt += ({ "Unknown error, no backtrace."});
  string res = (
		"An error occured while calling <b>"+bt[1]+"</b>\n"
		+(reason?reason:"")
		+"<h3>Complete Backtrace:</h3>\n\n<ol>");

  int q = sizeof(bt)-1;
  array ares = ({});
  foreach(bt[1..], string line)
  {
    string ff, rest;
    int ln;
    if(line[0..3] == "    ") {
      if(sizeof(ares)) {
	line = String.trim_whites(line);
	if(strlen(line) > 20) {
	  ares[-1] += "<br>&nbsp;&nbsp;&nbsp;&nbsp;"+_Roxen.html_encode_string(line);
	} else {	 
	  ares[-1] += _Roxen.html_encode_string(line);
	}
      } else {
	ares += ({ _Roxen.html_encode_string(line) });
      }
    } else if(sscanf(line, "%s:%d%s", ff, ln, rest) == 3) {
      line =  _Roxen.html_encode_string(rest[1..]);
      if(strlen(line)) {
	line = "<br>&nbsp;&nbsp;&nbsp;&nbsp;"+ line;
      }
      rest = get_id( ff );
      ares += ({ (link_to(ff, ln,eid,sizeof(bt)-q-1)+ff+"</a> on line "+ln
		  +rest+":"+line)  -(getcwd()+"/") });
    } else {
      ares += ({ _Roxen.html_encode_string(line) });
    }
  }
  res += "<li>"+(ares * "</li><li><p>") +"</li>"+
    ("</ul><p><b><a href=\"/(old_error,plain)/error?error="+eid+"\">"
     "Generate text-only version of this error message, for bug reports"+
     "</a></b>");
  return res+"</body>";
}

string generate_bugreport(array from, string u, string rd)
{
  add_id(from);
  return ("<pre>"+_Roxen.html_encode_string("Caudium version: "+version()+
	  (caudium->real_version != version()?
	   " ("+caudium->real_version+")":"")+
	  "\nRequested URL: "+u+"\n"
	  "\nError: "+
	  describe_backtrace(from)-(getcwd()+"/")+
	  "\n\nDate: "+Caudium.HTTP.date(predef::time())+     
	  "\n\nRequest data:\n"+rd));
}

string censor(string what)
{
  string a, b, c;
  if(sscanf(what, "%shorization:%s\n%s", a, b, c)==3)
    return a+" ################ (censored)\n"+c;
  return what;
}

int store_error(array err)
{
  mapping e = caudium->query_var("errors");
  if(!e) caudium->set_var("errors", ([]));
  e = caudium->query_var("errors"); /* threads... */
  
  int id = ++e[0];
  if(id>1024) id = 1;
  e[id] = ({err,raw_url,censor(raw)});
  return id;
}

array get_error(string eid)
{
  mapping e = caudium->query_var("errors");
  if(e) return e[(int)eid];
  return 0;
}


// This macro ensures that something gets reported even when the very
// call to internal_error() fails. That happens eg when this_object()
// has been destructed.
#define INTERNAL_ERROR(err)							\
  if (mixed __eRr = catch (internal_error (err)))				\
    report_error("Internal server error: " + describe_backtrace(err) +		\
		 "internal_error() also failed: " + describe_backtrace(__eRr))

void internal_error(array err)
{
    string error_message;
    array err2;
    if(QUERY(show_internals))
    {
	err2 = catch {
	    array(string) bt = (describe_backtrace(err)/"\n") - ({""});
	    error_message = format_backtrace(bt, store_error(err));
	};
	if(err2) {
	    werror("Internal server error in internal_error():\n" +
		   describe_backtrace(err2)+"\n while processing \n"+
		   describe_backtrace(err));
	    error_message =
		"<h1>Error: The server failed to " +
		"fulfill your query, due to an " +
		"internal error in the internal error routine.</h1>";
	}
    } else {
	error_message =
	    "<h1>Error: The server failed to " +
	    "fulfill your query, due to an internal error.</h1>";
    }
    report_error("Internal server error: " +
		 describe_backtrace(err) + "\n");
    if ( catch( file = caudium->http_error->handle_error( 500, "Internal Server Error", error_message, this_object() ) ) ) {
        report_error("*** http_error object missing during internal_error() ***\n");
	file =
	    Caudium.HTTP.low_answer( 500, "<h1>Error: The server failed to fulfill your query due to an " +
            "internal error in the internal error routine.</h1>" );
    }
}

void do_log()
{
  MARK_FD("HTTP logging"); // fd can be closed here
  if(conf)
  {
    int len;
    if(pipe) file->len = pipe->bytes_sent();
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      file->len += misc->_log_cheat_addition;
      conf->log(file, this_object());
    }
  }
  end(0,1);
  return;
}

static void pipe_timeout() {
#if defined(FD_DEBUG) || defined(DEBUG)
  werror("Sending of data (piping) timed out.\n");
#endif
  end("");
}


static void timer(int start, int|void last_sent, int|void called_out)
{
  if(pipe) {
    int ps = pipe->bytes_sent();
    if(ps != last_sent) {
      if(called_out) {
	remove_call_out(pipe_timeout);
	called_out = 0;
      }
      last_sent = ps;
    } else if(!called_out) {
      call_out(pipe_timeout, 300);
      called_out = 1;
    }
    
    MARK_FD(sprintf("HTTP piping (st=%d, ln=%d, lc=%d, tm=%d, fl=%s)",
		    ps,
		    stringp(pipe->current_input) ?
		    strlen(pipe->current_input) : -1,
		    pipe->last_called,
		    _time(1) - start, 
		    not_query));
  } else {
    MARK_FD("HTTP piping, but no pipe for "+not_query); 
  }
  call_out(timer, 60, start, last_sent, called_out);
}

mapping handle_error_file_request(array err, int eid)
{
//   return "file request for "+variables->file+"; line="+variables->line;
  string data = Stdio.read_bytes(variables->file);
  array(string) bt = (describe_backtrace(err)/"\n") - ({""});

  if(data)
  {
    int off = 29;
    array (string) lines = data/"\n";
    int start = (int)variables->line-30;
    if(start < 0)
    {
      off += start;
      start = 0;
    }
    int end = (int)variables->line+30;
    lines=highlight_pike("foo", ([ "nopre":1 ]), lines[start..end]*"\n")/"\n";
    for(int st = start+1, i = 0; i < sizeof(lines); st++, i++) {
      lines[i] = sprintf("%4d:\t%s", st, lines[i]);
    }
//     foreach(bt, string b)
//     {
//       int line;
//       string file, fun;
//       sscanf(what, "%s(%*s in line %d in %s", fun, line, file);
//       if(file && fun && line) sscanf(file, "%s (", file);
//       if((file == variables->file) && 
// 	 (fun == variables->fun) && 
// 	 (line == variables->line))
//     }

    if(sizeof(lines)>off)
      lines[off]=("<font size=+1><b>"+lines[off]+"</b></font>");
    lines[max(off-20,0)] = "<a name=here>"+lines[max(off-20,0)]+"</a>";
    data = lines*"\n";
  }
  if ( catch( file = caudium->http_error->handle_error( 500, "Internal Server Error",  format_backtrace(bt,eid)+(data ? "<hr noshade><pre>"+data+"</pre>" : ""), this_object() ) ) ) {
    report_error("*** http_error object missing during internal_error() ***\n");
    file =
      Caudium.HTTP.low_answer( 500, "<h1>Error: The server failed to fulfill your query due to an " +
		       "internal error in the internal error routine.</h1>" );
  }
  return file;
}


// The wrapper for multiple ranges (send a multipart/byteranges reply).
#define BOUND "Byte_Me_Now_Caudium"

class MultiRangeWrapper
{
  object file;
  function rcb;
  int current_pos, len, separator, is_single_range;
  array ranges;
  array range_info = ({});
  string type;
  string stored_data = "";
  void create(mapping _file, mapping heads, array _ranges, object id)
  {
    //    werror("MultiRangeWrapper\n");
    file = _file->file;
    len = _file->len;
    ranges = _ranges;
    int clen;
    if(sizeof(ranges) == 1) {
      is_single_range = 1;
      clen = 1+ ranges[0][1] - ranges[0][0];
      range_info = ({ ({ clen }) });
    } else {
      foreach(indices(heads), string h)
      {
        if(lower_case(h) == "content-type") {
          type = heads[h];
          m_delete(heads, h);
        }
      }
      if(id->request_headers["request-range"])
        heads["Content-Type"] = "multipart/x-byteranges; boundary=" BOUND;
      else
        heads["Content-Type"] = "multipart/byteranges; boundary=" BOUND;
      foreach(ranges, array range) {
        int rlen = 1+ range[1] - range[0];
        string sep =  sprintf("\r\n--" BOUND "\r\nContent-Type: %O\r\n"
                              "Content-Range: bytes %d-%d/%d\r\n\r\n",
                              type, @range, len);
        clen += rlen + strlen(sep);
        range_info += ({ ({ rlen, sep }) });
      }
      clen += strlen(BOUND) + 8; // End boundary length.
    }
    _file->len = clen;
    //    werror("Create finished.\n");
  }

  string read(mixed ... args)
  {
    string out = stored_data;
    stored_data = "";
    int rlen, num_bytes, total;
    if(sizeof(args))
      num_bytes = args[0];
    else
      num_bytes = 0xeffffff;
    //    werror(sprintf("Want to read %d bytes\n", num_bytes));
    total = num_bytes;
    num_bytes -= strlen(out);
    foreach(ranges, array range)
    {
      rlen = range_info[0][0] - current_pos;
      if(separator != 1) {
	// New range, write new separator.
	//	werror(sprintf("Initiating new range %d -> %d.\n", @range));
	if(!is_single_range) {
	  out += range_info[0][1];
	  num_bytes -= strlen(range_info[0][1]);
	}
	file->seek(range[0]);
	separator = 1;
      }
      if(num_bytes > 0) {
	if(rlen <= num_bytes)
	  // Entire range fits.
	{
	  out += file->read(rlen);
	  num_bytes -= rlen;
	  current_pos = separator = 0;
	  ranges = ranges[1..]; // One range done.
	  range_info = range_info[1..];
	  //	  werror("Entire range added.\n");
	} else {
	  out += file->read(num_bytes);
	  current_pos += num_bytes;
	  num_bytes = 0;
	}
      }
      if(num_bytes <= 0)
	break; // Return data
    }
    if(!sizeof(ranges) && !is_single_range && separator != 2) {
      // End boundary. Only write once.
      separator = 2;
      out += "\r\n--" BOUND "--\r\n";
      //      werror("Adding end of multipart\n");
    }  
    if(strlen(out) > total)
    {
      // Oops. too much data again. Write and store. Write and store.
      stored_data = out[total..];
      //      werror(sprintf("Returning partial %d of %d.\n",
      //		     strlen(out[..total-1]), strlen(out)));
      return out[..total-1];
    }
    //    werror(sprintf("Returning last %d bytes.\n", strlen(out[..total-1])));
    return out ; // We are finally done.
  }
  
  mixed `->(string what) {
    //    werror("Call for %s\n", what);
    switch(what) {
     case "read":
      return read;
     case "set_nonblocking":
      return 0;
     case "query_fd":
      return lambda() { return 0; };
     default:
      return file[what];
    }
  }
}


// Parse the range header itno multiple ranges.
array parse_range_header(int len)
{
  array ranges = ({});
  foreach(misc->range / ",", string range)
  {
    int r1, r2;
    if(range[0] == '-' ) {
      // End of file request
      r1 = (len - (int)range[1..]);
      if(r1 < 0) {
	// Entire file requested here. 
	r1 = 0;
      }
      ranges += ({ ({ len - (int)range[1..], len-1 }) }); 
    } else if(range[-1] == '-') {
      // Rest of file request
      r1 = (int)range;
      if(r1 >= len)
	// Range beginning is after EOF.
	continue; 
      ranges += ({ ({ r1, len-1 }) });
    } else if(sscanf(range, "%d-%d", r1, r2)==2) {
      // Standard range
      if(r1 <= r2) {
	if(r1 >= len)
	  // Range beginning is after EOF.
	  continue;
	ranges += ({ ({ r1, r2 < len ? r2 : len -1  }) });
      }
      else 
	// A syntatically incorrect range should make the server
	// ignore the header. Really.
	return 0;
    } else
      // Invalid syntax again...
      return 0; 
  }
  return ranges;
}

static string make_content_type(object conf, mapping file)
{
  string     type, charset = 0;

  if (!file || !mappingp(file))
    return "text/plain; charset=" + content_charset;
  
  type = file["type"];

  if (!type || sizeof(type) < 5 || type[0..4] != "text/")
    return type;
  
  if (file->charset)
    charset = file->charset;
  else if (conf && objectp(conf)) {
    if (conf->query("set_default_charset"))
      charset = conf->query("content_charset");
  } else
    charset = content_charset;

  if (charset)
    return type + "; charset=" + charset;
  else
    return type;
}

//! Send the result.
//!
//! @param result
//!  The result mapping
void send_result(mapping|void result)
{
  array err;
  int tmp;
  mapping heads;
  string head_string;

  MARK_FD(sprintf("send_result(%O)",result));

  if (result) {
    file = result;
  }
  if(!mappingp(file))
  {
    // There is no file so calling error
    mixed tmperr;
    tmperr = conf->handle_error_request(this_object());
    if(mappingp(tmperr)) 
      file = (mapping)tmperr;
    else {  // Fallback error handler.
      if(misc->error_code)
        file = Caudium.HTTP.low_answer(misc->error_code, errors[misc->error]);
      else if(method != "GET" && method != "HEAD" && method != "POST")
        file = Caudium.HTTP.low_answer(501,"Not implemented.");
      else 
        file = Caudium.HTTP.low_answer(404,"Not found.");
    }
  } else {
    if((file->file == -1) || file->leave_me) 
    {
      if(do_not_disconnect) {
        file = pipe = 0;
        return;
      }
      my_fd = file = 0;
      return;
    }

    if(file->type == "raw")
      file->raw = 1;
    else if(!file->type)
      file->type="text/plain";
  }

  if(!file->raw)
  {
    heads = ([]);
    if(!file->len)
    {
      array|object fstat;
      if(objectp(file->file))
        if(!file->stat && !(file->stat=misc->stat))
          file->stat = (array(int))file->file->stat();
      
      //
      // I think it's the highest time to decide on which pike we support...
      // I vote for 7.2 onwards only
      // /grendel
      //
      fstat = file->stat;
      if(arrayp(fstat) || objectp(fstat))
      {
        int fsize, fmtime;
	
        if (objectp(fstat)) {
          fsize = fstat->size;
          fmtime = fstat->mtime;
        } else {
          fsize = fstat[1];
          fmtime = fstat[3];
        }
	
        if(file->file && !file->len)
          file->len = fsize;

        if(!file->is_dynamic && !misc->is_dynamic) {
#ifdef SUPPORT_HTTP_09
          if(prot != "HTTP/0.9") {
#endif
            heads["Last-Modified"] = Caudium.HTTP.date(fmtime);
            if(since)
            {
              if(is_modified(since, fmtime, fsize))
              {
                file->error = 304;
                file->file = 0;
                file->data="";
                // 	    method="";
              }
            }
#ifdef SUPPORT_HTTP_09
          }
#endif
        } 
      }
      if(stringp(file->data)) 
        file->len += strlen(file->data);
    }

    //
    // Currently cache control is considered only when file is not raw
    // Shouldn't we move the below block out of the !file->raw conditional?
    // /grendel
    //
    if(file->is_dynamic && misc->is_dynamic)
    {
	  /* Do not cache! */
	  /* 
	   * Cache-Control is valid only with HTTP 1.1+
	   */
	  if (cache_control_ok)
	    heads["Cache-Control"] = "no-cache, no-store, max-age=0, private, must-revalidate, proxy-revalidate";
	  heads["Expires"] = "0";
	  
	  // The below is only for HTTP 1.0 - should we test whether the
	  // current request proto is 1.0 and set the header only then? /grendel
	  heads["pragma"] = "no-cache";
    }
    
#ifdef SUPPORT_HTTP_09
    if(prot != "HTTP/0.9")
    {
#endif
      string h;
      heads +=
        (["MIME-Version":(file["mime-version"] || "1.0"),
          "Content-Type": make_content_type(conf, file),
          "Accept-Ranges": "bytes",
#ifdef KEEP_ALIVE
          "Connection": (request_headers->connection == "close" ? "close": "Keep-Alive"),
#else
          "Connection"	: "close",
#endif
          "Server":version(),
          "X-Got-Fish": (caudium->query("identpikever") ? fish_version : "Yes"),	
          "Date":Caudium.HTTP.date(time)
        ]);    
      
      if(file->encoding)
        heads["Content-Encoding"] = file->encoding;
    
      if(!file->error) 
        file->error = 200;

      // expires == 0 is a valid value - it can serve to invalidate
      // the browser's (or Squid) cache because an invalid date
      // in that header should cause immediate expire of the page.
      if(!zero_type(file->expires))
        heads->Expires = file->expires ? Caudium.HTTP.date(file->expires) : "0";
    
      if(mappingp(file->extra_heads)) {
        heads |= file->extra_heads;
      }

      if(mappingp(misc->moreheads)) {
        heads |= misc->moreheads;
      }

      if(misc->range && file->len && objectp(file->file) && !file->data &&
         file->error == 200 && (method == "GET" || method == "HEAD"))
        // Plain and simple file and a Range header. Let's play.
        // Also we only bother with 200-requests. Anything else should be
        // nicely and completely ignored. Also this is only used for GET and
        // HEAD requests.
      {
        // split the range header. If no valid ranges are found, ignore it.
        // If one is found, send that range. If many are found we need to
        // use a wrapper and send a multi-part message. 
        array ranges = parse_range_header(file->len);
        if(ranges) // No incorrect syntax...
        { 
          if(sizeof(ranges)) // And we have valid ranges as well.
          {
            file->error = 206; // 206 Partial Content
            if(sizeof(ranges) == 1)
            {
              heads["Content-Range"] = sprintf("bytes %d-%d/%d",
                                               @ranges[0], file->len);
              if(ranges[0][1] == (file->len - 1) &&
                 GLOBVAR(RestoreConnLogFull))
                // Log continuations (ie REST in FTP), 'range XXX-'
                // using the entire length of the file, not just the
                // "sent" part. Ie add the "start" byte location when logging
                misc->_log_cheat_addition = ranges[0][0];
              file->file = MultiRangeWrapper(file, heads, ranges, this_object());
            } else {
              // Multiple ranges. Multipart reply and stuff needed.
              // We do this by replacing the file object with a wrapper.
              // Nice and handy.
              file->file = MultiRangeWrapper(file, heads, ranges, this_object());
            }
          } else {
            // Got the header, but the specified ranges was out of bounds.
            // Reply with a 416 Requested Range not satisfiable.
            file->error = 416;
            heads["Content-Range"] = "*/"+file->len;
            if(method == "GET") {
              file->data = "The requested byte range is out-of-bounds. Sorry.";
              file->len = strlen(file->data);
              file->file = 0;
            }
          }
        }
      }
      head_string = prot+" "+(file->rettext||errors[file->error]) + "\r\n";

      head_string = prot+" "+(file->rettext||errors[file->error]) + "\r\n";
      if(file->len > -1) {
        heads["Content-Length"] = (string)file->len;
#ifdef KEEP_ALIVE
        if(!file->len) {
          request_headers->connection = heads->Connection = "close";
        }
#endif
      }
#ifdef KEEP_ALIVE
      else request_headers->connection = heads->Connection = "close";
#endif

      head_string += _Roxen.make_http_headers(heads);
      if(conf) conf->hsent+=strlen(head_string||"");
#ifdef SUPPORT_HTTP_09
    }
#endif
  }
#ifdef REQUEST_DEBUG
  roxen_perror(sprintf("Sending result for prot:%O, method:%O file:%O\n",
                       prot, method, file));
#endif /* REQUEST_DEBUG */

  if(method == "HEAD")
  {
    file->file = 0;
    file->data="";
  }
  MARK_FD("HTTP handled");


#ifdef KEEP_ALIVE
  if(!leftovers) leftovers = data||"";
#endif

  if(file->len >= 0 && file->len < 2000)
  {
    my_fd->write((head_string || "") +
                 (file->file?file->file->read():file->data));
    do_log();
    return;
  }

  if(head_string) send(head_string);

  if(method != "HEAD" && file->error != 304)
    // No data for these two...
  {
    if(file->data && strlen(file->data))
      send(file->data, file->len);
    if(file->file)  
      send(file->file, file->len);
  } else
    file->len = 1; // Keep those alive, please...
  if (pipe) {
    MARK_FD("HTTP really handled, piping "+not_query);
    //  The timer function keeps track of the data sending. If no data
    //  has been sent for 360 seconds, the connection is closed.
    //  It seems like sometimes, when using poll() at least, Pike doesn't
    //  detect that the remote end closed which w/o this function would
    //  leave stale sockets.
    call_out(timer, 60, _time(1), 0, 0);
    pipe->set_done_callback( do_log );
    pipe->output(my_fd);
  } else {
    MARK_FD("HTTP really handled, pipe done");
    do_log();
  }
}

void handle_magic_error()
{
  function funp;
  mixed     err;

  if(prestate->old_error)
  {
    err = get_error(variables->error);
    if(err)
    {
      if(prestate->plain)
      {
	file = ([
	  "type":"text/html",
	  "data":generate_bugreport( @err ),
	]);
      } else {
	
	if(prestate->find_file)
        {
	  if(!realauth)
	    file = http_auth_required("admin");
	  else
	  {
	    array auth = (realauth+":")/":";
	    if((auth[0] != caudium->query("ConfigurationUser"))
	       || !crypt(auth[1], caudium->query("ConfigurationPassword")))
	      file = http_auth_required("admin");
	    else
	      file = handle_error_file_request( err[0],  (int)variables->error );
	  }
	}
      }
    }
  }
}

//! Handle the request
void handle_request( )
{
  mixed err;

#ifdef MAGIC_ERROR
  handle_magic_error();
#endif /* MAGIC_ERROR */

  MARK_FD("handle_request() is called.");

  remove_call_out(do_timeout);
  MARK_FD("HTTP handling request");
  if(!file) {
    MARK_FD("handle_request(): file is not here");
    if(conf) {
      MARK_FD("handle_request(): conf is here");
      if(err= catch(file = conf->handle_request( this_object() ))) {
        MARK_FD("handle_request(): internal error to be called.");
	INTERNAL_ERROR( err );  
        }
    } else {
      MARK_FD("handle_request(): conf is not here");
      if((err=catch(file = caudium->configuration_parse( this_object() )))) {
        if(err == -1) return;
        INTERNAL_ERROR(err);
      }
    }
  }  
  send_result();
}

/* We got some data on a socket.
 * ================================================= 
 */
int processed;
void got_data(mixed fdid, string s)
{

  int tmp;
  MARK_FD("HTTP got data");
  remove_call_out(do_timeout);
  call_out(do_timeout, 30); // Close down if we don't get more data 
                         // within 30 seconds. Should be more than enough.
  time = _time(1); // Check is made towards this to make sure the object
  		  // is not killed prematurely.
  // if data is ingored dont store it in raw - its body data from
  // the last request...
  int read_data = strlen(s);
  if ( unread_data > 0 ) {
    REQUEST_WERR("Ignoring " + unread_data + " bytes...");
    if ( read_data > unread_data ) {
      s = s[unread_data..];
      unread_data = 0;
    }
    else {
      unread_data -= read_data; 
      return;
    }
  }
  raw += s;
  if( wanted_data > 0 && strlen(raw) < wanted_data) 
    return;
 
  
  if(strlen(raw))
    tmp = parse_got();

  switch(tmp)
  { 
   case 0:
    // More on the way.
    return;
    
   case 1:
    end(prot+" 500 Stupid Client Error\r\nContent-Length: 0\r\n\r\n");
    return;			// Stupid request.
    
   case 2:
    end();
    return;
  }
   
  if(conf)
  {
    conf->received += strlen(s);
    conf->requests++;
  }

  my_fd->set_close_callback(0); 
  my_fd->set_read_callback(0); 
  processed=1;
  /* Call the precache modules, which include virtual hosting
   * and other modules which might not be relevant to http like
   * cache key generator modules for http2...
   */
  if(conf)  conf->handle_precache(this_object());
#ifdef THREADS
  caudium->handle(handle_request);
#else
  handle_request();
#endif
}

/* Get a somewhat identical copy of this object, used when doing 
 * 'simulated' requests. */

object clone_me()
{
  object c,t;
  c = object_program(t = this_object())(0, 0);

  // c->first = first;
  c->conf = conf;
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
  c->realauth = realauth;
  c->rawauth = rawauth;
  c->since = since;
  return c;
}

void clean()
{
  if(!(my_fd && objectp(my_fd)))
    end();
  else if((_time(1) - time) > 4800) 
    end();
}

void create(void|object f, void|object c)
{
  if(f)
  {
    ::create(f,c);
    f->set_nonblocking(got_data, 0, end);
    // No need to wait more than 30 seconds to get more data.
    call_out(do_timeout, 30);
    time = _time(1);
    remoteaddr = Caudium.get_address(my_fd->query_address()||"");
    MARK_FD("HTTP connection");
  }
  unread_data = 0;
}

void chain(object f, object c, string le)
{
  my_fd = f;
  conf = c;
  do_not_disconnect=-1;
  MARK_FD("Kept alive");
  if(strlen(le))
    // More to handle already.
    got_data(0,le);
  else
  {
    // If no pipelined data is available, call out...
    call_out(do_timeout, 150);
    time = _time(1);
  }

  if(!my_fd)
  {
    if(do_not_disconnect == -1)
    {
      do_not_disconnect=0;
      disconnect();
    }
  } else {
    if(do_not_disconnect == -1) 
      do_not_disconnect = 0;
    if(!processed) {
      f->set_close_callback(end);
      f->set_read_callback(got_data);
    }
  }
}

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
