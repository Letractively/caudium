/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
 * Copyright � 1994-2000 Roxen Internet Software
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

// import Array;

#include <caudium.h>
#include <module.h>

#ifndef IN_INSTALL
inherit "newdecode";
// string cvs_version = "$Id$";
#else
import spider;
# define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)
# include "newdecode.pike"
#endif

// import Array;
// import Stdio;

mapping (string:mapping) configs = ([ ]);
mapping (string:array(int)) config_stat_cache = ([]);
string configuration_dir; // Set by Roxen.

mapping copy_configuration(string from, string to)
{
  if(!configs[from]) return 0;
#ifdef DEBUG
  write(sprintf("Copying configuration \"%s\" to \"%s\"\n", from, to));
#endif /* DEBUG */
  configs[to] = copy_value( configs[from] );
  return configs[to];
}

array (string) list_all_configurations()
{
  array (string) fii;
  fii=get_dir(configuration_dir);
  if(!fii)
  {
    mkdirhier(configuration_dir+"test", 0700); // removes the last element..
    fii=get_dir(configuration_dir);
    if(!fii)
    {
      report_fatal("I cannot read from the configurations directory ("+
		   combine_path(getcwd(), configuration_dir)+")\n");
      exit(-1);	// Restart.
    }
    return ({});
  }
  return Array.map(Array.filter(fii, lambda(string s){
    if(s=="CVS" || s=="Global_Variables" || s=="Global Variables"
       || s=="global_variables" || s=="global variables" )
      return 0;
    return (s[-1]!='~' && s[0]!='#' && s[0]!='.');
  }), lambda(string s) { return replace(s, "_", " "); });
}

void save_it(string cl)
{
  object fd;
  string f;
#ifdef DEBUG_CONFIG
  perror("CONFIG: Writing configuration file for cl "+cl+"\n");
#endif

  f = configuration_dir + replace(cl, " ", "_");
  mv(f, f+"~");
  fd = open(f, "wc");
  if(!fd)
  {
    error("Creation of configuration file failed ("+f+") "
#if 0&&efun(strerror)
	  " ("+strerror()+")"
#endif
	  "\n");
    return;
  }
  string data = encode_regions( configs[ cl ] );
  int num;
  catch(num = fd->write(data));
  if(num != strlen(data))
  {
    error("Failed to write all data to configuration file ("+f+") "
#if efun(strerror)
	  " ("+strerror(fd->errno())+")"
#endif
	  "\n");
  }
  config_stat_cache[cl] = (array(int)) fd->stat();
  catch(fd->close("w"));
  destruct(fd);
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
  if(configs[cl]) return;

  object fd;

  mixed err;
  err = catch {
    fd = open(configuration_dir + replace(cl, " ", "_"), "r");
    if(!fd)
    {
      fd = open(configuration_dir + cl, "r");
      if(fd) rm(configuration_dir + cl);
    }
  
    if(!fd) {
      configs[cl] = ([ ]);
      m_delete(config_stat_cache, cl);
      } else {
      configs[cl] = decode_config_file( fd->read( 0x7fffffff ));
      config_stat_cache[cl] = (array(int))fd->stat();
      fd->close("rw");
      fix_config(configs[cl]);
      destruct(fd);
    }
  };
  if (err) {
    report_error(sprintf("Failed to read configuration file for %O\n"
			 "%s\n", cl, describe_backtrace(err)));
  }
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
#if 0&&efun(strerror)
	  strerror()
#endif
	  "\n");
  }
}

void store( string reg, mapping vars, int q, object current_configuration )
{
  string cl;
  mapping m;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif
  read_it(cl);
  
  if(q)
    configs[cl][reg] = copy_value(vars);
  else
  {
    mixed var;
    m = ([ ]);
    foreach(indices(vars), var)
      m[copy_value(var)] = copy_value( vars[ var ][ VAR_VALUE ] );
    configs[cl][reg] = m;
  }    
  save_it(cl);
}


mapping retrieve(string reg, object current_configuration)
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

  return configs[cl][reg] || ([ ]);
}
