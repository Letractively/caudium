string hostname;
int port;
int max_conns;

array conns=({});

void create(string _host, int _port, int maxconn)
{
  if(!strlen(_host)) error("No host specified.");
  if(!_port) error("No port number specified.");
  hostname=_host;
  port=_port;
  max_conns=maxconn;
}

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
  if(sizeof(conns)<max_conns)
    conns+=({conn});
}

class connection
{
  inherit .protocol;
  object c;
  int inuse=0;

  void create(string host, int port)
  {
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
        werror("received end response packet.\n");
      }
      else error("Invalid packet type " + r1->type + " received.\n");
    }
    while(keep_listening==1);

    inuse=0;
    return r;
  }

}

