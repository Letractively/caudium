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

constant module_type = MODULE_LOCATION | MODULE_EXPERIMENTAL;
constant module_name = "LDAP: Command Center";
constant module_doc  = "Central LDAP management module. Provides the connection to the "
                       "provider modules, manages the session data for them and dispatches "
                       "the requests to the provider modules.";

constant module_unique = 0;

//
// LDAP connection cache
//
private mapping(string:object) conn_cache = ([]);

//
// Known provider modules
//

//
// Provider is a "request" one - that means a file of the same name passed
// to find_file will invoke exactly this module.
//
#define PROVIDER_REQUEST  0x0001

//
// Provider is required
//
#define PROVIDER_REQUIRED 0x0002

//
// Indices are request "file" names (if the PROVIDER_REQUEST flag is set)
//
private multiset(string) reserved_providers = (<
    "add", "modify", "auth", "log", "admin", "screens",
    "error", "menu"
>);

private mapping(string:mapping) providers = ([
    "add" : ([ "flags" : PROVIDER_REQUEST, "name" : 0 ]),
    "modify" : ([ "flags" : PROVIDER_REQUEST, "name" : 0 ]),
    "auth" : ([ "flags" : PROVIDER_REQUIRED, "name" : 0 ]),
    "log" : ([ "flags" : 0, "name" : 0 ]),
    "admin" : ([ "flags" : PROVIDER_REQUEST, "name" : 0 ]),
    "screens" : ([ "flags" : PROVIDER_REQUIRED, "name" : 0 ]),
    "error" : ([ "flags" : PROVIDER_REQUIRED, "name" : 0 ]),
    "menu" : ([ "flags" : PROVIDER_REQUIRED | PROVIDER_REQUEST, "name" : 0])
]);

//
// Menu registration records
//
private array(mapping) my_menus = ({
    ([
        "name" : "Logout",
        "url" : "/logout",
        "provider" : "_ldap-center"
    ]),
    ([
        "name" : "About",
        "url" : "/about",
        "provider" : "_ldap-center"
    ])
});

private string make_reserved_ul()
{
    string ret = "<ul>";
    
    foreach(sort(indices(reserved_providers)), string idx)
        ret += "<li><strong><code>" + idx + "</code></strong></li>";

    return ret;
}

void create()
{
    defvar("mountpoint", "/", "Mount point", TYPE_LOCATION,
           "This is where the module will be visible in the "
           "virtual server namespace.");
    defvar("provider_prefix", "lcc", "Provider module name prefix", TYPE_STRING,
           "This string (plus an underscore) will be prepended to all the "
           "provider module names this module uses. For example, if a request "
           "is made to find a provider module named <code>add</code> the "
           "resulting name will be <code>lcc_add</code>");
    defvar("auth_realm", "LDAP Command Center", "Authentication realm", TYPE_STRING,
           "The string that will be shown to the user while authenticating with his "
           "browser.");
    defvar("auth_failed", "<strong>Authentication failed</strong>", "Authentication failed message",
           TYPE_TEXT_FIELD,
           "Message that will be sent to the browser when the user's authentication failed "
           "or was cancelled by the user.");
    defvar("user_providers", "", "User-defined providers",
           TYPE_TEXT_FIELD,
           "You can define your own actions this module will handle with the aid of your "
           "provider modules. Provider definitions are given one entry per line and "
           "must follow the format given below:<br />"
           "<blockquote><strong><code>module_base_name:is_required</code></strong></blockquote>"
           "where,<br /><blockquote><ul>"
           "<li><strong><code>module_base_name</code></strong> is a name of the provider module to which "
           "the <em>Provider module name prefix</em> will be prepended to form the real provider name.</li>"
           "<li><strong><code>is_required</code></strong> is <code>0</code> if the provider isn't required "
           "and <code>&gt;0</code> if it is.</li></ul></blockquote>"
           "All the user-defined modules are request handlers - that is, they will be called through "
           "the <code>handle_request</code> function that must be present in the object. "
           "The following module names are reserved:<blockquote>" + make_reserved_ul() + "</blockquote>");
    
    //  
    // Provider Modules
    //
    /*
    defvar("pm_add_name", "add", "Provider modules: 'add' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the <code>add</code> operation.</p>"
           "<p>This module must export the following functions:<br><ul>"
           "<li>add [TODO: syntax]</li>"
           "</ul></p>"
           "<p>This module is used to add new users to the LDAP directory. Only users that "
           "have been authenticated as administrators can use this provider.</p>"
          );

    defvar("pm_modify_name", "modify", "Provider modules: 'modify' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the <code>modify</code> operation.</p>"
           "<p>This module must export the following functions:<br><ul>"
           "<li>modify [TODO: syntax]</li>"
           "</ul></p>"
           "<p>This module is used to modify the user data, within the allowed limits. Only the "
           "administrators can modify all data in all the accounts.</p>"
          );

    defvar("pm_auth_name", "auth", "Provider modules: 'auth' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the <code>auth</code> operation.</p>"
           "<p>This module must export the following functions:<br><ul>"
           "<li>auth [TODO: syntax]</li>"
           "</ul></p>"
           "<p>This module is used to authenticate users with LDAP. It is also responsible for "
           "detecting the user's privileges with relation to the administration tasks."
          );

    defvar("pm_admin_name", "admin", "Provider modules: 'admin' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the <code>admin</code> operation.</p>"
           "<p>This module must export the following functions:<br><ul>"
           "<li>admin [TODO: syntax]</li>"
           "</ul></p>"
           "<p>This module is used to perform all the administrative tasks not available for "
           "normal users - listing, removing, disabling, changing the privileges etc.</p>"
          );

    defvar("pm_log_name", "log", "Provider modules: 'log' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the <code>log</code> operation.</p>"
           "<p>This module must export the following functions:<br><ul>"
           "<li>log [TODO: syntax]</li>"
           "</ul></p>"
           "This module handles all the loging tasks - it can log to syslog, to file, send mails "
           "etc. etc.</p>"
          );

    defvar("pm_screens_name", "screens", "Provider modules: 'screens' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the all the HTML screens."
           "<p>This module must export the following functions:<br><ul>"
           "<li>screen [TODO: syntax]</li>"
           "</ul></p>"
           "<p>This module is responsible for retrieving, manipulating (replacing of variables, default "
           "values etc.) the template HTML files used to present data to the user.</p>"
          );

    defvar("pm_screens_name", "screens", "Provider modules: 'screens' module name",
           TYPE_STRING | VAR_MORE,
           "<p>Name of the provider module that handles the all the HTML screens."
           "<p>This module must export the following functions:<br><ul>"
           "<li>screen [TODO: syntax]</li>"
           "</ul></p>");
    */
    
    //
    // LDAP
    //
    defvar("ldap_server", "ldap://localhost", "LDAP: server URL", TYPE_STRING,
           "LDAP URL of the directory server to be used");    
}

