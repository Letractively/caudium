/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

//
//! module: Authentication Provider: Active Directory
//!  Active Directory User authentication. Reads the directory and use it to
//!  authenticate users.
//!  Basic authentication names and passwords are mapped onto attributes
//!  in entries in preselected portions of an LDAP DSA. This module accesses
//!  Active Directory via its LDAP interface.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PROVIDER
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

#ifdef DEBUG
#define ERROR(X) werror("ADAuth: " + X + "\n");
#else
#define ERROR(X) 
#endif

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: ActiveDirectory";
constant module_doc  = "Authenticate users against Active"
	"Directory servers authorization using "
	"Pike's internal LDAP directory interface.";

// we can only have one per virtual server.
constant module_unique = 0;

object dir=0;

// initialize the counters.
int dir_accesses=0, last_dir_access=0, succ=0, att=0, nouser=0;

int no_anonymous_bind;

string aduser, adpassword, addomain;
array adservers=({});


void create()
{

  defvar("addomain", "", "ActiveDirectory Domain", TYPE_STRING,
         "Your ActiveDirectory Domain Name, for example: MYDOMAIN.COM");
  defvar("adservers", "", "ActiveDirectory Servers", TYPE_STRING,
         "Your ActiveDirectory Domain Name, comma separated in order of "
         "importance; for example: DC1, DC2");
  defvar("aduser", "", "ActiveDirectory Bind User", TYPE_STRING,
         "Distinguished Name for user that initial user search will be "
         "performed as. Leave blank to search as anonymous user. "
         "Example: cn=Bind User\\, Caudium, ou=People, dc=MYDOMAIN, dc=COM");
  defvar("adpassword", "", "ActiveDirectory Bind Password", TYPE_STRING,
         "Password that will be provided for initial user search. "
         "Leave blank to search as anonymous user.");
}

string status() {

  return "<H2>Security info</H2>"
   "Attempted authentications: "+ att +"<BR>\n"
   "Failed: "+((att-succ)+nouser)+ " ("+nouser+" because of wrong username)"
   "<BR>\n"+
   dir_accesses +" accesses to the directory were required.<BR>\n<p>";

}

void start(object cnf)
{

  ERROR("start");
  array d1=({});

  if(!catch(query("addomain")))
  {
    string d=query("addomain");
    ERROR(d);
    ERROR(d);
    array dom=d/".";  
    ERROR(d);
    foreach(dom, string d)
      d1+=({"dc=" + d});
    addomain=d1*", ";
  }
  if(!catch(query("adservers")))
  {
    ERROR("adservers");
    adservers=((query("adservers")-" ")/",");
  }
  
  if(!catch(query("aduser")) && !catch(query("adpassword"))) 
  {
    aduser=query("aduser");
    adpassword=query("adpassword");
    no_anonymous_bind=1;
  }
  else no_anonymous_bind=0;

}

void stop()
{

}

string query_provides()
{
  return "authentication";
}


string get_attrval(mapping attrval, string attrname, string dflt)
{
    return (zero_type(attrval[attrname]) ? dflt : attrval[attrname][0]);
}

mapping|int get_user_info(string username)
{
  ERROR("get_user_info: " + username);
  int res;
  if(!username)
    return 0;
  mapping data=loadUserInfo(username);

  if(!data) return 0;

    string uid="-1";
    string email, common_name, primary_group, home_directory="";
    array|int groups=({});

    if(data->primaryGroupID)
      primary_group=data->primaryGroupID[0];
    if(data->objectSid)
      uid=data->objectSid[0];
    if(data->cn)
      common_name=data->cn[0];
    if(data->mail)
      email=data->mail[0];
    if(data->homeDirectory)
      home_directory=data->homeDirectory[0];

    // get the groups a user is in.
    groups=get_groups_for_user(data->dn[0]);
    if(!groups) groups=({});

    return(["username": username, "primary_group": primary_group, 
	"name": common_name, "uid": uid, "email": email,
	"home_directory" : home_directory, "groups": groups,
	"_source": query("_name")]);

}

mapping|int get_username(string uid)
{
  ERROR("get_username: " + uid);

  if(!uid)
    return 0;

  mixed data=loadUserName(uid);

  if(!data) return -1;

  else return data;

}

