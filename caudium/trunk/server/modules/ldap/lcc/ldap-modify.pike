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

private mapping my_tags = ([
    "_minput" : tag_minput,
    "_mhidden" : tag_mhidden,
    "_mdump" : tag_mdump,
    "_mmail" : tag_mmail
]);

void create()
{
    defvar("provider_prefix", "lcc", "Provider module name prefix", TYPE_STRING,
           "This string (plus an underscore) will be prepended to all the "
           "provider module names this module uses. For example, if a request "
           "is made to find a provider module named <code>add</code> the "
           "resulting name will be <code>lcc_modify</code>");
    defvar("max_mails", 3, "Maximum mail addresses per account", TYPE_INT,
           "The default value for the maximum number of allowed mail aliases "
           "used when there's no 'maxMailAliases' attribute found in the user's "
           "LDAP entry.");
    defvar("mail_domains", "", "Mail domains for the users", TYPE_TEXT_FIELD,
           "A list (one per line) of mail domains where the users can create "
           "their mails");
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

    foreach(indices(my_tags), string idx) {
        my_tags[QUERY(provider_prefix) + idx] = my_tags[idx];
        m_delete(my_tags, idx);
    }
}

array(mapping) query_menus(object id)
{
    return my_menus;
}

string query_provides()
{
    return QUERY(provider_prefix) + "_modify";
}

mapping query_tag_callers()
{
    return my_tags;
}

private mixed do_start(object id, mapping data, string f)
{
    object sprov = PROVIDER(QUERY(provider_prefix) + "_screens");
    if (!sprov)
        return ([
            "lcc_error" : ERR_PROVIDER_ABSENT,
            "lcc_error_extra" : "No 'screens' provider"
        ]);
    
    mapping store = sprov->get_store(id, "modify");

    foreach(indices(data->user->ldap_data), string idx)
        if (!store[idx])
            store[idx] = data->user->ldap_data[idx][0];

    string screen = sprov->retrieve(id, "modify");

    if (screen && screen != "")
        return http_string_answer(screen);
    else
        return ([
            "lcc_error" : ERR_SCREEN_ABSENT,
            "lcc_error_extra" : "No 'modify' scren found"
        ]);
}

mixed handle_request(object id, mapping data, string f)
{
    function afun = do_start;
    
    if (id->variables && id->variables->todo) {
        switch(id->variables->todo) {
            case "chpass":
                break;

            case "modify":
                break;
        }
    }

    if (!afun)
        return http_string_answer("<strong>BOOM!!! No handler found!</strong>");

    return afun(id, data, f);
}

// tags

private multiset(string) input_attrs = (<
    "value", "size", "maxlength", "onfocus", "onblur",
    "onclick", "ondblclick", "onmousedown", "onmouseup",
    "onmouseover", "onmousemove", "onmouseout",
    "onkeypress", "onkeydown", "onkeyup", "id", "class",
    "lang", "title", "style", "alt", "align", "accept",
    "readonly", "disabled", "tabindex", "accesskey", "dir"
>);

private multiset(string) select_attrs = (<
    "id", "lang", "title", "style", "disabled", "dir",
    "tabindex", "onclick", "ondblclick", "onmousedown",
    "onmouseup", "onmouseover", "onmousemove", "onmouseout",
    "onkeypress", "onkeydown", "onkeyup"
>);

private multiset(string) option_attrs = (<
    "label", "id", "lang", "title", "style", "disabled", "dir",
    "tabindex", "onclick", "ondblclick", "onmousedown",
    "onmouseup", "onmouseover", "onmousemove", "onmouseout",
    "onkeypress", "onkeydown", "onkeyup"
>);

string tag_minput(string tag,
                  mapping args,
                  object id)
{
    if (!args || !args->field)
        return "<!-- invalid minput tag syntax - missing the 'field' attribute -->";
    
    string ret = "<input ";
    
    // first the standard attributes
    foreach(indices(args), string idx)
        if (input_attrs[lower_case(idx)])
            ret += sprintf("%s='%s' ", idx, args[idx]);

    // one extra here
    if (args->type)
        ret += "type='" + args->type + "' ";

    ret += "name='" + args->field + "'>";

    return ret;
}

string tag_mhidden(string tag,
                   mapping args,
                   object id)
{
    if (!args || !args->field)
        return "<!-- invalid minput tag syntax - missing the 'field' attribute -->";
    
    string ret = "<input ";
    
    // first the standard attributes
    foreach(indices(args), string idx)
        if (input_attrs[lower_case(idx)])
            ret += sprintf("%s='%s' ", idx, args[idx]);

    // one extra here
    ret += "type='hidden' name='" + args->field + "'>";

    return ret;
}

//
// Generate collection of several input boxes for the user to input/edit
// their mail addresses up to the maximum number of addresses (either set
// by default in the CIF or in the user's LDAP entry). In addition to the
// mail input addresses, a set of select controls for choosing the mail
// domain is presented to the user. The arguments syntax is a bit
// complicated but that's for reason. One might think that an output tag
// here would do well, but we are producing two controls for each mail
// entry - the text input box and the select control with a list of all
// allowable domains. Such kind of output couldn't be handled using an
// output tag, thus the syntax.
// The accepted attributes are:
//
//  - all HTML 4.x attributes for the 'text' input (prefixed with 't_')
//  - all HTML 4.x attributes for the 'select' input (prefixed with 's_')
//  - all HTML 4.x attributes for the 'option' tag (prefixed with 'o_')
//
string tag_mmail(string tag,
                 mapping args,
                 object id)
{
    if (!SDATA(id) && !SUSER(id))
        return "<!-- no session data! -->";
    
    string tattrs = "";
    string sattrs = "";
    string oattrs = "";

    // process the control attributes
    foreach(indices(args), string idx) {
        if (sizeof(idx) > 2) {
            switch(idx[0..1]) {
                case "t_":
                    if (input_attrs[idx[2..]])
                        tattrs += sprintf("%s='%s' ", idx[2..], args[idx]);
                    break;

                case "s_":
                    if (select_attrs[idx[2..]])
                        sattrs += sprintf("%s='%s' ", idx[2..], args[idx]);
                    break;

                case "o_":
                    if (option_attrs[idx[2..]])
                        oattrs += sprintf("%s='%s' ", idx[2..], args[idx]);
                    break;
            }
        }
    }

    array(string) mails = SUSER(id)->ldap_data->mail;
    int           max = SUSER(id)->ldap_data->maxMailAliases ? SUSER(id)->ldap_data->maxMailAliases : QUERY(max_mails);

    string ret = "";
    string dopts = "";
    
    foreach(mails, string mail) {
        array(string)   m = mail / "@";
        array(string) domains = (QUERY(mail_domains) / "\n") - ({}) - ({""});
        
        ret += sprintf("<input type='text' name='mail%02d' value='%s'> <strong>@</strong> "
                       "<select name='domain%02'>", max, m[0], max);
    }
}

// for debugging and your convenience
string tag_mdump(string tag,
                 mapping args,
                 object id)
{
    if (!SDATA(id) || !SUSER(id))
        return "<strong>No session data to dump</strong>";
    
    mapping ldap_data = SUSER(id)->ldap_data;
    string  ret = "<hr><table border='1'><tr><th>Attribute</th><th>Values</th></tr>";
    
    if (ldap_data) {
        foreach(sort(indices(ldap_data)), string idx) {
            foreach(ldap_data[idx], string d) {
                ret += sprintf("<tr><td>%s</td><td>%s</td></tr>",
                               idx, d);
            }
        }
    }

    ret += "</table><hr>";

    return ret;
}
