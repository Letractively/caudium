/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 * The Storage module and the accompanying code is Copyright © 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   James Tyson	<jnt@caudium.net>
 *
 */


#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK() 
#define UNLOCK()
#endif

static function _store;
static function _retrieve;
static function _unlink;
static function _unlink_regexp;
static function _size;
static function _list;
static function _stop;
static string namespace;

void create(string _namespace, mapping callbacks) {
  LOCK();
  _store = callbacks->store;
  _retrieve = callbacks->retrieve;
  _unlink = callbacks->unlink;
  _unlink_regexp = callbacks->unlink_regexp;
  _size = callbacks->size;
  _list = callbacks->list;
  _stop = callbacks->stop;
  namespace = _namespace;
}

public void store(string key, mixed val) {
  LOCK();
  _store(namespace, key, val);
}

public mixed retrieve(string key) {
  LOCK();
  return _retrieve(namespace, key);
}

public void unlink(void|string key) {
   LOCK();
   _unlink(namespace, key);
}

public void unlink_regexp(void|string regexp) {
  LOCK();
  _unlink_regexp(namespace, regexp);
}

public int size() {
 LOCK();
 return _size(namespace);
}

public array list() {
  return _list(namespace);
}

public void stop() {
  _stop(namespace);
}
