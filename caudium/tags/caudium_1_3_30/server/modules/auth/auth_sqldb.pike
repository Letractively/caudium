/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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

mixed conf;

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

string query_getusers="";
string query_getgroups="";

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
  else if(name=="sqlserver" && catch(Sql.Sql(value)))
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
      object o=Sql.Sql(QUERY(sqlserver));
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
     object o=Sql.Sql(QUERY(sqlserver));
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
     object o=Sql.Sql(QUERY(sqlserver));
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

  else if(name[0..0]!="_" && sizeof(name/"_")>1)
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
    
      object o=Sql.Sql(QUERY(sqlserver));
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

  conf=my_configuration();
  setup_queries();
}

void setup_queries()
{
  if(user_table)
  {
    array usertablefields=({});

    usertablefields+=({QUERY(user_usernamef) + " as _username"});
    usertablefields+=({QUERY(user_uidf) + " as _uid"});
    usertablefields+=({QUERY(user_fullnamef) + " as _fullname"});
    usertablefields+=({QUERY(user_gidf) + " as _primary_group"});
    usertablefields+=({QUERY(user_passwordf) + " as _password"});

    if(QUERY(user_emailf)!="")    
      usertablefields+=({QUERY(user_emailf) + " as _email"});
    if(QUERY(user_homedirectoryf)!="")    
      usertablefields+=({QUERY(user_homedirectoryf) + " as _home"});

    if(QUERY(user_otherf) && sizeof(QUERY(user_otherf))>0)
      usertablefields+=({(QUERY(user_otherf)/",")});

    if(QUERY(user_usernamef) && QUERY(usertable))
      query_getusers="SELECT " + QUERY(user_usernamef) + " AS _username FROM " +  QUERY(usertable);

    query_getuserbyname="SELECT " + usertablefields*", " + " FROM " + 
       user_table + " WHERE " + QUERY(user_usernamef) + "=%s";
    query_getuserbyuserid="SELECT " + usertablefields*", " + " FROM " + 
       user_table + " WHERE " + QUERY(user_uidf) + "=%s";
#ifdef AUTH_DEBUG
    report_debug("AUTH_SQL: byname: " + query_getuserbyname + "\n\n");
    report_debug("AUTH_SQL: byid: " + query_getuserbyuserid + "\n\n");
#endif
  }      

  if(group_table)
  {
    array grouptablefields=({});

    grouptablefields+=({QUERY(group_groupnamef) + " as _groupname"});
    grouptablefields+=({QUERY(group_groupidf) + " as _gid"});
    grouptablefields+=({QUERY(group_fullnamef) + " as _fullname"});

    if(QUERY(group_otherf) && sizeof(QUERY(group_otherf))>0)
      grouptablefields+=({(QUERY(group_otherf)/",")});

    if(QUERY(group_groupnamef) && QUERY(grouptable))
      query_getgroups="SELECT " + QUERY(group_groupnamef) + " AS _groupname FROM " +  QUERY(grouptable);

    query_getgroupbyname="SELECT " + grouptablefields*", " + " FROM " + 
       group_table + " WHERE " + QUERY(group_groupnamef) + "=%s";

    query_getgroupbygroupid="SELECT " + grouptablefields*", " + " FROM " + 
       group_table + " WHERE " + QUERY(group_groupidf) + "=%s";
#ifdef AUTH_DEBUG
    report_debug("AUTH_SQL: byname: " + query_getgroupbyname + "\n\n");
    report_debug("AUTH_SQL: byid: " + query_getgroupbygroupid + "\n\n");
#endif
  }      

  if(usergroup_table)
  {
    array usergrouptablefields=({});

    usergrouptablefields+=({QUERY(usergroup_groupf) + " as _group"});
    usergrouptablefields+=({QUERY(usergroup_userf) + " as _user"});

    query_getusersforgroup="SELECT " + usergrouptablefields*", " + " FROM " + 
       usergroup_table + " WHERE " + QUERY(usergroup_groupf) + "=%s";

    query_getgroupsforuser="SELECT " + usergrouptablefields*", " + " FROM " + 
       usergroup_table + " WHERE " + QUERY(usergroup_userf) + "=%s";

#ifdef AUTH_DEBUG
    report_debug("AUTH_SQL: bygroup: " + query_getusersforgroup + "\n\n");
    report_debug("AUTH_SQL: byuser: " + query_getgroupsforuser + "\n\n");
#endif
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
	TYPE_MULTIPLE_STRING,
	"Password storage format. Choose the method used to store user passwords.",
	({"Crypt", "MD5", "Plaintext"}));
defvar("user_usernamef", "",
	"Fields: User- Username",
	TYPE_STRING,
	"The name of the field containing the user name.");
defvar("user_gidf", "",
	"Fields: User- Group ID",
	TYPE_STRING,
	"The name of the field containing the numeric primary group id.");
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
defvar("usergroup_userf", "",
	"Fields: UserGroup- User field",
	TYPE_STRING,
	"Field in the user to group mapping table containing the user name.");
defvar("usergroup_groupf", "",
	"Fields: UserGroup- Group field",
	TYPE_STRING,
	"Field in the user to group mapping table containing the group name.");
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
 * Internal functions
 */

private array get_groups_for_user(string username, object s)
{
  if(!username || !s) return ({});
  array result=s->query(query_getgroupsforuser, username);
  if(!result || sizeof(result)==0) return ({});
  array groups=({});  
  foreach(result, mapping row)
    groups+=({row->_group});
  return groups;
}

private array get_users_for_group(string groupname, object s)
{
  if(!groupname || !s) return ({});
  array result=s->query(query_getusersforgroup, groupname);
  if(!result || sizeof(result)==0) return ({});
  array users=({});  
  foreach(result, mapping row)
    users+=({row->_user});
  return users;
}

/*
 * Auth functions
 */

mapping|int get_user_info(string u)
{
  if(!sqldb || query_getuserbyname=="") return 0;

  if(!u) return 0;

  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getuserbyname, (string)u);

  if(sizeof(result)!=1) return 0;
  
  mapping user=([]);

  user->username=result[0]->_username;
  user->primary_group=result[0]->_primary_group;  
  user->name=result[0]->_username;  
  user->uid=result[0]->_uid;  
  user->name=result[0]->_fullname;  
  if(result[0]->_home)
    user->home_directory=result[0]->_home;  
  if(result[0]->_email)
    user->email=result[0]->_email;  

  foreach(indices(result[0]), string f)
    if(f[0..0]=="_" || search(f, ".")!=-1)
      m_delete(result[0], f);

  user+=result[0];

  user->groups=(<>);
  
  user->groups=(multiset)(get_groups_for_user(user->username, s));

  user->_source=QUERY(_name);

#ifdef AUTH_DEBUG
  report_debug("AUTH_SQL: user res: %O\n", user);
#endif
  return user;
}


