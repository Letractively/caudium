/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

/*
 * The Gsession module and the accompanying code is Copyright © 2002 Davies, Inc.
 * This code is released under the LGPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   Marek Habersack <grendel@caudium.net> (core module)
 *   Chris Davies <mcd@daviesinc.com> (SQL plugins)
 *
 */
constant cvs_version = "$Id$";

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER | MODULE_PROVIDER | MODULE_LOCATION | MODULE_FIRST | MODULE_EXPERIMENTAL;
constant module_name = "GSession Module";
constant module_doc  = "This is an implementation of an (optionally) cookie-less session tracking module.";
constant module_unique = 1;
constant thread_safe = 1;

#define CACHE "_gsession_stronghold_"
#define SVAR QUERY(svarname)

#ifdef THREADS
private object gc_lock = Thread.Mutex();
private mixed  gc_key;
#endif

private Regexp dcookie_rx = Regexp("^[0-9.]+$");    
private array(Regexp) uri_regexps = ({});

//
// All registered storage plugins
//
private mapping(string:mapping(string:mixed)) storage_plugins = ([]);
private mapping cur_storage = 0;

string status()
{
  string ret = "";

  if (!cur_storage)
    return "No current storage at this moment.";

  array(int) counters = cur_storage->get_counters();
  
  ret += sprintf("<table>"
                 "<tr><td>Current storage name</td><td><strong>%s</strong></td></tr>"
                 "<tr><td>Current storage desc</td><td><strong>%s</strong></td></tr>"
                 "<tr><td>Total number of sessions</td><td><strong>%d</td></tr>"
                 "<tr><td>Number of idle sessions</td><td><strong>%d</td></tr>"
                 "</table>", (string)cur_storage->name, (string)cur_storage->description,
                 counters[0], counters[1]);
  
  return ret;
}

void start(int num, object conf)
{
  register_plugins(conf);
    
  //
  // schedule a gc callout
  //
  if (QUERY(dogc))
    call_out(co_session_gc, QUERY(expire) / 2);

  if (QUERY(doexpidle))
    call_out(co_idle_gc, QUERY(expidletime) / 2);
}

void stop()
{}

void create()
{
  register_plugins(); // just the memory one, actually...
  cur_storage = storage_plugins->Memory;
    
  defvar( "mountpoint", "/gsadmin/", "Administrative mountpoint", TYPE_STRING,
          "This is the location where the session admin interface is found." );

  defvar("cookieexpire", -1, "Cookies: Cookie Expiration Time", TYPE_INT,
         "if 0, do not set a cookie expiration, if more than 0, set cookie expiration "
         "for that many seconds.  If less than 0, set cookie with date 8 years in the future" );
    
  defvar("domaincookies", 0, "Cookies: Domain Cookies", TYPE_FLAG,
         "If used, cookies will be tagged with <tt>.domain.com</tt> from "
         "the url that requested the user browser to guarantee that "
         "<tt>www.domain.com</tt> and <tt>domain.com</tt> have the same "
         "session id");
    
  defvar("secure", 0, "Cookies: Secure Cookies", TYPE_FLAG,
         "If used, cookies will be flagged as 'Secure' (RFC 2109). It means that the cookie "
         "will be read/set only if the connection is over a secure channel (SSL/TLS).");

  defvar("cookienorewrite", 1, "Cookies: no URI rewrite", TYPE_FLAG,
         "If used, the URIs won't be rewritten to include the session id "
         "if a session cookie is found and contains a valid session id.");

  defvar("svarname", "CaudiumSID", "Session variable name", TYPE_STRING,
         "Sets the name of the session variable as found in the URI as well "
         "as the name of the session cookie.");

  defvar("splugin", "Memory", "Storage: default storage module", TYPE_STRING_LIST,
         "Which plugin should be used to store the session data. Registered plugins:<br>\n" +
         get_plugin_descriptions(), get_plugin_names());

  defvar("expire", 600, "Session: Expiration time", TYPE_INT,
         "After how many seconds an inactive session is removed. This is only a default "
         "value - each session can be set its own expiry value.", 0, hide_gc);

  defvar("expidletime", 600, "Session: Idle session expiration time", TYPE_INT,
         "After how many seconds an idle session (that is a session on which no store/retrieve "
         "operation was made) will be deleted from the storage. This is to minimize the memory "
         "usage in case you have a lot of idle/unused sessions.");

  defvar("doexpidle", 1, "Session: Automatic idle session expiry", TYPE_FLAG,
         "If set, then idle sessions will be expired automatically after certain timeout.", 0,
         hide_expidle);
  
  defvar("dogc", 1, "Session: Garbage Collection", TYPE_FLAG,
         "If set, then the sessions will expire automatically after the "
         "given period. If unset, session expiration must be done elsewhere.");

  defvar("reflist", "", "Session: Referrers treated as valid", TYPE_TEXT,
         "This variable holds a list (one per line) of referrer addresses that "
         "are considered valid for accepting a session id should it not be "
         "stored in the client cookie. By default the module accepts all session "
         "IDs when the referring site is this virtual host.<br>"
         "<strong>Note: You must use the full URI of the referrer!</strong>");

  defvar("urimode", "exclude", "Session: URI classification mode", TYPE_MULTIPLE_STRING,
         "What should be the behaviour if an URI from a list is matched:<br>"
         "<ul>"
         "<li><strong>exclude</strong> - all URIs will be accepted except for those in the list. "
         "No session will be created if an URI matches one in the list.</li>"
         "<li><strong>include</strong> - all URIs will be ignored except for those in the list. "
         "A session will be created only if an URI is in the list.</li>"
         "</ul>",
         ({"exclude", "include"}));

  defvar("includeuris", "", "Session: Include URIs", TYPE_TEXT_FIELD,
         "A list of regular expressions (one entry per line) specifying the URIs to "
         "allocate session ID for. The regular expressions should describe only the "
         "path part of the URI, i.e. without the protocol, server, file and query parts. Matching "
         "is case-insensitive."
         "Examples:<br><blockquote><pre>"
         "^.*mail/\n"
         "^/site/[0-9]+/archive\n"
         "</pre></blockquote>", 0, lambda() { return (QUERY(urimode)!="include"); });

  defvar("excludeuris", "", "Session: Exclude URIs", TYPE_TEXT_FIELD,
         "A list of regular expressions (one entry per line) specifying the URIs <strong>not</strong> to "
         "allocate session ID for. The regular expressions should describe only the "
         "path part of the URI, i.e. without the protocol, server parts, file and query. "
         "Matching is case-insensitive."
         "Examples:<br><blockquote><pre>"
         "^.*mail/\n"
         "^/site/[0-9]+/archive\n"
         "</pre></blockquote>", 0, lambda() { return (QUERY(urimode)!="exclude"); });

  defvar("excludefiles", "jpg\njpeg\npng\ngif\ncgi\npike", "Session: Exclude file types", TYPE_TEXT_FIELD,
         "A list of file extensions for which no session should ever be allocated. "
         "One entry per line");

  defvar("relativeonly", 1, "Session: Rewrite only relative URIs", TYPE_FLAG,
         "If enabled, only the relative URIs will be rewritten when parsing the &lt;a&gt; tag. "
         "Relative URIs are those that don't contain the <em>protocol://host</em> part.");
}

