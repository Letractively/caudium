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

constant module_type = MODULE_PARSER | MODULE_PROVIDER | MODULE_LOCATION | MODULE_EXPERIMENTAL;
constant module_name = "G's Session Module";
constant module_doc  = "This is an implementation of an (optionally) cookie-less session tracking module.";
constant module_unique = 1;
constant thread_safe = 1;

#define CACHE "_gsession_stronghold_"
#define SVAR QUERY(svarname)

#ifdef THREADS
private object counter_lock = Thread.Mutex();
private mixed  counter_key;

private object gc_lock = Thread.Mutex();
private mixed  gc_key;
#endif

private Regexp dcookie_rx = Regexp("^[0-9.]+$");
    
//
// Keeps the count of sessions allocated so far.
// This is used to append to the sha1 "cookie" generated in the start
// function. That thing, in turn, should be pretty much unique accross the
// persistent sessions. Since Pike 7.2+ supports very, veeeeery big
// integers, we have enough unique numbers till the end of this millenium.
//
private int session_counter;

//
// This is the session base hash. Counter above is appended to it for new
// sessions. It is generated in the start() function and doesn't change
// during the module's life span unless ordered so by the administrator
// using the admin interface.
//
private string session_hash = "";

//
// All registered storage plugins
//
private mapping(string:mapping(string:mixed)) storage_plugins = ([]);
private mapping cur_storage = 0;

string status()
{
    string ret = "Status? What status?! Buzz off, I want to sleep! And seriously:<br><blockquote>";

    ret += sprintf("<table border='1'><tr><td><strong>Base hash</strong></td><td>%s</td></tr>"
                   "<tr><td><strong>Cookie/variable name</strong></td><td>%s</td></tr>"
                   "</table></blockquote>", session_hash,  SVAR);

    return ret;
}

void start(int num, object conf)
{
#if constant(Crypto.sha)
    object hash = Crypto.sha();

    hash->update(sprintf("%d", time()));
#if constant(Crypto.randomness.reasonably_random)
    hash->update(Crypto.randomness.reasonably_random()->read(15));
#endif
    session_hash = replace(MIME.encode_base64(hash->digest()), ({"+","/","="}), ({"_","|","-"}));
#else
    throw(({"No Crypto.sha found!", backtrace()}));
#endif
    
    session_counter = cache_lookup(CACHE, "session_counter");

    cache_expire(CACHE);

    register_plugins(conf);
    
    //
    // schedule a gc callout
    //
    if (QUERY(dogc))
        call_out(co_session_gc, QUERY(expire) / 2);
}

void stop()
{
    // it might be a reload, save what's valuable
    cache_clear(CACHE);
    cache_set(CACHE, "session_counter", session_counter);
}

