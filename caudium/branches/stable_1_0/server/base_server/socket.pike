/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 */

// This code has to work both in 'roxen.pike' and all modules
// $Id$

#if !constant(caudium)
#define caudium caudiump()
#endif

#if DEBUG_LEVEL > 19
#ifndef SOCKET_DEBUG
# define SOCKET_DEBUG
#endif
#endif

private void connected(array args)
{
  if (!args) {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect: No arguments to connected\n");
#endif /* SOCKET_DEBUG */
    return;
  }
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect ok.\n");
#endif
  args[2]->set_id(0);
  args[0](args[2], @args[1]);
}

private void failed(array args)
{
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect failed\n");
#endif
  args[2]->set_id(0);
  destruct(args[2]);
  args[0](0, @args[1]);
}

private void got_host_name(string host, string oh, int port,
			   function callback, mixed ... args)
{
  object f;
  f=Stdio.File();
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect "+oh+" == "+host+"\n");
#endif
  if(!f->open_socket())
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: socket() failed. Out of sockets?\n");
#endif
    callback(0, @args);
    destruct(f);
    return;
  }
  f->set_id( ({ callback, args, f }) );
  f->set_nonblocking(0, connected, failed);
#ifdef FD_DEBUG
  mark_fd(f->query_fd(), "async socket communication: -> "+host+":"+port);
#endif
  if(catch(f->connect(host, port))) // Illegal format...
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: Illegal internet address in connect in async comm.\n");
#endif
    callback(0, @args);
    destruct(f);
    return;
  }
}

void async_connect(string host, int port, function|void callback,
		   mixed ... args)
{
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect requested to "+host+":"+port+"\n");
#endif
  caudium->host_to_ip(host, got_host_name, host, port, callback, @args);
}


private void my_pipe_done(object which)
{
  if(objectp(which))
  {
    if(which->done_callback)
      which->done_callback(which);
    else
      destruct(which);
  }
}

void async_pipe(object to, object from, function|void callback, 
		mixed|void id, mixed|void cl, mixed|void file)
{
  object pipe=Pipe.pipe();
  object cache;

#ifdef SOCKET_DEBUG
  perror("async_pipe(): ");
#endif
  if(callback) 
    pipe->set_done_callback(callback, id);
  else if(cl) {
    cache = caudium->cache_file(cl, file);
    if(cache)
    {
#ifdef SOCKET_DEBUG
      perror("Using normal pipe with done callback.\n");
#endif
      pipe->input(cache->file);
      pipe->set_done_callback(my_pipe_done, cache);
      pipe->output(to);
      destruct(from);
      pipe->start();
      return;
    }
    if(cache = caudium->create_cache_file(cl, file))
    {
#ifdef SOCKET_DEBUG
      perror("Using normal pipe with cache.\n");
#endif
      pipe->output(cache->file);
      pipe->set_done_callback(my_pipe_done, cache);
      pipe->input(from);
      pipe->output(to);
      return;
    }
  }
#ifdef SOCKET_DEBUG
  perror("Using normal pipe.\n");
#endif
  pipe->input(from);
  pipe->output(to);
}

void async_cache_connect(string host, int port, string cl, 
			 string entry, function|void callback,
			 mixed ... args)
{
  object cache;
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_cache_connect requested to "+host+":"+port+"\n");
#endif
  cache = caudium->cache_file(cl, entry);
  if(cache)
  {
    object f;
    f=cache->file;
//    perror("Cache file is %O\n", f);
    cache->file = 0; // do _not_ close the actual file when returning...
    destruct(cache);
    return callback(f, @args);
  }
  caudium->host_to_ip(host, got_host_name, host, port, callback, @args);
}