int hide_gc ()
{
  return (!QUERY(dogc));
}

int hide_expidle ()
{
  return (!QUERY(doexpidle));
}

//
// A private class to wrap the id->misc storage. It is needed in case user
// is doing something like id->misc->session_variables->variable = "stuff"
// and we need to know whether the session was modified or not.
//
private class SettableWrapper
{
  private object id;
  private string sid;
  private string reg;
  
  void create(object reqid, string reqsid, void|string r)
  {
    id = reqid;
    sid = reqsid;
    reg = r;
  }
  
  mixed `[](string what) 
  {
    mixed ret;

    if (!cur_storage)
      return ([])[0];
    
    return cur_storage->retrieve(id, what, sid, reg);
  }

  mixed `[]=(string what, mixed contents)
  {
    if (!cur_storage)
      return ([])[0];

    cur_storage->store(id, what, contents, sid, reg);
    return contents;
  }

  mixed `->(string what)
  {
    return `[](what);
  }

  mixed `->=(string what, mixed contents)
  {
    return `[]=(what, contents);
  }

  mixed _m_delete(mixed index)
  {
    report_notice("_m_delete for %t called, deleting %O\n", this_object(), index);
    if (stringp(index) && cur_storage) {  
      return cur_storage->delete_variable(id, index, sid, reg);
    }
    return 0;
  }
  
  static string _sprintf(int f)
  {
    switch(f) {
        case 't':
          return sprintf("SettableWrapper(%s%s)", sid, reg ? "," + reg : "");
          
        case 'O':
          if (!cur_storage)
            return sprintf("SettableWrapper(%s%s)", sid, reg ? "," + reg : "");
          
          mapping data = cur_storage->get_region(id, sid, reg);
          if (!data)
            return sprintf("SettableWrapper(%s%s)", sid, reg ? "," + reg : "");
          return sprintf("%O", data);
    }
  }
};

//
// This is the 123sessions compatibility scope, thus the name and behavior
// are exactly the same.
//
class SessionScope {
  inherit "scope";
  string name = "session";
    
  string|int get(string var, object id)
  {
    if (!cur_storage || !id->misc->session_id)
      return "";

    mixed val = cur_storage->retrieve(id, var, id->misc->session_id, "session");        

    if (!val)
      return "";
        
    catch {
      string vr = (string)val;
            
      return vr ? vr : "";
    };
  }
  
  int set(string var, mixed val, object id)
  {
    if (!cur_storage || !id->misc->session_id)
      return 0;
    
    if(val)
      cur_storage->store(id, var, val, id->misc->session_id, "session");
    else 
      cur_storage->delete_variable(id, var, id->misc->session_id, "session");

    return 0;
  }
}

mixed first_try(object id)
{
  id->misc->session_id = 0;

  if (cur_storage)
    cur_storage->setup(id);
    
  if (!check_access(id))
    return 0;
    
  alloc_session(id);
  setup_compat(id);

  return 0;
}

mixed find_file( string path, object id )
{
  string ret;

  ret = sprintf("Module version: <strong>%s</strong><br>"
                "Current storage: <strong>%s</strong>",
                cvs_version, cur_storage ? cur_storage->name : "unset");
        
  return http_string_answer(ret);
}

array(object) query_scopes()
{
  return ({ SessionScope() });
}

string query_location()
{
  return QUERY(mountpoint);
}

string query_provides()
{
  return("gsession");
}

mapping query_tag_callers() 
{
  return ([
    "session_variable" : tag_variables,
    "user_variable" : tag_variables,
    "dump_session" : tag_dump_session,
    "dump_sessions" : tag_dump_sessions,
    "delete_session" : tag_end_session,
    "frame" : tag_frame
  ]);
}

mapping query_container_callers()
{
  return ([
    "a" : container_a,
    "form" : container_form
  ]);
}

//
// Session handling functions
//
private int check_access(object id)
{
  array(string)   ra;

  if (!id->not_query)
    return 1;

  string          ext = (id->not_query / ".")[-1];

  if (ext && ext != "")
    foreach((QUERY(excludefiles) / "\n") - ({}) - ({""}), string e)
      if (e == ext)
        return 0;
    
  switch(QUERY(urimode)) {
      case "include":
        ra = (QUERY(includeuris) / "\n") - ({}) - ({""});
        break;

      case "exclude":
        ra = (QUERY(excludeuris) / "\n")  - ({}) - ({""});
        break;
  }

  if (sizeof(ra) != sizeof(uri_regexps)) {
    // recompile the regexps, something's changed
    uri_regexps = ({});
    foreach(ra, string rs)
      uri_regexps += ({ Regexp(lower_case(rs)) });
  }

  int   res = 0;

  if (!sizeof(uri_regexps))
    return 1;

  string path = (id->not_query && sizeof(id->not_query)) ? dirname(id->not_query) : "/";
  if (path == "")
    path = "/";
    
  foreach(uri_regexps, object r)
    if ((res = r->match(path)))
      break;

  if (QUERY(urimode) == "include")
    return res;
  else
    return res ? 0 : 1;
}

private void co_session_gc() 
{
  if (!cur_storage) {
    if (QUERY(dogc))
      call_out(co_session_gc, QUERY(expire) / 2);
    return;
  }

#ifdef THREADS
  Thread.thread_create(cur_storage->expire_old, time());
#else
  cur_storage->expire_old(time());
#endif
    
  if (QUERY(dogc))
    call_out(co_session_gc, QUERY(expire) / 2);
}

