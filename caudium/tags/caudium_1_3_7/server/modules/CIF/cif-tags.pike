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
        "conflist" : container_conflist
    ]);
}

//
// Tags
//
array(string) container_conflist(string tag, mapping args, string contents, object id, mapping defines)
{
    object cif_config = id->conf->get_provider("cif-config");

    if (!cif_config)
        return ({""});

    array(mapping)   configs = cif_config->list_all_configurations();
    array(mapping)   rep = ({});
    
    foreach(configs, mapping cfg) {
        mapping nmap = ([]);

        nmap->url = sprintf("%s(showconf)/?name=%s",
                            id->conf->query("MyWorldLocation"),
                            http_encode_url(cfg->name));
        nmap->name = cfg->name;
        rep += ({nmap});
    }

    return ({ do_output_tag(args, rep, contents, id) });
}
