/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
 * Copyright � 1994-2000 Roxen Internet Software
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

// User filesystem. Uses the userdatabase (and thus the system passwd
// database) to find the home-dir of users, and then looks in a
// specified directory in that directory for the files requested.

// Normaly mounted under /~, but / or /users/ would work equally well.
// / is quite useful for IPPs, enabling them to have URLs like
// http://www.hostname.of.provider/customer/.

// #define USERFS_DEBUG 
// #define PASSWD_DISABLED ((us[1]=="") || (us[1][0]=='*'))
#define BAD_PASSWORD(us)	(QUERY(only_password) && \
                                 ((us[1] == "") || (us[1][0] == '*')))
#include <module.h>

inherit "filesystem" : filesystem;

constant cvs_version="$Id$";

constant module_type = MODULE_LOCATION;
constant module_name = "User Filesystem";
constant module_doc  = "User filesystem. Uses the userdatabase (and thus the system passwd "
      "database) to find the home-dir of users, and then looks in a "
      "specified directory in that directory for the files requested. "
      "<p>Normaly mounted under /~, but / or /users/ would work equally well. "
      " is quite useful for IPPs, enabling them to have URLs like "
      " http://www.hostname.of.provider/customer/. ";
constant module_unique = 0;

// import Array;
// import Stdio;

/*
 * Function dhash :
 *
 * string dhash(string what, int depth)
 *
 * what  is the string hash
 * depth is the depth of the hash
 *
 * ex : dhash("bidule", 3) will give "b/i/d/bidule"
 *
 */
string dhash(string what, int depth)
{
  return ((what/1)[0..depth-1] * "/") + "/" + what;
}

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

int hide_searchpath()
{
  return QUERY(homedir);
}

int hide_pdir()
{
  return !QUERY(homedir);
}

int hide_directory_hash()
{
  return !QUERY(directory_hash);
}

int hide_www_virtual_hosting()
{
  return !QUERY(virtual_hosting);
}

int hide_www_prefix()
{
  return !QUERY(www_virtual_hosting);
}

int hide_banish_list()
{
  return !QUERY(blist);
}

void create()
{
  filesystem::create();
  killvar("searchpath");
  defvar("searchpath", "NONE", "Search path", TYPE_DIR,
	 "This is where the module will find the files in the real "+
	 "file system",
	 0, hide_searchpath);

  defvar("directory_hash", 0, "Hashing: Hash userdirectory", TYPE_FLAG,
         "If set the module will hash the path to the real user directory "+
	 "e.g. if you the user is <em>\"foouser\"</em> the module will try "+
	 "access to <em>\"f/o/o/foouser\"</em> instead", 0, hide_searchpath);
	  
  defvar("dhash_depth",3,"Hashing: Hash depth", TYPE_INT,
         "The length of the hash depth, e.g. the number of directory to use "+
	 "for the hashing...", 0, hide_directory_hash);

  set("mountpoint", "/~");
  
  defvar("only_password", 1, "Password users only",
	 TYPE_FLAG, "Only users who have a valid password can be accessed "
	 "through this module");

  defvar("user_listing", 0, "Enable userlisting", TYPE_FLAG,
	 "Enable a directory listing showing users with homepages. "
	 "When the mountpoint is accessed.");
  
  defvar("banish_list", ({ "root", "daemon", "bin", "sys", "admin", 
			   "lp", "smtp", "uucp", "nuucp", "listen", 
			   "nobody", "noaccess", "ftp", "news", 
			   "postmaster" }), "Banish list: Banish list",
	 TYPE_STRING_LIST, "None of these users are valid.", 0, hide_banish_list);

  defvar("blist",1,"Banish list: Enable banish list", TYPE_FLAG,
         "If set the banish list will be activated.");
  
  defvar("own", 0, "Only owned files", TYPE_FLAG, 
	 "If set, users can only send files they own through the user "
	 "filesystem. This can be a problem if many users are working "
	 "together with a project, but it will enhance security, since it "
	 "will not be possible to link to some file the user does not own.");

  defvar("virtual_hosting", 0, "Virtual User Hosting: Virtual User Support", TYPE_FLAG, 
	 "If set, virtual user hosting is enabled. This means that "
	 "the module will look at the \"host\" header to determine "
	 "which users directory to access. If this is set, you access "
	 "the users directory with "
	 "<tt><b>http://user.domain.com/&lt;mountpoint&gt;</b></tt> "
	 "instead of "
	 "<tt><b>http://user.domain.com/&lt;mountpoint&gt;user</b></tt>. "
	 "Note that this means that you will usually want to set the "
	 "mountpoint to \"/\". "
	 "To set this up you need to add CNAME entries for all your "
	 "users pointing to the IP(s) of this virtual server.");

  defvar("www_virtual_hosting", 0, "Virtual User Hosting: Stupid user workaround", TYPE_FLAG,
         "If set, a work around/hack about virtual hosting is enabled. "
         "This mean that not only the host module <b>will</b> look at "
         "the \"host\" header to determine which users directory to access, "
         "but also correct some stupid users attempt of adding \"www\" to "
         "the name of the site, eg. :<br>"
         "the site <tt><b>http://user.domain.com/&lt;mountpoint&gt;</b></tt> "
         "can be <b>also</b> accessed by <tt><b>http://<u>www</b>.user.domain.com/&lt;mountpoint&gt;</b></tt>.", 0, hide_www_virtual_hosting);

  defvar("www_prefix", "www", "Virtual User Hosting: Prefix to use for the user workaround", TYPE_STRING,
         "This is the prefix to add for the virtual user hosting", 0, hide_www_prefix);

  defvar("useuserid", 1, "Run user scripts as the owner of the script",
	 TYPE_FLAG|VAR_MORE,
	 "If set, users cgi and pike scripts will be run as the user who "
	 "owns the file, that is, not the actual file, but the user"
	 " in whose dir the file was found. This only works if the server"
	 " was started as root "
	 "(however, it doesn't matter if you changed uid/gid after startup).",
	 0, uid_was_zero);
  
  defvar("pdir", "html/", "Public directory",
	 TYPE_STRING, "This is where the public directory is located. "
	 "If the module is mounted on /~, and the file /~per/foo is "
	 "accessed, and the home-dir of per is /home/per, the module "
	 "will try to file /home/per/&lt;Public dir&gt;/foo.",
	 0, hide_pdir);

  defvar("homedir" ,1, "Look in users homedir", TYPE_FLAG,
	 "If set, the user's files are looked for in the home directory "
	 "of the user, according to the <em>Public directory</em> variable. "
	 "Otherwise, the <em>Search path</em> is used to find a directory "
	 "with the same name as the user.");
}

