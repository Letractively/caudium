/*
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
 */

constant cvs_version = "$Id$";
constant thread_safe=0;

#include <module.h>
inherit "module";
inherit "caudiumlib";

import Stdio;
import Array;

constant module_type = MODULE_PROVIDER | MODULE_EXPERIMENTAL;
constant module_name = "Authentication Provider: LDAP";
constant module_doc  = "Provides access to user and group accounts "
	"located in LDAP directories."

constant module_unique = 0;


string query_provides()
{
  return "authentication";
}


/*
 * Globals
 */

object dir=0;

int default_uid() {

#if constant(geteuid)
  return(geteuid());
#else
  return(0);
#endif
}

/*
 * Object management and configuration variables definitions
 */

void create()
{
	// LDAP server:
        defvar ("CI_dir_server","localhost","LDAP server: Location",
                   TYPE_STRING, "This is LDAP URL for the LDAP server with "
                   "the authentication information. Example: ldap(s)://myldaphost");

        defvar ("CI_basename","","LDAP server: Search Base name",
                   TYPE_STRING, "The distinguished name to use as a base for queries."
		   "Typically, this would be an 'o' or 'ou' entry "
		   "local to the DSA which contains the user entries.");

        defvar ("CI_search_templ","(&(objectclass=person)(uid=%u%))","Defaults: Search template",
                   TYPE_STRING, "Template used by LDAP search operation"
		   " as filter."
		   "<b>%u%</b> : Will be replaced by entered username." );

        defvar ("CI_level","subtree","LDAP query depth",
                   TYPE_STRING_LIST, "Scope used by LDAP search operation."
                   "",
		({ "base", "onelevel", "subtree" }) );

        defvar ("CI_required_attr","","LDAP server: Required attribute",
                   TYPE_STRING|VAR_MORE,
		   "Which attribute must be present to successfully"
		   " authenticate user (optional). "
		   "<br />For example: memberOf",
		   0);

        defvar ("CI_required_value","","LDAP server: Required value",
                   TYPE_STRING|VAR_MORE,
		   "Which value must be in required attribute (optional)" 
		   "<br />For example: cn=KISS-PEOPLE",
		   0);

        defvar ("CI_dir_username","","LDAP server: Directory search username",
                   TYPE_STRING|VAR_MORE,
		   "This Distinguished Name (DN) will be used to authenticate "
                   "when connecting to the LDAP server to perform "
                   "non-authentication related searches. Refer to your LDAP "
                   "server documentation, this could be irrelevant. (optional)",
		   0);

        defvar ("CI_dir_pwd","", "LDAP server: Directory user's password",
		    TYPE_STRING|VAR_MORE,
		    "This is the password used to authenticate "
		    "connection to directory (optional).",
		   0);

	// Defaults:
        defvar ("CI_default_attrname_upw", "userPassword",
		   "Attributes: User password", TYPE_STRING,
                   "The mapping between passwd:password and LDAP.");

        defvar ("CI_default_uid",default_uid(),"Defaults: User ID", TYPE_INT,
                   "Some modules require an user ID to work correctly. This is the "
                   "user ID which will be returned to such requests if the information "
                   "is not supplied by the directory search.");

        defvar ("CI_default_attrname_uid", "uidNumber",
		   "Attributes: User ID", TYPE_STRING,
                   "The attribute containing the user's numeric ID.");

        defvar ("CI_default_gid", getegid(),
		"Defaults: Group ID", TYPE_INT,
                   "Default GID to be supplied when directory entry does not provide one.");

        defvar ("CI_default_attrname_gid", "gidNumber",
		   "Attributes: Group ID", TYPE_STRING,
                   "The attribute containing the user's primary GID.");

        defvar ("CI_default_gecos", "", "Defaults: Gecos", TYPE_STRING,
                   "The default Full NAme (Gecos).");

        defvar ("CI_default_attrname_gecos", "gecos",
		   "Attribute: Full Name", TYPE_STRING,
                   "The attribute containing the user Full Name.");

        defvar ("CI_default_home","/", "Defaults: Home Directory", TYPE_DIR,
                   "It is possible to specify an user's home "
                   "directory. This is used if it's not provided.");

        defvar ("CI_default_attrname_homedir", "homeDirectory",
		   "Attributes: Home Directory", TYPE_STRING,
                   "The attribute containing the user Home Directory.");

        defvar ("CI_default_shell","/bin/false", "Defaults: Shell", TYPE_STRING,
                   "The shell name for entries without a shell.");

        defvar ("CI_default_attrname_shell", "loginShell",
		   "Attributes: Login Shell", TYPE_STRING,
                   "The attribute containing the user Login Shell.");

        defvar ("CI_default_addname",0,"Defaults: Username add",TYPE_FLAG,
                   "Setting this will add username to path to default "
                   "directory, when the home directory is not provided.");

}


