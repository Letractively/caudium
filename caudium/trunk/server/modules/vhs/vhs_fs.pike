/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

// #define USERFS_DEBUG 
// #define PASSWD_DISABLED ((us[1]=="") || (us[1][0]=='*'))
// vim: ts=2 sw=2 nowrap ai si st syn=pike
#define BAD_PASSWORD(us)				(QUERY(only_password) && \
                                 ((us[1] == "") || (us[1][0] == '*')))
#include <module.h>

inherit "modules/filesystems/filesystem" : filesystem;

constant cvs_version="$Id$";
constant module_type = MODULE_LOCATION;
constant module_name = "VHS - Virtual Filesystem";
constant module_doc  = "VHS - Virtual Filesystem";
constant module_unique = 0;
constant thread_safe = 1;

// #define VHFS_DEBUG 1

#ifdef VHFS_DEBUG
#define DW(x) werror("[VHS_fs] " + x + "\n")
#else
#define DW(x)
#endif

multiset allowedchars = mkmultiset("qwertyuiopasdfghjklzxcvbnm.-1234567890"/"");
array debug = allocate(2);
int bind_result;
int virtuals = 0;

void create()
{
  filesystem::create();

  killvar("searchpath");

  defvar("searchpath", "/var/www/", "Search path", TYPE_DIR,
				 "This is where the module will find the files in the real "+
				 "file system");

  set("mountpoint", "/");
}

void start()
{
  filesystem::start();
  path = "";
}

mixed getdata(string f, object id)
{
  if (!id->misc->vhs || !id->misc->vhs->wwwpath) return QUERY(searchpath);

  return id->misc->vhs->wwwpath;
}

mixed find_file(string f, object id)
{
  string u, of;
  of = f;

#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: find_file(%O, X)\n", f));
#endif /* USERFS_DEBUG */

	array st;
	mixed dir;

	dir = getdata(f, id);

	DW(sprintf("find_file: getdata(%O, X) = %O", f, dir));

	if (arrayp(dir))
	   return http_redirect("http://" + dir[1] + "/", id);

	if (dir == -2) return http_low_answer(400,sprintf("Invalid URL `%O' vs. `%O'", @debug));

	if (!dir) return 0;

	string path = dir + f;

	if (Stdio.is_dir(path))
	{
	   DW(sprintf("find_file: %s is directory", path));
	   DW("return -1;");

	   if (path[-1] != '/') return http_redirect(id->not_query + "/", id);

	   id->pragma["no-cache"] = 1;

	   return -1;
	}

	dir = replace(dir, "//", "/");

	// If public dir does not exist, or is not a directory 
	st = filesystem::stat_file(dir, id);

	if (!st || st[1] != -2) return 0;	// File not found.

	DW(sprintf("find_file: f = %O", f));

	f = dir + f;

	mixed tmpres = filesystem::find_file( f, id );
	
	DW(sprintf("find_file: filesystem::find_file( %O, X ) = %O", f, tmpres));

	return tmpres;
}

mixed real_file(string f, object id)
{
  string u, of;
  of=f;
	array st;
	mixed dir;

	DW("real_file / "+ f);

	dir = getdata(f, id);

	if (arrayp(dir) || dir == -2 || !dir) return 0;

	dir = replace(dir, "//", "/");

	f = dir + f;

	DW("real_file: returning " + f);

	return f;
	
}

mixed stat_file(string f, object id)
{
  string u, of;
  of=f;

	array st;

	mixed dir;

	dir = getdata(f, id);
	if(dir==-2 || !dir) return 0;
	dir = replace(dir, "//", "/");

	f = dir + f;
	
	return filesystem::stat_file( f, id );
}

mixed find_dir(string f, object id)
{
  string u, of;
  of = f;

#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: find_dir(%O, X)\n", f));
#endif /* USERFS_DEBUG */

	array st;
	mixed dir;

	dir = getdata(f, id);

	if (dir == -2)
           return http_string_answer(sprintf("Invalid URL `%O' vs. `%O'", @debug));

	dir = replace(dir, "//", "/");

	DW(sprintf("find_dir: getdata(%O, id) = %O", f, dir));
        DW(sprintf("find_dir: backtrace() = %O", this_thread()->backtrace()));

	// If public dir does not exist, or is not a directory 
	st = filesystem::stat_file(dir, id);

	if (!st || st[1] != -2)
	   return 0;				// File not found.

	DW(sprintf("f = %O", f));

	f = dir + f;

	array dirls;

	dirls = get_dir(f);

	if (!dirls) return 0;
	
	DW(sprintf("dirls = %O", dirls));
	
	// Access to this dir is not allowed.
	if (sizeof(dirls & ({".nodiraccess",".www_not_browsable",".nodir_access"})))
	   return 0;
	
	DW(sprintf("find_dir( %O, X ) = %O", f, dirls));

	return dirls;
}

string status()
{
  string result = "<br>\n<h3>Module enabled<h3>\n";

  return result;
}

