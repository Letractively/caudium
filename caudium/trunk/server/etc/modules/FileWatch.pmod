/* I'm -*-Pike-*-, dude 
 *
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
 * $Id$
 */

//!  This Pike module provides a couple of classes that makes it possible for
//!  module programmers to watch a file and get a callback every time the file
//!  has changed (size, modification date, ownership and permission).

//!  This is the base class of the two watcher classes. You should never use
//!  this class directly since it actually doesn't do anything.
//! @seealso
//!  @[FileWatch.Threaded], @[FileWatch.Callout]
class _base {
  static int timeout;
  static string file;
  static function cb;
  static array|object last_stat;

  void create(string _file, int _timeout, function _cb) {
    file    = _file;
    cb      = _cb;
    timeout = _timeout;
    if(timeout <= 0) 
      throw( ({ "Invalid timeout '"+timeout+"', must be a positive integer.\n",
		backtrace() }));
    if(!functionp(cb))
      throw( ({ "Callback is not a function.\n", backtrace() }));
    last_stat = file_stat(file);
    if(!last_stat)
      throw( ({ "The file '"+file+"' doesn't exist.\n", backtrace() }));
  }
  int is_modified(array|object new_stat) {
    if(new_stat) {
      if(!last_stat 
	 || last_stat[0] != new_stat[0]
	 || last_stat[1] != new_stat[1]
	 || last_stat[3] != new_stat[3]
	 || last_stat[5] != new_stat[5]
	 || last_stat[6] != new_stat[6]) {
	return 1;
      } else
	return 0;
    } else if(last_stat) {
      return 1;
    } else
      return 0;
  }
  void do_callback(array|object new_stat) {
    int ret;
    if(is_modified(new_stat)) {
      ret = cb(file, last_stat, new_stat);
      last_stat = new_stat;
      if(ret < 0) 
	timeout = -1; /* stop watching */
      else if(ret > 0)
	timeout = ret; /* change timeout */
    } 
  }    
}

//!  This class used a call_out to call the function that checks the watched
//!  file for any modification. Any callbacks to the supplied function will
//!  therefor be run in the backend (main) thread. This class is more scalable
//!  than FileWatch.Threaded since Pike easily can handle more call_outs than
//!  threads.
//! @seealso
//!  @[FileWatch._base], @[FileWatch.Threaded]
class Callout {
  inherit _base;
  
  void create(mixed ... args) {
    ::create(@args);
    call_out(callback, timeout);
  }

  void callback() {
    if(!this_object()) { return; }
    array|object new_stat;
    new_stat = file_stat(file);
    catch { 
      do_callback(new_stat);
    };
    if(timeout > 0)
      call_out(callback, timeout);
  }
}

//!  This class keeps track of a file with a new thread. The benefit
//!  of this model is that the call back function will be running in this
//!  same thread. The drawback is that it's less scalable since each watched
//!  file uses one thread.
//! @note
//!  This class is, for obvious reasons, only available if the Pike supports
//!  threads. If threads are not supported, this class will be identical to
//!  FileWatch.Callout.
//! @seealso
//!  @[FileWatch._base], @[FileWatch.Callout]
class Threaded {
#if constant(thread_create) 
  inherit _base;
  
  void create(mixed ... args) {
    ::create(@args);
    thread_create(watcher);
  }

  void watcher() {
    array|object new_stat;
    while(this_object() && timeout > 0)
    {
      sleep(timeout);
      new_stat = file_stat(file);
      do_callback(new_stat);
    }
  }
#else
  inherit Callout;
#endif
}
