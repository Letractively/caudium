/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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

#include <module.h>

#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define LOCK() object __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define LOCK() 
#define UNLOCK()
#endif

#define SYNC_IN 5

static mapping storage;
static object permstore;
static mapping clients;
function destroy = sync_all;
function stop = sync_all;

void create(string _permstore, string path) {
  start(_permstore, path);
  storage = ([ ]);
  clients = ([ ]);
#ifdef STORAGE_DEBUG
  write("STORAGE: Creating new Storage.Manager with backend %O and option %O\n",
        _permstore,
	path);
#endif
}

void start(string _permstore, string path) {

  if(functionp(path)) path=call_function(path);
  LOCK();
  if (objectp(permstore)) {
    destruct(permstore);
  }
  switch (_permstore) {
  case "Disk":
    permstore = Storage.Methods.Disk(path);
    break;
  case "MySQL":
    permstore = Storage.Methods.MySQL(path);
    break;
  case "GDBM":
    permstore = Storage.Methods.GDBM(path);
    break;
  }
#ifdef STORAGE_DEBUG
  write("Starting storage manager with %O backed.\n", _permstore);
#endif
}

public object get_storage(string namespace) {
  LOCK();
  mapping callbacks = ([ "store" : store, "retrieve" : retrieve, "unlink" : unlink, "size" : size, "list" : list, "stop" : stop, "unlink_regexp" : unlink_regexp ]);
  if (! clients[namespace]) {
    clients += ([ namespace : Storage.Client(namespace, callbacks) ]);
  }
  return clients[namespace];
}

public mapping storage_globvar() {
  return ([
    "default" : permstore->storage_default|"",
    "name " : permstore->storage_name,
    "doc" : permstore->storage_doc
  ]);
}

public array storage_types() {
  return ({ "Disk", "MySQL", "GDBM" });
}

public string storage_default() {
  return "Disk";
}

static void store(string namespace, string key, mixed val) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Storing %O from %O\n", key, namespace);
#endif
  LOCK();
  if (! storage[ namespace ])
    storage += ([ namespace : ([]) ]);
  storage[ namespace ] += ([ key : val ]);
  UNLOCK();
  call_out( sync, SYNC_IN, namespace, key );
}

static mixed retrieve(string namespace, string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Retrieving %O from %O\n", key, namespace);
#endif
  LOCK();
  if (storage[namespace])
    if (storage[namespace][key])
      return storage[namespace][key];
  UNLOCK();
  return permstore->retrieve(namespace, key);
}

static void sync(string namespace, string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Syncing %O/%O to permanent storage\n", key, namespace);
#endif
  LOCK();
  if (storage[namespace])
    if (storage[namespace][key]) {
      permstore->store(namespace, key, storage[namespace][key]);
    }
}

static void unlink(string namespace, void|string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Removing %O in %O\n", (key?key:"all"), namespace);
#endif
  LOCK();
  if (stringp(key)) {
    if (storage[namespace])
      if (storage[namespace][key])
        m_delete(storage[namespace], key);
  }
  else
    m_delete(storage,namespace);
  UNLOCK();
  permstore->unlink(namespace, key);
}

static void unlink_regexp(string namespace, string regexp) {
  sync_all(namespace);
  permstore->unlink_regexp(namespace, regexp);
}

static void sync_all(void|string namespace) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Syncing all objects\n");
#endif
  if (!storage || !sizeof(storage))
     return;

  if (namespace)
    if (storage[namespace])
      foreach(indices(storage[namespace]), string key)
        sync(namespace, key);
  foreach(indices(storage), string _namespace)
    foreach(indices(storage[_namespace]), string key)
      sync(namespace, key);
}

string storage_backend() {
  return permstore->name();
}

static int size(string namespace) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Getting total size of %O\n", namespace);
#endif
  sync_all();
  return permstore->size(namespace);
}

static array list(string namespace) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Listing objects in %O\n", namespace);
#endif
  sync_all();
  array _list = permstore->list(namespace);
  if (arrayp(_list))
    return _list;
  else
    return ({ });
}
