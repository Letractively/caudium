/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
//! module: Automatic sending of compressed files
//!  This module implements a suggestion by Francesco Chemolli:<br/>
//!  The modified filesystem should do about this:<br/>
//!  -check if the browser supports on-the-fly decompression<br/>
//!  -check if a precompressed file already exists.<br/>
//!  -if so, send a redirection to the precompressed file<p>
//!  So, no cost for compression, all URLs, content-types and such would
//!  remain vaild, no compression overhead and should be really simple
//!  to implement. Also, it would allow a site mantainer to
//!  choose WHAT to precompress and what not to.</p><p>
//!  This module acts as a filter, and it _will_ use one extra stat
//!  per access from browsers that support automatic decompression.</p>
//! inherits: module
//! type: MODULE_FIRST
//! cvs_version: $Id$
//
inherit "module";
#include <module.h>

constant cvs_version="$Id$";
constant thread_safe=1;

constant module_type = MODULE_FIRST;
constant module_name = "Automatic sending of compressed files";
constant module_doc  = "This module implements a suggestion by Francesco Chemolli:<br>\n"
      "The modified filesystem should do\n"
      "about this:<br>\n"
      "-check if the browser supports on-the-fly decompression<br>\n"
      "-check if a precompressed file already exists.<BR>\n"
      "-if so, send a redirection to the precompressed file<p>\n"
      "\n"
      "So, no cost for compression, all URLs, content-types and such would "
      "remain vaild, no compression overhead and should be really simple "
      "to implement. Also, it would allow a site mantainer to "
      "choose WHAT to precompress and what not to.<p>"
      "This module acts as a filter, and it _will_ use one extra stat "
      "per access from browsers that support automatic decompression.";
constant module_unique = 1;

mapping first_try(object id)
{
  NOCACHE();
  if(id->supports->autogunzip &&
     (caudium->real_file(id->not_query + ".gz", id)
      && caudium->stat_file(id->not_query + ".gz", id)))
  {
    if ( ! id->misc ) id->misc = ([]);
    if ( ! id->misc->moreheads ) id->misc->moreheads = ([]);
    
    id->misc->moreheads |= ([ "Content-Encoding" : "gzip" ]);
    
    id->not_query += ".gz";
    return caudium->get_file( id  );
  }
}
