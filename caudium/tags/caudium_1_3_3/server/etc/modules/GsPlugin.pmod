/* Dear Emacs, this file is written in -*-pike-*-
 *
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
 * $Id$
 */

/*
 * The Gsession module and the accompanying code is Copyright © 2002 Davies, Inc.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   Marek Habersack <grendel@caudium.net> (core module)
 *   Chris Davies <mcd@daviesinc.com> (SQL plugins)
 *
 */

inherit "caudiumlib";

//
//! This module is meant to be inherited by the storage plugins for the
//! gsession module. It actually implements the basic, memory, plugin albeit
//! without few functions required for making your plugin unique. Your
//! module may re-implement all/any of the methods or call up to the ones
//! defined below using the ::plugin_*(...) syntax.
//! The module implementing the storage plugin must be marked as a provider
//! module (MODULE_PROVIDER). In the simplest form you only need to
//! implement the following methods to have a working storage plugin:
//! @pre{
//!   plugin_name
//!   plugin_expire_old
//! @}
//! Without these methods, the plugin will not be registered.

//
//! Your plugin must return a string here. Otherwise the plugin won't be
//! registered by the core module.
private string plugin_name()
{
    return 0;
}

//! Your plugin may return a string here.
private string plugin_description()
{
    return 0;
}

//////////////////////////
// PLUGIN STORAGE
//

//
//! This is the plugin, in-memory, storage medium. As opposite to other
//! storage mechanism, this one is built in albeit using the same interface
//! as the other mechanisms. All storage plugins must provide interface to
//! in-memory storage structured in the way described below. This is
//! required as the external code which uses the gsession module using the
//! provider API as well as the core module itself, don't know the actual
//! storage medium/structures provided by the plugin. It is extremely
//! important that the structure and meaning of fields described below is
//! maintained accross all the storage plugins.
//!
//! The structure is as follows:
//!
//! @mapping
//!    @member mapping "_sessions_"
//!     @tt{_sessions_@} is a literal name. The format:
//!
//!     @mapping
//!      @member int "nocookies"
//!       1 if no cookies should be set, 0 if cookies are ok
//!      @member int "lastused"
//!       time when last used
//!      @member int "lastchanged"
//!       time of last store or delete
//!      @member int "lastretrieved"
//!       time of last retrieve
//!      @member int "cookieattempted"
//!       1 if a cookie set was attempted
//!      @member int "ctime"
//!       creation time
//!     @endmapping
//!    @member mapping "region1_name"
//!     @tt{region1_name@} is a region variable name. The format:
//!
//!     @mapping
//!      @member mapping "session1_id"
//!       @tt{session1_id@} is a variable session ID value. The format:
//!
//!       @mapping
//!        @member mapping "data"
//!         @mapping
//!          @member mixed "key1_name"
//!          @member mixed "key2_name"
//!         @endmapping
//!       @endmapping
//!     @endmapping
//! @endmapping
//!
//! Two predefined regions MUST exist, for compatibility with 123sessions:
//! "session" and "user" they are available through the
//! id->misc->session_variables and id->misc->user_variables,
//! respectively. All regions are available through the
//! id->misc->gsession->region_name mapping. This is true for all the
//! storage mechanisms.
//!
static mapping(string:mapping(string:mapping(string:mixed))) _plugin_storage = ([]);

