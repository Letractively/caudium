#!/usr/bin/env pike
#!NO_MODULE
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

/* $Id$
 *
 * name = "SQL Add user";
 * doc = "Add a user to an SQL user-database.";
 */

/*
 * This program is (C) 1997 Francesco Chemolli <kinkie@kame.usr.dsi.unimi.it>
 */

#define DEFAULTSHELL	"/bin/sh"

#include <sql.h>

string readline_until_got (string query) {
	string retval;
	while (!retval || !sizeof(retval))
		retval=Stdio.Readline()->read("(mandatory) "+query);
	return retval;
}

void help() {
	write("Usage: sqladduser.pike [OPTIONS] sqlurl://...\n\n");
	write("Enter user and login information for SQL User Database\n");
	write("Options are :\n");
	write(" -c		not crypt the password\n");
	write(" -u		not ask for UID\n");
	write(" -g		not ask for GID\n");
	write(" -s		not ask for shell\n");
	write(" -h, --help	help\n\n");
	write("Database url format is :\n");
	write(" databasetype://user:password@host/database\n\n");
	write("with :\n");
	write(" databasetype	mysql, msql, postgres, odbc, oracle...\n");
	write(" user		user used to connect to the database\n");
	write(" password	password used to connect with user\n");
	write(" host		host to connect to\n");
	write(" database	database used\n"); 
}

int main(int argc, array argv) {
	mapping data=([]);
	int acrypt=1;		// crypt password
	int auid=1;		// ask for uid
	int agid=1;		// ask for gid
	int ashell=1;		// ask for shell
	string dburl="";	// Database URL
	string query;
	mixed tmp,err;
	object sql;		// SQL object

	if ((argc < 2) || (argc > 7)) {
		help();
		return 1;
	}
	foreach(argv, string flag) {
		switch(flag) {
			case "-c" : acrypt=0; break;
			case "-u" : auid=0; break;
			case "-g" : agid=0; break;
			case "-s" : ashell=0; break;
			case "-h" :
			case "--help" : help(); return 1; break;
		}
		if (sizeof(flag / "://") == 2) dburl = flag;
	}
	if (dburl == "") {
		write("Check database url please.\n");
		help();
		return 1;
	}
	write("Using "+dburl+" as database.\n");
	err = catch {
		sql =  Sql.sql(dburl);
	};
	if (err) {
		write("Cannot connect to the database.\n");
		return 1;
	}
	data->username=readline_until_got("username: ");
	if (acrypt)
		data->passwd=crypt(readline_until_got("password: "));
	else
		data->passwd=readline_until_got("password: ");
	if (auid)
		data->uid=Stdio.Readline()->read("(deprecated) user ID: ");
	else
		data->uid="";
	if (agid)
		data->gid=Stdio.Readline()->read("(deprecated) group ID: ");
	else
		data->gid="";
	data->homedir=Stdio.Readline()->read("home directory: ");
	if (ashell)
		data->shell=Stdio.Readline()->read("login shell: ");
	else	
		data->shell=DEFAULTSHELL;

	foreach(indices(data),tmp) {
		if (!sizeof(data[tmp]))
			data-=([tmp:0]);
	}

	if(data->uid)
		data->uid=(int)data->uid;
	if(data->gid)
		data->gid=(int)data->gid;

	query="insert into passwd (" + (indices(data)*",") +
		") values (";
	foreach (values(data),tmp) {
		if (stringp(tmp))
			query += sprintf ("'%s',",tmp);
		else
			query += tmp+",";
	}
	
	query=query[..sizeof(query)-2];
	query += ")";

	tmp=sql->query("select * from passwd where username = '"+data->username+"'");
	if (sizeof(tmp))
		sql->query("delete from passwd where username = '"+data->username+"'");

	err= catch {
		sql->query(query);
	};
	if (err) {
		write("SQL query error: "+sql->error()+"\n");
		write("query was: "+query+"\n");
		return 1;
	}
	return 0;
}

