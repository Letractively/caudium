/*
 * Copyright © 1999 Martin Baehr
 * Copyright © 2001 Karl Pitrich
 * Copyright © 2004 The Caudium Group
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
 *  CHANGELOG:
 *     - Rewrote most of the code and use Protocols.XMLRPC (David Gourdelier,  2004-03-20)
 *     -fixed array type handling (pit, 2001-03-30)
 *     -class framework (pit, 2001-03-30)
 */

constant cvs_version="$Id$";

#include <module.h>
#include <stdio.h>
inherit "module";
inherit "caudiumlib";

static private string doc()
{
    return "This is a demo module for the XML-RPC protocol.\n";
}

array register_module()
{
  return ({ MODULE_PROVIDER, "XML-RPC-Provider: Demo.",
            ""+doc()
            ,0,1 });
}

string|array(string) query_provides() 
{
	return "XML-RPC";
}

mapping(string:function) query_rpc_functions()
{
	return ([ "test_a" : test_a,
				 "test_m" : test_m,
				 "test_i" : test_i,
				 "test_s" : test_s 
	]);
}

mapping(string:string) query_rpc_functions_help()
{
	return ([ "test_a": "Take no arguments and return a constant array",
		  "test_m": "Take no arguemnts and return a mapping that maps the virtual servers this server provides to their urls",
		  "test_i": "Given an int, add one to it",
		  "test_s": "Given a string, add the string \" ok.\" at the end of it" ]);
}
array test_a(void|int val) {
	array ret=({"aaa", "bbb", "ccc", "ddd"});

	return(ret);
}

mapping test_m(void|int val) {
	mapping my_urls=([]); 
	foreach(caudium->configurations, mixed this) {
		if(strlen(this->query("MyWorldLocation"))) {
			my_urls+=([ this->name : this->query("MyWorldLocation") ]);
		}
	}
	return(my_urls);
}

int test_i(void|int val)	{
	return val+1;
}

string test_s(void|string s) {
	return s+" ok.\n";
}

