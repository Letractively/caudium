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
// Error constants
//
int ERR_REQUIRED_MISSING = 0x0001;
int ERR_DEFAULT_USED = 0x0002;
int ERR_NOT_IN_POLICY = 0x0003;

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
//   def           - (string) default value of the item used when
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
//   index          - (string) name of the attribute in question [note: this is the
//                    mapping _index_ not a member named 'index']
//   errorCode      - (int) the error code, one of:
//                        ERR_REQUIRED_MISSING
//                           attribute was missing and it is required
//
//                        ERR_DEFAULT_USED
//                           more a warning than an error. The attribute is
//                           recommended but was absent and the default
//                           value was used.
//                        ERR_NOT_IN_POLICY
//                           the item isn't found in the current policy
//   errorMesage    - (string) error message in English that corresponds to
//                    the above error code.
//

#define REQ_OBJECTCLASS(name) name : ([ "objectClass" : 1, "required" : 1 ])
#define RECOM_OBJECTCLASS(name) name : ([ "objectClass" : 1, "recommended" : 1 ])
#define REQ_ATTRIBUTE(name) name : ([ "objectClass" : 0, "required" : 1 ])
#define RECOM_ATTRIBUTE(name, def) name : ([ "objectClass" : 0, "recommended" : 1, "def" : def ])

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


//
// The new user mapping structure:
//
//    name      - (string) LDAP item name
//    value     - (array of strings) values for this item
//

//
// Verify the passed user structure. Note that by default the items that
// aren't found in the policy mapping are ignored. You can, however, tell
// this function to check for such items and report them as errors.
// If an int < 0 is returned it means that policy exists but the user record
// was empty - thus it fails the verification. 0 is returned on success.
// The user record is not modified at this stage.
//
mapping(string:mapping(string:string|int))|int verify(mapping(string:array(string)) user, int|void strict)
{
    mapping(string:mapping(string:string|int)) ret = ([]);
    multiset(string)  reqstuff = (<>); // missing required stuff
    multiset(string)  recomstuff = (<>); // missing recommended stuff
    multiset(string)  notinpolicy = (<>); // stuff not in the policy
    string            idx;
    
    if ((policy && sizeof(policy)) && (!user || !sizeof(user)))
        return -1;
    
    foreach(indices(policy), idx) {
        if (policy[idx]->required && !user[idx])
            reqstuff += (<idx>);
        else if (policy[idx]->recommended && !user[idx])
            recomstuff += (<idx>);
    }

    if (strict) {
        // Check the user record against the policy
        foreach(indices(user), idx) {
            if (!policy[idx])
                notinpolicy += (<idx>);
        }
    }

    // generate the reports
    if (strict) { // report items not in the policy
        foreach(indices(notinpolicy), idx)
            ret += ([ idx : ([ "errorCode" : ERR_NOT_IN_POLICY,
                               "errorMessage" : sprintf("Item '%s' not in the current policy",
                                                        idx) ]) ]);
    }
    
    // report missing required items
    foreach(indices(reqstuff), idx)
        ret += ([ idx : ([ "errorCode" : ERR_REQUIRED_MISSING,
                           "errorMessage" : sprintf("Required item '%s' missing",
                                                    idx) ]) ]);

    // report missing recommended items
    foreach(indices(recomstuff), idx)
        ret += ([ idx : ([ "errorCode" : ERR_DEFAULT_USED,
                           "errorMessage" : sprintf("Recommended item '%s' missing. Default value %O will be used'",
                                                    idx, policy[idx]->def ) ]) ]);

    if (!sizeof(ret))
        return 0;
    
    return ret;
}

