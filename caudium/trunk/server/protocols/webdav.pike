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

#include <caudium.h>
#include <module.h>

static array(string) week = ({ "Mon", "Tue", "Wed","Thu","Fri","Sat", "Sun"});
static array(string) month = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
				"Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

#ifdef WEBDAV_DEBUG
#define DAV_WERR(s) roxen_perror((s)+"\n")
#else
#define DAV_WERR(s) 
#endif

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
string get_time(int t)
{
    mapping lt = localtime(t);
    lt->year += 1900;
    lt->mon++;
    return week[lt->wday-1]+", "+
	(lt->mday < 10 ? "0"+lt->mday :lt->mday)
	+" "+month[lt->mon-1]+" "+
	lt->year+" "+
	(lt->hour < 10 ? "0"+lt->hour:lt->hour) + ":"+
	(lt->min  < 10 ? "0"+lt->min: lt->min ) + ":"+
	(lt->sec  < 10 ? "0"+lt->sec: lt->sec ) + " GMT";    
}

#define TYPE_DATE  (1<<16)
#define TYPE_DATE2 (1<<17)
#define TYPE_FSIZE (1<<18)


static mapping properties = ([
    "getcontentlength": 1|TYPE_FSIZE,
    "getlastmodified":3|TYPE_DATE,
    "creationdate":2|TYPE_DATE,
    ]);

static array _props = ({"getcontenttype","resourcetype"})+indices(properties);
			    
array(string) get_dav_properties(array fstat)
{
    if ( fstat[1] < 0 )
	return _props - ({ "getcontentlength" });
    else
	return _props - ({ "getcontenttype" });
}

