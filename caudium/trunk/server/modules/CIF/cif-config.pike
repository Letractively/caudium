/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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


static object get_the_storage(string fname) 
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

    if (!functionp(storage[fname])) {
        report_error(EPREFIX + "The '%s' storage module is invalid (missing get_configs_list)\n",
                     storage_method);
        return 0;
    }

    return storage;
}

//
// Retrieve a list of configuration files from the config directory.
// Note that the config "directory" might in reality be something
// completely different depending on the storage used. This module
// implements only the flatfile, plain text storage (Caudium/Roxen format 6
// and XML).
//
// Returns:
//
//  An array of mappings containing the configuration names. 
//
array(mapping) list_all_configurations()
{
  object storage = get_the_storage("get_configs_list");

  if (storage)
    return storage->get_configs_list();

  return 0;
}

array(string) list_all_region_names(string cfg_name)
{
  object storage = get_the_storage("get_config_region_names");

  if (storage)
    return storage->get_config_region_names(cfg_name);

  return 0;
}

//
// Storage API
//
private object cfg_dir = 0;
private string global_vars_name = "Global_Variables";

private void open_cfg_dir()
{
  if (!cfg_dir) {
    mixed error = catch {
      cfg_dir = Config.Files.Dir(caudium->configuration_dir);
    };
    
    if (error || !cfg_dir) {
      report_fatal("Cannot read from the configurations directory ("+
                   combine_path(getcwd(), caudium->configuration_dir)+")\n");
      exit(-1); // Restart.
    }
  }
}

array(mapping(string:string|int)) get_configs_list()
{
  open_cfg_dir();
  
  array(mapping(string:string|int)) cfiles = cfg_dir->list_files();

  foreach(cfiles, mapping(string:string|int) cf)
    if (cf->name == global_vars_name) {
      cfiles -= ({ cf });
      break;
    }
  
  return cfiles;
}

array(string) get_config_region_names(string cfg_name)
{
  open_cfg_dir();

  mixed      error;
  string|int errmsg;
  object     file;

  error = catch {
    file = Config.Files.File(cfg_dir, cfg_name);
  };

  if (error) {
    report_error("Failed to open configuration file for %O:\n%s\n",
                 cfg_name, describe_backtrace(error));
    return ({});
  }

  error = catch {
    errmsg = file->parse();
  };

  if (error || stringp(errmsg)) {
    report_error("Error reading configuration file '%O':\n%s\n",
                 cfg_name, stringp(errmsg) ? errmsg : describe_backtrace(error));
    destruct(file);
    return ({});
  }

  array(string) module_names = file->retrieve_region_names();

  if (module_names && sizeof(module_names))
    return sort(module_names);
  return ({});
}
