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
                       "the current LDAP session.<br />";

constant module_unique = 0;

int usedefdomain_not_set()
{
    return(!QUERY(user_usedefdomain));
}

void create()
{
    defvar("provider_prefix", "lcc", "Provider module prefix", TYPE_STRING,
           "This prefix must match one of the LDAP Command Center prefixes used "
           "in this virtual server or otherwise the LCC module won't load. Initially "
           "both LCC and this module share the <code>lcc</code> prefix.");

    // User auth
    defvar("user_dntype", "any", "User auth: DN type", TYPE_STRING_LIST,
           "This module can authenticate users based on number of LDAP attributes. "
           "It is possible to create the DN using the <code>uid</code> attribute, "
           "the <code>mail</code> attribute or both of them simultanously. Below "
           "is a short explanation of what choices the adminstrator has:<br />"
           "<blockquote><ul>"
           "<li><strong><code>any</code></strong>. This means that the module will "
           "attempt to authenticate the user using any of the two attributes mentioned "
           "above. If the login typed by the user contains the <code>@</code> character "
           "the login string will be treated as an email address and the user will be "
           "sought for using the <code>mail</code> attribute. If there's no <code>@</code> "
           "character in the login string, the search will be performed on the <code>uid</code> "
           "attribute. If the <em>Fallback to UID</em> option below is set then, should "
           "the <code>mail</code> search fail, the module will attempt the <code>uid</code> "
           "authentication.</li>"
           "<li><strong><code>uid</code></strong>. The search is performed only on the "
           "<code>uid</code> attribute no matter what type of string the user entered "
           "in the login box. If the string is an email address, though, only the part "
           "before the <code>@</code> character will be used.</li>"
           "<li><strong><code>email</code></strong>. The search is performed on the "
           "<code>mail</code> attribute. If the string entered by the user in the login "
           "box comes without the <code>@</code> character the further action depends upon "
           "the value of the <em>Use default domain</em> option. If the option is unset "
           "then the authentification will fail and if it exists the domain name "
           "(or names - see the <em>Use default domain</em> description) will be suffixed "
           "to the typed string and the authentication will be retried.</li>"
           "<li><strong><code>both</strong></code>. This setting means that the user search "
           "will be performed using both the <code>uid</code> and the <code>mail</code> "
           "attributes. In this case the rules described in the previous section apply.</li>"
           "</ul></blockquote>",
           ({ "any", "uid", "email", "both"}));

    defvar("user_uidfallback", 0, "User auth: Fallback to UID", TYPE_FLAG,
           "If enabled, the failed <code>email</code> authentication will be attempted "
           "using the <code>uid</code> attribute as explained in the <em>DN type</em> "
           "description.");

    defvar("user_usedefdomain", 0, "User auth: Use default domain", TYPE_FLAG,
           "If set then the default domain(s) will be used during authentication as "
           "explained in the description of the <em>DN type</em> option.");

    defvar("user_defdomains", "", "User auth: Default domain(s)", TYPE_TEXT_FIELD,
           "This is a list of default domains, one per line. If more than one domain "
           "is listed here, then the login screen will contain a selection list "
           "with those domains in the order given below. If there's just one line in this "
           "box, it will be used silently when/if needed.",
           0, usedefdomain_not_set);
    
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

private string make_dn(object id, string login)
{}

mapping auth(object id, mapping user, object ldap)
{
    mixed    error;
    int      result = 0;
    
    if (user->name == "" && (!id->variables || !id->variables->lcc_login)) {
        object sprov = PROVIDER(QUERY(provider_prefix) + "_screens");
        if (!sprov)
            return ([
                "lcc_error" : ERR_PROVIDER_ABSENT,
                "lcc_error_extra" : "No 'screens' provider"
            ]);
        
        string authscr = sprov->retrieve(id, "auth");
        if (authscr && authscr != "")
            return http_string_answer(authscr);
        else
            return ([
                "lcc_error" : ERR_SCREEN_ABSENT,
                "lcc_error_extra" : "No 'auth' scren found"
            ]);
    } else if (id->variables && id->variables->lcc_login) {
        user->name = id->variables->lcc_login;
        user->dn = make_dn(id, user->name);
        user->password = id->variables->lcc_password;
    }
    
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

    report_notice("Trying to bind with %s:%s on ldap %O\n", user->name, user->password, ldap);
    
    error = catch {
        result = ldap->bind(user->name, user->password, QUERY(ldap_protocol));
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
    } else if (result) {
        return ([
            "lcc_error" : ERR_AUTH_FAILED,
            "lcc_error_extra" : ldap->error_string()
        ]);
    }

    //
    // Set the rest of the values now that we're bound
    //
    user->ldap->god_dn = QUERY(ldap_god_dn);
    user->ldap->god_pass = QUERY(ldap_god_pass);
    user->ldap->protocol = QUERY(ldap_protocol);
    
    return 0; // 0 == everything's fine
}

