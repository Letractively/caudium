/*
 * 123 Session Module - Scope Extension
 * (c) Kai Voigt, k@123.org
 *
 * Session Entity support for Caudium. Based on the Roxen 2.x module.
 *
 * This module creates the "session" scope to include the content of
 * session variables into your RXML documents.  You can set a variable
 * by using the <set> tag.
 *
 * <set variable="session.myvar">
 *
 * This variable will then be available during the entire session and
 * can be included into the document by putting &session.myvar; anywhere.
 *
 * This module only works with Caudium and requires the 123 Session
 * Module to be installed.
 *
 * TODO: This module needs comments, testing and review.
 */

//! module: 123 Sessions - Scope Extension
//! 
//! Session Entity support for Caudium. Based on the Roxen 2.x module.
//!
//! <p>This module creates the "session" scope to include the content of
//! session variables into your RXML documents.  You can set a variable
//! by using the &lt;set /&gt; tag.</p>
//!
//! <p>&lt;set variable="session.myvar" /&gt;</p>
//!
//! <p>This variable will then be available during the entire session and
//! can be included into the document by putting &amp;session.myvar; anywhere.</p>
//!
//! cvs_version: $Id$
//! inherits: module
//! inherits: caudiumlib
string cvs_version = "$Id$";

#include <module.h>
#include <config.h>

inherit "module";
inherit "caudiumlib";

constant thread_safe=1;
constant module_type = MODULE_PARSER;
constant module_name = "123 Sessions - Scope Extension";
constant module_doc  =
"Extends the 123 Session module with Scope functionality.";
constant module_unique = 1;

//! entity_scope: session
//!  Allows for storage and retrieving of 123session variables using
//!  RXML. This scope contains no predefined entities.
class SessionScope {
  inherit "scope";
  constant name = "session";
  string|int get(string var, object id) {
    if (mappingp(id->misc->session_variables) &&
	id->misc->session_variables[var]) {
      /* Catch in case the value can't be (cast) to a string. */
      catch {
	return (string)id->misc->session_variables[var];
      };
    }
  }
  
  int set(string var, mixed val, object id) {
    if(mappingp(id->misc->session_variables)) {
      if(val)
	id->misc->session_variables[var] = val;
      else 
	m_delete(id->misc->session_variables, var);
      return 1;
    }
    return 0;
  }
}

array(object) query_scopes() {
  return ({ SessionScope() });
}

void start(int cnt, object conf) {
  /* We need 123session */
  module_dependencies(conf, ({ "123session" }));
}