mapping|int get_group_info(string g)
{
  if(!sqldb || query_getgroupbyname=="") return 0;

  if(!g) return 0;

  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getgroupbyname, (string)g);

  if(sizeof(result)!=1) return 0;
  
  mapping group=([]);

  group->groupname=result[0]->_groupname;
  group->name=result[0]->_groupname;  
  group->gid=result[0]->_gid;  
  group->name=result[0]->_fullname;  

  foreach(indices(result[0]), string f)
    if(f[0..0]=="_" || search(f, ".")!=-1)
      m_delete(result[0], f);

  group+=result[0];

  group->users=(<>);
  
  group->users=(multiset)(get_users_for_group(group->name, s));

  group->_source=QUERY(_name);

  return group;

  return 0;
}

array(string) list_all_users()
{
  if(!sqldb || query_getusers=="") return ({});
  array res=({});

  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getusers);

  foreach(result, mapping row)
    res+=({row->_username});

  return res;
}

array(string) list_all_groups()
{
  if(!sqldb || query_getgroups=="") return ({});
  array res=({});

  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getgroups);

  foreach(result, mapping row)
    res+=({row->_groupname});

  return res;
}

string|int get_username(int|string uid)
{
  if(!sqldb || query_getuserbyuserid=="") return 0;

  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getuserbyuserid, (string)uid);
  if(sizeof(result) !=1) return 0;
  else
  {
    return result[0]->_username;
  }
  return 0;
}

