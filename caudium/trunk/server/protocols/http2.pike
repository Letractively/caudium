/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
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


/* If defined, write files smaller than this define directly to
 * the output fd instead of using the data shuffler.
 */
#define DIRECT_WRITE 4000

#define MAGIC_ERROR

#ifdef MAGIC_ERROR
inherit "highlight_pike";
#endif
constant cvs_version = "$Id$";
// HTTP protocol module.
#include <config.h>
private inherit "caudiumlib";
private inherit "cachelib";
// int first;

#ifdef DO_TIMER
static int global_timer, global_total_timer;
#  define ITIMER()  write("\n\n\n");global_total_timer = global_timer = gethrtime();
#  define TIMER(X) do {int x=gethrtime()-global_timer; \
                       int y=gethrtime()-global_total_timer; \
                       write( "%20s ... %1.1fms / %1.1fms\n",X,x/1000.0,y/1000.0 );\
                       global_timer = gethrtime(); } while(0);
#else
#  define ITIMER()
#  define TIMER(X)
#endif

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
constant _query        = caudium->query;
constant thepipe       = caudium->pipe;
constant _time         = predef::time;

object conf;

#include <caudium.h>
#include <module.h>

#undef QUERY

#define QUERY(X)  _query( #X )

int time;
string raw_url;
int do_not_disconnect;
mapping (string:string) variables       = ([ ]);
mapping (string:mixed)  misc            = ([ ]);
mapping (string:string) cookies         = ([ ]);
mapping (string:string) request_headers = ([ ]);

multiset (string) prestate  = (< >);
multiset (string) internal  = (< >);
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

private int cache_control_ok = 0;

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

/* Not used internally, but used by external files */
string scan_for_query( string f )
{
  if(sscanf(f,"%s?%s", f, query) == 2)
    Caudium.parse_query_string(query, variables);
  return f;
}

private mixed f;
/* Processing here not needed for cached connections. It mainly
 * includes various URL processing and variable scanning.
 */
inline void do_post_processing()
{
  multiset (string) sup;
  array mod_config;
  string a, b, linename, contents, s;
  int config_in_url;
  if(processed) return;
  if(misc->len && method == "POST") {
    REQUEST_WERR(sprintf("Process post data (want %d, got %d): %O",
			 misc->len, strlen(data), data));
    int l = misc->len;
    if(strlen(data) < l) return;
    leftovers = data[l..];
    data = data[..l-1];

    mapping tmp = ([]);
    if(request_headers["content-type"]) {
      // handle post data
      switch((lower_case(request_headers["content-type"])/";")[0]-" ")
      {
       case "application/x-www-form-urlencoded": // Normal form data.
	string v;
	if(l < 200000) {
	  Caudium.parse_query_string(replace(data, ({ "\n", "\r"}),
					     ({"", ""})), variables);
	}
	break;

       case "multipart/form-data":
	//		perror("Multipart/form-data post detected\n");
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
	  } else {
	    if(variables[part->disp_params->name])
	      variables[part->disp_params->name] += "\0" + part->getdata();
	    else
	      variables[part->disp_params->name] = part->getdata();
	  }
	}
	break;
       default:
	REQUEST_WERR("Unknown POST content type: "+
		     request_headers["content-type"]);	
      }
    }
  }
#ifdef KEEP_ALIVE
  else
    leftovers = data;
#endif
  if(query)
      Caudium.parse_query_string(query, variables);
  REQUEST_WERR(sprintf("After query scan:%O", f));

#if 0
  // FIXME: This should be done in C
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
  /*
#ifdef ENABLE_SUPPORTS    
  if(useragent == "unknown") {
    supports = find_supports("", supports); // This makes it somewhat faster.
  } else 
    supports = find_supports(lower_case(useragent), supports);
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif
  */

#ifdef EXTRA_ROXEN_COMPAT
  if(!referer) referer = ({ });