void create()
{
    register_plugins(); // just the memory one, actually...
    cur_storage = storage_plugins->Memory;
    
    defvar( "mountpoint", "/gsadmin", "Administrative mountpoint", TYPE_STRING,
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

    defvar("expire", 600, "Session expiration Time", TYPE_INT,
           "After how many seconds an unactive session is removed", 0, hide_gc);

    defvar("dogc", 1, "Garbage Collection", TYPE_FLAG,
           "If set, then the sessions will expire automatically after the "
           "given period. If unset, session expiration must be done elsewhere.");
}

int hide_gc ()
{
    return (!QUERY(dogc));
}

mixed find_file ( string path, object id )
{
    return http_string_answer("Nothing here... yet.");
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
        "user_variable" : tag_variables
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
void co_session_gc() 
{
    if (!cur_storage) {
        if (QUERY(dogc))
            call_out(co_session_gc, QUERY(expire) / 2);
        return;
    }

#ifdef THREADS
    Thread.thread_create(cur_storage->expire, time(), QUERY(expire));
#else
    cur_storage->expire(time());
#endif
    
    if (QUERY(dogc))
        call_out(co_session_gc, QUERY(expire) / 2);
}

private void gsession_set_cookie(object id, string sid) {
    string Cookie = SVAR + "=" + sid + "; path=/";

    if(QUERY(domaincookies)) 
        if (!(dcookie_rx->match((string)id->misc->host)))
            Cookie += ";domain=."+(((string)id->misc->host / ".")[(sizeof((string)id->misc->host / ".")-2)..]) * ".";
    
    if (query ("cookieexpire") > 0)
        Cookie += "; Expires=" + http_date(time()+query("cookieexpire")) +";";
    if (query ("cookieexpire") < 0)
        Cookie += "; Expires=Fri, 31 Dec 2010 23:59:59 GMT;";
    if (query ("secure"))
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
    report_notice("gSession: providers = %O\n", sproviders);
    
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
            
            if (storage_plugins[regrec->name])
                report_warning("gSession: duplicate plugin '%s'\n", regrec->name);
            
            storage_plugins[regrec->name] = regrec;
        }
    }

    defvar("splugin", "Memory", "Storage: default storage module", TYPE_STRING_LIST,
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
// The structure is as follows:
//
//  storage_mapping
//      region1_name:region1_mapping
//         session1_id:session2_data
//           key1_name:key1_value
//           key2_name:key2_value
//           ...
//         session2_id:session2_data
//           key1_name:key1_value
//           key2_name:key2_value
//           ...
//      region2_name:region2_mapping
//         session1_id:session2_data
//           key1_name:key1_value
//           key2_name:key2_value
//           ...
//         session2_id:session2_data
//           key1_name:key1_value
//           key2_name:key2_value
//           ...
//
// Two predefined regions exist, for compatibility with 123sessions:
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
//     function to setup the plugin. Called once for every
//     request. Synopsis below.
//
//  function store; (mandatory)
//     function to store a variable into a region. Synopsis below.
//
//  function retrieve; (mandatory)
//     function to retrieve a variable from a region. Synopsis below.
//
//  function delete_variable; (mandatory)
//     function to delete a variable from a region. Synopsis below.
//
//  function expire_old; (mandatory)
//     called from a callout to expire aged sessions. Ran in a separate
//     thread, if available.
//
//  function delete_session; (mandatory)
//     delete a session from all the regions of the storage.
//
// Function synopses:
//
//   void setup(object id, string sid);
//   void store(object id, string key, mixed data, string sid, void|string reg);
//   mixed retrieve(object id, string key, string sid, void|string reg);
//   mixed delete_variable(object id, string key, string sid, void|string reg);
//   void expire_old(int curtime, int expiration_time);
//   void delete_session(sid);
//
private mapping memory_storage_registration_record = ([
    "name" : "Memory",
    "description" : "Memory-only storage of session data",
    "setup" : memory_setup,
    "store" : memory_store,
    "retrieve" : memory_retrieve,
    "delete_variable" : memory_delete_variable,
    "expire_old" : memory_expire_old,
    "delete_session" : memory_delete_session
]);

//
// Validate region+session storage. Report an error if anything's wrong.
//
private int memory_validate_storage(string reg, string sid) 
{
    if (!_memory_storage[reg]) {
        // To throw (up) or not to throw (up) - that is the question...
        report_error("gSession: Fugazi! No memory storage for region '%s'!", reg);
        return -1;
    }

    if (!_memory_storage[reg][sid]) {
        // To throw (up) or not to throw (up) - that is the question...
        report_error("gSession: Fugazi! No session storage for region '%s' and session '%s'!", reg, sid);
        return -1;
    }

    return 0; // phew, everything's fine :)
}

//
// Set up storage of the session. If storage for given session ID already
// exists, simply point the id->misc variables to it.
//
private void memory_setup(object id, string sid) 
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
    }

    //
    // If storage for the passed session id doesn't exist, allocate it in
    // all the regions. At the same time, set up the id->misc->gsession mapping
    //
    if (!id->misc->gsession)
        id->misc->gsession = ([]);
    
    foreach(indices(_memory_storage), string region) {
        if (!_memory_storage[region][sid])
            _memory_storage[region][sid] = ([]);
        
        if (!id->misc->gsession[region])
            id->misc->gsession[region] = _memory_storage[region][sid];
    }

    //
    // Compat variables
    //
    id->misc->session_id = sid;
    id->misc->session_variables = _memory_storage->session[sid];
    id->misc->user_variables = _memory_storage->user[sid];
}

//
// Store a variable in the indicated region for the passed session ID.
//
private void memory_store(object id, string key, mixed data, string sid, void|string reg)
{
    string    region = reg || "session";

    if (memory_validate_storage(region, sid) < 0)
        return;

    _memory_storage[region][sid] += ([
        key : ([
            "lastused" : time(),
            "data" : data
        ])
    ]);
}

