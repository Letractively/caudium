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
constant module_name = "LDAP: Auth module for the Command Center";
constant module_doc  = "Module that manages LDAP authentication for the LCC. "
                       "In addition to authentication, this module sets up the connection for "
                       "the current LDAP session.<br />"
                       "This module is <strong>not supposed</strong> to ask for the browser user "
                       "authentication - it can assume this had been done before calling the "
                       "<code>auth</code> method. The only things this module is expected to do "
                       "are authenticated the user with the LDAP and setting up the LDAP part of "
                       "the user mapping stored in the session.";

constant module_unique = 0;

void create()
{
    defvar("provider_prefix", "lcc", "Provider module prefix", TYPE_STRING,
           "This prefix must match one of the LDAP Command Center prefixes used "
           "in this virtual server or otherwise the LCC module won't load. Initially "
           "both LCC and this module share the <code>lcc</code> prefix.");

    // LDAP
    defvar("ldap_basedn", "", "LDAP: base DN", TYPE_STRING,
           "Base DN (Distinguished Name) to be used in all the operations throughout "
           "the session in which this module was used to authenticate the users. ");

    defvar("ldap_god_dn", "", "LDAP: admin bind dn", TYPE_STRING,
           "The omnipotent DN that can do anything to the directory - used to retrieve "
           "user listings etc.");

    defvar("ldap_god_pass", "", "LDAP: admin bind password", TYPE_STRING,
           "Password for the admin DN");

    defvar("ldap_protocol", 3, "LDAP: protocol version to use", TYPE_INT_LIST,
           "The LDAP protocol version to use with this server",
           ({2, 3}));

    defvar ("ldap_scope","subtree","LDAP: query scope", TYPE_STRING_LIST,
            "Scope used by LDAP search operation."
            "", ({ "base", "onelevel", "subtree" }));
}

string query_provides()
{
    return QUERY(provider_prefix) + "_auth";
}

mapping auth(object id, mapping user, object ldap)
{
    mixed    error;
    
    if (user->name == "")
        return ([
            "lcc_error" : ERR_NO_USERNAME,
            "lcc_error_extra" : user->name
        ]);
    
    switch(QUERY(ldap_scope)) {
        case "subtree":
            ldap->set_scope(2);
            break;
            
        case "onelevel":
            ldap->set_scope(1);
            break;
            
        case "base":
            ldap->set_scope(0);
            break;
    }
    ldap->set_basedn(QUERY(ldap_basedn));

    error = catch {
        ldap->bind(user->name, user->password, QUERY(ldap_protocol));
    };

    if (error) {
        mapping ret = ([]);
        if (arrayp(error)) {
            ret->lcc_error = ERR_LDAP_BIND;
            ret->lcc_error_extra = error[0];
        } else {
            ret->lcc_error = ERR_LDAP_BIND;
        }

        return ret;
    }

    //
    // Set the rest of the values now that we're bound
    //
    user->ldap->god_dn = QUERY(ldap_god_dn);
    user->ldap->god_pass = QUERY(ldap_god_pass);
    user->ldap->protocol = QUERY(ldap_protocol);
    
    return 0; // 0 == everything's fine
}

