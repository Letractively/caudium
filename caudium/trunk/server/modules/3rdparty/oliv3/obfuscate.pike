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
//! module:Address obfuscator
//! inherits: module
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
inherit "module";
#include <module.h>

constant cvs_version="$Id$";
constant thread_safe=1;

constant module_type = MODULE_PARSER;
constant module_name = "Address obfuscator";
constant module_doc  = "This module makes an obfuscated mailto: href.<br>Usage: &lt;addr&gt;user@domain.com&lt;/addr&gt;";
constant module_unique = 1;

mapping query_container_callers () {
  return ([ "addr"   : container_address ]);
}

string container_address (string tag_name, mapping args, string contents, object id) {
  // get user and domain
  array tmp = contents / "@";
  if (sizeof (tmp) == 2) {
    string user = tmp[0];
    string domain = tmp[1];
    tmp = 0;

    string res = "<a href=\"m\nail\nto:\n";
 
    // first, add leading comment
    res += "(";
    res += "&#32;&#x20;" * (random (4)+1);
    res += ")";
    res += "&#32;" * (random (5) + 1);

    // user
    if (strlen (user) >= 2) {
      int l = strlen (user) / 2;
      res += user[0..l];
      res += "(" + user + ")";
      res += user[l+1..];
    }
    else
      res += "(" + user + ")" + user;
    res += "\n";

    // domain
    if (random (10) % 2)
      res += "&#64;";
    else
      res += "&#X40;";

    // domain
    tmp = domain / "";
    tmp = Array.map (tmp, lambda (string s) {
                            return s + "(" + (" " * random (3)) + ")";
			  } );
    res += tmp * "";
    tmp = 0;
    
    res += "\n  \">";

    // text
    if (args->nogtext)
      res += contents;
    else {
      res += "<gtext alt=\"\">"; 
      res += contents;
      res += "</gtext>";
    }
    
    res += "</a>";
    return res;
  }
  else
    return contents;
} 
