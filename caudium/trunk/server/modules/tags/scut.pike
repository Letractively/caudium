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

//! module: String Cut Module
//!  Module that cut strings to a limited value<br />
//!  <p>This module add the <tt>&lt;scut&gt;</tt>
//!  container.</p>
//!  <p><b>Syntax is :</b><br /><tt>
//!  &lt;scut max=size [postfix=stringtoappend]&gt;
//!  stringtocut&lt;/scut&gt;</tt></p>
//!  <p><b>Example :</b><br /><tt>
//!  &lt;scut max=10 postfix="..."&gt;
//!  0123456789012345&lt;/scut&gt;</tt><br />
//!  Will returns :<br /><tt>
//!  0123456...</tt></p>
//! type: MODULE_PARSER
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

#include <module.h>
#include <process.h>
inherit "module";
inherit "caudiumlib";

constant module_type  = MODULE_PARSER;
constant module_name  = "String Cut Module";
constant module_doc   = "Module that cut strings to a limited value.<br />"
                        "<p>This module add the <tt>&lt;scut&gt;</tt> "
			"container.</p>"
			"<p><b>Syntax is :</b><br /><tt>"
			"&lt;scut max=size [postfix=stringtoappend]&gt;"
			"stringtocut&lt;/scut&gt;</tt></p>"
			"<p><b>Example :</b><br /><tt>"
			"&lt;scut max=10 postfix=\"...\"&gt;"
			"0123456789012345&lt;/scut&gt;</tt><br />"
			"Will returns :<br /><tt>"
			"0123456...</tt></p>";
constant cvs_version  = "$Id$";
constant thread_safe  = 1;

//! container: scut
//!  Cut a string to a max value
//! attribute: max
//!  Cut the sting up to this max value.
//! attribute: postfix
//!  Add this string argument after the cut less the size of this arg
string scut(string tag_name, mapping args, string contents,
            object id, object f, mapping defines, object fd)
{
 if(args->help) return "There is no help yet !";	// FIXME

 if(args->max)
 {
  int max=(int) args->max;
  if (max > 1) max = max - 1;
  if(sizeof(contents) > max)
  {
    if(args->postfix)
    {
     string postfix = (string)args->postfix;
     if (max > sizeof(postfix)) max = max - sizeof(postfix);
     contents = contents[..max] + postfix;
    }
    else contents = contents[..max];
  }
 }
 return contents;
}

mapping query_container_callers()
{ 
 return (["scut":scut ]);
}

