/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
constant module_name = "LDAP: Auth module for the Command Center";
constant module_doc  = "Module that manages LDAP authentication for the LCC. "
                       "In addition to authentication, this module sets up the connection for "
                       "the current LDAP session.<br />";

constant module_unique = 0;

private mapping tags = ([
    "_input_login" : tag_input_login,
    "_input_password" : tag_input_password,
    "_select_domain" : tag_select_domain
]);

int usedefdomain_not_set()
{
    return(!QUERY(user_usedefdomain));
}

int useother_not_set()
{
    return (QUERY(user_dntype) != "other");
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
           "the <code>mail</code> attribute or both of them simultanously. <br />"
           "Below is a short explanation of what choices the adminstrator has:<br />"
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
           "<li><strong><code>other</strong></code>. This allows the administrator to "
           "specify the filter to be used to search the directory. The <em>LDAP search filter</em>"
           " option description contains more information on this type of authentication.</li>"
           "</ul></blockquote>",
           ({ "any", "uid", "email", "both", "other"}));

    defvar("user_filter", "&((mail=%m)(uid=%u))", "User auth: LDAP search filter", TYPE_STRING,
           "This option is used when the <code>other</code> authentication scheme was "
           "selected as the value of the <em>DN type</em> option. The string here must be a "
           "valid LDAP filter string and you can use the following macros in it:<br /><blockquote><ul>"
           "<li><code>%m</code> - mail address as typed by the user in the login screen. If the user "
           "typed only the user name part, default domain will be appended (if enabled). "
           "Note that in case the default domain is used and the default domains list contains "
           "more than one entry, the first entry will be used as a value of this macro.</li>"
           "<li><code>%u</code> - user name as typed by the user.</li>"
           "<li><code>%d</code> - domain name from the user's mail address (or from the default "
           "domain, if enabled). "
           "Note that in case the default domain is used and the default domains list contains "
           "more than one entry, the first entry will be used as a value of this macro.</li>"
           "<li><code>%b</code> - base DN as specified in the LDAP options.</li>"
           "<li><code>%p</code> - DN prefix as specified in the LDAP options.</li>"
           "<ul></blockquote>", 0, useother_not_set);
    
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

    // Access control settings
    
    // LDAP
    defvar("ldap_basedn", "", "LDAP: base DN", TYPE_STRING,
           "Base DN (Distinguished Name) to be used in all the operations throughout "
           "the session in which this module was used to authenticate the users. ");

    defvar("ldap_dnprefix", "ou=People", "LDAP: DN prefix", TYPE_STRING,
           "String to be prepended to the base dn for every user DN generated in this module.");

    defvar("ldap_mailattr", "mail", "LDAP: mail attribute", TYPE_STRING,
           "Attribute to be used when matching user mail on searches. "
           "<font color='red'><strong>*** MUST NOT BE EMPTY ***</strong></font>");

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
    return QUERY(provider_prefix) + "_auth";
}

mapping query_tag_callers()
{
    return tags;
}

//
// Auth functions used by make_dn
//
private array(string) dn_any(object id, string username, string|void domain)
{
    array(string) ret = ({});
    string        pfx = QUERY(ldap_dnprefix);
    
    if (domain)
        ret += ({
            sprintf("%s=%s@%s,%s%s", QUERY(ldap_mailattr),
                    username, domain, (pfx ? pfx + "," : ""),
                    QUERY(ldap_basedn))
        });

    if (!domain || (domain && QUERY(user_uidfallback)))
        ret += ({
            sprintf("uid=%s,%s%s", username, (pfx ? pfx + "," : ""),
                    QUERY(ldap_basedn))
        });

    return ret;
}

private array(string) dn_uid(object id, string username, string|void domain)
{
    array(string) ret = ({});
    string        pfx = QUERY(ldap_dnprefix);

    ret += ({
        sprintf("uid=%s,%s%s", username, (pfx ? pfx + "," : ""),
                    QUERY(ldap_basedn))
    });

    return ret;
}

