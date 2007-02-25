/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2006 The Caudium Group
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
 * a simple authentication provider intended for use with the configuration
 * interface. only knows about a single user.
 */

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: Configuration Interface";
constant module_doc  = "Authentication provider intended for use with the Caudium "
                       "Configuration Interface (CIF)";
constant module_unique = 1;

/*
 * Statistics
 */

int succ, fail, nouser;

string status()
{
  return("<h1>Security info</h1>\n"
	 "<b>Successful auths:</b> " + (string)succ +
	 "<b>Failed auths:</b> " + (string)fail +
	 ", " + (string)nouser + " had the wrong username.<br>\n");
}

/*
 * Auth functions
 */

int authenticate(string user, string password)
{
  int result;
werror("r: %O\n", crypt(password, QUERY(password)));
  if(user == QUERY(username) && crypt(password, QUERY(password)))
    return 1;

  else return -1;
}

mapping|int get_user_info(string u)
{
  if(u == QUERY(username))
  {
    return (["username": QUERY(username), "uid": 1, "name": QUERY(username), "primary_group": 1, "groups": (<>), "superuser":1]);
  }

  else return 0;
}

/*
 * Registration and initialization
 */

void start(int i)
{
}

string query_provides()
{
  return "authentication";
}

void create()
{
defvar("username", "admin",
         "User Name",
         TYPE_STRING, "Username");

defvar("password", "",
         "Password",
         TYPE_PASSWORD, "Password");

}