//
//! Registration record for the "plugin". Such record is used for all the
//! storage plugins, including this one for consistency. All plugins are
//! required to provide just one function - register_gsession_plugin - that
//! returns a mapping whose contents is described below:
//!
//! @mapping
//!  @member string "name"
//!   @b{mandatory@}
//!
//!   plugin name (displayed in the CIF and the admin interface)
//!
//! @member string "description"
//!  @b{optional@} plugin description
//!
//! @member function "setup"
//!  @b{mandatory@}
//!
//!  @tt{void setup(object id, string|void sid);@}
//!
//!  function to setup the plugin. Called once for every
//!  request. If sid is absent, the function is required just to make
//!  sure the storage exists and exit. If sid is present, a new area for
//!  the given session must be created in every region.
//!
//! @member function "store"
//!  @b{mandatory@}
//!
//!  @tt{void store(object id, string key, mixed data, string sid, void|string reg);@}
//!
//!  function to store a variable into a region.
//!
//! @member function "retrieve"
//!  @b{mandatory@}
//!
//!  @tt{mixed retrieve(object id, string key, string sid, void|string reg);@}
//! 
//!  function to retrieve a variable from a region.
//!
//! @member function "delete_variable"
//!  @b{mandatory@}
//!
//!  @tt{mixed delete_variable(object id, string key, string sid, void|string reg);@}
//!
//!  function to delete a variable from a region. Synopsis below.
//!
//! @member function "expire_old"
//!  @b{mandatory@}
//!
//!  @tt{void expire_old(int curtime, int expiration_time);@}
//!
//!  called from a callout to expire aged sessions. Ran in a separate
//!  thread, if available.
//!
//! @member function "delete_session"
//!  @b{mandatory@}
//!
//!  @tt{void delete_session(string sid);@}
//!
//!  delete a session from all the regions of the storage.
//!
//! @member function "get_region"
//!  @b{mandatory@}
//!
//!  @tt{mapping get_region(object id, string sid, string reg);@}
//!
//!  return a storage mapping of the specified region. This function
//!  @b{must@} return valid mappings for the "session" and "user" regions
//!  (compatibility with 123sessions)
//!
//! @member function "get_all_regions"
//!  @b{mandatory@}
//!
//!  @tt{mapping get_all_regions(object id);@}
//!
//!  returns a mapping of all the regions in use - i.e. full storage.
//!
//! @member function "session_exists"
//!  @b{mandatory@}
//!
//!  @tt{int session_exists(object id, string sid);@}
//!
//!  checks whether the given session exists in the storage
//!
//! @member function "get_sessions_area"
//!  @b{mandatory@}
//!
//!  @tt{mapping get_sessions_area(object id);@}
//!
//!  returns the special '_sessions_' area in the storage. That area
//!  stores all the options global to any session ID.
//! @endmapping
static mapping plugin_storage_registration_record = ([
    "name" : plugin_name(),
    "description" : plugin_description(),
    "setup" : plugin_setup,
    "store" : plugin_store,
    "retrieve" : plugin_retrieve,
    "delete_variable" : plugin_delete_variable,
    "expire_old" : plugin_expire_old,
    "delete_session" : plugin_delete_session,
    "get_region" : plugin_get_region,
    "get_all_regions" : plugin_get_all_regions,
    "session_exists" : plugin_session_exists,
    "get_sessions_area" : plugin_get_sessions_area
]);

//
//! Validate region+session storage. Report an error if anything's wrong.
//!
//! This routine should check whether the given region exists and contains
//! the specified session entry. @tt{fn@} can be used for error reporting. The
//! function is optional but it is recommended to call it in the prolog of
//! all the routines manipulating the storage in any way.
//!
//! @param reg
//!  The region name
//!
//! @param sid
//!  The session ID
//!
//! @param fn
//!  Error callback
//!
//! @returns
//!  @int
//!   @value 0
//!    everything's fine
//!   @value -1
//!    failure
//!  @endint
private int plugin_validate_storage(string reg, string sid, string|void fn) 
{
    if (!_plugin_storage[reg]) {
        // To throw (up) or not to throw (up) - that is the question...
        report_error("gSession: Fugazi! No in-memory storage for region '%s'! (called from '%s')\n", reg, fn);
        return -1;
    }

    if (!_plugin_storage[reg][sid]) {
        // To throw (up) or not to throw (up) - that is the question...
        report_error("gSession: Fugazi! No session storage for region '%s' and session '%s'! (called from '%s')\n", reg, sid || "", fn);
        return -1;
    }

    return 0; // phew, everything's fine :)    
}