private void co_idle_gc()
{
  if (!cur_storage) {
    if (QUERY(doexpidle))
      call_out(co_idle_gc, QUERY(expidletime) / 2);
    return;
  }

#ifdef THREADS
  Thread.thread_create(cur_storage->expire_idle, time());
#else
  cur_storage->expire_idle(time());
#endif
    
  if (QUERY(dogc))
    call_out(co_idle_gc, QUERY(expidletime) / 2);
}

private string gsession_build_cookie(object id, string sid, void|int remove)
{
  string Cookie = SVAR + "=" + (remove ? "" : sid) + "; path=/";

  if(QUERY(domaincookies)) 
    if (!(dcookie_rx->match((string)id->misc->host)))
      Cookie += ";domain=."+(((string)id->misc->host / ".")[(sizeof((string)id->misc->host / ".")-2)..]) * ".";

  if (!remove) {
    if (QUERY(cookieexpire) > 0)
#if constant(Caudium.HTTP.date)
      Cookie += "; Expires=" + Caudium.HTTP.date(time()+QUERY(cookieexpire)) +";";
#else
      Cookie += "; Expires=" + http_date(time()+QUERY(cookieexpire)) +";";
#endif  
    if (QUERY (cookieexpire) < 0)
      Cookie += "; Expires=Fri, 31 Dec 2010 23:59:59 GMT;";
  } else
#if constant(Caudium.HTTP.date)
    Cookie += "; Expires=" + Caudium.HTTP.date(0) + ";";
#else
    Cookie += "; Expires=" + http_date(0) + ";";
#endif
  if (QUERY (secure))
    Cookie += "; Secure";

  return Cookie;
}

private void gsession_set_cookie(object id, string sid, void|int remove)
{
  string Cookie = gsession_build_cookie(id, sid, remove);
    
  id->misc->is_dynamic = 1;
  id->misc->moreheads = ([ "Set-Cookie": Cookie ]);
}

//////////////////////////
//
// PLUGIN HANDLING CODE
//

private void rec_item_missing(string itemname, void|string pluginname)
{
  report_error("gSession: required registration record item missing. Name: %s, Plugin: %s\n",
               itemname, pluginname || "unknown");
}

private string get_plugin_descriptions()
{
  string   ret = "<table border='1'>";

  foreach(indices(storage_plugins), string pname)
    ret += sprintf("<tr><td><strong>%s</strong></td><td>%s</td></tr>",
                   pname, storage_plugins[pname]->description || "no description");

  return ret + "</table>";
}

private array(string) get_plugin_names()
{
  array(string)   ret = ({});
    
  foreach(indices(storage_plugins), string pname)
    ret += ({pname});

  return ret;
}

static private array(string) __required_plugin_funcs = ({
  "setup", "store", "retrieve", "delete_variable", "expire_old", "get_region",
  "get_all_regions", "session_exists", "get_sessions_area", "is_touched",
  "expire_idle", "get_counters", "set_expire_time", "set_expire_hook"
});

void register_plugins(void|object conf)
{
  //
  // always start from scratch
  //
  storage_plugins = ([]);
    
  //
  // memory plugin is always registered
  //
  storage_plugins[memory_storage_registration_record->name] =
    memory_storage_registration_record;
    
  if (!conf)
    return;
    
  array(object)  sproviders = conf->get_providers("gsession_storage_plugin");
    
  foreach(sproviders, object sp) {
    if (functionp(sp->register_gsession_plugin)) {
      mapping regrec = sp->register_gsession_plugin();
      int     broken = 0;
      
      //
      // Check whether the returned mapping contains all the required
      // data
      //
      if (!stringp(regrec->name) || !regrec->name || !strlen(regrec->name)) {
        rec_item_missing("name");
        continue;
      }

      foreach(__required_plugin_funcs, string funcname) {
        if (!regrec[funcname] || !functionp(regrec[funcname])) {
          rec_item_missing("setup", regrec->name);
          broken = 1;
        }
      }

      if (broken)
        continue;
      
      if (storage_plugins[regrec->name])
        report_warning("gSession: duplicate plugin '%s'\n", regrec->name);
            
      storage_plugins[regrec->name] = regrec;
    }
  }

  defvar("splugin", QUERY(splugin), "Storage: default storage module", TYPE_STRING_LIST,
         "Which plugin should be used to store the session data. Registered plugins:<br>\n" +
         get_plugin_descriptions(), get_plugin_names());
}

//////////////////////////
// MEMORY STORAGE
//

//
// This is the default, memory, storage medium. As opposite to other
// storage mechanism, this one is built in albeit using the same interface
// as the other mechanisms.
// The structure is as follows (fields in single quotes denote literal names):
//
//  storage_mapping
//      '_sessions_':sessions_mapping
//         session1_id:session1_options
//           'nocookies':1 if no cookies should be set, 0 if cookies are ok
//           'lastused':time_when_last_used
//           'lastchanged':time_of_last_store_or_delete
//           'lastretrieved':time_of_last_retrieve
//           'cookieattempted':1 if a cookie set was attempted
//           'ctime':creation_time
//           'exptime':expiration time in s
//           'exphook':function, if any, to be called when the session is
//                     about to expire.
//         session2_id:session2_options
//           'nocookies':1 if no cookies should be set, 0 if cookies are ok
//           'lastused':time_when_last_used
//           'cookieattempted':1 if a cookie set was attempted
//      region1_name:region1_mapping
//         session1_id:session1_storage
//           'data':session1_data
//             key1_name:key1_value
//             key2_name:key2_value
//             ...
//         session2_id:session2_storage
//           'data':session2_data
//             key1_name:key1_value
//             key2_name:key2_value
//             ...
//      region2_name:region2_mapping
//         session1_id:session1_storage
//           'data':session1_data
//             key1_name:key1_value
//             key2_name:key2_value
//             ...
//         session2_id:session2_storage
//           'data':session2_data
//             key1_name:key1_value
//             key2_name:key2_value
//             ...
//
// Two predefined regions MUST exist, for compatibility with 123sessions:
// "session" and "user" they are available through the
// id->misc->session_variables and id->misc->user_variables,
// respectively. All regions are available through the
// id->misc->gsession->region_name mapping. This is true for all the
// storage mechanisms.
//
private mapping(string:mapping(string:mapping(string:mixed))|object) _memory_storage = ([]);

