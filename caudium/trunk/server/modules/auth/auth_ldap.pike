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
 */
/*
 * $Id$
 */

#define DEBUG_AUTH

#ifdef DEBUG_AUTH
# define DEBUGLOG(X) report_debug(X);
#else
# define DEBUGLOG(X)
#endif

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

import Stdio;
import Array;

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: LDAP";
constant module_doc  = "Provides access to user and group accounts "
	"located in LDAP directories.";

constant module_unique = 0;


string query_provides()
{
  return "authentication";
}


/*
 * Globals
 */

int att,succ=0;

int default_uid() {

#if constant(geteuid)
  return(geteuid());
#else
  return(0);
#endif
}

int default_gid() {

#if constant(getegid)
  return(getegid());
#else
  return(0);
#endif
}

/*
 * Object management and configuration variables definitions
 */

void create()
{
// LDAP server definitions

        defvar ("CI_dir_server","localhost","LDAP server: Location",
                   TYPE_STRING, "This is LDAP URL for the LDAP server with "
                   "the authentication information. Example: ldap(s)://myldaphost");

        defvar ("CI_basename","","LDAP server: Search Base name",
                   TYPE_STRING, "The distinguished name to use as a base for queries."
		   "Typically, this would be an 'o' or 'ou' entry "
		   "local to the DSA which contains the user entries.");

        defvar ("CI_level","subtree","LDAP server: LDAP query depth",
                   TYPE_STRING_LIST, "Scope used by LDAP search operation."
                   "",
		({ "base", "onelevel", "subtree" }) );

        defvar ("CI_dir_username","","LDAP server: Directory search username",
                   TYPE_STRING|VAR_MORE,
		   "This Distinguished Name (DN) will be used to authenticate "
                   "when connecting to the LDAP server to perform "
                   "non-authentication related searches. Refer to your LDAP "
                   "server documentation, this could be irrelevant. (optional)",
		   0);

        defvar ("CI_dir_pwd","", "LDAP server: Directory user's password",
		    TYPE_STRING|VAR_MORE,
		    "This is the password used to authenticate "
		    "connection to directory (optional).",
		   0);



// SEARCH TEMPLATE DEFINITIONS

        defvar ("CI_search_templ","(&(objectclass=person)(uid=%u%))","Search: User Search template",
                   TYPE_STRING, "Template used by LDAP search operation "
                   "as filter for searching for users"
		   "<b>%u%</b> : Will be replaced by entered username." );

        defvar ("CI_groupsearch_templ","(&(objectclass=group)(cn=%g%))","Search: Group Search template",
                   TYPE_STRING, "Template used by LDAP search operation "
                   "as filter for searching for groups"
		   "<b>%g%</b> : Will be replaced by entered groupname." );

        defvar ("CI_userforgroup_search_templ","(&(objectclass=group)(cn=%g%))","Search: Users in groups Search template",
                   TYPE_STRING, "Search template used as filter "
                   "when searching for user members of groups."
		   "<b>%g%</b> : Will be replaced by entered groupname."
		   "<b>%d%</b> : Will be replaced by group's full dn." );

        defvar ("CI_groupforuser_search_templ","(&(objectclass=group)(memberuid=%u%))","Search: Groups for user Search template",
                   TYPE_STRING, "Template used by LDAP search operation"
		   " as filter."
		   "<b>%u%</b> : Will be replaced by entered username."
		   "<b>%d%</b> : Will be replaced by user's full dn." );

        defvar ("CI_userlist_search_templ","(objectclass=person)","Search: Userlist search query",
                   TYPE_STRING, "Template used by LDAP userlist search operation");

        defvar ("CI_grouplist_search_templ","(objectclass=group)","Search: Grouplist search query",
                   TYPE_STRING, "Template used by LDAP grouplist search operation");

// ATTRIBUTE DEFINITIONS

        defvar ("CI_attr_userforgroup","memberuid","User Attributes: Username in group entry",
                   TYPE_STRING, 
		   "Attribute in group object containing a user's name" );

        defvar ("CI_attr_group_groupname","cn","Group Attributes: Groupname",
                   TYPE_STRING, 
		   "Attribute in group object containing a group's name" );

        defvar ("CI_attr_group_fullname","description","Group Attributes: Long Description",
                   TYPE_STRING, 
		   "Attribute in group object containing a group's description" );

        defvar ("CI_attr_group_gid","gidNumber","Group Attributes: Group ID",
                   TYPE_STRING, 
		   "Attribute in group object containing a group's numerid ID" );

        defvar ("CI_attr_user_uid", "uidNumber",
		   "User Attributes: User ID", TYPE_STRING,
                   "The attribute containing the user's numeric ID.");

        defvar ("CI_attr_user_gid", "gidNumber",
		   "User Attributes: Group ID", TYPE_STRING,
                   "The attribute containing the user's primary GID.");

        defvar ("CI_attr_user_username", "uid",
		   "User Attributes: User", TYPE_STRING,
                   "The attribute containing the user name in user object.");

        defvar ("CI_attr_user_homedir", "homeDirectory",
		   "User Attributes: Home Directory", TYPE_STRING,
                   "The attribute containing the user Home Directory.");

        defvar ("CI_attr_user_shell", "loginShell",
		   "User Attributes: Login Shell", TYPE_STRING,
                   "The attribute containing the user Login Shell.");

        defvar ("CI_attr_user_email", "mail",
		   "User Attributes: E-Mail Address", TYPE_STRING,
                   "The attribute containing the user E-Mail Address.");

        defvar ("CI_attr_user_fullname", "gecos",
		   "User Attributes: Full Name", TYPE_STRING,
                   "The attribute containing the user Full Name.");


// DEFAULT VALUE DEFINITIONS

        defvar ("CI_default_group_gid",default_gid(),"Group Defaults: Group ID", TYPE_INT,
                   "Some modules require an group ID to work correctly. This is the "
                   "group ID which will be returned to such requests if the information "
                   "is not supplied by the directory search.");

        defvar ("CI_default_group_fullname", "", "Group Defaults: Full Name", TYPE_STRING,
                   "The default Full Name (Gecos).");

        defvar ("CI_default_user_uid",default_uid(),"User Defaults: User ID", TYPE_INT,
                   "Some modules require an user ID to work correctly. This is the "
                   "user ID which will be returned to such requests if the information "
                   "is not supplied by the directory search.");

        defvar ("CI_default_user_gid", default_gid(),
		"User Defaults: Group ID", TYPE_INT,
                   "Default GID to be supplied when directory entry does not provide one.");

        defvar ("CI_default_user_fullname", "", "User Defaults: Full Name", TYPE_STRING,
                   "The default Full Name (Gecos).");

        defvar ("CI_default_user_homedir","/", "User Defaults: Home Directory", TYPE_DIR,
                   "It is possible to specify an user's home "
                   "directory. This is used if it's not provided.");

        defvar ("CI_default_user_shell","/bin/false", "User Defaults: Shell", TYPE_STRING,
                   "The shell name for entries without a shell.");

        defvar ("CI_default_user_addname",0,"User Defaults: Add username to Home",TYPE_FLAG,
                   "Setting this will add username to path to default "
                   "directory, when the home directory is not provided.");

}


