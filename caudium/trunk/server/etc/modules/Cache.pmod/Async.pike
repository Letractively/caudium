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

/*
 * The Cache module and the accompanying code is Copyright © 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   James Tyson	<jnt@caudium.net>
 *
 */

class Retrieve {

  inherit "base_server/cachelib";

  object in, out;
  
  void create(function retrieve, string name, object _out) {
    in = retrieve(name);
    out = _out;
    in->set_buffer(8192000);
    out->set_buffer(8192000);
    in->set_nonblocking(read, 0, close);
  }

  static void read(mixed id, string data) {
    out->write(data);
  }

  static void close() {
    in->close();
    out->close();
  }

}

class Store {

  inherit "base_server/cachelib";

  object in, out;
  function store;
  string data, name;
  mapping cache_response;
  int exp;

  void create(function _store, string name, object _in, object _out, void|int _exp) {
    in = _in;
    out = _out;
    store = _store;
    data = "";
    exp = (_exp?_exp:300);
    in->set_buffer(8192000);
    out->set_buffer(8192000);
    in->set_nonblocking(read, 0, close);
  }

  static void read(mixed id, string _data) {
    out->write(_data);
    data += _data;
  }

  static void close() {
    in->close();
    out->close();
    object pipe_in = Stdio.File();
    object pipe_out = pipe_in->pipe();
    pipe_in->write(data);
    pipe_in->close();
    store(cache_file(name, pipe_out, exp));
  }

}
