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

constant storage_type    = "Disk";
constant storage_doc     = "Please enter the path on the filesystem that you would like to "
                           "store the data in."
#ifdef NFS_LOCK
                           " <i>Using NFS safe hitchingpost file locking, this is good "
			   "because it will stop multiple machines from writing to files "
			   "at the same time - however, it is possible that you can put "
			   "one or more machines in your cluster into what is essentially "
			   "a deadlock condition. Be careful.</i>"
#endif
                           ;
constant storage_default = "+";

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
#define KEY __fkey
#define FUNLOCK() destruct(__fkey);
#else
#define PREFLOCK()
#define FLOCK(X,Y,Z) ({X, Y, Z})
#define KEY 0
#define FUNLOCK()
#endif

#define SYNCTIME 30

static string path;
mapping idx;
static mapping _size;
array _sending;
int idx_sync_stop;

void create(string _path) {
  PRELOCK();
  LOCK();
  _sending = ({});
  path = _path;
  _size = ([]);
  idx = idx_get();
  if (!mappingp(idx)) {
    idx = ([]);
  }
  else 
  UNLOCK();
  call_out(idx_sync, SYNCTIME);
  if (!Stdio.is_dir(path))
    Stdio.mkdirhier(path);
#ifdef CACHE_DEBUG
  debug();
#endif
}

#ifdef CACHE_DEBUG
void debug() {
  if (sizeof(_sending))
    write("Writing files: %O\n", _sending);
  call_out(debug, 0.1);
}
#endif

void store(string namespace, string key, string value) {
  if (!namespace || !key)
    return;
  string objpath = idx_path(namespace, key);
  string data = encode(namespace, key, value);
  //Stdio.write_file(objpath, encode(namespace, key, value));
  catch(SendFile(data, objpath, sending, unsending));
}

void unlock(void|object key) {
  if (objectp(key))
    destruct(key);
}

mixed retrieve(string namespace, string key) {
  PRELOCK();
  if (!namespace || !key)
    return 0;
  string objpath = idx_path(namespace, key);
  if (Stdio.exist(objpath)) {
    PREFLOCK();
    FLOCK(objpath, "r", 1);
    string s = Stdio.read_file(objpath);
    FUNLOCK();
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
      FLOCK(objpath, "w", 1);
      rm(objpath);
      FUNLOCK();
      return 0;
    }
  }
  else {
    idx_rm(namespace, key);
    return 0;
  }
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  PREFLOCK();
  if (!namespace)
    return;
  if (!stringp(key)) {
    array keys = list(namespace);
    foreach(keys, string _key) {
      string objpath = idx_path(namespace, _key);
      idx_rm(namespace, _key);
      if (Stdio.exist(objpath)) {
        FLOCK(objpath, "w", 1);
        rm(objpath);
        FUNLOCK();
      }
    }
    idx_rm(namespace);
    return;
  }
  string objpath = idx_path(namespace, key);
  idx_rm(namespace, key);
  if (Stdio.exist(objpath)) {
    FLOCK(objpath, "w", 1);
    rm(objpath);
    FUNLOCK();
  }
}

void unlink_regexp(string namespace, string regexp) {
  PRELOCK();
  PREFLOCK();
  object r = Regexp(regexp);
  array keys = list(namespace);
  foreach(keys, string key) {
    if (!r->match(key))
      continue;
    string objpath = idx_path(namespace, key);
    idx_rm(namespace, key);
    FLOCK(objpath, "w", 1);
    rm(objpath);
    FUNLOCK();
  }
}

static string encode(string namespace, string key, string value) {
  mapping tmp = ([ "namespace" : namespace, "key" : key, "value" : value ]);
  string data = sprintf("/* Storage.Disk */\n\nmapping data = %O;\n", tmp);
  return MIME.encode_base64(data, 1);
}

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

static string get_hash( string data ) {
  string retval;
  retval = Caudium.Crypto.hash_md5(data);
  return sprintf("%@02x",(array(int)) retval);
}

int size(string namespace) {
  if (_size[namespace])
    return _size[namespace];
  PREFLOCK();
  int total;
  array keys = list(namespace)||({});
  foreach(keys, string key) {
    string objpath = idx_path(namespace, key);
    string s;
    FLOCK(objpath, "r", 1);
    if (catch(s = Stdio.read_file(objpath))) {
      FUNLOCK();
      continue;
    }
    FUNLOCK();
    mapping p = decode(s);
    if (!mappingp(p))
      continue;
    mixed data = p->value;
    total += data?sizeof(data):0;
  }
  _size[namespace] = total;
  return total;
}

