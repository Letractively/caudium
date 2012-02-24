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

//! an ajp connection. created by @[AJP.Server].
class connection
{
  inherit .protocol;
  object c;
  int inuse=0;
  int destruct_on_close=0;
  function destroy_function;

//!
  void create(Stdio.File f)
  {
#ifdef AJP_DEBUG
     report_debug("Protocols.AJP.Server.connection()\n");
#endif
     c=f;
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
  int receive_request(object id, int keep_listening)
  {
    inuse=1;
    mapping r=([]);
    string data;

    // send request
    r=decode_client_packet(read_packet());
 
    if(!r) return 0;

    mapping v=decode_request_headers(r);

    // do we have a request body to send?
    if(v->request_headers["content-length"] && 
       (int)(v->request_headers["content-length"]) > 0)
    {
      data=read_client_body(c)
      if(!data) return 0;
    }

    report_debug("received the AJP 1.3 request\n");

    werror("ajp container request: %O,\n data: %O\n", v, data);

    return 1;
  }
  
}

