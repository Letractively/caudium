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

#define MAGIC_ERROR

#ifdef MAGIC_ERROR
inherit "highlight_pike";
#endif
constant cvs_version = "$Id$";
// HTTP protocol module.
#include <config.h>
private inherit "caudiumlib";
// int first;
#if efun(gethrtime)
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

constant decode        = MIME.decode_base64;
constant find_supports = caudium->find_supports;
constant version       = caudium->version;
constant handle        = caudium->handle;
constant _query        = caudium->query;
constant thepipe       = caudium->pipe;
constant _time         = predef::time;

private static int wanted_data, have_data;

object conf;

#include <caudium.h>
#include <module.h>

#undef QUERY
#if constant(cpp)
#define QUERY(X)	_query( #X )
#else /* !constant(cpp) */
#define QUERY(X) 	_query("X")
#endif /* constant(cpp) */

int time;
string raw_url;
int do_not_disconnect;
mapping (string:string) variables       = ([ ]);
mapping (string:mixed)  misc            = ([ ]);
mapping (string:string) cookies         = ([ ]);
mapping (string:string) request_headers = ([ ]);

multiset (string) prestate  = (< >);
multiset (string) config    = (< >);
multiset (string) supports  = (< >);
multiset (string) pragma    = (< >);

string remoteaddr, host;

#ifdef EXTRA_ROXEN_COMPAT
array  (string) client = ({"unknown"});
array  (string) referer;
#endif

string referrer;
string useragent = "unknown";


mapping file;

object my_fd; /* The client. */
object pipe;

// string range;
string prot;
string clientprot;
string method;

string realfile, virtfile;
string rest_query="";
string raw=""; // Raw request
string query;
string not_query;
string extra_extension = ""; // special hack for the language module
string data, leftovers;
array (int|string) auth;
string rawauth, realauth;
string since;

// Parse a HTTP/1.1 HTTP/1.0 or 0.9 request, including form data and
// state variables.  Return 0 if more is expected, 1 if done, and -1
// if fatal error.

