/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
 * Thomas Bopp
 *
 * Portions created by the Initial Developer are Copyright (C)
 * Thomas Bopp & The Caudium Group. All Rights Reserved.
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

//! This is WebDav module for Caudium. Used to help WebDav support 
//! on Caudium.
//!
//! @note
//!  You can start Caudium with -DWEBDAV_DEBUG to help debugging Caudium

inherit "compatlib";

#define WEBDAV_DEBUG

#ifdef WEBDAV_DEBUG
#define DAV_WERR(s, args...) werror(s+"\n", args)
#else
#define DAV_WERR(s, args...) 
#endif

#define TYPE_DATE  (1<<16)
#define TYPE_DATE2 (1<<17)
#define TYPE_FSIZE (1<<18)
#define TYPE_EXEC  (1<<19)

//!
class Property {
  
  //!
  void create(string p) {
    prop = p;
    ns = 0;
  }
  
  //!
  void set_namespace(NameSpace n) {
    ns = n;
  }

  //!
  string describe_namespace() {
    if ( !objectp(ns) )
      return "";
    return ns->get_name();
  }
 
  //!
  void set_value(string v) { 
    value = v;
  }

  //!
  string get_value() {
    return value;
  }

  //!
  string get_name() {
    return prop;
  }

  //!
  string get_ns_name() {
    string xmlns = describe_namespace();
    if ( strlen(xmlns) > 0 )
      return xmlns + ":" + prop;
    return prop;
  }

  //!
  string _sprintf() {
    return "Property("+prop+","+describe_namespace()+")";
  }
  static string  prop;
  static string value;
  static NameSpace ns;
}


//!
class NameSpace {
  static array(Property) props;
  static string       name, id;

  //!
  string get_name() { 
    return name;
  }

  //!
  void create(string n) { 
    name = n;
    props = ({ });
  }

  //!
  void set_id(string i) {
    id = i;
  }

  //!
  string get_id() { 
    return id;
  }

  //!
  void add_prop(Property p) {
    props += ({ p });
    p->set_namespace(this_object());
  }

  //!
  Property get_prop(string name) {
    
    foreach(props, Property p) {
      if ( p->get_name() == name )
	return p;
    }
    return 0;
  }
}

//! Available namespaces
static mapping mNameSpaces;

//!
void create()
{
  mNameSpaces = ([ "" : NameSpace(""), ]);
}

//!
NameSpace add_namespace(string name, void|string id)
{
  if ( stringp(id) && (!stringp(name) || name == "") ) 
    error("Invalid namespace!");
  if ( mNameSpaces[name] ) 
    return 0;
  NameSpace n = NameSpace(name);
  mNameSpaces[n->get_name()] = n;
  n->set_id(id);
  mNameSpaces[id] = n;
  return n;
}

//!
NameSpace get_namespace(string name, void|string id)
{
  NameSpace n = mNameSpaces[name];
  return n;
}

//!
Property find_prop(string ns, string pn) 
{
  NameSpace n = get_namespace(ns);
  if ( objectp(n) ) {
    Property p = n->get_prop(pn);
    if ( !objectp(p) ) {
      p = Property(pn);
      n->add_prop(p);
    }
    return p;
  }
  return 0;
}
  

//!
class WebdavHandler {

    //! the stat file function should additionally send mime type
    function stat_file; 

    //!
    function get_directory;

    //!
    function set_property;

    //!
    function get_property;
}


static mapping properties = ([
    "getlastmodified":3|TYPE_DATE,
    "creationdate":2|TYPE_DATE,
    ]);

static array _props = ({"getcontenttype","resourcetype", "getcontentlength", "href"})+indices(properties);
			    
//!
array(string) get_dav_properties(array fstat)
{
    return _props;
}


