/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
private string packet="";
string body="";

#define GETTING_REQUEST_BODY 1

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
       parse_forward();
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

  if(conf)
  {
    conf->received += strlen(s);
    conf->requests++;
  }

  my_fd->set_close_callback(0); 
  my_fd->set_read_callback(0); 
  processed=1;

  mapping h = (["response_code":200, "response_msg":"OK", 
     "headers": (["Content-Length": 5, "Content-Type": "text/plain"])  ]);

  my_fd->write(generate_container_packet(encode_send_headers(h)));
  my_fd->write(generate_container_packet(encode_send_body_chunk("ha ha")));
  my_fd->write(generate_container_packet(encode_end_response(1)));

  packet = "";
  body_len = 0;
  processed = 0;
  ready_for_request();

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
void parse_forward()
{
  mapping r = decode_forward((["data": packet, "type": MSG_FORWARD_REQUEST]));

  werror("request: %O\n", r);
  body_len=r->request_headers["content-length"];
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

void ready_for_request()
{
    my_fd->set_nonblocking(got_data, 0, end);
    // No need to wait more than 30 seconds to get more data.
    call_out(do_timeout, 30);
    time = _time(1);
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

