/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
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

#include <module.h>


inherit "modules/filesystems/filesystem";

constant cvs_version= "$Id$";

constant module_type = MODULE_LOCATION;
constant module_name = "Incoming filesystem";
constant module_doc  = "This is a virtual filesystem than can be used only for uploads, not "
                       "downloads.";
constant module_unique = 0;

static class decaying_file {

  inherit Stdio.File;

  static int rate, left;
  static function other_read_callback;
  static int crot;


  constant rotten_bits = "muahaha!(%/?\"&?�/&?(/?_,-.,_:;Ѭ��";


  static string decay(string data)
  {
    if(sizeof(data)<=left) {
      left -= sizeof(data);
      return data;
    }
    string newdata = "";
    while(sizeof(data)>left) {
      newdata += data[..left-1];
      newdata += rotten_bits[crot..crot];
      data = data[left+1..];
      left = rate;
      if(++crot >= sizeof(rotten_bits))
	crot = 0;
    }
    left -= sizeof(data);
    return newdata + data;
  }


  string read(mixed ... args)
  {
    string r = ::read(@args);
    if(stringp(r))
      r = decay(r);
    return r;
  }

  static mixed my_read_callback(mixed id, string data)
  {
    if(stringp(data))
      data = decay(data);
    return other_read_callback(id, data);
  }

  void set_read_callback(function read_callback)
  {
    if(read_callback) {
      other_read_callback = read_callback;
      ::set_read_callback(my_read_callback);
    } else
      ::set_read_callback(read_callback);
  }

  void set_nonblocking(function ... args)
  {
    if(sizeof(args) && args[0]) {
      other_read_callback = args[0];
      ::set_nonblocking(my_read_callback, @args[1..]);
    } else
      ::set_nonblocking(@args);
  }

  int query_fd()
  {
    return -1;
  }

  void create(object f, int s, int r)
  {
    assign(f);
    rate = r-1;
    if(rate<0)
      rate=0;
    left = s;
    crot = 0;
  }
}


void create()
{
  ::create();

  defvar("bitrot", 0,
	 "Scrambled downloads: Return files with bitrot", TYPE_FLAG,
	 "If this function is enabled, downloads <i>are</i> allowed, "
	 "but the files will be scrambled.");

  defvar("bitrot_header", 2376,
	 "Scrambled downloads: Unscrambled header length", TYPE_INT,
	 "Number of bytes to be sent without any bitrot at all.", 0,
	 lambda(){ return !QUERY(bitrot); });
	 
  defvar("bitrot_percent", 3,
	 "Scrambled downloads: Percent of bits to rot", TYPE_INT,
	 "Selects the percentage of the file that will receive bitrot", 0,
	 lambda(){ return !QUERY(bitrot); });
}

static mixed not_allowed( object id )
{
  id->misc->moreheads = (id->misc->moreheads||([]))|(["allow":"PUT"]);
  id->misc->error_code = 405;
  return 0;
}


#define FILE_SIZE(X) (stat_cache?_file_size((X),id):Stdio.file_size(X))


static mixed lose_file( string f, object id )
{
  object o;
  int size = FILE_SIZE( f = path + f );
  if(size < 0)
    return (size==-2? -1:0);

  o = open( f, "r" );

  if(!o)
    return 0;

  id->realfile = f;
  accesses++;

  return decaying_file( o, QUERY(bitrot_header), 100/QUERY(bitrot_percent) );
}

mixed find_file( string f, object id )
{
  switch(id->method) {
  case "GET":
  case "HEAD":
  case "POST":
    if(QUERY(bitrot) && QUERY(bitrot_percent)>0)
      return lose_file( f, id );
    else
      return not_allowed( id );

  case "PUT":
    if(FILE_SIZE( path + f ) >= 0) {
      id->misc->error_code = 409;
      return 0;
    }
    return ::find_file( f, id );

  case "DELETE":
  default:
    return not_allowed( id );
  }

  report_error("Not reached..\n");
  return 0;
}
 
