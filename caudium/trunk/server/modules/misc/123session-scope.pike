/*
 * 123 Session Module - Scope Extension
 * (c) Kai Voigt, k@123.org
 *
 * _very_ BETA version for Roxen 2.0
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
 * This module only works with Roxen 2.0 and requires the 123 Session
 * Module to be installed.
 *
 * TODO: This module needs comments, testing and review.
 */

string cvs_version = "$Id$";

inherit "module";
inherit "roxenlib";
#include <module.h>

constant module_type = MODULE_PARSER;
constant module_name = "123 Sessions - Scope Extension";
constant module_doc  =
#"Extends the 123 Session module with Scope functionality.";

void start(int num, Configuration conf) {
  query_tag_set()->prepare_context=set_entities;
}

class ScopeSession {
  inherit RXML.Scope;

  string|int `[] (string var, void|RXML.Context c, void|string scope) {
    string SessionID = c->id->misc->session_id;
    if (c->id->misc->session_variables[var]) {
      return c->id->misc->session_variables[var];
    } else {
      return "<!-- no such variable in scope '"+scope+"' -->";
    }
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope) {
    string SessionID = c->id->misc->session_id;
    c->id->misc->session_variables[var] = val;
  }
}

RXML.Scope scope_session=ScopeSession();

void set_entities(RXML.Context c) {
  c->extend_scope("session", scope_session);
}
