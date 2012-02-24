/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

//! Saver module for Caudium CIF
//! $Id$

#include <confignode.h>
#include <module.h>

//!
string module_short_name(object m, object cf)
{
  string sn;
  mapping mod;
  int i;
  if(!objectp(m))
    error("module_short_name on non object.\n");

  sn=cf->otomod[ m ];
  mod=cf->modules[ sn ];

  if(!mod) error("No such module!\n");

  if(!mod->copies) return sn+"#0";

  if((i=search(mod->copies, m)) >= 0)
    return sn+"#"+i;

  error("Module not found.\n");
}

//!
inline int is_module(object node)
{
  if(!node) return 1;
  switch(node->type)
  {
   case NODE_MODULE_COPY:
   case NODE_MODULE_MASTER_COPY:
    return 1;
  }
}

//!
void save_module_variable(object o)
{
  object module;
  
  module = o;

  while(!is_module(module))
    module = module->up;

  if(!module)
    module = this_object()->root;

  if(objectp(module->data))
    module->data->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else if(mappingp(module->data) && module->data->master)
    module->data->master->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else if(o->config())
    o->config()->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
  else
    caudium->set(o->data[VAR_SHORTNAME], o->data[VAR_VALUE]);
      
  if(o->changed) o->change(-o->changed);
}

//!
void save_global_variables(object o)
{
  caudium->store("Variables", caudium->variables, 0, 0);
//  caudium->initiate_configuration_port();
  init_logger();
  caudium->initiate_supports();
  if(o->changed) o->change(-o->changed);
}

//!
void save_module_master_copy(object o, object config)
{
  string s;

  caudium->current_configuration = config;
  caudium->store(s=o->data->sname+"#0", o->data->master->query(), 0, o->config());
  o->data->master->start(2, config);
  o->config()->invalidate_cache();
  if(o->changed) o->change(-o->changed);
}

//!
void save_configuration_global_variables(object o, object config)
{
  caudium->store("spider#0", o->config()->variables, 0, o->config());
  if(o->changed) o->change(-o->changed);
  o->config()->start(2, config);
}

//!
void save_configuration(object o, object config)
{
  if(o->changed) o->change(-o->changed);
  config->invalidate_cache();
//o->config()->start(2, config);
}

//!
void save_module_copy(object o, object config)
{
  string s;
  object cf;
  s=module_short_name(o->data, cf=o->config());

  if(!s) error("Fop fip.\n");

  cf->invalidate_cache();
  
  caudium->store(s, o->data->query(), 0, cf);
  if(o->data->start) o->data->start(2, config);
  if(o->changed) o->change(-o->changed);
}
