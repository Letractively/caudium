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
#define FUNLOCK() destruct(__fkey);
#else
#define PREFLOCK()
#define FLOCK(X,Y,Z) ({X, Y, Z})
#define FUNLOCK()
#endif

static string path;

void create(string _path) {
  PRELOCK();
  LOCK();
  path = _path;
  if (!Stdio.is_dir(path))
    Stdio.mkdirhier(path);
}

void store(string namespace, string key, string value) {
  PRELOCK();
  LOCK();
  string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
  PREFLOCK();
  FLOCK(objpath, "w", 1);
  Stdio.write_file(objpath, encode(namespace, key, value));
}

mixed retrieve(string namespace, string key) {
  PRELOCK();
  LOCK();
  string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
  if (Stdio.exist(objpath)) {
    PREFLOCK();
    FLOCK(objpath, "r", 1);
    //return decode(Stdio.read_file(objpath))->value;
    mixed tmp = decode(Stdio.read_file(objpath));
    if(mappingp(tmp) && (tmp->value))
      return tmp->value;
    else
      return 0;
  }
  else
    return 0;
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  LOCK();
  PREFLOCK();
  string _path = path;
  UNLOCK();
  if (stringp(key)) {
    string objpath = Stdio.append_path(path, get_hash(sprintf("%s|%s", namespace, key)));
    if (Stdio.exist(objpath)) {
      FLOCK(objpath, "w", 1);
      rm(objpath);
      FUNLOCK();
    }
  }
  else {
    array dir = get_dir(_path)?get_dir(_path):({});
    foreach(dir, string fname) {
      string objpath = Stdio.append_path(_path, fname);
      mapping obj = decode(Stdio.read_file(objpath));
      if (mappingp(obj))
        if (obj->namespace == namespace) {
          FLOCK(objpath, "w", 1);
          rm(objpath);
	  FUNLOCK();
        }
      else {
        FLOCK(objpath, "w", 1);
	rm(objpath);
	FUNLOCK();
      }
    }
  }
}

void unlink_regexp(string namespace, string regexp) {
  PRELOCK();
  PREFLOCK();
  LOCK();
  string _path = path;
  UNLOCK();
  object r = Regexp(regexp);
  array dir = get_dir(path);
  if (arrayp(dir))
    foreach(dir, string fname) {
      string objpath = Stdio.append_path(_path, fname);
      FLOCK(objpath,"r",1);
      mapping p;
      if (catch(p = decode(Stdio.read_file(objpath)))) {
        FUNLOCK();
        continue;
      }
      FUNLOCK();
      if (!mappingp(p))
        continue;
      if (p->namespace = namespace)
        if (r->match(p->key)) {
          FLOCK(objpath, "w", 1);
	  rm(objpath);
	  FUNLOCK();
        }
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
  PREFLOCK();
  int total;
  array dir = get_dir(path);
  if (arrayp(dir))
    foreach(dir, string fname) {
      string objpath = Stdio.append_path(path, fname);
      FLOCK(objpath, "r", 1);
      mapping p;
      if (catch(p = decode(Stdio.read_file(objpath))))
        continue;
      if (!mappingp(p))
        continue;
      if (p->namespace == namespace) {
        string data = decode(Stdio.read_file(objpath))->value;
        FUNLOCK();
        total += sizeof(data);
      }
    }
}

array list(string namespace) {
  PREFLOCK();
  array ret = ({ });
  array dir = get_dir(path)?get_dir(path):({});
  foreach(get_dir(path), string fname) {
    string objpath = Stdio.append_path(path, fname);
    FLOCK(objpath, "r", 1);
    mapping obj = decode(Stdio.read_file(objpath));
    if (mappingp(obj))
      if (obj->namespace == namespace) {
        string key = decode(Stdio.read_file(objpath))->key;
        ret += ({ key });
      }
    FUNLOCK();
  }
}