mapping|int get_groupname(string gid)
{
  ERROR("get_groupname: " + gid);

  if(!gid)
    return 0;

  mixed data=loadGroupName(gid);

  if(!data) return -1;

  else return data;

}

mapping|int get_group_info(string groupname)
{
  ERROR("get_user_info: " + groupname);
  int res;
  if(!groupname)
    return 0;
  mapping data=loadGroupInfo(groupname);

  if(!data) return 0;

    string gid="-1";
    string common_name, primary_group="";
    array|int users=({});

    if(data->objectSid)
      gid=data->objectSid[0];
    if(data->cn)
      common_name=data->cn[0];

    // get the users in a group.
    users=get_users_for_group(data->dn[0]);
    if(!users) users=({});

    return(["groupname": groupname, 
	"name": common_name, "gid": gid,
	"users": users ]);

}

array list_all_groups()
{
  ERROR("list_all_groups()");

  int res;
  array groups=({});

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("&(objectclass=group)", ({"sAMAccountName"})));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }

  ERROR("got " + r->num_entries() + " groups");

  for(int i=0; i<r->num_entries(); i++)
  {
    groups+=({r->fetch()->sAMAccountName[0]});  
    r->next();
  }
  return groups;

}
array list_all_users()
{
  ERROR("list_all_users()");

  int res;
  array users=({});

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("(&(objectclass=user)(!(objectclass=computer)))", ({"sAMAccountName"})));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }

  ERROR("got " + r->num_entries() + " users");

  for(int i=0; i<r->num_entries(); i++)
  {
    users+=({r->fetch()->sAMAccountName[0]});  
    r->next();
  }
  return users;

}

array get_groups_for_user(string dn)
{

  ERROR("get_groups_for_user(" + dn + ")");

  int res;
  array groups=({});

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("&(objectclass=group)(member=" + dn + ")"));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }

  ERROR("got " + r->num_entries() + " for user");

  for(int i=0; i<r->num_entries(); i++)
  {
    groups+=({r->fetch()->sAMAccountName[0]});  
    r->next();
  }
  return groups;
}

array get_users_for_group(string dn)
{

  ERROR("get_users_for_group(" + dn + ")");

  int res;
  array users=({});

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(dn);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + dn + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(0);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(0) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("objectclass=*"));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }


  ERROR("got " + r->num_entries() + " for group");

  ERROR(sprintf("%O", r->fetch()));
  foreach(r->fetch()["member"], string memberdn)
  {
    object u;
    ldap->set_basedn(memberdn);
    catch(u=ldap->search("objectclass=*"));
    if(!u)
    {
      ERROR("failed to perform search for member " + memberdn + ".");
      continue;
    } 
    users+=({u->fetch()->sAMAccountName[0]});  
 
  }
  return users;
}

mapping|void loadUserInfo(string username)
{

  ERROR("loadUserInfo(" + username + ")");
  int res;

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("&(SAMAccountname=" + username + ")(objectclass=user)(!(objectclass=computer))"));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return;
  }

  if(r->num_entries()!=1)
  {
    ERROR("found " + r->num_entries() + " entries for user " + username + ". must be bogus.");
    for(int i=0; i<r->num_entries(); i++)
    {
      ERROR("bogus dn: " + r->get_dn());
      r->next();
    }
    return;
  }
  werror("returning data.\n");

  return r->fetch();
}

string|int loadUserName(string uid)
{

  ERROR("loadUserName(" + uid + ")");
  int res;

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("&(ObjectSID=" + uid + ")(objectclass=user)(!(objectclass=computer))"));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }

  if(r->num_entries()!=1)
  {
    ERROR("found " + r->num_entries() + " entries for uid " + uid + ". must be bogus.");
    for(int i=0; i<r->num_entries(); i++)
    {
      ERROR("bogus dn: " + r->get_dn());
      r->next();
    }
    return 0;
  }
  werror("returning data.\n");

  return r->fetch()->sAMAccountName[0];
}

string|int loadGroupName(string gid)
{

  ERROR("loadGroupName(" + gid + ")");
  int res;

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("&(ObjectSID=" + gid + ")(objectclass=group)"));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }

  if(r->num_entries()!=1)
  {
    ERROR("found " + r->num_entries() + " entries for gid " + gid + ". must be bogus.");
    for(int i=0; i<r->num_entries(); i++)
    {
      ERROR("bogus dn: " + r->get_dn());
      r->next();
    }
    return 0;
  }
  werror("returning data.\n");

  return r->fetch()->sAMAccountName[0];
}