string|int get_groupname(int|string gid)
{
  if(!sqldb || query_getgroupbygroupid=="") return 0;

  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getgroupbygroupid, (string)gid);
  if(sizeof(result) !=1) return 0;
  else
  {
    return result[0]->_groupname;
  }
  return 0;
}

int authenticate(string user, string password)
{
  if(!sqldb || query_getuserbyname=="") return 0;
  object s=conf->sql_connect(sqldb);
  mixed result=s->query(query_getuserbyname, (string)user);
  if(sizeof(result)!=1) return 0; // user not found.

  string auth_password=result[0]->_password;

  // should we really treat empty password field as no password?
  if(auth_password=="" && password=="") return 1;

  if(QUERY(passwordformat)=="Plaintext")
  {
    if(password==auth_password) return 1;
    else return -1;
  }
  
  if(QUERY(passwordformat)=="Crypt")
  {
    if(crypt(password, auth_password))
      return 1;
    else return -1;
  }

  if(QUERY(passwordformat)=="MD5")
  {
    if(Crypto.make_crypt_md5(password, auth_password) == auth_password)
      return 1;
    else return -1;
  }  

  return -1; // failed authentication.
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: sqlserver
//! The SQL URL of the database containing the authentication tables.
//!  type: TYPE_STRING
//!  name: SQL Data Source URL
//
//! defvar: usertable
//! The name of the table containing user data.
//!  type: TYPE_STRING
//!  name: User Table
//
//! defvar: grouptable
//! The name of the table containing group data.
//!  type: TYPE_STRING
//!  name: Group Table
//
//! defvar: usergrouptable
//! The name of the table containing the user to group mapping.
//!  type: TYPE_STRING
//!  name: User to Group Table
//
//! defvar: passwordformat
//! Password storage format. Choose the method used to store user passwords.
//!  type: TYPE_MULTIPLE_STRING
//!  name: Password Format
//
//! defvar: user_usernamef
//! The name of the field containing the user name.
//!  type: TYPE_STRING
//!  name: Fields: User- Username
//
//! defvar: user_gidf
//! The name of the field containing the numeric primary group id.
//!  type: TYPE_STRING
//!  name: Fields: User- Group ID
//
//! defvar: user_uidf
//! The name of the field containing the numeric user id.
//!  type: TYPE_STRING
//!  name: Fields: User- User ID
//
//! defvar: user_homedirectoryf
//! The name of the field containing the user's home directory (optional).
//!  type: TYPE_STRING
//!  name: Fields: User- Home Directory
//
//! defvar: user_fullnamef
//! The name of the field containing the user's full name.
//!  type: TYPE_STRING
//!  name: Fields: User- Full Name
//
//! defvar: user_emailf
//! The name of the field containing the user's email address (optional).
//!  type: TYPE_STRING
//!  name: Fields: User- Email Address
//
//! defvar: user_otherf
//! Additional fields to include in the user record (optional).
//!  type: TYPE_STRING
//!  name: Fields: User- Additional fields
//
//! defvar: user_passwordf
//! The name of the field containing the user's password.
//!  type: TYPE_STRING
//!  name: Fields: User- Password
//
//! defvar: group_groupnamef
//! The name of the field containing the group name.
//!  type: TYPE_STRING
//!  name: Fields: Group- Groupname
//
//! defvar: group_fullnamef
//! The name of the field containing the full name of the group.
//!  type: TYPE_STRING
//!  name: Fields: Group- Full Name
//
//! defvar: group_groupidf
//! The name of the field containing the group ID number.
//!  type: TYPE_STRING
//!  name: Fields: Group- Group ID
//
//! defvar: group_otherf
//! Additional fields to include in the group record (optional).
//!  type: TYPE_STRING
//!  name: Fields: Group- Additional fields
//
//! defvar: usergroup_userf
//! Field in the user to group mapping table containing the user name.
//!  type: TYPE_STRING
//!  name: Fields: UserGroup- User field
//
//! defvar: usergroup_groupf
//! Field in the user to group mapping table containing the group name.
//!  type: TYPE_STRING
//!  name: Fields: UserGroup- Group field
//
