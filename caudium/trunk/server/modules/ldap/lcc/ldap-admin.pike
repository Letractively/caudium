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
constant module_name = "LDAP: User Admin";
constant module_doc  = "Module that enables the administrator to manipulate "
                       "the user accounts on the LDAP server - adding, editing, "
                       "listing, searching operations are available.";

constant module_unique = 0;

private array(mapping) my_menus = ({
    ([
        "name" : "Admin",
        "url" : "/admin",
        "provider" : "_admin"
    ])
});

void create()
{
    defvar("provider_prefix", "lcc", "Provider module name prefix", TYPE_STRING,
           "This string (plus an underscore) will be prepended to all the "
           "provider module names this module uses. For example, if a request "
           "is made to find a provider module named <code>add</code> the "
           "resulting name will be <code>lcc_admin</code>");
    defvar("security_admindn", "cn=Directory Admin, dc=yourdomain, dc=com", "Security: administrator role", TYPE_STRING,
           "All users that are to be able to use this module must be listed in this DN's "
           "<tt>roleOccupant</tt> attribute (the DN must contain the <tt>organizationalRole</tt> "
           "class for this to work). Take a look at "
           "<a href='http://ldap.hklc.com/objectclass.html?objectclass=organizationalRole'>this page</a> "
           "for more information about the LDAP class.<br />"
           "If the user is not listed in this attribute, the module will "
           "not be visible in the menu but it still will be possible to access it through "
           "the provider interface (see the <em>access control provider name</em> option for more "
           "information about the access control).");
    defvar("security_acprov", "", "Security: access control provider name", TYPE_STRING,
           "Name of a provider module that can be used to validate access to this module "
           "during the request. Its 'check_access' function is called on every request "
           "handled by this module and is passed the RequestID object and the type of operation. If the function "
           "returns != 0, the request is handled, if 0 - the request is ignored silently. "
           "This check is done in addition to checking whether the person logged in "
           "is allowed to access this module at all. This is useful when you want to, for example, "
           "enable one-time access to the 'add' capability for account creation by anonymous "
           "users.");
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

string query_provides()
{
    return QUERY(provider_prefix) + "_admin";
}

array(mapping) query_menus(object id)
{
    return my_menus;
}

mixed handle_request(object id, mapping data, string f)
{}