mapping|void loadGroupInfo(string groupname)
{

  ERROR("loadGroupInfo(" + groupname + ")");
  int res;

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return 0;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return 0;
    }
  }
  ERROR("setting base dn.\n");
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return 0;
  }
  ERROR("setting scope.\n");
  
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return 0;
  }

  ERROR("preparing to do search.\n");

  object r;
  catch( r=ldap->search("&(SAMAccountname=" + groupname + ")(objectclass=group)"));

  ERROR("search result:" + ldap->error_string() + "\n");
  if(!r)
  {
    ERROR("failed to perform search");
    return 0;
  }

  if(r->num_entries()!=1)
  {
    ERROR("found " + r->num_entries() + " entries for group " + groupname + ". must be bogus.");
    for(int i=0; i<r->num_entries(); i++)
    {
      ERROR("bogus dn: " + r->get_dn());
      r->next();
    }
    return 0;
  }
  werror("returning data.\n");

  return r->fetch();
}

array(string) userlist() 
{
    return ({});
}

string user_from_uid (int u) 
{
    return 0;
}

object getLDAPConnection()
{
  object ldap;
  //
  // get a connection to a server
  //
  if(sizeof(adservers)>0)
    foreach(adservers, string server)
    {
      string ldapurl="ldap://" + server;
      if(catch(ldap=Protocols.LDAP.client(ldapurl))) continue;      
      else break;
    }
  return ldap;
}

string getUserDN(string username)
{
  ERROR("getUserDN(" + username + ")\n");
  object ldap=getLDAPConnection();
  if(!ldap) 
  {
    ERROR("unable to get LDAP connection");
    return "";
  }

  string userdn="";
  int res;
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(!res)
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return "";
    }
  }
    
  res=ldap->set_basedn(addomain);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return "";
  }
  res=ldap->set_scope(2);
  if(!res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return "";
  }
  
  object r;

  if(catch(r=ldap->search("&(SAMAccountname=" + username + ")(objectclass=user)(!(objectclass=computer))")))
  {
    catch(ldap->unbind());
    ERROR("search failed for username: " + username);
    return "";
  }

  if(r->num_entries()!=1)
  {
    ERROR("found " + r->num_entries() + "dns for username: " + username);
    catch(ldap->unbind());
    return "";
  }
  if(catch(userdn=r->fetch()["dn"][0]))
  {
    ERROR("fetching dn failed for username: " + username);
    catch(ldap->unbind());
    return "";
  }

  catch(ldap->unbind());
  return userdn;
}

//
//  return 1 on success, -1 on failed authentication
//    0 when user is not found, etc.
//
int authenticate(string username, string password)
{
  object ldap, entry;
  int res;

  string userdn=getUserDN(username);

  if(userdn=="") // was the user found?
  {
    nouser++;
    return 0;
  }

  ldap=getLDAPConnection();

  //
  // did we get an ldap connection?  
  //
  if(!ldap)
  {
    ERROR("unable to get LDAP connection.");
    return 0;
  }

  res=ldap->bind(userdn, password);

  if(!res) 
  {
    ERROR("unable to bind: " + ldap->error_string());
    ldap(ldap->unbind());
    return -1;
  }

  // increment the success counter.
  succ++;
  return 1;
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: addomain
//! Your ActiveDirectory Domain Name, for example: MYDOMAIN.COM
//!  type: TYPE_STRING
//!  name: ActiveDirectory Domain
//
//! defvar: adservers
//! Your ActiveDirectory Domain Name, comma separated in order of importance; for example: DC1, DC2
//!  type: TYPE_STRING
//!  name: ActiveDirectory Servers
//
//! defvar: aduser
//! Distinguished Name for user that initial user search will be performed as. Leave blank to search as anonymous user. Example: cn=Bind User\, Caudium, ou=People, dc=MYDOMAIN, dc=COM
//!  type: TYPE_STRING
//!  name: ActiveDirectory Bind User
//
//! defvar: adpassword
//! Password that will be provided for initial user search. Leave blank to search as anonymous user.
//!  type: TYPE_STRING
//!  name: ActiveDirectory Bind Password
//