#endif

  if(!supports->cookies)
    config = prestate;
  else if(conf
	  && GLOBVAR(set_cookie)
	  && !cookies->CaudiumUserID && strlen(not_query)
	  && not_query[0]=='/' && method!="PUT")
  {
    if (GLOBVAR(set_cookie_only_once)) {
      if(!cache_lookup("hosts_for_cookie",remoteaddr)) {
	misc->moreheads = ([ "Set-Cookie": http_caudium_id_cookie(), ]);
	cache_set("hosts_for_cookie",remoteaddr,1);
      }
    } else
      misc->moreheads = ([ "Set-Cookie": http_caudium_id_cookie(), ]);
  }

  foreach(indices(request_headers), string linename) {
    array(string) y;
    switch(linename) {
     case "authorization":
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
      y = request_headers[linename] / " ";
      if(sizeof(y) < 2)
	break;
      y[1] = decode(y[1]);
      if(conf && conf->auth_module)
	y = conf->auth_module->auth( y, this_object() );
      misc->proxyauth=y;
      misc->cacheable = 0;

      // The Proxy-authorization header should be removed... So there.
      // Should be done by proxy modile? Oh well, never really used.
      mixed tmp1,tmp2;    
      foreach(tmp2 = (raw / "\n"), tmp1) {
	if(!search(lower_case(tmp1), "proxy-authorization:"))
	  tmp2 -= ({tmp1});
      }
      raw = tmp2 * "\n"; 
      break;
      
     case "pragma":
      // FIXME: Parse in C
      pragma = aggregate_multiset(@replace(request_headers[linename],
					   " ", "")/ ",");
      if(pragma["no-cache"])
	misc->cacheable = 0;
      break;
      
     case "user-agent":
      sscanf(useragent = request_headers[linename], "%s via", useragent);
#ifdef EXTRA_ROXEN_COMPAT
      client = (useragent/" ") - ({ "" });
#endif
#ifdef ENABLE_SUPPORTS    
  if(useragent == "unknown") {
    supports = find_supports("", supports); // This makes it somewhat faster.
  } else 
    supports = find_supports(lower_case(useragent), supports);
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif
      break;

     case "referer":
#ifdef EXTRA_ROXEN_COMPAT
      referer = request_headers[linename]/" ";
#endif
      referrer = request_headers[linename];
      break;
	    
#ifdef DEBUG
     case "extension":
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

#ifdef EXTRA_ROXEN_COMPAT
     case "content-type":
     case "connection":
      misc[linename] = lower_case(request_headers[linename]);
      misc[linename] = request_headers[linename];      
      break;
#endif

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
      misc[linename] = (request_headers[linename]-" ") / ",";
      break;

     case "cookie": /* This header is quite heavily parsed */
      // FIXME: Definite candidate for parsing in C 
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
#ifdef EXTRA_ROXEN_COMPAT
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
#endif
	}
      }
      break;

#ifdef EXTRA_ROXEN_COMPAT
     case "host":
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
  if(prestate->nocache) {
    // This allows you to "reload" a page with MSIE by setting the
    // (nocache) prestate.
    pragma["no-cache"] = 1;
    misc->cacheable = 0;
  }
  processed = 1;
}

inline void disconnect()
{
  file = 0;
  if(do_not_disconnect) return;
  TIMER("disconnected");
  destruct();
}

void end(string|void s, int|void keepit)
{
  pipe = 0;
  MARK_FD("http2 end");
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
  TIMER("keep alive check");
  if(keepit &&
     (!(file->raw || file->len <= 0))
     && (request_headers->connection == "keep-alive" ||
	 (prot == "HTTP/1.1" && request_headers->connection != "close"))
     && my_fd)
  {
    // Now.. Transfer control to a new http-object. Reset all variables etc..
    object o = object_program(this_object())(0,0);
    o->remoteaddr = remoteaddr;
    o->supports = supports;
#ifdef EXTRA_ROXEN_COMPAT
    o->client = client;
#endif
    o->useragent = useragent;
    MARK_FD("HTTP kept alive");
    if(!leftovers && method != "POST")
      leftovers = data;
    if(s) leftovers += s;
    o->chain(my_fd,conf,leftovers);
    my_fd = 0;
    TIMER("kept alive");
    disconnect();
    return;
  } 
#endif

  if(objectp(my_fd))
  {
    MARK_FD("HTTP closed");
    if(s) catch {
      my_fd->write(s);
      my_fd->set_blocking();
    };
    destruct(my_fd);
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


string format_backtrace(array bt, int eid) {
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
	  "\n\nDate: "+Caudium.http_date(predef::time())+
	  "\n\nRequest data:\n"+rd));
}

