/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
//! module: .htaccess support
//!  Almost complete support for NCSA/Apache .htaccess files.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_SECURITY | MODULE_URL
//! cvs_version: $Id$
//

// .htaccess compability by David Hedbor, neotron@idonex.se 
//   Changed into module by Per Hedbor, per@idonex.se

// import Stdio;

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#include <caudium.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_SECURITY | MODULE_URL;
constant module_name = ".htaccess support";
constant module_doc  = "Almost complete support for NCSA/Apache .htaccess files. See "
	      "<a href=http://hoohoo.ncsa.uiuc.edu/docs/setup/access/Overview.html>http://hoohoo.ncsa.uiuc.edu/docs/setup/access/Overview.html</a> for more information.";
constant module_unique = 1;

#define SERIOUS
//#define HTACCESS_DEBUG

#ifdef HTACCESS_DEBUG
#define HT_WERR(X) werror("HTACCESS: %s\n",X)
#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));else HT_WERR(A);}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));else HT_WERR(A);}while(0)
#else /* !HTACCESS_DEBUG */
#define HT_WERR(X)
#define TRACE_ENTER(A,B)
#define TRACE_LEAVE(A)
#endif /* HTACCESS_DEBUG */

#define IS_PATH (strlen(id->not_query)&&id->not_query[0]=='/')
#define NOT_QUERY (id->not_query)

void create()
{
  defvar("cache_all", 1, "Cache the failures",
	 TYPE_FLAG,
	 "If set, cache failures to find a .htaccess file as well as found "
	 "ones. This will limit the number of stat(2) calls quite dramatically."
	 " This should be set if you have a busy site! It does have at least "
	 " one disadvantage: The user has to press reload to get the new "
	 ".htaccess file parsed."
#ifndef SERIOUS
	 " Since the poor user is quite used to reloading,"
	 " that is not usually a problem. Just blame the client-side cache. "
	 ":-)"
#endif
    );
  defvar("file", ".htaccess", "Access file name", TYPE_STRING|VAR_MORE,
	 "The file name of the file where the access information is stored.");
  defvar("denyhtlist", ({".htaccess", ".htpasswd", ".htgroup"}),
	 "Deny file list", TYPE_STRING_LIST, 
	 "Always deny access to these files. This is useful to protect "
	 "htaccess related files.");
  
}


/* Parse the 'limit' tag. This function is called via the builtin
 * SGML parser. 
 */

string parse_limit(string tag, mapping m, string s, mapping id, mapping access)
{
  string line, tmp, ent, item;
  mixed data;
  mapping tmpmap = ([]);
  if(!sizeof(m))
    m = ([ "all": 1 ]);
  
  foreach(s / "\n", line) {
    tmp = 0;

    line = (replace(line, "\t", " ") / " " - ({""})) * " ";

    if(!strlen(line))
      continue;

    if(line[0] == ' ') /* There can be only one /Connor MacLeod */
      line = line[1..];

    if(sscanf(line, "deny from %s", data))
      tmp = "deny";
    else if(sscanf(line, "allow from %s", data))
      tmp = "allow";
    else if(sscanf(line, "require %s %s", ent, data) == 2)
      tmp = ent;
    else if(sscanf(line, "satisfy %s", data)) {
      tmp = "all";
      if(data == "all")
	data = 1;
      else
	data = -1;
    } else if(!search(line, "require valid-user")) {
      tmp = "valid-user";
      data = 1;
    }
    if(sscanf(line, "order %s", data)) {
      data = replace(data, " ", "");
      if(!search(data, "allow"))
	data = 1;
      else if(!search(data, "mutual-failure"))
	data = -1;
      else 
      	data = 0;
      tmpmap->order = data;
    } else if(tmp) {
      if(stringp(data)) {
	foreach(data / " ", item) {
	  if(strlen(item)) {
	    if(!multisetp(tmpmap[tmp]))
	      tmpmap[ tmp ] = (<>);
	    tmpmap[ tmp ] += (< item >);
	  }
	}
      } else {
	tmpmap[tmp] = data;
      }
    }
  }
  if(!tmpmap->all)
    tmpmap->all = 1;

  foreach(indices(m), tmp)
    if(!access[tmp])
      access[tmp] = tmpmap;
    else 
      foreach(indices(tmpmap), data)
	if(access[tmp][data])
	  access[tmp][data] += tmpmap[data];
	else
	  access[tmp][data] = tmpmap[data];
  return "";
}