array list(string namespace) {
  PREFLOCK();
  if (idx[namespace] && sizeof(idx[namespace]))
    return indices(idx[namespace]);
  array ret = ({});
  array dir = get_dir(path)||({});
  foreach(dir, string fname) {
    string objpath = Stdio.append_path(path, fname);
    FLOCK(objpath, "r", 1);
    string s = Stdio.read_file(objpath);
    FUNLOCK();
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

void flush() {
  if (sizeof(_sending)) {
    _sending->flush();
    while(sizeof(_sending))
      _do_call_outs();
  }
}

static void sending(object o) {
  PRELOCK();
  LOCK();
  _sending += ({ o });
  UNLOCK();
}

static void unsending(object o) {
  PRELOCK();
  LOCK();
  _sending -= ({ o });
  UNLOCK();
}

string idx_path(string namespace, string key, void|string _path) {
  PRELOCK();
  if (!idx[namespace]) {
    LOCK();
    idx[namespace] = ([]);
    UNLOCK();
  }
  if (stringp(_path)) {
    LOCK();
    idx[namespace] += ([ key : _path ]);
    UNLOCK();
    return _path;
  }
  else {
    _path = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
    LOCK();
    idx[namespace] += ([ key : _path ]);
    UNLOCK();
    return _path;
  }
}

void idx_sync(void|int stop) {
  PREFLOCK();
  string ipath = Stdio.append_path(path, "storage_index"); 
  FLOCK(ipath, "w", 1);
  string data = sprintf("/* Storage.Disk */\n\nmapping data = %O;\n\n", idx);
  data = MIME.encode_base64(data, 1);
  //catch(Stdio.write_file(ipath, data));
  catch(SendFile(data, ipath, sending, unsending));
  FUNLOCK();
  if (stop)
    idx_sync_stop = 1;
  if (!idx_sync_stop) {
    call_out(idx_sync, SYNCTIME);
  }
}


mapping idx_get() {
  PREFLOCK();
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

#ifdef CACHE_DEBUG
  write("loading index file %O: %O\n", ipath, p->data);
#endif
  return p->data;
}

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

void stop() {
  idx_sync(1);
  flush();
}

class SendFile {

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

#define BLOCKSIZE 4096

#ifdef NFS_LOCK
  static object hitch = HitchingPost;
#endif

  static string from;
  static string to;
  static object fto;
  static object key;
  static int pos;
  function start;
  function stop;
  static int _flush;

  void create(string _from, string _to, function _start, function _stop) {
    PRELOCK();
    LOCK();
    from = _from;
    to = _to;
    start = _start;
    stop = _stop;
    key = lock("w");
    start(this_object());
  #ifdef CACHE_DEBUG
    write("[%s] sending %d bytes.\n", to, sizeof(from));
  #endif
    fto = Stdio.File(to, "cwt");
    UNLOCK();
    // non-blocking doesn't work on disk files, for me anyway.
    // could do with a better solution.
    //fto->set_nonblocking(0, write_cb, close_cb);
    writeloop();
  }

  void writeloop() {
    if (pos != -1) {
      write_cb();
      call_out(writeloop, 0);
    }
  }

  void flush() {
    _flush = 1;
  }

  void write_cb() {
    if ((pos > sizeof(from)) || (pos == -1)) {
#ifdef CACHE_DEBUG
      write("[%s] end of file, closing.\n", to);
#endif
      pos = -1;
      close_cb(0);
    }
    else {
      if (_flush) {
#ifdef CACHE_DEBUG
	write("[%s] flushing file from position %d\n", to, pos);
#endif
	fto->write(from[pos..]);
	pos = -1;
	close_cb(0);
      }
      else if (sizeof(from) > pos + BLOCKSIZE) {
#ifdef CACHE_DEBUG
	write("[%s] writing %d bytes from position %d\n", to, BLOCKSIZE, pos);
#endif
	fto->write(from[pos..(pos+BLOCKSIZE)]);
	pos += BLOCKSIZE + 1;
      }
      else {
#ifdef CACHE_DEBUG
	write("[%s] writing %d bytes from position %d\n", to, sizeof(from) - pos, pos);
#endif
	fto->write(from[pos..]);
	pos = -1;
	close_cb(0);
      }
    }
  }

  void close_cb(int errno) {
#ifdef CACHE_DEBUG
    write("[%s] closing file.\n", to);
#endif
    fto->close();
    if (errno)
      rm(to);
    unlock(key);
    stop(this_object());
    destruct(this_object());
  }

#ifdef NFS_LOCK
  object lock(string t) {
    return hitch->lock(to, t, 1);
  }
#else

  class FakeLock() {
  }

  object lock(string t) {
    return FakeLock();
  }
#endif

  void unlock(void|object l) {
    if (objectp(l)) {
      PRELOCK();
      LOCK();
      destruct(l);
      UNLOCK();
    }
  }

  string _sprintf() {
    return sprintf("SendFile(%O /* %d%% */)", to, (int)(((float)pos / (float)sizeof(from)) * 100));
  }

}
