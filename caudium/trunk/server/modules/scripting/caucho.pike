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

//
//! module: mod_caucho for Caudium
//!  This module provides srun Caudium interface.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FILE_EXTENSION | MODULE_LAST
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe = 0;

#include <roxen.h>
#include <module.h>

#define DEFAULT_PORT	6802

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

inherit "module";
inherit "caudiumlib";

constant module_type	= MODULE_FILE_EXTENSION | MODULE_LAST;
constant module_unique	= 0;
constant module_name	= "mod_caucho for Caudium";
constant module_doc	= "This module provides srun Caudium interface.\n";

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

  object open(void|string hostname, void|int port)
  {
    int result;

    result = fd->connect(hostname || "localhost", port || DEFAULT_PORT);

    string res = fd?"open ok":"open fail";

    RESINWERR(res);

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
    if (id->auth && sizeof(id->auth) && id->auth[0])
       srun->write_string(CSE_REMOTE_USER, id->auth[1]);
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

string caucho_error(object id, string err)
{
  string result;

  id->request_headers["content-type"] = "text/html";

  result = "<html>\n<head>\n<title>Caucho error</title>\n</head>\n<body>\n";
  result += "<h1>Roxen caucho module error</h1>\n";
  result += "<h3>" + err + "</h3>\n";
  result += "</body>\n</html>\n";

  return result;
}

string caucho_request(object id)
{
  string output;
  string jsid;

  id->misc->srun = CseStream();

  if (!id->misc->srun) return caucho_error(id, "Can't create CseStream.");

  if (!id->misc->srun->open(query("host"), query("port")))
     return caucho_error(id, "Can't connect to srun.\n");

  if (id->cookies->JSESSIONID) jsid = id->cookies->JSESSIONID;
  if (id->misc->jspquery) sscanf(id->misc->jspquery, "jsessionid=%s", jsid);

  if (jsid) id->misc->srun->session = id->misc->srun->decode_session(jsid);

  RESINWERR("jsid = " + jsid);
  RESINWERR("decode_session = " + id->misc->srun->session);

  id->misc->srun->write_request(id);
  output = id->misc->srun->send_data(id);
  id->misc->srun->close();

  return output;
}

void start(int n, object conf)
{
}

string status()
{
  return "Loaded";
}

void create(object conf)
{
  defvar("ext", ({"jsp", "xtp"}),
         "Resin extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, " +
         "will be parsed by Resin.");
  defvar("host", "localhost",
         "srun host", TYPE_STRING,
         "Host, where srun is running.");
  defvar("port", 6802,
         "srun port", TYPE_INT,
         "Port, where srun listen.");
}

array(string) query_file_extensions()
{
  return query("ext");
}

int|mapping handle_file_extension(object o, string e, object id)
{
  return ([ "data":caucho_request(id),
            "type":id->request_headers["content-type"] ]);
}

int|mapping last_resort(object id)
{
  string toparse = id->not_query;
  array(string) tmp;

  tmp = toparse / ";";

  if (id->misc->jspquery) return 0;

  switch (sizeof(tmp))
  {
    case 1:
		return 0;
    case 2:
		id->not_query = tmp[0];
		id->misc->jspquery = tmp[1];
		return 1;
    default:
		id->not_query = tmp[0];
		id->misc->jspquery = tmp[1..] * ";";
		return 1;
  }
}
