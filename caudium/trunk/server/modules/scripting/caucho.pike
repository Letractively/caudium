/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 *
 * Ported from Roxen module
 * Daniel Podlejski <underley@underley.eu.org>
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

//
//! module: mod_caucho for Caudium
//!  This module provides srun Caudium interface.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FILE_EXTENSION | MODULE_LAST
//! cvs_version: $Id$
//

inherit "module";
inherit "caudiumlib";
inherit "cachelib";

constant cvs_version = "$Id$";
constant thread_safe = 1;

// we should be thread safe, as we create a new connection with each
// request. hopefully that's not a problem.

#include <caudium.h>
#include <module.h>

#define DEFAULT_PORT	6802

// uncomment this if you want debug
//#define RESINDEBUG	1

#ifdef RESINDEBUG
# define RESINWERR(X) werror(sprintf("caucho.pike: %s\n", X))
#else
# define RESINWERR(X)
#endif

#define CSE_NULL            '?'
#define CSE_PATH_INFO       'b'
#define CSE_PROTOCOL        'c'
#define CSE_METHOD          'd'
#define CSE_QUERY_STRING    'e'
#define CSE_SERVER_NAME     'f'
#define CSE_SERVER_PORT     'g'
#define CSE_REMOTE_HOST     'h'
#define CSE_REMOTE_ADDR     'i'
#define CSE_REMOTE_PORT     'j'
#define CSE_REAL_PATH       'k'
#define CSE_REMOTE_USER     'm'
#define CSE_AUTH_TYPE       'n'
#define CSE_URI             'o'
#define CSE_CONTENT_LENGTH  'p'
#define CSE_CONTENT_TYPE    'q'
#define CSE_IS_SECURE       'r'
#define CSE_SESSION_GROUP   's'
#define CSE_CLIENT_CERT     't'
#define CSE_HEADER          'H'
#define CSE_VALUE           'V'
#define CSE_STATUS          'S'
#define CSE_SEND_HEADER     'G'
#define CSE_PING            'P'
#define CSE_QUERY           'Q'
#define CSE_ACK             'A'
#define CSE_DATA            'D'
#define CSE_FLUSH           'F'
#define CSE_KEEPALIVE       'K'
#define CSE_END             'Z'
#define CSE_CLOSE           'X'

array resin_hosts=({});
object session_cache;

constant module_type	= MODULE_FILE_EXTENSION | MODULE_LAST;
constant module_unique	= 0;
constant module_name	= "mod_caucho for Caudium";
constant module_doc	= "This module provides an interface to "
                          "Caucho Resin servers using the srun protocol.\n";

// srun protocol class
class CseStream
{
  object fd;
  string read_queue;
  string write_queue;
  int write_length;
  int read_length;
  int read_offset;
  int lastcode;
  int session;

  string host;
  int port;

  object open(string _hostname, int _port)
  {
    int result;

    result = fd->connect(_hostname, _port);

    string res = fd?"open ok":"open fail";

    RESINWERR(res);

    if(result)
    host=_hostname;
    port=_port; 

    if (result) return fd;
    else return 0;
  }

  void write_string(int code, string buff)
  {
     int length = 0;
     string hdr;

     if (!buff) buff = "";
     if (buff) length = sizeof(buff);

     hdr = sprintf("%c%c%c%c", code, (length >> 16) & 0xff,
                              (length >> 8) & 0xff, (length) & 0xff);

     RESINWERR("write " + (buff || ""));

     fd->write(hdr + buff);
  }

  string read_string()
  {
     int code, l1, l2, l3, length;
     string result;
     string packet;
     string hdr;

     hdr = fd->read(4, 1);

     if (!hdr) return 0;

     sscanf(hdr, "%c%c%c%c", code, l1, l2, l3);

     length = (l1 << 16) + (l2 << 8) + (l3);

     lastcode = code;

     packet = fd->read(length, 0);

     result = packet;

     RESINWERR("read " + (result || ""));

     return result;
  }

  int decode_session(string session)
  {
     int value = 0;
     int i;
   
     for (i = 2; i >= 0; i--) {
       int code = session[i];

       RESINWERR("decode_session: v: " + value + " c: " + code);
   
       if (code >= 'a' && code <= 'z')
         value = 64 * value + code - 'a';
       else if (code >= 'A' && code <= 'Z')
         value = 64 * value + code - 'A' + 26;
       else if (code >= '0' && code <= '9')
         value = 64 * value + code - 'A' + 52;
       else if (code == '_')
         value = 64 * value + 62;
       else if (code == '/')
         value = 64 * value + 63;
       else
         return -1;
     }
   
     if (i > -1)
       return -1;
     else
       return value;
  }