/**
 * Retrieve the properties of some file by calling the
 * config objects stat_file function.
 *  
 * @param string file - the file to retrieve props
 * @param mapping xmlbody - the xmlbody of the request
 * @param array|void fstat - file stat information if previously available
 * @return xml code of properties
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string retrieve_props(string file, mapping xmlbody, array|void fstat) 
{
    string response = "";
    string unknown_props;
    array        __props;
    string      property;

    if ( !arrayp(fstat) )
	fstat = conf->stat_file(file, this_object());

    if ( !arrayp(fstat) ) {
	DAV_WERR("Failed to find file: " + file);
	return "";
    }

    unknown_props = "";
    __props = get_dav_properties(fstat);
    
    if ( !xmlbody->allprop ) {
	foreach(indices(xmlbody), property ) {
	    if ( property == "allprop" || property == "")
		continue;
	    if ( search(__props, property) == -1 ) 
		unknown_props += "<i0:"+property+"/>\r\n";
	}
    }
    
    
    response += "<D:response"+
	(strlen(unknown_props) > 0 ? " xmlns:i0=\"DAV:\"":"") + 
 	"  xmlns:lp0=\"DAV:\">\r\n";
    
    if ( fstat[1] < 0 && file[-1] != '/' ) file += "/";

    response += "<D:href>"+file+"</D:href>\r\n";
    
    if ( xmlbody->propname ) {
	response += "<D:propstat>\r\n";	   
	// only the normal DAV namespace properties at this point
	response += "<D:prop>";
	foreach(__props, property) {
	    if ( fstat[1] < 0 )
	    response += "<"+property+"/>\r\n";
	}	
	response += "</D:prop>";
	response += "</D:propstat>\r\n";
    }


    response += "<D:propstat>\r\n";
    response += "<D:prop>\r\n";

    if ( fstat[1] < 0 ) { // its a directory
	if ( xmlbody->resourcetype || xmlbody->allprop ) 
	    response+="<D:resourcetype><D:collection/></D:resourcetype>\r\n";
	if ( xmlbody->getcontenttype || xmlbody->allprop )
	    response+="<D:getcontenttype>httpd/unix-directory"+
		"</D:getcontenttype>\r\n";
    }
    else { // normal file
	if ( xmlbody->resourcetype || xmlbody->allprop )
	    response += "<D:resourcetype/>\r\n";
    }
    foreach(indices(properties), string prop) {
	if ( xmlbody[prop] || xmlbody->allprop ) {
	    if ( properties[prop] & TYPE_DATE ) {
		response += "<lp0:"+prop+" xmlns:b="+
		    "\"urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/\""+
		    " b:dt=\"dateTime.rfc1123\">";
		response += get_time(fstat[properties[prop]&0xff]);
		response += "</lp0:"+prop+">\r\n";
	    }
	    else if ( properties[prop] & TYPE_FSIZE ) {
		int sz = fstat[(properties[prop]&0xff)];
		if ( sz >= 0 ) { 
		    response += "<lp0:"+prop+">";
		    response += sz;
		    response += "</lp0:"+prop+">\r\n";
		}
	    }
	}
    }
    response+="</D:prop>\r\n";
    response+="<D:status>HTTP/1.1 "+errors[200]+"</D:status>\r\n";
    response+="</D:propstat>\r\n";

    // props not found...
    if ( strlen(unknown_props) > 0 ) {
	response += "<D:propstat>\r\n";
	response += "<D:prop>\r\n";
	response += unknown_props;
	response += "</D:prop>\r\n";
	response += "<D:status>HTTP/1.1 404 Not Found</D:status>\r\n";
	response += "</D:propstat>\r\n";
    }

    response += "</D:response>\r\n";    
    return response;
}

/**
 * Retrieve the properties of a colletion - that is if depth
 * header is given the properties of the collection and the properties
 * of the objects within the collection are returned.
 *  
 * @param string path - the path of the collection
 * @param mapping xmlbody - the xml request body
 * @return the xml code of the properties
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
string
retrieve_collection_props(string colpath, mapping xmlbody)
{
    string response = "";
    int                i;
    mapping       fstats;


    DAV_WERR("Retrieving collection props:\n"+
	     sprintf("%O\nHeaders=%O\n", xmlbody, request_headers));

    array directory = conf->find_dir(colpath, this_object());
    string  lastmod;
    int len,filelen;
    array     fstat;
    
    if ( !arrayp(directory) )
	directory = ({ });
    else
	len = sizeof(directory);
    
    lastmod = get_time(_time(1));

    string path;
    fstats = ([ ]);
    
    for ( i = 0; i < len; i++) {
	DAV_WERR("stat_file("+path+"/"+directory[i]+"\n");
	if ( strlen(colpath) > 0 && colpath[-1] != '/' )
	    path = colpath + "/" + directory[i];
	else
	    path = colpath + directory[i];
	fstat = conf->stat_file(path, this_object());
	if ( fstat[1] >= 0 )
	    response += retrieve_props(path, xmlbody, fstat);
	else
	    fstats[path] = fstat;
    }
    foreach(indices(fstats), string f) {
	string fname;

	if ( f[-1] != '/' ) 
	    fname = f + "/";
	else
	    fname = f;
	response += retrieve_props(fname, xmlbody, fstats[f]);
    }
    return response;
}

/**
 * Converts the XML structure into a mapping for prop requests
 *  
 * @param object node - current XML Node
 * @param void|string pname - the name of the previous (father) node
 * @return mapping
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
mapping convert_to_mapping(object node, void|string pname)
{
    string tname = node->get_tag_name();
    int                               t;

    if ( (t=search(tname, ":")) >= 0 ) 
	tname = tname[t+1..]; // no namespace prefixes
    
    mapping m = ([ ]);
    if ( pname == "prop" ) {
	m[tname] = node->get_text();
    }
    array(object) elements = node->get_children();
    foreach(elements, object n) {
	m += convert_to_mapping(n, tname);
    }
    return m;
}      

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping get_xmlbody_props()
{
    mapping xmlData;
    object     node;

    if ( !stringp(data) || strlen(data) == 0 ) {
	xmlData = ([ "allprop":"", ]); // empty BODY treated as allprop
    }
    else {
	DAV_WERR("DATA="+data);
	mixed err = catch {
	    node = Parser.XML.Tree.parse_input(data);
	    xmlData = convert_to_mapping(node);
	};
	if ( err != 0 )
	    xmlData = ([ "allprop":"", ]); // buggy http ?
    }
    return xmlData;
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
    "LOCK": handle_lock,
    "UNLOCK": handle_unlock,
    ]);

/**
 * Handle the normal http commands
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 */
void|mapping handle_http()
{
    mixed err;

    DAV_WERR("clientprot="+clientprot);
    
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
      
	file = http_low_answer(200, "OK");
    }
    return file;
}