string query_location()
{
    return QUERY(mountpoint);
}

void start(int cnt, object conf)
{
    module_dependencies(conf, ({"ldapuserauth",
                                "ldap-auth",
                                "ldap-screens",
                                "ldap-error",
                                "ldap-menu"}));

    // Parse the user-defined providers
    
    // prepare provider names and check for the presence of the required
    // ones, if any
    array(string) udprov = (QUERY(user_providers) / "\n") - ({}) - ({""});
    foreach(udprov, string prov) {
        array(string) line = prov / ":";

        if (sizeof(line) != 2)
            continue;

        string name = lower_case(String.trim_whites(line[0]));
        if (reserved_providers[name]) {
            report_warning("LCC: Reserved module name '%s' used in user defined modules.\n",
                           name);
            continue;
        }
        
        mapping menu = ([
            "flags" : PROVIDER_REQUEST
        ]);
        
        menu->name = QUERY(provider_prefix) + "_" + name;
        if (String.trim_whites(line[1]) != "0")
            menu->flags |= PROVIDER_REQUIRED;

        providers[name] = menu;
    }
        
    foreach(indices(providers), string idx) {
        providers[idx]->name = sprintf("%s_%s", QUERY(provider_prefix), idx);
        if (providers[idx]->flags & PROVIDER_REQUIRED)
            if (!conf->get_provider(providers[idx]->name))
                throw(({sprintf("Required provider '%s' absent!\n", providers[idx]->name),
                        backtrace()}));
    }

    my_menus[0]->provider = QUERY(provider_prefix) + my_menus[0]->provider;
}

void stop()
{
    mixed error;
    
    if (conn_cache && sizeof(conn_cache))
        foreach(indices(conn_cache), string idx) 
            if (objectp(conn_cache[idx])) {
                error = catch(conn_cache[idx]->unbind());
                destruct(conn_cache[idx]);
                m_delete(conn_cache, idx);
            }
}


private mapping init_user(object id)
{
    mapping(string:mixed)   ret = ([]);

    if (id->auth && arrayp(id->auth) && id->auth[0]) {
        ret->name = id->auth[1];
        ret->password = id->auth[2];
    } else {
        ret->name = "";
        ret->password = "";
    }

    ret->flags = 0;
    ret->authenticated = 0;
    ret->session = id->misc->session_id;
    ret->ldap = ([]);
    ret->prefix = QUERY(provider_prefix);
    ret->my_world = id->conf->QUERY(MyWorldLocation);
    ret->mountpoint = QUERY(mountpoint);
    ret->lang = "en";
    
    return ret;
}

