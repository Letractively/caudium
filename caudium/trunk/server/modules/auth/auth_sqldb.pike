/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: SQL Database";
constant module_doc  = "Authentication provider that uses an SQL"
  " database as a source of user and group information.";
constant module_unique = 0;

/*
 * Global Variables
 */

string sqldb="";
string user_table="";
string group_table="";
string usergroup_table="";

string query_getuserbyname="";
string query_getuserbyuserid="";
string query_getgroupbyname="";
string query_getgroupbygroupid="";

string query_getusersforgroup="";
string query_getgroupsforuser="";

array tables=({});

/*
 * Registration and initialization
 */

//
// check variables.
//
void|string check_variable(string name, mixed value)
{
  if(name=="sqlserver" && value=="")
    return "You must provide a SQL URL for this setting.";
  else if(name=="sqlserver" && catch(Sql.sql(value)))
    return "Unable to connect to SQL server " + value + ".";

  else if(name=="usertable" && value=="")
    return "You must provide a value for this setting.";

  else if(name=="grouptable" && value=="")
    return "You must provide a value for this setting.";

  else if(name=="usergrouptable" && value=="")
    return "You must provide a value for this setting.";

  else if(name=="usertable" || name=="grouptable" || name=="usergrouptable")
  {
    if(QUERY(sqlserver))
    {
      object o=Sql.sql(QUERY(sqlserver));
      if(catch(o->list_fields(value)))
      {
        return "Unable to find table " + value + ".";
      }
    }
    else return "You must configure your database connection first.";

  }
  else if(name=="user_otherf")
  {
     array f=((value-"")/",");
     object o=Sql.sql(QUERY(sqlserver));
     foreach(f, string field)
     {
       array x;
       if(catch(x=o->list_fields(QUERY(usertable), field)))
       {
         return "Unable to find table " + QUERY(usertable) + ".";
       }
       else
       {
         int found=0;
         foreach(x, mapping fx)
         {
           if(lower_case(fx->name) == lower_case(field))
             found=1;
         }
         if(!found)
           return "Unable to find field " + field + " in table " + 
             QUERY(usertable) + ".";
       }
    }
  }
  else if(name=="group_otherf")
  {
     array f=((value-"")/",");
     object o=Sql.sql(QUERY(sqlserver));
     foreach(f, string field)
     {
       array x;
       if(catch(x=o->list_fields(QUERY(grouptable), field)))
       {
         return "Unable to find table " + QUERY(grouptable) + ".";
       }
       else
       {
         int found=0;
         foreach(x, mapping fx)
         {
           if(lower_case(fx->name) == lower_case(field))
             found=1;
         }
         if(!found)
           return "Unable to find field " + field + " in table " + 
             QUERY(grouptable) + ".";
       }
    }
  }

  else if(sizeof(name/"_")>1)
  {
    if(QUERY(sqlserver))
    {
    string table;

      if((name/"_")[0]=="user")
        table=QUERY(usertable);
      if((name/"_")[0]=="group")
        table=QUERY(grouptable);
      if((name/"_")[0]=="usergroup")
        table=QUERY(usergrouptable);
    
      object o=Sql.sql(QUERY(sqlserver));
      array x;

      if(catch(x=o->list_fields(table, value)))
      {
        return "Unable to find table " + value + ".";
      }
      else
      {
        int found=0;
        foreach(x, mapping f)
        {
          if(lower_case(f->name) == lower_case(value))
          {
            found=1;
            break;
          }
        }
        if(!found)
          return "Field " + value + " doesn't exist in table " + table + ".";
        else return;
      }
    }
    else return "You must configure your database connection first.";
    
  }
}

void start(int i)
{

  if(QUERY(sqlserver))
    sqldb=QUERY(sqlserver);
  if(QUERY(usertable))
    user_table=QUERY(usertable);
  if(QUERY(grouptable))
    group_table=QUERY(grouptable);
  if(QUERY(usergrouptable))
    usergroup_table=QUERY(usergrouptable);

  setup_queries();
}