void close_dir(object dir) {
  dir->unbind();
  dir=0;
  DEBUGLOG("closing the directory\n");
  return;
}


int|object open_dir() {
    mixed err;
    int res;
    object dir;

    // FIXME: there is no reference to this variable .. :p
    //dir_accesses++; //I count accesses here, since this is called before each


    err = catch 
    {
	dir = Protocols.LDAP.client(QUERY(CI_dir_server));
    };

    if (arrayp(err)) 
    {
      report_error ("LDAPauth: Couldn't open authentication directory!\n"
          "[Internal: "+err[0]+"]\n");
      return 0;
    }

   // bind if we have a default user specified.
   if(QUERY(CI_dir_username) && QUERY(CI_dir_username)!="")
   {
     res=dir->bind(QUERY(CI_dir_username), QUERY(CI_dir_pwd));
     if(!res)
     {
       report_error("LDAPauth: bind failed as " + QUERY(CI_dir_username) + "\n");
       close_dir(dir);
       return 0;
     }
   }   
    
   switch(QUERY(CI_level)) 
   {
     case "subtree": dir->set_scope(2); break;
     case "onelevel": dir->set_scope(1); break;
     case "base": dir->set_scope(0); break;
   }

    dir->set_basedn(QUERY(CI_basename));

    DEBUGLOG("directory successfully opened\n");

    return dir;
}



