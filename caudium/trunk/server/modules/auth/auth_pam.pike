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
 * PAM User Authentication. Uses the System.PAM module to authenticate
 * users via PAM.
 */

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: PAM";
constant module_doc  = "Experimental module for authorization using "
	      "Pluggable Authentication Modules (PAM).";
constant module_unique = 1;

#if constant(System.PAM)

/*
 * Globals
 */
object pam;

/*
 * Statistics
 */

int succ, fail, nouser;

string status()
{
  return("<h1>Security info</h1>\n"
	 "<b>PAM Service:</b> " + QUERY(service + "<br>\n"
	 "<p>\n"
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

  pam->start(user, conv);
  pam->open_session(0);
  pam->setcred(0);

  result = pam->authenticate(password, 0);

  pam->close_session(0);
  pam->end(0);
  
  if(result == System.PAM.PAM_SUCCESS)
    return 1;

  else return -1;
}

mixed conv(string user, mixed data, array c)
{
//  write("user: %s\n data: %O\n conv: %O\n", user, data, c);
  if(stringp(data))
    return ({({data, 1})});
  else
    return ({({"whee", 1})});
}


/*
 * Registration and initialization
 */

void start(int i)
{
  if (!pam && QUERY(service)) 
  {
    pam = System.PAM(QUERY(service));
  }
}

string query_provides()
{
  return "authentication";
}

void create()
{
defvar("service", "caudium",
         "PAM Service Name",
         TYPE_STRING,
         "Specifies the PAM service name to use when selecting"
         " a PAM profile (typically defined in /etc/pam.conf or /etc/pam.d.)");

}
#endif /* constant(System.PAM) */
