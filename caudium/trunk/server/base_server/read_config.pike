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
 * $Id$
 */

#include <caudium.h>
#include <module.h>

#ifndef IN_INSTALL
inherit "newdecode";
string cvs_version = "$Id$";
#else
import spider;
# define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)
# include "newdecode.pike"
#endif

mapping(string:object)        configs = ([]);

// does it make sense to cache the config files stat results? /grendel
mapping (string:array(int))     config_stat_cache = ([]);

// flatfile storage
string configuration_dir; // Set in caudium.pike:main()
private object dir = 0;

private void open_cfg_dir()
{
  mixed      error;
  
  if (!dir) {
    error = catch {
      dir = Config.Files.Dir(configuration_dir);
    };
    
    if (error || !dir) {
      report_fatal("I cannot read from the configurations directory ("+
                   combine_path(getcwd(), configuration_dir)+")\n");
      exit(-1);	// Restart.
    }
  }
}

mapping copy_configuration(string from, string to)
{
#if 0 //FIXME!!
  if(!configs[from]) return 0;
#ifdef DEBUG
  write(sprintf("Copying configuration \"%s\" to \"%s\"\n", from, to));
#endif /* DEBUG */
  configs[to] = copy_value( configs[from] );
  
  return configs[to];
#endif
}

array(mapping(string:string|int)) list_all_configurations()
{
  if (!dir)
    open_cfg_dir();
  
  return dir->list_files();
}

void save_it(string cl)
{
  if (!configs[cl]) {
    report_error("Config '%s' does not exist while trying to save.\n");
    return;
  }

  if (!dir)
    open_cfg_dir();

  mixed       err;
  string|int  errmsg;

  err = catch {
    errmsg = configs[cl]->save();
  };

  if (err) {
    report_error("Error trying to save the '%s' config:\n%s\n",
                 cl, describe_backtrace(err));
    return;
  }

  if (stringp(errmsg)) {
    report_error("Error trying to save the '%s' config: %s\n", cl, errmsg);
    return;
  }
}

void fix_config(mapping c);

array fix_array(array c)
{
  int i;
  for(i=0; i<sizeof(c); i++)
    if(arrayp(c[i]))
      fix_array(c[i]);
    else if(mappingp(c[i]))
      fix_config(c[i]);
    else if(stringp(c[i]))
      c[i]=replace(c[i],".lpc#", "#");
}

void fix_config(mixed c)
{
  mixed l;
  if(arrayp(c)) {
    fix_array((array)c);
    return;
  }
  if(!mappingp(c)) return;
  foreach(indices(c), l)
  {
    if(stringp(l) && (search(l, ".lpc") != -1))
    {
      string n = l-".lpc";
      c[n]=c[l];
      m_delete(c,l);
    }
  }
  foreach(values(c),l)
  {
    if(mappingp(l)) fix_config(l);
    else if(arrayp(l)) fix_array(l);
    else if (multisetp(l)) perror("Warning; illegal value of config\n");
  }
}

array config_is_modified(string cl)
{
  array st = file_stat(configuration_dir + replace(cl, " ", "_"));
  
  if(st)
    if(!config_stat_cache[cl])
      return st;
    else
      foreach( ({ 1, 3, 5, 6 }), int i)
        if(st[i] != config_stat_cache[cl][i])
          return st;
}

private static void read_it(string cl)
{
  if(configs[cl])
    return;

  if (!dir)
    open_cfg_dir();
  
  mixed       err;
  string|int  errmsg;
  object      file;
  
  err = catch {
    file = Config.Files.File(dir, replace(cl, " ", "_"));
  };
  
  if (err) {
    report_error("Failed to open configuration file for %O\n%s\n",
                 cl, describe_backtrace(err));
    return;
  };

  err = catch {
    errmsg = file->parse();
  };

  if (stringp(errmsg)) {
    report_error("Error reading configuration the file '%s': %s\n",
                 cl, errmsg);
    destruct(file);
    return;
  }

  if (err) {
    report_error("Error reading configuration the file '%s':\n%s\n",
                 cl, describe_backtrace(err));
    destruct(file);
    return;
  }

  configs[cl] = file;
}

void remove( string reg , object current_configuration) 
{
  string cl;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif
  read_it(cl);

  m_delete(configs[cl], reg);
  save_it(cl);
}

void remove_configuration( string name )
{
  string f;

  f = configuration_dir + replace(name, " ", "_");
  if(!file_stat( f ))   f = configuration_dir + name;
  if(!rm(f) && file_stat(f))
  {
    error("Failed to remove configuration file ("+f+")! "+
#if 0&&constant(strerror)
          strerror()
#endif
          "\n");
  }
}

void store( string reg, mapping vars, int q, object current_configuration )
{
  string cl;
  mapping m;

  if(!current_configuration)
    cl="Global Variables";
  else
    cl=current_configuration->name;

  read_it(cl);
  
  if (q) {
    configs[cl][reg] = copy_value(vars);
  } else {
    mixed var;
    
    m = ([ ]);
    
    foreach(indices(vars), var)
      m[copy_value(var)] = copy_value( vars[ var ][ VAR_VALUE ] );
    
    configs[cl]->store_region(reg, m);
  }
  
  save_it(cl);
}


mapping retrieve(string reg, object current_configuration)
{
  string cl;

  if(!current_configuration)
    cl="Global Variables";
  else
    cl=current_configuration->name;
  
  read_it(cl);

  if (configs[cl])
    return configs[cl]->retrieve(reg) || ([]);
  else
    return ([]);
}
/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 */
