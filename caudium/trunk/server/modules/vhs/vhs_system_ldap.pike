/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

/* TODO:
 *
 * - config cache expiring
 * - improve reconnect code
 * - better error handling
 * - configurable LDAP fields
 * - use grendels OpenLDAP module
 * - make SQL based module
 *
 */

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PRECACHE;
constant module_name = "VHS - Virtual Hosting System (LDAP)";
constant module_doc  = "Basic Virtual Hosting module (LDAP).";
constant module_unique = 1;

// #define VHS_DEBUG

#if defined(DEBUG) || defined(VHS_DEBUG)
# define DW(x) werror("[VHS_system] " + x + "\n")
#else
# define DW(x)
#endif

#ifdef THREADS
object mutex  = Thread.Mutex();
#else
object mutex;
#endif

mapping (string:object) virtcache = ([]);

int virtuals;
int ldap_last_query=0;
int ldap_err_count;

object ldap;

int ldap_ttl, ldap_bind_result, ldap_count;

int _initialized_ok;

int lame_users = 0;

string ldapquery;

class ConfigCache
{
  string hostname;
  string virtpath;
  string cgipath;
  string logpath;
  string owneruid;
  string redirect;
  string homedir;

  int expires;
  int createtime;
  int dynamic;
  int uidnumber;
  int gidnumber;

  void create(string owner, string host, string path,
              string cgi, string log, string home, int uid, int gid,
	      int ttl, void|string redir)
  {
    createtime = time();
    expires = createtime + ttl;
    logpath = log;
    cgipath = cgi;
    hostname = host;
    virtpath = path;
    owneruid = owner;
    redirect = redir;
    uidnumber = uid;
    gidnumber = gid;
    homedir = home;

    DW(sprintf("New ConfigCache entry: uid=%s, host=%s, path=%s, cgi=%s, logs=%s, redir=%s",
               owneruid, hostname, virtpath, cgipath||"-", logpath||"-", redirect||"-"));
  }
};

void ldap_reconnect()
{
  mixed init_err = catch {
    ldap = Protocols.LDAP.client(QUERY(ldap_url));
  
    DW(sprintf("url = %s", QUERY(ldap_url)));
  
    ldap_bind_result = ldap->bind(QUERY(bind_dn), QUERY(bind_pw), QUERY(proto_ver));
  
    DW(sprintf("bind_dn = %s, bind_pw = %s", QUERY(bind_dn), QUERY(bind_pw)));
  
    ldap->set_basedn(QUERY(base_dn));
  
    DW(sprintf("base_dn = %s", QUERY(base_dn)));
  
    ldap->set_scope(2);
  
    if (!ldap_bind_result) ldap_err_count = 0;
  
    ldap_last_query = time();
  }
  ;

  if (!init_err) _initialized_ok = 1;
}

string ldap_getvirt(string hostname, object id)
{
#ifdef THREADS
  object key = mutex->lock();
#endif

  if ((time() - ldap_last_query) > QUERY(ldap_reconnect))
     ldap_reconnect();

  ldap_count++;

  object result;
  mapping res;

  mixed err = catch
  {
	string tmpquery = sprintf(ldapquery, hostname);
        result = ldap->search(tmpquery);
        DW(sprintf("ldap->search(\"%s\")", tmpquery));
  }
  ;

  if (err)
  {
     ldap_err_count++;
     if (ldap_err_count > QUERY(ldap_max_err)) return 0;
     ldap_reconnect();
     return ldap_getvirt(hostname, id);
  }

  res = result->fetch();
  ldap_last_query = time();

  DW(sprintf("result->fetch() = %O", res));

#ifdef THREADS
  destruct(key);
#endif

  if (res)
  {
     string vpath;

     vpath = res->homeDirectory[0];

     if (vpath[-1] != '/') vpath += "/";

     // owner, hostname, path, ttl
     virtcache[hostname] = ConfigCache(res->uid[0],
				       hostname,
				       vpath + QUERY(wwwdir),
				       vpath + QUERY(cgidir),
				       vpath + QUERY(logdir),
				       vpath,
				       (int)res->uidNumber[0],
				       (int)res->gidNumber[0],
				       QUERY(ttl_positive));

     return vpath;
  }

  if (lame_users && hostname[0..3] == "www.")
  {
      string tmphost = hostname[4..];

#ifdef THREADS
  object key = mutex->lock();
#endif

      mixed err = catch
      {
            result = ldap->search(sprintf(ldapquery, tmphost));
      }
      ;
    
      if (err)
      {
         ldap_err_count++;
         if (ldap_err_count > QUERY(ldap_max_err)) return 0;
         ldap_reconnect();
         return ldap_getvirt(hostname, id);
      }

      res = result->fetch();
      ldap_last_query = time();

#ifdef THREADS
  destruct(key);
#endif

      if (res)
      {
         string vpath;
    
         vpath = res->homeDirectory[0];
    
         if (vpath[-1] != '/') vpath += "/";
    
         // owner, hostname, path, ttl
         virtcache[hostname] = ConfigCache(res->uid[0],
                       			       hostname,
                       			       vpath + QUERY(wwwdir),
                       			       vpath + QUERY(cgidir),
                       			       vpath + QUERY(logdir),
                       			       vpath,
                       			       (int)res->uidNumber[0],
                       			       (int)res->gidNumber[0],
                       			       QUERY(ttl_positive));
    
         return vpath;
      }

  }

  return 0;
}

