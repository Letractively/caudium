/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
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

constant module_type = MODULE_PARSER | MODULE_LOCATION;
constant module_name = "CIF - Main Module";
constant module_doc  = "Caudium Configuration InterFace main module. This module implements the core of the "
                       "web-based Caudium management.";
constant module_unique = 1;

private object our_conf = 0;
private object cif_config;

void create()
{
    defvar("mountpoint", "/", "Paths: Mount Point", TYPE_LOCATION,
           "This is where the configuration interface will be found in the "
           "namespace of your virtual host.");

    defvar("title", "Caudium: Configuration InterFace", "Strings: Document title", TYPE_STRING,
           "This is the string that will be used as the title of the HTML documents "
           "generated for each page of the CIF.");

    defvar("realm", "Caudium Configuration Interface", "Strings: Realm", TYPE_STRING,
           "Realm name which will be shown in the HTTP authentication dialog box");

    defvar("authfailedmsg", "Caudium Configuration Interface: <strong>authentication failed.</strong>",
           "Strings: Authentication Failed message", TYPE_STRING,
           "The message that will be shown to the user when authentication failed.");
}

private array(string) dependencies = ({
    "gsession", "gbutton", "cif-config"
});

void start(int num, object conf)
{
    our_conf = conf;
    module_dependencies(conf, dependencies);
    
    cif_config = conf->get_provider("cif-config");
}

string query_location()
{
    return QUERY(mountpoint);
}

private mapping notyet_style = ([
    "body" : "font-family: sans-serif; background-color: #eeeeee;",
    "strong" : "font-weight: bold; color: #aa0000;"
]);

private mapping error_style = ([
    "body" : "font-family: sans-serif; font-size: xlarge; background-color: #eeeeee;",
    "strong" : "font-weight: bold; color: #FF0000;"
]);

//
// The actions we handle
//
private mapping cif_actions = ([
  "root" : do_root,
  "showconf" : do_showconf
]);

//
// Show the main screen of the interface
//
private mapping do_root(object id)
{
  return http_htmldoc_answer(parse_rxml(sprintf("<strong>Not yet (config dir: %s)</strong><br>"
                                                "Configurations:<br>"
                                                "<conflist>#name#: <a href='#url#'>#name#</a><br></conflist>",
                                                caudium->configuration_dir), id),
                             QUERY(title), 0, notyet_style);
}

//
// Show the given configuration
//
private mapping do_showconf(object id)
{
  string  title = "Configuration for %s";

  return http_htmldoc_answer("showconf",
                            sprintf(title, id->variables->name ? id->variables->name : "unnamed"));
}

//
// A temporary function to ask the user for their
// login/password. Eventually this will be handled by the UI module.
//
private mixed get_auth_data(object id)
{
   return http_auth_required(QUERY(realm), QUERY(authfailedmsg), 1);
}

mixed find_file(string f, object id)
{
    //
    // we need a session here
    //
    if (!id->misc->gsession || !id->misc->gsession->session)
        return http_htmldoc_answer("<strong>Session data missing. Cannot continue</strong>",
                                   QUERY(title), 0, error_style);

    mapping session = id->misc->gsession->session;
    
    //
    // check whether we are logged in or not
    //
    if (!session->loggedin) {
        if (!id->realauth)
            return get_auth_data(id);

        array(string)  bauth = id->realauth / ":";
        
        do_login(bauth[0], bauth[1], id, session);
        if (!session->loggedin)
            return get_auth_data(id);
    }

    if (!f || f == "" || f == "/")
      f = "root";

    foreach(indices(cif_actions), string index)
      if (index == f) {
        if (objectp(cif_actions[f]) && functionp(cif_actions[f]->run))
          return cif_actions[f]->run(id);
        else if (functionp(cif_actions[f]))
          return cif_actions[f](id);
        else
          report_warning("Unknown file '%s' in the CIF", f);
      }

    return http_htmldoc_answer("404", "CIF: No such file");
}

//
// Find auth plugin(s) and query them in order for login information. 
//
private int cmp_plugins(mixed o1, mixed o2)
{
    if (!objectp(o1) || !objectp(o2))
        return 0;

    if (!functionp(o1->get_order) || !functionp(o2->get_order))
        return 0;

    if (o1->get_order() > o2->get_order())
        return 1;

    return 0;
}

private void do_login(string user, string pass, object id, mapping session)
{
    array(object) authplugins = id->conf->get_providers("cif-auth-plugin");

    if (authplugins && sizeof(authplugins)) {
        authplugins = Array.sort_array(authplugins, cmp_plugins);
        foreach(authplugins, object p)
            if (functionp(p->authenticate_user) && p->authenticate_user(user, pass, id, session))
                return;
    }
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: mountpoint
//! This is where the configuration interface will be found in the namespace of your virtual host.
//!  type: TYPE_LOCATION
//!  name: Paths: Mount Point
//
//! defvar: title
//! This is the string that will be used as the title of the HTML documents generated for each page of the CIF.
//!  type: TYPE_STRING
//!  name: Strings: Document title
//
//! defvar: realm
//! Realm name which will be shown in the HTTP authentication dialog box
//!  type: TYPE_STRING
//!  name: Strings: Realm
//
//! defvar: authfailedmsg
//! The message that will be shown to the user when authentication failed.
//!  type: TYPE_STRING
//!  name: Strings: Authentication Failed message
//
