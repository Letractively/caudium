//! This module impliments the Apache JServ Protocol, version 1.3

//! Web Server to Servlet Container message
constant MSG_FORWARD_REQUEST =	2;

//! Web Server to Servlet Container message
constant MSG_SHUTDOWN =		7;

//! Servlet Container to Web Server message
constant MSG_SEND_HEADERS =		4;

//! Servlet Container to Web Server message
constant MSG_SEND_BODY_CHUNK =	3;

//! Servlet Container to Web Server message
constant MSG_GET_BODY_CHUNK	=	6;

//! Servlet Container to Web Server message
constant MSG_END_RESPONSE =		5;

//! Maximum Packet Size, in bytes
constant MAX_PACKET_SIZE =	8*1024;

constant METHOD_OPTIONS = 1; 
constant METHOD_GET = 2; 
constant METHOD_HEAD = 3; 
constant METHOD_POST = 4;
constant METHOD_PUT = 5; 
constant METHOD_DELETE = 6; 
constant METHOD_TRACE = 7; 
constant METHOD_PROPFIND = 8; 
constant METHOD_PROPPATCH = 9; 
constant METHOD_MKCOL = 10; 
constant METHOD_COPY = 11; 
constant METHOD_MOVE = 12;
constant METHOD_LOCK = 13; 
constant METHOD_UNLOCK = 14; 
constant METHOD_ACL = 15; 
constant METHOD_REPORT = 16; 
constant METHOD_VERSION_CONTROL = 17; 
constant METHOD_CHECKIN = 18;
constant METHOD_CHECKOUT = 19; 
constant METHOD_UNCHECKOUT = 20; 
constant METHOD_SEARCH = 21; 
constant METHOD_MKWORKSPACE = 22; 
constant METHOD_UPDATE = 23; 
constant METHOD_LABEL = 24; 
constant METHOD_MERGE = 25;
constant METHOD_BASELINE_CONTROL = 26; 
constant METHOD_MKACTIVITY = 27;

constant attribute_values=([
    "context" : 0x01,  // not implimented
    "servlet_path" : 0x02,  // not implimented
    "remote_user" : 0x03,
    "auth_type" : 0x04,
    "query_string" : 0x05,
    "jvm_route" : 0x06,
    "ssl_cert" : 0x07,
    "ssl_cipher" : 0x08,
    "ssl_session" : 0x09,
    "req_attribute" : 0x0a,
    "terminator" : 0xff
    ]);

constant header_values=([
    "accept" : 0xa001,
    "accept-charset" : 0xa002,
    "accept-encoding" : 0xa003,
    "accept-language" : 0xa004,
    "authorization" : 0xa005,
    "connection" : 0xa006,
    "content-type" : 0xa007,
    "content-length" : 0xa0008,
    "cookie" : 0xa009,
    "cookie2" : 0xa00a,
    "host" : 0xa00b,
    "pragma" : 0xa00c,
    "referer" : 0xa00d,
    "user-agent" : 0xa00e
    ]);

string generate_server_packet(string data)
{
  if(strlen(data)>MAX_PACKET_SIZE) error("AJP Packet too large: " + strlen(data) + ".");
  else
    return sprintf("%c%c%2c%s", 0x12, 0x34, strlen(data), data);
}

string packet_shutdown()
{
  return sprintf("%c", MSG_SHUTDOWN);
}

string packet_body(string d)
{
  return sprintf("%2c%s",strlen(d),d);
}

string packet_forward_request(object id)
{
  int method=method_from_string(id->method);    
  mapping attributes=([]);
  string packet="";
  string server_name;
  int server_port;
  int is_ssl=0;

  if(id->server_protocol=="HTTPS")
  {
   is_ssl=1;
//   we need to figure out what this information should be.
//   attributes->ssl_cert=id->;
//   attributes->ssl_cipher="";
//   attributes->ssl_session="";
  }
  if(id->user)
  {
    attributes->remote_user=id->user->username;
    attributes->auth_type="Basic";
  }


  server_name=id->conf->query("MyWorldLocation");
  sscanf(server_name, "%*s//%s", server_name);
  sscanf(server_name, "%s:", server_name);
  sscanf(server_name, "%s/", server_name);

  sscanf(id->my_fd->query_address(1), "%*s %d", server_port);
  
  if(id->query)
    attributes->query_string=id->query;

  packet=sprintf("%c%c%s%s%s%s%s%2c%c%2c%s%s%c",
     MSG_FORWARD_REQUEST,
     method,
     push_string(id->clientprot),
     push_string(id->not_query),
     push_string(id->remoteaddr),
     push_string(caudium->quick_ip_to_host(id->remoteaddr)),
     push_string(server_name),
     server_port,
     is_ssl,
     sizeof(id->request_headers),
     make_request_headers(id->request_headers),
     make_attributes(attributes),
     0xff
     );

  return packet;

}

