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
constant module_name = "CIF - configuration files module";
constant module_doc  = "CIF module that implements all the file tasks - reading/writing/parsing/updating.";
constant module_unique = 1;

#define EPREFIX "CIF TAGS: "

//
// TEMPORARY STUFF: START
//

//
// It should be made an option to the 'start' script eventually, and stored
// in the caudium.pike file
//
string storage_method = "flatfile";

//
// TEMPORARY STUFF: END
//
void create()
{}

void start(int num, object conf)
{}

string query_provides()
{
    return "cif-config";
}

//
// provided APIs
//


//
// Retrieve a list of configuration files from the config directory.
// Note that the config "directory" might in reality be something
// completely different depending on the storage used. This module
// implements only the flatfile, plain text storage (Caudium/Roxen format 6
// and XML).
//
// Parameters:
//
//  configdir  - the directory with configurations, defaults to
//               caudium->configuration_dir.
//
//  creat      - if != 0 then the config directory is created if not
//               found. 
//
//  cmod       - if creat != 0 then this parameter (if present) specifies
//               the access mode for the directory. Defaults to 0711.
//
//
// Returns:
//
//  An array of mappings containing the configuration names. This array
//  should be passed to the function doing actual configuration
//  reading/parsing.
//
array(mapping) list_all_configurations(void|string configdir, void|int creat, void|int cmod)
{
    object storage = 0;
    
    //
    // Find the module implementing the given storage. We implement
    // 'flatfile' here.
    //
    switch(storage_method) {
        case "flatfile":
            storage = this_object();
            break;
    }

    if (!storage) {
        report_error(EPREFIX + "Couldn't find module implementing storage type '%s'\n",
                     storage_method);
        return 0;
    }

    if (!functionp(storage->get_configs_list)) {
        report_error(EPREFIX + "The '%s' storage module is invalid (missing get_configs_list)\n",
                     storage_method);
        return 0;
    }

    return storage->get_configs_list(configdir, creat, cmod);
}


//
// Storage API
//
private mapping config_files_only(string file)
{
    Stdio.Stat  fs = Stdio.Stat(file_stat(file));

    if (fs && fs->isreg && file[-1] != '~')
        return ([
            "name" : file,
            "size" : fs->size,
            "mtime" : fs->mtime
        ]);
    
    return 0;
}

array(mapping) get_configs_list(void|string configdir, void|int creat, void|int cmod)
{
    string    cfdir = configdir || caudium->configuration_dir;
    int       cmode = cmod || 0711;
    string    cwd = getcwd();
    
    if (!cd(cfdir)) {
        if (!creat) {
            report_error(EPREFIX + "Configuration directory '%s' does not exist.\n", cfdir);
            return 0;
        }
        
        if (!Stdio.mkdirhier(cfdir, cmode)) {
            report_error(EPREFIX + "Couldn't create the config directory '%s'\n", cfdir);
            return 0;
        }

        cd(cfdir);
    }

    array(string)  files = get_dir(cfdir);

    if (!files) {
        // shouldn't happen...
        report_error(EPREFIX + "Couldn't get the directory listing for '%s'\n", cfdir);
        return 0;
    }

    array(mapping) ret = map(files, config_files_only) - ({0}) - ({([])});

    cd(cwd);

    return ret;
}

