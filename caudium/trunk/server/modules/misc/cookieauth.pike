/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

/*
 * File licensing and authorship information block.
 *
 * Version: MPL 1.1/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 *
 * Karl Stevens <kstevens@accurate.ca>.
 *
 * Portions created by the Initial Developer are Copyright (C) Karl
 * Karl Stevens & The Caudium Group. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the LGPL, and not to allow others to use your version
 * of this file under the terms of the MPL, indicate your decision by
 * deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL or the LGPL.
 *
 * Significant Contributors to this file are:
 *
 */

/*
 * cookieauth.pike: Allows site designer to use forms and cookies
 *      to authenicate users, instead of htauth.  Once authenticated,
 *      the web designer can use the standard mechanisms to check user
 *      credentials (such as <if user=> or modules that check the id->auth
 *      mapping.)  Can be used to automatically replace htauth, by
 *      replacing any 401 responses with a form.  SecureFS v2 is supposed
 *      to have this ability, but it has been broken since Roxen v1.2, due
 *      to changes in the way the system determines if a call has been
 *      handled or not.  This module sets the auth-cookie via the filter()
 *      module type, after the page has been processed.
 */

#include <caudium.h>
#include <module.h>
//#include <process.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version="$Id$";
constant module_type= MODULE_FIST | MODULE_FILTER;
constant module_name= "Cookie Authentication Module";
constant module_doc = "Allow site designer to use forms and cookie to "
                      "authenticate users, instead of htauth.\n Once "
                      "authenticated, the web designer can use standard "
                      "mechanisms to check user credentials (such as &lt;if "
                      "user= .. &gt; or modules that check id-&gt;auth mapping"
                      ".). Can be used automatically replace htauth, by "
                      "replacing any 401 responses with a form. " 
                      "This module sets the cookie &quot;roxen_auth_cookie"
                      "&quot; (compatibility) and &quot;caudium_auth_cookie"
                      "&quot; from form variables &quot;cookie_user&quot; and "
                      "&quot;cookie_pass&quot;. This cookie will be used to "
                      "set the user credentials.";
constant module_unique=1;
constant thread_safe = 1;

void create() {
  defvar( "key", "CHANGE ME!", "Encryption Key", TYPE_STRING,
          "The cookie used for authentication is encrypted "
          "with RC4.  This text will be used as a key to encrypt the "
          "password.  Changing this will result in expiration of every auth "
          "cookie already issued." );
  defvar( "persist", 1, "Use Persistant Cookies", TYPE_FLAG,
          "If disabled, the cookie will expire when the client closes their "
          "browser." );
  defvar( "replace401", 0, "Replace 401 Auth-Required responses", TYPE_FLAG |VAR_MORE ,
          "Replace &quot;401 Authorization required&quot; responses "
          "with a form for authentication.  This will replace the standard "
          "authentication mechanism completely." );
  defvar( "authpage", "NONE", "Web page to use when replacing 401 responses.",
          TYPE_FILE |VAR_MORE,
          "This is the location (in the real file system) of the page to send "
          "to replace 401 responses.  It must be set.\n"
          "This page should contain a form container with no action, which must "
          "contain the variables &quot;cookie_user&quot; and "
          "&quotcookie_pass&quot;. " );
}

mixed first_try( object id ) {

  if(!id->auth ) {
    object n=Crypto.arcfour();
    n->set_encrypt_key(QUERY(key));

    // check to see if the form variables are present, set auth info if so
    if(id->variables->cookie_user && id->variables->cookie_pass) {
      id->auth=id->conf->auth_module->auth( ({ "Basic",
          sprintf("%s:%s", id->variables->cookie_user, id->variables->cookie_pass) })
               , id);
      if(id->auth[0]) {
        id->misc->cookie_auth=n->crypt(sprintf("%s:%s",
             id->variables->cookie_user, id->variables->cookie_pass));
      }
    } else {
    // otherwise set auth info from cookie.
      if(id->cookies->roxen_auth_cookie) {
        string authinfo=n->crypt(id->cookies->roxen_auth_cookie);
        if(authinfo)
          id->auth=id->conf->auth_module->auth( ({"Basic",
            authinfo }), id);
      }
    }
  }
  return 0;
}

mixed filter( mapping res, object id ) {

  if(res) {
    if(QUERY(replace401) && res->extra_heads["WWW-Authenticate"]) {
      array t=file_stat(QUERY(authpage));
      if(t && t[1]>0) {
        m_delete(id->misc,"cookie_auth");
        res=http_string_answer(Stdio.read_file(QUERY(authpage)));
      }
    }

    if(id->misc->cookie_auth) {
      mapping n=([]);
      if(res["extra_heads"]) {
        n+=res["extra_heads"];
        m_delete(res, "extra_heads");
        m_delete(id->misc, "moreheads");

        n+=(["Set-Cookie":
              sprintf("%s=%s; expires=%d", "roxen_auth_cookie",
                       http_encode_cookie(id->misc->cookie_auth),
                         QUERY(persist)?3600*(24*365*5):0 ) ]);
        res["extra_heads"]=n;
        id->misc->moreheads=n;
      }
    }
  }
  return res;
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: key
//! The cookie used for authentication is encrypted with RC4.  This text will be used as a key to encrypt the password.  Changing this will result in expiration of every auth cookie already issued.
//!  type: TYPE_STRING
//!  name: Encryption Key
//
//! defvar: persist
//! If disabled, the cookie will expire when the client closes their browser.
//!  type: TYPE_FLAG
//!  name: Use Persistant Cookies
//
//! defvar: replace401
//! Replace &quot;401 Authorization required&quot; responses with a form for authentication.  This will replace the standard authentication mechanism completely.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Replace 401 Auth-Required responses
//
//! defvar: authpage
//! This is the location (in the real file system) of the page to send to replace 401 responses.  It must be set.
//!This page should contain a form container with no action, which must contain the variables &quot;cookie_user&quot; and &quotcookie_pass&quot;. 
//!  type: TYPE_FILE|VAR_MORE
//!  name: Web page to use when replacing 401 responses.
//
