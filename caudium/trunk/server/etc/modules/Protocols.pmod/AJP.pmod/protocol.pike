//! This module impliments the Apache JServ Protocol, version 1.3

//! Web Server to Servlet Container message
constant int MSG_FORWARD_REQUEST =	2

//! Web Server to Servlet Container message
constant int MSG_SHUTDOWN =		7

//! Servlet Container to Web Server message
constant int MSG_SEND_HEADERS =		4

//! Servlet Container to Web Server message
constant int MSG_SEND_BODY_CHUNK =	3

//! Servlet Container to Web Server message
constant int MSG_GET_BODY_CHUNK	=	6

//! Servlet Container to Web Server message
constant int MSG_END_RESPONSE =		5

//! Maximum Packet Size, in bytes
constant int MAX_PACKET_SIZE =	8*1024

constant int METHOD_OPTIONS = 1; 
constant int METHOD_GET = 2; 
constant int METHOD_HEAD = 3; 
constant int METHOD_POST = 4;
constant int METHOD_PUT = 5; 
constant int METHOD_DELETE = 6; 
constant int METHOD_TRACE = 7; 
constant int METHOD_PROPFIND = 8; 
constant int METHOD_PROPPATCH = 9; 
constant int METHOD_MKCOL = 10; 
constant int METHOD_COPY = 11; 
constant int METHOD_MOVE = 12;
constant int METHOD_LOCK = 13; 
constant int METHOD_UNLOCK = 14; 
constant int MEHTOD_ACL = 15; 
constant int METHOD_REPORT = 16; 
constant int METHOD_VERSION_CONTROL = 17; 
constant int METOD_CHECKIN = 18;
constant int METHOD_CHECKOUT = 19; 
constant int METHOD_UNCHECKOUT = 20; 
constant int METHOD_SEARCH = 21; 
constant int METHOD_MKWORKSPACE = 22; 
constant int METHOD_UPDATE = 23; 
constant int METHOD_LABEL = 24; 
constant int METHOD_MERGE = 25;
constant int METHOD_BASELINE_CONTROL = 26; 
constant int METHOD_MKACTIVITY = 27;

string generate_server_packet(string data)
{
  if(strlen(data)>MAX_PACKET_SIZE) error("AJP Packet too large: " + strlen(data) + ".");
  else
    return sprintf("%c%c%2c%s", 0x12, 0x34, strlen(data), data);
}

string packet_forward_request(object id)
{
  int method=method_from_string(id->method);    
  mapping attributes=([]);
  string packet="";
  string server_name;
  int server_port;
  int is_ssl=0;

  if(id->SSL) is_ssl=1;

  server_name=id->conf->query("MyWorldLocation");
  sscanf(server_name, "%*s//%s", server_name);
  sscanf(server_name, "%s:", server_name);
  sscanf(server_name, "%s/", server_name);

  sscanf(id->my_fd->query_address(1), "%*s %d", server_port);

  packet=sprintf("%c%c%s%s%s%s%s%2c%c%2c%s%s%c",
     MSG_FORWARD_REQUEST,
     method,
     to_string(id->clientprot),
     to_string(id->raw_query),
     to_string(id->remoteaddr),
     to_string(quick_ip_to_host(id->remoteaddr)),
     to_string(server_name),
     server_port,
     is_ssl,
     sizeof(id->request_headers),
     make_request_headers(id->request_headers),
     make_attributes(attributes),
     0xff
     );

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
string to_string(string s)
{
   string news=s;
   
   return news;
}

string make_request_headers(mapping h)
{
  return "";
}

string make_attributes(mapping a)
{
  return "";
}
