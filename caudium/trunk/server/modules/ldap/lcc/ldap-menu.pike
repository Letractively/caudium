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

#define SMENUAREA(_id_) SDATA(_id_)->menus
#define SMENU(_id_, _p_) SMENUAREA(_id_)[_p_]

constant module_type = MODULE_PARSER | MODULE_PROVIDER;
constant module_name = "LDAP: Menu module for the Command Center";
constant module_doc  = "Module that manages all the menu screens for the LCC.";

constant module_unique = 0;

private mapping tags = ([
        "_menu" : tag_lcc_menu,
        "_menus" : tag_lcc_menus
]);

void create()
{
    defvar("provider_prefix", "lcc", "Provider module prefix", TYPE_STRING,
           "This prefix must match one of the LDAP Command Center prefixes used "
           "in this virtual server or otherwise the LCC module won't load. Initially "
           "both LCC and this module share the <code>lcc</code> prefix.");
}

void start(int cnt, object conf)
{
    foreach(indices(tags), string idx) {
        tags[QUERY(provider_prefix) + idx] = tags[idx];
        m_delete(tags, idx);
    }
}

string status() 
{
    string ret = "This module provides the following tags:<br /><blockquote><ul>";

    foreach(indices(tags), string idx)
        ret += sprintf("<li><strong>%s</strong></li>", idx);

    ret += "</ul></blockquote>";

    return ret;
}

string query_provides()
{
    return QUERY(provider_prefix) + "_menu";
}

private mapping find_one_menu(object id, string pidx, string name)
{
    if (SMENUAREA(id) && SMENU(id, pidx)) {
        mapping prov = SMENU(id, pidx);
        int i = 1;

        while(1) {
            if (!prov[i])
                break;

            mapping menu = prov[i++];
            if (menu->name != name)
                continue;

            return menu;
        }
    }

    return 0;
}

private string make_all_menus(object id, mapping data, string|void f)
{
    string ret = "";

    if (SMENUAREA(id)) {
        foreach(sort(indices(SMENUAREA(id))), string idx) {
            
            mapping prov = SMENU(id, idx);
            int i = 1;

            while(1) {                
                if (!prov[i])
                    break;
                
                mapping menu = prov[i++];
                
                if (menu->url) {
                    string url = data->user->my_world + data->user->mountpoint[1..];
                    
                    ret += sprintf(" <a href='%s%s'>%s</a> | ",
                                   url,
                                   (url[-1] == '/' && menu->url[0] == '/' ? menu->url[1..] : menu->url),
                                   menu->name);
                } else
                    ret += sprintf(" %s | ", menu->name);
            }
        }
    
    }

    if (ret == "")
        return "<h1>Main Menu Empty!</h1>";

    return "|" + ret;
}

mapping handle_request(object id, mapping data, string f)
{
    string menuname = "mainmenu";
    
    if (id->variables && id->variables->menuname)
        menuname = id->variables->menuname;

    object sprov = id->conf->get_provider(QUERY(provider_prefix) + "_screens");
    string menuscreen = sprov ? sprov->retrieve(id, menuname, data->lang) : "";

    if (!menuscreen || menuscreen == "")
        return http_string_answer(make_all_menus(id, data, f));

    return http_string_answer(menuscreen);
}

//
// Register a menu from another provider with this object. The mapping
// contains the following indices:
//
//  name - name to be displayed
//
//  url - URL. If this one is missing, the action taken will depend on
//        which tag you are using to generate the menus. If it is
//        <lcc-menu /> then the menu item won't be shown if 'url' is
//        missing; if it is <lcc-menus /> then the item will be shown but
//        inactive (i.e. it won't be a link).
//
//  provider - provider module name for logging, error reporting and
//             storage purposes.
//
//  _id - this will be set by this function and the caller must not modify
//        this value - it will be/can be used to unregister the menu.
//
private void do_register_menu(object id, mapping menu)
{
    if (!menu || !menu->name || !menu->provider)
        return;
    
    if (!SMENU(id, menu->provider))
        SMENU(id, menu->provider) = ([
            "_id" : 1
        ]);

    menu->_id = SMENU(id, menu->provider)->_id++;
    
    SMENU(id, menu->provider)[menu->_id] = menu;
}

