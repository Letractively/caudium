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
//! module: Content types
//!  This module handles all normal extension to
//!  content type mapping. Given the file 'foo.html', it will
//!  normally set the content type to 'text/html'
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_TYPES
//! cvs_version: $Id$
//

/*
 * This module handles all normal extension to content type
 * mapping. Given the file 'foo.html', it will per default
 * set the contenttype to 'text/html'
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";

constant module_type = MODULE_TYPES;
constant module_name = "Content types";
constant module_doc  = "This module handles all normal extension to "+
	     "content type mapping. Given the file 'foo.html', it will "+
	     "normally set the content type to 'text/html'.";
constant module_unique = 1;

mapping (string:string) extensions=([]), encodings=([]);
mapping  (string:int) accessed=([]);

void create()
{
  defvar("exts", "\n"
	 "# This will include the defaults from a file.\n"
	 "# Feel free to add to this, but do it after the #include line if\n"
	 "# you want to override any defaults\n"
	 "\n"
	 "#include <etc/extensions>\n\n", "Extensions", 
	 TYPE_TEXT_FIELD, 
	 "This is file extension "
	 "to content type mapping. The format is as follows:\n"
	 "<pre>extension type encoding<br />gif image/gif<br />"
	 "gz STRIP application/gnuzip</pre>"
	 "For a list of types, see <a href=\"ftp://ftp.isi.edu/in-"
	 "notes/iana/assignments/media-types/media-types\">ftp://ftp"
	 ".isi.edu/in-notes/iana/assignments/media-types/media-types</a>");
  defvar("extsfile", "/etc/mime.types", "System-wide extension file",
         TYPE_STRING,
	 "This file holds extra extension-to-contenttype mapping, "
	 "in the following format:<br />"
	 "<pre>content-type&lt;one or more tabs&gt;extension(s) (separated by spaces if more than one)</pre><br />"
	 "If the specified file does not exist, the module silently discards this setting (so you are "
	 "safe to leave it as it is, if you are not sure). Empty lines and lines beginning with a '#' are also "
	 "discarded.");
	 // the parser is actually a bit more relaxed that that...
  defvar("default", "application/octet-stream", "Default content type",
	 TYPE_STRING, 
	 "This is the default content type which is used if a file lacks "
	 "extension or if the extension is unknown.\n");
}

string status()
{
  string a,b;
  int even = 0;
  // accessed list follows
  b="<h2>Accesses per extension</h2>\n\n";
  b += "<table cellpadding=\"4\" cellspacing=\"5\">";
  foreach(indices(accessed), a)
    b += "<tr" + ( (even = !even) ? " bgcolor=\"#d1d1d1\"" : "" ) + "><td>" + accessed[ a ] + "</td><td>" + a + "</td></tr>\n";
  b += "</table>\n";

  // extension list follows
  b += "<h2>Extensions list</h2>\n\n";
  b += "<table cellpadding=\"4\" cellspacing=\"5\">";
  a = "";
  even = 0;
  foreach(sort(indices(extensions)), a)
    b += "<tr" + ( (even = !even) ? " bgcolor=\"#d1d1d1\"" : "" ) + "><td>" + extensions[ a ] + "</td><td>" + a + "</td></tr>\n";
  b += "</table>\n";

  // encoding list follows
  b += "<h2>Encodings list</h2>\n\n";
  b += "<table cellpadding=\"4\" cellspacing=\"5\">";
  a = "";
  even = 0;
  foreach(sort(indices(encodings)), a)
    b += "<tr" + ( (even = !even) ? " bgcolor=\"#d1d1d1\"" : "" ) + "><td>" + encodings[ a ] + "</td><td>" + a + "</td></tr>\n";
  b += "</table>\n";
  return b;
}

string comment()
{
  return sizeof(extensions) + " extensions, " + sizeof(accessed)+" used.";
}

void parse_ext_string(string exts)
{
  string line;
  array(string) f;

  foreach((exts-"\r")/"\n", line)
  {
    if(!strlen(line))  continue;
    if(line[0]=='#')
    {
      string file;
      if(sscanf(line, "#include <%s>", file))
      {
	string s;
	if(s=Stdio.read_bytes(file)) parse_ext_string(s);
      }
    } else {
      f = (replace(line, "\t", " ")/" "-({""}));
      if(sizeof(f) >= 2)
      {
	if(sizeof(f) > 2) encodings[lower_case(f[0])] = lower_case(f[2]);
	extensions[lower_case(f[0])] = lower_case(f[1]);
      }
    }
  }
}

void start()
{
  string line, ct, extra_exts;
  array ext, atmp;
  extra_exts = "";
  parse_ext_string(QUERY(exts));
  if(file_stat(QUERY(extsfile))) {
    foreach( (Stdio.read_bytes(QUERY(extsfile))-"\r")/"\n", line) {
      ext = ({ });
      // don't try to parse empty lines
      if( strlen(line) && line[0] == '#' )
        continue;
      sscanf(line, "%s%*[ \t]%{%s%*[ ]%}", ct, atmp);
      // beats me why "%{%s%*[ ]%}" expands to an array(array) ... ?!
      foreach(atmp, array foo)
        ext += foo;
      // lines w/o at least one extension, we don't need 'em
      if(!sizeof(ext)) continue;
      foreach(ext, string s)
        extra_exts += sprintf("%s\t%s\n", s, ct);
    }
    parse_ext_string( extra_exts );
  }
}

array type_from_extension(string ext)
{
  ext = lower_case(ext);
  if(ext == "default") {
    accessed[ ext ] ++;
    return ({ QUERY(default), 0 });
  } else if(extensions[ ext ]) {
    accessed[ ext ]++;
    return ({ extensions[ ext ], encodings[ ext ] });
  }
}

int may_disable() 
{ 
  return 0; 
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: exts
//! This is file extension to content type mapping. The format is as follows:
//!<pre>extension type encoding<br />gif image/gif<br />gz STRIP application/gnuzip</pre>For a list of types, see <a href="ftp://ftp.isi.edu/in-notes/iana/assignments/media-types/media-types">ftp://ftp.isi.edu/in-notes/iana/assignments/media-types/media-types</a>
//!  type: TYPE_TEXT_FIELD
//!  name: Extensions
//
//! defvar: default
//! This is the default content type which is used if a file lacks extension or if the extension is unknown.
//!
//!  type: TYPE_STRING
//!  name: Default content type
//
