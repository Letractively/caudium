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

// mapping from digits to file type names for file_stat in Pike < 7.2
private mapping(int:string) num2type = ([
    -1 : "a file of unknown type",
    -2 : "a directory",
    -3 : "a symlink",
    -4 : "a device"
]);

private mapping(string:string) reserved_screens = ([
    "add" : "screen_add",
    "modify" : "screen_modify",
    "modified" : "screen_modified",
    "error" : "screen_error",
    "mainmenu" : "screen_mainmenu",
    "auth" : "screen_auth",
    "logout" : "screen_logout"
]);

private mapping(string:string) module_screens = ([]);

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
           "messages etc. to the user. The template directory must contain subdirectories "
           "that have this name.");
    defvar("misc_max_fsize", 128, "Miscellaneous: Maximum file size (in Kb)", TYPE_INT,
           "Maximum size of the screen HTML file in kilobytes.");
    
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

    defvar("screen_modified", "modified.html", "Screens: 'MODIFIED' template file", TYPE_STRING,
           "Name of the file that contains the 'modified' screen template.");
    
    defvar("screen_error", "error.html", "Screens: 'ERROR' template file", TYPE_STRING,
           "Name of the file that contains the 'error' screen template.");

    defvar("screen_mainmenu", "mainmenu.html", "Screens: 'MAIN MENU' template file", TYPE_STRING,
           "Name of the file that contains the 'main menu' screen template.");

    defvar("screen_auth", "auth.html", "Screens: 'AUTH' template file", TYPE_STRING,
           "Name of the file that contains the 'auth' screen template. This template "
           "is used for the login page.");

    defvar("screen_logout", "logout.html", "Screens: 'LOGOUT' template file", TYPE_STRING,
           "Name of the file that contains the 'logout' screen template.");

    defvar("screen_custom", "", "Screens: custom screens", TYPE_TEXT_FIELD,
           "Definitions of the custom screens, one per line. The format is as follows: "
           "<pre>"
           "    screen name:rel/path/to/name2.html\n"
           "    screen name2:name2.html\n"
           "</pre>");
}


void start(int cnt, object conf)
{
    // process the user-defined screens
    array(string) uds = (QUERY(screen_custom) / "\n") - ({}) - ({""});
    
    if (sizeof(uds)) {
        array(string) scrdef;
        
        foreach(uds, string scrline) {
            scrdef = scrline / ":";

            if (sizeof(scrdef) < 2) {
                report_warning("Malformed screen definition line in provider '%s': %s\n",
                               query_provides(), scrline);
                continue;
            }
            scrdef[0] = String.trim_whites(scrdef[0]);
            scrdef[1] = String.trim_whites(scrdef[1]);
            
            if (reserved_screens[scrdef[0]]) {
                report_warning("Provider '%s' is using reserved name for user-defined screen ('%s')\n",
                               query_provides(), scrdef[0]);
                continue;
            } else
                module_screens[scrdef[0]] = scrdef[1];
        }
    }

    // process the predefined screens
    string sfile;
    foreach(indices(reserved_screens), string idx) {
        sfile = query(reserved_screens[idx]);
        if (sfile[0] != '/')
            sfile = "/" + sfile;
        
        module_screens[idx] = sfile;
    }
}

string query_provides() 
{
    return QUERY(provider_prefix) + "_screens";
}

private array(array(string)) make_replace_array(mapping rdata)
{
    array(array(string)) fromto = ({({}), ({})});

    foreach(indices(rdata), string idx) {
        fromto[0] += ({ "@" + idx + "@" });
        fromto[1] += ({ rdata[idx] });
    }

    return fromto;
}

private array check_file(string fname, string|void lang)
{
    array(string) spath;
    string dpath = QUERY(screens_path) + "/" + QUERY(misc_def_lang) + "/" + fname;
    string ret = "";
    int    fsize = 0;
    
    if (lang) {
        string tmp = QUERY(screens_path) + "/" + lang + "/" + fname;
        if (tmp != dpath)
            spath = ({tmp, dpath});
        else
            spath = ({dpath});
    } else {
        spath = ({dpath});
    }

    foreach(spath, string file) {
        array(int)|object f = file_stat(file);

        if (!f)
            continue;
        
        int ftype = arrayp(f) ? f[1] : (objectp(f) ? f->size : -1);
                
        if (ftype < 0) {
            report_warning("Screen path '%s' points to %s and not to a regular file\n",
                           spath, num2type[ftype]);
            continue;
        } else if (ftype == 0) {
            report_warning("Screen path '%s' points to an empty file. Ignoring it.\n",
                           spath);
            continue;
        }

        ret = file;
        fsize = ftype;
        break;
    }
    
    return ({ret, fsize});
}

//
// if 'lang' == 0 then the default language will be retrieved
//
string retrieve(object id, string name, string|void lang)
{
    if (!name || name == "")
        return "";
    
    if (!module_screens[name])
        return "<!-- No screen named '" + name + "' found -->\n";

    array finfo = check_file(module_screens[name], lang);
    if (finfo[0] == "")
        return "<!-- no file for screen '" + name + "' -->";
    
    if (finfo[1] > (QUERY(misc_max_fsize) * 1024))
        return sprintf("<!-- Screen file '%s' is too big (allowed max is %dKb)\n -->",
                           module_screens[name], QUERY(misc_max_size));
    
    Stdio.File f = Stdio.File(finfo[0], "r");
    if (!f)
        return "<!-- Couldn't open the " + module_screens[name] + " screen file -->";

    string fdata = f->read();
    f->close();

    mapping rdata = 0;

    if (SSTORE(id) && SSTORE(id)[name])
        rdata = SSTORE(id)[name];
    
    if (rdata) {
        array(array(string)) fromto = make_replace_array(rdata);

        if (sizeof(fromto) == 2 && sizeof(fromto[0]) && (sizeof(fromto[0]) == sizeof(fromto[1])))
            fdata = replace(fdata, fromto[0], fromto[1]);
    }

    return parse_rxml(fdata, id);
}

//
// This stores all the id->variables in the storage area for the template
// named 'name'. This data will be used later on in the retrieve
// function. The replace variables in the template have the following
// format:
//
//  @varname@
//
// where 'varname' is taken from id->variables name (other modules can add
// variables to the storage mapping for the template, of course and then
// the 'varname' will be set to the mapping index name)
//
void store(object id, string name)
{
    if (!SSTORE(id))
        SSTORE(id) = ([]);

    if (!SSTORE(id)[name])
        SSTORE(id)[name] = ([]);
    
    if (!id->variables || !sizeof(id->variables))
        return;
    
    foreach(indices(id->variables), string idx)
        SSTORE(id)[name][idx] = id->variables[idx];
}

//
// purge the store for the given template
//
void purge(object id, string name)
{
    if (!SSTORE(id))
        return;

    if (SSTORE(id)[name])
        SSTORE(id)[name] = ([]);
}

//
// return the store for the given template
//
mapping get_store(object id, string name)
{
    if (SSTORE(id) && SSTORE(id)[name])
        return SSTORE(id)[name];

    if (!SSTORE(id))
        SSTORE(id) = ([]);

    if (!SSTORE(id)[name])
        SSTORE(id)[name] = ([]);
    
    return SSTORE(id)[name];
}