void close_dir() {
  dir->unbind();
  dir=0;
  DEBUGLOG("closing the directory");
  return;
}


object open_dir(string u, string p) {
    mixed err;
    string binddn, bindpwd;

    dir_accesses++; //I count accesses here, since this is called before each

    if(!access_mode_is_guest_or_roaming()) { // access type is "guest"/"roam."
	binddn = QUERY(CI_dir_username);
	bindpwd = QUERY(CI_dir_pwd);
    } else {                      // access type is "user"
	binddn = replace(QUERY(CI_bind_templ), "%u%", u);
	if (sizeof(QUERY(CI_basename)))
	    binddn += ", " + QUERY(CI_basename);
	bindpwd = p;
    }

    err = catch {
	dir = Protocols.LDAP.client(QUERY(CI_dir_server));
	dir->bind(binddn, bindpwd);
    };
    if (arrayp(err)) {
	report_error ("LDAPauth: Couldn't open authentication directory!\n[Internal: "+err[0]+"]\n");
	if (objectp(dir)) {
	    report_error("LDAPauth: directory interface replies: "+dir->error_string()+"\n");
	    catch(dir->unbind());
	}
	else
	    report_error("LDAPauth: unknown reason\n");
	report_error ("LDAPauth: check the values in the configuration interface, and "
		"that the user\n\trunning the server has adequate permissions "
		"to the server\n");
	close_dir();
	return;
    }
    if(dir->error_code) {
	report_error ("LDAPauth: authentication error ["+dir->error_string+"]\n");
	close_dir();
	return;
    }
    switch(QUERY(CI_level)) {
	case "subtree": dir->set_scope(2); break;
	case "onelevel": dir->set_scope(1); break;
	case "base": dir->set_scope(0); break;
    }
    dir->set_basedn(QUERY(CI_basename));
    DEBUGLOG("directory successfully opened");
    if(QUERY(CI_close_dir) && (QUERY(CI_access_mode) != "user"))
	call_out(close_dir,QUERY(CI_timer));
}



/*
 * Statistics
 */

string status() {

    return ("<H2>Security info</H2>"
	   "Attempted authentications: "+att+"<BR>\n"
	   "Failed: "+(att-succ+nouser)+" ("+nouser+" because of wrong username)"
	   "<BR>\n"+
	   dir_accesses +" accesses to the directory were required.<BR>\n" +

	     "<p>"+
	     "<h3>Failure by host</h3>" +
	     Array.map(indices(failed), lambda(string s) {
	       return caudium->quick_ip_to_host(s) + ": "+failed[s]+"<br>\n";
	     }) * ""
	     //+ "<p>The database has "+ sizeof(users)+" entries"
#ifdef LOG_ALL
	     + "<p>"+
	     "<h3>Auth attempt by host</h3>" +
	     Array.map(indices(accesses), lambda(string s) {
	       return caudium->quick_ip_to_host(s) + ": "+accesses[s]->cnt+" ["+accesses[s]->name[0]+
		((sizeof(accesses[s]->name) > 1) ?
		  (Array.map(accesses[s]->name, lambda(string u) {
		    return (", "+u); }) * "") : "" ) + "]" +
		"<br>\n";
	     }) * ""
#endif
	   );

}


/*
 * Auth functions
 */

string get_attrval(mapping attrval, string attrname, string dflt) {

    return (zero_type(attrval[attrname]) ? dflt : attrval[attrname][0]);
}

