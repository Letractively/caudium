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

//
// Module setup
//
private int auto_add_recommended = 1;

//
// These are the policy settings. That means, the mapping below contains
// all objectClasses and/or attributes in them that must be found in every
// record being added to the LDAP database. Reasonable defaults for Unix
// systems are set below but the external code is welcome (and even
// encouraged) to replace/modify the set. The mapping structure is as
// follows:
//
//   index         - (string) name of the LDAP item [note: this is the
//                   mapping _index_ not a member named 'index']
//   objectClass   - (boolean) 0 - is an attribute, != 0 is an objectClass
//   required      - (boolean) 0 - not required, != 0 required
//   recommended   - (boolean) 1 - the item is recommended
//   default       - (string) default value of the item used when
//                   recommended == 1 _and_ the client code
//                   chose to let this module add recommended items
//                   automatically (the default behavior)
//
// The 'required' field is used if the client code choses to validate the
// input and the record having been just constructed. This module will not
// signal any errors, it will not throw exceptions - it will merely return
// a response mapping with the situation description to the client. The
// response mapping has the following structure:
//
//   name          - (string) name of the attribute in question
//   errorCode     - (int) the error code, one of:
//                        ERR_REQUIRED_MISSING
//                           attribute was missing and it is required
//
//                        ERR_DEFAULT_USED
//                           more a warning than an error. The attribute is
//                           recommended but was absent and the default
//                           value was used.
//   errorMesage   - (string) error message in English that corresponds to
//                   the above error code.
//

#define REQ_OBJECTCLASS(name) name : ([ "objectClass" : 1, "required" : 1 ])
#define RECOM_OBJECTCLASS(name) name : ([ "objectClass" : 1, "recommended" : 1 ])
#define REQ_ATTRIBUTE(name) name : ([ "objectClass" : 0, "required" : 1 ])
#define RECOM_ATTRIBUTE(name, def) name : ([ "objectClass" : 0, "recommended" : 1, "default" : def ])

private mapping(string:mapping(string:string|int)) policy = ([
    REQ_OBJECTCLASS("top"),
    REQ_OBJECTCLASS("posixAccount"),
    REQ_OBJECTCLASS("inetOrgPerson"),
    RECOM_OBJECTCLASS("shadowAccount"),
    REQ_ATTRIBUTE("uid"),
    REQ_ATTRIBUTE("uidNumber"),
    REQ_ATTRIBUTE("gidNumber"),
    REQ_ATTRIBUTE("cn"),
    REQ_ATTRIBUTE("homeDirectory"),
    RECOM_ATTRIBUTE("userPassword", ""),
    RECOM_ATTRIBUTE("loginShell", "/bin/sh"),
    RECOM_ATTRIBUTE("gecos", "User"),
    RECOM_ATTRIBUTE("user", "User")
]);

//
// Return the current policy mapping - user can modify it.
//
mapping(string:mapping(string:string|int)) get_policy()
{
    return policy;
}

//
// Set the policy to the passed mapping. No verification is done.
//
void set_policy(mapping(string:mapping(string:string|int)) npolicy)
{
    policy = npolicy;
}

