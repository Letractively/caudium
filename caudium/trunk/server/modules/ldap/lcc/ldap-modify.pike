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

//
// LDAP access funcs
//
private void insert_attr(string atype, string|array(string) value,
                         string op, mapping(string:array(string)) data)
{
    int do_op = 0, opval;
    
    data[atype] = ({});

    switch(op) {
        case "replace":
            opval = do_op = 2;
            break;
            
        case "modify":
            opval = 0;
            do_op = 1;
            break;
    }

    if (do_op)
        data[atype] += ({opval});

    if (stringp(value))
        data[atype] += ({value});
    else
        data[atype] += value;
}

private void add_attribute(string name, string|array(string) value, mapping(string:array(string)) data)
{
    insert_attr(name, value, "add", data);
}

private void replace_attribute(string name, string|array(string) value, mapping(string:array(string)) data)
{
    insert_attr(name, value, "replace", data);
}

private void add_class(string|array(string) name, mapping(string:array(string)) data)
{
    insert_attr("objectClass", name, "add", data);
}

private void replace_class(string name, mapping(string:array(string)) data)
{
    insert_attr("objectClass", name, "replace", data);
}

//
// Handlers
//
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

//
// replaces the LDAP attribute value with 'nval' if it differs from the
// previous contents. This method is used only for single-value
// attributes. If data differs, it gets added to the 'data' mapping for the
// LDAP replacement further on.
//
private void replace_if_differs(string name, array(string) entry,
                                string nval, mapping(string:array(string)) data)
{
    foreach(entry, string val)
        if (val == nval)
            return;

    entry[0] = nval;
    replace_attribute(name, nval, data);
}

//
// Searches the given attribute for values matching the given one and
// comparing them by the position in the array. If the original array
// doesn't contain the given index, new value is appended to it, otherwise
// value at this index in the original array is replaced.
// If the array is modified, a value > 0 is returned, 0 otherwise. This
// function is used for multi-value attributes.
//
private int replace_or_append(array(string) entry, string nval, int index)
{
    report_notice("Entry: %O\nnval: %s\nindex: %d\n",
                  entry, nval, index);
    
    if (sizeof(entry) <= index || index < 0) {
        entry += ({nval});
        return 1;
    }
    
    report_notice("Checking for replacements...\n");
    if (entry[index] != nval) {
        report_notice("Replacing '%s' with '%s' at position %d\n",
                      entry[index], nval, index);
        entry[index] = nval;
        return 1;
    }

    report_notice("Nothing's changed\n");
    return 0;
}

private mixed do_modify(object id, mapping data, string f)
{
    object sprov = PROVIDER(QUERY(provider_prefix) + "_screens");
    if (!sprov)
        return ([
            "lcc_error" : ERR_PROVIDER_ABSENT,
            "lcc_error_extra" : "No 'screens' provider"
        ]);

    // here we need to modify two storage areas - the ldap_data and the
    // screens store for the 'modify' screen
    sprov->store(id, "modify");
    sprov->store(id, "modified");

    mapping(string:array(string)) ldata = ([]);
    int                           mailchanged = 0;
    int                           max = SUSER(id)->ldap_data->maxMailAliases ? SUSER(id)->ldap_data->maxMailAliases : QUERY(max_mails);
    
    foreach(indices(id->variables), string idx) {
        if (sizeof(idx) > 4 && idx[0..3] == "mail") {
            string maddr = "";

            if (id->variables[idx] != "")
                maddr = id->variables[idx] + "@" + id->variables["domain" + idx[4..]];
            
            if (data->user->ldap_data && data->user->ldap_data->mail)
                mailchanged += replace_or_append(data->user->ldap_data->mail,
                                                 maddr, max - (int)(idx[4..]));
            continue;
        }

        if (idx == "userPassword") {
            if (id->variables->userPassword == "")
                continue;

            if (id->variables->userPassword != id->variables->userPasswordAgain)
                return ([
                    "lcc_error" : ERR_PASS_MISMATCH
                ]);

            //TODO: encryption stuff goes here
        }
        
        if (data->user->ldap_data && data->user->ldap_data[idx])
            replace_if_differs(idx, data->user->ldap_data[idx], id->variables[idx], ldata);
    }
    
    if (mailchanged)
        replace_attribute("mail", data->user->ldap_data->mail, ldata);
    
    object lccprov = PROVIDER(QUERY(provider_prefix) + "_ldap-center");
    object ldap = lccprov->get_ldap(id);
    
    if (!ldap) {
        // baaaaaaad
        return ([
            "lcc_error" : ERR_LDAP_CONN_MISSING
        ]);
    }

    string screen;
    
    if (sizeof(ldata)) {
        report_notice("modifying '%s' with data '%O'\n",
                      data->user->dn, ldata);
    
        int res = ldap->modify(data->user->dn, ldata);

        // TODO: handle the res == 50 situation specially here
        if (res != 0) {
            string errs = ldap->error_string(res);

            report_notice("Error string: %O\n", errs);
        
            return ([
                "lcc_error" : ERR_LDAP_MODIFY,
                "lcc_error_extra" : ldap->error_string(res)
            ]);
        }
    
         screen = sprov->retrieve(id, "modified");
    } else
        screen = sprov->retrieve(id, "modify");
    
    if (screen && screen != "")
        return http_string_answer(screen);
    else
        return ([
            "lcc_error" : ERR_SCREEN_ABSENT,
            "lcc_error_extra" : "No 'modified' scren found"
        ]);
}

private mixed do_suggestpass(object id, mapping data, string f)
{
    return http_string_answer("this window will suggest the password");
}

mixed handle_request(object id, mapping data, string f)
{
    if (id->variables && id->variables->todo) {
        switch(id->variables->todo) {
            case "chpass":
                return do_start(id, data, f);

            case "modify":
                return do_modify(id, data, f);

            case "suggestpass":
                return do_suggestpass(id, data, f);
                
            default:
                return do_start(id, data, f);
        }
    }

    return do_start(id, data, f);
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
    array(string) domains = (QUERY(mail_domains) / "\n") - ({}) - ({""});
    array(string) mdomains = ({});
    
    foreach(mails, string mail) {
        array(string) m = mail / "@";
        if (sizeof(m) != 2)
            continue;

        mdomains += ({m[1]});
    }
    domains |= mdomains;
    domains = Array.uniq(domains);
        
    foreach(mails, string mail) {
        array(string)   m = mail / "@";
        if (sizeof(m) != 2)
            continue;
        
        ret += sprintf("<input type='text' name='mail%02d' value='%s'> <strong>@</strong> "
                       "<select name='domain%02d'>\n", max, m[0], max);
        foreach(domains, string d) {
            if (d == m[1])
                ret += sprintf("<option selected='yes' value='%s' %s>%s</option>",
                               d, oattrs, d);
            else
                ret += sprintf("<option value='%s' %s>%s</option>",
                               d, oattrs, d);
        }
        ret += "</select><br />\n";
        max--;
    }

    while (max > 0) {
        ret += sprintf("<input type='text' name='mail%02d'> <strong>@</strong> "
                       "<select name='domain%02u'>\n", max, max);
        foreach(domains, string d) {
                ret += sprintf("<option value='%s' %s>%s</option>",
                               d, oattrs, d);
        }
        ret += "</select><br />\n";
        max--;
    }

    return ret;
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
