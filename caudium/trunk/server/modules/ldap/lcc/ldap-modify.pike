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

constant module_type = MODULE_PROVIDER | MODULE_PARSER | MODULE_EXPERIMENTAL;
constant module_name = "LDAP: Account Edit module for the Command Center";
constant module_doc  = "Module that manages all the operations related "
                       "to the account data editing for a normal user.";

constant module_unique = 0;

private array(mapping) my_menus = ({
    ([
        "name" : "Edit Account",
        "url" : "/modify",
        "provider" : "_modify"
    ]),
    ([
        "name" : "Change Password",
        "url" : "/modify?todo=chpass",
        "provider" : "_modify"
    ])
});

void create()
{
    defvar("provider_prefix", "lcc", "Provider module name prefix", TYPE_STRING,
           "This string (plus an underscore) will be prepended to all the "
           "provider module names this module uses. For example, if a request "
           "is made to find a provider module named <code>add</code> the "
           "resulting name will be <code>lcc_modify</code>");
}

string status() 
{
    string ret = "This module provides the following menus:<br /><blockquote><ul>";

    foreach(my_menus, mapping mnu)
        ret += sprintf("<li><strong>%s</strong> at <em>%s</em></li>",
                       mnu->name, mnu->url);

    ret += "</ul></blockquote>";

    return ret;
}

void start(int cnt, object conf)
{
    foreach(my_menus, mapping mnu)
        mnu->provider = QUERY(provider_prefix) + mnu->provider;
}

array(mapping) query_menus(object id)
{
    report_notice("Returning menus: %O\n", my_menus);
    
    return my_menus;
}

string query_provides()
{
    return QUERY(provider_prefix) + "_modify";
}

mixed handle_request(object id, mapping data, string f)
{
    return http_string_answer("<strong>To Be Done</strong>");
}
