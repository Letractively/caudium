/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 - 2003  The Caudium Group
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

/* Module derivated from a quick hack of the filesystem module made by
 * Tamas TEVESZ. 
 * This code is now more than a quick hack and handle dynamic contents as well
 * as virtual requests.
 * 
 * Authors:
 *  Bertrand LUPART <bertrand AT caudium DOT net>
 *  Nicolas GOSSET <ngosset AT linkeo DOT com>
 */

#include<module.h>

inherit "modules/filesystems/filesystem.pike" : filesystem;

//#define VHS_DEBUG

#ifdef VHS_DEBUG
# define DEBUG(X) if(QUERY(debug)) write("VHS-FS: "+X+"\n")
#else
# define DEBUG(X)
#endif

constant module_type = MODULE_FIRST|MODULE_LOCATION|MODULE_PROVIDER;
constant module_name = "Simple Virtual Hosting System: Filesystem";
constant module_doc = "<p>Basic Virtual Hosting module based on a directory structure.\n</p>"
  "<p>Just put your sites in directories matching the scheme setup below:</p>"
  +fs_struct_help+
  "<p>All the sites will then have the same set of modules loaded.</p>"
  "<p>All the sites handled should point to this Caudium virtual server. If you have "
  "multiple Caudium virtual servers, take care of the Virtual host matcher configuration.</p>";

constant module_version = "$Id$";

constant module_unique = 0;
// Does dealing with global variables affect thread-safeness?
constant thread_safe = 0;

constant fs_struct_help = 
  "<ul>"
  "<li><b>simple</b>:<br><pre>caudium.net/\nroxen.com/\n</pre></li>"
  "<li><b>dot reverse</b>:<br><pre>net/\n\tcaudium/\ncom/\n\troxen/</pre></li>"
  "<li><b>progressive</b>:<br><pre>c/ca/caudium.net/\nr/ro/roxen.com/</pre></li>"
  "</ul>";

constant strip_www_help =
  "The heading \"www.\" can be stripped, this way, only the domain is stored in"
  "the filesystem<br>"
  "DNS must then contain an entry for domain.tld and www.domain.tld";

constant fs_access_help =
	"<p>The request matching this regexp won't go through the virtual hosting system, thus "
	"the hostname won't be checked against the filesystem and it will be done as a "
	"normal filesystem request.</p>"
	"<p>This way, you can access the sites with both methods, eg for a filesystem structure "
	"set to \"simple\":"
	"<ul><li>http://domain.that.matches.this.regexp/domain.tld</li>"
	"<li>http://domain.tld/</li></ul></p>";

//! method: string query_provides()
//!  What this module provides for other modules to access its methods
string query_provides()
{
  return "simple_vhs_fs"; 
}

//! method: void start()
//!  When the module is started, start filesystem
void start(int count, object conf)
{
  filesystem::start();
}

//! method: void create()
//!  At the creation, call filesystem module constructor and add virtual
//!  hosting specific variables
void create()
{
  filesystem::create();

#ifdef VHS_DEBUG
  defvar(
		"debug",
		0,
		"Debug",
		TYPE_FLAG,
		"If set to yes, some debug information will be put in the debug logs.");
#endif

  defvar(
		"fs_struct",
		"simple",
		"Virtual hosting settings: Filesystem structure",
		TYPE_MULTIPLE_STRING,
		fs_struct_help,
		({ "simple","dot reverse","progressive" }));
	 
  defvar(
		"strip_www",
		1,
		"Virtual hosting settings: Strip www.",
		TYPE_FLAG,
		strip_www_help);

	defvar(
		"fs_access",
		"^.*domain\.tld$",
		"Exception",
		TYPE_STRING,
		fs_access_help);

}

//! mapping first_try(object id)
//!  At first try, modify path to the data in the filesystem given the settings
//!  in the CIF and id->request_headers->host (kind of root pivot)
//!  Return 0, then let the filesystem module do its job.
mapping first_try(object id)
{
  // path is a filesystem global variable which contain the path to data
  path = QUERY(searchpath);

  // TODO: add a safe way to make a difference between a domain name and an IP

  // fix for the module not trying to go to the 127.0.0.1/ directory or
  // whatever if you want to test the module on the loopback
  // to be removed once the domain/IP detection is done
  if( !zero_type(id->request_headers->host) &&
     	id->request_headers->host != "127.0.0.1" &&
			!Regexp(QUERY(fs_access))->match(id->request_headers->host))
  {
    string domain = "";		// Store the modified domain
 
    // Deal with the domain requested
    if(QUERY(strip_www))
    {
      if(id->request_headers->host[0..3]=="www.")
        domain = id->request_headers->host[4..];
      else
        domain = id->request_headers->host;
    }
    else
      domain = id->request_header->host;

    // domain is added a trailing / because it's now a directory
    domain = domain+"/";
 
    // Modify the path given the filesystem structure
    switch(QUERY(fs_struct))
    {
      case "simple": 
        path = path+domain;
        break;
      
      case "dot reverse":
        array parts = reverse(domain / ".");
        foreach(parts, string part)
          path += part+"/";
        break;
      
      case "progressive":
        path = path + domain[0..0]+"/"+domain[0..1]+"/"+domain;
        break;

      default:
        DEBUG(QUERY(fs_struct)+" is not a known filesystem structure");
    }
  
    // TODO: play with the add_constant to be 1.2/1.3 safe
    // clean up the path a bit
    path = simplify_path(path);

  }

  return 0; 
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: debug
//! If set to yes, some debug information will be put in the debug logs
//!  type: TYPE_FLAG
//!  name: Debug
//
//! defvar: fs_struct
//!  type: TYPE_MULTIPLE_STRING
//!  name: Virtual hosting settings: Filesystem structure
//
//! defvar: strip_www
//!  type: TYPE_FLAG
//!  name: Virtual hosting settings: Strip www.
//

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
