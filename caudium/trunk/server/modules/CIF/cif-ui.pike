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
 * $Id$
 */
constant cvs_version = "$Id$";
constant thread_safe=1;

#include <config.h>
#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER;
constant module_name = "CIF - User Interface Module";
constant module_doc  = "CIF module that implements the UI routines.";
constant module_unique = 1;

#define EPREFIX "CIF UI: "

void create()
{
    defvar("themesdir", "NONE/", "Themes directory", TYPE_DIR,
           "A directory with one subdirectory per theme. At least one "
           "subdirectory called <tt>default</tt> must exist in the "
           "indicated directory. Each theme directory contains one file "
           "per screen (the file can use other files in the directory, of course) "
           "and it can contain a directory called <tt>images</tt> which will be "
           "available on the runtime under the themename/images/ directory "
           "(relative to the mountpoint).");
    
}

void start(int num, object conf)
{}

string query_provides()
{
    return "cif-ui";
}


//
// Here's what we provide
//

//
// Return a string matching the given name. If session->theme exists then
// try to get file from that theme falling back to the default option if
// the theme isn't found. Returns 0 if an error occurred.
//
//  The following screen names are defined:
//
//   login    - the login form.
//
string get_screen(string name, mapping session, object id)
{
    if (QUERY(themesdir) == "NONE/")
        return 0;

    if (!Stdio.is_dir(QUERY(themesdir))) {
        report_error(EPREFIX + "theme directory '%s' not found\n",
                     QUERY(themesdir));
        return 0;
    }

    string theme;
    string deftheme = QUERY(themesdir);
    
    if (session->theme && !Stdio.is_dir(QUERY(themesdir) + session->theme)) {
        if (!Stdio.is_dir(deftheme)) {
            report_error(EPREFIX + "neither %s or %s directories exist\n",
                         QUERY(themesdir) + session->theme,
                         deftheme);
            return 0;
        }
        theme = deftheme;
    } else
        theme = QUERY(themesdir) + session->theme;

    
}