private array(string) dn_email(object id, string username, string|void domain)
{
    array(string)  ret = ({});
    string         pfx = QUERY(ldap_dnprefix);
    array(string)  dom = 0;
    
    if (!domain && QUERY(user_usedefdomain)) {
        // let's see what to do with the domain...
        array(string) dom = (QUERY(user_defdomains) / "\n") - ({}) - ({""});

        if (!sizeof(dom))
            dom = 0;
    } else if (domain)
        dom = ({domain});

    if (!dom)
        return ret;

    foreach(dom, string d)
        ret += ({
            sprintf("%s=%s@%s,%s%s", QUERY(ldap_mailattr),
                    username, d, (pfx ? pfx + "," : ""),
                    QUERY(ldap_basedn))
        });

    return ret;
}

private array(string) dn_both(object id, string username, string|void domain)
{
    array(string)  ret = ({});
    string         pfx = QUERY(ldap_dnprefix);
    array(string)  dom = 0;
    
    if (!domain && QUERY(user_usedefdomain)) {
        // let's see what to do with the domain...
        dom = (QUERY(user_defdomains) / "\n") - ({}) - ({""});

        if (!sizeof(dom))
            dom = 0;
    } else if (domain)
        dom = ({domain});

    if (!dom)
        return ret;

    foreach(dom, string d)
        ret += ({
            sprintf("uid=%s,%s=%s@%s,%s%s", username, QUERY(ldap_mailattr),
                    username, d, (pfx ? pfx + "," : ""),
                    QUERY(ldap_basedn))
        });

    return ret;
}

private array(string) dn_other(object id, string username, string|void domain)
{
    array(string)  ret;
    string         pfx = QUERY(ldap_dnprefix);
    array(string)  to = ({"", "", "", "", ""});

    to[0] = username; // %u
    if (domain)
        to[1] = domain; // %d
    else if (QUERY(user_usedefdomain)) {
        array(string) dom = (QUERY(user_defdomains) / "\n") - ({}) - ({""});

        if (sizeof(dom))
            to[1] = dom[0];
    }

    if (domain)
        to[2] = username + "@" + domain; // %m
    else if (QUERY(user_usedefdomain)) {
        array(string) dom = (QUERY(user_defdomains) / "\n") - ({}) - ({""});

        if (sizeof(dom))
            to[2] = username + "@" + dom[0];
    }

    if (pfx)
        to[3] = pfx; // %p

    if (QUERY(ldap_basedn))
        to[4] = QUERY(ldap_basedn); // %b
    
    ret += ({
        replace(QUERY(user_filter), ({"%u", "%d", "%m", "%b"}), to)
    });

    return ret;
}

//
// Making the DN depends upon the settings in the CIF, see create() above
// for description of the modes we support
//
private array(string) make_dn(object id, string login)
{
    string username, domain;
    
    // First let's try to find out what the user typed in
    int tmp = search(login, "@");
    
    if (tmp > -1) {
        // an email
        array(string) l = login / "@";
        
        username = l[0];
        domain = l[1];
    } else {
        // username only, most probably
        username = login;

        // see whether we have some domain selected by the user in the form
        string sd = QUERY(provider_prefix) + "_domain";
        if (id->variables && id->variables[sd])
            domain = id->variables[sd];
        else
            domain = 0;
    }

    //
    // Now that we know what we have, let's see what we are supposed to do
    // with it. This depends on the mode.
    //
    array(string) ret = 0;
    
    switch(QUERY(user_dntype)) {
        case "any":
            ret = dn_any(id, username, domain);
            break;

        case "uid":
            ret = dn_uid(id, username, domain);
            break;

        case "email":
            ret = dn_email(id, username, domain);
            break;

        case "both":
            ret = dn_both(id, username, domain);
            break;

        case "other":
            ret = dn_other(id, username, domain);
            break;

        default:
            report_warning("Unknown DN type '%s' in ldap-auth\n", QUERY(user_dntype));
            return 0;
    }

    return ret;
}

mapping read_user_info(object id, mapping user, object ldap)
{}