array(string) userinfo (string u,mixed p) {
    array(string) dirinfo;
    object results;
    mixed err;
    mapping(string:array(string)) tmp, attrsav;

    DEBUGLOG ("userinfo ("+u+")");
    //DEBUGLOG (sprintf("DEB:%O\n",p));
    if (u == "A. Nonymous") {
      DEBUGLOG ("A. Nonymous pseudo user catched and filtered.");
      return 0;
    }

    open_dir(u, p);

    if (!dir) {
	report_error ("LDAPauth: Returning 'user unknown'.\n");
	return 0;
    }

    if(QUERY(CI_access_type) == "search") {
	string rpwd = "";

	err = catch(results=dir->search(replace(QUERY(CI_search_templ), "%u%", u)));
	if (err || !objectp(results) || !results->num_entries()) {
	    DEBUGLOG ("no entry in directory, returning unknown");
	    if(access_mode_is_guest_or_roaming() && objectp(dir)) {
		catch(dir->unbind());
		dir=0;
	    }
	    return 0;
	}
	tmp=results->fetch();
	//DEBUGLOG(sprintf("userinfo: got %O",tmp));
	if(zero_type(tmp[QUERY(CI_default_attrname_upw)]))
	      report_warning("LDAPuserauth: WARNING: entry doesn't have the '" + QUERY(CI_default_attrname_upw) + "' attribute !\n");
	 else
	     rpwd = tmp[QUERY(CI_default_attrname_upw)][0];
	/*
	if(!access_mode_is_guest()) {	// mode is 'guest'
	    if(zero_type(tmp[QUERY(CI_default_attrname_upw)]))
		report_warning("LDAPuserauth: WARNING: entry haven't '" + QUERY(CI_default_attrname_upw) + "' attribute !\n");
	    else
		rpwd = tmp[QUERY(CI_default_attrname_upw)][0];
	}
	*/
	if(!access_mode_is_user_or_roaming())	// mode is 'user'
	// this is use when no password suplied (for example fetching www.website.com/~user) 
	 rpwd = stringp(p) ? rpwd : "{x-hop}*";
	if(!access_mode_is_roaming()) {	// mode is 'roaming'
	  // OK, now we'll try to bind ...
	  string binddn = get_attrval(tmp, QUERY(CI_owner_attr), "");
	  DEBUGLOG (sprintf("LDAPauth: indirect DN: [%s]\n", binddn));
	  if(!sizeof(binddn)) {
	    DEBUGLOG ("no value for indirect attribute, returning unknown");
	    return 0;
	  }
	  err = catch (dir->bind(binddn, p));
	  if (arrayp(err)) {
	    report_error("LDAPauth: Couldn't open authentication directory!\n[Internal: "+err[0]+"]\n");
	    if (objectp(dir)) {
	      werror("LDAPauth: directory interface replies: "+dir->error_string()+"\n");
	      catch(dir->unbind());
	    } else
	      werror("LDAPauth: unknown reason\n");
	    werror ("LDAPauth: check the values in the configuration interface,"
		    " and that the user\n\trunning the server has adequate"
		    " permissions to the server\n");
	    dir=0;
	    return 0;
	  }
	  if(dir->error_code) {
	    werror ("LDAPauth: authentication error ["+dir->error_string+"]\n");
	    dir=0;
	    return 0;
	  }
	  dir->set_scope(0);
	  dir->set_basedn(binddn);
	  //err = catch(results=dir->search(replace(QUERY(CI_search_templ), "%u%", u)));
	  err = catch(results=dir->search("objectclass=*")); // FIXME: modify
							      // to conf. int!
	  if (err || !objectp(results) || !results->num_entries()) {
	    DEBUGLOG ("no entry in directory, returning unknown");
	    if(objectp(dir)) {
	      catch(dir->unbind());
	      dir=0;
	    }
	    return 0;
	  }
	  tmp=results->fetch();
	}
	dirinfo= ({
		u, 			//tmp->uid[0],
		rpwd,
		get_attrval(tmp, QUERY(CI_default_attrname_uid), QUERY(CI_default_uid)),
		get_attrval(tmp, QUERY(CI_default_attrname_gid), QUERY(CI_default_gid)),
		get_attrval(tmp, QUERY(CI_default_attrname_gecos), QUERY(CI_default_gecos)),
		QUERY(CI_default_addname) ? QUERY(CI_default_home)+u : get_attrval(tmp, QUERY(CI_default_attrname_homedir), ""),
		get_attrval(tmp, QUERY(CI_default_attrname_shell), QUERY(CI_default_shell)),
		sizeof(QUERY(CI_required_attr)) && !access_mode_is_user() && !zero_type(tmp[QUERY(CI_required_attr)]) ? mkmapping(({QUERY(CI_required_attr)}),tmp[QUERY(CI_required_attr)]) : 0
	});
    } else {
	// Compare method is unimplemented, yet
    }
    if(!access_mode_is_user()) { // Should be 'closedir' method?
      close_dir();
    }
    if(!access_mode_is_roaming()) { // We must rebind connection
      dir->bind(QUERY(CI_dir_username), QUERY(CI_dir_pwd));
    }

    if(zero_type(uids[(string)dirinfo[2]]))
	uids = uids + ([ dirinfo[2] : ({ dirinfo[0] }) ]);
    else
	uids[dirinfo[2]] = uids[dirinfo[2]] + ({dirinfo[0]});
#if 0
    if(zero_type(gids[(string)dirinfo[3]]))
	gids = ([ dirinfo[3]:({dirinfo[0]}) ]);
    else
	gids[dirinfo[3]] = gids[dirinfo[3]] + ({dirinfo[0]});
#endif // FIXME: hacked - returns gidname = uidname !!!

    //DEBUGLOG(sprintf("Result: %O",dirinfo)-"\n");
    return dirinfo;
}

