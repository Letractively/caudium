/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2001-2002 The Caudium Group
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
 *
 * The HumanVerify module and the accompanying code is 
 * Copyright © 2002 Davies, Inc
 *
 * This code is released under the LGPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   Chris Davies <mcd@daviesinc.com>
 */

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version   = "$Id$";
constant module_unique = 1;
constant thread_safe=1;
constant module_type = MODULE_PARSER|MODULE_FIRST;
constant module_name = "Human Verification";
constant module_doc  = #"This module allows you to insert a hidden field in a form, displays a &lt;gtext&gt; tag and performs input validation to make a reasonable assumption that the form was filled in by a human.
<p>
This module inspired by Altavista and many other sites that are using 
methods similar to this to prevent automated submissions.
<p>
Usage:<p>
&lt;body bgcolor=\"#ffffff\" text=\"#000000\"><br>
&lt;form method=\"post\"><br>
&lt;humanid fg=\"#000066\"><br>
&lt;input type=\"text\" name=\"humanver\"><br>
&lt;p><br>
&lt;input type=\"submit\"><br>
&lt;/form><br>
&lt;p><br>
&lt;formoutput><br>
Did this Verify? #verified#<br>
&lt;/formoutput><br>
&lt;/body>
<p>
The &lt;humanid&gt; tag passes any parameters to the &lt;gtext&gt; tag that is called
from this module.
<p>
The form value 'verified' returns either YES or NO if the verification was
successful.  There is a simple timestamp in the field value that makes sure 
the value was recently generated. 
<p>
The Random Local Value is a simple character replacement designed to add a 
some local randomness to the encoding that is done.  The string is cut in half
and the left side is replaced by the characters on the right side.  
<p>
All of the form field names can be changed in the configuration interface to
further confuse autosubmission programs.
";

void create()
{
  /* defvar()'s */
  defvar("humanid", 
         "humanid",
         "Name of form field that will contain the checksum number", TYPE_STRING,
         "This field is used to set the fieldname in the form that will contain the numeric checksum that will be recalculated and verified after character input.");
  defvar("humanver", 
         "humanver",
         "Name of form field that will contain the verified data", TYPE_STRING,
         "This field is used to set the fieldname in the form that will contain the text as keyed in by the person submitting the form");
  defvar("verified", 
         "verified",
         "Name of form field that will contain YES or NO indicating SUCCESS", TYPE_STRING,
         "This field is used to set the fieldname in the form results that will contain either YES for a successful validation or NO for an unsuccessful validation.");
  defvar("salt", 
         "ABCabc",
         "Insert a random local value here", TYPE_STRING,
         "This value is added so that the simple formula is not easily discovered");
  defvar("capital", "Leave as is", "Case Assignment", TYPE_STRING_LIST,
         "Leave case as is, Force Uppercase, Force Lowercase", 
         ({ "Leave as is", "Force Uppercase", "Force Lowercase" }));
  defvar("cache", 
         "1",
         "Cache Enable", TYPE_FLAG,
         "Recommended except in a cluster environment.  If Caching is not used, for example in a clustered environment, the expiration time logic is somewhat different.");
  defvar("cacheexpire", 
         "3600",
         "Cache Expiration in seconds", TYPE_STRING,
         "If you are using caching, you can specify the expire time for the cached entries",0,cache_is_not_enabled);
}

int cache_is_not_enabled() {
  return (QUERY(cache) != 1);
}

string tag_humanid(string t, mapping m, object id)
{
  array dbinfo;
  string rdm = (string)Crypto.randomness.really_random()->read(10);
  if (!(QUERY(cache)))
    rdm = (string)localtime(time())["wday"]+rdm;
  string rval = human_encrypt(rdm);
  rdm = MIME.encode_base64(rdm);

  if (QUERY(cache)) {
    dbinfo = ({ rval, rdm });
    cache_set("HumanVerify",rval,dbinfo,(int)QUERY(cacheexpire));
  }

  string out = "<input type=\"hidden\" name=\""+QUERY(humanid)+"\" value=\""+rdm+"\">";
  string gtextoptions = "";
  foreach (indices(m),string key) {
    gtextoptions += key + "=\"" + m[key] + "\" ";
  }
  out += "<gtext alt=\"" + rdm + "\" " + gtextoptions + ">" + rval + "</gtext>";
  return(out);
}

