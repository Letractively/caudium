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

// username,passwd,uid,gid,homedir,shell

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: SQL Database";
constant module_doc  = "Module documentation";
constant module_unique = 0;

/*
 * Global Variables
 */

string sqldb="";
string user_table="";
string group_table="";
string usergroup_table="";

/*
 * Registration and initialization
 */

void start(int i)
{
  if(query("sqlserver"))
    sqldb=query("sqlserver");
  if(query("usertable"))
    user_table=query("usertable");
  if(query("grouptable"))
    group_table=query("grouptable");
  if(query("usergrouptable"))
    usergroup_table=query("usergrouptable");
}

void stop()
{
}

void create()
{
defvar("sqlserver", "",
         "SQL Data Source URL",
         TYPE_STRING,
         "The SQL URL of the database containing the authentication tables.");
defvar("usertable", "users",
	"User Table",
	TYPE_STRING,
	"The name of the table containing user data.");
defvar("grouptable", "groups",
	"Group Table",
	TYPE_STRING,
	"The name of the table containing group data.");
defvar("usergrouptable", "user_group",
	"User to Group Table",
	TYPE_STRING,
	"The name of the table containing the user to group mapping.");
defvar("passwordformat", "Crypt",
	"Password Format",
	TYPE_SELECT,
	"Password storage format. Choose the method used to store user passwords."
	({"Crypt", "MD5", "SHA1", "Plaintext"}));
defvar("user_usernamef", "username",
	"Fields: User/Username"
	TYPE_SELECT,
	"The name of the field containing the user name.",
	list_user_fields());
defvar("group_groupnamef", "groupname",
	"Fields: Group/Groupname"
	TYPE_SELECT,
	"The name of the field containing the group name.",
	list_group_fields());
}

array list_user_fields()
{
  return ({});
}

array list_group_fields()
{
  return ({});
}

array list_usergroup_fields()
{
  return ({});
}

string query_provides()
{
  return "authentication";
}


string status()
{
  return "";
}

/*
 * Auth functions
 */

mapping|int get_user_info(string u)
{
  return 0;
}


mapping|int get_group_info(string g)
{
  return 0;
}

array(string) list_all_users()
{
  return ({});
}

array(string) list_all_groups()
{
  return ({});
}

string|int get_username(int|string uid)
{
  return 0;
}

string|int get_groupname(int|string gid)
{
  return 0;
}

int authenticate(string user, string password)
{
  return 0;
}