//! Retrieve the properties of some file by calling the
//! config objects stat_file function.
//!  
//! @param file 
//!  The file to retrieve props
//! @param xmlbody
//!  The xmlbody of the request
//! @param fstat
//!  File stat information if previously available
//! @returns
//!  XML code of properties
string retrieve_props(string file, mapping xmlbody, array fstat, 
		      WebdavHandler h, mixed context) 
{
    string response = "";
    string unknown_props;
    string   known_props;
    array        __props;
    string      property;

    if ( !arrayp(fstat) ) {
	error("Failed to find file: " + file);
	return "";
    }

    if ( sizeof(fstat) < 8 ) {
	if ( fstat[1] < 0 )
	    fstat += ({ "httpd/unix-directory" });
	else
	    fstat += ({ "application/x-unknown-content-type" });
    }

    unknown_props = "";
    known_props = "";
    __props = get_dav_properties(fstat);

    mapping mprops = ([ ]);

    if ( !xmlbody->allprop ) {
	foreach(indices(xmlbody), Property p) {
	    string property = p->get_name();  
	    if ( property == "allprop" || property == "")
		continue;
	    if ( search(__props, property) == -1 ) {
	      mixed val = h->get_property(context, p);
	      if ( val != 0 ) {
		known_props += "<"+property+" xmlns=\""+
		  p->describe_namespace()+"\">"+val+"</"+property+">";
	      }
	      else
		unknown_props += "<i0:"+property+"/>\r\n";
	    }
	    else
	      mprops[p->get_name()] = 1;    
	}
    } 

    
    response += "<D:response"+
      (strlen(unknown_props) > 0 ? " xmlns:i0=\"DAV:\"":"") + ">\r\n";
    //" xmlns:lp0=\"DAV:\">\r\n";
    
    if ( fstat[1] < 0 && file[-1] != '/' ) file += "/";

    response += "<D:href>"+file+"</D:href>\r\n";
    
    if ( mprops->propname ) {
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
    response += "<D:prop xmlns:lp0=\"DAV:\">\r\n";

    if ( fstat[1] < 0 ) { // its a directory
	if ( mprops->resourcetype || xmlbody->allprop ) 
	    response+="<D:resourcetype><D:collection/></D:resourcetype>\r\n";
	if ( mprops->getcontentlength || xmlbody->allprop )
	    response += "<D:getcontentlength></D:getcontentlength>\r\n";
    }
    else { // normal file
	if ( mprops->resourcetype || xmlbody->allprop )
	    response += "<D:resourcetype/>\r\n";
	if ( mprops->getcontentlength || xmlbody->allprop )
	    response += "<D:getcontentlength>"+fstat[1]+
		"</D:getcontentlength>\r\n";
    }
    if ( mprops->getcontenttype || xmlbody->allprop )
	response+="<D:getcontenttype>"+fstat[7]+
	    "</D:getcontenttype>\r\n";
    
    foreach(indices(properties), string prop) {
	if ( mprops[prop] || xmlbody->allprop ) {
	    if ( properties[prop] & TYPE_DATE ) {
		response += "<lp0:"+prop+" xmlns:b="+
		    "\"urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/\""+
		    " b:dt=\"dateTime.rfc1123\">";
		response += http_date(fstat[properties[prop]&0xff]);
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
	    else if ( properties[prop] & TYPE_EXEC ) {
		//int stats = fstat[0][
	    }
	}
    }
    response += known_props;
    response+="</D:prop>\r\n";
    response+="<D:status>HTTP/1.1 200 OK</D:status>\r\n";
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

//! Retrieve the properties of a colletion - that is if depth
//! header is given the properties of the collection and the properties
//! of the objects within the collection are returned.
//!  
//! @param path 
//!  The path of the collection
//! @param xmlbody
//!  The xml request body
//! @returns
//!  The xml code of the properties
string retrieve_collection_props(string colpath, mapping xmlbody, WebdavHandler h, mixed context)
{
    string response = "";
    int                i;
    mapping       fstats;
    array      directory;


    int len,filelen;
    array     fstat;
    
    directory = h->get_directory(colpath);
    len = sizeof(directory);
    
    string path;
    fstats = ([ ]);
    
    for ( i = 0; i < len; i++) {
	DAV_WERR("stat_file("+colpath+"/"+directory[i]);
	if ( strlen(colpath) > 0 && colpath[-1] != '/' )
	    path = colpath + "/" + directory[i];
	else
	    path = colpath + directory[i];
	fstat = h->stat_file(path, this_object());
	if ( fstat[1] >= 0 )
	    response += retrieve_props(path, xmlbody, fstat, h, context);
	else
	    fstats[path] = fstat;
    }
    foreach(indices(fstats), string f) {
	string fname;

	if ( f[-1] != '/' ) 
	    fname = f + "/";
	else
	    fname = f;
	response += retrieve_props(fname, xmlbody, fstats[f], h, context);
    }
    return response;
}

//! Converts the XML structure into a mapping for prop requests
//!  
//! @param node
//!  Current XML Node
//! @param pname 
//!  The name of the previous (father) node
//! @returns
//!  A mapping
mapping convert_to_mapping(object node, void|string pname)
{
    string tname = node->get_tag_name();
    int                               t;
    string                      ns = "";
    NameSpace                    nspace;

    sscanf(tname, "%s:%s", ns, tname);
    nspace = get_namespace(ns);
    
    mapping m = ([ ]);
    if ( pname == "prop" || tname == "allprop" ) {
      mapping attributes = node->get_attributes();
      if ( mappingp(attributes) ) {
	if ( stringp(attributes->xmlns) ) {
	  DAV_WERR("Adding namespace: %s", attributes->xmlns);
	  add_namespace(attributes->xmlns);
	  nspace = get_namespace(attributes->xmlns);
	}
      }
      else {
	if ( sscanf(tname, "%s:%s", ns, tname) == 2 ) {
	  nspace = get_namespace(ns);
	}
	else
	  nspace = get_namespace("");
      }
      Property p = nspace->get_prop(tname);
      if ( !objectp(p ) ) {
	p = Property(tname);
	nspace->add_prop(p);
      }
      m[p] = nspace->get_name();
      p->set_value(node->get_text());
    }
    array(object) elements = node->get_children();
    foreach(elements, object n) {
        mapping attr = n->get_attributes();
	// create namespaces:
	if ( mappingp(attr) ) {
	  foreach( indices(attr), string attribute ) {
	    string ns;
	    if ( sscanf(attribute, "xmlns:%s", ns) ) {
	      add_namespace(attr[attribute], ns);
	    }
	  }
	}
	m += convert_to_mapping(n, tname);
    }
    return m;
}      

//! Parse body data and return a mapping.
//!   
//! @param data
//!  The data of the XML body.
//! @returns
//!  A mapping
mapping get_xmlbody_props(string data)
{
  mapping xmlData= ([ ]);
  object            node;

    if ( !stringp(data) || strlen(data) == 0 ) {
	xmlData = ([ "allprop":find_prop("", "allprop"), ]); 
	// empty BODY treated as allprop
    }
    else {
      node = Parser.XML.Tree.parse_input(data);
      xmlData = convert_to_mapping(node);
    }
    DAV_WERR("Props mapping:\n"+sprintf("%O", xmlData));
    return xmlData;
}

//!
array(object) get_xpath(object node, array(string) expr)
{
    array result = ({ });
    
    if ( expr[0] == "/" )
	throw( ({ "No / in front of xpath expresions", backtrace() }) );
    array childs = node->get_children();
    foreach(childs, object c) {
	string tname;
	tname = c->get_tag_name();
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

//!
mapping|string resolve_destination(string destination, string host)
{
    string dest_host;

    if ( sscanf(destination, "http://%s/%s", dest_host, destination) == 2 )
    {
	if ( dest_host != host ) 
	    return low_answer(502, "Bad Gateway");
	destination = "/" + destination;
    }
    return destination;
}


//!
mapping get_properties(object n)
{
    mapping result = ([ ]);
    foreach(n->get_children(), object c) {
	string tname = c->get_tag_name();
	if ( search(tname, "prop") >= 0 ) {
	    foreach (c->get_children(), object prop) {
		if ( prop->get_tag_name() == "" ) continue;
		// make sure no wide strings appear
		string xmlns = prop->get_attributes()->xmlns;
		if ( !stringp(xmlns) )
		  xmlns = "";
		NameSpace nspace = get_namespace(xmlns);
		if ( !objectp(nspace) )
		  nspace = add_namespace(xmlns);
		if ( !objectp(nspace) )
		  error("Namespace " + xmlns+
			" not found for property " + prop->get_tag_name());
		
		Property p = find_prop(xmlns, prop->get_tag_name());
		result[p] = xmlns;
		
		if ( String.width(prop->value_of_node()) == 8 ) 
		  p->set_value(prop->value_of_node());
		else
		  p->set_value(string_to_utf8(prop->value_of_node()));
	    }
	}
    }
    return result;
}

//!
mapping|void proppatch(string url, mapping request_headers, string data, WebdavHandler h, mixed context)
{
    mapping result, xmlData;
    object             node;
    array(object)     nodes;
    string         response;
    string host = request_headers->host;
    
    if ( !stringp(url) || strlen(url) == 0 )
	url = "/";
    
    response ="<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
    response+="<D:multistatus xmlns:D=\"DAV:\">\n";
    response+="<D:response>\n";
    
    array fstat = h->stat_file(url, this_object());
    response += "<D:href>http://"+host+url+"</D:href>\n";

    node = Parser.XML.Tree.parse_input(data);

    nodes = get_xpath(node, ({ "propertyupdate" }) );
    if ( sizeof(nodes) == 0 )
	error("Failed to parse webdav body.");
    mapping namespaces = nodes[0]->get_attributes();
    DAV_WERR("Namespaces:\n"+sprintf("%O", namespaces));
    array sets    = get_xpath(nodes[0], ({ "set" }));
    array updates = get_xpath(nodes[0], ({ "update" }));
    array removes = get_xpath(nodes[0], ({ "remove" }));

    object n;
    foreach(sets+updates, n) {
	mapping props = get_properties(n);
	foreach (indices(props), Property p) {
	    int patch;
	    string prop = p->get_name();
	    response += "<D:propstat>\n";
	    patch = h->set_property(context, p, namespaces);
	    response += "<D:prop><"+prop+"/></D:prop>\n";
	    response += "<D:status>HTTP/1.1 "+
		(patch ? " 200 OK" : " 403 Forbidden")+ "</D:status>\r\n";
	    response += "</D:propstat>\n";
	}
    }
    foreach(removes, n) {
	mapping props = get_properties(n);
	foreach (indices(props), Property p) {
	    int patch;
	    string prop = p->get_name();
	    response += "<D:propstat>\n";
	    p->set_value(0);
	    patch = h->set_property(context, p, namespaces);
	    response += "<D:prop><"+prop+"/></D:prop>\n";
	    response += "<D:status>HTTP/1.1 "+
		(patch ? " 200 OK" : " 403 Forbidden")+ "</D:status>\r\n";
	    response += "</D:propstat>\n";
	}
      
    }
	


    response+="</D:response>\n";
    response+="</D:multistatus>\n";
    DAV_WERR("RESPONSE="+response);
    result = low_answer(207, response);
    result["type"] = "text/xml; charset=\"utf-8\"";
    result["rettext"] = "207 Multi-Status";
    return result;
}

//!
mapping|void propfind(string raw_url,mapping request_headers,string data,WebdavHandler h, mixed context)
{
    mapping result, xmlData;
    object             node;
    string         response;

    
    mixed err = catch {
      xmlData = get_xmlbody_props(data);
    };
    if ( err != 0 ) {
      if ( sizeof(err) >= 2 )
	DAV_WERR("Error in get_xmlbody_props: %O\n%O", 
		 err[0], describe_backtrace(err[1]));
      return low_answer(400, "bad request");
    }
	
    response ="<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n";
    
    if ( !stringp(raw_url) || strlen(raw_url) == 0 )
	raw_url = "/";
    
    array fstat = h->stat_file(raw_url, this_object());
    
    if ( !stringp(request_headers->depth) )
	request_headers["depth"] = "infinity";
    
    if ( !arrayp(fstat) ) {
#if 0
	response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	response += "<D:response>\r\n";
	response += "<D:href>"+raw_url+"</D:href>\r\n";	
	response += "<D:status>HTTP/1.1 404 Not Found</D:status>\r\n";
	response += "</D:response\r\n";
	response += "</D:multistatus>\r\n";
#endif
	return low_answer(404,"");
    }
    else if ( fstat[1] < 0 ) {
	response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	if ( request_headers->depth != "0" ) 
	    response += retrieve_collection_props(raw_url, xmlData, h,context);
	response += retrieve_props(raw_url, xmlData, fstat, h, context);
	response += "</D:multistatus>\r\n";
    }
    else {
	response += "<D:multistatus xmlns:D=\"DAV:\">\r\n";
	response += retrieve_props(raw_url, xmlData, 
				   h->stat_file(raw_url), h, context);
	response += "</D:multistatus>\r\n";
    }
    DAV_WERR("Propfind reponse=\n%s", response);
    result = low_answer(207, response);
    result["rettext"] = "207 Multi-Status";
    result["type"] = "text/xml; charset=\"utf-8\"";
    return result;
}

//!
mapping low_answer(int code, string str)
{
    return ([ "error": code, "data": str, "extra_heads": ([ "DAV": "1", ]), ]);
}