  int close()
  {
    return fd->close();
  }

  void write_env(object id)
  {
    object srun;
  
    if (id->misc->srun) srun = id->misc->srun;
    if (!srun->fd) return;
  
    srun->write_string(CSE_PROTOCOL, id->prot);
    srun->write_string(CSE_METHOD, id->method);
    if (id->misc->jspquery)
       srun->write_string(CSE_URI, id->not_query + ";" +id->misc->jspquery);
    else srun->write_string(CSE_URI, id->not_query);
    if (id->query) srun->write_string(CSE_QUERY_STRING, id->query);
    srun->write_string(CSE_SERVER_NAME, (string)id->conf->name);
    srun->write_string(CSE_SERVER_PORT, (string)id->conf->port || "unk");
    srun->write_string(CSE_REMOTE_ADDR, (string)id->remoteaddr || "unk");
    srun->write_string(CSE_REMOTE_PORT, (string)id->clientprot || "unk");
    if (id->user)
       srun->write_string(CSE_REMOTE_USER, id->user->username);
    srun->write_string(CSE_SESSION_GROUP, sprintf("%d", srun->session));
  }
  
  void write_headers(object id)
  {
    object srun;
  
    if (id->misc->srun) srun = id->misc->srun;
    if (!srun->fd) return;
  
    mapping headers = id->request_headers;
  
    foreach (indices(headers) - ({"content-type", "content-length"}),
             string hdr)
    {
       write_string(CSE_HEADER, hdr);
       write_string(CSE_VALUE, headers[hdr]);
    }
    write_string(CSE_CONTENT_TYPE, headers["content-type"]);
    write_string(CSE_CONTENT_LENGTH, headers["content-length"]);
  }
  
  void write_request(object id)
  {
    object srun;
  
    if (id->misc->srun) srun = id->misc->srun;
    if (!srun->fd) return;
  
    write_env(id);
    write_headers(id);
  
    if (id->data) write_string(CSE_DATA, id->data);
  
    write_string(CSE_END, "");
    write_string(CSE_ACK, "");
  }

  string send_data(object id)
  {
    int code = 1;
    object srun;
    string buff;
    string result;
    int i;
  
    RESINWERR("send_data(1): lastcode = " + lastcode);

    if (id->misc->srun) srun = id->misc->srun;
  
    while (code > 0 && code != CSE_END && code != CSE_CLOSE)
    {
      if (!srun->fd) return 0;
  
      buff = read_string();
      RESINWERR("send_data(2): buff = " + buff);
      code = lastcode;
      RESINWERR("send_data(3): code = " + code);

      switch (code) {
      case CSE_STATUS:
        break;
  
      case CSE_HEADER:
        string key = buff;
        string value = read_string();
        id->request_headers[lower_case(key)] = value;
        RESINWERR("send_data(4): " + key + ": " + value);
        break;
  
      case CSE_DATA:
        result = buff;
        break;
  
      case CSE_FLUSH:
        break;
  
      case CSE_KEEPALIVE:
        break;
  
      case CSE_SEND_HEADER:
        break;
  
      case -1:
        break;
  
      default:
        break;
      }
    }
  
    RESINWERR("send_data(5): return " + result);
    return result;
  }

  void create()
  {
    write_length = 0;
    read_length  = 0;
    read_offset  = 0;
    read_queue   = "";
    write_queue  = "";
    fd = Stdio.File();
  }
}

// wrapper for parsing html from output.
class RXMLParseWrapper
{
  static object _file;
  static object _id;
  static string _data;

  int write(string data)
  {
    _data += data;
    return strlen(data);
  }

  int close(void|string how)
  {
    _file->write(parse_rxml(_data,_id));
    _data="";
    return _file->close(how);
  }