multiset banish_list;
mapping dude_ok;
multiset banish_reported = (<>);

void start()
{
  filesystem::start();
  // We fix all file names to be absolute before passing them to
  // filesystem.pike
  path="";
  banish_list = mkmultiset(QUERY(banish_list));
  dude_ok = ([]);
  // This is needed to override the inherited filesystem module start().
}

mixed *register_module()
{
  return ({ 
    MODULE_LOCATION, 
    "User Filesystem", 
      "User filesystem. Uses the userdatabase (and thus the system passwd "
      "database) to find the home-dir of users, and then looks in a "
      "specified directory in that directory for the files requested. "
      "<p>Normaly mounted under /~, but / or /users/ would work equally well. "
      " is quite useful for IPPs, enabling them to have URLs like "
      " http://www.hostname.of.provider/customer/. "
    });
}

static array(string) find_user(string f, object id)
{
  string of = f;
  string u;

  if(QUERY(virtual_hosting)) {
    if(id->misc->host) {
      string host = (id->misc->host / ":")[0];
      if(search(host, ".") != -1) {
	sscanf(host, "%s.%*s", u);
      } else {
	u = host;
      }
      // case of www.<myloginname>
      if(QUERY(www_virtual_hosting)) {
        if ( u == QUERY(www_prefix))
        {
          string host = (id->misc->host / ":")[0];
	  if(search(host,".") != -1) {
	    //sscanf(host, "%*s.%s.%*s",u);
	    sscanf(host, QUERY(www_prefix)+".%s.%*s",u);
	  } else u = host;
        }
      }
    }
  } else {
    if((<"", "/", ".">)[f])
      return 0;

    switch(sscanf(f, "%*[/]%s/%s", u, f)) {
    case 1:
      sscanf(f, "%*[/]%s", u);
      f = "";
      break;
    default:
      u="";
      // FALL_THROUGH
    case 2:
      f = "";
      // FALL_THROUGH
    case 3:
      break;
    }
  }

#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: find_user(%O, X) => u:%O, f:%O\n", of, u, f));
#endif /* USERFS_DEBUG */

  return({ u, f });
}

mixed find_file(string f, object got)
{
  string u, of;
  of=f;

#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: find_file(%O, X)\n", f));
#endif /* USERFS_DEBUG */

  array a = find_user(f, got);

  if (!a) {
    return -1;
  }
  u = a[0];
  f = a[1];
  
  if(u)
  {
    string *us;
    array st;
    if(!dude_ok[ u ] || f == "")
    {
      us = got->conf->userinfo( u, got );
      // No user, or access denied.
      if(QUERY(blist))
      if(!us || BAD_PASSWORD(us) || banish_list[u])
      {
	if (!banish_reported[u]) {
	  banish_reported[u] = 1;
	  roxen_perror(sprintf("User %s banished (%O)...\n", u, us));
	}
	return 0;
      }
      if((f == "") && (strlen(of) && of[-1] != '/'))
      {
	redirects++;
	return http_redirect(got->not_query+"/",got);
      }

      string dir;

      if (QUERY(homedir))
	dir =  us[ 5 ] + "/" + QUERY(pdir) + "/";
      else
       if (QUERY(directory_hash))
          dir = combine_path(QUERY(searchpath)+"/",dhash(u, QUERY(dhash_depth))) + "/";
       else
	  dir = QUERY(searchpath) + "/" + u + "/";

      dir = replace(dir, "//", "/");

#ifdef USERFS_DEBUG
      roxen_perror(sprintf("USERFS: find_file(%O, X) => dir:%O\n", f, dir));
#endif

      // If public dir does not exist, or is not a directory 
      st = filesystem::stat_file(dir, got);
      if(!st || st[1] != -2) {
	return 0;	// File not found.
      }
      dude_ok[u] = dir;	// Always '/' terminated.
    }
    f = dude_ok[u] + f;
    if(QUERY(own))
    {
      if (!us) {
	us = got->conf->userinfo( u, got );
      }

      st = filesystem::stat_file(f, got);

      if(!st || (st[5] != (int)(us[2])))
        return 0;
    }
    if(QUERY(useuserid))
      got->misc->is_user = f;
    return filesystem::find_file( f, got );
  }
  return 0;
}

