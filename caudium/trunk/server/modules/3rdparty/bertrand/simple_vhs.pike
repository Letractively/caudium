/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002  The Caudium Group
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

#include<module.h>

inherit "modules/filesystems/filesystem.pike" : filesystem;

#define DEBUG(X) write("VHS-FS: "+X+"\n")

constant module_type = MODULE_FIRST|MODULE_LOCATION|MODULE_EXPERIMENTAL;
constant module_name = "VHS- Simple directory structure-based virtual hosting system";
constant module_doc = "Zero config filesystem-based virtual hosting.\n Just"
  "put your sites in directories matching the scheme setup below:<br>"
  +fs_struct_help+"<br><br>"
  "All the sites will then have the same modules loaded.<br><br>";

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
  "The heading www. can be stripped, this way, only the domain is stored in"
  "the filesystem<br>"
  "DNS must then contain an entry for domain.tld and www.domain.tld";

//! method: void start()
//!  When the module is started, start filesystem
void start()
{
  filesystem::start();
}

//! method: void create()
//!  At the creation, call filesystem module constructor and add virtual
//!  hosting specific variables
void create()
{
  filesystem::create();

  defvar("fs_struct",
         "simple",
         "Virtual hosting settings: Filesystem structure",
         TYPE_MULTIPLE_STRING,
         fs_struct_help,
         ({ "simple","dot reverse","progressive" }));
	 
  defvar("strip_www",
         1,
         "Virtual hosting settings: Strip www.",
         TYPE_FLAG,
         strip_www_help);
}

//! mapping first_try(object id)
//!  At first try, modify path to the data in the filesystem given the settings
//!  in the CIF and id->request_headers->host (kind of root pivot)
//!  Return 0, then let the filesystem module do its job.
mapping first_try(object id)
{
  // path is a filesystem global variable which contain the path to data
  path = query("searchpath");

  DEBUG("before: path: "+path);
    
  string domain = "";		// Store the modified domain
 
  // Deal with the domain requested
  if(query("strip_www"))
  {
    if(id->request_headers->host[0..3]=="www.")
      domain=id->request_headers->host[4..];
    else
      domain=id->request_headers->host;
  }
  else
    domain=id->request_header->host;

  // domain is added a trailing / because it's now a directory
  domain=domain+"/";
 
  // Modify the path given the filesystem structure
  switch(query("fs_struct"))
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
      DEBUG(query("fs_struct")+" is not a known filesystem structure");
  }
  
  // clean up the path a bit
  path=simplify_path(path);

  DEBUG("after: path: "+path);
    
  return 0; 
}
