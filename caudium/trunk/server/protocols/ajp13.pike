/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2004 The Caudium Group
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
inherit "http";
private inherit Protocols.AJP.protocol;
private inherit "caudiumlib";

// HTTP protocol module.
#include <config.h>
#include <module.h>

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

object my_fd;

private final string user;
string raw="";
string to_process="";

private int got_len=0;
private int len_to_get=0;
private int body_len=0;
private int last_get_success=0;
private int sent;
private int reuse=1;
private string packet="";
string body="";

#define GETTING_REQUEST_BODY 1

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


mapping h = ([]);
h->response_msg = "Config in cookie!";
h->response_code = 302;
h->headers = ([
  "set-cookie": Caudium.HTTP.config_cookie(indices(config) * ","),
  "location": url, 
  "content-type": "text/html", 
  "content-length": "0"
]);
  my_fd->write(generate_container_packet(encode_send_headers(h)));
  my_fd->write(generate_container_packet(encode_end_response(1)));
  // do we need to end the request?

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

    url = Caudium.add_pre_state(url, prestate);

    if (base[-1] == '/') {
      url = base + url[1..];
    } else {
      url = base + url;
    }

mapping h = ([]);
h->response_msg = "Config in cookie!";
h->response_code = 302;
h->headers = ([
  "location": url, 
  "content-type": "text/html", 
  "content-length": "0"
]);
  my_fd->write(generate_container_packet(encode_send_headers(h)));
  my_fd->write(generate_container_packet(encode_end_response(1)));
  // do we need to end the request?

  }
  return 2;

}


int parse_got()
{
  if(got_len)
  {
    // we know how much data we're waiting for.
    if(sizeof(to_process) >= len_to_get)
    {
      // we should have the rest of the packet.
      sscanf(to_process, "%" + len_to_get + "s%s", packet, to_process);
      last_get_success=1; 
      len_to_get=0;
      got_len=0; 

      if(current_state == GETTING_REQUEST_BODY) // we're not expecting a packet type.
      {
         body+=packet;
         got_len=0;
         len_to_get=0;
         // have we received all of the body data?
         if(sizeof(body) < body_len) // no?
           return 0;
         else
           // we have finished receiving the request...
           return -1;
      }

      // otherwise, we need to get the packet type.
      else
      {
         int packet_type;
         sscanf(packet, "%c%s", packet_type, packet);
         return packet_type;
      }
    }
    else return 0;
  }
  // we need at least 4 bytes to read a packet.
  else if(sizeof(to_process)>=4 )
  {
    int code, len;
    int n = sscanf(to_process, "%2c%2c%s", code, len, to_process);
    if(n!=3) 
    {
      // what should we do if we receive a bad packet?
      write("invalid packet received!\n");
    } 

    if(code!=0x1234)
    {
      // what should we do if we receive a bad packet?
      write("invalid packet received!\n");
    }

    else
    {
      got_len=1; 
      len_to_get=len;
      return parse_got(); // we might have a full packet.
    }
  }

  return 0;
}
/* We got some data on a socket.
 * ================================================= 
 */
int processed;


private int current_state;

