/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2004 The Caudium Group
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

//! Storage Module : Disk method.

/*
 * The Storage module and the accompanying code is Copyright � 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   James Tyson	<jnt@caudium.net>
 *
 */

//!
constant storage_type    = "Disk";

//!
constant storage_doc     = "Please enter the path on the filesystem that you would like to "
                           "store the data in.";

//!
constant storage_default = "+";

// we use a base time plus a randomization to prevent things from getting locked
// into a cycle of sync processes.
#define SYNCTIME 60

static string path;
mapping idx;
mapping idx_sz;
static mapping _size;
array _sending;
int idx_sync_stop;

int get_sync_time()
{
  return SYNCTIME + random(SYNCTIME/10);
}

//!
//! the index is the canonical source for information about whether something is stored.
//! at startup, if a file is present on disk, but is not in the index, it will be deleted.
void create(string _path) {
  _sending = ({});
  path = _path;
  _size = ([]);
  idx_sz = idx_size_get();
  idx = idx_get();
  if (mappingp(idx)) {
    array f = ({});
    foreach(indices(idx), string n) {
      f += values(idx[n]);
    }
    array _d = get_dir(path) - ({ "storage_index", "storage_size" });
    array d = ({});
    string _f;
    foreach(_d, _f)
      d += ({ Stdio.append_path(path, _f) });
    array r = d - f;
    foreach(r, _f)
      rm(Stdio.append_path(path, _f));
  }
  else 
  {
    idx = ([]);
    idx_sz = ([]);
  }
  call_out(idx_sync, get_sync_time());
  if (!Stdio.is_dir(path))
    Stdio.mkdirhier(path);
#ifdef CACHE_DEBUG
  debug();
#endif
}

#ifdef CACHE_DEBUG

//!
void debug() {
  if (sizeof(_sending))
    write("Writing files: %O\n", _sending);
  call_out(debug, 0.1);
}
#endif

//!
void store(string namespace, string key, string value) {
  if (!namespace || !key)
    return;
  string objpath = idx_path(namespace, key);
  string data = encode(namespace, key, value);
  idx_size(namespace, key, data);
  write_file(objpath, encode(namespace, key, value));
}

//!
void unlock(void|object key) {
  if (objectp(key))
    destruct(key);
}

//!
mixed retrieve(string namespace, string key) {
  if (!namespace || !key)
    return 0;
  string objpath = idx_path(namespace, key);
  if (Stdio.exist(objpath)) {
    string s = read_file(objpath);
    if (!stringp(s))
      return 0;
    mixed tmp = decode(s);
    if(mappingp(tmp) && (tmp->value)) {
#ifdef CACHE_DEBUG
      if (sizeof(tmp->value) > 100)
        write("object %O|%O returning %O\n", namespace, key, tmp->value[0..100]);
      else
        write("object %O|%O returning %O\n", namespace, key, tmp->value);
#endif
      return tmp->value;
    }
    else {
      idx_rm(namespace, key);
      rm(objpath);
      return 0;
    }
  }
  else {
    idx_rm(namespace, key);
    return 0;
  }
}

//!
void unlink(string namespace, void|string key) {
  if (!namespace)
    return;
  if (!stringp(key)) {
    array keys = list(namespace);
    foreach(keys, string _key) {
      string objpath = idx_path(namespace, _key);
      idx_rm(namespace, _key);
      if (Stdio.exist(objpath)) {
        rm(objpath);
      }
    }
    idx_rm(namespace);
    return;
  }
  string objpath = idx_path(namespace, key);
  idx_rm(namespace, key);
  if (Stdio.exist(objpath)) {
    rm(objpath);
  }
}

//!
void unlink_regexp(string namespace, string regexp) {
  object r = Regexp(regexp);
  array keys = list(namespace);
  foreach(keys, string key) {
    if (!r->match(key))
      continue;
    string objpath = idx_path(namespace, key);
    idx_rm(namespace, key);
    rm(objpath);
  }
}

//!
static string encode(string namespace, string key, string value) {
  mapping tmp = ([ "namespace" : namespace, "key" : key, "value" : value ]);
  string data = sprintf("/* Storage.Disk */\n\nmapping data = %O;\n", tmp);
  return data;
}

//!
static mixed decode(string data) {
  program p;
  object e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  if (mixed err = catch(p = compile_string(data))) {
    return 0;
    master()->clear_compilation_failures();
    master()->set_inhibit_compile_errors(0);
  }
  master()->clear_compilation_failures();
  master()->set_inhibit_compile_errors(0);
  return p()->data;
}

//!
static string get_hash(string data) {
  return Caudium.Crypto.hash_md5(data, 1);
}

static string hash_path(string namespace, string key) {
  return Caudium.Crypto.hash_md5(namespace + key, 1);
}

//! this is an _extremely_ heavy operation. avoid using it if at 
//! all possible. additionally, it's hard to say whether the value
//! returned is useful.
int size(string namespace) {
#ifdef STORAGE_DEBUG
    write("STORAGE: size(%s).\n", namespace);
#endif
  if (_size[namespace])
    return _size[namespace];
#ifdef STORAGE_DEBUG
    write("STORAGE: size(%s): generating size.\n", namespace);
#endif
  int total;
  array keys = list(namespace)||({});
  foreach(keys, string key) {
    int size = idx_size(namespace, key);
    total += size;
  }
  _size[namespace] = total;
  return total;
}