string human_encrypt (string rdm) {
  string salt = replace((string)QUERY(salt)," ","");
// set up salt with characters we are going to replace anyhow
// these characters could be confused with other characters, 
// i.e. 1 and l look similar enough to cause confusion
  array saltleft=({"+","/","=","O","0","1","l","I"}),
        saltright=({"","","","","","","",""});
  int offset = (int)sizeof(salt)/2;
  for (int loop=0;loop<offset;loop++) {
    saltleft += ({salt[loop..loop]});
    saltright += ({salt[(loop+offset)..(loop+offset)]});
  }
  string rtn_val = (replace(MIME.encode_base64(rdm), saltleft, saltright))[0..7];
  if (QUERY(capital) == "Force Uppercase")
    rtn_val = upper_case(rtn_val);
  if (QUERY(capital) == "Force Lowercase")
    rtn_val = lower_case(rtn_val);
  
  return(rtn_val);
}

mapping query_tag_callers()
{
  return ([ "humanid":tag_humanid, ]);
}

mixed first_try(object id)
{
  if (id->variables[QUERY(humanid)]) {
  string humanver = (string)id->variables[QUERY(humanver)];
  if (QUERY(capital) == "Force Uppercase")
    humanver = upper_case(humanver);
  if (QUERY(capital) == "Force Lowercase")
    humanver = lower_case(humanver);
  string rval = human_encrypt(MIME.decode_base64((string)id->variables[QUERY(humanid)]));
  id->variables[QUERY(verified)] = "NO";
    if (humanver == rval) {
      if (QUERY(cache)) {
        array dbinfo=cache_lookup("HumanVerify",humanver);
        if ( (dbinfo) && ((string)dbinfo[1] == (string)id->variables[QUERY(humanid)]) ) {
          id->variables[QUERY(verified)] = "YES";
          cache_remove("HumanVerify",humanver);
        }
      } else {
        if ((string)id->variables[QUERY(humanid)][0..0] == (string)localtime(time())["wday"]) 
          id->variables[QUERY(verified)] = "YES";
      } // if (QUERY(cache))
    } // if (humanver == rval)
  } // if (id->variables[QUERY(humanid)])
  return(0);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: humanid
//! This field is used to set the fieldname in the form that will contain the numeric checksum that will be recalculated and verified after character input.
//!  type: TYPE_STRING
//!  name: Name of form field that will contain the checksum number
//
//! defvar: humanver
//! This field is used to set the fieldname in the form that will contain the text as keyed in by the person submitting the form
//!  type: TYPE_STRING
//!  name: Name of form field that will contain the verified data
//
//! defvar: verified
//! This field is used to set the fieldname in the form results that will contain either YES for a successful validation or NO for an unsuccessful validation.
//!  type: TYPE_STRING
//!  name: Name of form field that will contain YES or NO indicating SUCCESS
//
//! defvar: salt
//! This value is added so that the simple formula is not easily discovered
//!  type: TYPE_STRING
//!  name: Insert a random local value here
//
//! defvar: capital
//! Leave case as is, Force Uppercase, Force Lowercase
//!  type: TYPE_STRING_LIST
//!  name: Case Assignment
//
//! defvar: cache
//! Recommended except in a cluster environment.  If Caching is not used, for example in a clustered environment, the expiration time logic is somewhat different.
//!  type: TYPE_FLAG
//!  name: Cache Enable
//
//! defvar: cacheexpire
//! If you are using caching, you can specify the expire time for the cached entries
//!  type: TYPE_STRING
//!  name: Cache Expiration in seconds
//