mapping auth(object id, mapping user, object ldap)
{
    mixed    error;
    int      result = 0;
    string   lcc_login, lcc_password;

    lcc_login = QUERY(provider_prefix) + "_login";
    lcc_password = QUERY(provider_prefix) + "_password";
    
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
    } else if (id->variables && id->variables[lcc_login]) {
        user->name = id->variables[lcc_login];
        user->dn = make_dn(id, user->name);
        user->password = id->variables[lcc_password];
    }

    ldap->set_basedn(QUERY(ldap_basedn));
    
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

    foreach(user->dn, string dn) {
        error = catch {
            result = ldap->bind(dn, user->password, QUERY(ldap_protocol));
        };

        if (!result) {
            user->dn = dn;
            break; // success
        }
    }
    
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

    // Try reading the user info. If the returned value doesn't contain the
    // userPassword entry, it is assumed that the user hasn't been
    // authenticated correctly.
    object res = 0;
    error = catch {
        string suffix = "," + QUERY(ldap_dnprefix) + "," + QUERY(ldap_basedn);
        res = ldap->search(user->dn - suffix);
    };

    if (error) {
        mapping ret = ([]);
        if (arrayp(error)) {
            ret->lcc_error = ERR_INVALID_USER;
            ret->lcc_error_extra = error[0];
        } else {
            ret->lcc_error = ERR_INVALID_USER;
        }
        ldap->unbind();
        
        return ret;
    } else if (!res || !res->num_entries()) {
        ldap->unbind();
        return ([
            "lcc_error" : ERR_INVALID_USER
        ]);
    }

    mixed rdata = res->fetch();    
    if (!rdata->userPassword) {
        ldap->unbind();
        return ([
            "lcc_error" : ERR_INVALID_USER
        ]);
    }

    if (!rdata->preferredLanguage)
        rdata->preferredLanguage = ({"en"}); // TODO: use the data from the
                                             // screens module here!
    
    user->ldap_data = rdata;
    
    return 0; // 0 == everything's fine
}

// tags

//
// INPUT attributes (HTML 4.01)
//
private multiset(string) input_attrs = (<
    "value", "size", "maxlength", "onfocus", "onblur",
    "onclick", "ondblclick", "onmousedown", "onmouseup",
    "onmouseover", "onmousemove", "onmouseout",
    "onkeypress", "onkeydown", "onkeyup", "id", "class",
    "lang", "title", "style", "alt", "align", "accept",
    "readonly", "disabled", "tabindex", "accesskey", "dir"
>);

private string make_input_tag(string ttype, string tag, mapping args, object id)
{
    string ret = "<input type='" + ttype + "' name='" + QUERY(provider_prefix) + tag + "' ";
    
    // first the standard attributes
    foreach(indices(args), string idx)
        if (input_attrs[lower_case(idx)])
            ret += sprintf("%s='%s' ", idx, args[idx]);

    ret += ">";

    return ret;
}

//
// Creates a 'text' type input control with the name set to the one
// expected by this instance of the module. All the other standard HTML 4.x
// attributes are preserved by this tag.
//
string tag_input_login(string tag,
                       mapping args,
                       object id)
{
    return make_input_tag("text", "_login", args, id);
}

//
// Creates a 'password' type input control with the name set to the one
// expected by this instance of the module. All the other standard HTML 4.x
// attributes are preserved by this tag.
//
string tag_input_password(string tag,
                          mapping args,
                          object id)
{
    return make_input_tag("password", "_password", args, id);
}

//
// Creates a select control with a list of default domains for the user to
// choose from. If the user_defdomains is empty or contains just one
// element, no output is made. The tag enforces the single selection
// control (the 'multiple' attribute is ignored)
//
private multiset(string) select_attrs = (<
    "size", "id", "class", "lang", "dir", "title",
    "style", "disabled", "tabindex", "onfocus", "onblur",
    "onclick", "ondblclick", "onmousedown", "onmouseup",
    "onmouseover", "onmousemove", "onmouseout",
    "onkeypress", "onkeydown", "onkeyup"
>);

string tag_select_domain(string tag,
                         mapping args,
                         object id)
{
    array(string) dom = (QUERY(user_defdomains) / "\n") - ({}) - ({""});
    
    if (!sizeof(dom))
        return "";

    string ret = "<select name='" + QUERY(provider_prefix) + "_domain' ";
        
    // first the standard attributes
    foreach(indices(args), string idx)
        if (select_attrs[lower_case(idx)])
            ret += sprintf("%s='%s' ", idx, args[idx]);
    ret += ">\n";
    
    // output the options (domains)
    int dosel = 1;
    foreach(dom, string d)
        if (dosel) {
            dosel = 0;
            ret += sprintf("<option selected='1' label='%s' value='%s'>%s</option>\n",
                           d, d, d);
        } else {
            ret += sprintf("<option label='%s' value='%s'>%s</option>\n",
                           d, d, d);
        }
    
    ret += "</select>";

    return ret;
}