//
// Retrieve a variable from the indicated region
//
private mixed memory_retrieve(object id, string key, string sid, void|string reg)
{
    string    region = reg || "session";

    if (memory_validate_storage(region, sid) < 0)
        return 0;

    if (!_memory_storage[region][sid][key])
        return 0;


    _memory_storage[region][sid][key]->lastused = time();
    return _memory_storage[region][sid][key]->data;
}

//
// Remove a variable from the indicated region and return its value to the
// caller.
//
private mixed memory_delete_variable(object id, string key, string sid, void|string reg)
{
    string    region = reg || "session";

    if (memory_validate_storage(region, sid) < 0)
        return 0;

    if (_memory_storage[region][sid][key]) {
        mixed val = _memory_storage[region][sid][key]->data;
        m_delete(_memory_storage[region][sid], key);
        
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
            if (curtime - _memory_storage[region][sid]->lastused > QUERY(expire)) {
                memory_delete_session(sid);
            }
        }
    }
#ifdef THREADS
    destruct(gc_key);
#endif
}

//
// Find out whether we have a session id available anywhere and/or create a
// new session if necessary. Returns a session id string.
//
private string alloc_session(object id)
{
    string    ret = "";
    int       sesstag;

    id->misc->_gsession_is_here = 0;
    
    string   sp = QUERY(splugin);
    if (!storage_plugins[sp])
        throw(({
            sprintf("gSessions: something seriously broken! Storage plugin '%s' on in the registry!\n",
                    sp),
            backtrace()
        }));

    cur_storage = storage_plugins[sp];
    
    if (id->variables[SVAR]) {
        if (id->cookies[SVAR] && id->cookies[SVAR] != id->variables[SVAR])
            gsession_set_cookie(id, id->variables[SVAR]);
        id->misc->session_id = id->variables[SVAR];
    }

    if (id->cookies[SVAR] && sizeof(id->cookies[SVAR])) {
        id->misc->session_id = id->cookies[SVAR];
        id->misc->_gsession_cookie = 1;
    }
    
    if (id->misc->session_id) {
        cur_storage->setup(id, id->misc->session_id);
        id->misc->_gsession_is_here = 1;
        return id->misc->session_id;
    }
    
    //
    // new session it seems
    //
#ifdef THREADS
    catch { counter_key = counter_lock->lock(); };
#endif
    sesstag = ++session_counter;
#ifdef THREADS
    if (counter_key)
        destruct(counter_key);
#endif
    
    ret = sprintf("%s%d", session_hash, session_counter);
    cur_storage->setup(id, ret);

    id->misc->_gsession_is_here = 1;
    id->misc->session_id = ret;
    gsession_set_cookie(id, ret);
    
    return ret;
}

//
// tags below
//

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

    alloc_session(id);
    
    string region;
    if (tag == "session_variable")
        region = "session";

    if (tag == "user_variable")
        region = "user";
    
    if (args->value) {
        cur_storage->store(id, args->variable, args->value, id->misc->session_id, region);
        return "";
    } else {
        return cur_storage->retrieve(id, args->variable, id->misc->session_id, region);
    }
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
    if (!append)
        return sprintf("%s?%s=%s", from, SVAR, id->misc->session_id);
    else
        return sprintf("%s&%s=%s", from, SVAR, id->misc->session_id);
}

mixed container_a(string tag, mapping args, string contents, object id, mapping defines)
{
    string   query;
    mapping  hvars = ([]);

    alloc_session(id);
    
    if (args && args->href && !leave_me_alone(args->href)) {
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
    string   query;
    mapping  hvars = ([]);
    int      do_hidden = 1;
    
    alloc_session(id);
    
    if (args && args->action && !leave_me_alone(args->action)) {
        if (!args->method || (args->method && lower_case(args->method) != "post")) {
            if (sscanf(args->action, "%*s?%s", query) == 2)
                Caudium.parse_query_string(query, hvars);

            if (!hvars[SVAR] && (!id->misc->_gsession_cookie || (id->misc->_gsession_cookie && !QUERY(cookienorewrite)))) {
                if (!sizeof(hvars))
                    args->action = rewrite_uri(id, args->action);
                else
                    args->action = rewrite_uri(id, args->action, 1);
                do_hidden = 0;
            }
        }
    }

    if (do_hidden)
        contents = sprintf("<input type='hidden' name='%s' value='%s'>",
                           SVAR, id->misc->session_id) + contents;
    
    return ({ make_container("form", args, parse_rxml(contents, id)) });
}