mapping handle_options()
{	
    mapping result = http_low_answer(200,"OK");
    result->extra_heads = ([ 
	"Allow": (indices(mHandler)*", "), "DAV":"1",
	"MS-Author-Via": "DAV", ]);
	
    return result;
}

mapping|void handle_move()
{
    // create copy variables before calling filesystem module
    if ( stringp(request_headers->destination) )
	misc["new-uri"] = request_headers->destination;
    mapping res = handle_http();
    if ( mappingp(res) )
	return http_low_answer(201, "Created");
    return 0;
}

mapping|void handle_mkcol()
{
    method = "MKDIR";
    mapping result =  handle_http();
    if ( mappingp(result) )
	return http_low_answer(201, "Created");
    return 0;
}

mapping|void handle_copy()
{
    string destination = request_headers->destination;
    string dest_host;

    if ( sscanf(destination, "http://%s/%s", dest_host, destination) == 2 )
    {
	if ( dest_host != host ) 
	    return http_low_answer(502, "Bad Gateway");
    }
    misc->destination = destination;
    mixed result =  handle_http();
    if ( mappingp(result) ) {
	return http_low_answer(201, "Created");
    }
    return result;
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping get_properties(object n)
{
    mapping result = ([ ]);
    foreach(n->get_children(), object c) {
	string tname = c->get_tag_name();
	if ( search(tname, "prop") >= 0 ) {
	    foreach (c->get_children(), object prop) {
		if ( prop->get_tag_name() == "" ) continue;
		result[prop->get_tag_name()] = prop->value_of_node();
	    }
	}
    }
    return result;
}

/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
int set_property(string prop, string value, mapping namespaces)
{
    string ns;
    if ( sscanf(prop, "%s:%s", ns, prop) == 2 ) {
	
    }
    return 1;
}


/**
 *
 *  
 * @param 
 * @return 
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
 * @see 
 */
mapping|void handle_proppatch()
{
    mapping result, xmlData;
    object             node;
    array(object)     nodes;
    string         response;
    
    if ( !realauth ) {
	send_result(http_auth_required("webdav"));
	return;
    }
    DAV_WERR("Proppatch:\n"+sprintf("%s\n%O\n", data, mkmapping(indices(this_object()), values(this_object()))));

    if ( !stringp(raw_url) || strlen(raw_url) == 0 )
	raw_url = "/";
    
    response ="<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
    response+="<D:multistatus xmlns:D=\"DAV:\">\n";
    response+="<D:response>\n";
    
    array fstat = conf->stat_file(raw_url, this_object());
    response += "<D:href>http://"+host+raw_url+"</D:href>\n";

    node = Parser.XML.Tree.parse_input(data);

    nodes = get_xpath(node, ({ "propertyupdate" }) );
    if ( sizeof(nodes) == 0 )
	internal_error(backtrace());
    mapping namespaces = nodes[0]->get_attributes();
    DAV_WERR("Namespaces:\n"+sprintf("%O", namespaces));
    array sets    = get_xpath(nodes[0], ({ "set" }));
    array updates = get_xpath(nodes[0], ({ "update" }));
    array removes = get_xpath(nodes[0], ({ "removes" }));

    object n;
    foreach(sets+updates, n) {
	mapping props = get_properties(n);
	foreach (indices(props), string prop) {
	    int patch;
	    response += "<D:propstat>\n";
	    patch = set_property(prop, props[prop], namespaces);
	    response += "<D:prop><"+prop+"/></D:prop>\n";
	    response += "<D:status>HTTP/1.1 "+
		(patch ? errors[200] : " 403 Forbidden")+ "</D:status>\r\n";
	    response += "</D:propstat>\n";
	}
	DAV_WERR("Properties:\n"+sprintf("%O", props));
    }
    foreach(removes, n) {
	DAV_WERR("REMOVE:\n");
    }
	


    response+="</D:response>\n";
    response+="</D:multistatus>\n";
    DAV_WERR("RESPONSE="+response);
    return http_low_answer(207, response);
}

mapping|void handle_propfind()
{
    mapping result, xmlData;
    object             node;
    string         response;

    if ( !realauth ) {
	send_result(http_auth_required("webdav"));
	return;
    }
    xmlData = get_xmlbody_props();
	
    response ="<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
    
    if ( !stringp(raw_url) || strlen(raw_url) == 0 )
	raw_url = "/";
    
    array fstat = conf->stat_file(raw_url, this_object());
    
    if ( !stringp(request_headers->depth) )
	request_headers["depth"] = "infinity";
    
    if ( !arrayp(fstat) ) {
	result = http_low_answer(404, "");
    }
    else {
	if ( fstat[1] < 0 ) {
	    response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	    if ( request_headers->depth != "0" )
		response += retrieve_collection_props(raw_url, xmlData);
	    response += retrieve_props(raw_url, xmlData, fstat);
	    response += "</D:multistatus>\r\n";
	}
	else {
	    response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	    response += retrieve_props(raw_url, xmlData);
	    response += "</D:multistatus>\r\n";
	}
	result = http_low_answer(207, response);
	result["rettext"] = "207 Multi-Status";
    }
    return result;
}

mapping|void handle_lock()
{
    mapping result, xmlData;
    object             node;
    string         response;
    
    // this fakes the LOCK method, 
    // because this is "only" a DAV class 1 server
    
    node = Parser.XML.Tree.parse_input(data);
    xmlData = convert_to_mapping(node);
    
    response ="<?xml version=\"1.0\" ?>\n";
    response+="<D:prop xmlns:D=\"DAV:\">\n";
    response+="<D:lockdiscovery>\n";
    response+="<D:activelock>\n";
    
    if (xmlData["lockscope"]) 
	response+="<D:lockscope><D:exclusive/></D:lockscope>\n";
    if (xmlData["locktype"])
    {
	response+="<D:locktype>";
	if (xmlData["write"]) response+="<D:write/>";
	if (xmlData["read"]) response+="<D:read/>";
	response+="</D:locktype>\n";
    }
    response+="<D:depth>Infinity</D:depth>\n";
    if (xmlData["owner"])
    {
	response+="<D:owner>\n";
	response+="<D:href>";
	response+="http://"+request_headers["host"]+raw_url;
	response+="</D:href>\n"; response+="</D:owner>\n";
    }
    response+="<D:timeout>Second-604800</D:timeout>\n";
    if (xmlData["locktoken"])
	response+="<D:locktoken/>\n";
    
    response+="</D:activelock>\n";
    response+="</D:lockdiscovery>\n";
    response+="</D:prop>\n";
    result = http_low_answer(200,response);
    return result;
}

mapping|void handle_unlock()
{
}



/**
 * First handle Webdav commands, then call the http handle_request() 
 * stuff.
 *  
 * @author <a href="mailto:astra@upb.de">Thomas Bopp</a>) 
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
	result["type"] = "text/xml; charset=\"utf-8\"";

	if ( stringp(result->data) ) {
	    object f = Stdio.File("/root/www/dav.log", "wct");
	    f->write(result->data);
	    f->close();
	}
	send_result(result);
    }
}













