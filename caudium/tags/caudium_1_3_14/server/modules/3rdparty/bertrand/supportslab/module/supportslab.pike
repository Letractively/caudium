/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2003 The Caudium Group
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
 */
/*
 * $Id$
 */

/*
 * Authors:
 *  Bertrand LUPART <bertrand@caudium.net>
 */

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER|MODULE_EXPERIMENTAL;
constant module_name = "Supports lab";
constant cvs_version = "$Id$";
constant module_doc  = "Interactive tests of the supports database.\n <br>"
  "Add this module in a virtual server and the put the example file in it.";

//! method: mapping query_container_callers()
//!  Public containers handled by this module
mapping query_container_callers()
{
  return ([ "supportslab_form" : container_supportslab_form ]);
}

// TODO: put all the test, their explanation and the link to the test in
// another file. XML?
array graphical_tests = 
({ 
  ({
    "gecko",
    "is a gecko based browser",
    ""
   }),
  ({
    "gifinline",
    "diplay inline gif",
    "http://kotzpdweb.tripod.com/gifpage.html"
  }),
  ({
    "jpeginline",
    "diplay inline jpeg",
    ""
  }),
  ({
    "pnginline",
    "diplay inline png",
    "http://www.w3.org/Graphics/PNG/Inline-img.html"
  }),
  ({
    "pngalpha",
    "alpha layer in png graphics",
    "http://www.w3.org/Graphics/PNG/inline-alpha-table"
  }),
});

class entityscope
{
  inherit "scope";
  string name = "";

  mapping data = ([ ]);

  void create(string _name, mapping|void _data)
  {
    name = _name;
    data = _data;
  }

  int set(string var, string value, object id)
  {
    data[var] = value;
    return 1;
  }

  string get(string var, object id)
  {
    return data[var];
  }
}

string scope_callback(object parser, string scope, string name, object id, string|multiset scopes)
{
  return get_scope_var(name, scope, id);
}

//! method: void override_supports(string useragent, object id)
//!  Here's the trick: supports are recomputed given some arbitrary user agent
void override_supports(string useragent, object id)
{
  useragent = lower_case(useragent[..150]);
  // TODO: provide a way to reload the supports file
  multiset newsupports = caudium->find_supports(useragent);
  id->supports = newsupports;
}

//! container: supportslab_form
//!  Public container that will parse all the remaining
//! nestedtags:
//!  supportslab_useragent
//!  supportslab_submit
//! nestedcontainers:
//!  supportslab_tests
//!  supportslab_supports
string container_supportslab_form(string tagname, mapping args, string contents, object id, mapping defines)
{
  string out = "";
 
  // if a user_agent is specified, override the supports with this
  if(id->variables->user_agent && id->variables->user_agent!="")
    override_supports(id->variables->user_agent, id);
 
  mapping tags =
    ([
      "supportslab_useragent" : tag_supportslab_useragent,
      "supportslab_submit"    : tag_supportslab_submit,
    ]);

  mapping containers =
    ([
      "supportslab_tests"     : container_supportslab_tests,
      "supportslab_supports"  : container_supportslab_supports,
    ]);

  out += "<form name=\"supportslab_form\" method=\"get\" ";
  out == "action=\""+id->raw_url+"\">";
#if constant(parse_html)
  out += parse_html(contents, tags, containers, id);
#else
  out += spider.parse_html(contents, tags, containers, id);
#endif
  out += "</form>";

  return out;
}

//! tag: supportslab_useragent
//!  Input for setting user agent
//! parentcontainer: supportslab_form
string tag_supportslab_useragent(string tagname, mapping args, object id, mapping defines)
{
  string out = "";

  out = "<input type=\"text\" size=\"80\" name=\"user_agent\" ";

  if(id->variables->user_agent && id->variables->user_agent!="")
    out += "value=\""+id->variables->user_agent+"\"";
  else
    out += "value=\""+id->request_headers["user-agent"]+"\"";

  out += ">";
  
  return out;
}

//! tag: supportslab_submit
//!  Input for submitting the form
//! parentcontainer: supportslab_form
string tag_supportslab_submit(string tagname, mapping args, object id, mapping defines)
{
  return "<input type=\"submit\">";
}

//! container: supportslab_test
//!  Zone that will be appended to the page for each supports test known
//! nestedentities:
//!  &supportslab.test;     name of the support tested
//!  &supportslab.sentence; sentence explaining the test
//!  &supportslab.link;     url of a link for testing
//! parentcontainer: supportslab_form
string container_supportslab_tests(string tagname, mapping args, string contents, object id, mapping defines)
{
  string out = "";
  
  foreach(graphical_tests, array test)
  {
    mapping entities = ([
                         "test"     : test[0],
                         "sentence" : test[1],
                         "link"     : test[2],
                        ]);

    id->misc->scopes["supportslab"] = entityscope("supportslab",entities);
    out += parse_scopes(contents, scope_callback, id);
    id->misc->scopes["supportslab"] = 0;
  }

  return out;
}

//! container supportslab_supports
//!  Zone appended to the page for each feature supported by the user-agent
//! nestedtentities:
//!  &supportslab.support;
//! parentcontainer:
//!  supportslab_form
string container_supportslab_supports(string tagname, mapping args, string contents, object id, mapping defines)
{
  string out = "";
  
  foreach(sort((array)id->supports), string support)
  {
    // TODO: add sentence and link as well when all data test are better stored
    mapping entities = ([
                         "supports" : support
		       ]);
       
    id->misc->scopes["supportslab"] = entityscope("supportslab",entities);
    out += parse_scopes(contents, scope_callback, id);
    id->misc->scopes["supportslab"] = 0;
  }
  
  return out;
}
