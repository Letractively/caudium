/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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
 *
 * PATH_INFO support for Roxen.
 *
 * Henrik Grubbström 1998-10-01
 */

#include <module.h>

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;

// #define PATHINFO_DEBUG

constant module_type = MODULE_LAST;
constant module_name = "PATH_INFO support";
constant module_doc  = "Support for PATH_INFO style URLs.";
constant module_unique = 1;

array register_module()
{
  return ({ MODULE_LAST, "PATH_INFO support",
	    "Support for PATH_INFO style URLs.",
	    0, 1 });
}

mapping|int last_resort(object id)
{
#ifdef PATHINFO_DEBUG
  roxen_perror(sprintf("PATHINFO: Checking %O...\n", id->not_query));
#endif /* PATHINFO_DEBUG */
  if (id->misc->path_info) {
    // Already been here...
#ifdef PATHINFO_DEBUG
    roxen_perror(sprintf("PATHINFO: Been here, done that.\n"));
#endif /* PATHINFO_DEBUG */
    return 0;
  }
  array(int) offsets = Array.map(id->not_query/"/", sizeof);

  int sum = 0;
  int i;
  for (i=0; i < sizeof(offsets); i++) {
    sum = (offsets[i] += sum) + 1;
  }

  int lo = (offsets[0] != 0);	// Skip testing the empty string.
  int hi = sizeof(offsets) - 1;

  while(lo <= hi) {		// Don't let the beams cross.
    int probe = (lo + hi)/2;
    string file = id->not_query[..offsets[probe]-1];

#ifdef PATHINFO_DEBUG
    roxen_perror(sprintf("PATHINFO: Trying %O...\n", file));
#endif /* PATHINFO_DEBUG */

    array st = id->conf->stat_file(file, id);
    if (st) {
      if (st[1] >= 0) {
	// Found a file!
	id->misc->path_info = id->not_query[offsets[probe]..];
	id->not_query = file;
#ifdef PATHINFO_DEBUG
	roxen_perror(sprintf("PATHINFO: Found: %O:%O\n",
			     id->not_query, id->misc->path_info));
#endif /* PATHINFO_DEBUG */
	return 1;	// Go through id->handle_request() one more time...
      }
#ifdef PATHINFO_DEBUG
      roxen_perror(sprintf("PATHINFO: Directory: %O\n", file));
#endif /* PATHINFO_DEBUG */

      lo = probe + 1;
    } else {
      hi = probe - 1;
    }
  }
  return 0;
}