//
// Registration record for the "plugin". Such record is used for all the
// storage plugins, including this one for consistency. All plugins are
// required to provide just one function - register_gsession_plugin - that
// returns a mapping whose contents is described below:
//
//  string name; (mandatory)
//     plugin name (displayed in the CIF and the admin interface)
//
//  string description; (optional)
//     plugin description
//
//  function setup; (mandatory)
//  synopsis: void setup(object id, string|void sid);
//     function to setup the plugin. Called once for every
//     request. If sid is absent, the function is required just to make
//     sure the storage exists and exit. If sid is present, a new area for
//     the given session must be created in every region.
//
//  function store; (mandatory)
//  synopsis: void store(object id, string key, mixed data, string sid, void|string reg);
//     function to store a variable into a region. Synopsis below.
//
//  function retrieve; (mandatory)
//  synopsis: mixed retrieve(object id, string key, string sid, void|string reg);
//     function to retrieve a variable from a region. Synopsis below.
//
//  function delete_variable; (mandatory)
//  synopsis: mixed delete_variable(object id, string key, string sid, void|string reg);
//     function to delete a variable from a region.
//
//  function is_touched; (mandatory)
//  synopsis: int is_touched(object id, string sid);
//     returns 1 if the session was used (that is anything was
//     stored/retrieved), 0 otherwise.
//
//  function expire_old; (mandatory)
//  synopsis: void expire_old(int curtim);
//     called from a callout to expire aged sessions. Ran in a separate
//     thread, if available.
//
//  function expire_idle; (mandatory)
//  synopsis: void expire_idle(int curtime);
//     called from a callout to expire idle sessions. Ran in a separate
//     thread, if available.
//
//  function delete_session; (mandatory)
//  synopsis: void delete_session(string sid);
//     delete a session from all the regions of the storage.
//
//  function get_region; (mandatory)
//  synopsis: mapping get_region(object id, string sid, string reg);
//     return a storage mapping of the specified region. This function
//     _must_ return valid mappings for the "session" and "user" regions
//     (compatibility with 123sessions)
//
//  function get_all_regions; (mandatory)
//  synopsis: mapping get_all_regions(object id);
//     returns a mapping of all the regions in use - i.e. full storage.
//
//  function session_exists; (mandatory)
//  synopsis: int session_exists(object id, string sid);
//     checks whether the given session exists in the storage
//
//  function get_sessions_area; (mandatory)
//  synopsis: mapping get_sessions_area(object id);
//     returns the special '_sessions_' area in the storage. That area
//     stores all the options global to any session ID.
//
//  function get_counters; (mandatory)
//  synopsis: array(int) get_counters(object id);
//     returns a two element array with the session counters. The first
//     index contains the total number of sessions, the second index
//     contains the number of idle sessions.
//
//  function set_expire_time: (mandatory)
//  synopsis: void set_expire_time(string sid, int seconds);
//     sets the expire time for the specified session.
//
//  function set_expire_hook: (mandatory)
//  synopsis: void set_expire_hook(string sid, function|void hook);
//     defines a hook to be called when the session is about to expire. The
//     hook takes one argument - the session id string - and returns no
//     result. Passing a null hook (or not passing it at all) removes any
//     existing hook from the specified session.
//
private mapping memory_storage_registration_record = ([
  "name" : "Memory",
  "description" : "Memory-only storage of session data",
  "setup" : memory_setup,
  "store" : memory_store,
  "retrieve" : memory_retrieve,
  "delete_variable" : memory_delete_variable,
  "expire_old" : memory_expire_old,
  "expire_idle" : memory_expire_idle,
  "delete_session" : memory_delete_session,
  "get_region" : memory_get_region,
  "get_all_regions" : memory_get_all_regions,
  "session_exists" : memory_session_exists,
  "get_sessions_area" : memory_get_sessions_area,
  "is_touched" : memory_is_touched,
  "get_counters" : memory_get_counters,
  "set_expire_time" : memory_set_expire_time,
  "set_expire_hook" : memory_set_expire_hook
]);

//
// Validate region+session storage. Report an error if anything's wrong.
//
private int memory_validate_storage(string reg, string sid, string fn) 
{
  if (!_memory_storage[reg]) {
    // To throw (up) or not to throw (up) - that is the question...
    report_error("gSession: Fugazi! No memory storage for region '%s'! (called from '%s')\n", reg, fn);
    return -1;
  }

  if (!_memory_storage[reg][sid]) {
    // To throw (up) or not to throw (up) - that is the question...
    report_error("gSession: Fugazi! No session storage for region '%s' and session '%s'! (called from '%s')\n", reg, sid || "", fn);
    return -1;
  }

  return 0; // phew, everything's fine :)
}

//
// Set up storage of the session. If storage for given session ID already
// exists, simply point the id->misc variables to it. The plugin is
// responsible for setting up the two legacy regions - "session" and
// "user". They _must_ exist in every storage!
//
private void memory_setup(object id, string|void sid) 
{
  if (!_memory_storage || !sizeof(_memory_storage)) {
    //
    // set up the compatibility regions. These are the only regions
    // that we create/use by default. All variables not specifically
    // destined for some named region end up in the "session" one.
    //
    _memory_storage = ([]); // it might be 0
    _memory_storage->session = ([]);
    _memory_storage->user = ([]);
    _memory_storage->_sessions_ = ([
      "total_sessions" : 0,
      "idle_sessions" : 0
    ]);
  }

  if (!sid)
    return;
    
  //
  // If storage for the passed session id doesn't exist, allocate it in
  // all the regions. At the same time, set up the id->misc->gsession mapping
  //
  if (!id->misc->gsession)
    id->misc->gsession = ([]);

  if (!_memory_storage["_sessions_"][sid]) {
    _memory_storage["_sessions_"][sid] = ([
      "nocookies" : 0,
      "cookieattempted" : 0,
      "lastused" : time(),
      "fresh" : 1,
      "exptime" : QUERY(expire)
    ]);
    _memory_storage["_sessions_"]->total_sessions++;
    _memory_storage["_sessions_"]->idle_sessions++;
  }
  
  foreach(indices(_memory_storage), string region) {
    if (region != "_sessions_" && !_memory_storage[region][sid])
      _memory_storage[region][sid] = ([
        "data" : ([])
      ]);
        
    if (!id->misc->gsession[region])
      id->misc->gsession[region] = SettableWrapper(id, sid, region);
  }
}