/*
 * Statistics
 */
#if 0
string status() {

    return ("<H2>Security info</H2>"
	   "Attempted authentications: "+att+"<BR>\n"
	   "Failed: "+(att-succ)
	   "<BR>\n"+
	   dir_accesses +" accesses to the directory were required.\n"

	   );

}
#endif


/*
 * Auth functions
 */

private string get_attrval(mapping attrval, string attrname, string dflt) 
{

    return (zero_type(attrval[attrname]) ? dflt : attrval[attrname][0]);
}

mapping|int get_user_info(string user) {

    object sr,dir;
    mixed err;
    mapping dirinfo=([]);

    mapping(string:array(string)) tmp, attrsav;

    DEBUGLOG ("userinfo ("+user+")\n");

    dir=open_dir();

    if (!dir) 
    {
      return 0;
    }

    sr=get_user_object(dir, user);
    if(!sr)
    {
      DEBUGLOG("no user object for " + user + "\n");
      return 0;
    }

    tmp=sr->fetch();

    dirinfo->username=tmp[QUERY(CI_attr_user_username)][0];
    dirinfo->name=get_attrval(tmp, QUERY(CI_attr_user_fullname), QUERY(CI_default_user_fullname));
    dirinfo->uid=get_attrval(tmp, QUERY(CI_attr_user_uid), QUERY(CI_default_user_uid));
    dirinfo->primary_group=get_attrval(tmp, QUERY(CI_attr_user_gid), QUERY(CI_default_user_gid));
    dirinfo->shell=get_attrval(tmp, QUERY(CI_attr_user_shell), QUERY(CI_default_user_shell));
    dirinfo->home_directory=get_attrval(tmp, QUERY(CI_attr_user_homedir), QUERY(CI_default_user_homedir));

    if(QUERY(CI_attr_user_email) && tmp[QUERY(CI_attr_user_email)])
      dirinfo->email=tmp[QUERY(CI_attr_user_email)][0];

    if(QUERY(CI_default_user_addname) && dirinfo->home_directory==QUERY(CI_default_user_homedir))
      dirinfo->home_directory+=user;

    dirinfo->groups=get_groups_for_user(dir, user, sr->get_dn());

    dirinfo->_source=QUERY(_name);

    return dirinfo;
}

mapping|int get_group_info(string group) {

    object sr,dir;
    mixed err;
    mapping dirinfo=([]);

    mapping(string:array(string)) tmp, attrsav;

    DEBUGLOG ("groupinfo ("+group+")\n");

    dir=open_dir();

    if (!dir) 
    {
      return 0;
    }

    sr=get_group_object(dir, group);
    if(!sr)
    {
      DEBUGLOG("no group object for " + group + "\n");
      return 0;
    }

    tmp=sr->fetch();

    dirinfo->groupname=tmp[QUERY(CI_attr_group_groupname)][0];
    dirinfo->name=get_attrval(tmp, QUERY(CI_attr_group_fullname), QUERY(CI_default_group_fullname));
    dirinfo->gid=get_attrval(tmp, QUERY(CI_attr_group_gid), QUERY(CI_default_group_gid));
    dirinfo->users=get_users_for_group(dir, group, sr->get_dn());

    dirinfo->_source=QUERY(_name);

    return dirinfo;
}

