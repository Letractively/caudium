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
 * $Id$
 */
constant cvs_version = "$Id$";
constant thread_safe=1;

#include <config.h>
#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER;
constant module_name = "CIF - GDBM Authentication Module";
constant module_doc  = "CIF authentication module that stores data in a GDBM file";
constant module_unique = 1;

#define EPREFIX "CIF GDBM AUTH: "

void create()
{
    defvar("order", 0, "Authentication order", TYPE_INT,
           "All authentication plugins have their call order assigned. "
           "It can be used to create chains of authentication. Plugins with "
           "the same order will be queried in an unpredicted order.");

    defvar("dbfile", "", "Database file", TYPE_FILE,
           "Path to a file which will be used to store the authentication data. "
           "If the file doesn't exist, it will be created. ");

    defvar("dbfileowner", "", "Database file owner", TYPE_STRING,
           "uid:gid pair specifying the database file owner. If empty it will "
           "default to the user/group under which Caudium is running. You "
           "are encouraged to set it to some other user/group (but remember "
           "that in this case your Caudium must not drop the superuser "
           "privileges completely).");
}

void start(int num, object conf)
{
#if !constant(Gdbm.gdbm)
    throw(({EPREFIX + "Required module Gdbm.gdbm not found in your pike!",
            backtrace()}));
#endif

#if !constant(Crypto.sha) && !constant(Mhash.hash_sha1)
    throw(({EPREFIX + "this module requires Crypto.sha or Mhash.hash_sha to be present!",
            backtrace()}));
#endif
}

string query_provides()
{
    return "cif-auth-plugin";
}


//
// What we provide
//
int get_order()
{
    return QUERY(order);
}

string get_name()
{
    return "GDBM Authentication";
}

//
// Open (and create if doesn't exist) the database configured for this
// module.
//
private Gdbm.gdbm open_database()
{
    string dir = dirname(QUERY(dbfile));

    if (dir && dir == "")
        dir = "/"; // ouch, dangerous...

    if (!Stdio.is_dir(dir)) {
        if (!Stdio.mkdirhier(dir, 0711)) {
            report_error(EPREFIX + "Cannot create the database directory %s\n",
                         dir);
            return 0;
        }
    }

    array(string)   owner = QUERY(dbfileowner) / ":";

    if (sizeof(owner) != 2)
        owner = 0;
    
    int dochmod = 0;
    
    if (!Stdio.is_file(QUERY(dbfile)))
        dochmod = 1;

    object privs = 0;
    
    if (owner)
        privs = Privs(EPREFIX + "Opening the CIF GDBM database file");
    
    Gdbm.gdbm   db = Gdbm.gdbm(QUERY(dbfile), "rwc");

    if (db && dochmod) {
        if (owner) {
            array(int|string)                uid;
            array(int|string|array(string))  gid;

            uid = getpwnam(owner[0]);
            gid = getgrnam(owner[1]);

            if (!gid || !uid)
                report_error(EPREFIX + "Cannot get uid/gid info for %s:%s\n", @owner);
            else
                chown(QUERY(dbfile), uid[2], gid[2]);
        }
        
        chmod(QUERY(dbfile), 0600);
    }
    
    if (privs)
        destruct(privs);

    return db;
}

//
// After authentificating the user, this function is required to set the
// appropriate field in the session mapping:
//
//   loggedin   - != 0 if the user was successfully logged in
//
int authenticate_user(string user, string pass, object id, mapping session)
{
    Gdbm.gdbm db = open_database();

    if (!db) {
        report_error(EPREFIX + "Couldn't open the database\n");
        if (session) {
            session->username = 0;
            session->loggedin = 0;
        }
        return 0;
    }
    
    string up = db[user];
    string ep;

#if constant(Mhash.hash_sha1)
    ep = Mhash.hash_sha1(pass);
#else
    ep = Crypto.sha()->update(pass)->digest();
#endif

    if (up == ep)
        session->loggedin = 1;
    else
        session->loggedin = 0;

    db->close();

    return session->loggedin;
}

//
// This function stores the new username/password pair in the database. 
// The password is passed here in plain text.
//
// 0 is returned for failure, != 0 otherwise
//
int store_user(string username, string pass)
{
    Gdbm.gdbm db = open_database();

    if (!db) {
        report_error(EPREFIX + "Couldn't open the database\n");
        return 0;
    }

    string ep;

#if constant(Mhash.hash_sha1)
    ep = Mhash.hash_sha1(pass);
#else
    ep = Crypto.sha()->update(pass)->digest();
#endif
    
    mixed error = catch {
        db->store(username, ep);
    };

    db->close();

    if (error)
        return 0;

    return 1;
}