void setup_queries()
{
  if(user_table)
  {
    array usertablefields=({});

    usertablefields+=({QUERY(user_usernamef)});
    usertablefields+=({QUERY(user_uidf)});
    usertablefields+=({QUERY(user_fullnamef)});
    usertablefields+=({QUERY(user_passwordf)});

    if(QUERY(user_emailf)!="NONE")    
      usertablefields+=({QUERY(user_emailf)});
    if(QUERY(user_homedirectoryf)!="NONE")    
      usertablefields+=({QUERY(user_homedirectoryf)});

    if(QUERY(user_otherf) && sizeof(QUERY(user_otherf))>0)
      usertablefields+=({(QUERY(user_otherf)/",")});


    query_getuserbyname="SELECT " + usertablefields*", " + " FROM " + 
       user_table + " WHERE " + QUERY(user_usernamef) + "=";
    query_getuserbyuserid="SELECT " + usertablefields*", " + " FROM " + 
       user_table + " WHERE " + QUERY(user_uidf) + "=";

    werror("byname: " + query_getuserbyname + "\n\n");
    werror("byid: " + query_getuserbyuserid + "\n\n");
  }      

  if(group_table)
  {
    array grouptablefields=({});

    grouptablefields+=({QUERY(group_groupnamef)});
    grouptablefields+=({QUERY(group_groupidf)});
    grouptablefields+=({QUERY(group_fullnamef)});

    if(QUERY(group_otherf) && sizeof(QUERY(group_otherf))>0)
      grouptablefields+=({(QUERY(group_otherf)/",")});


    query_getgroupbyname="SELECT " + grouptablefields*", " + " FROM " + 
       group_table + " WHERE " + QUERY(group_groupnamef) + "=";

    query_getgroupbygroupid="SELECT " + grouptablefields*", " + " FROM " + 
       group_table + " WHERE " + QUERY(group_groupidf) + "=";

    werror("byname: " + query_getgroupbyname + "\n\n");
    werror("byid: " + query_getgroupbygroupid + "\n\n");
  }      

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
defvar("usergrouptable", "users_groups",
	"User to Group Table",
	TYPE_STRING,
	"The name of the table containing the user to group mapping.");
defvar("passwordformat", "Crypt",
	"Password Format",
	TYPE_STRING,
	"Password storage format. Choose the method used to store user passwords.",
	({"Crypt", "MD5", "SHA1", "Plaintext"}));
defvar("user_usernamef", "",
	"Fields: User- Username",
	TYPE_STRING,
	"The name of the field containing the user name.");
defvar("user_uidf", "",
	"Fields: User- User ID",
	TYPE_STRING,
	"The name of the field containing the numeric user id.");
defvar("user_homedirectoryf", "",
	"Fields: User- Home Directory",
	TYPE_STRING,
	"The name of the field containing the user's home directory (optional).");
defvar("user_fullnamef", "",
	"Fields: User- Full Name",
	TYPE_STRING,
	"The name of the field containing the user's full name.");
defvar("user_emailf", "",
	"Fields: User- Email Address",
	TYPE_STRING,
	"The name of the field containing the user's email address (optional).");
defvar("user_otherf", "",
	"Fields: User- Additional fields",
	TYPE_STRING,
	"Additional fields to include in the user record (optional).");
defvar("user_passwordf", "",
	"Fields: User- Password",
	TYPE_STRING,
	"The name of the field containing the user's password.");
defvar("group_groupnamef", "",
	"Fields: Group- Groupname",
	TYPE_STRING,
	"The name of the field containing the group name.");
defvar("group_fullnamef", "",
	"Fields: Group- Full Name",
	TYPE_STRING,
	"The name of the field containing the full name of the group.");
defvar("group_groupidf", "",
	"Fields: Group- Group ID",
	TYPE_STRING,
	"The name of the field containing the group ID number.");
defvar("group_otherf", "",
	"Fields: Group- Additional fields",
	TYPE_STRING,
	"Additional fields to include in the group record (optional).");
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

