#!/usr/bin/pike
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
/*
 * $Id$
 */

class connection {

private object fd;
private int j = 0, i = 0, nbrequests;
private string path, host;

void read_cb(mixed id, string data)
{
  remove_call_out(selfexit);
  int end = 0, pos = 0;
  while((pos = search(data, "</html>", pos+1)) != -1)
  {
    end = 1; j++;
  }
  //write("Answer number %d\n", j);
  if(i<nbrequests && end)
  {
    // now launch a bunch of new requests to stress even more
    // 100 per default
    int advance = 100;
    if(advance > nbrequests)
      advance = nbrequests;
    if(i - j <= advance)
    {
      // a long call_out is required on busy servers
      call_out(selfexit, 3000);
      for(int k = 0; k < advance; k++)
        write_cb();
    }
  }
  if(j > nbrequests)
    selfexit();
}

void selfexit()
{
  write("answers=%d, requests=%d\n", j-1,i-1);
  catch (fd->close());
  // remove all calls out
  while(zero_type(find_call_out(selfexit)) != 1)
    remove_call_out(selfexit);
  destruct(this_object());
}

void close_cb()
{
  werror("connection closed by foreign host.\n");
  selfexit();
}

void write_cb()
{
  //write(sprintf("Request number %d\n", i));
  string data = sprintf("GET %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\n\r\n", path, host);
  int written = fd->write(data);
  if(written != sizeof(data))
  {
    werror("Didn't write all data to socket.\n");
  }
  i++;
}

void create(int _nbrequests, string _path, string _host, int port)
{
  host = _host;
  path = _path;
  nbrequests = _nbrequests;
  fd = Stdio.File();
  fd->connect(host, port);
  fd->set_nonblocking(read_cb, 0, close_cb);
  write_cb();
}

}

void usage(string myname)
{
  werror("%s: nb_simultaneous_requests nb_request_per_session path_to_file "
  "[host] [port]\n", myname);
  werror("This script will test a keepalived webserver with nb_simultaneous_requests\n"
  "simultaneous requests and will output nb_request_per_session query of\n"
  "path_to_file to the host optional host and port.\n");
  werror("If number of answers is not equals number of requests then you\n"
  "have a problem. Note also that this program never return.\n"
  "It also require a file ending in </html> on the server\n");
}

int main(int argc, array(string) argv)
{
  if(argc != 6)
  {
    usage(argv[0]);
    return 1;
  }
  int nbsimrequests = (int)argv[1];
  for(int i=0; i < nbsimrequests; i++)
    connection((int)argv[2], argv[3], argv[4], (int)argv[5]);
  return -1;
}

