/*
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

// $Id$

string hostname;
int port;
int max_conns;

array conns=({});

//! Create a new AJP1.3 client. 
void create(string _host, int _port, int maxconn)
{
#ifdef AJP_DEBUG
  report_debug("Protocols.AJP.Client()\n");
#endif
  if(!strlen(_host)) error("No host specified.");
  if(!_port) error("No port number specified.");
  hostname=_host;
  port=_port;
  max_conns=maxconn;
}

void destruct()
{
#ifdef AJP_DEBUG
  report_debug("Protocols.AJP.Client.destruct()\n");
#endif
  foreach(conns, object c)
  {
    if(c->destroy_function && functionp(c->destroy_function))
      c->destroy_function();
    c->destruct();
  }
}

//! handle a request
mapping handle_request(object id)
{
  object c=get_connection();
  mapping response=([]);
  response=c->handle(id);
  replace_connection(c);
  return response;
}

object get_connection()
{
  foreach(conns, object c)
  {
    if(!c->inuse)
    {
      conns-=({c});
      return c;
    }    
  }  
  return connection(hostname, port);

}

void replace_connection(object conn)
{
#ifdef AJP_DEBUG
  report_debug("sizeof conns: " + sizeof(conns) + "\n");
#endif
  if(sizeof(conns)<max_conns)
  {
    conn->set_destroy_function(lambda(object cnx){conns-=({cnx});});
    conns+=({conn});
    conn->request_done();
  }
}

//! an ajp connection. created by @[AJP.Client].
class connection
{
  inherit .protocol;
  object c;
  int inuse=0;
  int destruct_on_close=0;
  function destroy_function;

//!
  void create(string host, int port)
  {
#ifdef AJP_DEBUG
     report_debug("Protocols.AJP.Client.connection()\n");
#endif
     c=Stdio.File();    
     if(!c->connect(host, port))
       error("Protocols.AJP.client.connection(): Unable to connect to " + host + ":" + port + ".");
  }

  string read_packet()
  {
    int len;
    string d= c->read(4); // get packet header and length.
    sscanf(d, "%2*c%2c", len);
    d+=c->read(len);
    return d;
 }


//!
  mapping handle(object id)
  {
    inuse=1;
    mapping r=([]);

    // send request
    c->write(generate_server_packet(packet_forward_request(id)));

    // do we have a request body to send?
    if(id->request_headers["content-length"] && 
       (int)(id->request_headers["content-length"]) > 0)
    {
      string data=id->data;
      // loop through, sending at most the maximum packet length
      foreach(id->data/(float)(MAX_PACKET_SIZE-6), string d)
      {
        c->write(generate_server_packet(packet_body(d)));   
      }
    }

    int keep_listening=1;
    report_debug("sent AJP 1.3 request\n");

    mapping r1;

    do
    {
      string rcv=read_packet();
      r1=decode_container_packet(rcv);

      if(r1->type==MSG_GET_BODY_CHUNK)
      {
        c->write(generate_server_packet(packet_body("")));   
        error("container asked for data we already should have sent.");
      }
      if(r1->type==MSG_SEND_HEADERS)
       r=decode_send_headers(r1);
      else if(r1->type==MSG_SEND_BODY_CHUNK)
      {
        if(!r->body) r->body="";
        r->body+=decode_send_body_chunk(r1);
      }
      else if(r1->type==MSG_END_RESPONSE) 
      {
        keep_listening=0;
        r1=decode_end_response(r1);
        if(r1->reuse!=1)
        {
#ifdef AJP_DEBUG
          report_debug("we will destruct this connection when done.\n");
#endif
          destruct_on_close=1;
        }
      }
      else error("Invalid packet type " + r1->type + " received.\n");
    }
    while(keep_listening==1);

    inuse=0;
    return r;
  }
  
  void set_destroy_function(function f)
  {
    if(f)
      destroy_function=f;
  }

  void request_done()
  {
    if(destruct_on_close && destroy_function)
      destroy_function(this_object());
  }

}