void register_menus(object id, mapping|array(mapping) menu)
{
    if (!SMENUAREA(id))
        SMENUAREA(id) = ([]);

    if (!menu || !sizeof(menu))
        return;

    if (mappingp(menu) && (!menu->name || !sizeof(menu->name)))
        return;

    if (mappingp(menu) && (!menu->provider || !sizeof(menu->provider)))
        return;
    
    if (arrayp(menu)) {
        foreach(menu, mapping m) {
            do_register_menu(id, m);
        }
    } else {
        do_register_menu(id, menu);
    }
    
    report_debug("Menus: %O\n", SMENUAREA(id));
}

private void do_unregister_menu(object id, mapping menu)
{
    if (!menu->_id) {
        report_warning("Trying to unregister invalid menu entry in ldap-menu");
        return;
    }
    
    if (SMENU(id, menu->provider) && SMENU(id, menu->provider)[menu->_id]) {
        m_delete(SMENU(id, menu->provider), menu->_id);
        m_delete(menu, "_id");
    }
}

void unregister_menus(object id, mapping|array(mapping) menu)
{
    if (!SMENUAREA(id))
        return;
    
    if (!menu || !sizeof(menu) || (mappingp(menu) && !menu->_id)) {
        report_warning("Trying to unregister invalid menu entry in ldap-menu");
        return;
    }

    if (arrayp(menu)) {
        foreach(menu, mapping m) {
            do_unregister_menu(id, m);
        }
    } else {
        do_unregister_menu(id, menu);
    }
}

//
// Tags
//

//
// Anchor attributes (HTML 4.01)
//
private multiset(string) anchor_attr = (<
    "id", "class", "lang", "title", "style",
    "shape", "coords", "onfocus", "onblur",
    "onclick", "ondblclick", "onmousedown", "onmouseup",
    "onmouseover", "onmousemove", "onmouseout",
    "onkeypress", "onkeydown", "onkeyup",
    "target", "tabindex", "accesskey", "name",
    "hreflang", "type", "rel", "rev", "charset"
>);

//
// <lcc_menu>
//
// Supported attributes:
//
//   - every standard attribute for the <a></a> HTML4 tag (note that 'href'
//     will be ignored)
//   - provider  - provider name from which the menu should come (required)
//   - menu  - menu name that the tag should output (required)
//   - always - if present, output the menu even if there's no URL for it
//
//   Attributes not in the anchor_attr multiset and not ours are left out
//   of the output.
//
string tag_lcc_menu(string tag,
                    mapping args,
                    object id)
{
    string ret = "<a ";

    if (!SMENUAREA(id))
        return "";
    
    if (!args || !sizeof(args) || !args->provider || !args->menu)
        return "<!-- Missing required parameters ('provider' or 'menu') to the lcc_menu tag -->";

    if (args->provider == "" || args->menu == "")
        return "<!-- Neither the 'provider' or the 'menu' parameter can be empty in the lcc_menu tag -->";

    if (!SMENU(id, args->provider))
        return sprintf("<!-- No provider '%s' in the lcc_menu tag -->", args->provider);
    
    // first the standard attributes
    foreach(indices(args), string idx)
        if (anchor_attr[lower_case(idx)])
            ret += sprintf("%s='%s' ", idx, args[idx]);

    // now ours
    mapping menu = find_one_menu(id, args->provider, args->menu);
    if (!menu || !sizeof(menu))
        return sprintf("<-- no such menu: %s->%s -->",
                       args->provider, args->menu);

    if (menu->url)
        ret += sprintf("href='%s'>%s</a>",
                       menu->url, (menu->name ? menu->name : "Unnamed Menu"));
    else if (args->always)
        ret += sprintf(">%s</a>", menu->name);
    else
        return "";

    return ret;
}

string tag_lcc_menus(string tag,
                     mapping args,
                     object id)
{
    return make_all_menus(id, SDATA(id));
}

mapping query_tag_callers()
{
    return tags;
}
