#!/usr/bin/env pike
#!NO_MODULE
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

// Define there the SQL url for password database access

#define	PASSWDDB "mysql://user:passwd@localhost/passwd"

#include <sql.h>

object(Stdio.Readline) readline;

string readline_until_got (string query) {
	string retval;
	while (!retval || !sizeof(retval))
		retval=readline("(mandatory) "+query);
	return retval;
}

int main() {
	mapping data=([]);
	//object sql=Sql.sql("localhost","passwd");
	object sql=Sql.sql(PASSWDDB);
	mixed tmp,err;
	string query;
	data->username=readline_until_got("username: ");
	data->passwd=crypt(readline_until_got("password: "));
	data->uid=readline("(deprecated) user ID: ");
	data->gid=readline("(deprecated) group ID: ");
	data->homedir=readline("home directory: ");
	data->shell=readline("login shell: ");

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
}