int method_from_string(string method)
{
   int mi=0;
   switch(upper_case(method))
   {
     case "OPTIONS":
        mi=METHOD_OPTIONS;
        break;

     case "GET":
        mi=METHOD_GET;
        break;

     case "HEAD":
        mi=METHOD_HEAD;
        break;

     case "POST":
        mi=METHOD_POST;
        break;

     case "PUT":
        mi=METHOD_PUT;
        break;

     case "DELETE":
        mi=METHOD_DELETE;
        break;

     case "TRACE":
        mi=METHOD_TRACE;
        break;

     case "PROPFIND":
        mi=METHOD_PROPFIND;
        break;

     case "PROPPATCH":
        mi=METHOD_PROPPATCH;
        break;

     case "MKCOL":
        mi=METHOD_MKCOL;
        break;

     case "COPY":
        mi=METHOD_COPY;
        break;

     case "MOVE":
        mi=METHOD_MOVE;
        break;

     case "LOCK":
        mi=METHOD_LOCK;
        break;

     case "UNLOCK":
        mi=METHOD_UNLOCK;
        break;

     case "ACL":
        mi=METHOD_ACL;
        break;

     case "REPORT":
        mi=METHOD_REPORT;
        break;

     case "VERSION-CONTROL":
        mi=METHOD_VERSION_CONTROL;
        break;

     case "CHECKIN":
        mi=METHOD_CHECKIN;
        break;

     case "CHECKOUT":
        mi=METHOD_CHECKOUT;
        break;

     case "UNCHECKOUT":
        mi=METHOD_UNCHECKOUT;
        break;

     case "SEARCH":
        mi=METHOD_SEARCH;
        break;

     case "MKWORKSPACE":
        mi=METHOD_MKWORKSPACE;
        break;

     case "UPDATE":
        mi=METHOD_UPDATE;
        break;

     case "LABEL":
        mi=METHOD_LABEL;
        break;

     case "MERGE":
        mi=METHOD_MERGE;
        break;

     case "BASELINE_CONTROL":
        mi=METHOD_BASELINE_CONTROL;
        break;

     case "MKACTIVITY":
        mi=METHOD_MKACTIVITY;
        break;

     default:
        error("unknown method " + method);
        break;
   }
   return mi;
}

//! @note 
//!    the spec doesn't specifically say how to encode this, so we need to check
//!    the apache source to see the length of the length code.
string push_string(string s)
{
   string news=sprintf( "%2c%s%c", strlen(s), s, 0x00);
   
   return news;
}

//! @note 
//!    the spec doesn't specifically say how to encode this, so we need to check
//!    the apache source to see the length of the length code.
array pull_string(string s)
{
   string news;
   int len;
   sscanf(s, "%2c%s", len, s);
   if(!len) return ({"", s[1..]});
   sscanf(s, "%" + len + "s%*c%s", news, s);   
   return ({news, s});
}

string make_request_headers(mapping h)
{
  string header_string="";

  foreach(indices(h), string header)
  {
    if(header_values[h])
      header_string+=header_values[h] + push_string(h[header]);
    else
      header_string+=push_string(header) + push_string(h[header]);
  }
  return header_string;
}

string make_attributes(mapping a)
{
  string attribute_string="";

  foreach(indices(a), string attribute)
  {
    if(attribute_values[attribute])
      attribute_string+= sprintf("%c", attribute_values[attribute]) + 
        push_string(a[attribute]);
    else
      error("unknown attribute " + attribute + ".\n");
  }

//  attribute_string+=sprintf("%c", attribute_values->terminator);
  return attribute_string;
}

string decode_send_body_chunk(mapping packet)
{
  werror("decode_send_body_chunk: ");
  if(packet->type != MSG_SEND_BODY_CHUNK)
    error("Attempt to decode invalid send body chunk packet.\n");
  
  int len;

  sscanf(packet->data, "%2c%s", len, packet->data);
  sscanf(packet->data, "%" + len + "s", packet->data);
  werror(" " + len + " bytes of data.\n");
  return packet->data;
}

mapping decode_end_response(mapping packet)
{
  werror("decode_end_response\n");
  if(packet->type != MSG_END_RESPONSE)
    error("Attempt to decode invalid end response packet.\n");

  sscanf(packet->data, "%c", packet->reuse);

  return packet;

}

mapping decode_send_headers(mapping packet)
{
  werror("decode_send_headers\n");
  if(packet->type != MSG_SEND_HEADERS)
    error("Attempt to decode invalid send headers packet.\n");

  sscanf(packet->data, "%2c%s", packet->response_code, packet->data);
  [packet->response_msg, packet->data]=pull_string(packet->data);
  sscanf(packet->data, "%2c%s", packet->num_headers, packet->data);

  packet->response_headers=([]);

  for(int i=0; i<packet->num_headers; i++)
  {
    string h,v;
    [h, packet->data]=pull_string(packet->data);
    [v, packet->data]=pull_string(packet->data);
    packet->response_headers[h]=v;
  }

  return packet;
}

mapping decode_container_packet(string packet)
{
  mapping result=([]);
  int len=0;

  if(packet[0..1]!="AB")
  {
    error("Invalid packet from container.\n");
  }

  sscanf(packet[2..], "%2c%s", len, packet);

  if(!len)
  {
    error("Invalid packet length from container.\n");
  }

  sscanf(packet, "%" + len + "s", packet);

  if(strlen(packet) !=len)
  {
    error("Payload length not correct. Expected " + len + " got " + 
      strlen(packet) + ".");
  }

  sscanf(packet, "%c%s", result->type, result->data);
  
  return result;
}
