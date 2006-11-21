/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2005 The Caudium Group
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
//!  &lt;scut max='size' [postfix='stringtoappend'] [cut_on_whites='1']&gt;
//!  stringtocut&lt;/scut&gt;</tt></p>
//!  <p><b>Example :</b><br /><tt>
//!  &lt;scut max='10' postfix="..."&gt;
//!  0123456789012345&lt;/scut&gt;</tt><br />
//!  Will return :<br /><tt>
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
			"&lt;scut max='size' [postfix='stringtoappend'] [cut_on_whites='1']&gt;"
			"stringtocut&lt;/scut&gt;</tt></p>"
			"<p><b>Example :</b><br /><tt>"
			"&lt;scut max='10' postfix=\"...\"&gt;"
			"0123456789012345&lt;/scut&gt;</tt><br />"
			"Will return :<br /><tt>"
			"0123456...</tt></p>";
constant cvs_version  = "$Id$";
constant thread_safe  = 1;

void create()
{
  defvar(
    "cut_type",
    "any",
    "Default cut type",
    TYPE_STRING_LIST,
    "<ul><li><strong>any</strong>: cuts on any character by default. Cutting "
    "on white spaces should be explicit on RXML side using cut_on_whites='1'."
    "</li>"
    "<li><strong>whites</strong>: cuts only on whitespaces by default.</li>"
    "</ul>",
		({ "any", "whites" })
    );
}

//! container: scut
//!  Cut a string to a max value
//! attribute: max
//!  Cut the sting up to this max value.
//! attribute: postfix
//!  Add this string argument after the cut less the size of this arg
string scut(string tag_name, mapping args, string contents,
            object id, object f, mapping defines, object fd)
{
  if(args->help)
    return "There is no help yet !";	// FIXME

  if(args->max)
  {
    int max=(int)args->max;
    if (max > 1)
      max = max - 1;
    contents = Protocols.HTTP.unentity(contents);

    // Do we want to cut on a whitespace?
    // Legayc behovior is cut on anything
    int cut_on_whites = 0;  

    if(args->cut_on_whites)
    {
      cut_on_whites=1;
    }
    else
    {
      if(QUERY(cut_type)=="whites")
        cut_on_whites=1;
    }

    // Cut only if we have more data than the max specified
    if(sizeof(contents) > max)
    {
      if(args->postfix)
      {
        string postfix = (string)args->postfix;
        if (max > sizeof(postfix))
          max = max - sizeof(postfix);

         if(cut_on_whites)
           contents = string_cut_on_whites(contents, max)+postfix;
         else
           contents = contents[..max] + postfix;
      }
      else
      {
        if(cut_on_whites)
          contents = string_cut_on_whites(contents, max);
        else
          contents = contents[..max];
      }
    }
  }
  return _Roxen.html_encode_string(contents);
}

mapping query_container_callers()
{ 
 return (["scut":scut ]);
}

// TODO: get that in a Pike module somewhere String.pmod or something
//! Cut a given string on a white space
//!
//! @param from
//! The string to cut
//!
//! @param max
//! The maximum character to output.
//!
//! @returns
//! The longuest string shorter than max cut on a whitespace
string string_cut_on_whites(string from, int max)
{
  if(sizeof(from)>max)
  {
    int cut = max;

    for(int i=cut; i>0; i--)
    {
      if(from[i..i]==" ")
      {
        cut=i;
        break;
      }
    }

    from = from[..(cut-1)];
  }

  return from;
}