string recursive_check_virtual(object id, string hostname, void|string prefix)
{
  int ctime = time();

  if (!prefix) prefix = "";

  if (virtcache[hostname] &&
      !virtcache[hostname]->dynamic &&
      virtcache[hostname]->expires >= ctime &&
      virtcache[hostname]->virtpath)
     return virtcache[hostname]->virtpath + "/" + prefix;
  else
  {
     id->pragma["no-cache"] = 1;

     if (!virtcache[hostname] || virtcache[hostname]->expires < ctime)
     {
        DW("recursive_check_virtual: (cache miss) " + hostname + "\n");
        string ret = ldap_getvirt(hostname, id);
        if (ret) return ret + QUERY(wwwdir) + prefix;
     }
     else
     {
        DW("recursive_check_virtual: (cache hit) " + hostname + "\n");
        return virtcache[hostname]->virtpath + "/" + prefix;
     }
  }
  
  if (!virtcache[hostname] || virtcache[hostname]->expires < ctime)
  {
     if (hostname == "") return 0;
   
     array hostparts = hostname / ".";
   
     DW(sprintf("recursive_check_virtual: hostparts = %O", hostparts));
   
     if (prefix != "") prefix += ".";
   
     prefix += hostparts[0];
     hostname = hostparts[1..] * ".";
   
     string ret = recursive_check_virtual(id, hostname, prefix);
   
     if (!ret) return 0;
     else if (ret[-1] != '/') ret += "/";

     ret = replace(ret, "//", "/");
   
     if (Stdio.is_dir(ret))
     {
        if (virtcache[hostname] && virtcache[hostname]->owneruid)
        {
           virtcache[prefix + "." + hostname] =
	           ConfigCache(virtcache[hostname]->owneruid,
	                       prefix + "." + hostname,
	                       ret,
			       virtcache[hostname]->cgipath,
			       virtcache[hostname]->logpath,
			       virtcache[hostname]->homedir,
			       virtcache[hostname]->uidnumber,
			       virtcache[hostname]->gidnumber,
			       QUERY(ttl_positive));
   	   virtcache[prefix + "." + hostname]->dynamic = 1;
        }
   
        return ret;
     }
     else
     {
        if (virtcache[hostname] && virtcache[hostname]->owneruid)
        {
           virtcache[prefix + "." + hostname] =
	           ConfigCache(virtcache[hostname]->owneruid,
	                       prefix + "." + hostname,
	                       ret,
			       virtcache[hostname]->cgipath,
			       virtcache[hostname]->logpath,
			       virtcache[hostname]->homedir,
			       virtcache[hostname]->uidnumber,
			       virtcache[hostname]->gidnumber,
			       QUERY(ttl_negative),
			       hostname);
   	   virtcache[prefix + "." + hostname]->dynamic = 1;
        }
   
        return ret;
     }
  }

  return 0;
}

string find_nearest_virt(string name)
{
  if (name == "") return 0;

  if (virtcache[name]) return name;

  array hostparts = name / ".";

  return find_nearest_virt(hostparts[1..] * ".");
}

