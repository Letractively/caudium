/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#include <caudium.h>
#include "ldap-center.h"

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "LDAP: Screens module for the Command Center";
constant module_doc  = "Module that manages the user <em>screens</em> - i.e. "
                       "HTML template files used to generate output seen by the "
                       "user in their browser. This module provides two simple "
                       "services:<br /><ul>"
                       "<li><strong>File management.</strong> This part includes "
                       "providing named access to template files that abstracts the "
                       "client modules from the physical storage. Clients simply ask for "
                       "a named template that's fetched for them by this module.</li>"
                       "<li><strong>Value replacement and storage.</strong> This part is "
                       "responsible for storing the form values in the session mapping for "
                       "the indicated named screen and subsequent replacement of those values "
                       "when the screen is fetched.</li></ul><p>";


constant module_unique = 0;

void create()
{
    defvar("provider_prefix", "lcc", "Provider module prefix", TYPE_STRING,
           "This prefix must match one of the LDAP Command Center prefixes used "
           "in this virtual server or otherwise the LCC module won't load. Initially "
           "both LCC and this module share the <code>lcc</code> prefix.");

    //
    // Misc
    //
    defvar("misc_def_lang", "en", "Miscellaneous: Default language", TYPE_STRING,
           "The ISO code for the language that should be used when sending files, "
           "messages etc. to the user. The template directory must contain templates "
           "that have this extension. The exception is the default <code>en</code> - "
           "files without extension will be treated as if though they had it.");

    //
    // Directories
    //
    defvar("screens_path", "NONE", "Directories: Templates", TYPE_DIR,
           "Directory where the template files are located (in real file system)");
    
    //
    // Standard named screens
    //
    defvar("screen_add", "add.html", "Screens: 'ADD' template file", TYPE_STRING,
           "Name of the file that contains the 'add' screen template.");
    
    defvar("screen_modify", "modify.html", "Screens: 'MODIFY' template file", TYPE_STRING,
           "Name of the file that contains the 'modify' screen template.");

    defvar("screen_error", "error.html", "Screens: 'ERROR' template file", TYPE_STRING,
           "Name of the file that contains the 'error' screen template.");

    defvar("screen_mainmenu", "mainmenu.html", "Screens: 'MAIN MENU' template file", TYPE_STRING,
           "Name of the file that contains the 'main menu' screen template.");

    defvar("screen_custom", "", "Screens: custom screens", TYPE_TEXT_FIELD,
           "Definitions of the custom screens, one per line. The format is as follows: "
           "<pre>"
           "    screen name:rel/path/to/name2.html\n"
           "    screen name2:name2.html\n"
           "</pre>");
}

string query_provides() 
{
    return QUERY(provider_prefix) + "_screens";
}

string retrieve(object id, string name)
{
    return "";
}

void store(object id, string name)
{}