string censor(string what) {
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
	    http_low_answer( 500, "<h1>Error: The server failed to fulfill your query due to an " +
			     "internal error in the internal error routine.</h1>" );
    }
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
  TIMER("data sent");
  if(conf)
  {
    int len;
    if(pipe) file->len = pipe->bytes_sent();
    if(conf)
    {
      if(file->len > 0) conf->sent += file->len;
      file->len += misc->_log_cheat_addition;
      conf->log(file, this_object());
    }
  }
  TIMER("logged");
  end(0,1);
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
    
    if(sizeof(lines)>off)
      lines[off]=("<font size=+1><b>"+lines[off]+"</b></font>");
    lines[max(off-20,0)] = "<a name=here>"+lines[max(off-20,0)]+"</a>";
    data = lines*"\n";
  }
  
  if ( catch( file = caudium->http_error->handle_error( 500, "Internal Server Error",  format_backtrace(bt,eid)+(data ? "<hr noshade><pre>"+data+"</pre>" : ""), this_object() ) ) ) {
    report_error("*** http_error object missing during internal_error() ***\n");
    file =
      http_low_answer( 500, "<h1>Error: The server failed to fulfill your query due to an " +
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

void start_sender()
{  
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

// Send the result.
void send_result(mapping|void result)
{
  array err;
  int tmp;
  mapping heads;
  string head_string="";
  file = result || file;
  TIMER("enter_send_result");
  MARK_FD("send_result");
  if(!mappingp(file))
  {
    // There is no file so calling error
    mixed tmperr;
    tmperr = conf->handle_error_request(this_object());
    if(mappingp(tmperr)) 
      file = (mapping)tmperr;
    else {  // Fallback error handler.
      if(misc->error_code)
        file = http_low_answer(misc->error_code, errors[misc->error]);
      else if(method != "GET" && method != "HEAD" && method != "POST")
        file = http_low_answer(501,"Not implemented.");
      else 
        file = http_low_answer(404,"Not found.");
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
      mixed fstat;
      if(objectp(file->file))
        if(!file->stat && !(file->stat=misc->stat))
          file->stat = (array(int))file->file->stat();
	 
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
    	
        if(!file->is_dynamic && !misc->is_dynamic)
        {
          heads["Last-Modified"] = Caudium.http_date(fmtime);
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
    if(file->is_dynamic || misc->is_dynamic)
    {
	  /* Do not cache! */
	  /* 
	   * Cache-Control is valid only for the HTTP 1.1+ requests
	   */
	  if (cache_control_ok)
	    heads["Cache-Control"] = "no-store, no-cache, max-age=0, private, must-revalidate, proxy-revalidate";
	  heads["Expires"] = "0";
	  
	  // The below is only for HTTP 1.0 - should we test whether the
	  // current request proto is 1.0 and set the header only then? /grendel
	  heads["pragma"] = "no-cache";
    }
    
    string h;
    heads +=
    (["MIME-Version":(file["mime-version"] || "1.0"),
      "Content-Type":file["type"],
      "Accept-Ranges": "bytes",
#ifdef KEEP_ALIVE
      "Connection": (request_headers->connection == "close" ?
		     "close": "keep-alive"),
#else
      "Connection"	: "close",
#endif
      "Server":version(),
      "X-Got-Fish": (caudium->query("identpikever") ? fish_version : "Yes"), 
      "Date":Caudium.http_date(time) ]);    

    if(file->encoding)
      heads["Content-Encoding"] = file->encoding;
    
    if(!file->error) 
      file->error = 200;
    
    if(!zero_type(file->expires))
      heads->Expires = file->expires ? Caudium.http_date(file->expires) : "0";
    
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
      misc->cacheable = 0;
      
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
    if(conf) conf->hsent += strlen(head_string);
  }
  
  
  
#ifdef REQUEST_DEBUG
  roxen_perror(sprintf("Sending result for prot:%O, method:%O file:%O\n",
		       prot, method, file));
#endif /* REQUEST_DEBUG */
  
  TIMER("send_result");
  MARK_FD("send_result");
  if(method == "HEAD" || file->error == 304)
  {
    my_fd->write(head_string);
    do_log();
    return;
  } else {
#ifdef ENABLE_RAM_CACHE
    if( conf && (misc->cacheable > 0) && file->len > 0)
    {
      string data = head_string +
        (file->file?file->file->read(file->len):
        (file->data[..file->len-1]));
      caudium->cache_manager->get_cache()->store(
        cache_pike(
	  ({
	    data,
	    ([
	      "hs"    : strlen(head_string),
	      "len"   : file->len,
	      "error" : error
	    ])
	  }),
	  sprintf("http2|%s", raw_url),
	  misc->cacheable
	)
      );
      file = ([ "data":data, "len": strlen(data) ]);
      head_string = "";
    } 
#endif
#if DIRECT_WRITE
    if(file->len >= 0 && file->len < DIRECT_WRITE) {
      my_fd->write(head_string + (file->file ? file->file->read() :
				  file->data[..file->len-1]));
      do_log();
      return;
    }
#endif
    if(strlen(head_string))                 send(head_string);
    if(file->data && strlen(file->data))    send(file->data, file->len);
    else if(file->file)                     send(file->file, file->len);
  }

  start_sender();
}


// Execute the request
void handle_request( )
{
  mixed err;
  function funp;
  object thiso=this_object();
  TIMER("enter_handle");
  MARK_FD("handle request");
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
	      file = handle_error_file_request( err[0],  (int)variables->error );
	  }
	}
      }
    }
  }
#endif /* MAGIC_ERROR */

  remove_call_out(do_timeout);
  MARK_FD("handling request");
  TIMER("handle_request");
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
static int processed;
static int got_all_data;
object htp;
void got_data(mixed fdid, string s)
{
  int tmp;
  ITIMER();
  TIMER("got_data");
  MARK_FD("http2 got_data");
  remove_call_out(do_timeout);
  call_out(do_timeout, 30); // Close down if we don't get more data 
  // within 30 seconds. Should be more than enough.
  time = _time(1); // Check is made towards this to make sure the object
  // is not killed prematurely.
  raw += s;
  if(!method) {
    if (!htp)
      htp = Caudium.ParseHTTP(misc, request_headers, GLOBVAR(RequestBufSize));
    tmp = htp->append(s);
    switch(tmp)
    { 
     case 0:
      // More on the way.
      return;
     case 1:
      // Processed OK
      method = misc->method;
      prot = clientprot = misc->protocol;
      if (prot == "HTTP/1.1")
        cache_control_ok = 1;
      not_query = f = misc->file;
      raw_url = misc->raw_url;
      query = misc->query;
      data = misc->data;      
      destruct(htp);
      if(request_headers->host)
      	host = lower_case(request_headers->host);
      if(request_headers->connection)
	request_headers->connection = lower_case(request_headers->connection);
      if(strlen(data) < (misc->len = (int)request_headers["content-length"])) {
	// Need more data
	return;
      }
      break;
     default:
      string err = "Broken request";
      MARK_FD("http2 broken request");
      
      switch(tmp) {
       case 400: /* bad request */
	err = "Bad request";
	break;
	
       case 413: /* Request entity too large */
	err = "Request Entity Too Large (trying to overflow, eh?)";
	break;
      }
      
      end("HTTP/1.0 "+tmp +" Sorry dude.\r\n\r\n<h1>"+err+"</h1>");
      return;
    }
  } else {
    data += s;
  }
  if(strlen(data) < misc->len) {
    // Need more data
    return;
  }
  got_all_data = 1;
  TIMER("parsed");
#ifdef ENABLE_RAM_CACHE
  if(!request_headers->authorization && method != "POST")
    misc->cacheable = GLOBVAR(RequestCacheTimeout);
#endif
  if(conf)
  {
    conf->received += strlen(s);
    conf->requests++;
  }
  
  my_fd->set_nonblocking(0,0,0);

  if(conf) {
    conf->handle_precache(this_object());
#ifdef ENABLE_RAM_CACHE
    array cv;
    if( misc->cacheable && (cv = caudium->cache_manager->get_cache()->retrieve(sprintf("http2|%s", raw_url))) )
    {
      MARK_FD("http2 cached reply");

      string d = cv[ 0 ];
      file = cv[1];
      conf->hsent += file->hs;
#ifdef DIRECT_WRITE
      if( strlen( d ) < DIRECT_WRITE )
      {
	my_fd->write( d );
	do_log();
      } else {
#endif
	send( d );
	start_sender();      
#ifdef DIRECT_WRITE
      }
#endif
      return;
    }
#endif
  }
  TIMER("post_cache_check");
  do_post_processing();
  TIMER("post_processed");
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
    my_fd = f;
    conf = c;
    f->set_nonblocking(got_data, 0, end);
    // No need to wait more than 30 seconds to get more data.
    call_out(do_timeout, 30);
    time = _time(1);
    remoteaddr = Caudium.get_address(my_fd->query_address()||"");
    MARK_FD("HTTP connection");
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
    if(!got_all_data) {
      f->set_nonblocking(got_data, 0, end);
    }
  }
}

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