multiset get_groups_for_user(object dir, string user, string dn)
{
    multiset v=(<>);

    string q=QUERY(CI_groupforuser_search_templ);
    q=replace(q, ({"%u%", "%d%"}), ({user, dn}));
    object sr=dir->search(q, ({QUERY(CI_attr_group_groupname)}));

    if(sr->num_entries()==0) return (<>);

    for(int i=0; i< sr->num_entries(); i++)
    {
      v+=(<sr->fetch()[QUERY(CI_attr_group_groupname)][0]>);
      sr->next();
    }
    
   return v;
}

multiset get_users_for_group(object dir, string group, string dn)
{
    multiset v=(<>);

    string q=QUERY(CI_userforgroup_search_templ);
    q=replace(q, ({"%g%", "%d%"}), ({group, dn}));
    object sr=dir->search(q, ({QUERY(CI_attr_userforgroup)}));

    if(sr->num_entries()!=1) return (<>);
    else
    {
       array g=sr->fetch();
       v=(multiset)(g[QUERY(CI_attr_userforgroup)]);
    }
    
   return v;
}

array(string) list_all_users() 
{
  object dir=open_dir();

  if(!dir)
    return ({});

  array users=({});

  object sr=dir->search(QUERY(CI_userlist_search_templ), QUERY(CI_attr_user_username));

  if(sr->num_entries()==0) return ({});

  for(int i=0; i<sr->num_entries(); i++)
  {
    if(sr->fetch()[QUERY(CI_attr_user_username)])
      users+=({ sr->fetch()[QUERY(CI_attr_user_username)][0] });
    sr->next();
  }

  return users;
}

array(string) list_all_groups() 
{
  object dir=open_dir();

  if(!dir)
    return ({});

  array groups=({});

  object sr=dir->search(QUERY(CI_grouplist_search_templ), QUERY(CI_attr_group_groupname));

  if(sr->num_entries()==0) return ({});

  for(int i=0; i<sr->num_entries(); i++)
  {
    if(sr->fetch()[QUERY(CI_attr_group_groupname)])
      groups+=({ sr->fetch()[QUERY(CI_attr_group_groupname)][0] });
    sr->next();
  }

  return groups;
}

private int|object get_user_object(object dir, string user)
{
   string userdn;
   mixed err;
   object sr;
   mapping dirinfo;

   // first, we find the dn for the user we are about to authenticate as.
   userdn=replace(QUERY(CI_search_templ), "%u%", user);

   err=catch(sr=dir->search(userdn));    

   if(err) 
   {
     report_error("LDAPAuth: Search failed for query " + userdn + "\n", 
       dir->error_string());
   }

   if(sr->num_entries()==0)
   {
      report_error("LDAPAuth: user not found: " + user + "\n");
      close_dir(dir);
      return 0;
   }
   else if(sr->num_entries()>1)
   {
      report_error("LDAPAuth: we have more than one match for user " + user + "!\n");
   }

   dirinfo=sr->fetch();  // we will work with the first entry.

   return sr;
}

private int|object get_group_object(object dir, string group)
{
   string groupdn;
   mixed err;
   object sr;
   mapping dirinfo;

   // first, we find the dn for the group we are about to search as.
   groupdn=replace(QUERY(CI_groupsearch_templ), "%g%", group);

   err=catch(sr=dir->search(groupdn));    

   if(err) 
   {
     report_error("LDAPAuth: Search failed for query " + groupdn + "\n", 
       dir->error_string());
   }

   if(sr->num_entries()==0)
   {
      report_error("LDAPAuth: group not found: " + group + "\n");
      report_error("LDAPAuth: Search used: " + groupdn + "\n");
      close_dir(dir);
      return 0;
   }
   else if(sr->num_entries()>1)
   {
      report_error("LDAPAuth: we have more than one match for group " + group + "!\n");
   }

   dirinfo=sr->fetch();  // we will work with the first entry.

   return sr;
}