//
//! Set up storage of the session. If storage for given session ID already
//! exists, simply point the id->misc variables to it. The plugin is
//! responsible for setting up the two legacy regions - "session" and
//! "user". They _must_ exist in every storage!
//! If 'sid' is NULL, the routine must only initialize its storage mapping.
//! The plugin must also create and populate the id->misc->gsession mapping
//! that contains a copy of all the regions for the current session. To
//! summarize:
//!
//!  On exit from this routine the following mappings must exist in the
//!  request id object:
//!
//!   id->misc->session_variables   = points to the 'data' member of the
//!                                   storage mapping for the "session"
//!                                   region of the given session id.
//!
//!   id->misc->user_variables      = points to the 'data' member of the
//!                                   storage mapping for the "user"
//!                                   region of the given session id.
//!
//!   id->misc->gsession            = mapping that contains all 'data'
//!                                   members of the regions found in the
//!                                   current session.
private void plugin_setup(object id, string|void sid) 
{
    if (!_plugin_storage || !sizeof(_plugin_storage)) {
        //
        // set up the compatibility regions. These are the only regions
        // that we create/use by default. All variables not specifically
        // destined for some named region end up in the "session" one.
        //
        _plugin_storage = ([]); // it might be 0
        _plugin_storage->session = ([]);
        _plugin_storage->user = ([]);
        _plugin_storage->_sessions_ = ([]);
    }

    if (!sid)
        return;
    
    //
    // If storage for the passed session id doesn't exist, allocate it in
    // all the regions. At the same time, set up the id->misc->gsession mapping
    //
    if (!id->misc->gsession)
        id->misc->gsession = ([]);
    
    foreach(indices(_plugin_storage), string region) {
        if (!_plugin_storage[region][sid])
            _plugin_storage[region][sid] = ([
                "data" : ([])
            ]);
        
        if (!id->misc->gsession[region])
            id->misc->gsession[region] = _plugin_storage[region][sid];
    }
    
    if (!_plugin_storage->_sessions_[sid])
        _plugin_storage->_sessions_[sid] = ([
            "nocookies" : 0,
            "cookieattempted" : 0,
            "lastused" : time()
        ]);
}

//
//! Store a variable in the indicated region for the passed session ID.
private void plugin_store(object id, string key, mixed data, string sid, void|string reg)
{
    string    region = reg || "session";
    int       t = time();    

    _plugin_storage["_sessions_"][sid]->lastused = t;
    
    if (plugin_validate_storage(region, sid, "plugin_storage") < 0)
        return;

    _plugin_storage[region][sid]->data += ([
        key : data
    ]);

    _plugin_storage["_sessions_"][sid]->lastchanged = t;
}

//
//! Retrieve a variable from the indicated region
private mixed plugin_retrieve(object id, string key, string sid, void|string reg)
{
    string    region = reg || "session";
    int       t = time();

    _plugin_storage["_sessions_"][sid]->lastused = t;
    
    if (plugin_validate_storage(region, sid, "plugin_retrieve") < 0)
        return 0;

    if (!_plugin_storage[region][sid]->data[key])
        return 0;

    _plugin_storage["_sessions_"][sid]->lastretrieved = t;
    
    return _plugin_storage[region][sid]->data[key];
}

//
//! Remove a variable from the indicated region and return its value to the
//! caller.
private mixed plugin_delete_variable(object id, string key, string sid, void|string reg)
{
    string    region = reg || "session";
    int       t = time();    

    _plugin_storage["_sessions_"][sid]->lastused = t;
    
    if (plugin_validate_storage(region, sid, "plugin_delete_variable") < 0)
        return 0;

    if (_plugin_storage[region][sid][key]) {
        mixed val = _plugin_storage[region][sid][key]->data;
        m_delete(_plugin_storage[region][sid], key);

        _plugin_storage["_sessions_"][sid]->lastchanged = t;
        return val;
    }

    return 0;
}

//
//! Delete the given session from all regions of the storage
private void plugin_delete_session(string sid)
{
    foreach(indices(_plugin_storage), string region)
        m_delete(_plugin_storage[region], sid);
}

//
//! This function must be implemented in your plugin - it is supposed to
//! both expire the sessions in your storage as well as in the
//! _plugin_storage.
private void plugin_expire_old(int curtime)
{}

private mapping plugin_get_region(object id, string sid, string reg)
{
    string    region = reg || "session";

    _plugin_storage["_sessions_"][sid]->lastused = time();
    
    if (plugin_validate_storage(region, sid, "plugin_get_region") < 0)
        return 0;

    return _plugin_storage[region][sid];
}

private mapping plugin_get_all_regions(object id)
{
    return _plugin_storage;
}

private int plugin_session_exists(object id, string sid)
{
    if (plugin_validate_storage("session", sid, "plugin_session_exists") < 0)
        return 0;

    return 1;
}

private mapping plugin_get_sessions_area(object id)
{
    if (_plugin_storage["_sessions_"])
        return _plugin_storage["_sessions_"];

    return 0;
}

mapping register_gsession_plugin()
{
    return plugin_storage_registration_record;
}

string query_provides()
{
    return "gsession_storage_plugin";
}
