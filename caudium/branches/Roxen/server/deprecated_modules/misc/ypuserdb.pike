// This is a roxen module. Copyright � 1996 - 1998, Idonex AB.

// YP User database. Reads the system password database and use it to
// authentificate users.

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

#ifndef __NT__
#if constant(Yp.Domain)

// import Stdio;
// import Array;
// import Yp;

/*
 * Globals
 */
object(Yp.Domain) domain;

/*
 * Statistics
 */

int succ, fail, nouser, emptypasswd;
mapping(string:int) failed = ([]);

string status()
{
  return("<h1>Security info</h1>\n"
	 "<b>YP-server:</b> " + domain->server("passwd.byname") + "<br>\n"
	 "<b>YP-domain:</b> " + default_yp_domain() + "<br>\n"
	 "<p>\n"
	 "<b>Successful auths:</b> " + (string)succ +
	 ", " + (string)emptypasswd + " had empty password fields.<br>\n"
	 "<b>Failed auths:</b> " + (string)fail +
	 ", " + (string)nouser + " had the wrong username.<br>\n"
	 "<p>\n"
	 "<h3>Failure by host</h3>" +
	 (Array.map(indices(failed), lambda(string s) {
	   return roxen->quick_ip_to_host(s) + ": " + failed[s] + "<br>\n";
	 }) * "") +
	 "<p>The database has " + sizeof(domain->all("passwd.byname")) +
	 " entries.");
}

/*
 * Auth functions
 */

array(string) userinfo(string u)
{
  if (sizeof(u)) {
    string s = domain->match("passwd.byname", u);
    if (s) {
      return(s/":");
    }
  }
  return(0);
}

array(string) userlist()
{
  mapping(string:string) m = domain->all("passwd.byname");
  if (m) {
    return(indices(m));
  }
  return(0);
}

string user_from_uid(int u)
{
  string s = domain->match("passwd.byuid", (string)u);
  if (s) {
    return((s/":")[0]);
  }
  return(0);
}

array|int auth(array(string) auth, object id)
{
  array(string) arr = auth[1]/":";
  string u, p;

  u = arr[0];
  if (sizeof(arr) <= 1) {
    p = "";
  } else {
    p = arr[1..]*":";
  }
  string s = domain->match("passwd.byname", u);
  if (!s) {
    fail++;
    nouser++;
    failed[id->remoteaddr]++;
    return(({ 0, auth[1], -1 }));
  }
  arr = s/":";
  if ((!sizeof(arr[1])) || crypt(p, arr[1])) {
    // Valid user
    id->misc->uid = arr[2];
    id->misc->gid = arr[3];
    id->misc->gecos = arr[4];
    id->misc->home = arr[5];
    id->misc->shell = arr[6];
    succ++;
    emptypasswd += !sizeof(arr[1]);
    return(({ 1, u, 0 }));
  }
  fail++;
  failed[id->remoteaddr]++;
  return(({ 0, auth[1], -1 }));
}

/*
 * Registration and initialization
 */

array register_module()
{
  return(({ MODULE_AUTH,
	      "YP (NIS) authorization",
	      "Experimental module for authorization using "
	      "Pike's internal YP-database interface.",
	      ({}), 1 }));
}

void start(int i)
{
  if (!domain) 
    domain = Yp.Domain();
}

#endif /* constant(Yp.Domain) */
#endif
