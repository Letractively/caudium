/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2001 The Caudium Group
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
//! module: Fast directory parsing module MKII
//!  This module is responsible for pretty-printing the directory contents.
//!  Unlike the other two directory modules 
//!  ([modules/directories/directories.pike] and 
//!   [modules/directories/directories2.pike]) this one doesn't use the 
//!  folding/unfolding feature.
//!  Unlike the standart Fast Directory Module 
//!  ([modules/directories/fastdir.pike]) it has the ability to add
//!  some header / footer when displaying directories.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_DIRECTORIES
//! cvs_version: $Id$
//
/*
 * A fast directory module, without support for the fold/unfold stuff
 * in the normal one.
 */

constant cvs_version = "$Id$";
int thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib";

/************** Generic module stuff ***************/

constant module_type = MODULE_DIRECTORIES;
constant module_name = "Fast directory module MKII";
constant module_doc  = "This is a _fast_ directory parsing module. "
	    "Basically, this one just prints the list of files.<br />"
            "This module has also the capabitity to include custom "
            "header and footer in the listing".
constant module_unique = 1;

void create()
{
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html", "index.htm" }),
	 "Index files", TYPE_STRING_LIST,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of 'no such file'.");

  defvar("readme", 1, "Include readme files", TYPE_FLAG,
	 "If set, include readme files in directory listings");

  defvar("header","","Header",TYPE_STRING,
         "The HTML text to include before the listing of the directory.");

  defvar("footer","","Footer",TYPE_STRING,
         "The HTML text to include at the end of the listing.");

}

/*  Module specific stuff */


#define TYPE_MP  "    Module location"
#define TYPE_DIR "    Directory"


inline string image(string f) 
{ 
  return ("<img border=0 src="+(f)+" alt=>"); 
}

inline string link(string a, string b) 
{ 
  return ("<a href="+replace(b, ({ "//", "#" }), ({ "/", "%23" }))
	  +">"+a+"</a>"); 
}

string find_readme(string path, object id)
{
  string rm, f;
  object n;
  foreach(({ "README.html", "README" }), f)
  {
    rm=caudium->try_get_file(path+f, id);
    if(rm) if(f[-1] == 'l')
      return "<hr noshade>"+rm;
    else
      return "<pre><hr noshade>"+
	replace(rm, ({"<",">","&"}), ({"&lt;","&gt;","&amp;"}))+"</pre>";
  }
  return "";
}

string head(string path,object id)
{
  string rm="";

  if(QUERY(readme)) 
    rm=find_readme(path,id);
 
  return ("<html><head><title>Directory listing of "+path+"</title>"
          "</head><body>"+QUERY(footer) +"<h1>"
          "Directory listing of "+path+"</h1>\n<p>"+rm
	  +"<pre>\n<hr noshade>");
}

string foot()
{
  return ("</pre><hr noshade>"+QUERY(footer)+"</body></html>");
}

string describe_dir_entry(string path, string filename, array stat)
{
  string type, icon;
  int len;
  
  if(!stat)
    return "";

  switch(len=stat[1])
  {
   case -3:
    type = TYPE_MP;
    icon = "internal-gopher-menu";
    filename += "/";
    break;
      
   case -2:
    type = TYPE_DIR;
    filename += "/";
    icon = "internal-gopher-menu";
    break;
      
  default:
    array tmp;
    tmp = my_configuration()->type_from_filename(filename, 1);
    if(!tmp)
      tmp=({ "Unknown", 0 });
    type = tmp[0];
    icon = image_from_type(type);
    if(tmp[1])  type += " " + tmp[1];
  }
  
  return sprintf("%s %s %8s %-20s\n", 	
		 link(image(icon), http_encode_string(path + filename)),
		 link(sprintf("%-35s", filename[0..34]), 
		      http_encode_string(path + filename)),
		 sizetostring(len), type);
}

static private string key;

void start()
{
  key="file:"+caudium->current_configuration->name;
}

string new_dir(string path, object id)
{
  int i;
  array files;
  string fname;

  files = caudium->find_dir(path, id);
  if(!files) return "<h1>There is no such directory.</h1>";
  sort(files);

  if(path != "/")
    files = ({ ".." }) + files;

  for(i=0; i<sizeof(files) ; i++)
  {
    fname = replace(path+files[i], "//", "/");
    files[i] = describe_dir_entry(path,files[i],caudium->stat_file(fname, id));
  }
  return files * "";
}

mapping parse_directory(object id)
{
  string f;
  string dir;
  array indexfiles;

  f=id->not_query;

  if(strlen(f) > 1 ?  f[-1] != '/' : f != "/")
    return http_redirect(id->not_query+"/", id);

  if(f[-1] == '/') /* Handle indexfiles */
  {
    string file;
    foreach(query("indexfiles") - ({""}), file) {
      if(caudium->stat_file(f+file, id))
      {
	id->not_query = f + file;
	mapping got = caudium->get_file(id);
	if (got) {
	  return(got);
	}
      }
    }
    // Restore the old query.
    id->not_query = f;
  }

  if(id->pragma["no-cache"] || !(dir = cache_lookup(key, f))) {
    cache_set(key, f, dir=new_dir(f, id));
  }
  return http_string_answer(head(f, id) + dir + foot());
}



/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: indexfiles
//! If one of these files is present in a directory, it will be returned instead of 'no such file'.
//!  type: TYPE_STRING_LIST
//!  name: Index files
//
//! defvar: readme
//! If set, include readme files in directory listings
//!  type: TYPE_FLAG
//!  name: Include readme files
//
//! defvar: header
//! The HTML text to include before the listing of the directory.
//!  type: TYPE_STRING
//!  name: Header
//
//! defvar: footer
//! The HTML text to include at the end of the listing.
//!  type: TYPE_STRING
//!  name: Footer
//
