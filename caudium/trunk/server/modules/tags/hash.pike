/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
/*
 * $Id$
 */

//! module: Hash Module
//!  Module that give hash using crypto of the content between the 
//!  container.
//!  <p><b>Syntax is :</b><br /><tt>
//!  &lt;hash type=[crypto] [postfix=stringtoappend]&gt;
//!  stringtohash&lt;/hash&gt;</tt></p>
//!  <p><b>Example :</b><br /><tt>
//!  &lt;hash max=md5&gt;
//!  0123456789012345&lt;/hash&gt;</tt><br />
//!  Will returns :<br /><tt>
//!  d927ad81199aa7dcadfdb4e47b6dc694</tt></p>
//!  Crypto that is currenlty supported : md5, md2, sha
//! type: MODULE_PARSER
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

#include <module.h>
#include <process.h>
inherit "module";
inherit "caudiumlib";

constant module_type  = MODULE_PARSER;
constant module_name  = "Hash Module";
constant module_doc   = "Module that give hash using crypto of the content "
			"container."
			"<p><b>Syntax is :</b><br /><tt> "
			"&lt;hash type=[crypto] [postfix=stringtoappend]&gt; "
			"stringtohash&lt;/hash&gt;</tt></p> "
			"<p><b>Example :</b><br /><tt> "
			"&lt;hash max=md5&gt; "
			"0123456789012345&lt;/hash&gt;</tt><br /> "
			"Will returns :<br /><tt> "
			"d927ad81199aa7dcadfdb4e47b6dc694</tt></p> "
			"Crypto that is currenlty supported : md5, md2, sha ";
constant cvs_version  = "$Id$";
constant thread_safe  = 1;

//! container: hash
//!  Hash a string with crypto
//! attribute: type
//!  Specify the crypto type to use for hashing.
string cont_hash(string tag_name, mapping args, string contents,
            object id, object f, mapping defines, object fd)
{
 if(args->help) return "There is no help yet !";	// FIXME

 if(args->type)
 {
   switch(args->type)
     {
	case "md2":
          return Crypto.string_to_hex(Crypto.md2()->update(contents)->digest());
          break;
        case "md5":
          return Crypto.string_to_hex(Crypto.md5()->update(contents)->digest());
          break;
        case "md5":
          return Crypto.string_to_hex(Crypto.sha()->update(contents)->digest());
          break;
        default:
          return("<!-- No such hash type -->\n"+contents);
      }
 }
 return contents;
}

mapping query_container_callers()
{ 
 return (["hash":cont_hash ]);
}