private int memory_is_touched(object id, string sid)
{
  if (memory_validate_storage("session", sid, "memory_storage") < 0)
    return 0;
  
  return _memory_storage["_sessions_"][sid]->fresh != 0;
}

private array(int) memory_get_counters(object|void id)
{
  if (!_memory_storage || !_memory_storage["_sessions_"])
    return ({0, 0});
  
  return ({
   (int)_memory_storage["_sessions_"]->total_sessions,
   (int)_memory_storage["_sessions_"]->idle_sessions
  });
}

//
// Store a variable in the indicated region for the passed session ID.
//
private void memory_store(object id, string key, mixed data, string sid, void|string reg)
{
  string    region = reg || "session";
  int       t = time();
    
  if (memory_validate_storage(region, sid, "memory_storage") < 0)
    return;

  _memory_storage["_sessions_"][sid]->lastused = t;
  if (_memory_storage["_sessions_"][sid]->fresh) {
    _memory_storage["_sessions_"]->idle_sessions--;
    _memory_storage["_sessions_"][sid]->fresh = 0;
  }
  _memory_storage[region][sid]->data[key] = data;
  _memory_storage["_sessions_"][sid]->lastchanged = t;
}

//
// Retrieve a variable from the indicated region
//
private mixed memory_retrieve(object id, string key, string sid, void|string reg)
{
  string    region = reg || "session";
  int       t = time();
    
  if (memory_validate_storage(region, sid, "memory_retrieve") < 0)
    return 0;

  _memory_storage["_sessions_"][sid]->lastused = t;
  if (_memory_storage["_sessions_"][sid]->fresh) {
    _memory_storage["_sessions_"][sid]->fresh = 0;
    _memory_storage["_sessions_"]->idle_sessions--;
  }
  
  if (!_memory_storage[region][sid]->data[key])
    return 0;
  _memory_storage["_sessions_"][sid]->lastretrieved = t;
  
  return _memory_storage[region][sid]->data[key];
}

//
// Remove a variable from the indicated region and return its value to the
// caller.
//
private mixed memory_delete_variable(object id, string key, string sid, void|string reg)
{
  string    region = reg || "session";
  int       t = time();    

  if (memory_validate_storage(region, sid, "memory_delete_variable") < 0)
    return 0;
  
  _memory_storage["_sessions_"][sid]->lastused = t;
  if (_memory_storage["_sessions_"][sid]->fresh) {
    _memory_storage["_sessions_"][sid]->fresh = 0;
    _memory_storage["_sessions_"]->idle_sessions--;
  }  

  if (_memory_storage[region][sid]->data[key]) {
    mixed val = _memory_storage[region][sid]->data[key];
    m_delete(_memory_storage[region][sid]->data, key);

    _memory_storage["_sessions_"][sid]->lastchanged = t;
    return val;
  }

  return 0;
}

//
// Delete the given session from all regions of the storage
//
private void memory_delete_session(string sid)
{
  if (memory_validate_storage("_sessions_", sid, "memory_delete_session") < 0)
    return 0;

  if (_memory_storage["_sessions_"][sid]->fresh)
    _memory_storage["_sessions_"]->idle_sessions--;
  _memory_storage["_sessions_"]->total_sessions--;
  
  foreach(indices(_memory_storage), string region)
    m_delete(_memory_storage[region], sid);
}

private void memory_expire_idle(int curtime)
{
#ifdef THREADS
  gc_key = gc_lock->lock();
#endif

  foreach(indices(_memory_storage), string region)
    if (mappingp(_memory_storage[region])) {
      foreach(indices(_memory_storage[region]), string sid) {
        if (_memory_storage["_sessions_"][sid] && mappingp(_memory_storage["_sessions_"][sid])) {
          if (_memory_storage["_sessions_"][sid]->fresh && QUERY(doexpidle) &&
              curtime - _memory_storage["_sessions_"][sid]->lastused > QUERY(expidletime)) {
            memory_delete_session(sid);
          }
        }
      }
    }
#ifdef THREADS
  destruct(gc_key);
#endif
}

private void memory_expire_old(int curtime)
{
#ifdef THREADS
  gc_key = gc_lock->lock();
#endif

  foreach(indices(_memory_storage), string region)
    if (mappingp(_memory_storage[region])) {
      foreach(indices(_memory_storage[region]), string sid) {
        if (_memory_storage["_sessions_"][sid] && mappingp(_memory_storage["_sessions_"][sid])) {
          if (curtime - _memory_storage["_sessions_"][sid]->lastused > _memory_storage["_sessions_"][sid]->exptime) {
            if (_memory_storage["_sessions_"][sid]->exphook)
              _memory_storage["_sessions_"][sid]->exphook(sid);
            memory_delete_session(sid);
            continue;
          }
        }
      }
    }
#ifdef THREADS
  destruct(gc_key);
#endif
}

private mapping memory_get_region(object id, string sid, string reg)
{
  string    region = reg || "session";

  _memory_storage["_sessions_"][sid]->lastused = time();
    
  if (memory_validate_storage(region, sid, "memory_get_region") < 0)
    return 0;

  return _memory_storage[region][sid];
}

private mapping memory_get_all_regions(object id)
{
  return _memory_storage;
}

private int memory_session_exists(object id, string sid)
{
  if (memory_validate_storage("session", sid, "memory_session_exists") < 0)
    return 0;

  return 1;
}

private mapping memory_get_sessions_area(object id)
{
  if (_memory_storage["_sessions_"])
    return _memory_storage["_sessions_"];

  return 0;
}

private void memory_set_expire_time(string sid, int timeval)
{  
  if (memory_validate_storage("session", sid, "memory_set_expire_time") < 0)
    return;

  _memory_storage["_sessions_"][sid]->exptime = timeval;
}

private void memory_set_expire_hook(string sid, function exphook)
{  
  if (memory_validate_storage("session", sid, "memory_set_expire_hook") < 0)
    return;

  _memory_storage["_sessions_"][sid]->exphook = exphook;
}

//
// provider interface
//


