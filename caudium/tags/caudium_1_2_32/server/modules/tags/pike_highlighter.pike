/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2002 Xavier Beaudouin
 * Copyright � 2002 The Caudium Group
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

#include <module.h> 
inherit "module"; 
inherit "caudiumlib"; 
inherit "highlight_pike"; 
constant cvs_version	= "$Id$";
constant module_type	= MODULE_PARSER;
constant module_name	= "Pike Source Highlighter";
constant module_doc	= "Pike Source Highlighter module";
constant module_unique	= 1;
constant thread_safe	= 1;

void create() {
  defvar("css", 1, "Force usage of CSS", TYPE_FLAG,
         "If set, the Pike Highlighter will use CSS to set colors and fonts "
         "instead of old HTML 2.0 font color systems.");
}

mapping query_container_callers() {
  return ([
           "phl":cont_phigh,
          ]);
}

string cont_phigh(string tag_name, mapping args, string contents, object id, object f, mapping defines, object fd) {

  if(QUERY(css))
   args += ([ "css":"yes" ]);
  return highlight_pike("foo", args, contents);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: css
//! If set, the Pike Highlighter will use CSS to set colors and fonts instead of old HTML 2.0 font color systems.
//!  type: TYPE_FLAG
//!  name: Force usage of CSS
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

