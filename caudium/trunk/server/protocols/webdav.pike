/*
 * webdav Protocol for Caudium Webserver (RFC 2518)
 * This is only an implementation for a filesystem.
 * Copyright (C) 2002 Thomas Bopp (astra@uni-paderborn.de)
 * based on webdav filesystem module for Roxen webserver by:
 * Copyright (C) 2001 Christoph Schmidt (fuzzel@uni-paderborn.de)
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
inherit "http";
inherit "caudiumlib";

import WebDAV;

#include <caudium.h>
#include <module.h>

#ifdef WEBDAV_DEBUG
#define DAV_WERR(s) roxen_perror((s)+"\n")
#else
#define DAV_WERR(s) 
#endif

static object __handler;


void create(void|object f, void|object c) 
{
  __handler = WebdavHandler();
  __handler->get_directory = 0;
  __handler->stat_file = 0;
  __handler->set_property = set_property;
  __handler->get_property = get_property;
  ::create(f, c);
}

array(object) get_xpath(object node, array(string) expr)
{
    array result = ({ });
    
    if ( expr[0] == "/" )
	throw( ({ "No / in front of xpath expresions", backtrace() }) );
    array childs = node->get_children();
    foreach(childs, object c) {
	string tname;
	tname = c->get_tag_name();
	DAV_WERR("TAG:"+tname);
	sscanf(tname, "%*s:%s", tname); // this xpath does not take care of ns
	
	if ( tname == expr[0] ) {
	    if ( sizeof(expr) == 1 )
		result += ({ c });
	    else
		result += get_xpath(c, expr[1..]);
	}
    }
    return result;
}

// mapping maps method -> function to call     
// http/1.1 commands are handled the normal way
// webdav commands are handled locally
static mapping mHandler = ([
    "GET": handle_http,
    "HEAD": handle_http,
    "POST": handle_http, 
    "DELETE": handle_http,
    "MV": handle_http,
    "PUT": handle_http,
    "CONNECT":handle_http,
    "TRACE": handle_http,
    "MKCOL": handle_mkcol,
    "COPY": handle_copy,
    "MOVE": handle_move,
    "PROPFIND": handle_propfind,
    "PROPPATCH": handle_proppatch,
    "OPTIONS": handle_options,
    ]);

void outp(string x)
{
    werror("TRACE_LEAVE("+x+")\n");
}

/**
 * Handle the normal http commands, but convert successfull results
 * 200 response, because some commands are aware of ftp and return
 * ftp responses.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void|mapping handle_http()
{
    mixed err;

    DAV_WERR("clientprot="+clientprot+ ", method="+method);
#ifdef WEBDAV_DEBUG
    misc->trace_leave = outp;
#endif
#ifdef MAGIC_ERROR
    handle_magic_error();
#endif
    if ( conf )
    {
	// handle the request the normal way,
	// but just check if the result is ok or not and
	// send back status=200
	// This is because filesystem modules might handle
	// ftp-commands and dont return a proper http status
	err = catch {
	    file = conf->handle_request(this_object());
	};
        if ( err != 0 )
	    internal_error( err );
	DAV_WERR("Result="+sprintf("%O", file));
	if ( mappingp(file) && file->error >= 200 && file->error < 200 )
	    file = Caudium.HTTP.low_answer(200, "");
    }
    else
	file = caudium->configuration_parse( this_object() );

    return file;
}

mapping handle_options()
{	
    mapping result = Caudium.HTTP.low_answer(200,"OK");
    result->extra_heads = ([ 
	"Allow": (indices(mHandler)*", "), "DAV":"1",
	"MS-Author-Via": "DAV", ]);
	
    return result;
}

static int move_and_rename(object obj, string name)
{
}

mapping|void handle_move()
{
    string destination = request_headers->destination;
    string overwrite   = request_headers->overwrite;

    if ( !stringp(overwrite) )
	overwrite = "T";
    misc->overwrite = overwrite;
    misc->destination = resolve_destination(destination,
					    request_headers->host);

    // create copy variables before calling filesystem module
    if ( mappingp(misc->destination) )
	return misc->destination;
    else if ( stringp(misc->destination) )
	misc["new-uri"] = misc->destination;
    DAV_WERR("Handling move:misc=\n"+sprintf("%O\n", misc));
    
    mapping res = handle_http();
    if ( mappingp(res) && res->error == 200 )
	return Caudium.HTTP.low_answer(201, "Created");
    return res;
}

mapping|void handle_mkcol()
{
    method = "MKDIR";
    mapping result =  handle_http();
    if ( mappingp(result) && (result->error == 200 || !result->error) )
	return Caudium.HTTP.low_answer(201, "Created");
    return result;
}

mapping|void handle_copy()
{
    string destination = request_headers->destination;
    string overwrite   = request_headers->overwrite;
    string dest_host;

    if ( !stringp(overwrite) )
	overwrite = "T";
    misc->overwrite = overwrite;
    misc->destination = resolve_destination(destination,
					    request_headers->host);
    if ( mappingp(misc->destination) )
	return misc->destination;

    mixed result =  handle_http();
    if ( mappingp(result) && result->error == 200 ) {
	return Caudium.HTTP.low_answer(201, "Created");
    }
    return result;
}

mixed get_property(mixed context, Property property)
{
}

int set_property(mixed context, Property property, mapping namespaces)
{
    return 1;
}


mapping|void handle_proppatch()
{
    if ( !realauth ) {
	send_result(Caudium.HTTP.auth_required("webdav"));
	return;
    }
    
    DAV_WERR("Proppatch:\n"+sprintf("%s\n%O\n", data, mkmapping(indices(this_object()), values(this_object()))));

    if ( !stringp(raw_url) || strlen(raw_url) == 0 )
	raw_url = "/";
    
    return proppatch(raw_url, request_headers, data, __handler, 0);

}

mapping|void handle_propfind()
{
    if ( !realauth ) {
	send_result(Caudium.HTTP.auth_required("webdav"));
	return;
    }
    return propfind(raw_url, request_headers, data, __handler, 0);
}

/**
 * First handle Webdav commands, then call the http handle_request() 
 * stuff.
 *  
 */      
void handle_request()
{
    mapping      xmlData;
    mapping|void  result;
    object          node;


    DAV_WERR("handle_request(method="+method+")....\n\n");
    DAV_WERR("data="+data);
    function func = mHandler[method];
    if ( functionp(func) )
        result = func();
    else
	internal_error(backtrace());

    if ( mappingp(result) ) {
	if ( !stringp(result->type) )
	    result["type"] = "text/xml; charset=\"utf-8\"";
	send_result(result);
    }
    else
	send_result();
}















