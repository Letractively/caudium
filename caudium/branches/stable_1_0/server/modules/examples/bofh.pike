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
//! module: BOFH  Module
//!  Returns a random BOFH excuse.
//! inherits: module
//! type: MODULE_PARSER
//! cvs_version: $Id$
//

string cvs_version = "$Id$";
/* BOFH module. Returns a random BOFH excuse. */

#include <module.h>
inherit "module";

string *excuses = ({
"clock speed ",
"solar flares ",
"electromagnetic radiation from satellite debris ",
"static from nylon underwear ",
"static from plastic slide rules ",
"global warming ",
"poor power conditioning ",
"static buildup ",
"doppler effect ",
"hardware stress fractures "});

array register_module()
{
  return ({ MODULE_PARSER,
            "BOFH  Module",
            "Adds an extra tag, 'bofh'.", ({}), 1
            });
}


string bofh_excuse(string tag, mapping m)
{
  return excuses[random(sizeof(excuses))];
}

string info() { return bofh_excuse("", ([])); }

mapping query_tag_callers() { return (["bofh":bofh_excuse,]); }

mapping query_container_callers() { return ([]); }



