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
 * $Id$
 */

constant storage_type    = "GDBM";
constant storage_doc     = "Please enter the full path that you would like to store the "
                           "GDBM database in";
constant storage_default = "+storage.gdbm";

#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define PRELOCK() object __key
#define LOCK() __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define PRELOCK()
#define LOCK()
#define UNLOCK()
#endif

#ifdef NFS_LOCK
static object hitch = HitchingPost;
#define PREFLOCK() object __fkey
#define FLOCK(X, Y, Z) __fkey = hitch->lock(X, Y, Z)
#define FUNLOCK() destruct(__fkey);
#else
#define PREFLOCK()
#define FLOCK(X,Y,Z) ({X, Y, Z})
#define FUNLOCK()
#endif

#define DB db

static object db;
static string path;

void create(string _path) {
  PRELOCK();
  LOCK();
  path = Stdio.append_path(_path, sprintf("%d.%d.%d.gdbm", __MAJOR__, __MINOR__, __BUILD__));
}

void store(string namespace, string key, string value) {
  PRELOCK();
  LOCK();
  string _hash = get_hash(sprintf("%s|%s", namespace, key));
  DB()->store(_hash, value);
}

mixed retrieve(string namespace, string key) {
  PRELOCK();
  LOCK();
  string _hash = get_hash(sprintf("%s|%s", namespace, key));
  DB()->fetch(_hash);
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  LOCK();
  if (stringp(key)) {
    string _hash = get_hash(sprintf("%s|%s", namespace, key));
    DB()->delete(_hash);
  }
  else {
    string lastkey = DB()->firstkey();
    while(string key = DB()->nextkey(lastkey)) {
      lastkey = key;
      mapping obj = decode(DB()->fetch(key));
      if (mappingp(obj))
        if (obj->namespace == namespace)
	  DB()->delete(key);
    }
  }
}

void unlink_regexp(string namespace, string regexp) {
  PRELOCK();
  LOCK();
  string lastkey = DB()->firstkey();
  object r = Regexp(regexp);
  while(string key = DB()->nextkey(lastkey)) {
    lastkey = key;
    mapping obj = decode(DB()->fetch(key));
    if (mappingp(obj))
      if (obj->namespace == namespace)
        if (r->match(obj->key))
	  DB()->delete(key);
  }
}

static string encode(string namespace, string key, string value) {
  string data = sprintf("/* Storage.Disk */\n\nmapping data = ([ \"namespace\" : \"%s\", \"key\" : \"%s\", \"value\" : \"%s\" ]);", namespace, replace(key, "\"", "\\\""), replace(value, "\"", "\\\""));
  return MIME.encode_base64(data, 1);
}

static mixed decode(string data) {
  program p;
  if (catch(p = compile_string(MIME.decode_base64(data))))
    return 0;
  return p()->data;
}

static string get_hash( string data ) {
  string retval;
#if constant(_Lobotomized_Crypto)
  retval = _Lobotomized_Crypto.md5()->update( data )->digest();
#elseif constant(Crypto)
  retval = Crypto.md5()->update( data )->digest();
#else
  retval = MIME.encode_base64( data );
#endif
  return sprintf("%@02x",(array(int)) retval);
}

int size(string namespace) {
  PRELOCK();
  LOCK();
  int total;
  string lastkey = DB()->firstkey();
  while(string key = DB()->nextkey(lastkey)) {
    mapping obj = decode(DB()->fetch(key));
    if (mappingp(obj))
      if (obj->namespace == namespace)
        total += sizeof(obj->value);
  }
}

array list(string namespace) {
  PRELOCK();
  LOCK();
  array ret = ({});
  string lastkey = DB()->firstkey();
  while(string key = DB()->nextkey(lastkey)) {
    mapping obj = decode(DB()->fetch(key));
    if (mappingp(obj))
      if (obj->namespace == namespace)
        ret += ({ obj->key });
  }
}

object _db() {
  if (!objectp(db))
    return db;
  else {
    PREFLOCK();
    FLOCK(path, "w", 1);
    db = Gdbm.gdbm(path, "crw");
    return db;
  }
}