string real_file( mixed f, mixed id )
{
  string u;

#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: real_file(%O, X)\n", f));
#endif /* USERFS_DEBUG */

  array a = find_user(f, id);

  if (!a) {
    return 0;
  }

  u = a[0];
  f = a[1];

  if(u)
  {
    array(int) fs;
    if(query("homedir"))
    {
      string *us;
      us = id->conf->userinfo( u, id );
      if ((!us) || BAD_PASSWORD(us) || banish_list[u]) {
	return 0;
      }
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    } else
       if (QUERY(directory_hash))
          f = combine_path(QUERY(searchpath)+"/",dhash(u, QUERY(dhash_depth))) + "/" + f;
       else
          f = QUERY(searchpath) + u + "/" + f;
#ifdef USERFS_DEBUG
      roxen_perror(sprintf("USERFS: real_file(%O, X)\n", f));
#endif
    
    // Use the inherited stat_file
    fs = filesystem::stat_file( f,id );

    //    werror(sprintf("%O: %O\n", f, fs));
    // FIXME: Should probably have a look at this code.
    if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
      return f;
  }
  return 0;
}

mapping|array find_dir(string f, object got)
{
#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: find_dir(%O, X)\n", f));
#endif /* USERFS_DEBUG */

  array a = find_user(f, got);
  

  if (!a) {
    if (QUERY(user_listing)) {
      array l;
      l = got->conf->userlist(got);

      if(l) return(l - QUERY(banish_list));
    }
    return 0;
  }

  string u = a[0];
  f = a[1];

  if(u)
  {
    if(query("homedir"))
    {
      array(string) us;
      us = got->conf->userinfo( u, got );
      if(!us) return 0;
      if(QUERY(blist))
      if((!us) || BAD_PASSWORD(us))   		      return 0;
      // FIXME: Use the banish multiset.
      if(QUERY(blist))
      if(search(QUERY(banish_list), u) != -1)         return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    }
    else
       if (QUERY(directory_hash))
          f = combine_path(QUERY(searchpath)+"/",dhash(u, QUERY(dhash_depth))) + "/" + f;
       else
          f = QUERY(searchpath) + u + "/" + f;
#ifdef USERFS_DEBUG
          roxen_perror(sprintf("USERFS: find_dir(%O, X)\n", f));
#endif
	  
    array dir = filesystem::find_dir(f, got);
    if(QUERY(virtual_hosting) && arrayp(dir))
      return ([ "files": dir ]);
    return dir;
  }
  return (got->conf->userlist(got) - QUERY(banish_list));
}

mixed stat_file( mixed f, mixed id )
{
#ifdef USERFS_DEBUG
  roxen_perror(sprintf("USERFS: stat_file(%O, X)\n", f));
#endif /* USERFS_DEBUG */

  array a = find_user(f, id);

  if (!a) {
    return ({ 0, -2, 0, 0, 0, 0, 0, 0, 0, 0 });
  }

  string u = a[0];
  f = a[1];

  if(u)
  {
    array us, st;
    us = id->conf->userinfo( u, id );
    if(query("homedir"))
    {
      if(!us) return 0;
      if(QUERY(blist))
      if((!us) || BAD_PASSWORD(us))		      return 0;
      // FIXME: Use the banish multiset.
      if(QUERY(blist))
      if(search(QUERY(banish_list), u) != -1)         return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    } else
       if (QUERY(directory_hash))
          f = combine_path(QUERY(searchpath)+"/",dhash(u, QUERY(dhash_depth))) + "/" + f;
       else
          f = QUERY(searchpath) + u + "/" + f;
#ifdef USERFS_DEBUG
        roxen_perror(sprintf("USERFS: stat_file(%O, X)\n", f));
#endif
    st = filesystem::stat_file( f,id );
    if(!st) return 0;
    if(QUERY(own) && (int)us[2] != st[-2]) return 0;
    return st;
  }
  return 0;
}



string query_name()
{
  return ("Location: <i>" + QUERY(mountpoint) + "</i>, " +
	  (QUERY(homedir)
	   ? "Pubdir: <i>" + QUERY(pdir) +"</i>"
	   : "mounted from: <i>" + QUERY(searchpath) + "</i>"));
}
