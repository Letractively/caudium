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

constant module_type = MODULE_PARSER;
constant module_name = "CIF - tags module";
constant module_doc  = "CIF module that implements the tags/containers used in the themes.";
constant module_unique = 1;

#define EPREFIX "CIF TAGS: "

void create()
{}

void start(int num, object conf)
{}

mapping query_tag_callers()
{
    return ([]);
}

mapping query_container_callers()
{
    return ([
      "showdata" : container_showdata,
    ]);
}

private mapping get_session(object id)
{
  if (!id->misc->gsession || !id->misc->gsession->session)
    return 0;

  return id->misc->gsession->session;
}

private array(string) do_configs(object id, object cif_config)
{
  array(string) configs = cif_config->list_all_configurations();
  
  return ({});
}

private array(string) do_data(object id, object cif_config)
{
  array(string)   configs = cif_config->list_all_region_names(session->config_name);

  foreach(configs, string cfg) {
    mapping nmap = ([]);

    array(string) parts = cfg / "#";
    object        mod;

    if (!id->conf->modules[parts[0]])
      continue;
        
    if ((int)parts[1] != 0)
      mod = id->conf->modules[parts[0]]->copies[(int)parts[1]];
    else
      mod = id->conf->modules[parts[0]]->enabled;
        
    nmap->url = sprintf("%sshowregion?name=%s",
                        id->conf->query("MyWorldLocation"),
                        Caudium.http_encode_url(cfg));
    nmap->name = cfg;

        
    nmap->label = "";
    
    rep += ({nmap});
  }
  
  return ({});
}

//
// Tags
//
array(string) container_showdata(string tag, mapping args, string contents, object id, mapping defines)
{
    object   cif_config = id->conf->get_provider("cif-config");
    mapping  session;
    
    if (!cif_config || !(session = get_session(id)) || !session->showdata)
        return ({""});

    array(mapping)  rep = ({});
    
    switch(session->showdata) {
        case "configs":
          rep = do_configs(id, cif_config);
          break;

        case "data":
          rep = do_data(id, cif_config);
          break;

        default:
          report_warning(EPREFIX + "unknown action: %s", session->showdata);
          return ({""}});
    }    

    return ({ do_output_tag(args, rep, contents, id) });
}
