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

//
//! module: Developer tag
//!  Defines the tag to show Caudium developer information
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//

//
//! tag: developer
//!   Shows info about Caudium developers:
//!
//!   <ul>
//!    <li>list of developers (&lt;developer list>)</li>
//!    <li>info about one developer (&lt;developer name="name">)</li>
//!    <li>birthdays of developers (&lt;developer birthday>)</li>
//!    <li>notifies if any developer has birthday today (&lt;developer birthday="notify">)</li>
//!  </ul>
//
//! attribute: [list]
//!  List all active Caudium developers.
//
//! attribute: [name = developer_name]
//!  Prints information about the named developer (if such exists). developer_name
//!  must be developer's login name as used in Caudium CVS.
//
//! attribute: [birthday [= 'notify']]
//!  List birthdays of all the active developers. If the optional notify value
//!  is assigned to this attribute, then the tag will check whether today is
//!  the birthday of any of the developers and, if so, display a suitable notification.
//

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER;
constant module_name = "Developers";
constant module_doc  = "This tag generates developer information";
constant module_unique = 1;

void start(int num, object configuration)
{}

// A temporary solution. Will be replaced by a query to a server to
// fetch the data. Maps a login name at Caudium CVS to array of
// data about the user. Layout of the array:
//
//  [0] - full name
//  [1] - contact e-mail
//  [2] - birthday in ISO format (text - YYYY-MM-DD)
//  [3] - country of origin
//
// All the array elements are optional. Every developer has to agree for
// publication of his data here.
//

//
// In alphabetical order, please :)
//
mapping(string:array) developers = ([
  //    "aleph1":({"Aleph One", "aleph1@caudium.net", "", ""}),
  //    "duerrj":({"Joseph Duerr", "duerrj@caudium.net", "", "USA"}),
  //    "eMBee":({"Martin Baehr", "mbaehr@caudium.net", "", "Austria"}),
  "grendel":({"Marek Habersack", "grendel@caudium.net", "1973-09-11.", "Poland"}),
  "james_tyson":({"James Tyson", "eugene@caudium.net", "1977-06-25", "New Zealand"}),
  "kvoigt":({"Kai Voigt","k@caudium.net", "", "Germany"}),
  "kiwi":({"Xavier Beaudouin", "kiwi@caudium.net", "1972-11-6", "France"}),
  "mikeharris":({"Mike A. Harris", "mikeharris@users.sourceforge.net", "", "Canada"}),
  "neotron":({"David Hedbor", "david@caudium.net", "1974-11-30", "Sweden"}),
  //    "nikram":({"Fred van Dijk", "fred@caudium.net", "", "Holland"}),
  "redax":({"Zsolt Varga", "redax@caudium.net", "1973-02-01", "Hungary"}),
  "underley":({"Daniel Podlejski", "underley@underley.eu.org", "1976-08-08", "Poland"}),
  "wilsonm":({"Matthew Wilson", "matthew@caudium.net", "1976-4-10", "USA"})
]);

static string print_developer(string dev, array devdata, int full)
{
    string   ret = "", info = "";
    
    ret = "<strong>" + dev + "</strong>";
    if (devdata[0] != "")
	info += "<em>" + devdata[0] + "</em> ";
    if (devdata[1] != "")
	info += "&lt;" + replace(devdata[1], ({"@"}), ({"<em> at </em>"})) + "&gt; ";

    if (full) {
	if (devdata[2] != "" || devdata[3] != "")
	    info += "(born ";
	if (devdata[2] != "")
	    info += "on <tt>" + devdata[2] + "</tt> ";
	if (devdata[3] != "")
	    info += "in <tt>" + devdata[3] + "</tt>\n";
	if (devdata[2] != "" || devdata[3] != "")
	    info += ")";
    }
    	
    ret += ": ";
    if (info == "")
	ret += "no data";
    
    return (ret + info);
}

static string birthday_text(array(string) dev, object cal)
{
    string      ret = "";
    
    if (dev[0] != "")
	ret += dev[0];
    else if (dev[1] != "")
	ret += dev[1];
    else
	ret += "Somebody";
    
    ret += "'s birthday today! It was on " + cal->dateofyear();
    
    if (dev[3])
	ret += " in " + dev[3];
	
    return ret;
}

static string birthday_notify()
{
    object cal;
    object today = Calendar.ISO.Day();
    
    string ret = "";
        
    foreach(indices(developers), string dev) {
	cal = Calendar.ISO.parse("%Y-%M-%D", developers[dev][2]);
	
	if (!cal)
	    continue;
	    
	if (cal->iso_name() == today->iso_name())
	    ret += birthday_text(developers[dev], cal);
    }
	
    return ret;
}

string tag_developer( string tag, 
                    mapping attr, 
		    string q, 
		    object request_id,
		    object file, 
		    mapping defines)
{
    string   ret = "";
    
    if (sizeof(attr) == 0)
	return "<!-- No arguments given to the 'developer' tag -->";
	
    if (attr->list) {
	ret += "<ul>\n";
	foreach(indices(developers), string dev)
	    ret += "<li>" + print_developer(dev, developers[dev], 0) + "</li>\n";
	ret += "</ul>\n";
    } else if (attr->name && attr->name != "") {
	if (developers[attr->name])
	    ret += print_developer(attr->name, developers[attr->name], 1);
    } else if (attr->birthday) {
	if (attr->birthday == "notify") {
	    ret += birthday_notify();
	} else {
	    ret += "<ul>\n";
	    foreach(indices(developers), string dev)
		if (developers[dev][2] != "")
		    ret += "<li><strong>" + dev + "</strong> <tt>" + developers[dev][2] + "</tt></li>";
	    ret += "</ul>\n";
	}
    }
	    
    return ret;
}

mapping query_tag_callers()
{
  return ([ "developer" : tag_developer ]);
}