int is_touched(object id, string|mapping(string:mapping(string:mixed)) key)
{
  if (!cur_storage || !id->misc->session_id)
    return -1;

  return cur_storage->is_touched(id, id->misc->session_id);
}

//     "store" : memory_store,
//     "retrieve" : memory_retrieve,
//     "delete_variable" : memory_delete_variable,
//     "delete_session" : memory_delete_session,
//     "get_sessions_area" : memory_get_sessions_area
//     "build_cookie" : build the cookie to set (to be used by the code
//                      that returns Caudium.HTTP.pipe_in_progress)
// STORE
//
//  Params:
//
//    id     - request id
//    key    - name of the variable to store if a string, mapping of
//             key/value pairs otherwise. Every entry in a mapping contains
//             a string index called 'key' and a mixed value called 'data'.
//    data   - contents of the variable to store. Ignored if key is a
//             mapping.
//    reg    - (optional) region name, defaults to "session" which is the
//             region compatible with the old 123session storage and
//             available through the id->misc->session_variables mapping.
//
//  Returns:
//     -1    - when an error ocurred
//      0    - when everything's fine
//
int store(object id, string|mapping(string:mapping(string:mixed)) key, void|mixed data, void|string reg)
{
  if (!cur_storage || !id->misc->session_id)
    return -1;

  if (mappingp(key)) {
    foreach(indices(key), string s) {
      cur_storage->store(id, key[s]->key, key[s]->data, id->misc->session_id, reg);
    }
  } else
    cur_storage->store(id, key, data, reg);
    
  return 0;
}

// RETRIEVE
//
//  Params:
//
//   id       - the request id
//   key      - a variable name or an array of variable names to retrieve
//   reg      - (optional) region from which to retrieve the data. Defaults
//              to "session".
//
//  Returns:
//   a mixed value of the given variable if 'key' is a string, a mapping of
//   key/value ('key' and 'data' indices, respectively) if 'key' is an
//   array.
//
mixed|mapping(string:mixed) retrieve(object id, string|array(string) key, void|string reg)
{
  if (!cur_storage || !id->misc->session_id)
    return 0;

  mixed|mapping(string:mixed) ret;
    
  if (arrayp(key)) {
    ret = ([]);
    foreach(key, string k)
      ret += ([ "key" : k, "data" : cur_storage->retrieve(id, k, reg) ]);
  } else
    ret = cur_storage->retrieve(id, key, id->misc->session_id, reg);

  return ret;
}

// DELETE VARIABLE
//
//  Params:
//
//   id       - the request id
//   key      - a name, or an array of names, of the variable(s) to remove
//   reg      - (optional) region name, defaults to "sessions"
//
//  Returns:
//   a mixed value of the variable that was deleted if 'key' is a string or
//   a mapping of key/value pairs if 'key' is an array.
//
mixed|mapping(string:mixed) delete_variable(object id, string|array(string) key, void|string reg)
{
  if (!cur_storage || !id->misc->session_id)
    return 0;

  mixed|mapping(string:mixed) ret;

  if (arrayp(key)) {
    ret = ([]);
    foreach(key, string k)
      ret += ([ "key" : k, "data" : cur_storage->delete_variable(id, k, reg) ]);
  } else
    ret = cur_storage->delete_variable(id, key, id->misc->session_id, reg);
    
  return ret;
}

// DELETE SESSION
//
//  Params:
//
//    id     - the request object
//
void delete_session(object|string id)
{
  if (!cur_storage || (objectp(id) && !id->misc->session_id))
    return;

  if (objectp(id))
    cur_storage->delete_session(id->misc->session_id);
  else if (stringp(id))
    cur_storage->delete_session(id);
}

function kill_session = delete_session;

void set_expire_time(int timeval, string|object id)
{
  if (!cur_storage || (objectp(id) && !id->misc->session_id))
    return;

  string sid;
  
  if (stringp(id))
    sid = id;
  else if (objectp(id))
    sid = id->misc->session_id;
  
  cur_storage->set_expire_time(sid, timeval);
}

void set_expire_hook(function exphook, string|object id)
{
  if (!cur_storage || (objectp(id) && !id->misc->session_id))
    return;

  string sid;
  
  if (stringp(id))
    sid = id;
  else if (objectp(id))
    sid = id->misc->session_id;
  
  cur_storage->set_expire_hook(sid, exphook);
}

// GET SESSIONS AREA
//
//  Params:
//    id     - the request object
//
//  Returns:
//    a mapping containing the current session settings
mapping get_session_area(object id)
{
  if (!cur_storage || !id->misc->session_id)
    return 0;

  mapping sa = cur_storage->get_sessions_area(id);
  if (sa && sa[id->misc->session_id])
    return sa[id->misc->session_id];

  return 0;
}

// BUILD A COOKIE
//
// Params:
//   id       - the request object
//   sid      - a session id. If absent, id->misc->session_id is used.
//   remove   - if set, then the returned cookie will be used to remove the
//              session cookie from the client.
//
// Returns:
//   A string to be used as the value of the Set-Cookie header.
string build_cookie(object id, void|string sid, void|int remove)
{
  if (!cur_storage || !id->misc->session_id)
    return 0;

  return gsession_build_cookie(id, sid ? sid : id->misc->session_id, remove);
}

// module code
//
private int referrer_ok(object id)
{
  if (!id->referrer || !sizeof(id->referrer))
    return 0;

  array(string)  refs = ({ id->conf->QUERY(MyWorldLocation) }) + (QUERY(reflist) / "\n") - ({}) - ({""});
    
  foreach(refs, string ref)
    if (String.common_prefix(({ref, id->referrer})) == ref)
      return 1;

  return 0;
}

