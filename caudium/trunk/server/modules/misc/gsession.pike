/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
    string ret = "Status? What status?! Buzz off, I want to sleep! And seriously: status quo... ";

    ret += sprintf("See the admin interface for information.");
    
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
           "After how many seconds an unactive session is removed", 0, hide_gc);

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
}

int hide_gc ()
{
    return (!QUERY(dogc));
}

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

mixed find_file ( string path, object id )
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
        "delete_session" : tag_end_session
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

    string path = dirname(id->not_query);
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
    Thread.thread_create(cur_storage->expire_old, time(), QUERY(expire));
#else
    cur_storage->expire_old(time(), QUERY(expire));
#endif
    
    if (QUERY(dogc))
        call_out(co_session_gc, QUERY(expire) / 2);
}

private void gsession_set_cookie(object id, string sid, void|int remove) {
    string Cookie = SVAR + "=" + (remove ? "" : sid) + "; path=/";

    if(QUERY(domaincookies)) 
        if (!(dcookie_rx->match((string)id->misc->host)))
            Cookie += ";domain=."+(((string)id->misc->host / ".")[(sizeof((string)id->misc->host / ".")-2)..]) * ".";

    if (!remove) {
        if (QUERY(cookieexpire) > 0)
            Cookie += "; Expires=" + http_date(time()+QUERY(cookieexpire)) +";";
        if (QUERY (cookieexpire) < 0)
            Cookie += "; Expires=Fri, 31 Dec 2010 23:59:59 GMT;";
    } else
        Cookie += "; Expires=" + http_date(0) + ";";
    
    if (QUERY (secure))
        Cookie += "; Secure";
    
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

            //
            // Check whether the returned mapping contains all the required
            // data
            //
            if (!stringp(regrec->name) || !regrec->name || !strlen(regrec->name)) {
                rec_item_missing("name");
                continue;
            }
            
            if (!functionp(regrec->setup) || !regrec->setup) {
                rec_item_missing("setup", regrec->name);
                continue;
            }

            if (!functionp(regrec->store) || !regrec->store) {
                rec_item_missing("store", regrec->name);
                continue;
            }

            if (!functionp(regrec->retrieve) || !regrec->retrieve) {
                rec_item_missing("retrieve", regrec->name);
                continue;
            }

            if (!functionp(regrec->delete_variable) || !regrec->delete_variable) {
                rec_item_missing("delete_variable", regrec->name);
                continue;
            }

            if (!functionp(regrec->expire_old) || !regrec->expire_old) {
                rec_item_missing("expire_old", regrec->name);
                continue;
            }

            if (!functionp(regrec->get_region) || !regrec->get_region) {
                rec_item_missing("get_region", regrec->name);
                continue;
            }

            if (!functionp(regrec->get_all_regions) || !regrec->get_all_regions) {
                rec_item_missing("get_all_regions", regrec->name);
                continue;
            }

            if (!functionp(regrec->session_exists) || !regrec->session_exists) {
                rec_item_missing("session_exists", regrec->name);
                continue;
            }

            if (!functionp(regrec->get_sessions_area) || !regrec->get_sessions_area) {
                rec_item_missing("get_sessions_area", regrec->name);
                continue;
            }
            
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
private mapping(string:mapping(string:mapping(string:mixed))) _memory_storage = ([]);

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
//     function to delete a variable from a region. Synopsis below.
//
//  function expire_old; (mandatory)
//  synopsis: void expire_old(int curtime, int expiration_time);
//     called from a callout to expire aged sessions. Ran in a separate
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
private mapping memory_storage_registration_record = ([
    "name" : "Memory",
    "description" : "Memory-only storage of session data",
    "setup" : memory_setup,
    "store" : memory_store,
    "retrieve" : memory_retrieve,
    "delete_variable" : memory_delete_variable,
    "expire_old" : memory_expire_old,
    "delete_session" : memory_delete_session,
    "get_region" : memory_get_region,
    "get_all_regions" : memory_get_all_regions,
    "session_exists" : memory_session_exists,
    "get_sessions_area" : memory_get_sessions_area
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
        _memory_storage->_sessions_ = ([]);
    }

    if (!sid)
        return;
    
    //
    // If storage for the passed session id doesn't exist, allocate it in
    // all the regions. At the same time, set up the id->misc->gsession mapping
    //
    if (!id->misc->gsession)
        id->misc->gsession = ([]);
    
    foreach(indices(_memory_storage), string region) {
        if (!_memory_storage[region][sid])
            _memory_storage[region][sid] = ([
                "data" : ([])
            ]);
        
        if (!id->misc->gsession[region])
            id->misc->gsession[region] = _memory_storage[region][sid];
    }
    
    if (!_memory_storage->_sessions_[sid])
        _memory_storage->_sessions_[sid] = ([
            "nocookies" : 0,
            "cookieattempted" : 0,
            "lastused" : time()
        ]);
}

//
// Store a variable in the indicated region for the passed session ID.
//
private void memory_store(object id, string key, mixed data, string sid, void|string reg)
{
    string    region = reg || "session";
    int       t = time();    

    _memory_storage["_sessions_"][sid]->lastused = t;
    
    if (memory_validate_storage(region, sid, "memory_storage") < 0)
        return;

    _memory_storage[region][sid]->data += ([
        key : data
    ]);

    _memory_storage["_sessions_"][sid]->lastchanged = t;
}

//
// Retrieve a variable from the indicated region
//
private mixed memory_retrieve(object id, string key, string sid, void|string reg)
{
    string    region = reg || "session";
    int       t = time();

    _memory_storage["_sessions_"][sid]->lastused = t;
    
    if (memory_validate_storage(region, sid, "memory_retrieve") < 0)
        return 0;

    _memory_storage["_sessions_"][sid]->lastused = time();
    
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

    _memory_storage["_sessions_"][sid]->lastused = t;
    
    if (memory_validate_storage(region, sid, "memory_delete_variable") < 0)
        return 0;

    if (_memory_storage[region][sid][key]) {
        mixed val = _memory_storage[region][sid][key]->data;
        m_delete(_memory_storage[region][sid], key);

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
    foreach(indices(_memory_storage), string region)
        m_delete(_memory_storage[region], sid);
}

private void memory_expire_old(int curtime)
{
#ifdef THREADS
    gc_key = gc_lock->lock();
#endif

    foreach(indices(_memory_storage), string region) {
        foreach(indices(_memory_storage[region]), string sid) {
            if (curtime - _memory_storage["_sessions_"][sid]->lastused > QUERY(expire)) {
                memory_delete_session(sid);
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

//
// Find out whether we have a session id available anywhere and/or create a
// new session if necessary. Returns a session id string.
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
    
#if constant(Mhash.hash_sha1)
    digest = Mhash.hash_sha1((string)(time()) + Crypto.randomness.reasonably_random()->read(15));
#else
    object hash = Crypto.sha();

    hash->update((string)(time()));
    hash->update(Crypto.randomness.reasonably_random()->read(15));
    digest = hash->digest();
#endif
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
    mapping data;

    if (!cur_storage) {
        report_warning("gSession: cur_storage unset!\n");
        return;
    }
    
    data = cur_storage->get_region(id, id->misc->session_id, "session");

    if (data)
        id->misc->session_variables = data->data;
    else {
        report_warning("gSession: the 'session' region absent from storage '%s'\n",
                       cur_storage->name);
        id->misc->session_variables = ([]);
    }
    
    data = cur_storage->get_region(id, id->misc->session_id, "user");

    if (data)
        id->misc->user_variables = data->data;
    else {
        report_warning("gSession: the 'user' region absent from storage '%s'\n",
                       cur_storage->name);
        id->misc->user_variables = ([]);
    }
    
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

    if (sizeof(uri) >= 7 && uri[0..6] == "mailto:")
        return 1;
    
    if (search(uri, "://") < 0)
        return 0; // assuming it's a relative URI
    
    if (sizeof(uri) >= 7 && uri[0..6] == "http://")
        return 0;

    if (sizeof(uri) >= 8 && uri[0..7] == "https://")
        return 0;
    
    return 1;
}

string rewrite_uri(object id, string from, void|int append)
{
    int              hashpos;
    array(string)    parts;
    
    hashpos = search(from, "#");

    if (hashpos >= 0) {
        parts = from / "#";
        if (parts[0] == "")
            parts[0] = id->raw_url;
    }
    
    if (!append) {
        if (hashpos >= 0)
            return sprintf("%s?%s=%s#%s", parts[0], SVAR, id->misc->session_id, parts[1]);
        else
            return sprintf("%s?%s=%s", from, SVAR, id->misc->session_id);
    } else {
        if (hashpos >= 0)
            return sprintf("%s&%s=%s#%s", parts[0], SVAR, id->misc->session_id, parts[1]);
        else
            return sprintf("%s&%s=%s", from, SVAR, id->misc->session_id);
    }
}

mixed container_a(string tag, mapping args, string contents, object id, mapping defines)
{
    string   query;
    mapping  hvars = ([]);

    if (id->misc->session_id && args && !args->norewrite && args->href && !leave_me_alone(args->href)) {
        if (sscanf(args->href, "%*s?%s", query) == 2)
            Caudium.parse_query_string(query, hvars);
        
        if (!hvars[SVAR] && (!id->misc->_gsession_cookie || (id->misc->_gsession_cookie && !QUERY(cookienorewrite))))
            if (!sizeof(hvars))
                args->href = rewrite_uri(id,  args->href);
            else
                args->href = rewrite_uri(id,  args->href, 1);
    }
    
    return ({ make_container("a", args, parse_rxml(contents, id)) });
}

mixed container_form(string tag, mapping args, string contents, object id, mapping defines)
{
    if (args && !args->norewrite && id->misc->session_id)
        contents = sprintf("<input type=\"hidden\" name=\"%s\" value=\"%s\">",
                           SVAR, id->misc->session_id) + contents;
    
    return ({ make_container("form", args, parse_rxml(contents, id)) });
}
