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

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "LDAP: Error module for the Command Center";
constant module_doc  = "Module that manages LDAP error messages for the LCC.";

constant module_unique = 0;

void create()
{
    defvar("provider_prefix", "lcc", "Provider module prefix", TYPE_STRING,
           "This prefix must match one of the LDAP Command Center prefixes used "
           "in this virtual server or otherwise the LCC module won't load. Initially "
           "both LCC and this module share the <code>lcc</code> prefix.");
}

string query_provides()
{
    return QUERY(provider_prefix) + "_error";
}

mapping error(object id, int errcode, mixed|void errextra)
{
    return http_redirect("http://localhost/", id);
}