int authenticate (string user, string password)
{
    mixed err;
    object dir;
    string userdn;
    mapping dirinfo;
    int res;
    object sr;

    att++;
    
    dir=open_dir();
    if(!dir) return 0;

    sr=get_user_object(dir, user);
    if(!sr)
    {
      // user does not exist.
      return 0;
    }

    userdn=sr->get_dn();

    // in case we are bound already.
    dir->unbind();

    res=dir->bind(userdn, password);

    if(!res) 
    {
      close_dir(dir);
      DEBUGLOG (user+" authentication failed\n");
      return -1;
    }

    // successful authentication
    DEBUGLOG (user +" positively recognized\n");
    close_dir(dir);
    succ++;
    return 1;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: CI_dir_server
//! This is LDAP URL for the LDAP server with the authentication information. Example: ldap(s)://myldaphost
//!  type: TYPE_STRING
//!  name: LDAP server: Location
//
//! defvar: CI_basename
//! The distinguished name to use as a base for queries.Typically, this would be an 'o' or 'ou' entry local to the DSA which contains the user entries.
//!  type: TYPE_STRING
//!  name: LDAP server: Search Base name
//
//! defvar: CI_search_templ
//! Template used by LDAP search operation as filter.<b>%u%</b> : Will be replaced by entered username.
//!  type: TYPE_STRING
//!  name: Defaults: Search template
//
//! defvar: CI_level
//! Scope used by LDAP search operation.
//!  type: TYPE_STRING_LIST
//!  name: LDAP query depth
//
//! defvar: CI_required_attr
//! Which attribute must be present to successfully authenticate user (optional). <br />For example: memberOf
//!  type: TYPE_STRING|VAR_MORE
//!  name: LDAP server: Required attribute
//
//! defvar: CI_required_value
//! Which value must be in required attribute (optional)<br />For example: cn=KISS-PEOPLE
//!  type: TYPE_STRING|VAR_MORE
//!  name: LDAP server: Required value
//
//! defvar: CI_dir_username
//! This Distinguished Name (DN) will be used to authenticate when connecting to the LDAP server to perform non-authentication related searches. Refer to your LDAP server documentation, this could be irrelevant. (optional)
//!  type: TYPE_STRING|VAR_MORE
//!  name: LDAP server: Directory search username
//
//! defvar: CI_dir_pwd
//! This is the password used to authenticate connection to directory (optional).
//!  type: TYPE_STRING|VAR_MORE
//!  name: LDAP server: Directory user's password
//
//! defvar: CI_default_uid
//! Some modules require an user ID to work correctly. This is the user ID which will be returned to such requests if the information is not supplied by the directory search.
//!  type: TYPE_INT
//!  name: Defaults: User ID
//
//! defvar: CI_default_attrname_uid
//! The attribute containing the user's numeric ID.
//!  type: TYPE_STRING
//!  name: Attributes: User ID
//
//! defvar: CI_default_gid
//! Default GID to be supplied when directory entry does not provide one.
//!  type: TYPE_INT
//!  name: Defaults: Group ID
//
//! defvar: CI_default_attrname_gid
//! The attribute containing the user's primary GID.
//!  type: TYPE_STRING
//!  name: Attributes: Group ID
//
//! defvar: CI_default_gecos
//! The default Full NAme (Gecos).
//!  type: TYPE_STRING
//!  name: Defaults: Gecos
//
//! defvar: CI_default_attrname_gecos
//! The attribute containing the user Full Name.
//!  type: TYPE_STRING
//!  name: Attribute: Full Name
//
//! defvar: CI_default_home
//! It is possible to specify an user's home directory. This is used if it's not provided.
//!  type: TYPE_DIR
//!  name: Defaults: Home Directory
//
//! defvar: CI_default_attrname_homedir
//! The attribute containing the user Home Directory.
//!  type: TYPE_STRING
//!  name: Attributes: Home Directory
//
//! defvar: CI_default_shell
//! The shell name for entries without a shell.
//!  type: TYPE_STRING
//!  name: Defaults: Shell
//
//! defvar: CI_default_attrname_shell
//! The attribute containing the user Login Shell.
//!  type: TYPE_STRING
//!  name: Attributes: Login Shell
//
//! defvar: CI_default_addname
//! Setting this will add username to path to default directory, when the home directory is not provided.
//!  type: TYPE_FLAG
//!  name: Defaults: Username add
//
