/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
//! module: ActiveDirectory user database
//!  Active Directory User authentication. Reads the directory and use it to
//!  authenticate users.
//!  Basic authentication names and passwords are mapped onto attributes
//!  in entries in preselected portions of an LDAP DSA. This module accesses
//!  Active Directory via its LDAP interface.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_AUTH
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

#ifdef DEBUG
#else
#define ERROR(X) 
#endif

constant module_type = MODULE_AUTH | MODULE_EXPERIMENTAL;
constant module_name = "ActiveDirectory user database";
constant module_doc  = "Authenticate users against Active"
	"Directory servers authorization using "
	"Pike's internal LDAP directory interface.";

// we can only have one per virtual server.
constant module_unique = 1;

object dir=0;

// initialize the counters.
int dir_accesses=0, last_dir_access=0, succ=0, att=0, nouser=0;

int no_anonymous_bind;
int cache_timeout, cache_info_timeout;

string aduser, adpassword, addomain;
array adservers=({});

mapping user_cache=([]);

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
  defvar("cache_timeout", 300, "User auth cache timeout", TYPE_INT,
         "Seconds a cached user entry will remain valid for authentication."); 
  defvar("cache_info_timeout", 600, "User cache timeout", TYPE_INT,
         "Seconds a cached user entry will remain valid for user information."); }

string status() {
  return ("<H2>Security info</H2>"
   "Attempted authentications: "+att+"<BR>\n"
   "Failed: "+((att-succ)+nouser)+" ("+nouser+" because of wrong username)"
   "<BR>\n"+
   dir_accesses +" accesses to the directory were required.<BR>\n" +
   "<p>"
#ifdef LOG_ALL
   + "<p>"+
   "<h3>Auth attempt by host</h3>" +
   Array.map(indices(accesses), lambda(string s) {
     return caudium->quick_ip_to_host(s) + ": "+accesses[s]->cnt+" ["+accesses[s]->name[0]+
       ((sizeof(accesses[s]->name) > 1) ?
       (Array.map(accesses[s]->name, lambda(string u) {
       return (", "+u); }) * "") : "" ) + "]" +
	  "<br>\n";
	  }) * ""
#endif
   "<h3>User cache</h3>"
   + sizeof(user_cache) + " entries in user cache."
  );

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

  if(!catch(query("cache_timeout")))
    cache_timeout=query("cache_timeout");
  else 
    cache_timeout=300;	// 5 minutes is the default.

  if(!catch(query("cache_info_timeout")))
    cache_info_timeout=query("cache_info_timeout");
  else 
    cache_info_timeout=600;	// 10 minutes is the default.
}

void stop()
{

}

string get_attrval(mapping attrval, string attrname, string dflt)
{
    return (zero_type(attrval[attrname]) ? dflt : attrval[attrname][0]);
}

array(string) userinfo (string u,mixed p) 
{
    array ui=getUserInfo(u);
    if(ui)
      return ui;
    else return ({});
}

array getUserInfo(string username)
{
  int res;
  if(!username)
    return ({});
  loadUserInfo(username);
  if(user_cache[username])
  {
    return({username, 0, 0, user_cache[username]->primaryGroupID[0], 
	user_cache[username]->cn[0], 
	user_cache[username]->homeDirectory[0], 0});
  }
  return ({});
}

void loadUserInfo(string username)
{
  int res;
  if(user_cache[username] && user_cache[username]->cache_info_timeout > time())
    return;

  object ldap=getLDAPConnection();
  if(!ldap)
  {
    ERROR("failed to get LDAP connection");
    return;
  }
  if(no_anonymous_bind) // must we bind before searching?
  {
    res=ldap->bind(aduser, adpassword);
    if(res)   
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return;
    }
  }
    
  res=ldap->set_basedn(addomain);
  if(res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return;
  }
  
  res=ldap->set_scope(2);
  if(res)
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return;
  }
  object r;
  if(catch(r=ldap->search("SAMAccountname=" + username)))
  {
    ERROR("failed to perform search");
    return;
  }

  if(r->num_entries()!=1)
  {
    ERROR("found " + r->num_entries() + " entries for user " + username + ". must be bogus.");
    return;
  }

  if(catch(user_cache[username]=r->fetch()))
  {
    ERROR("failed to add user data to cache: " + ldap->error_string());
    catch(ldap->unbind());
    return;
  }

  else
  {
    user_cache[username]->cache_info_timeout = time() + cache_info_timeout;
    return;
  }
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
    if(res)
    {
      catch(ldap->unbind());
      ERROR("no_anonymous_bind failed ("+ aduser + ", " + adpassword+ "): " + ldap->error_string());
      return "";
    }
  }
    
  res=ldap->set_basedn(addomain);
  if(res && ldap->error_string()!="Success")
  {
    catch(ldap->unbind());
    ERROR("set_basedn(" + addomain + ") failed: " + ldap->error_string());
    return "";
  }
  res=ldap->set_scope(2);
  if(res)
  {
    catch(ldap->unbind());
    ERROR("set_scope(2) failed: " + ldap->error_string());
    return "";
  }
  
  object r;

  if(catch(r=ldap->search("SAMAccountname=" + username)))
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

array|int auth (array(string) auth, object id)
{
  object ldap, entry;
  string username, password;
  int res;

  if(sizeof(auth) !=2) return ({0, auth[1], ""});

  array a=auth[1]/":";

  if(sizeof(a) !=2) return ({0, auth[1], ""});

  // increment the status counter.
  att++;  

  username=a[0];
  password=a[1];
  
  if(user_cache[username]) // do we have a cached entry for this user?
  {
    
if(user_cache[username]->cache_timeout
  && (user_cache[username]->cache_timeout > time()) &&
  user_cache[username]->cache_pass == Crypto.sha()->update(password+username)->digest())
    {
      succ++;
      return ({1, username, 0});
    }
  }

  string userdn=getUserDN(username);

  if(userdn=="") // was the user found?
  {
    nouser++;
    return ({0, username, password});
  }

  ldap=getLDAPConnection();

  //
  // did we get an ldap connection?  
  //
  if(!ldap)
  {
    ERROR("unable to get LDAP connection.");
    return ({0, username, password});
  }

  res=ldap->bind(userdn, password);

  if(res) 
  {
    ERROR("unable to bind: " + ldap->error_string());
    ldap(ldap->unbind());
    return ({0, username, password});
  }
  // from here out, we have a successful auth, but data fetch may fail.
  res=ldap->set_basedn(userdn);  
  dir_accesses++;  
  if(catch(entry=ldap->search("objectclass=*")))
  {
    ERROR("failed to gather user data: " + ldap->error_string());
    catch(ldap->unbind());
    return ({1, username, 0});
  }
  if(catch(user_cache[username]=entry->fetch()))
  {
    ERROR("failed to add user data to cache: " + ldap->error_string());
    catch(ldap->unbind());
    return ({1, username, 0});
  }
  else
  {
    user_cache[username]->cache_timeout=time()+cache_timeout;
    user_cache[username]->cache_pass=Crypto.sha()->update(password+username)->digest();
  }

  ldap->unbind();
 
  // increment the success counter.
  succ++;
  return ({1, username, 0});
}

