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

int default_uid() {

#if constant(geteuid)
  return(geteuid());
#else
  return(0);
#endif
}

/*
 * Object management and configuration variables definitions
 */

void create()
{
	// LDAP server:
        defvar ("CI_dir_server","localhost","LDAP server: Location",
                   TYPE_STRING, "This is LDAP URL for the LDAP server with "
                   "the authentication information. Example: ldap(s)://myldaphost");

        defvar ("CI_basename","","LDAP server: Search Base name",
                   TYPE_STRING, "The distinguished name to use as a base for queries."
		   "Typically, this would be an 'o' or 'ou' entry "
		   "local to the DSA which contains the user entries.");

        defvar ("CI_search_templ","(&(objectclass=person)(uid=%u%))","Defaults: Search template",
                   TYPE_STRING, "Template used by LDAP search operation"
		   " as filter."
		   "<b>%u%</b> : Will be replaced by entered username." );

        defvar ("CI_level","subtree","LDAP query depth",
                   TYPE_STRING_LIST, "Scope used by LDAP search operation."
                   "",
		({ "base", "onelevel", "subtree" }) );

        defvar ("CI_required_attr","","LDAP server: Required attribute",
                   TYPE_STRING|VAR_MORE,
		   "Which attribute must be present to successfully"
		   " authenticate user (optional). "
		   "<br />For example: memberOf",
		   0);

        defvar ("CI_required_value","","LDAP server: Required value",
                   TYPE_STRING|VAR_MORE,
		   "Which value must be in required attribute (optional)" 
		   "<br />For example: cn=KISS-PEOPLE",
		   0);

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

	// Defaults:
        defvar ("CI_default_uid",default_uid(),"Defaults: User ID", TYPE_INT,
                   "Some modules require an user ID to work correctly. This is the "
                   "user ID which will be returned to such requests if the information "
                   "is not supplied by the directory search.");

        defvar ("CI_default_attrname_uid", "uidNumber",
		   "Attributes: User ID", TYPE_STRING,
                   "The attribute containing the user's numeric ID.");

        defvar ("CI_default_gid", getegid(),
		"Defaults: Group ID", TYPE_INT,
                   "Default GID to be supplied when directory entry does not provide one.");

        defvar ("CI_default_attrname_gid", "gidNumber",
		   "Attributes: Group ID", TYPE_STRING,
                   "The attribute containing the user's primary GID.");

        defvar ("CI_default_gecos", "", "Defaults: Gecos", TYPE_STRING,
                   "The default Full NAme (Gecos).");

        defvar ("CI_default_attrname_gecos", "gecos",
		   "Attribute: Full Name", TYPE_STRING,
                   "The attribute containing the user Full Name.");

        defvar ("CI_default_home","/", "Defaults: Home Directory", TYPE_DIR,
                   "It is possible to specify an user's home "
                   "directory. This is used if it's not provided.");

        defvar ("CI_default_attrname_homedir", "homeDirectory",
		   "Attributes: Home Directory", TYPE_STRING,
                   "The attribute containing the user Home Directory.");

        defvar ("CI_default_shell","/bin/false", "Defaults: Shell", TYPE_STRING,
                   "The shell name for entries without a shell.");

        defvar ("CI_default_attrname_shell", "loginShell",
		   "Attributes: Login Shell", TYPE_STRING,
                   "The attribute containing the user Login Shell.");

        defvar ("CI_default_addname",0,"Defaults: Username add",TYPE_FLAG,
                   "Setting this will add username to path to default "
                   "directory, when the home directory is not provided.");

}


void close_dir(object dir) {
  dir->unbind();
  dir=0;
  DEBUGLOG("closing the directory");
  return;
}


int|object open_dir() {
    mixed err;
    int res;
    object dir;

    dir_accesses++; //I count accesses here, since this is called before each


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

    DEBUGLOG("directory successfully opened");

    return dir;
}



/*
 * Statistics
 */

string status() {

    return ("<H2>Security info</H2>"
	   "Attempted authentications: "+att+"<BR>\n"
	   "Failed: "+(att-succ+nouser)+" ("+nouser+" because of wrong username)"
	   "<BR>\n"+
	   dir_accesses +" accesses to the directory were required.\n"

	   );

}


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

    DEBUGLOG ("userinfo ("+u+")");

    dir=open_dir();

    if (!dir) 
    {
      return 0;
    }

    sr=get_user_object(user);
    if(!sr)
    {
      DEBUGLOG("no user object for " + user);
      return 0;
    }

    tmp=sr->fetch();

    dirinfo->username=user;
    dirinfo->name=get_attrval(tmp, QUERY(CI_default_attrname_gecos), QUERY(CI_default_gecos));
    dirinfo->uid=get_attrval(tmp, QUERY(CI_default_attrname_uid), QUERY(CI_default_uid));
    dirinfo->primary_group=get_attrval(tmp, QUERY(CI_default_attrname_gid), QUERY(CI_default_gid));
    dirinfo->shell=get_attrval(tmp, QUERY(CI_default_attrname_shell), QUERY(CI_default_shell));
    dirinfo->home_directory=get_attrval(tmp, QUERY(CI_default_attrname_homedir), QUERY(CI_default_home));

    if(QUERY(CI_default_addname) && dirinfo->home_directory==QUERY(CI_default_home))
      dirinfo->home_directory+=user;

    dirinfo->groups=get_groups_for_user(dir, user);

    dirinfo->_source=QUERY(_name);

    return dirinfo;
}

array(string) userlist() 
{

    return ({});
}

string user_from_uid (int u) 
{

    if(!zero_type(uids[(string)u]))
	return(uids[(string)u][0]);
    return 0;
}

private int|object get_user_object(object dir, string user)
{
   string userdn;
   mixed err;
   object sr;
   mapping dirinfo;

   // first, we find the dn for the user we are about to authenticate as.
   userdn=replace(QUERY(CI_search_templ), "%u", user);

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

   // check for required attribute, if any
   if(QUERY(CI_required_attr) && QUERY(CI_required_attr)!="")
   {
     if(!dirinfo[QUERY(CI_required_attr)])
     {
       DEBUGLOG (user + " does not have required attribute.");
       close_dir(dir);
       return 0;
     }
     int ok=0;
     array v=dirinfo[QUERY(CI_required_attr)];
     foreach(v, mixed val)
       if(val==QUERY(CI_required_value))
       {
         ok=1;
         break; // we have a match
       }
     if(!ok) // we didn't find a match.
     {
       DEBUGLOG (user + " has required attribute, but not value.");
       close_dir(dir);
       return 0;
     }
   }
  
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
      DEBUGLOG (u+" authentication failed");
      return -1;
    }

    // successful authentication
    DEBUGLOG (u+" positively recognized");
    close_dir(dir);
    succ++;
    return 1;
}