  mixed `->(string n)
  {
    return ::`->(n) || predef::`->(_file, n);
  }

  void create(object file, object id)
  {
    _file = file;
    _id = id;
    _data = "";
  }
}


// throw error page
// TODO - maybe this should return HTTP 500 status ?
string caucho_error(object id, string err)
{
  string result;

  id->request_headers["content-type"] = "text/html";

  result = "<html>\n<head>\n<title>Caucho error</title>\n</head>\n<body>\n";
  result += "<h1>Caudium caucho module error</h1>\n";
  result += "<h3>" + err + "</h3>\n";
  result += "</body>\n</html>\n";

  return result;
}

// connect to srun and process request
string caucho_request(object id)
{
  string output;
  string jsid;

  // get jsessionid from request - this is needed to determine
  // which srun host to use 
  if (id->cookies->JSESSIONID) jsid = id->cookies->JSESSIONID;
  if (id->misc->jspquery) sscanf(id->misc->jspquery, "jsessionid=%s", jsid);

  // connect to srun, else throw error
  string shost;
  int sport;
  array r;
  array h; 

  if(jsid)  // we have an existing session, which resin do we connect to?
  {
     r=session_cache->retrieve(jsid);
  }

 if(!jsid || !r) // we don't know the current session's destination, so pick one.
  {
    h=resin_hosts[random(sizeof(resin_hosts))];
    shost=h[0];
    sport=h[1];
  }

  // create connection handler
  id->misc->srun = CseStream();

  // throw error if no CseStream
  if (!id->misc->srun) return caucho_error(id, "Can't create CseStream.");

  int srun_connected;
  array hosts_to_try=resin_hosts;

  // try to connect, trying the available hosts if our preference fails.
  do
  {

    if(id->misc->srun->open(shost, sport))
    {
      // success!
      srun_connected=1;
      break;
    }
    else
    {
      // for some reason, we need to make sure we close after a failure.
      // go figure.
      id->misc->srun->close();

      hosts_to_try-=({ h });
      if(sizeof(hosts_to_try)<1) break;

      h=hosts_to_try[random(sizeof(hosts_to_try))];
      shost=h[0];
      sport=h[1];
    }
  }
  while(sizeof(hosts_to_try)>0);


  // did we give up and not connect?
  if(!srun_connected)
     return caucho_error(id, "Can't connect to srun.\n");

  // if we have a session, let us remember the host we conneted to.
  if(jsid)
   session_cache->store(cache_pike(({ shost, sport }), jsid, 3600));

  // set sessionid
  if (jsid) id->misc->srun->session = id->misc->srun->decode_session(jsid);

  RESINWERR("jsid = " + jsid);
  RESINWERR("decode_session = " + id->misc->srun->session);

  // send request to srun ...
  id->misc->srun->write_request(id);

  // ... read results ...
  output = id->misc->srun->send_data(id);

  // and close connction
  // TODO - keepalive, if possible
  id->misc->srun->close();

  return output;
}

void start(int n, object conf)
{
  resin_hosts=({});

  if(QUERY(hosts) && QUERY(hosts)!="")
  {
     array r=QUERY(hosts)/"\n";
     foreach(r, string h)
     {
        if(!h || h=="") continue;
        array hp=h/":";
        if(sizeof(hp)==2)
          resin_hosts+=({ ({hp[0], (int)(hp[1])}) });
        else
          resin_hosts+=({ ({hp[0], DEFAULT_PORT}) });
     }

     // create the cache for session to srun hosts mapping.
     session_cache=caudium->cache_manager->get_cache(this_object());
  }

}

string status()
{
  return "Loaded with " + sizeof(resin_hosts) + " Resin servers in queue.";
}

void create(object conf)
{
  defvar("ext", ({"jsp", "xtp"}),
         "Resin extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, " +
         "will be parsed by Resin.");
  defvar("hosts", "localhost",
         "srun hosts", TYPE_TEXT_FIELD,
         "Hosts where srun is running, provided in the format: host:port, "
         "one per line. Omitting the port will cause the default port "
         "of DEFAULT_PORT to be used");
 defvar("rxml", 0, "Parse RXML in servlet output", TYPE_FLAG|VAR_MORE,
         "If this is set, the output from Resin handled by this "
         "module will be RXML parsed. NOTE: No data will be returned to the "
         "client until the output is fully parsed.");

}

array(string) query_file_extensions()
{
  return query("ext");
}

int|mapping handle_file_extension(object o, string e, object id)
{

  if(QUERY(rxml)) return (["data": parse_rxml(caucho_request(id), id),
              "type": id->request_headers["content-type"] ]);

  else return ([ "data":caucho_request(id),
            "type":id->request_headers["content-type"] ]);
}

// jsp has own query string standard - all after ";" is jsp query
int|mapping last_resort(object id)
{
  string toparse = id->not_query;
  array(string) tmp;

  tmp = toparse / ";";

  // don't parse, if id->misc->jspquery exists
  if (id->misc->jspquery) return 0;

  // there is no jsp query
  if (sizeof(tmp) == 1) return 0;

  // assign all after ";" to id->misc->jspquery
  id->not_query = tmp[0];
  id->misc->jspquery = tmp[1..] * ";";
  return 1;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: ext
//! All files ending with these extensions, 
//!  type: TYPE_STRING_LIST
//!  name: Resin extensions
//
//! defvar: host
//! Host, where srun is running.
//!  type: TYPE_STRING
//!  name: srun host
//
//! defvar: port
//! Port, where srun listen.
//!  type: TYPE_INT
//!  name: srun port
//
