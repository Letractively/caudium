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

//! This module implements NFS safe "hitching post" file locking.
//! This is for Storage.pmod and Cache.pmod, but you can use it too, honest.

constant cvs_version = "$Id$";

#define SLEEP 0.2

static mapping locks;

void create() {
  locks = ([]);
}

mixed cast(string to) {
  switch(to){
  case "string":
    string ret = "";
    if (sizeof(locks))
      foreach(indices(locks), mixed id) {
        ret += sprintf("%s,%s,%ds\n",locks[id]->path, locks[id]->mode, (time()-locks[id]->since));
      }
    else
      ret = "No files locked";
    return ret;
    break;
  case "int":
    return sizeof(locks);
    break;
  }
}

//! Attempt to lock a file.
//!
//! @param path
//! The full path to the file you want to lock
//!
//! @param mode
//! A string containing either "r", "w", or "rw" depending on whether you want
//! a read, write or read-write lock.
//!
//! @param behavior
//!
//! Changes the behavior on a failure to lock, 0 causes lock() to throw an error
//! when it's unable to acquire a lock, 1 states for it to sleep until it can.
object lock(string path, string mode, int behavior) {
  string ro = sprintf("%s.lock,r",path);
  string wo = sprintf("%s.lock,w",path);
  string rw = sprintf("%s.lock,rw",path);
  string acquire;
  array decline = ({ ro, rw, wo });
  string want;
  switch(mode) {
  case "r":
    want = "read";
    acquire = ro;
    break;
  case "w":
    want = "write";
    acquire = wo;
    break;
  case "rw":
  case "wr":
    want = "read-write";
    acquire = rw;
    break;
  }
  foreach(decline, string test) {
    if (Stdio.is_file(test))
      switch (behavior) {
      case 0:
        throw(({
	  sprintf("Unable to acquire %s lock on file %s\n", want, path),
	  backtrace()
	}));
	break;
      case 1:
        while(Stdio.is_file(test))
	  sleep(SLEEP);
        break;
      }
  }
  string dir = dirname(path);
  string tmp = Stdio.append_path(
    dir,
    sprintf(".%d.%d.%s",time(), getpid(), uname()->nodename)
  );
  object ftmp = Stdio.File();
  if (catch(ftmp->open(tmp,"cw")))
    throw(({
      sprintf("Unable to create hitching post for %s\n",path),
      backtrace()
    }));
  ftmp->close();
  object stat;
  if (catch(hardlink(tmp,acquire)))
    if (!catch(stat = file_stat(tmp))) {
      if (!objectp(stat)) {
        rm(tmp);
	throw(({
	  sprintf("Unable to stat hitching post %s\n", tmp),
	  backtrace()
	}));
      }
      if (stat->nlink != 2) {
        rm(tmp);
        throw(({
          sprintf("Unable to acquire %s lock on file %s\n", want, path),
          backtrace()
        }));
      }
    }
  string id = get_hash(path);
  locks += ([ id : 1 ]);
  locks[ id ] = ([
    "path" : path,
    "type" : want,
    "since" : time(),
    "lock_file" : acquire,
    "mode" : mode
  ]);
  return _lock(id, unlock, sprintf("%s,%s",path, mode));
}

static void unlock(mixed id) {
  rm(locks[id]->lock_file);
  m_delete(locks, id);
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


static class _lock {

//! This class is the object containing the hitchingpost lock.

  mixed id;
  static function unlock;
  static string desc;
  int since;

  void create(mixed _id, function _unlock, string _desc) {
    id = _id;
    desc = _desc;
    unlock = _unlock;
    since = time();
  }

  mixed cast(string to) {
    switch(to) {
    case "string":
      return sprintf("%s,%ds", desc, (time()-since));
    }
  }

  void destroy() {
    unlock(id);
  }

}