void end(string|void a,int|void b);

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

  if(!remoteaddr)
  {
    if(my_fd) sscanf(my_fd->query_address()||"", "%s ", remoteaddr);
    if(!remoteaddr) {
      end();
      return 0;
    }
  }

  if(sscanf(f,"%s?%s", f, query) == 2)
    Caudium.parse_query_string(query, variables);
  
  REQUEST_WERR(sprintf("After query scan:%O", f));

  f = http_decode_string( f );

  /* Fix %00 (NULL) bug */
  sscanf( f, "%s\0", f );
  if (sscanf(f, "/<%s>/%s", a, f)==2)
  {
    config_in_url = 1;
    mod_config = (a/",");
    f = "/"+f;
  }

  REQUEST_WERR(sprintf("After cookie scan:%O", f));
  
  if ((sscanf(f, "/(%s)/%s", a, f)==2) && strlen(a))
  {
    prestate = aggregate_multiset(@(a/","-({""})));
    f = "/"+f;
  }

  REQUEST_WERR(sprintf("After prestate scan:%O", f));

  not_query = simplify_path(f);

  REQUEST_WERR(sprintf("After simplify_path == not_query:%O", not_query));

  if(sizeof(s)) {
#if constant(Caudium.parse_headers)
    request_headers = Caudium.parse_headers(s);
    foreach(indices(request_headers), string linename) {
      switch(linename) {
       case "content-length":
	misc->len = (int)(request_headers[linename]-" ");
	if(!misc->len) continue;
	if(method == "POST")
	{
	  if(!data) data="";
	  int l = misc->len;
	  wanted_data=l;
	  have_data=strlen(data);

	  if(strlen(data) < l)
	  {
	    REQUEST_WERR("HTTP: parse_request(): More data needed in POST.");
	    return 0;
	  }
	  leftovers = data[l..];
	  data = data[..l-1];
	  switch(lower_case((((request_headers["content-type"]||"")+";")/";")[0]-" "))
	  {
	   default: // Normal form data.
	    string v;
	    if(l < 200000)
	      Caudium.parse_query_string(replace(data, ({ "\n", "\r"}),
						 ({"", ""})), variables);
	    break;

	   case "multipart/form-data":
	    //		perror("Multipart/form-data post detected\n");
	    object messg = MIME.Message(data, request_headers);
	    foreach(messg->body_parts, object part) {
	      if(part->disp_params->filename) {
		variables[part->disp_params->name]=part->getdata();
		variables[part->disp_params->name+".filename"]=
		  part->disp_params->filename;
		if(!misc->files)
		  misc->files = ({ part->disp_params->name });
		else
		  misc->files += ({ part->disp_params->name });
	      } else {
		if(variables[part->disp_params->name])
		  variables[part->disp_params->name] += "\0" + part->getdata();
		else
		  variables[part->disp_params->name] = part->getdata();
	      }
	    }
	    break;
	  }
	}
	break;
	  
       case "authorization":
	array(string) y;
	rawauth = request_headers[linename];
	y = rawauth / " ";
	if(sizeof(y) < 2) break;
	y[1]     = decode(y[1]);
	realauth = y[1];
	if(conf && conf->auth_module)
	  y = conf->auth_module->auth( y, this_object() );
	auth = y;
	break;
	  
       case "proxy-authorization":
	array(string) y;
	y = request_headers[linename] / " ";
	if(sizeof(y) < 2)
	  break;
	y[1] = decode(y[1]);
	if(conf && conf->auth_module)
	  y = conf->auth_module->auth( y, this_object() );
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
	misc[linename] = lower_case(request_headers[linename]);
#endif
	break;

       case "accept-encoding":
	foreach((request_headers[linename]-" ")/",", string e) {
	  if (lower_case(e) == "gzip") {
	    supports["autogunzip"] = 1;
	  }
	}
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
	    value=http_decode_string(value);
	    name=http_decode_string(name);
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
    // premature call_out... *¤#!"
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
    id = f->read(200);
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

string link_to(string what, int eid, int qq)
{
  int line;
  string file, fun;
  sscanf(what, "%s(%*s in line %d in %s", fun, line, file);
  if(file && fun && line)
  {
    sscanf(file, "%s (", file);
    if(file[0]!='/') file = combine_path(getcwd(), file);
//     werror("link to the function "+fun+" in the file "+
// 	   file+" line "+line+"\n");
    return ("<a href=\"/(old_error,find_file)/error?"+
	    "file="+http_encode_string(file)+"&"
	    "fun="+http_encode_string(fun)+"&"
	    "off="+qq+"&"
	    "error="+eid+"&"
	    "line="+line+"#here\">");
  }
  return "<a>";
}


string format_backtrace(array bt, int eid)
{
  // first entry is always the error, 
  // second is the actual function, 
  // rest is backtrace.

  string reason = caudium->diagnose_error( bt );
  if(sizeof(bt) == 1) // No backtrace?!
    bt += ({ "Unknown error, no backtrace."});
  string res = ("<title>Internal Server Error</title>"
		"<body bgcolor=white text=black link=darkblue vlink=darkblue>"
		"<table width=\"100%\" border=0 cellpadding=0 cellspacing=0>"
		"<tr><td valign=bottom align=left><img border=0 "
		"src=\""+(conf?"/internal-caudium-":"/img/")+
		"caudium-icon-gray.gif\" alt=\"\"></td>"
		"<td>&nbsp;</td><td width=100% height=39>"
		"<table cellpadding=0 cellspacing=0 width=100% border=0>"
		"<td width=\"100%\" align=right valigh=center height=28>"
		"<b><font size=+1>Failed to complete your request</font>"
		"</b></td></tr><tr width=\"100%\"><td bgcolor=\"#003366\" "
		"align=right height=12 width=\"100%\"><font color=white "
		"size=-2>Internal Server Error&nbsp;&nbsp;</font></td>"
		"</tr></table></td></tr></table>"
		"<p>\n\n"
		"<font size=+2 color=darkred>"
		"<img alt=\"\" hspace=10 align=left src="+
		(conf?"/internal-caudium-":"/img/") +"manual-warning.gif>"
		+bt[0]+"</font><br>\n"
		"The error occured while calling <b>"+bt[1]+"</b><p>\n"
		+(reason?reason+"<p>":"")
		+"<br><h3><br>Complete Backtrace:</h3>\n\n<ol>");

  int q = sizeof(bt)-1;
  foreach(bt[1..], string line)
  {
    string fun, args, where, fo;
    if((sscanf(html_encode_string(line), "%s(%s) in %s",
	       fun, args, where) == 3) &&
       (sscanf(where, "%*s in %s", fo) && fo)) {
      line += get_id( fo );
      res += ("<li value="+(q--)+"> "+
	      (replace(line, fo, link_to(line,eid,sizeof(bt)-q-1)+fo+"</a>")
	       -(getcwd()+"/"))+"<p>\n");
    } else {
      res += "<li value="+(q--)+"> <b><font color=darkgreen>"+
	line+"</font></b><p>\n";
    }
  }
  res += ("</ul><p><b><a href=\"/(old_error,plain)/error?error="+eid+"\">"
	  "Generate text-only version of this error message, for bug reports"+
	  "</a></b>");
  return res+"</body>";
}

string generate_bugreport(array from, string u, string rd)
{
  add_id(from);
  return ("<pre>"+html_encode_string("Caudium version: "+version()+
	  (caudium->real_version != version()?
	   " ("+caudium->real_version+")":"")+
	  "\nRequested URL: "+u+"\n"
	  "\nError: "+
	  describe_backtrace(from)-(getcwd()+"/")+
	  "\n\nDate: "+http_date(predef::time())+			     
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
  array err2;
  if(QUERY(show_internals)) 
  {
    err2 = catch { 
      array(string) bt = (describe_backtrace(err)/"\n") - ({""});
      file = http_low_answer(500, format_backtrace(bt, store_error(err)));
    };	
    if(err2) {
      werror("Internal server error in internal_error():\n" +
	     describe_backtrace(err2)+"\n while processing \n"+
	     describe_backtrace(err));
      file = http_low_answer(500, "<h1>Error: The server failed to "
			     "fulfill your query, due to an "
			     "internal error in the internal error routine.</h1>");
    }
  } else {
    file = http_low_answer(500, "<h1>Error: The server failed to "
			   "fulfill your query, due to an internal error.</h1>");
  }
  report_error("Internal server error: " +
	       describe_backtrace(err) + "\n");
}

constant errors =
([
  200:"200 OK",
  201:"201 URI follows",
  202:"202 Accepted",
  203:"203 Provisional Information",
  204:"204 No Content",
  206:"206 Partial Content", // Byte ranges
  
  300:"300 Moved",
  301:"301 Permanent Relocation",
  302:"302 Temporary Relocation",
  303:"303 Temporary Relocation method and URI",
  304:"304 Not Modified",

  400:"400 Bad Request",
  401:"401 Access denied",
  402:"402 Payment Required",
  403:"403 Forbidden",
  404:"404 No such file or directory.",
  405:"405 Method not allowed",
  407:"407 Proxy authorization needed",
  408:"408 Request timeout",
  409:"409 Conflict",
  410:"410 This document is no more. It has gone to meet it's creator. It is gone. It will not be coming back. Give up. I promise. There is no such file or directory.",
  416:"416 Requested range not satisfiable",
  
  500:"500 Internal Server Error.",
  501:"501 Not Implemented",
  502:"502 Gateway Timeout",
  503:"503 Service unavailable",
  
  ]);


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

#ifdef FD_DEBUG
void timer(int start)
{
  if(pipe) {
    // FIXME: Disconnect if no data has been sent for a long while
    //   (30min?)
    MARK_FD(sprintf("HTTP_piping_%d_%d_%d_%d_(%s)",
		    pipe->sent,
		    stringp(pipe->current_input) ?
		    strlen(pipe->current_input) : -1,
		    pipe->last_called,
		    _time(1) - start, 
		    not_query));
  } else {
    MARK_FD("HTTP piping, but no pipe for "+not_query);
  }
  call_out(timer, 30, start);
}
#endif

string handle_error_file_request(array err, int eid)
{
//   return "file request for "+variables->file+"; line="+variables->line;
  string data = Stdio.read_bytes(variables->file);
  array(string) bt = (describe_backtrace(err)/"\n") - ({""});
  string down;

  if((int)variables->off-1 >= 1)
    down = link_to( bt[(int)variables->off-1],eid, (int)variables->off-1);
  else
    down = "<a>";
  if(data)
  {
    int off = 49;
    array (string) lines = data/"\n";
    int start = (int)variables->line-50;
    if(start < 0)
    {
      off += start;
      start = 0;
    }
    int end = (int)variables->line+50;
    lines=highlight_pike("foo", ([ "nopre":1 ]), lines[start..end]*"\n")/"\n";

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
      lines[off]=("<font size=+2><b>"+down+lines[off]+"</a></b></font></a>");
    lines[max(off-20,0)] = "<a name=here>"+lines[max(off-20,0)]+"</a>";
    data = lines*"\n";
  }
  
  return format_backtrace(bt,eid)+"<hr noshade><pre>"+data+"</pre>";
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

// Send the result.
void send_result(mapping|void result)
{
  array err;
  int tmp;
  mapping heads;
  string head_string;

  if (result) {
    file = result;
  }

  if(!mappingp(file))
  {
    if(misc->error_code)
      file = http_low_answer(misc->error_code, errors[misc->error]);
    else if(method != "GET" && method != "HEAD" && method != "POST")
      file = http_low_answer(501, "Not implemented.");
    else if(err = catch {
      file=http_low_answer(404,
			   replace(parse_rxml(conf->query("ZNoSuchFile"),
					      this_object()),
				   ({"$File", "$Me"}), 
				   ({html_encode_string(not_query),
				     conf->query("MyWorldLocation")})));
    }) {
      INTERNAL_ERROR(err);
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

    if(file->type == "raw")  file->raw = 1;
    else if(!file->type)     file->type="text/plain";
  }
  
  if(!file->raw)
  {
    heads = ([]);
    if(!file->len)
    {
      array fstat;
      if(objectp(file->file))
	if(!file->stat && !(file->stat=misc->stat))
	  file->stat = (int *)file->file->stat();
      if(arrayp(fstat = file->stat))
      {
	if(file->file && !file->len)
	  file->len = fstat[1];
    	
	if(!file->is_dynamic
#ifdef SUPPORT_HTTP_09
	   && prot != "HTTP/0.9"
#endif
	   )
	{
	  heads["Last-Modified"] = http_date(fstat[3]);
	  if(since)
	  {
	    if(is_modified(since, fstat[3], fstat[1]))
	    {
	      file->error = 304;
	      file->file = 0;
	      file->data="";
	      // 	    method="";
	    }
	  }
	}
      }
      if(stringp(file->data)) 
	file->len += strlen(file->data);
    }

#ifdef SUPPORT_HTTP_09
    if(prot != "HTTP/0.9")
    {
#endif
      string h;
      heads +=
      (["MIME-Version":(file["mime-version"] || "1.0"),
	"Content-type":file["type"],
	"Accept-Ranges": "bytes",
#ifdef KEEP_ALIVE
	"Connection": (request_headers->connection == "close" ? "close": "Keep-Alive"),
#else
	"Connection"	: "close",
#endif
	"Server":version(),
	"X-Got-Fish": fish_version,
	"Date":http_date(time) ]);    

      if(file->encoding)
	heads["Content-Encoding"] = file->encoding;
    
      if(!file->error) 
	file->error = 200;
    
      if(file->expires)
	heads->Expires = http_date(file->expires);
    
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

#if constant(_Roxen.make_http_headers)
      head_string += _Roxen.make_http_headers(heads);
#else
      foreach(indices(heads), h)
	if(arrayp(heads[h]))
	  foreach(heads[h], tmp)
	    head_string +=  h+": "+tmp+"\r\n";
	else
	  head_string += h+": "+heads[h]+"\r\n";
      head_string += "\r\n";
#endif
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

  if(file->len > 0 && file->len < 2000)
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
#ifdef FD_DEBUG
    call_out(timer, 30, _time(1)); // Update FD with time...
#endif
    pipe->set_done_callback( do_log );
    pipe->output(my_fd);
  } else {
    MARK_FD("HTTP really handled, pipe done");
    do_log();
  }
}


// Execute the request
void handle_request( )
{
  mixed err;
  function funp;

#ifdef MAGIC_ERROR
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
	      file = ([
		"type":"text/html",
		"data":handle_error_file_request( err[0], 
						  (int)variables->error ),
	      ]);
	  }
	}
      }
    }
  }
#endif /* MAGIC_ERROR */


  remove_call_out(do_timeout);
  MARK_FD("HTTP handling request");
  if(!file) {
    if(conf) {
      if(err= catch(file = conf->handle_request( this_object() )))
	INTERNAL_ERROR( err );  
    } else if((err=catch(file = caudium->configuration_parse( this_object() )))) {
      if(err == -1) return;
      INTERNAL_ERROR(err);
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
  raw += s;
  if(wanted_data && strlen(raw) < wanted_data)
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
#ifdef THREADS
  handle(handle_request);
#else
  handle_request();
#endif
}

/* Get a somewhat identical copy of this object, used when doing 
 * 'simulated' requests. */

object clone_me()
{
  object c,t;
  c = object_program(t = this_object())(my_fd, conf);

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

void create(object f, object c)
{
  if(f)
  {
    f->set_nonblocking();
    my_fd = f;
    conf = c;
    MARK_FD("HTTP connection");
    my_fd->set_close_callback(end);
    my_fd->set_read_callback(got_data);
    // No need to wait more than 30 seconds to get more data.
    call_out(do_timeout, 30);
    time = _time(1);
  }
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