//
// Find out whether we have a session id available anywhere and/or create a
// new session if necessary. Returns a session id string.
//
private string alloc_session(object id)
{
  string    ret = "";

  id->misc->_gsession_is_here = 0;
    
  string   sp = QUERY(splugin);
  if (!storage_plugins[sp])
    throw(({
      sprintf("gSessions: something seriously broken! Storage plugin '%s' not in the registry!\n",
              sp),
      backtrace()
    }));

  cur_storage = storage_plugins[sp];
    
  mapping  sa = cur_storage->get_sessions_area(id) || ([]);

  if (id->cookies[SVAR] && sizeof(id->cookies[SVAR]) && sa[id->cookies[SVAR]]) {
    id->misc->session_id = id->cookies[SVAR];
    id->misc->_gsession_cookie = 1;
    sa->cookieattempted = 0;
    sa->nookookies = 0;
  } else if (id->cookies[SVAR]) {
    id->misc->_gsession_cookie = 0;
    id->misc->_gsession_remove_cookie = 1;
  } else
    id->misc->_gsession_cookie = 0;
    
  if (!id->misc->_gsession_cookie && id->variables[SVAR]) {
    if (referrer_ok(id))
      id->misc->session_id = id->variables[SVAR];
  }
    
  if (id->misc->session_id && cur_storage->session_exists(id, id->misc->session_id)) {
    cur_storage->setup(id, id->misc->session_id);
    id->misc->_gsession_is_here = 1;
    sa = cur_storage->get_sessions_area(id)[id->misc->session_id];
        
    if (!id->misc->_gsession_cookie) {
      if (!sa->nookookies && !sa->cookieattempted) {
        sa->cookieattempted = 1;
        gsession_set_cookie(id, id->misc->session_id);
      } else {
        sa->nocookies = 1;
      }
    }
    
    return id->misc->session_id;
  }

  id->misc->session_id = 0;
    
  //
  // new session it seems
  //
  string digest;    

  digest = Crypto.sha()->update((string)(time()))->digest() + Crypto.randomness.reasonably_random()->read(15);
  ret = replace(MIME.encode_base64(digest), ({"+","/","="}), ({"_","|","-"}));    
    
  cur_storage->setup(id, ret);

  id->misc->_gsession_is_here = 1;
  id->misc->session_id = ret;

  sa = cur_storage->get_sessions_area(id)[id->misc->session_id];

  sa->lastused = time();
  sa->ctime = time();
    
  if (!sa->nocookies && !sa->cookieattempted) {
    gsession_set_cookie(id, ret);
    sa->cookieattempted = 1;
  } else if (sa->cookieattempted)
    sa->nocookies = 1;
    
  return ret;
}

//
// tags below
//
private void setup_compat(object id)
{
  if (!cur_storage) {
    report_warning("gSession: cur_storage unset!\n");
    return;
  }

  if (!id->misc->session_id) {
    report_warning("gSession: no session allocated\n");
    return;
  }

  id->misc->session_variables = SettableWrapper(id, id->misc->session_id, "session");
  id->misc->user_variables = SettableWrapper(id, id->misc->session_id, "user");
}

//
// 123sessions compatibility tags
//
string tag_variables(string tag, mapping args, object id, object file, mapping defines)
{
  if (!cur_storage)
    return "";
    
  if (!args->variable) {
    return "";
  }

  string region;
  if (tag == "session_variable")
    region = "session";

  if (tag == "user_variable")
    region = "user";
    
  if (args->value) {
    cur_storage->store(id, args->variable, args->value, id->misc->session_id, region);
    return "";
  } else {
    return cur_storage->retrieve(id, args->variable, id->misc->session_id, region) || "";
  }
}

string tag_dump_session (string tag, mapping args, object id, object file)
{
  if (!id->misc->session_id)
    return "";
    
  return (id->misc->session_variables) ?
    (sprintf ("<pre>id->misc->session_variables : %O\n</pre>", id->misc->session_variables)) : "";
}

string tag_dump_sessions (string tag, mapping args, object id, object file)
{
  if (!id->misc->session_id)
    return "";
    
  string   ret;
  mapping  m = cur_storage->get_all_regions(id);

  return m ? sprintf("<pre>_variables : %O\n</pre>", m) : "";
}

string tag_end_session (string tag, mapping args, object id, object file)
{
  if (!id->misc->session_id)
    return "";
    
  if (id->misc->session_id && cur_storage) {
    mapping m = cur_storage->get_sessions_area(id)[id->misc->session_id];

    if (!m->nocookies)
      gsession_set_cookie(id, 0, 1);
        
    cur_storage->delete_session (id->misc->session_id);
  }
    
  return "";
}

//
// URI tags overloaders
//

//
// Checks whether we should rewrite the uri or not
private int leave_me_alone(string uri)
{
  if (!uri || !sizeof(uri))
    return 0;

  if (uri[0] == '/')
    return 0;

  uri = lower_case(uri);
    
  if (sizeof(uri) >= 7 && uri[0..6] == "mailto:")
    return 1;

  if (sizeof(uri) > 11 && uri[0..10] == "javascript:")
    return 1;
    
  if (search(uri, "://") < 0)
    return 0; // assuming it's a relative URI

  if (QUERY(relativeonly))
    return 1;
    
  if (sizeof(uri) >= 7 && uri[0..6] == "http://")
    return 0;

  if (sizeof(uri) >= 8 && uri[0..7] == "https://")
    return 0;

  if (sizeof(uri) >= 6 && uri[0..5] == "ftp://")
    return 0;
    
  return 1;
}

string rewrite_uri(object id, string from, void|int append, void|mapping qvars)
{
  int              hashpos;
  array(string)    parts;
  string           sepchar = append ? "&" : "?";
    
  hashpos = search(from, "#");

  if (hashpos >= 0) {
    int skip_sid = 0;
        
    parts = from / "#";
    if (parts[0] == "") {
      parts[0] = id->raw_url;
      skip_sid = 1;
    }

    if (!skip_sid || (search(from, SVAR) < 0 && search(parts[0], SVAR) < 0))
      parts = ({parts[0], SVAR, "=" + id->misc->session_id, "#" + parts[1]});
    else {
      sepchar = "";
      parts = ({parts[0], "", "", "#" + parts[1]});
    }
  } else
    parts = ({from, SVAR, "=" + id->misc->session_id, ""});
    
  return sprintf("%s%s%s%s%s", parts[0], sepchar, parts[1], parts[2], parts[3]);

}

mixed container_a(string tag, mapping args, string contents, object id, mapping defines)
{
  string   query;
  mapping  hvars = ([]);
  int      have_query = 0;
    
  if (id->misc->session_id && args && !args->norewrite && args->href && !leave_me_alone(args->href)) {
    if (sscanf(args->href, "%*s?%s", query) == 2) {
      Caudium.parse_query_string(query, hvars);
      have_query = 1;
    }
        
    if (!hvars[SVAR] && (!id->misc->_gsession_cookie || (id->misc->_gsession_cookie && !QUERY(cookienorewrite))))
      args->href = rewrite_uri(id,  args->href, have_query, hvars);
  }

  m_delete(args, "norewrite");
    
  return ({ Caudium.make_container("a", args, parse_rxml(contents, id)) });
}