/* parse the .htaccess file */
mapping|int parse_htaccess(object f, object id, string rht)
{
  string htaccess, line;
  string cache_key;
  array(int) s;
  mixed in_cache;
  mapping access = ([ ]);
  cache_key = "htaccess:" + id->conf->name;
    

  s = (array(int))f->stat();

  if((in_cache = cache_lookup(cache_key, rht)) && (s[3] == in_cache[0]))
    return in_cache[1];

  htaccess = f->read(0x7fffffff);
  
  if(!htaccess || !strlen(htaccess))
    return 0;

  htaccess = replace(htaccess, "\\\n", " ");

  access = ([]); 

  htaccess = parse_html(htaccess - "\r",
			([]), (["limit": parse_limit ]), id, access);

  if ((!access["head"]) && access["get"]) {
    access["head"] = access["get"];
  }

  foreach(htaccess / "\n"-({""}), line) {
    string cmd, rest;

    if(line[0] == '#')
      continue;

    line = (replace(line, "\t", " ") / " " - ({""})) * " ";

    if(!strlen(line))
      continue;
    
    if(line[0]==' ')
      line=line[1..];

    sscanf(line, "%[^ ] %s", cmd, rest);

    cmd = lower_case(cmd);    

    switch(cmd) {
    case "redirecttemp":
    case "redirecttemporary":
    case "redirectperm":
    case "redirectpermanent":
      cmd = "redirect";

      // FALL-THROUGH
    case "authuserfile":
    case "authname":
    case "authgroupfile":
    case "redirect":
    case "errorfile": 
      access[cmd] = rest;
      break;

    default:
#ifdef HTACCESS_DEBUG
      report_debug(".htaccess: Unsupported command in "+cache_key+": "+ cmd +"\n");
#endif
    }
    HT_WERR(sprintf("Result of .htaccess file parsing -> %O", access));
  }
  cache_set(cache_key, rht, ({s[3], access}));
  return access;
}

/* The host/ip verifier */
int allowed(multiset allow, string hname, string ip, int def)
{
  string s;
  int ok, i, a;
  array tmp1, tmp2;
  if(!allow || !sizeof(allow))
    return 0;
  foreach(indices(allow), s)
  {
    if(s == "all" || s==ip || s == hname)
    {
      ok = 1;
      HT_WERR(sprintf("IP/hostname access deny/allow exact match:"
		      "HTACCESS: (%s -> %s || %s)\n", s, ip, hname));
    }
    if(!ok && (int)s && (ip/".")[0] == s)
    {
      ok = 1;

      HT_WERR(sprintf("IP/hostname access deny/allow ip match:"
		     "HTACCESS: (%s -> %s || %s)\n", s, ip, hname));
    }
    if(!ok)
    {
      tmp1 = lower_case(s) / "." - ({""});
      tmp2 = lower_case(hname) / "." - ({""});
      a = sizeof(tmp2)  - sizeof(tmp1);
      if(a > -1)
      {
	for(i = 0; i < sizeof(tmp1); i++)
	  if(tmp1[i] != tmp2[a+i])
	  { 
	    ok = -1;
	    break;
	  } 
	if(!ok)
	  ok = 1;
	else 
	  ok = 0;
      }
#ifdef HTACCESS_DEBUG
      if(ok)
	HT_WERR(sprintf("IP/hostname access deny/allow hostname/"
		       "domain match:\n"
		       "HTACCESS: (%s -> %s || %s)", s, ip, hname));
#endif
      
    }
    if(!ok)
    {
      tmp2 = ip / "." - ({""});      
      if(sizeof(tmp2) >= sizeof(tmp1))
      {
	for(i = 0; i < sizeof(tmp1); i++)
	  if(tmp1[i] != tmp2[i])
	  { 
	    ok = -1;
	    break;
	  } 
	if(!ok)
	  ok = 1;
	else 
	  ok = 0;
      }
#ifdef HTACCESS_DEBUG
      if(ok)
	HT_WERR(sprintf("IP/hostname access deny/allow ip-number "
		       "match:\nHTACCESS: (%s -> %s || %s)", s, ip, hname));
#endif
      
    }
    if(ok)
      break;
  }
  if(!ok && hname == ip)
    ok = def;

  return ok;
}

mapping validate(string aname)
{
  return (["type":"text/html",
	   "error":401,
	   "extra_heads":
	   ([ "WWW-Authenticate":
	     "basic realm=\""+ aname +"\""]),
	   ]);
}

/* Check if the password is correct.  */
int match_passwd(string org, string try)
{
  if(!strlen(org))   return 1;
  if(crypt(try, org)) return 1;
}


/* Check if this user has access */

int validate_user(int|multiset users, array auth, string userfile, object id)
{
  string passwd, line;
  HT_WERR(sprintf("Validating user %s.", auth[0]));

  if(!users) {
    HT_WERR("Warning. No users are allowed to see this page.");
    return 0;
  } else {
    if(multisetp(users) && !users[auth[0]])
    {
      HT_WERR(sprintf("Failed auth. User %s not among the "
		     "valid users.", auth[0]));
      HT_WERR(sprintf("Valid users -> %O", users));
      return 0;
    }
  }
  if(!userfile)
  { 
    if(id->auth)
      return id->auth[0];
    return 0;
  }

  array st;

  if((!(st = file_stat(userfile))) || (st[1] == -4) || (!(passwd = Stdio.read_bytes(userfile))))
  {
    if (st && (st[1] == -4)) {
      report_error(sprintf("HTACCESS: Userfile \"%s\" is a device!\n"
			   "query: \"%s\"\n", userfile, id->query + ""));
    }
#ifdef HTACCESS_DEBUG
    HT_WERR(sprintf("Failed to read password file (%s)", 
		   userfile));
#endif    
    return 0;
  }
  passwd = replace(passwd, "\r", "");
  foreach(passwd/"\n", line)
  {
    array(string) arr = line/":";
    if(sizeof(arr) >= 2)
    {
      string user = arr[0];
      string pass = arr[1];
      if((users == 1 || users[user]) && (user == auth[0]) &&
	 match_passwd(pass, auth[1]))
      {
#ifdef HTACCESS_DEBUG
	HT_WERR("Successful auth.");
#endif      
	return 1;
      }
    }
  }
  return 0;
}

/* Check if the users is a member of the valid group(s) */
int validate_group(multiset grps, array auth, string groupfile, string userfile,
		   object id)
{
  mapping g;
  string groups, cache_key, grp, members, user, s2;
  array(int) s;
  object f;
  mixed in_cache;

  cache_key = "groupfile:" + id->conf->name;

  if (!groupfile) {
#ifdef HTACCESS_DEBUG
    HT_WERR(sprintf("!groupfile"));
#endif
    if(!validate_user(1, auth, userfile, id))
      return 0;

    foreach(indices(grps), grp) {
      array gr
#if constant(getgrnam)
	= getgrnam(grp)
#endif
	;
#ifdef HTACCESS_DEBUG
      HT_WERR("Checking for unix group "+grp+" ... "
	     +(gr&&gr[3]?"Existant":"Nope")+"");
#endif
      if(!gr || !gr[3])
	continue;
      if(!userfile && id->conf->userlist(id)){
#ifdef HTACCESS_DEBUG
	HT_WERR("Checking login group for user "+auth[0]
	       +"("+id->conf->userinfo(auth[0],id)[3]+") against gid("+gr[2]+")");
#endif
	if((int)id->conf->userinfo(auth[0],id)[3]==gr[2])
	  return 1;
      }
      int gr_i;
      foreach(indices(gr[3]), gr_i){
#ifdef HTACCESS_DEBUG
	HT_WERR("Checking for user "+auth[0]+" in group "+grp+
	       " ("+gr[3][gr_i]+") ... "+
	       (gr[3][gr_i]&&gr[3][gr_i]==auth[0]?"Yes":"Nope")+"");
#endif
	if(gr[3][gr_i]&&gr[3][gr_i]==auth[0])
	  return 1;
      }
    }
    return 0;
  }

  array st;

  f = Stdio.File();

  if((!(st = file_stat(groupfile))) || (st[1] == -4) ||
     (!(f->open(groupfile, "r")))) {
    if (st && (st[1] == -4)) {
      report_error(sprintf("The groupfile \"%s\" is a device!\n"
			   "userfile: \"%s\"\n"
			   "query: \"%s\"\n", groupfile, userfile, id->query + ""));
    }
#ifdef HTACCESS_DEBUG
    HT_WERR("The groupfile "+groupfile+" cannot be opened.");
#endif
    return 0;
  }

#ifdef FD_DEBUG
  mark_fd(f->query_fd(), ".htaccess groupfile ("+groupfile+")\n");
#endif
  s = (array(int))f->stat();
  
  if((in_cache = cache_lookup(cache_key, groupfile))
     && (s[3] == in_cache[0]))
    g = in_cache[1];
  else if(groups = f->read(0x7fffffff)) {
    g = ([]);
    groups = replace(groups, "\r", "");
    groups = replace(groups, "\\\n", " ");
    foreach(groups/"\n", s2)
    {
      if(sscanf(s2, "%s:%s", grp, members) == 2)
      {
	foreach(replace(members, ({",", "\t"}), ({" ", " "})) / 
		" " - ({""}), user)
	{
	  if(!multisetp(g[grp]))
	    g += ([ grp : (<>) ]);
	  g[grp][user]=1;
	}
      }
    }
    cache_set(cache_key, groupfile, ({s[3], g}));
  }
  f->close();
  destruct(f);
  foreach(indices(grps), grp)
  {
#ifdef HTACCESS_DEBUG
    HT_WERR("Checking for group "+grp+" ... "
	   +(g[grp]?"Existant":"Nope")+"");
#endif
    if(g[grp])
      if(validate_user(g[grp], auth, userfile, id))
	return 1;
  }
}

/* Check if the person accessing this page should be denied or not. */
mapping|string|int htaccess(mapping access, object id)
{
  int hok;
  mixed tmp;
  multiset l;

  string htaccess, aname, userfile, tmp2, groupfile, hname, method, errorfile;

  TRACE_ENTER("htaccess->htaccess()", htaccess);

  if(access->redirect)
  {
    string from, to;

    if(sscanf(access->redirect, "%s %s", from, to) < 2) {
      TRACE_LEAVE("redirect (access->redirect)");
      return http_redirect(access->redirect,id);
    }

    if(search(NOT_QUERY, from) + 1) {
      TRACE_LEAVE("redirect");
      return http_redirect(to,id);
    }
  }
  aname      = access->authname || "authorization";
  userfile   = access->authuserfile;
  groupfile  = access->authgroupfile;
#ifdef HTACCESS_DEBUG
  HT_WERR("Verifying access.");
#endif

  TRACE_ENTER("Checking method :" + id->method, htaccess);

  if(!access[method = lower_case(id->method)])
  {
    if(access->all)
      method = "all";
    else switch(method)
    {
    case "list":
    case "dir":
      if (access->list) {
	method = "list";
	break;
      } else if (access->dir) {
	method = "dir";
	break;
      }
    case "stat":
    case "head":
    case "cwd":
    case "post":
      if (access->get) {
	method = "get";
	break;
      }

    case "get":
      if (access->head) {
	method = "head";
	break;
      }
      TRACE_LEAVE("Method GET not specified!");
      TRACE_LEAVE("Assumed OK");
      return 0;
      
    case "mv":
    case "chmod":
    case "mkdir":
    case "delete":
    default:
      if (access->put) {
	method = "put";
	break;
      }
      TRACE_LEAVE("Unknown method or PUT or DELETE");
      TRACE_LEAVE("Assumed denied");
      return 1;
    }
  }

  TRACE_LEAVE("Method to use:"+method);
  
  if(!access[method]->allow && !access[method]->deny)
    hok = 1;
  else 
  {
    if(access[method]->order == 1) {
      if(allowed(access[method]->allow, id->remoteaddr, id->remoteaddr, 0))
	hok = 1;
      if(allowed(access[method]->deny, id->remoteaddr, id->remoteaddr, 1))
	hok = 0;
    } else if(access[method]->order == 0) {
      if(allowed(access[method]->deny, id->remoteaddr, id->remoteaddr, 1))
	hok = 0;
      if(allowed(access[method]->allow, id->remoteaddr, id->remoteaddr, 0))
	hok = 1;
    } else 
      hok = (allowed(access[method]->allow, id->remoteaddr,
		     id->remoteaddr, 0) && 
	     allowed(access[method]->deny, id->remoteaddr, 
		     id->remoteaddr, 1));

    if(!hok)
    {
      if(id->remoteaddr)
      {
	if(!((hname=caudium->quick_ip_to_host(id->remoteaddr)) && 
	     hname != id->remoteaddr))
	  hname = caudium->blocking_ip_to_host(id->remoteaddr);
      }
    
      if(!hname)
	hname = id->remoteaddr;
      if(access[method]->order == 1) {
	if(allowed(access[method]->allow, hname, id->remoteaddr, 0))
	  hok = 1;
	if(allowed(access[method]->deny, hname, id->remoteaddr, 1))
	  hok = 0;
      } else if(access[method]->order == 0) {
	if(allowed(access[method]->deny, hname, id->remoteaddr, 1))
	  hok = 0;
	if(allowed(access[method]->allow, hname, id->remoteaddr, 0))
	  hok = 1;
      } else 
	hok = (allowed(access[method]->allow, hname, id->remoteaddr, 0) && 
	       allowed(access[method]->deny, hname, id->remoteaddr, 1));
    }
  }
  if(!hok && access[method]->all == 1)
  {
    if((hname || id->remoteaddr) == id->remoteaddr) {
      TRACE_LEAVE("2");
      return 2;
    }
    TRACE_LEAVE("1");
    return 1;
  } else if(hok && access[method]->all == -1) {
    TRACE_LEAVE("0");
    return 0;
  }
#ifdef HTACCESS_DEBUG
  if(hok) HT_WERR("Host based access verified and granted.");
#endif

  if(access[method]->user || access[method]["valid-user"] 
     || access[method]->group)
  {
#ifdef HTACCESS_DEBUG
    HT_WERR("Verifying user access.");
#endif
    if(!id->realauth)
    {
#ifdef HTACCESS_DEBUG
      HT_WERR("No authification string from client.");
#endif
      TRACE_LEAVE("No auth");
      return validate(aname);
    } else {
      array(string) auth;
      
      auth = id->realauth/":";

      if((access[method]->user && 
	  validate_user(access[method]->user, auth, userfile, id)) ||
	 (access[method]["valid-user"] &&
	  validate_user(1, auth, userfile, id)) ||
	 (access[method]->group &&
	  validate_group(access[method]->group, auth, 
			 groupfile, userfile, id)))
      {
#ifdef HTACCESS_DEBUG
	HT_WERR("User access ok!");
#endif
	id->auth = ({ 1, auth[0], 0 });

	TRACE_LEAVE("OK");
	return 0;
      } else {
#ifdef HTACCESS_DEBUG
	HT_WERR("User access denied, invalid user.");
#endif
	id->auth = ({ 0, auth[0], auth[1] });
	TRACE_LEAVE("Invalid user");
	return validate(aname);
      }
    }
  }
  TRACE_LEAVE("OK");
}

inline string dot_dot(string from)
{
  if(from=="/") return "";
  return combine_path(from, "../");
}

string|int cache_path_of_htaccess(string path, object id)
{
  mixed f;
  f = cache_lookup("htaccess_files:"+id->conf->name, path);
#ifdef HTACCESS_DEBUG
  if(f==0)
    HT_WERR("Location of .htaccess file for "+path+" not cached.");
  else if(f==-1)
    HT_WERR("Non-existant .htaccess file cached: "+path+"");
  else if(f)
    HT_WERR("Existant .htaccess file cached: "+path+"");
#endif
  return f;
}

void cache_set_path_of_htaccess(string path, string|int htaccess_file, object id)
{
#ifdef HTACCESS_DEBUG
  HT_WERR("Setting cached location for "
	 +path+" to "+htaccess_file+"");
#endif
  cache_set("htaccess_files:"+id->conf->name, path, htaccess_file);
}

// This function traverse the virtual filepath to see if there are any 
// .htaccess files hiding anywhere. When (and if) if finds one, it returns 
// the full path to it _and_ the actual open file (modified by Per)

array new_find_htaccess_file(object id, string vpath)
{
  HT_WERR(sprintf("new_find_htaccess_file(X, %O)", vpath));

  if (vpath == "") return 0;

  string|int path;

  int use_cache;
  if (use_cache = (!id->pragma["no-cache"])) {
    if (path = cache_path_of_htaccess(vpath, id)) {
      HT_WERR(sprintf("Cached: path = %O", path));

      array st;

      if (stringp(path) && (st = file_stat(path)) && (st[1] != -4)) {
	Stdio.File f = open(path, "r");
	if(f) {
	  return ({ path, f });
	}
	// Invalid cache entry. Invalidate the cache path.
	use_cache = 0;
      } else {
	if (st && (st[1] == -4)) {
	  report_error(sprintf("HTACCESS: The htaccess-file in \"%s\" is a device!\n"
			       "vpath: \"%s\"\n"
			       "query: \"%s\"\n", path, vpath, id->query + ""));
	  return 0;
	}
	if(QUERY(cache_all))
	  return 0;
      }
    }
  }
  // Not found in cache...

  array(string) segments = vpath/"/";
  string subvpath = "";

  path = -1;

  foreach(segments, string segment) {
    subvpath += segment + "/";

    HT_WERR(sprintf("Trying vpath %O", subvpath));

    string|int p;

    if (use_cache && (p = cache_path_of_htaccess(subvpath, id))) {
      HT_WERR(sprintf("Cached: path = %O\n", p));
      if (stringp(p) || !stringp(path)) {
	path = p;
	continue;
      }
    }

    if (!(p = id->conf->real_file(subvpath, id))) {
      // No use checking any deeper.
      HT_WERR("Not found.");
      break;
    }
    string fname = p + query("file");
    array st;
    if(st = file_stat(fname)) {
      HT_WERR(sprintf("Found htaccess-file: %O", fname));
      if (st[1] >= 0) {
	path = fname;
      } else {
	report_error(sprintf("HTACCESS: The htaccess-file \"%s\" is not a regular file!\n"
			     "vpath: \"%s\"\n"
			     "query: \"%s\"\n", fname, vpath, id->query + ""));
      }
    }
    if (stringp(path)) {
      cache_set_path_of_htaccess(subvpath, path, id);
    } else if (QUERY(cache_all)) {
      cache_set_path_of_htaccess(subvpath, -1, id);
    }
  }

  if (stringp(path)) {
    HT_WERR(sprintf("Result htaccess-file: %O", path));

    array st;
    if ((st = file_stat(path)) && (st[1] >= 0)) {
      Stdio.File f = open(path, "r");
      if (f)
	return ({ path, f });
      report_error(sprintf("HTACCESS: Unable to open \"%s\"!\n", path));
    } else {
      report_error(sprintf("HTACCESS: The htaccess-file \"%s\" is not a regular file!\n"
			   "vpath: \"%s\"\n"
			   "query: \"%s\"\n", path, vpath, id->query + ""));
    }
  }
  HT_WERR("No htaccess-file.");
  return 0;
}

array find_htaccess_file(object id)
{
  string vpath;

  vpath = NOT_QUERY;

  if(vpath[-1] == '/')
    return new_find_htaccess_file( id, vpath);
  else 
    return new_find_htaccess_file( id, dot_dot(vpath) );
}

mapping htaccess_no_file(object id)
{
  mixed tmp;
  mapping access = ([]);
  string file;
  if(!(tmp = find_htaccess_file(id)))
    return 0;

  access = parse_htaccess(tmp[1], id, tmp[0]);

  if(access && (access->nofile || (access->nofile=access->errorfile)))
  {
    array st;

    if ((st = file_stat(access->nofile)) && (st[1] != -4) &&
	(file = Stdio.read_bytes(access->nofile)))
    {
      file = parse_rxml(file, id);
      return http_string_answer( file );
    }
    if (st && (st[1] == -4)) {
      report_error(sprintf("HTACCESS: Nofile \"%s\" is a device!\n"
			   "query: \"%s\"\n", file, id->query + ""));
    }
  }
  return 0;
}

    

mapping try_htaccess(object id)
{
  mixed tmp;
  mapping access = ([]);

  TRACE_ENTER("htaccess->try_htaccess()", try_htaccess);

  if(!(tmp = find_htaccess_file(id)))
  {
#ifdef HTACCESS_DEBUG
    HT_WERR("No htaccess file for "+id->not_query+"");
#endif
    TRACE_LEAVE("No htaccess file.");
    return 0;
  }
  NOCACHE(); // Since there is a htaccess file we cannot cache at all.
  access = parse_htaccess(tmp[1], id, tmp[0]);

  if(access)
  {
    mixed ret;
    if(ret = htaccess(access, id))
    {
      string file;

      if(ret == 1)
      {
	if(access->errorfile)
	{
	  array st;

	  if ((st = file_stat(access->errorfile)) && (st[1] != -4) &&
	      (file = Stdio.read_bytes(access->errorfile))) {
	    file = parse_rxml(file, id);
	  } else if (st && (st[1] == -4)) {
	    report_error(sprintf("HTACCESS: Errorfile \"%s\" is a device!\n"
				 "query: \"%s\"\n", access->errorfile, id->query + ""));
	  }
	}
	id->misc->error_code = 403;

	TRACE_LEAVE("Access Denied (1)");

	return http_low_answer(403, file || 
			       ("<title>Access Denied</title>"
				"<h2 align=center>Access Denied</h2>"));
      }
      

      else if(ret == 2) {
	id->misc->error_code = 403;

	TRACE_LEAVE("Access Denied (2)");

	return http_low_answer(403, "<title>Access Denied</title>"
			       "<h2 align=center>Access Denied</h2>"
			       "<h3>This page is protected based on host name "
			       "or domain name. The server couldn't resolve "
			       "your hostname. If you try again, "
			       "it might work better.</h3>"
			       "<b>Your computer might also lack a correct "
			       "PTR DNS entry. In that "
			       "case, ask your system administrator to add "
			       "one.</b>");
      }

      else if(mappingp(ret))
      {
	if(access->errorfile)
	{
	  array st;

	  if ((st = file_stat(access->errorfile)) && (st[1] != -4) &&
	      (file = Stdio.read_bytes(access->errorfile))) {
	    file = parse_rxml(file, id);
	  } else if (st && (st[1] == -4)) {
	    report_error(sprintf("HTACCESS: Errorfile \"%s\" is a device!\n"
				 "query: \"%s\"\n", access->errorfile, id->query + ""));
	  }
	}
	id->misc->error_code = ret->error || 403;

	TRACE_LEAVE("Access Denied (mapping)");

	return  (["data":file || 
		 ("<title>Access Denied</title>"
		  "<h2 align=center>Access forbidden by user</h2>") ]) 
	  | ret; /*Mix the returned mapping with the default message :-)*/
      }
    } else
      id->misc->auth_ok = 1;
  }

  TRACE_LEAVE("OK");
}

mapping last_resort(object id)
{
  mapping access_violation;

  TRACE_ENTER("htaccess->last_resort()", last_resort);

  if(IS_PATH)
    if(access_violation = htaccess_no_file( id )) {
      TRACE_LEAVE("Access violation");
      return access_violation;
    }
  TRACE_LEAVE("OK");
}

mapping remap_url(object id)
{
  mapping access_violation;

  TRACE_ENTER("htaccess->remap_url()", remap_url);

  if(IS_PATH)
  {
    access_violation = try_htaccess( id );
    if(access_violation) {
      TRACE_LEAVE("Access violation");
      return access_violation;
    } else {

      string s = (NOT_QUERY/"/")[-1];
      if (search(QUERY(denyhtlist), s) != -1) {
	report_debug("Denied access for "+s+"\n");
	id->misc->error_code = 401;
	TRACE_LEAVE("Access Denied");
	return http_low_answer(401, "<title>Access Denied</title>"
			       "<h2 align=center>Access Denied</h2>");
      }
    }
  }
  TRACE_LEAVE("OK");
}



/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: cache_all
//! If set, cache failures to find a .htaccess file as well as found ones. This will limit the number of stat(2) calls quite dramatically. This should be set if you have a busy site! It does have at least  one disadvantage: The user has to press reload to get the new .htaccess file parsed.
//!  type: TYPE_FLAG
//!  name: Cache the failures
//
//! defvar: file
//! The file name of the file where the access information is stored.
//!  type: TYPE_STRING|VAR_MORE
//!  name: Access file name
//
//! defvar: denyhtlist
//! Always deny access to these files. This is useful to protect htaccess related files.
//!  type: TYPE_STRING_LIST
//!  name: Deny file list
//
