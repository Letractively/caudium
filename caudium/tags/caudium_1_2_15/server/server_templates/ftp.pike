/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

/*
 * $Id$
 *
 * FTP server template 
 */

#include <module.h>

constant name = "FTP server";
constant desc = "An FTP server, with a preconfigured FTP port.";
constant modules = ({ "filesystem#0", "userdb#0", "htaccess#0", });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

void post(object node)
{
  object o,o2;
  if (o = node->descend("Global", 1)) {
    if (o2 = o->descend("Listen ports", 1)) {
      o2->data[VAR_VALUE] = ({ ({ 21, "ftp", "ANY", "" }) });
    }
    if (o2 = o->descend("Allow named FTP", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
    if (o2 = o->descend("Messages", 1)) {
      o2->folded = 0;
      o2->change(1);
      if (o2 = o2->descend("FTP Welcome", 1)) {
	o2->folded = 0;
	o2->change(1);
      }
    }
    if (o2 = o->descend("Shell database", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
  }
  if (o = node->descend("User database and security", 1)) {
    object o2;
    if (o2 = o->descend("Password database request method", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
    if (o2 = o->descend("Password database file", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
  }
}