//!
array list(string namespace) {
  if (idx[namespace] && mappingp(idx[namespace])) {
#ifdef STORAGE_DEBUG
    write("STORAGE: listing using index.\n");
#endif
    return indices(idx[namespace]);
  }
#ifdef STORAGE_DEBUG
  write("STORAGE: list(%O) called without index - generating.\n", namespace);
#endif
  array ret = ({});
  array dir = get_dir(path)||({});
  dir -= ({ "storage_index" });
  foreach(dir, string fname) {
    string objpath = Stdio.append_path(path, fname);
#ifdef STORAGE_DEBUG
    write("STORAGE OBJECT PATH: %O\n", objpath);
#endif
    string s = read_file(objpath);
    mapping obj = decode(s);
    if (mappingp(obj)) {
      string key = obj->key;
      if (obj->namespace == namespace)
        ret += ({ key });
      idx_path(obj->namespace, key, objpath);
    }
  }
  if (!sizeof(ret))
  {
    idx[namespace]=([]);
    idx_sz[namespace]=([]);
  }
#ifdef STORAGE_DEBUG
  write("STORAGE: index = %O\n", idx);
#endif
  return ret;
}

//!
void flush() {
  if (sizeof(_sending)) {
    _sending->flush();
    while(sizeof(_sending))
      _do_call_outs();
  }
}

//!
static void sending(object o) {
  _sending += ({ o });
}

//!
static void unsending(object o) {
  _sending -= ({ o });
}

//!
string idx_path(string namespace, string key, void|string _path) {
#ifdef STORAGE_DEBUG
  write("STORAGE INDEX: path %O %O %O\n", namespace, key, _path);
#endif
  if (!idx[namespace]) {
    idx[namespace] = ([]);
    idx_sz[namespace] = ([]);
  }
  if (stringp(_path)) {
    idx[namespace][key] = _path;
    return _path;
  }
  else {
    if (idx[namespace][key]) {
      return idx[namespace][key];
    }
    else {
      _path = Stdio.append_path(path, hash_path(namespace, key));
      idx[namespace][key] = _path;
      return _path;
    }
  }
}

//!
int idx_size(string namespace, string key, void|mixed data) {
#ifdef STORAGE_DEBUG
  write("STORAGE INDEX SIZE: path %O %O %O\n", namespace, key, sizeof(data||""));
#endif
  if (!idx_sz[namespace]) {
    idx_sz[namespace] = ([]);
  }
  if (idx_sz[namespace][key]) {
    return idx_sz[namespace][key];
  }
  else if(data){
    int sz = sizeof(data);
    idx_sz[namespace][key] = sz;
    return sz;
  }
  else
  {
    string objpath = idx_path(namespace, key);
    int sz;
    if (Stdio.exist(objpath))
    {
      string s = read_file(objpath);
      sz = sizeof(s);
    }
    idx_sz[namespace][key] = sz;
    return sz;
  }
}

//!
void idx_sync(void|int stop) {
#ifdef STORAGE_DEBUG
  write("STORAGE: Syncing index to disk.\n");
#endif
  string ipath = Stdio.append_path(path, "storage_index"); 
  string data = sprintf("/* Storage.Disk */\n\nmapping data = %O;\n\n", idx);
  catch(write_file(ipath, data));

  ipath = Stdio.append_path(path, "storage_size"); 
  data = sprintf("/* Storage.Disk */\n\nmapping data = %O;\n\n", idx_sz);
  catch(write_file(ipath, data));

  if (stop)
    idx_sync_stop = 1;
  if (!idx_sync_stop) {
    call_out(idx_sync, get_sync_time());
  }
}


//!
void|mapping idx_get() {
#ifdef STORAGE_DEBUG
  mapping i;
  float t = gauge{ i = _idx_get(); };
  write("STORAGE: index load took %f second\n", t);
  write("STORAGE: result = %O\n", i);
  return i;
}

//!
void|mapping _idx_get() {
#endif
  string ipath = Stdio.append_path(path, "storage_index");
  if (!Stdio.exist(ipath)) {
#ifdef STORAGE_DEBUG
    write("STORAGE: Unable to load index - file %O doesn't exist\n", ipath);
#endif
    return 0;
  }
  string s;

  catch(s = read_file(ipath));

  if (!stringp(s)) {
#ifdef STORAGE_DEBUG
    write("STORAGE: Unable to load index - no contents");
#endif
    return 0;
  }

  mixed p;
  if (mixed err = catch(p = decode(s))) {
#ifdef STORAGE_DEBUG
    write("STORAGE: Unable to load index - exception during decode.\n");
    throw(err);
#endif
    return 0;
  }

  if (!mappingp(p))
    return 0;

#ifdef STORAGE_DEBUG
  write("loading index file %O: %O\n", ipath, p);
#endif
  return p;
}

mapping idx_size_get()
{
  string s;
  mapping idx_sz;
  string ipath = Stdio.append_path(path, "storage_size");
  catch(s = read_file(ipath));

  if (mixed err = catch(idx_sz = decode(s))) {
#ifdef STORAGE_DEBUG
    write("STORAGE: Unable to load index - exception during decode.\n");
    throw(err);
#endif
    return ([]);
  }

  if (!mappingp(idx_sz))
    return ([]);

#ifdef STORAGE_DEBUG
  write("loading index size file %O: %O\n", ipath, idx_sz);
#endif
  
  return idx_sz;
}

//!
void idx_rm(string namespace, void|string key) {
#ifdef STORAGE_DEBUG
  write("STORAGE INDEX: rm %O %O\n", namespace, key);
#endif
  if (!key) {
    if (idx[namespace])
    {
      m_delete(idx, namespace);
      m_delete(idx_sz, namespace);
    }
  }
  if (idx[namespace]) {
    if (idx[namespace][key])
    {
      m_delete(idx[namespace], key);
      catch(m_delete(idx_sz[namespace], key));
    }
  }
}

//!
void stop() {
  idx_sync(1);
  flush();
}

int write_file(string filename, string content) {
  return Stdio.write_file(filename, content);
}

string read_file(string filename) {
  return Stdio.read_file(filename);
}