//
// Actions we handle in this module
//
private mixed do_logout(object id, mapping data, string f)
{
    object sprov = PROVIDER(QUERY(provider_prefix) + "_screens");
    if (!sprov)
        return ([
            "lcc_error" : ERR_PROVIDER_ABSENT,
            "lcc_error_extra" : "No 'screens' provider"
        ]);
    
    //TODO: kill the session, the LDAP connection, everything here!
    data->user->name = "";
    data->user->password = "";
    
    string logoutscr = sprov->retrieve(id, "logout");
    if (logoutscr && logoutscr != "")
        return http_string_answer(logoutscr);
    else
        return ([
            "lcc_error" : ERR_SCREEN_ABSENT,
            "lcc_error_extra" : "No 'auth' scren found"
        ]);
}

mixed handle_request(object id, mapping data, string f)
{
    switch(f) {
        case "logout":
            return do_logout(id, data, f);

        case "about":
        default:
            return http_string_answer("The <code>About</code> data will come here...");
    }
}


mixed find_file(string f, object id)
{
    object  p_err = PROVIDER(providers->error->name);

    if (!f || f == "")
        f = "menu";
    
    if (!p_err)
        return http_string_answer("Major screwup - provider module missing<br />");
    
    if (!SVARS(id))
        return p_err->error(id, ERR_NO_SESSION_VARS);

    if (!SDATA(id)) 
        SDATA(id) = ([]);
    
    if (!SUSER(id))
        SUSER(id) = init_user(id);
    
    mixed     error = 0;

    //
    // Create the LDAP object if it doesn't exist yet for this session but
    // do not bind - it's not our business, the auth module will take care
    // of it.
    //
    if (!conn_cache[id->misc->session_id]) {
        error = catch {
            conn_cache[id->misc->session_id] = Protocols.LDAP.client(QUERY(ldap_server));
        };

        if (error) {
            if (arrayp(error))
                return p_err->error(id, ERR_LDAP_CONNECT, error[0]);
            else
                return p_err->error(id, ERR_LDAP_CONNECT);
        }
    }
    
    mapping response = 0;
    
    if ((!SDATA(id) || !SUSER(id) || !SUSER(id)->authenticated)) {
        object auth_prov = PROVIDER(providers->auth->name);
        if (!auth_prov)
            return p_err->error(id, ERR_PROVIDER_ABSENT, providers->auth->name);

        response = auth_prov->auth(id, SUSER(id), conn_cache[id->misc->session_id]);
        if (response)
            if (response->lcc_error)
                return p_err->error(id, response->lcc_error, response->lcc_error_extra);
            else
                return response;

        SUSER(id)->authenticated = 1;

        //
        // OK, now we can register the menus exported from the providers
        //
        object menu_prov= PROVIDER(providers->menu->name);

        // first our menus
        menu_prov->register_menus(id, my_menus);
        
        foreach(indices(providers), string idx) {
            if (idx == "menu")
                continue;
            
            object p = PROVIDER(providers[idx]->name);
            if (!p || !p->query_menus || !functionp(p->query_menus))
                continue;

            mapping|array(mapping) menus = p->query_menus(id);
            if (!menus || !sizeof(menus))
                continue;
            
            menu_prov->register_menus(id, menus);
        }        
    }

    //
    // Find the appropriate provider to handle the request
    //
    object    req_prov = 0;
    
    if (providers[f] && (providers[f]->flags && PROVIDER_REQUEST)) {
        req_prov = PROVIDER(providers[f]->name);

        if (!req_prov)
            return p_err->error(id, ERR_PROVIDER_ABSENT, providers[f]->name);
    } else {
        switch(f) {
            case "logout":
            case "about":
                req_prov = this_object();
                break;
                
            default:
                return p_err->error(id, ERR_INVALID_REQUEST);
        }
    }
    
    //
    // Authenticated. Fine, let's handle the request.
    //
    response =  req_prov->handle_request(id, SDATA(id), f);

    if (response && response->close_ldap) {
        if (conn_cache[id->misc->session_id] && objectp(conn_cache[id->misc->session_id])) {
            error = catch(conn_cache[id->misc->session_id]->unbind());
            destruct(conn_cache[id->misc->session_id]);
            m_delete(conn_cache, id->misc->session_id);
        }
    }

    return response ? response : http_string_answer("Some screwup - check your provider modules");
}