void got_data(mixed fdid, string s)
{
  int tmp, ready_to_process, keep_trying;
  MARK_FD("AJP got data");
  remove_call_out(do_timeout);
  call_out(do_timeout, 30); // Close down if we don't get more data 
                         // within 30 seconds. Should be more than enough.

  time = _time(1); // Check is made towards this to make sure the object
  		  // is not killed prematurely.

  // if data is ingored dont store it in raw - its body data from
  // the last request...

  to_process += s;

  if(!strlen(to_process))
    return;

  do
  {
    last_get_success=0;
    tmp = parse_got();

    switch(tmp)
    {
      // we need more data.
      case 0:
      break;

      // we got a forward request.
      case 2:
       if(parse_forward())  // we're done, as we've been short circuited.
       {
         packet = "";
         body_len = 0;
         processed = 0;
	 remove_call_out(do_timeout);
         if(reuse) ready_for_request();

       }
       if(!body_len) // if we need to wait for the body, we should continue.
       ready_to_process=1;
       break;

      // we got a shutdown request
      case 7:
       break;

      // we got a ping
      case 8:
       break;

      // we got a cping
      case 10:
       break;

      // done receiving data
      case -1:    
       ready_to_process=1;
       break;
    }

    if(ready_to_process)
      break;

  } while(last_get_success);

  remove_call_out(do_timeout);

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

// we need to pull the forward packet apart.
int parse_forward()
{
  string a, h;
  string contents;
  int config_in_url;
  array mod_config;

  mapping r = decode_forward((["data": packet, "type": MSG_FORWARD_REQUEST]));

//  werror("request: %O\n", r);
  body_len=r->request_headers["content-length"];
  method = method_names[r->method];
  prot = clientprot = r->protocol;
  string f = raw_url = r->req_uri;
  time = _time(1);

  if (clientprot == "HTTP/1.1") {
    REQUEST_WERR("HTTP/1.1 request - checking for absolute URI");
    int startpos = 0;
    if (has_prefix(raw_url, "http://"))
      startpos = 7;
    if (has_prefix(raw_url, "https://"))
      startpos = 8;

    if (startpos) {
      REQUEST_WERR("Apparently an absoluteURI - recording the host part");
      int i = startpos;
      int l = strlen(raw_url);
      
      while (i < l && raw_url[i] != '/')
        i++;
      
      if (i < l && raw_url[i] == '/') {
        absolute_uri = raw_url[0..i];
        raw_url = raw_url[i..];
        f = f[i..];
        REQUEST_WERR(sprintf("AbsoluteURI == %s; raw_url == %s", absolute_uri, raw_url));
      }
    }
  }
  if(sscanf(f,"%s?%s", f, query) == 2) {
    Caudium.parse_query_string(query, variables, empty_variables);
    foreach(indices(empty_variables), string varname)
      variables[varname] = "";
    rest_query = indices(empty_variables) * ";";
  }
  
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

  f = Caudium.parse_prestates(f, prestate, internal);
  REQUEST_WERR(sprintf("prestate == %O\ninternal == %O\n",
                       prestate, internal));

  REQUEST_WERR(sprintf("After prestate scan:%O", f));

  not_query = Caudium.simplify_path(f);

  REQUEST_WERR(sprintf("After Caudium.simplify_path == not_query:%O", not_query));

  request_headers = r->request_headers;

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
//  }

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
    really_set_config( mod_config );
    return 1;
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
	misc->moreheads = ([ "Set-Cookie": Caudium.HTTP.id_cookie(), ]);
      }
      if (QUERY(set_cookie_only_once))
	cache_set("hosts_for_cookie",remoteaddr,1);
    }

	// site_id is set to conf->name
	// this should be overriden by 2nd level virtual hosting modules in
	// precache_rewrite()
	if(objectp(conf) && conf->name)
	{
		site_id = conf->name;
	}
  return 0;
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
	c->site_id = site_id;

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

             
// This macro ensures that something gets reported even when the very
// call to internal_error() fails. That happens eg when this_object()
// has been destructed.
#define INTERNAL_ERROR(err)                                                     \
  if (mixed __eRr = catch (internal_error (err)))                               \
    report_error("Internal server error: " + describe_backtrace(err) +          \
                 "internal_error() also failed: " + describe_backtrace(__eRr))
  
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
      if((err=catch(file = caudium->configuration_parse( this_object() 
)))) {
        if(err == -1) return;
        INTERNAL_ERROR(err);
      }      
    }        
  }          
  send_result();
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

  MARK_FD(sprintf("send_result(%O,%O)",result, file));

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
        file = Caudium.HTTP.low_answer(misc->error_code, Caudium.Const.errors[misc->error]);
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
      object fstat;
      if(objectp(file->file))
        if(!file->stat && !(file->stat=misc->stat))
          file->stat = file->file->stat();
      
      fstat = file->stat;
      if(objectp(fstat))
      {
        int fsize, fmtime;
	
        fsize = fstat->size;
        fmtime = fstat->mtime;
	
        if(file->file && !file->len)
          file->len = fsize;

        if(!file->is_dynamic && !misc->is_dynamic) {
#ifdef SUPPORT_HTTP_09
          if(prot != "HTTP/0.9") {
#endif
            heads["Last-Modified"] = Caudium.HTTP.date(fmtime);
            if(since)
            {
              if(Caudium.is_modified(since, fmtime, fsize))
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

//      head_string += _Roxen.make_http_headers(heads);
//      if(conf) conf->hsent+=strlen(head_string||"");
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
my_fd->set_blocking();
mapping h = ([]);
h->response_msg = (file->rettext||Caudium.Const.errors[file->error]);
h->response_code = file->error;
h->headers = heads;
  my_fd->write(generate_container_packet(encode_send_headers(h)));
sent = 0;

if(file->len>=0)
{
  int pkt_no=0;
  string chunk;
  do 
  {
    chunk="";
    if(file->data)
    {  
      if(sizeof(file->data)< ((MAX_PACKET_SIZE-7)*(pkt_no+1)))
         chunk = file->data[(MAX_PACKET_SIZE-7)*pkt_no..];
      else
        chunk = 
file->data[(MAX_PACKET_SIZE-7)*pkt_no..((MAX_PACKET_SIZE-7)*++pkt_no)-1];      
    }

    else chunk = file->file->read(MAX_PACKET_SIZE-7);

    sent+=sizeof(chunk);
//    werror("sending " + sizeof(chunk) + " bytes of " + sent + " / "+ file->len + " ");
    
  my_fd->write(generate_container_packet(encode_send_body_chunk(chunk)));
  
  } while (sent < file->len);
}

  my_fd->write(generate_container_packet(encode_end_response(reuse)));
  do_log();
  if(reuse) ready_for_request();
  else 
  {
    my_fd->close();
  }
  packet = "";
  body_len = 0;
  processed = 0;
}

void ready_for_request()
{
    object o = object_program(this_object())(my_fd, conf);
    object fd = my_fd;
    my_fd = 0;
    o->chain(fd, conf, to_process);
}

void do_log()
{
  MARK_FD("HTTP logging"); // fd can be closed here
  if(conf)
  {
    int len;
    if(pipe)
#ifdef USE_SHUFFLER
      file->len = pipe->sent_data();
#else
      file->len = pipe->bytes_sent();
#endif
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      file->len += misc->_log_cheat_addition;
      conf->log(file, this_object());
    }
  }
//  end(0,1);
  return;
}



void create(void|object f, void|object c)
{
  if(f)
  {
    ::create(f,c);
    server_protocol="AJP";

    f->set_nonblocking(got_data, 0, end);
    // No need to wait more than 30 seconds to get more data.
    call_out(do_timeout, 30);
    time = _time(1);
    my_fd = f;
    MARK_FD("AJP connection");
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
//    call_out(do_timeout, 150);
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
      f->set_close_callback(this->destroy);
      f->set_read_callback(got_data);
    }
  }
}
   