void create()
{
  defvar("ldap_url", "ldap://localhost/dc=none",
         "LDAP: database URL", TYPE_STRING,
	 "LDAP database with virtuals data.");

  defvar("ldap_reconnect", 1800, "LDAP: Reconnect interval", TYPE_INT,
         "Time since last query to reconnect to ldap.");

  defvar("ldap_max_err", 10, "LDAP: Max connection attempts", TYPE_INT,
         "Caudium try to connect to LDAP n times, and return error.");

  defvar("bind_dn", "cn=readonly,ou=adm,dc=none",
         "LDAP: Bind DN", TYPE_STRING,
	 "Bind DN");

  defvar("base_dn", "ou=caudium,dc=none",
         "LDAP: Base DN", TYPE_STRING,
	 "DN with virtuals data.");

  defvar("bind_pw", "secret", "LDAP: Bind password", TYPE_STRING,
         "Password used to bind");

  defvar("host_query", "(wwwDomain=%s)", "LDAP: Query", TYPE_STRING,
         "LDAP query used to get virtual data");

  defvar("proto_ver", 2, "LDAP: Protocol version", TYPE_INT,
         "Which LDAP protocol version use to bind");

  defvar("ttl_reconnect", 600, "LDAP: LDAP connection TTL", TYPE_INT,
	 "Time since last LDAP query to reconnect.");

  defvar("defvirtual", "default.domain.com", "Default virtual name", TYPE_STRING,
	 "Redirect to this virtual, if no valid.");

  defvar("searchpath", "/var/www/", "Default path", TYPE_DIR,
	 "If no virtual found, this is default path.");

  defvar("wwwdir", "htdocs/", "WWW root directory", TYPE_STRING,
         "Directory, where are virtuals and subvirtuals stored.");

  defvar("cgidir", "cgi-bin/", "CGI directory", TYPE_STRING,
         "Directory, mounted as cgi-bin");

  defvar("logdir", "logs/", "Logs directory", TYPE_STRING,
         "Directory, where are logfiles");

  defvar("ttl_positive", 1800, "TTL: Positive TTL", TYPE_INT,
         "Time to cache positive config hits.");

  defvar("ttl_negative", 60, "TTL: Negative TTL", TYPE_INT,
         "Time to cache negative config hits.");

  defvar("lamers_mode", 1, "Enable lamers friendly mode", TYPE_INT,
         "Append www prefix to each wirtual.");
}

void precache_rewrite(object id)
{
  string hostname = lower_case( ( (id->host || "localhost" ) / ":" )[0] );
  string host, p;
  mapping vhs = ([]);

  id->raw_url = id->host + id->raw_url;

  if (!id->misc->host) id->misc->host = hostname;

  host = recursive_check_virtual(id, hostname);

  if (!host)
  {
    host = find_nearest_virt(hostname);

    if (!host) 
    {
        vhs->wwwpath = QUERY(searchpath);
        vhs->logpath = 0;
        vhs->cgipath = 0;
        vhs->uid = "nobody";
        vhs->redirect = QUERY(defvirtual);
        id->misc->vhs = vhs;
        return;
    }
    else
    {
      virtcache[hostname] = ConfigCache(virtcache[host]->owneruid,
            hostname, virtcache[host]->virtpath,
	    virtcache[host]->cgipath, virtcache[host]->logpath,
	    virtcache[host]->homedir, virtcache[host]->uidnumber,
	    virtcache[host]->gidnumber,
            QUERY(ttl_negative), host);
      virtcache[hostname]->dynamic = 1;
      hostname = host;
    }
  }

  vhs->wwwpath = virtcache[hostname]->virtpath;
  vhs->logpath = virtcache[hostname]->logpath;
  vhs->cgipath = virtcache[hostname]->cgipath;
  vhs->uid = virtcache[hostname]->owneruid;
  vhs->redirect = virtcache[hostname]->redirect;
  vhs->uidnumber = virtcache[hostname]->uidnumber;
  vhs->gidnumber = virtcache[hostname]->gidnumber;
  vhs->homedir = virtcache[hostname]->homedir;
  vhs->host = hostname;

  DW(sprintf("vhs = %O", vhs));

  id->misc->vhs = vhs;
}

void start()
{
  if (QUERY(lamers_mode)) lame_users = 1;

  ldapquery = QUERY(host_query);

  mixed err = catch {
   ldap_reconnect();
  };

  if(err) { DW("Error loading LDAP... Maybe because it is not configured"); }

  virtcache[QUERY(defvirtual)] = ConfigCache("nobody",
  QUERY(defvirtual), QUERY(searchpath), 0, 0, "/tmp", 65500, 65500,
  9999999999);
}