mixed container_form(string tag, mapping args, string contents, object id, mapping defines)
{
  int restrict = ((args ? args->norewrite : 0) + id->misc->_gsession_cookie);
    
  if (!restrict && id->misc->session_id)
    contents = sprintf("<input type=\"hidden\" name=\"%s\" value=\"%s\">",
                       SVAR, id->misc->session_id) + contents;

  m_delete(args, "norewrite");
    
  return ({ Caudium.make_container("form", args, parse_rxml(contents, id)) });
}

mixed tag_frame (string tag, mapping args, object id, object file)
{
  string   query;
  mapping  hvars = ([]);
  int      have_query = 0;
    
  if (id->misc->session_id && args && !args->norewrite && args->src && !leave_me_alone(args->src)) {
    if (sscanf(args->src, "%*s?%s", query) == 2) {
      Caudium.parse_query_string(query, hvars);
      have_query = 1;
    }
        
    if (!hvars[SVAR] && (!id->misc->_gsession_cookie || (id->misc->_gsession_cookie && !QUERY(cookienorewrite))))
      args->src = rewrite_uri(id,  args->src, have_query, hvars);
  }

  m_delete(args, "norewrite");
    
  return ({ Caudium.make_tag("frame", args) });
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: mountpoint
//! This is the location where the session admin interface is found.
//!  type: TYPE_STRING
//!  name: Administrative mountpoint
//
//! defvar: cookieexpire
//! if 0, do not set a cookie expiration, if more than 0, set cookie expiration for that many seconds.  If less than 0, set cookie with date 8 years in the future
//!  type: TYPE_INT
//!  name: Cookies: Cookie Expiration Time
//
//! defvar: domaincookies
//! If used, cookies will be tagged with <tt>.domain.com</tt> from the url that requested the user browser to guarantee that <tt>www.domain.com</tt> and <tt>domain.com</tt> have the same session id
//!  type: TYPE_FLAG
//!  name: Cookies: Domain Cookies
//
//! defvar: secure
//! If used, cookies will be flagged as 'Secure' (RFC 2109). It means that the cookie will be read/set only if the connection is over a secure channel (SSL/TLS).
//!  type: TYPE_FLAG
//!  name: Cookies: Secure Cookies
//
//! defvar: cookienorewrite
//! If used, the URIs won't be rewritten to include the session id if a session cookie is found and contains a valid session id.
//!  type: TYPE_FLAG
//!  name: Cookies: no URI rewrite
//
//! defvar: svarname
//! Sets the name of the session variable as found in the URI as well as the name of the session cookie.
//!  type: TYPE_STRING
//!  name: Session variable name
//
//! defvar: splugin
//! Which plugin should be used to store the session data. Registered plugins:<br />
//!
//!  type: TYPE_STRING_LIST
//!  name: Storage: default storage module
//
//! defvar: expire
//! After how many seconds an inactive session is removed. This is only a default value - each session can be set its own expiry value.
//!  type: TYPE_INT
//!  name: Session: Expiration time
//
//! defvar: expidletime
//! After how many seconds an idle session (that is a session on which no store/retrieve operation was made) will be deleted from the storage. This is to minimize the memory usage in case you have a lot of idle/unused sessions.
//!  type: TYPE_INT
//!  name: Session: Idle session expiration time
//
//! defvar: doexpidle
//! If set, then idle sessions will be expired automatically after certain timeout.
//!  type: TYPE_FLAG
//!  name: Session: Automatic idle session expiry
//
//! defvar: dogc
//! If set, then the sessions will expire automatically after the given period. If unset, session expiration must be done elsewhere.
//!  type: TYPE_FLAG
//!  name: Session: Garbage Collection
//
//! defvar: reflist
//! This variable holds a list (one per line) of referrer addresses that are considered valid for accepting a session id should it not be stored in the client cookie. By default the module accepts all session IDs when the referring site is this virtual host.<br /><strong>Note: You must use the full URI of the referrer!</strong>
//!  type: TYPE_TEXT
//!  name: Session: Referrers treated as valid
//
//! defvar: urimode
//! What should be the behaviour if an URI from a list is matched:<br /><ul><li><strong>exclude</strong> - all URIs will be accepted except for those in the list. No session will be created if an URI matches one in the list.</li><li><strong>include</strong> - all URIs will be ignored except for those in the list. A session will be created only if an URI is in the list.</li></ul>
//!  type: TYPE_MULTIPLE_STRING
//!  name: Session: URI classification mode
//
//! defvar: includeuris
//! A list of regular expressions (one entry per line) specifying the URIs to allocate session ID for. The regular expressions should describe only the path part of the URI, i.e. without the protocol, server, file and query parts. Matching is case-insensitive.Examples:<br /><blockquote><pre>^.*mail/
//!^/site/[0-9]+/archive
//!</pre></blockquote>
//!  type: TYPE_TEXT_FIELD
//!  name: Session: Include URIs
//
//! defvar: excludeuris
//! A list of regular expressions (one entry per line) specifying the URIs <strong>not</strong> to allocate session ID for. The regular expressions should describe only the path part of the URI, i.e. without the protocol, server parts, file and query. Matching is case-insensitive.Examples:<br /><blockquote><pre>^.*mail/
//!^/site/[0-9]+/archive
//!</pre></blockquote>
//!  type: TYPE_TEXT_FIELD
//!  name: Session: Exclude URIs
//
//! defvar: excludefiles
//! A list of file extensions for which no session should ever be allocated. One entry per line
//!  type: TYPE_TEXT_FIELD
//!  name: Session: Exclude file types
//
//! defvar: relativeonly
//! If enabled, only the relative URIs will be rewritten when parsing the &lt;a&gt; tag. Relative URIs are those that don't contain the <em>protocol://host</em> part.
//!  type: TYPE_FLAG
//!  name: Session: Rewrite only relative URIs
//
//! defvar: splugin
//! Which plugin should be used to store the session data. Registered plugins:<br />
//!
//!  type: TYPE_STRING_LIST
//!  name: Storage: default storage module
//

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */

