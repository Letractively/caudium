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
 * $Id$
 */

//! Storage Module : Disk method.

/*
 * The Storage module and the accompanying code is Copyright © 2002 James Tyson.
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

#define SYNCTIME 30

static string path;
mapping idx;
static mapping _size;
array _sending;
int idx_sync_stop;

//!
void create(string _path) {
  _sending = ({});
  path = _path;
  _size = ([]);
  idx = idx_get();
  if (!mappingp(idx)) {
    idx = ([]);
  }
  else 
  call_out(idx_sync, SYNCTIME);
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
  Stdio.write_file(objpath, encode(namespace, key, value));
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
    string s = Stdio.read_file(objpath);
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
  return MIME.encode_base64(data, 1);
}

//!
static mixed decode(string data) {
  program p;
  object e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  if (mixed err = catch(p = compile_string(MIME.decode_base64(data)))) {
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
  return Caudium.Crypto.hash_md5(namespace, 1) + "_" + Caudium.Crypto.hash_md5(key, 1);
}

//!
int size(string namespace) {
  if (_size[namespace])
    return _size[namespace];
  int total;
  array keys = list(namespace)||({});
  foreach(keys, string key) {
    string objpath = idx_path(namespace, key);
    string s;
    if (catch(s = Stdio.read_file(objpath))) {
      continue;
    }
    mapping p = decode(s);
    if (!mappingp(p))
      continue;
    mixed data = p->value;
    total += data?sizeof(data):0;
  }
  _size[namespace] = total;
  return total;
}

//!
array list(string namespace) {
  if (idx[namespace] && sizeof(idx[namespace]))
    return indices(idx[namespace]);
  array ret = ({});
  array dir = get_dir(path)||({});
  foreach(dir, string fname) {
    string objpath = Stdio.append_path(path, fname);
    string s = Stdio.read_file(objpath);
    mapping obj = decode(s);
    if (mappingp(obj))
      if (obj->namespace == namespace) {
        string key = decode(Stdio.read_file(objpath))->key;
        ret += ({ key });
	idx_path(namespace, key, objpath);
      }
  }
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
  if (!idx[namespace]) {
    idx[namespace] = ([]);
  }
  if (stringp(_path)) {
    idx[namespace] += ([ key : _path ]);
    return _path;
  }
  else {
    if (idx[namespace][key]) {
      return idx[namespace][key];
    }
    else {
      _path = Stdio.append_path(path, hash_path(namespace, key));
      idx[namespace] += ([ key : _path ]);
      return _path;
    }
  }
}

//!
void idx_sync(void|int stop) {
  string ipath = Stdio.append_path(path, "storage_index"); 
  string data = sprintf("/* Storage.Disk */\n\nmapping data = %O;\n\n", idx);
  data = MIME.encode_base64(data, 1);
  catch(Stdio.write_file(ipath, data));
  if (stop)
    idx_sync_stop = 1;
  if (!idx_sync_stop) {
    call_out(idx_sync, SYNCTIME);
  }
}


//!
mapping idx_get() {
#ifdef STORAGE_DEBUG
  float t = gauge{ _idx_get(); };
  write("STORAGE: index load took %f second\n", t);
}

//!
mapping _idx_get() {
#endif
  string ipath = Stdio.append_path(path, "storage_index");
  if (!Stdio.exist(ipath))
    return 0;
  string s;

  catch(s = Stdio.read_file(ipath));

  if (!stringp(s))
    return 0;

  mapping p;
  catch(p = decode(s));
    return 0;

  if (!mappingp(p))
    return 0;

#ifdef STORAGE_DEBUG
  write("loading index file %O: %O\n", ipath, p->data);
#endif
  return p->data;
}

//!
void idx_rm(string namespace, void|string key) {
  if (!key) {
    if (idx[namespace])
      m_delete(idx, namespace);
  }
  if (idx[namespace]) {
    if (idx[namespace][key])
      m_delete(idx[namespace], key);
  }
}

//!
void stop() {
  idx_sync(1);
  flush();
}