string status()
{
  string result = "";

  if (!_initialized_ok) return "<h3>Module disabled - error</h3>";

  result += "<h3>Module enabled</h3>";
  result += "<h3>Info:<h3>\n";

  result += "<table><tr><td align=\"left\">Virtuals in LDAP:</td><td>: " +
	 virtuals + "</td></tr>\n" +
	 "<tr><td align=\"left\">Virtuals in cache:</td><td>: " +
	 sizeof(indices(virtcache)) + "</td></tr>\n" +
	 "<tr><td align=\"left\">LDAP bind result:</td><td>: " +
	 ldap_bind_result  + "</td></tr>\n" +
	 "<tr><td align=\"left\">LDAP queries:</td><td>: " +
	 ldap_count + "</td></tr>\n" + "</table><br>\n";

  result += "<h3>Virtuals in config cache:</h3>\n";

  result += "<table bgcolor=\"#00ff80\">\n";

  foreach (sort(indices(virtcache)), string name)
  {
     result += "<tr><td><small>" + name + "</small></td>" +
	       "<td><small>" + (virtcache[name]->owneruid || "not known") + "</small></td>" +
               "<td><small>" + (virtcache[name]->virtpath || "not defined") + "</small></td>" +
               "<td><small>" + (virtcache[name]->logpath || "not defined") + "</small></td>" +
               "<td><small>" + (virtcache[name]->cgipath || "not defined") + "</small></td>" +
               "<td><small>" + (virtcache[name]->expires || "-") + "</small></td>" +
	       "<td><small>" + (virtcache[name]->dynamic ? "dynamic" : "static") + "</small></td>" +
	       "</tr>\n";
  }

  result += "</table>\n";

  return result;
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: ldap_url
//! LDAP database with virtuals data.
//!  type: TYPE_STRING
//!  name: LDAP: database URL
//
//! defvar: ldap_reconnect
//! Time since last query to reconnect to ldap.
//!  type: TYPE_INT
//!  name: LDAP: Reconnect interval
//
//! defvar: ldap_max_err
//! Caudium try to connect to LDAP n times, and return error.
//!  type: TYPE_INT
//!  name: LDAP: Max connection attempts
//
//! defvar: bind_dn
//! Bind DN
//!  type: TYPE_STRING
//!  name: LDAP: Bind DN
//
//! defvar: base_dn
//! DN with virtuals data.
//!  type: TYPE_STRING
//!  name: LDAP: Base DN
//
//! defvar: bind_pw
//! Password used to bind
//!  type: TYPE_STRING
//!  name: LDAP: Bind password
//
//! defvar: host_query
//! LDAP query used to get virtual data
//!  type: TYPE_STRING
//!  name: LDAP: Query
//
//! defvar: proto_ver
//! Which LDAP protocol version use to bind
//!  type: TYPE_INT
//!  name: LDAP: Protocol version
//
//! defvar: ttl_reconnect
//! Time since last LDAP query to reconnect.
//!  type: TYPE_INT
//!  name: LDAP: LDAP connection TTL
//
//! defvar: defvirtual
//! Redirect to this virtual, if no valid.
//!  type: TYPE_STRING
//!  name: Default virtual name
//
//! defvar: searchpath
//! If no virtual found, this is default path.
//!  type: TYPE_DIR
//!  name: Default path
//
//! defvar: wwwdir
//! Directory, where are virtuals and subvirtuals stored.
//!  type: TYPE_STRING
//!  name: WWW root directory
//
//! defvar: cgidir
//! Directory, mounted as cgi-bin
//!  type: TYPE_STRING
//!  name: CGI directory
//
//! defvar: logdir
//! Directory, where are logfiles
//!  type: TYPE_STRING
//!  name: Logs directory
//
//! defvar: ttl_positive
//! Time to cache positive config hits.
//!  type: TYPE_INT
//!  name: TTL: Positive TTL
//
//! defvar: ttl_negative
//! Time to cache negative config hits.
//!  type: TYPE_INT
//!  name: TTL: Negative TTL
//
//! defvar: lamers_mode
//! Append www prefix to each wirtual.
//!  type: TYPE_INT
//!  name: Enable lamers friendly mode
//