array(string) userlist() {

    //if (QUERY(disable_userlist))
    return ({});
}

string user_from_uid (int u) 
{

    if(!zero_type(uids[(string)u]))
	return(uids[(string)u][0]);
    return 0;
}

#if LOG_ALL
int chk_name(string x, string y) {

    return(x == y);
}
#endif

array|int authenticate (string user, string password)
{
    array(string) dirinfo;
    mixed attr,value;
    mixed err;

    att++;

    dirinfo=userinfo(username, password);
    if (!dirinfo||!sizeof(dirinfo)) {
	DEBUGLOG ("password check failed");
	DEBUGLOG ("no such user");
	nouser++;
	return ({0,u,p});
    }
    pw = dirinfo[1];
    if(pw == "{x-hop}*")  // !!!! HACK
	pw = p;
    if(p != pw) {
	// Digests {CRYPT}, {SHA1} and {MD5}
	int pok = 0;
	if (sizeof(pw) > 6)
	    switch (upper_case(pw[..4])) {
		case "{SHA}" :
		    pok = (pw[5..] == MIME.encode_base64(Crypto.sha()->update(p)->digest()));
		    DEBUGLOG ("Trying SHA digest ...");
		    break;

		case "{MD5}" :
		    pok = (pw[5..] == MIME.encode_base64(Crypto.md5()->update(p)->digest()));
		    DEBUGLOG ("Trying MD5 digest ...");
		    break;

		case "{CRYP" :
		    if (sizeof(pw) > 7 && upper_case(pw[5..6]) == "T}") {
			pok = crypt(p,pw[7..]);
			DEBUGLOG ("Trying CRYPT digest ...");
		    }
		    break;
	    } // switch
	if (!pok) {
	    DEBUGLOG ("password check failed");
	    caudium->quick_ip_to_host(id->remoteaddr);
	    return ({0,u,p});
	}
    }

    if(!access_mode_is_user()) {
	// Check for the Atributes
	if(sizeof(QUERY(CI_required_attr))) {
	    attr=QUERY(CI_required_attr);
	    if (mappingp(dirinfo[7]) && dirinfo[7][attr]) {
		mixed d;
		d=dirinfo[7][attr];
		// werror("User "+u+" has attr "+attr+"\n");
		if(sizeof(QUERY(CI_required_value))) {
		    mixed temp;
		    int found=0;
		    value=QUERY(CI_required_value);
		    foreach(d, mixed temp) {
			// werror("Looking at "+temp+"\n");
			if (search(temp,value)!=-1)
			    found=1;
		    }
		    if (found) {
			// werror("User "+u+" has value "+value+"\n");
		    } else {
			werror("LDAPuserauth: User "+u+" has not value "+value+"\n");
			return ({0,u,p});
		    }
		}
	    } else {
		werror("LDAPuserauth: User "+u+" has no attr "+attr+"\n");
		return ({0,u,p});
	    }

	}
    } // if access_mode_is_user

    DEBUGLOG (u+" positively recognized");
    succ++;
    return 1;
}
