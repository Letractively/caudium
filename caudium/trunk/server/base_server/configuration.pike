/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

constant cvs_version = "$Id$";
#include <module.h>
#include <caudium.h>
#ifdef PROFILE
mapping profile_map = ([]);
#endif

#define CATCH(X)  do { mixed err; if(err = catch{X;}) report_error(describe_backtrace(err)); } while(0)


#ifdef REQUEST_DEBUG
# define REQUEST_WERR(X) werror("CONFIG: "+X+"\n")
#else
# define REQUEST_WERR(X)
#endif

/* A configuration.. */

inherit Configuration;

inherit "caudiumlib14";
inherit "logformat";

public string real_file(string file, object id);


function store = caudium->store;
function retrieve = caudium->retrieve;
function remove = caudium->remove;
function do_dest = caudium->do_dest;
function create_listen_socket = caudium->create_listen_socket;

//! the parser module for this configuration
object   parse_module;

//! the content-types module for this configuration
object   types_module;

//! the master authentication module for this configuration 
object   auth_module;

//! the directory listing module for this configuration
object   dir_module;

//! the content-type function from the types_module
function types_fun;

//! the authentication function from the authentication module
function auth_fun;

//! the name for the configuration
string name;

/* Since the main module (Roxen, formerly Spinner, alias spider), does
 * not have any clones its settings must be stored somewhere else.
 * This looked like a likely spot.. :)
 */
mapping variables = ([]); 

//! Retrieve (query) a variable from the configuration variable store.
//!
//! @param var
//!  Variable name
//!
//! @returns
//!  The variable value
public mixed query(string var)
{
  if(var && variables[var])
    return variables[var][ VAR_VALUE ];
  if(!var) return variables;
  error("query("+var+"): Unknown variable.\n");
}

//! Set the variable value for a variable in the configuration variable
//! store.
//!
//! @param var
//!  The variable name
//!
//! @param val
//!  The value to be assigned to the variable.
//!
//! @returns
//!  The value assigned to the function
mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  perror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var])
  {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  }
  error("set("+var+"). Unknown variable.\n");
}

int setvars( mapping (string:mixed) vars )
{
  string v;
//  perror("Setting variables to %O\n", vars);
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

//! Kill a variable.
void killvar(string name)
{
  m_delete(variables, name);
}

static class ConfigurableWrapper
{
  int mode;
  function f;
  int check()
  {
    if ((mode & VAR_EXPERT) &&
        (!caudium->configuration_interface()->expert_mode)) {
      return 1;
    }
    if ((mode & VAR_MORE) &&
        (!caudium->configuration_interface()->more_mode)) {
      return 1;
    }
    return(f());
  }
  void create(int mode_, function f_)
  {
    mode = mode_;
    f = f_;
  }
};

//! Create a Defvar for Configuration interface
int defvar(string var, mixed value, string name, int type,
           string|void doc_str, mixed|void misc,
           int|function|void not_in_config)
{
  variables[var]                      = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]         = value;
  variables[var][ VAR_TYPE ]          = type & VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]       = doc_str;
  variables[var][ VAR_NAME ]          = name;
  variables[var][ VAR_MISC ]          = misc;
  
  type &= ~VAR_TYPE_MASK;   // Probably not needed, but...
  type &= (VAR_EXPERT | VAR_MORE);
  if (functionp(not_in_config)) {
    if (type) {
      variables[var][ VAR_CONFIGURABLE ] = ConfigurableWrapper(type, not_in_config)->check;
    } else {
      variables[var][ VAR_CONFIGURABLE ] = not_in_config;
    }
  } else if (type) {
    variables[var][ VAR_CONFIGURABLE ] = type;
  } else if(intp(not_in_config)) {
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  }

  variables[var][ VAR_SHORTNAME ] = var;
}

//!
int definvisvar(string var, mixed value, int type)
{
  return defvar(var, value, "", type, "", 0, 1);
}

//!
string query_internal_location(object|void mod)
{
  return QUERY(InternalLoc)+(mod? replace(otomod[mod]||"", "#", "!")+"/":"");
}

//!
string query_name()
{
  if(strlen(QUERY(name))) return QUERY(name);
  return name;
}

//!
string comment()
{
  return QUERY(comment);
}

//!
class Priority 
{
  array (object) url_modules = ({ });
  array (object) logger_modules = ({ });
  array (object) location_modules = ({ });
  array (object) filter_modules = ({ });
  array (object) last_modules = ({ });
  array (object) first_modules = ({ });
  array (object) precache_modules = ({ });
  array (object) error_modules = ({ }); 
  
  mapping (string:array(object)) extension_modules = ([ ]);
  mapping (string:array(object)) file_extension_modules = ([ ]);
  mapping (object:multiset) provider_modules = ([ ]);


  void stop()
  {
    foreach(url_modules, object m)               CATCH(m->stop && m->stop());
    foreach(logger_modules, object m)            CATCH(m->stop && m->stop());
    foreach(filter_modules, object m)            CATCH(m->stop && m->stop());
    foreach(location_modules, object m)          CATCH(m->stop && m->stop());
    foreach(last_modules, object m)              CATCH(m->stop && m->stop());
    foreach(first_modules, object m)             CATCH(m->stop && m->stop());
    foreach(precache_modules, object m)          CATCH(m->stop && m->stop());
    foreach(indices(provider_modules), object m) CATCH(m->stop && m->stop());
    foreach(error_modules, object m)             CATCH(m->stop && m->stop());
  }
}



//! A 'pri' is one of the ten priority objects. Each one holds a list
//! of modules for that priority. They are all merged into one list for
//! performance reasons later on.
array (object) allocate_pris()
{
  int a;
  array (object) tmp;
  tmp=allocate(10);
  for(a=0; a<10; a++)  tmp[a]=Priority();
  return tmp;
}

#ifndef __AUTO_BIGNUM__
//!
class Bignum {
#if constant(Gmp.mpz) // Perfect. :-)
  object gmp = Gmp.mpz();
  float mb()
  {
    return (float)(gmp/1024)/1024.0;
  }

  object `+(int i)
  {
    gmp = gmp+i;
    return this_object();
  }

  object `-(int i)
  {
    gmp = gmp-i;
    return this_object();
  }

  mixed cast(string what) {
    switch(what) {
        case "int":
          return (int)gmp;
        case "float":
          return (float)gmp;
        case "string":
          return (string)gmp;
    }
  }
#else
  int msb;
  int lsb=-0x7ffffffe;

  object `-(int i);
  object `+(int i)
  {
    if(!i) return this_object();
    if(i<0) return `-(-i);
    object res = object_program(this_object())(lsb+i,msb,2);
    if(res->lsb < lsb) res->msb++;
    return res;
  }

  object `-(int i)
  {
    if(!i) return this_object();
    if(i<0) return `+(-i);
    object res = object_program(this_object())(lsb-i,msb,2);
    if(res->lsb > lsb) res->msb--;
    return res;
  }

  float mb()
  {
    return ((((float)lsb/1024.0/1024.0)+2048.0)+(msb*4096.0));
  }

  void create(int|void num, int|void bnum, int|void d)
  {
    if(!d)
      lsb = num-0x7ffffffe;
    else
      lsb = num;
    msb = bnum;
  }
#endif
}
#endif


//! Request used for debug and statistics info only
int requests;

//! Protocol specific statistics.
mapping(string:mixed) extra_statistics = ([]);

//! Even more protocol specific statistics
mapping(string:mixed) misc = ([]); 

#ifdef __AUTO_BIGNUM__
int sent, hsent, received;
#else
//! Sent data
object sent=Bignum();

//! Sent headers
object hsent=Bignum();

//! Received data
object received=Bignum();
#endif
object this = this_object();


// Used to store 'parser' modules before the main parser module
// is added to the configuration.
private array(object) _toparse_modules = ({});

//! Will write a line to the log-file. This will probably be replaced
//! entirely by log-modules in the future, since this would be much
//! cleaner.
int|function log_function;

//! The last time an item was logged. Used to determine if the log file
//! descriptor should be closed 
int last_log_time;

// The logging format used. This will probably move the the above
// mentioned module in the future.
private mapping (string:string) log_format = ([]);

//! The objects for each logging format. Each of the objects has the function
//! format_log which takes the file and id object as arguments and returns
//! a formatted string. the hashost variable is 1 if there is a $host that
//! needs to be resolved.
mapping (string:object) log_format_objs = ([]);


// A list of priority objects (used like a 'struct' in C, really)
private array (object) pri = allocate_pris();

// All enabled modules in this virtual server.
// The format is "module":([ module_info ])
public mapping (string:mapping(string:mixed)) modules = ([]);

// A mapping from objects to module names
public mapping (object:string) otomod = ([]);


// Caches to speed up the handling of the module search.
// They are all sorted in priority order, and created by the functions
// below.
private array (function) url_module_cache, last_module_cache, error_module_cache;
private array (function) logger_module_cache, first_module_cache;
private array (function) filter_module_cache, precache_module_cache;
private array (array (string|function)) location_module_cache;
private mapping (string:array (function)) extension_module_cache=([]);
private mapping (string:array (function)) file_extension_module_cache=([]);
private mapping (string:array (object)) provider_module_cache=([]);


//! Call stop in all modules.
void stop()
{
  CATCH(parse_module && parse_module->stop && parse_module->stop());
  CATCH(types_module && types_module->stop && types_module->stop());
  CATCH(auth_module && auth_module->stop && auth_module->stop());
  CATCH(dir_module && dir_module->stop && dir_module->stop());
  for(int i=0; i<10; i++) CATCH(pri[i] && pri[i]->stop && pri[i]->stop());
}

//! returns the content-type for the given filename. if "to" is set,
//! then returns the content-encoding as well.
//! ok, so this fun changes according to the new MODULE_TYPE API.
//! basically, from now on this is just a dummy function. the old one tried to play voodoo magic
//! with data it didn't really have, so...
public array|string type_from_filename( string file, int|void to ) {
  object current_configuration;

  // the defaultest (grah) content-type and content-encoding. never ever EVER dare to change this, or else...
  array retval = ({ "application/octet-stream", 0 });

  if( !types_fun )
    return to ? retval : retval[ 0 ];

//   while(file[-1] == '/') 
//     file = file[0..strlen(file)-2]; // Security patch? 

  retval = types_fun( file );
  // hmm, all else is being taken care of inside types_fun...
  return to ? retval : retval[ 0 ];
}

//! Return an array with all provider modules that provides "provides".
//! @fixme
//!   Is there any way to clear this cache ? (grubba 1998-05-28)
//!   Yes, it is zapped together with the rest in invalidate_cache()
array (object) get_providers(string provides)
{
  if(!provider_module_cache[provides])
  { 
    int i;
    provider_module_cache[provides]  = ({ });
    for(i = 9; i >= 0; i--)
    {
      foreach(indices(pri[i]->provider_modules), object d) 
        if(pri[i]->provider_modules[ d ][ provides ]) 
          provider_module_cache[provides] += ({ d });
    }
  }
  return provider_module_cache[provides];
}

//! Return the first provider module that provides "provides".
object get_provider(string provides)
{
  array (object) prov = get_providers(provides);
  if(sizeof(prov))
    return prov[0];
  return 0;
}

//! map the function "fun" over all matching provider modules.
array(mixed) map_providers(string provides, string fun, mixed ... args)
{
  array (object) prov = get_providers(provides);
  array error;
  array a=({ });
  mixed m;
  foreach(prov, object mod) 
  {
    if(!objectp(mod))
      continue;
    if(functionp(mod[fun])) 
      error = catch(m=mod[fun](@args));
    if(arrayp(error)) {
      error[0] = "Error in map_providers(): "+error[0];
      roxen_perror(describe_backtrace(error));
    }
    else
      a += ({ m });
    error = 0;
  }
  return a;
}

//! map the function "fun" over all matching provider modules and
//! return the first positive response.
mixed call_provider(string provides, string fun, mixed ... args)
{
  foreach(get_providers(provides), object mod) {
    function f;
    if(objectp(mod) && functionp(f = mod[fun])) {
      mixed error;
      if (arrayp(error = catch {
        mixed ret;
        if (ret = f(@args)) {
          return(ret);
        }
      })) {
        error[0] = "Error in call_provider(): "+error[0];
        throw(error);
      }
    }
  }
}

//!
array (function) extension_modules(string ext, object id)
{
  if(!extension_module_cache[ext])
  { 
    int i;
    extension_module_cache[ext]  = ({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d = pri[i]->extension_modules[ext])
        foreach(d, p)
          extension_module_cache[ext] += ({ p->handle_extension });
    }
  }
  return extension_module_cache[ext];
}

//!
array (function) file_extension_modules(string ext, object id)
{
  if(!file_extension_module_cache[ext])
  { 
    int i;
    file_extension_module_cache[ext]  = ({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d = pri[i]->file_extension_modules[ext])
        foreach(d, p)
          file_extension_module_cache[ext] += ({ p->handle_file_extension });
    }
  }
  return file_extension_module_cache[ext];
}

//!
array (function) url_modules(object id)
{
  if(!url_module_cache)
  {
    int i;
    url_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->url_modules)
        foreach(d, p)
          url_module_cache += ({ p->remap_url });
    }
  }
  return url_module_cache;
}

//!
mapping api_module_cache = ([]);

//!
mapping api_functions(object id)
{
  return copy_value(api_module_cache);
}

//!
array (function) logger_modules(object id)
{
  if(!logger_module_cache)
  {
    int i;
    logger_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->logger_modules)
        foreach(d, p)
          if(p->log)
            logger_module_cache += ({ p->log });
    }
  }
  return logger_module_cache;
}

//!
array (function) last_modules(object id)
{
  if(!last_module_cache)
  {
    int i;
    last_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->last_modules)
        foreach(d, p)
          if(p->last_resort)
            last_module_cache += ({ p->last_resort });
    }
  }
  return last_module_cache;
}

//! Used for error modules
//!
//! @note
//!   Non RIS calls
array (function) error_modules(object id)
{
if(!error_module_cache)
  {  
    int i;
    error_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->error_modules)
        foreach(d, p)
          if(p->handle_error)
            error_module_cache += ({ p->handle_error });
    }  
  } 
  return error_module_cache;
}

//!
array (function) first_modules(object id)
{
  if(!first_module_cache)
  {
    int i;
    first_module_cache=({
    });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->first_modules) {
        foreach(d, p) {
          if(p->first_try) {
            first_module_cache += ({ p->first_try });
          }
        }
      }
    }
  }

  return first_module_cache;
}

//!
array (function) precache_modules(object id)
{
  if(!precache_module_cache)
  {
    int i;
    precache_module_cache = ({ });
    for(i = 9; i >= 0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->precache_modules) {
        foreach(d, p) {
          if(p->precache_rewrite) {
            precache_module_cache += ({ p->precache_rewrite });
          }
        }
      }
    }
  }
  return precache_module_cache;
}

//!
array location_modules(object id)
{
  if(!location_module_cache)
  {
    int i;
    array new_location_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->location_modules) {
        array level_find_files = ({});
        array level_locations = ({});
        foreach(d, p) {
          string location;
          // FIXME: Should there be a catch() here?
          if(p->find_file && (location = p->query_location())) {
            level_find_files += ({ p->find_file });
            level_locations += ({ location });
          }
        }
        sort(level_locations, level_find_files);
        int j;
        for (j = sizeof(level_locations); j--;) {
          // Order after longest path first.
          new_location_module_cache += ({ ({ level_locations[j],
                                             level_find_files[j] }) });
        }
      }
    }
    location_module_cache = new_location_module_cache;
  }
  return location_module_cache;
}

//!
array filter_modules(object id)
{
  if(!filter_module_cache)
  {
    int i;
    filter_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object p;
      array(object) d;
      if(d=pri[i]->filter_modules)
        foreach(d, p)
          if(p->filter)
            filter_module_cache+=({ p->filter });
    }
  }
  return filter_module_cache;
}

string cache_hostname=gethostname();

//!
int init_log_file(int|void force_open)
{
  int t = time(1);
  remove_call_out(init_log_file);
  
  if(functionp(log_function))
  {
    destruct(function_object(log_function)); 
    // Free the old one.
  }
  // Here we close the log file since it hasn't been used for
  // 'max_open_time' seconds, and we don't need it open, i.e
  // this open call is not from the logging.p
  if(!force_open && QUERY(max_open_time) && 
     (t - last_log_time) > QUERY(max_open_time)) {
    log_function = 0;
    return 0;
  }
  if(query("Log")) // Only try to open the log file if logging is enabled!!
  {
    mapping m = localtime(t);
    string logfile = QUERY(LogFile);
    m->year += 1900;  /* Adjust for years being counted since 1900 */
    m->mon++;   /* Adjust for months being counted 0-11 */
    if(m->mon < 10) m->mon = "0"+m->mon;
    if(m->mday < 10) m->mday = "0"+m->mday;
    if(m->hour < 10) m->hour = "0"+m->hour;
    logfile = replace(logfile,({"%d","%m","%y","%h","%H"}),
                      ({ (string)m->mday, (string)(m->mon),
                         (string)(m->year),(string)m->hour,cache_hostname}));
    if(strlen(logfile))
    {
      do {
        object lf=open( logfile, "wac");
        if(!lf) {
          Stdio.mkdirhier(logfile);
          if(!(lf=open( logfile, "wac"))) {
            report_error("Failed to open logfile. ("+logfile+")\n" +
                         "No logging will take place!\n");
            log_function=-1;
            return 0;
          }
        }
        log_function=lf->write; 
        // Function pointer, speeds everything up (a little..).
        lf=0;
      } while(0);
    } else {
      log_function=-1;
      return 0;
    }
    // Call out to this to reopen or close (if that feature is enabled)
    // the log file. reopening is done in case the file name has changed
    // or in case the file has been removed. A random(20) is added to avoid
    // getting ALL virtual servers calling this at the same time. Reopening
    // 500 files at once is expensive. :-)
    call_out(init_log_file, 60 + random(20));
    return 1;
  } else {
    log_function=-1;
    return 0;
  }
}

// Parse the logging format strings.
private inline string fix_logging(string s)
{
  string pre, post, c;
  sscanf(s, "%*[\t ]", s);
  s = replace(s, ({"\\t", "\\n", "\\r" }), ({"\t", "\n", "\r" }));

  // FIXME: This looks like a bug.
  // Is it supposed to strip all initial whitespace, or do what it does?
  //  /grubba 1997-10-03
  while(s[0] == ' ') s = s[1..];
  while(s[0] == '\t') s = s[1..];
  while(sscanf(s, "%s$char(%d)%s", pre, c, post)==3)
    s=sprintf("%s%c%s", pre, c, post);
  while(sscanf(s, "%s$wchar(%d)%s", pre, c, post)==3)
    s=sprintf("%s%2c%s", pre, c, post);
  while(sscanf(s, "%s$int(%d)%s", pre, c, post)==3)
    s=sprintf("%s%4c%s", pre, c, post);
  if(!sscanf(s, "%s$^%s", pre, post))
    s+="\n";
  else
    s=pre+post;
  return s;
}

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  log_format = ([]);
  log_format_objs = ([]);
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1) 
      log_format[(b/":")[0]] = fix_logging((b/":")[1..]*":");
  foreach(indices(log_format), string code) {
    string format = parse_log_format(log_format[code]);
    object formatter;
    if(catch(formatter = compile(format)()) || !formatter) {
      report_error(sprintf("Failed to compile log format // %s //.",
                           format));
    }
    log_format_objs[code] = formatter;
  }
}

// Really write an entry to the log.
private void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  else
    host = (host/" ")[0]; // In case it's an IP we don't want the port.
  if(fun) fun(replace(rest, "$host", host));
}

// Logging format support functions.
nomask private inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

nomask private inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

nomask private inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}
#ifdef THREADS
private object log_file_mutex = Thread.Mutex();
#endif

public void log(mapping file, object request_id)
{
//    _debug(2);
  string a;
  string form;
  object fobj;
  function f;

  foreach(logger_modules(request_id), f) // Call all logging functions
    if(f(request_id,file)) return;

  if(log_function == -1 || !request_id ||
     (QUERY(NoLog) && Caudium._match(request_id->remoteaddr, QUERY(NoLog))))
    return;
  if(!log_function) {
#ifdef THREADS
    object key = log_file_mutex->lock(1);
    // Second if to avoid call the function if it was already done by previous
    // locker, if any. 
    if(!log_function)
#endif
      init_log_file(1);
#ifdef THREADS
    destruct(key);
#endif
  }
  if(functionp(log_function)) {
    if(!(fobj = log_format_objs[(string)file->error]))
      if(!(fobj = log_format_objs["*"]))
        return; // no logging for this one.
    last_log_time = time(1);
    if(fobj->hashost)
      caudium->ip_to_host(request_id->remoteaddr, write_to_log,
                          fobj->format_log(file, request_id),
                          request_id->remoteaddr, log_function);
    else
      log_function(fobj->format_log(file, request_id));
  }
}

// These are here for statistics and debug reasons only.
public string status()
{
  float tmp;
  string res = "";
#ifdef __AUTO_BIGNUM__
  tmp = (sent/(float)(time(1)-caudium->start_time+1));
  res += sprintf("<table><tr align=right><td><b>Sent data:</b></td><td>%s"
                 "</td><td>%.2f Kbit/sec</td>",
                 Caudium.sizetostring(sent),tmp/128.0);
  
  res += sprintf("<td><b>Sent headers:</b></td><td>%s</td></tr>\n",
                 Caudium.sizetostring(hsent));
  
  tmp=(requests*600.0)/((time(1)-caudium->start_time)+1);

  res += sprintf("<tr align=right><td><b>Number of requests:</b></td>"
                 "<td>%8d</td><td>%.2f/min</td>"
                 "<td><b>Received data:</b></td><td>%s</td></tr>\n",
                 requests, tmp/10.0, Caudium.sizetostring(received));
#else
  if(!sent||!received||!hsent)
    return "Fatal error in status(): Bignum object gone.\n";

  tmp = (sent->mb()/(float)(time(1)-caudium->start_time+1));
  res += sprintf("<table><tr align=right><td><b>Sent data:</b></td><td>%.2fMB"
                 "</td><td>%.2f Kbit/sec</td>",
                 sent->mb(),tmp * 8192.0);
  
  res += sprintf("<td><b>Sent headers:</b></td><td>%.2fMB</td></tr>\n",
                 hsent->mb());
  
  tmp=(((float)requests*(float)600)/
       (float)((time(1)-caudium->start_time)+1));

  res += sprintf("<tr align=right><td><b>Number of requests:</b></td>"
                 "<td>%8d</td><td>%.2f/min</td>"
                 "<td><b>Received data:</b></td><td>%.2fMB</td></tr>\n",
                 requests, (float)tmp/(float)10, received->mb());
#endif
#ifdef ENABLE_RAM_CACHE
  if(datacache && (datacache->hits || datacache->misses)) {
    res += sprintf("<tr align=right><td><b>Cache Requests:</b></td>"
                   "<td>%d hits</td><td>%d misses</td></td>"
                   "<td><b>Cache Hitrate:</b></td>"
                   "<td>%.1f%%</td></tr>",
                   datacache->hits, datacache->misses,
                   datacache->misses ?
                   (datacache->hits / (float)(datacache->hits +
                                              datacache->misses))*100 :  100);
    
    res += sprintf("<tr align=right><td><b>Cache Utilization:</b></td>"
                   "<td>%s</td><td>%.1f%% free</td>"
                   "<td><b>Cache Entries:</b></td>"
                   "<td>%d</td></tr>",
                   Caudium.sizetostring(datacache->current_size),
                   ((datacache->max_size - datacache->current_size)/
                    (float)datacache->max_size)*100, sizeof(datacache->cache));
  }
#endif

  if (!zero_type(misc->ftp_users)) {
    tmp = (((float)misc->ftp_users*(float)600)/
           (float)((time(1)-caudium->start_time)+1));

    res += sprintf("<tr align=right><td><b>FTP users (total):</b></td>"
                   "<td>%8d</td><td>%.2f/min</td>"
                   "<td><b>FTP users (now):</b></td><td>%d</td></tr>\n",
                   misc->ftp_users, (float)tmp/(float)10, misc->ftp_users_now);
  }
  res += "</table><p>\n\n";

  if ((caudium->configuration_interface()->more_mode) &&
      (extra_statistics->ftp) && (extra_statistics->ftp->commands)) {
    // FTP statistics.
    res += "<b>FTP statistics:</b><br>\n"
      "<ul><table>\n";
    foreach(sort(indices(extra_statistics->ftp->commands)), string cmd) {
      res += sprintf("<tr align=right><td><b>%s</b></td>"
                     "<td align=right>%d</td><td> time%s</td></tr>\n",
                     upper_case(cmd), extra_statistics->ftp->commands[cmd],
                     (extra_statistics->ftp->commands[cmd] == 1)?"":"s");
    }
    res += "</table></ul>\n";
  }
  
  return res;
}

//! @deprecated
public array(string) userinfo(string u, object|void id)
{
  report_warning("Calls to conf->userinfo() are deprecated and may not exist in future releases of this software.\n");
  if(auth_module) return auth_module->userinfo(u);
  else report_warning(sprintf("userinfo(): No authorization module\n"
                              "%s\n", describe_backtrace(backtrace())));
}

//! @deprecated
public array(string) userlist(object|void id)
{
  report_warning("Calls to conf->userlist() are deprecated and may not exist in future releases of this software.\n");
  if(auth_module) return auth_module->userlist();
  else report_warning(sprintf("userlist(): No authorization module\n"
                              "%s\n", describe_backtrace(backtrace())));
}

//! @deprecated
public array(string) user_from_uid(int u, object|void id)
{
  report_warning("Calls to conf->user_from_uid() are deprecated and may not exist in future releases of this software.\n");
  if(auth_module)
    return auth_module->user_from_uid(u);
  else report_warning(sprintf("user_from_uid(): No authorization module\n"
                              "%s\n", describe_backtrace(backtrace())));
}

// Some clients does _not_ handle the magic 'internal-gopher-...'.
// So, lets do it here instead.
private mapping internal_gopher_image(string from)
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  from -= ".";
  // Disallow "internal-gopher-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  return (["file":open("caudium-images/dir/"+from+".gif","r"),
           "type":"image/gif"]);
}

private static int nest = 0;
  
#ifdef MODULE_LEVEL_SECURITY
private mapping misc_cache=([]);

//!
int|mapping check_security(function a, object id, void|int slevel)
{
  array level;
  array seclevels;
  int ip_ok = 0;  // Unknown
  int auth_ok = 0;  // Unknown
  // NOTE:
  //   ip_ok and auth_ok are three-state variables.
  //   Valid contents for them are:
  //     0  Unknown state -- No such restriction encountered yet.
  //     1  May be bad -- Restriction encountered, and test failed.
  //    ~0  OK -- Test passed.
  
  if(!(seclevels = misc_cache[ a ])) {
    int seclvl;
    mixed secgroup;
    catch { seclvl = function_object(a)->query("_seclvl"); };
    catch { secgroup = function_object(a)->query("_sec_group"); };
    misc_cache[ a ] = seclevels = ({
      function_object(a)->query_seclevels(),
      seclvl, secgroup
    });
  }
  if (sizeof(seclevels[0]) && seclevels[0][0] != MOD_USER_SECLEVEL)
    if(slevel && (seclevels[1] > slevel)) // "Trustlevel" to low.
      return 1;
  
  if(!sizeof(seclevels[0]))
    return 0; // Ok if there are no patterns.

  mixed err;
  err = catch {
    foreach(seclevels[0], level) {
      
      switch(level[0]) {
          case MOD_ALLOW: // allow ip=...
            if(level[1](id->remoteaddr)) {
              ip_ok = ~0; // Match. It's ok.
            } else {
              ip_ok |= 1; // IP may be bad.
            }
            break;
  
          case MOD_DENY: // deny ip=...
            if(level[1](id->remoteaddr))
              return Caudium.HTTP.low_answer(403, "<h2>Access forbidden</h2>");
            break;

          case MOD_USER: // allow user=...
            if(id->auth && id->auth[0] && level[1](id->auth[1])) {
              auth_ok = ~0; // Match. It's ok.
            } else {
              auth_ok |= 1; // Auth may be bad.
            }
            break;
  
          case MOD_PROXY_USER: // allow user=...
            if (ip_ok != 1) {
              // IP is OK as of yet.
              if(id->misc->proxyauth && id->misc->proxyauth[0] && 
                 level[1](id->misc->proxyauth[1])) return 0;
              return Caudium.HTTP.proxy_auth_required(seclevels[2]);
            } else {
              // Bad IP.
              return(1);
            }
            break;

          case MOD_ACCEPT: // accept ip=...
            // Short-circuit version on allow.
            if(level[1](id->remoteaddr)) {
              // Match. It's ok.
              return(0);
            } else {
              ip_ok |= 1; // IP may be bad.
            }
            break;

          case MOD_ACCEPT_USER: // accept user=...
            // Short-circuit version on allow.
            if(id->auth && id->auth[0] && level[1](id->auth[1])) {
              // Match. It's ok.
              return(0);
            } else {
              if (id->auth) {
                auth_ok |= 1; // Auth may be bad.
              } else {
                // No auth yet, get some.
                return Caudium.HTTP.auth_required(seclevels[2],QUERY(ZAuthenticationFailed));
              }
            }
            break;

          case MOD_ACCEPT_GROUP:
            if (id->auth && id->auth[0] && sizeof(id->auth) >= 4 && level[1](id->auth[3])) {
              return 0;
            } else {
              if (id->auth)
                auth_ok |= 1;
              else
                return Caudium.HTTP.auth_required(seclevels[2],QUERY(ZAuthenticationFailed));
            }
            break;
            
          case MOD_USER_SECLEVEL: // secuname=...
            mapping(string:int)  usrlist = level[1];

            if(id->auth && id->auth[0]) {
              int  mylevel = -1000;
      
              if (usrlist["any"]) {
                report_notice("Any match on User Seclevel\n");
                mylevel = usrlist["any"];
                report_notice("Security level will be set to " + mylevel + "\n");
              } else if (usrlist[id->auth[1]]) {
                report_notice("User match on User Seclevel (" + id->auth[1] + ")\n");
                mylevel = usrlist[id->auth[1]];
              }
              if (mylevel != -1000)
                misc_cache[a][1] = mylevel;
            } else {
              if (id->auth) {
                auth_ok |= 1; // Auth may be bad.
              } else {
                // No auth yet, get some.
                return Caudium.HTTP.auth_required(seclevels[2],QUERY(ZAuthenticationFailed));
              }
            }
            break;
      }
    }
  };

  if (err) {
    report_error(sprintf("Error during module security check:\n"
                         "%s\n", describe_backtrace(err)));
    return(1);
  }

  if (ip_ok == 1) {
    // Bad IP.
    return(1);
  } else {
    // IP OK, or no IP restrictions.
    if (auth_ok == 1) {
      // Bad authentication.
      // Query for authentication.
      return  Caudium.HTTP.auth_required(seclevels[2],QUERY(ZAuthenticationFailed));
    } else {
      // No auth required, or authentication OK.
      return(0);
    }
  }
}
#endif

//! Empty all the caches above.
void invalidate_cache()
{
  last_module_cache = 0;
  filter_module_cache = 0;
  first_module_cache = 0;
  precache_module_cache = 0;
  url_module_cache = 0;
  location_module_cache = 0;
  logger_module_cache = 0;
  extension_module_cache      = ([]);
  file_extension_module_cache = ([]);
  provider_module_cache = ([]);
  error_module_cache = 0;
#ifdef MODULE_LEVEL_SECURITY
  if(misc_cache)
    misc_cache = ([ ]);
#endif
}

//! Empty all the caches above AND the ones in the loaded modules.
void clear_memory_caches()
{
  invalidate_cache();
  foreach(indices(otomod), object m) {
    if (m && m->clear_memory_caches) {
      mixed err = catch {
        m->clear_memory_caches();
      };
      if (err) {
        report_error(sprintf("clear_memory_caches() failed for module %O:\n"
                             "%s\n",
                             otomod[m], describe_backtrace(err)));
      }
    }
  }
}

//!
string draw_saturation_bar(int hue,int brightness, int where)
{
  object bar=Image.image(30,256);

  for(int i=0;i<128;i++)
  {
    int j = i*2;
    bar->line(0,j,29,j,@Colors.hsv_to_rgb(hue,255-j,brightness));
    bar->line(0,j+1,29,j+1,@Colors.hsv_to_rgb(hue,255-j,brightness));
  }

  where = 255-where;
  bar->line(0,where,29,where, 255,255,255);

  return bar->togif(255,255,255);
}


// Inspired by the internal-gopher-... thingie, this is the for internal
// Caudium images, like logos etc.
private mapping internal_caudium_image(string from)
{
  object img;
  int hue,bright,w;
  string ext;

#if 0
  sscanf(from, "%s.%s", from, ext);
//  sscanf(from, "%s.gif", from);
//  sscanf(from, "%s.jpg", from);
//  sscanf(from, "%s.xcf", from);
  if (!ext)
    ext = "any";
  
  // Disallow "internal-caudium-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  // /internal-caudium-../.. was never possible, since that would be remapped to
  // /..
  from -= ".";
#endif
  
  // New idea: Automatically generated colorbar. Used by wizard code...
  if(sscanf(from, "%*s:%d,%d,%d", hue, bright,w)==4)
    return Caudium.HTTP.string_answer(draw_saturation_bar(hue,bright,w),"image/gif");
  from = replace(from, "roxen", "caudium");

#if 0
  // If the requested image had .xcf extension then we should treat
  // it especially. It differs from the other types in that it's a
  // layered image, and not a flat bitmap. Since some code asks
  // for .xcf it is highly probable it needs the layers (like gbutton,
  // for example). So, in case of XCF we either find the exact file
  // or return null.
  
  mapping img_types = ([
    "gif":"image/gif",
    "png":"image/png",
    "jpg":"image/jpeg",
    "jpeg":"image/jpeg",
    "xcf":"image/x-xcf"
  ]);
  
  switch(ext) {
      case "any":
      case "png":
      case "jpg":
      case "gif":
      case "jpeg":
        foreach(indices(img_types) - ({"xcf"}), string e)
          if(img = open("caudium-images/"+from+"."+e, "r")) 
            return (["  file": img, "type":img_types[e]]);
        break;
          
      case "xcf":
        if(img = open("caudium-images/"+from+"."+ext, "r")) 
          return (["file": img, "type":img_types[ext]]);
        break;
  }
#endif
  mapping ret = caudium->IFiles->get("image://" + from);
  if (!ret) {
    mapping err = caudium->IFiles->get("html://no_internal_image.html");
    return Caudium.HTTP.string_answer(err->data);
  }
  return ret;
}

//! The function that actually tries to find the data requested.  All
//! modules are mapped, in order, and the first one that returns a
//! suitable responce is used.
mapping (mixed:function|int) locks = ([]);

#ifdef THREADS
// import Thread;

mapping locked = ([]), thread_safe = ([]);

object _lock(object|function f)
{
  object key;
  function|int l;

  if (functionp(f)) {
    f = function_object(f);
  }
  if (l = locks[f])
  {
    if (l != -1)
    {
      // Allow recursive locks.
      catch{
        //perror("lock %O\n", f);
        locked[f]++;
        key = l();
      };
    } else
      thread_safe[f]++;
  } else if ((!catch(f->thread_safe)) && (f->thread_safe)) {
    locks[f]=-1;
    thread_safe[f]++;
  } else {
    if (!locks[f])
    {
      // Needed to avoid race-condition.
      l = Thread.Mutex()->lock;
      if (!locks[f]) {
        locks[f]=l;
      }
    }
    //perror("lock %O\n", f);
    locked[f]++;
    key = l();
  }
  return key;
}

#define LOCK(X) key=_lock(X)
#define UNLOCK() do{key=0;}while(0)
#else
#define LOCK(X)
#define UNLOCK()
#endif


#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

//!
string examine_return_mapping(mapping m)
{
  string res;

  if (m->extra_heads)
    m->extra_heads=mkmapping(Array.map(indices(m->extra_heads),
                                       lower_case),
                             values(m->extra_heads));
  else
    m->extra_heads=([]);

  switch (m->error||200)
  {
      case 302: // redirect
        if (m->extra_heads && 
            (m->extra_heads->location))
          res 
            = "Returned <i><b>redirect</b></i>;<br>&nbsp;&nbsp;&nbsp;to "
            "<a href="+(m->extra_heads->location)+">"
            "<font color=darkgreen><tt>"+
            (m->extra_heads->location)+
            "</tt></font></a><br>";
        else
          res = "Returned redirect, but no location header\n";
        break;

      case 401:
        if (m->extra_heads["www-authenticate"])
          res
            = "Returned <i><b>authentication failed</b></i>;"
            "<br>&nbsp;&nbsp;&nbsp;<tt>"+
            m->extra_heads["www-authenticate"]+"</tt><br>";
        else
          res 
            = "Returned <i><b>authentication failed</b></i>.<br>";
        break;

      case 200:
        res
          = "Returned <i><b>ok</b></i><br>\n";
        break;
   
      default:
        res
          = "Returned <b><tt>"+m->error+"</tt></b>.<br>\n";
  }

  if (!zero_type(m->len))
    if (m->len<0)
      res+="No data ";
    else
      res+=m->len+" bytes ";
  else if (stringp(m->data))
    res+=strlen(m->data)+" bytes";
  else if (objectp(m->file))
    if (catch {
      array a=(array(int))m->file->stat();
      res+=(a[1]-m->file->tell())+" bytes ";
    }) res+="? bytes";

  if (m->data) res+=" (static)";
  else if (m->file) res+="(open file)";

  if (stringp(m->extra_heads["http-content-type"]))
    res+=" of <tt>"+m->type+"</tt>\n";
  else if (stringp(m->type))
    res+=" of <tt>"+m->type+"</tt>\n";

  res+="<br>";

  return res;
}

//!
mapping|int low_get_file(object id, int|void no_magic)
{
#ifdef MODULE_LEVEL_SECURITY
  int slevel;
#endif

#ifdef THREADS
  object key;
#endif
  TRACE_ENTER("Request for "+id->not_query, 0);

  string file=id->not_query;
  string loc, type;
  function funp;
  mixed tmp, tmp2;
  mapping|object fid;

  if (!id->misc)
    id->misc = ([]);

  switch(QUERY(use_scopes)) {
      case "Off":
        id->misc->_use_scopes = 0;
        id->misc->_scope_status = 0;
        break;

      case "On":
        id->misc->_use_scopes = 1;
        id->misc->_scope_status = 1;
        break;

      case "Off/Conditional":
        id->misc->_use_scopes = 2;
        id->misc->_scope_status = 0;
        break;

      case "On/Conditional":
        id->misc->_use_scopes = 3;
        id->misc->_scope_status = 1;
        break;

      default:
        id->misc->_use_scopes = 0;
        id->misc->_scope_status = 0;
        break;
  }
    
  // Simplify the path to ensure that the file never points under the
  // current directory. Generally not needed, but it's a cheap
  // operation considering the security problems it stops.
  file = combine_path("/", file);
  
  if(!no_magic)
  {
    if (id->prestate->internal) {
      if (id->internal->image)
        return internal_caudium_image(file);
    }
      
#ifndef NO_INTERNAL_HACK 
    // No, this is not beautiful... :) 

    if(sscanf(file, "%*s/internal-%s-%s", type, loc) == 3)
    {
      switch(type) {
          case "gopher":
            TRACE_LEAVE("Magic internal gopher image");
            return internal_gopher_image(loc);

          case "caudium":
          case "roxen":
          case "spinner":
            TRACE_LEAVE("Magic  internal Caudium image");
            return internal_caudium_image(loc);
      }
    }
#endif

    if(id->prestate->diract && dir_module)
    {
      LOCK(dir_module);
      TRACE_ENTER("Directory module", dir_module);
      tmp = dir_module->parse_directory(id);
      UNLOCK();
      if(mappingp(tmp)) 
      {
        TRACE_LEAVE("");
        TRACE_LEAVE("Returning data");
        return tmp;
      }
      TRACE_LEAVE("");
    }

    if(!search(file, QUERY(InternalLoc))) 
    {
      object module;
      string name, rest;
      function find_internal;
      if(2==sscanf(file[strlen(QUERY(InternalLoc))..], "%s/%s", name, rest) &&
         (module = find_module(replace(name, "!", "#"))) &&
         (find_internal = module->find_internal))
      {
        LOCK(find_internal);
        fid=find_internal( rest, id );
        UNLOCK();
        if(mappingp(fid))
          return fid;
      }
    }
  }

  // Well, this just _might_ be somewhat over-optimized, since it is
  // quite unreadable, but, you cannot win them all.. 
#ifdef URL_MODULES
  // Map URL-modules
  foreach(url_modules(id), funp)
  {
    LOCK(funp);
    TRACE_ENTER("URL Module", funp);
    tmp=funp( id, file );
    UNLOCK();
    
    if(mappingp(tmp)) 
    {
      TRACE_LEAVE("");
      TRACE_LEAVE("Returning data");
      return tmp;
    }
    if(objectp( tmp ))
    {
      array err;

      nest ++;
      err = catch {
        if( nest < 20 )
          tmp = (id->conf || this_object())->low_get_file( tmp, no_magic );
        else
        {
          TRACE_LEAVE("Too deep recursion");
          error("Too deep recursion in roxen::get_file() while mapping "
                +file+".\n");
        }
      };
      nest = 0;
      if(err) throw(err);
      TRACE_LEAVE("");
      TRACE_LEAVE("Returned data");
      return tmp;
    }
    TRACE_LEAVE("");
  }
#endif
#ifdef EXTENSION_MODULES  
  if(tmp=extension_modules(loc=extension(file), id))
  {
    foreach(tmp, funp)
    {
      TRACE_ENTER("Extension Module ["+loc+"] ", funp);
      LOCK(funp);
      tmp=funp(loc, id);
      UNLOCK();
      if(tmp)
      {
        if(!objectp(tmp)) 
        {
          TRACE_LEAVE("Returing data");
          return tmp;
        }
        fid = tmp;
#ifdef MODULE_LEVEL_SECURITY
        slevel = function_object(funp)->query("_seclvl");
#endif
        TRACE_LEAVE("Retured open filedescriptor."
#ifdef MODULE_LEVEL_SECURITY
                    +(slevel != id->misc->seclevel?
                      ". The security level is now "+slevel:"")
#endif
                   );
#ifdef MODULE_LEVEL_SECURITY
        id->misc->seclevel = slevel;
#endif
        break;
      } else
        TRACE_LEAVE("");
    }
  }
#endif 
 
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
      TRACE_ENTER("Location Module ["+loc+"] ", tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(tmp2 = check_security(tmp[1], id, slevel))
        if(intp(tmp2))
        {
          TRACE_LEAVE("Permission to access module denied");
          continue;
        } else {
          TRACE_LEAVE("Request denied.");
          return tmp2;
        }
#endif
      TRACE_ENTER("Calling find_file()...", 0);
      LOCK(tmp[1]);
      fid=tmp[1]( file[ strlen(loc) .. ] + id->extra_extension, id);
      UNLOCK();
      TRACE_LEAVE(sprintf("find_file has returned %O", fid));
      if(fid)
      {
        id->virtfile = loc;

        if(mappingp(fid))
        {
          TRACE_LEAVE("");
          TRACE_LEAVE(examine_return_mapping(fid));
          return fid;
        }
        else
        {
#ifdef MODULE_LEVEL_SECURITY
          int oslevel = slevel;
          slevel = misc_cache[ tmp[1] ][1];
          // misc_cache from
          // check_security
          id->misc->seclevel = slevel;
#endif
          if(objectp(fid))
            TRACE_LEAVE("Returned open file"
#ifdef MODULE_LEVEL_SECURITY
                        +(slevel != oslevel?
                          ". The security level is now "+slevel:"")
#endif
      
                        +".");
          else
            TRACE_LEAVE("Returned directory indicator"
#ifdef MODULE_LEVEL_SECURITY
                        +(oslevel != slevel?
                          ". The security level is now "+slevel:"")
#endif
                       );
          break;
        }
      } else
        TRACE_LEAVE("");
    } else if(strlen(loc)-1==strlen(file)) {
      // This one is here to allow accesses to /local, even if 
      // the mountpoint is /local/. It will slow things down, but...
      if(file+"/" == loc) 
      {
        TRACE_ENTER("Automatic redirect to location module", tmp[1]);
        TRACE_LEAVE("Returning data");
        return Caudium.HTTP.redirect(id->not_query + "/", id);
      }
    }
  }
  
  if(fid == -1)
  {
    if(no_magic)
    {
      TRACE_LEAVE("No magic requested. Returning -1");
      return -1;
    }
    if(dir_module)
    {
      LOCK(dir_module);
      TRACE_ENTER("Directory module", dir_module);
      fid = dir_module->parse_directory(id);
      UNLOCK();
    }
    else
    {
      TRACE_LEAVE("No directory module. Returning 'no such file'");
      return 0;
    }
    if(mappingp(fid)) 
    {
      TRACE_LEAVE("Returned data");
      return (mapping)fid;
    }
  }
  
  // Map the file extensions, but only if there is a file...
  if(objectp(fid)&&
     (tmp=file_extension_modules(loc=Caudium.extension(id->not_query), id)))
    foreach(tmp, funp)
    {
      TRACE_ENTER("Extension module", funp);
#ifdef MODULE_LEVEL_SECURITY
      if(tmp=check_security(funp, id, slevel))
        if(intp(tmp))
        {
          TRACE_LEAVE("Permission to access module denied");
          continue;
        }
        else
        {
          TRACE_LEAVE("");
          TRACE_LEAVE("Permission denied");
          return tmp;
        }
#endif
      LOCK(funp);
      tmp=funp(fid, loc, id);
      UNLOCK();
      if(tmp)
      {
        if(!objectp(tmp))
        {
          TRACE_LEAVE("");
          TRACE_LEAVE("Returning data");
          return tmp;
        }
        if(fid)
          destruct(fid);
        TRACE_LEAVE("Returned new open file");
        fid = tmp;
        break;
      } else
        TRACE_LEAVE("");
    }
  
  if(objectp(fid))
  {
    if(stringp(id->extension))
      id->not_query += id->extension;


    TRACE_ENTER("Content-type mapping module", types_module);
    tmp=type_from_filename(id->not_query, 1);
    TRACE_LEAVE(tmp?"Returned type "+tmp[0]+" "+tmp[1]:"Missing");
    if(tmp)
    {
      TRACE_LEAVE("");
      return ([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
    }    
    TRACE_LEAVE("");
    return ([ "file":fid, ]);
  }
  if(!fid)
    TRACE_LEAVE("Returning 'no such file'");
  else
    TRACE_LEAVE("Returning data");
  return fid;
}

//! Call the precache_rewrite function in all MODULE_PRECACHE, if any.
//! This is done before the any raw caching is done and can be used for
//! virtual hosting and creation of a custom cache key.
void handle_precache(object id) {
  foreach(precache_module_cache||precache_modules(id), function funp)
  {
    funp( id );
    if(id->conf != this_object()) {
      REQUEST_WERR("handle_request(): Redirected (2)");
      if(!id->conf->inited) { id->conf->enable_all_modules(); }
      id->conf->handle_precache(id);
      return;
    }
  }
}

//! Call the handle_error function in all MODULE_ERROR, if any.
//! This is done at the end of request if there is nothing from others module
//!
//! @param id
//!   Caudium Object id
//!
//! @returns 
//!   object or data from @[Caudium.HTTP.low_answer] function or 0 if error
//!
//! @note
//!   Non RIS implementation
mixed handle_error_request( object id ) {
  REQUEST_WERR("handle_error_request(): called");
  mixed out, ret;
  foreach(error_module_cache||error_modules(id), function funp) {
    REQUEST_WERR("handle_error_request(): try module");
    if(ret = funp(id)) break;
    REQUEST_WERR(sprintf("handle_error_request(): get %O",ret));
    if(ret == 1) {
      REQUEST_WERR("handle_error_request(): Recurse");
      return handle_error_request(id);
    }
  } 
  out = ret;
  REQUEST_WERR("handle_error_request(): Done");
  return out;
}

//! This function handle the request for the server.
//! All request goes thru this function
//!
//! @param id
//!   Caudium Object id
//!
//! @returns
//!   To be documented
//!
//! @note
//!   RIS Implmentation with some additions
//!
//! @fixme 
//!   To be documented
mixed handle_request( object id  )
{
  function funp;
  mixed file;
  REQUEST_WERR("handle_request()");
  foreach(first_module_cache||first_modules(id), funp)
  {
    if(file = funp( id ))
      break;
    if(id->conf != this_object()) {
      REQUEST_WERR("handle_request(): Redirected (2)");
      return id->conf->handle_request(id);
    }
  }
  if(!mappingp(file) && !mappingp(file = get_file(id)))
  {
    mixed ret;
    foreach(last_module_cache||last_modules(id), funp)
      if(ret = funp(id)) break;
    if (ret == 1) {
      REQUEST_WERR("handle_request(): Recurse");
      return handle_request(id);
    }
    file = ret;
  }
  REQUEST_WERR("handle_request(): Done");
  return file;
}

//! Get the file in probably VFS
//!
//! @param id
//!   Caudium ID object
//!
//! @param no_magic
//!   Undocumented.
//!
//! @returns
//!   Undocumented.
//!
//! @note
//!   RIS implementation
//!
//! @fixme
//!   Undocumented
mixed get_file(object id, int|void no_magic)  
{
  mixed res, res2;
  function tmp;
  res = low_get_file(id, no_magic);
  // finally map all filter type modules.
  // Filter modules are like TYPE_LAST modules, but they get called
  // for _all_ files.
  foreach(filter_modules(id), tmp)
  {
    TRACE_ENTER("Filter module", tmp);
    if(res2=tmp(res,id))
    {
      if(res && res->file && (res2->file != res->file))
        destruct(res->file);
      TRACE_LEAVE("Rewrote result");
      res=res2;
    } else
      TRACE_LEAVE("");
  }
  return res;
}

public array find_dir(string file, object id)
{
  string loc;
  array dir = ({ }), tmp;
  array | mapping d;
  TRACE_ENTER("List directory "+file, 0);
  file=replace(file, "//", "/");
  
  if(file[0] != '/')
    file = "/" + file;

#ifdef URL_MODULES
#ifdef THREADS
  object key;
#endif
  // Map URL-modules
  foreach(url_modules(id), function funp)
  {
    string of = id->not_query;
    id->not_query = file;
    LOCK(funp);
    TRACE_ENTER("URL module", funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
      TRACE_LEAVE("Returned 'no thanks'");
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( tmp ))
    {
      array err;
      nest ++;
      
      TRACE_LEAVE("Recursing");
      file = id->not_query;
      err = catch {
        if( nest < 20 )
          tmp = (id->conf || this_object())->find_dir( file, id );
        else
          error("Too deep recursion in roxen::find_dir() while mapping "
                +file+".\n");
      };
      nest = 0;
      TRACE_LEAVE("");
      if(err)
        throw(err);
      return tmp;
    }
    id->not_query=of;
  }
#endif /* URL_MODULES */

  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) {
      /* file == loc + subpath */
      TRACE_ENTER("Location module", tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
        TRACE_LEAVE("Permission denied");
        continue;
      }
#endif
      if(d=function_object(tmp[1])->find_dir(file[strlen(loc)..], id))
      {
        if(mappingp(d))
        {
          if(d->files) { 
            dir |= d->files;
            TRACE_LEAVE("Got exclusive directory.");
            TRACE_LEAVE("Returning list of "+sizeof(dir)+" files");
            return dir;
          } else
            TRACE_LEAVE("");
        } else {
          TRACE_LEAVE("Got files");
          dir |= d;
        }
      } else
        TRACE_LEAVE("");
    } else if((search(loc, file)==0) && (loc[strlen(file)-1]=='/') &&
              (loc[0]==loc[-1]) && (loc[-1]=='/') &&
              (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER("Location module", tmp[1]);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      dir += ({ loc });
      TRACE_LEAVE("Added module mountpoint");
    }
  }
  if(sizeof(dir))
  {
    TRACE_LEAVE("Returning list of "+sizeof(dir)+" files");
    return dir;
  } 
  TRACE_LEAVE("Returning 'no such directory'");
}

// Stat a virtual file. 
public array stat_file(string file, object id)
{
  string loc;
  array s, tmp;
  TRACE_ENTER("Stat file "+file, 0);
  
  file=replace(file, "//", "/"); // "//" is really "/" here...

#ifdef URL_MODULES
#ifdef THREADS
  object key;
#endif
  // Map URL-modules
  foreach(url_modules(id), function funp)
  {
    string of = id->not_query;
    id->not_query = file;

    TRACE_ENTER("URL module", funp);
    LOCK(funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp )) {
      id->not_query = of;
      TRACE_LEAVE("");
      TRACE_LEAVE("said 'No thanks'");
      return 0;
    }
    if(objectp( tmp ))
    {
      file = id->not_query;

      array err;
      nest ++;
      TRACE_LEAVE("Recursing");
      err = catch {
        if( nest < 20 )
          tmp = (id->conf || this_object())->stat_file( file, id );
        else
          error("Too deep recursion in roxen::stat_file() while mapping "
                +file+".\n");
      };
      nest = 0;
      if(err)
        throw(err);
      TRACE_LEAVE("");
      TRACE_LEAVE("Returning data");
      return tmp;
    }
    TRACE_LEAVE("");
    id->not_query = of;
  }
#endif
    
  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if((file == loc) || ((file+"/")==loc))
    {
      TRACE_ENTER("Location module", tmp[1]);
      TRACE_LEAVE("Exact match");
      TRACE_LEAVE("");
      return ({ 0775, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    }
    if(!search(file, loc)) 
    {
      TRACE_ENTER("Location module", tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
        TRACE_LEAVE("");
        TRACE_LEAVE("Permission denied");
        continue;
      }
#endif
      if(s=function_object(tmp[1])->stat_file(file[strlen(loc)..], id))
      {
        TRACE_LEAVE("");
        TRACE_LEAVE("Stat ok");
        return s;
      }
      TRACE_LEAVE("");
    }
  }
  TRACE_LEAVE("Returning 'no such file'");
}

//!
class StringFile
{
  string data;
  int offset;

  //!
  string read(int nbytes)
  {
    if(!nbytes)
    {
      offset = strlen(data);
      return data;
    }
    string d = data[offset..offset+nbytes-1];
    offset += strlen(d);
    return d;
  }

  //!
  void write(mixed ... args)
  {
    throw( ({ "File not open for write", backtrace() }) );
  }

  //!
  void seek(int to)
  {
    offset = to;
  }

  //!
  void create(string d)
  {
    data = d;
  }

}

// this is not as trivial as it sounds. Consider gtext. :-)
public array open_file(string fname, string mode, object id)
{
  object oc = id->conf;
  string oq = id->not_query;
  function funp;
  mixed file;

  id->not_query = fname;
  foreach(oc->first_modules(), funp)
    if(file = funp( id )) 
      break;
    else if(id->conf != oc) 
    {
      if(!id->conf->inited) { id->conf->enable_all_modules(); }
      id->not_query = fname;
      return open_file(fname, mode,id);
    }
  fname = id->not_query;

  if(search(mode, "R")!=-1) //  raw (as in not parsed..)
  {
    string f;
    mode -= "R";
    if(f = real_file(fname, id))
    {
      //      werror("opening "+fname+" in raw mode.\n");
      return ({ open(f, mode), ([]) });
    }
//     return ({ 0, (["error":302]) });
  }

  if(mode=="r")
  {
    if(!file)
    {
      file = oc->get_file( id );
      if(!file) {
        foreach(oc->last_modules(), funp) if(file = funp( id ))
          break;
        if (file == 1) {
          // Recurse.
          return open_file(id->not_query, mode, id);
        }
      }
    }

    if(!mappingp(file))
    {
      if(!id->misc->error_request) {
        file = caudium->http_error->process_error (id);
        id->not_query = oq;
        return ({ 0, file });
      }
      return ({ 0, 0 });
    }

    if(file->data) 
    {
      file->file = StringFile(file->data);
      m_delete(file, "data");
    } 
    id->not_query = oq;
    return ({ file->file, file });
  }
  id->not_query = oq;
  return ({ 0,(["error":501,"data":"Not implemented"]) });
}

public mapping(string:array(mixed)) find_dir_stat(string file, object id)
{
  string loc;
  mapping(string:array(mixed)) dir = ([]);
  mixed d, tmp;

  file=replace(file, "//", "/");
  
  if(file[0] != '/')
    file = "/" + file;

  // FIXME: Should I append a "/" to file if missing?

  TRACE_ENTER("Request for directory and stat's \""+file+"\"", 0);

#ifdef URL_MODULES
#ifdef THREADS
  object key;
#endif
  // Map URL-modules
  foreach(url_modules(id), function funp)
  {
    string of = id->not_query;
    id->not_query = file;
    LOCK(funp);
    TRACE_ENTER("URL Module", funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
#ifdef MODULE_DEBUG
      roxen_perror(sprintf("conf->find_dir_stat(\"%s\"): url_module returned mapping:%O\n", 
                           file, tmp));
#endif /* MODULE_DEBUG */
      TRACE_LEAVE("URL Module returned mapping");
      TRACE_LEAVE("Empty directory");
      return 0;
    }
    if(objectp( tmp ))
    {
      array err;
      nest ++;
      
      file = id->not_query;
      err = catch {
        if( nest < 20 )
          tmp = (id->conf || this_object())->find_dir_stat( file, id );
        else {
          TRACE_LEAVE("Too deep recursion");
          error("Too deep recursion in roxen::find_dir_stat() while mapping "
                +file+".\n");
        }
      };
      nest = 0;
      if(err)
        throw(err);
#ifdef MODULE_DEBUG
      roxen_perror(sprintf("conf->find_dir_stat(\"%s\"): url_module returned object:\n", 
                           file));
#endif /* MODULE_DEBUG */
      TRACE_LEAVE("URL Module returned object");
      TRACE_LEAVE("Returning it");
      return tmp; // FIXME: Return 0 instead?
    }
    id->not_query=of;
    TRACE_LEAVE("");
  }
#endif /* URL_MODULES */

  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];

    TRACE_ENTER("Trying location module mounted on "+loc, 0);
    /* Note that only new entries are added. */
    if(!search(file, loc))
    {
      /* file == loc + subpath */
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      object c = function_object(tmp[1]);
      string f = file[strlen(loc)..];
      if (c->find_dir_stat) {
        TRACE_ENTER("Has find_dir_stat()", 0);
        if (d = c->find_dir_stat(f, id)) {
          TRACE_ENTER("find_dir_stat() returned mapping", 0);
          dir = d | dir;
          TRACE_LEAVE("");
        }
        TRACE_LEAVE("");
      } else if(d = c->find_dir(f, id)) {
        TRACE_ENTER("find_dir() returned array", 0);
        dir = mkmapping(d, Array.map(d, lambda(string f, string base,
                                               object c, object id) {
                                          return(c->stat_file(base + f, id));
                                        }, f, c, id)) | dir;
        TRACE_LEAVE("");
      }
    } else if(search(loc, file)==0 && loc[strlen(file)-1]=='/' &&
              (loc[0]==loc[-1]) && loc[-1]=='/' &&
              (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER("file is on the path to the mountpoint", 0);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      if (!dir[loc]) {
        dir[loc] = ({ 0775, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      }
      TRACE_LEAVE("");
    }
    TRACE_LEAVE("");
  }
  if(sizeof(dir))
    return dir;
}


// Access a virtual file?
public array|string access(string file, object id)
{
  string loc;
  array s, tmp;
  
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if((file+"/")==loc)
      return file += "/";
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->access(file[strlen(loc)..], id))
        return s;
    }
  }
}

//! Return the @b{real@} filename of a virtual file, if any.
//!
//! @param file
//!  Path to the @b{virtual@} file.
//!
//! @param id
//!  The request object
//!
//! @returns
//!  The real file corresponding to the virtual one.
public string real_file(string file, object id)
{
  string loc;
  string s;
  array tmp;
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  if(!id) error("No id passed to real_file");

  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      // FIXME: NOTE: Limits filename length to 1000000 bytes.
      //  /grubba 1997-10-03
      if(s=function_object(tmp[1])->real_file(file[strlen(loc)..1000000], id))
        return s;
    }
  }
}

//!  Convenience function used in quite a lot of modules. Tries to read a file
//!  into memory, and then returns the resulting string. Note that a 'file' 
//!  can be a CGI script, which will executed, resulting in a horrible delay.
//! @param s
//!  The file to read.
//! @param id
//!  The Caudium Object Id
//! @param status
//!  Ask the function to return 1 if file exist or 0 if it doesn't.
//! @param nocache
//!  Set to 1 if you don't want to cache or use the caudium cache for this
//!  access.
//! @returns
//!  A string with the content of file or int if you ask a status of the file
public mixed try_get_file(string s, object id, int|void status, int|void nocache)
{
  string res, q;
  object fake_id;
  mapping m;


  if(objectp(id)) {
    // id->misc->common makes it possible to pass information to
    // the originating request.
    if ( !id->misc )
      id->misc = ([]);
    if ( !id->misc->common )
      id->misc->common = ([]);

    fake_id = id->clone_me();

    fake_id->misc->common = id->misc->common;
  } else
    error("No ID passed to 'try_get_file'\n");

  if(!id->pragma["no-cache"] && !nocache && !id->auth)
    if(res = cache_lookup("file:"+id->conf->name, s))
      return res;

  if(sscanf(s, "%s?%s", s, q))
  {
    Caudium.parse_query_string(q, fake_id->variables);
    fake_id->query=q;
  }

  fake_id->raw_url=s;
  fake_id->not_query=s;
  fake_id->misc->internal_get=1;

  if(!(m = get_file(fake_id)))
  {
    fake_id->end();
    return 0;
  }
  fake_id->end();
  
  if (!(< 0, 200, 201, 202, 203 >)[m->error]) return 0;
  
  if(status) return 1;

#ifdef COMPAT
  if(m["string"])  res = m["string"]; // Compability..
  else
#endif
    if(m->data) res = m->data;
    else res="";
  m->data = 0;
  
  if(m->file)
  {
    res += m->file->read();
    destruct(m->file);
    m->file = 0;
  }
  
  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }
  cache_set("file:"+id->conf->name, s, res);
  return res;
}

//!  Is 'what' a file in ou virtual filesystem ?
//! @param what
//!  The file to test
//! @param id
//!  The Caudium Object Id
//! @returns
//!  1 if this a file. 0 otherwise.
public int is_file(string what, object id)
{
  return !!stat_file(what, id);
}

//! A quick hack to generate correct protocol references
static string make_proto_name(string p)
{
  // Note these are only the protocols that
  // Caudium can directly use
  multiset(string) known_protos = (<"http", "ftp", "https", "ssl3">);
  multiset(string) telnet_protos = (<"smtp", "pop", "pop2", "pop3", "imap", "tetris">);
    
  if (known_protos[p])
    return p;
  
  if (telnet_protos[p])
    return "telnet";

  foreach(indices(known_protos), string proto) {
    string ret;
  
    ret = String.common_prefix(({proto, p}));
    if (ret && ret != "")
      return ret;
  }
    
  foreach(indices(telnet_protos), string proto) {
    string ret;
  
    ret = String.common_prefix(({proto, p}));
    if (ret && ret != "")
      return "telnet";
  }
    
  return "about";
}

//!
string MKPORTKEY(array(string) p)
{
  if (sizeof(p[3])) {
    return(sprintf("%s://%s:%s/(%s)",
                   make_proto_name(p[1]), p[2], (string)p[0],
                   replace(p[3], ({"\n", "\r"}), ({ " ", " " }))));
  } else {
    return(sprintf("%s://%s:%s/",
                   make_proto_name(p[1]), p[2], (string)p[0]));
  }
}

//! Caudium opened ports.
mapping(string:object) server_ports = ([]);

int ports_changed = 1;

//!
void start(int num, void|object conf_id, array|void args)
{
  // Note: This may be run before uid:gid is changed.

  string server_name = query_name();
  array port;
  int err=0;
  object lf;
  mapping new=([]), o2;
#ifdef ENABLE_RAM_CACHE
  if(!datacache)
    datacache = DataCache(query( "data_cache_size" ) * 1024,
                          query( "data_cache_file_max_size" ) * 1024,
                          query( "data_cache_gc_cleanup") / 100.0);
  else
    datacache->init_from_variables(query( "data_cache_size" ) * 1024,
                                   query( "data_cache_file_max_size" ) * 1024,
                                   query( "data_cache_gc_cleanup") / 100.0);
#endif

#if 0
  // Doesn't seem to be set correctly.
  //  /grubba 1998-05-18
  if (!ports_changed) {
    return;
  }
#endif /* 0 */

  ports_changed = 0;

  // First find out if we have any new ports.
  mapping(string:array(string)) new_ports = ([]);

  //Make it possible to set variables from start.
  if(args)
    foreach(args, string variable)
    {
      string name, c, v;
      if(sscanf(variable, "%s:%s=%s", name, c, v) == 3)
        if(server_name == replace(name,"_"," "))
          if(variables[c])
            variables[c][VAR_VALUE]=compile_string(
                                                   "mixed f(){ return"+v+";}")()->f();
          else
            perror("Unknown variable: "+c+"\n");
    }

  foreach(query("Ports"), port) {
    if ((< "ssl", "ssleay" >)[port[1]]) {
      // Obsolete versions of the SSL protocol.
      report_warning(sprintf("%s: Obsolete SSL protocol-module \"%s\".\n"
                             "Converted to SSL3.\n",
                             server_name, port[1]));
      // Note: Change in-place.
      port[1] = "ssl3";
      // FIXME: Should probably mark node as changed.
    }
    if ((< "ftp2" >)[port[1]]) {
      // Obsolete versions of the FTP protocol.
      report_warning(sprintf("%s: Obsolete FTP protocol-module \"%s\". "
                             " Converted to FTP.\n",
                             server_name, port[1]));
      // Note: Change in-place.
      port[1] = "ftp";
      // FIXME: Should probably mark node as changed.
    }
    string key = MKPORTKEY(port);
    if (!server_ports[key]) {
      report_notice(sprintf("%s: New port: %s\n", server_name, key));
      new_ports[key] = port;
    } else {
      // This is needed not to delete old unchanged ports.
      new_ports[key] = 0;
    }
  }

  // Then disable the old ones that are no more.
  foreach(indices(server_ports), string key) {
    if (zero_type(new_ports[key])) {
      report_notice(sprintf("%s: Disabling port: %s...\n", server_name, key));
      object o = server_ports[key];
      m_delete(server_ports, key);
      mixed err;
      if (err = catch{
        destruct(o);
      }) {
        report_warning(sprintf("%s: Error disabling port: %s:\n"
                               "%s\n",
                               server_name, key, describe_backtrace(err)));
      }
      o = 0;    // Be sure that there are no references left...
    }
  }

  // Now we can create the new ports.
  roxen_perror(sprintf("Opening ports for %s... \n", server_name));
  foreach(indices(new_ports), string key) {
    port = new_ports[key];
    if (port) {
      array old = port;
      mixed erro;
      erro = catch {
        program requestprogram = (program)(getcwd()+"/protocols/"+port[1]);
        function rp;
        array tmp;
        if(!requestprogram) {
          report_error(sprintf("%s: No request program for %s\n",
                               server_name, port[1]));
          continue;
        }
        if(rp = requestprogram()->real_port)
          if(tmp = rp(port, this_object()))
            port = tmp;

        object privs;
        if(port[0] < 1024)
          privs = Privs("Opening listen port below 1024");

        object o;
        if(o=create_listen_socket(port[0], this_object(), port[2],
                                  requestprogram, port)) {
          report_notice(sprintf("%s: Opening port: %s\n", server_name, key));
          server_ports[key] = o;
        } else {
          report_error(sprintf("%s: The port %s could not be opened\n",
                               server_name, key));
        }
        if (privs) {
          destruct(privs);  // Paranoia.
        }
      };
      if (erro) {
        report_error(sprintf("%s: Failed to open port %s:\n"
                             "%s\n", server_name, key,
                             (stringp(erro)?erro:describe_backtrace(erro))));
      }
    }
  }
  if (sizeof(query("Ports")) && !sizeof(server_ports)) {
    report_error("No ports available for "+name+"\n"
                 "Tried:\n"
                 "Port  Protocol   IP-Number \n"
                 "---------------------------\n"
                 + Array.map(query("Ports"),
                             lambda(array p) {
                               return sprintf("%5d %-10s %-20s\n", @p);
                             })*"");
  }
  parse_log_formats();
  // We are not automatically opening the logfile until it's needed
  // to save file descriptors.
  // init_log_file();
  log_function = 0;
}



//! Save this configuration. If @[all] is present, save all the
//! configuration  global variables as well, otherwise only all module
//! variables.
//!
//! @param all
//!  If present, all the global variables are saved, only the module ones
//!  otherwise.
void save(int|void all)
{
  mapping mod;
  if(all)
  {
    store("spider.lpc#0", variables, 0, this);
    start(2);
  }
  
  foreach(values(modules), mod)
  {
    if(mod->enabled)
    {
      store(mod->sname+"#0", mod->master->query(), 0, this);
      mod->enabled->start(2, this);
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
        store(mod->sname+"#"+i, mod->copies[i]->query(), 0, this);
        mod->copies[i]->start(2, this);
      }
    }
  }
  invalidate_cache();
}

//! Save all variables in _one_ module.
int save_one( object o )
{
  mapping mod;
  if(!o) 
  {
    store("spider#0", variables, 0, this);
    start(2);
    return 1;
  }
  foreach(values(modules), mod)
  {
    if( mod->enabled == o)
    {
      store(mod->sname+"#0", o->query(), 0, this);
      o->start(2, this);
      invalidate_cache();
      return 1;
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
        if(mod->copies[i] == o)
        {
          store(mod->sname+"#"+i, o->query(), 0, this);
          o->start(2, this);
          invalidate_cache();
          return 1;
        }
      }
    }
  }
}

mapping _hooks=([ ]);

//!
void hooks_for( string modname, object mod )
{
  array hook;
  if(_hooks[modname])
  {
#ifdef MODULE_DEBUG
    perror("Module hooks...");
#endif
    foreach(_hooks[modname], hook)
      hook[0]( @hook[1], mod );
  }
}

//! enable a module in this configuration
object enable_module( string modname )
{
  string id;
  mapping module;
  mapping enabled_modules;
  caudium->current_configuration = this_object();
  modname = replace(modname, ".lpc#","#");
  
  sscanf(modname, "%s#%s", modname, id );

  module = modules[ modname ];
  if(!module)
  {
    load_module(modname);
    module = modules[ modname ];
  }

#if constant(gethrtime)
  int start_time = gethrtime();
#endif
  if (!module) {
    return 0;
  }

  object me;
  mapping tmp;
  int pr;
  array err;

#ifdef MODULE_DEBUG
  perror("Enabling "+module->name+" # "+id+" ... ");
#endif

  if(module->copies)
  {
    if (err = catch(me = module["program"](this_object()))) {
      report_error("Couldn't clone module \"" + module->name + "\"\n" +
                   describe_backtrace(err));
      if (module->copies[id]) {
#ifdef MODULE_DEBUG
        perror("Keeping old copy\n");
#endif
      }
      return(module->copies[id]);
    }
    if(module->copies[id]) {
#ifdef MODULE_DEBUG
      perror("Disabling old copy ... ");
#endif
      if (err = catch{
        module->copies[id]->stop();
      }) {
        report_error("Error during disabling of module \"" + module->name +
                     "\"\n" + describe_backtrace(err));
      }
      destruct(module->copies[id]);
    }
  } else {
    if(objectp(module->master)) {
      me = module->master;
    } else {
      if (err = catch(me = module["program"](this_object()))) {
        report_error("Couldn't clone module \"" + module->name + "\"\n" +
                     describe_backtrace(err));
        return(0);
      }
    }
  }

  me->set_configuration(this_object());
#ifdef MODULE_DEBUG
  //    perror("Initializing ");
#endif
  if (module->type & (MODULE_LOCATION | MODULE_EXTENSION |
                      MODULE_FILE_EXTENSION | MODULE_LOGGER |
                      MODULE_URL | MODULE_LAST | MODULE_PROVIDER |
                      MODULE_FILTER | MODULE_PARSER | MODULE_FIRST |
                      MODULE_PRECACHE | MODULE_ERROR))
  {
    me->defvar("_priority", 5, "Priority", TYPE_INT_LIST,
               "The priority of the module. 9 is highest and 0 is lowest."
               " Modules with the same priority can be assumed to be"
               " called in random order"
               "<p>You have to restart Caudium to ensure that the new"
               " priority is applied.",
               ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
      
    if(!(module->type & (MODULE_LOGGER | MODULE_PROVIDER | MODULE_PRECACHE)))
    {
      if(!(module->type & MODULE_PROXY))
      {
        me->defvar("_sec_group", "user", "Security: Realm", TYPE_STRING,
                   "The realm to use when requesting password from the "
                   "client. Usually used as an informative message to the "
                   "user.");
        me->defvar("_seclvl",  0, "Security: Security level", TYPE_INT, 
                   "The modules security level is used to determine if a "
                   " request should be handled by the module."
                   "\n<p><h2>Security level vs Trust level</h2>"
                   " Each module has a configurable <i>security level</i>."
                   " Each request has an assigned trust level. Higher"
                   " <i>trust levels</i> grants access to modules with higher"
                   " <i>security levels</i>."
                   "\n<p><h2>Definitions</h2><ul>"
                   " <li>A requests initial Trust level is infinitely high."
                   " <li> A request will only be handled by a module if its"
                   "     <i>trust level</i> is higher or equal to the"
                   "     <i>security level</i> of the module."
                   " <li> Each time the request is handled by a module the"
                   "     <i>trust level</i> of the module will be set to the"
                   "      lower of its <i>trust level</i> and the modules"
                   "     <i>security level</i>."
                   " </ul>"
                   "\n<p><h2>Example</h2>"
                   " Modules:<ul>"
                   " <li>  User filesystem, <i>security level</i> 1"
                   " <li>  Filesystem module, <i>security level</i> 3"
                   " <li>  CGI module, <i>security level</i> 2"
                   " </ul>"
                   "\n<p>A request handled by \"User filesystem\" is assigned"
                   " a <i>trust level</i> of one after the <i>security"
                   " level</i> of that module. That request can then not be"
                   " handled by the \"CGI module\" since that module has a"
                   " higher <i>security level</i> than the requests trust"
                   " level."
                   "\n<p>On the other hand, a request handled by the the"
                   " \"Filsystem module\" could later be handled by the"
                   " \"CGI module\".");

        me->defvar("_seclevels", "", "Security: Patterns", TYPE_TEXT_FIELD,
                   "This is the 'security level=value' list.<br>"
                   "Each security level can be any or more from this list:"
                   "<hr noshade>"
                   "accept ip=<i>IP</i>/<i>bits</i><br>"
                   "accept ip=<i>IP</i>:<i>mask</i><br>"
                   "accept ip=<i>pattern</i><br>"
                   "accept user=<i>username</i>,...<br>"
                   "accept group=<i>groupname</i>,...<br>"
                   "allow ip=<i>IP</i>/<i>bits</i><br>"
                   "allow ip=<i>IP</i>:<i>mask</i><br>"
                   "allow ip=<i>pattern</i><br>"
                   "allow user=<i>username</i>,...<br>"
                   "deny ip=<i>IP</i>/<i>bits</i><br>"
                   "deny ip=<i>IP</i>:<i>mask</i><br>"
                   "deny ip=<i>pattern</i><br>"
                   "secuname=<i>username:level</i>,...<br>"
                   "<hr noshade>"
                   "In patterns: * matches one or more characters, "
                   "and ? matches one character.<p>"
                   "In username: 'any' stands for any valid account "
                   "(from .htaccess or an authentication module.) "
                   "<p>allow and deny are short-circuit rules."
                   "<p>The default (used when _no_ "
                   "entries are present) is 'allow ip=*', allowing"
                   " everyone to access the module");
    
      } else {
        me->definvisvar("_seclvl", -10, TYPE_INT); /* A very low one */
    
        me->defvar("_sec_group", "user", "Proxy Security: Realm", TYPE_STRING,
                   "The realm to use when requesting password from the "
                   "client. Usually used as an informative message to the "
                   "user.");
        me->defvar("_seclevels", "", "Proxy security: Patterns",
                   TYPE_TEXT_FIELD,
                   "This is the 'security level=value' list.<br>"
                   "Each security level can be any or more from this list:"
                   "<hr noshade>"
                   "accept ip=<i>IP</i>/<i>bits</i><br>"
                   "accept ip=<i>IP</i>:<i>mask</i><br>"
                   "accept ip=<i>pattern</i><br>"
                   "accept user=<i>username</i>,...<br>"
                   "allow ip=<i>IP</i>/<i>bits</i><br>"
                   "allow ip=<i>IP</i>:<i>mask</i><br>"
                   "allow ip=<i>pattern</i><br>"
                   "allow user=<i>username</i>,...<br>"
                   "deny ip=<i>IP</i>/<i>bits</i><br>"
                   "deny ip=<i>IP</i>:<i>mask</i><br>"
                   "deny ip=<i>pattern</i><br>"
                   "secuname=<i>username:level</i>,...<br>"
                   "secgname=<i>groupname:level</i>,...<br>"
                   "<hr noshade>"
                   "In patterns: * matches one or more characters, "
                   "and ? matches one character.<p>"
                   "In username: 'any' stands for any valid account "
                   "(from .htaccess or an authentication module.) "
                   "<p>allow and deny are short-circuit rules."
                   "<p>The default (used when _no_ "
                   "entries are present) is 'deny ip=*', allowing"
                   " everyone to access the module");
      }
    }
  } else {
    me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);
  }
  
  me->defvar("_comment", "", " Comment", TYPE_TEXT_FIELD|VAR_MORE,
             "An optional comment. This has no effect on the module, it "
             "is only a text field for comments that the administrator "
             "might have (why the module are here, etc.)");

  me->defvar("_name", "", " Module name", TYPE_STRING|VAR_MORE,
             "An optional name. Set to something to remaind you what "
             "the module really does.");
  
  me->setvars(retrieve(modname + "#" + id, this));

  if(module->copies)
    module->copies[(int)id] = me;
  else
    module->enabled = me;

  otomod[ me ] = modname;
      
  if((me->start) && (err = catch{
    me->start(0, this);
  })) {
    report_error("Error while initiating module copy of " +
                 module->name + "\n" + describe_backtrace(err));

    /* Clean up some broken references to this module. */
    m_delete(otomod, me);

    if(module->copies)
      m_delete(module->copies, (int)id);
    else
      m_delete(module, "enabled");
    
    destruct(me);
    
    return 0;
  }
    
  if (err = catch(pr = me->query("_priority"))) {
    report_error("Error while initiating module copy of " +
                 module->name + "\n" + describe_backtrace(err));
    pr = 3;
  }

  api_module_cache |= me->api_functions();

  if(module->type & MODULE_EXTENSION) {
    if (err = catch {
      array arr = me->query_extensions();
      if (arrayp(arr)) {
        string foo;
        foreach( arr, foo )
          if(pri[pr]->extension_modules[ foo ])
            pri[pr]->extension_modules[foo] += ({ me });
          else
            pri[pr]->extension_modules[foo] = ({ me });
      }
    }) {
      report_error("Error while initiating module copy of " +
                   module->name + "\n" + describe_backtrace(err));
    }
  }   

  if(module->type & MODULE_FILE_EXTENSION) {
    if (err = catch {
      array arr = me->query_file_extensions();
      if (arrayp(arr)) {
        string foo;
        foreach( me->query_file_extensions(), foo )
          if(pri[pr]->file_extension_modules[foo] ) 
            pri[pr]->file_extension_modules[foo]+=({me});
          else
            pri[pr]->file_extension_modules[foo]=({me});
      }
    }) {
      report_error("Error while initiating module copy of " +
                   module->name + "\n" + describe_backtrace(err));
    }
  }

  if(module->type & MODULE_PROVIDER) {
    if (err = catch {
      mixed provs = me->query_provides();
      if(stringp(provs))  provs = (< provs >);
      else if(arrayp(provs))  provs = mkmultiset(provs);
      if (multisetp(provs)) pri[pr]->provider_modules [ me ] = provs;
    }) {
      report_error("Error while initiating module copy of " +
                   module->name + "\n" + describe_backtrace(err));
    }
  }
    
  if(module->type & MODULE_TYPES)
  {
    types_module = me;
    types_fun = me->type_from_filename;
  }
  
  if((module->type & MODULE_MAIN_PARSER))
  {
    parse_module = me;
    if (_toparse_modules) {
      Array.map(_toparse_modules,
                lambda(object o, object me, mapping module)
                {
                  array err;
                  if (err = catch {
                    me->add_parse_module(o);
                  }) {
                    report_error("Error while initiating module copy of " +
                                 module->name + "\n" +
                                 describe_backtrace(err));
                  }
                }, me, module);
    }
  }

  if(module->type & MODULE_PARSER)
  {
    if(parse_module) {
      if (err = catch {
        parse_module->add_parse_module( me );
      }) {
        report_error("Error while initiating module copy of " +
                     module->name + "\n" + describe_backtrace(err));
      }
    }
    _toparse_modules += ({ me });
  }

  if(module->type & MODULE_AUTH)
  {
    auth_module = me;
    auth_fun = me->authenticate;
  }

  if(module->type & MODULE_DIRECTORIES)
    dir_module = me;

  if(module->type & MODULE_LOCATION)
    pri[pr]->location_modules += ({ me });

  if(module->type & MODULE_LOGGER) 
    pri[pr]->logger_modules += ({ me });

  if(module->type & MODULE_URL)
    pri[pr]->url_modules += ({ me });

  if(module->type & MODULE_LAST)
    pri[pr]->last_modules += ({ me });

  if(module->type & MODULE_FILTER)
    pri[pr]->filter_modules += ({ me });

  if(module->type & MODULE_FIRST) 
    pri[pr]->first_modules += ({ me });

  if(module->type & MODULE_PRECACHE) 
    pri[pr]->precache_modules += ({ me });
  
  if(module->type & MODULE_ERROR)
    pri[pr]->error_modules += ({ me });
  
  hooks_for(module->sname+"#"+id, me);
      
  enabled_modules = retrieve("EnabledModules", this);

  if(!enabled_modules[modname+"#"+id])
  {
#ifdef MODULE_DEBUG
    perror("New module...");
#endif
    enabled_modules[modname+"#"+id] = 1;
    store( "EnabledModules", enabled_modules, 1, this);
  }
  invalidate_cache();
#ifdef MODULE_DEBUG
#if constant(gethrtime)
  perror(" Done (%3.3f seconds).\n", (gethrtime()-start_time)/1000000.0);
#else
  perror(" Done.\n");
#endif
#endif
  return me;
}

//! Called from the configuration interface.
string check_variable(string name, string value)
{
  switch(name)
  {
      case "Ports":
        ports_changed=1; 
        return 0;
      case "MyWorldLocation":
        if(strlen(value)<7 || value[-1] != '/' ||
           !(sscanf(value,"%*s://%*s/")==2))
          return "The URL should follow this format: protocol://computer[:port]/";
        return 0;
  }
}


// This is used to update the server-global and module variables
// between Roxen releases. It enables the poor roxen administrator to
// reuse the configuration file from a previous release. without any
// fuss. Configuration files from Roxen 1.0�11 pre 11 and earlier
// are not differentiated, but since that release is quite old already
// when I write this, that is not really a problem....


#define perr(X) do { report += X; perror(X); } while(0)

//! Used to hide some variables when logging is not enabled.
int log_is_not_enabled()
{
  return !QUERY(Log);
}

//! Used to hide the default charset variable
int default_charset_not_used()
{
  return !QUERY(set_default_charset);
}

//!
int disable_module( string modname )
{
  mapping module;
  mapping enabled_modules;
  object me;
  int pr;
  int id;

  sscanf(modname, "%s#%d", modname, id );

  module = modules[ modname ];

  if(!module) 
  {
    report_error("Failed to disable module\n"
                 "No module by that name: \""+modname+"\".\n");
    return 0;
  }

  if(module->copies)
  {
    me = module->copies[id];
    m_delete(module->copies, id);
    if(!sizeof(module->copies))
      unload_module(modname);
  } else {
    me = module->enabled || module->master;
    module->enabled=module->master = 0;
    unload_module(modname);
  }

  invalidate_cache();

  if(!me)
  {
    report_error("Failed to Disable "+module->name+" # "+id+"\n");
    return 0;
  }

  if(me->stop) me->stop();

#ifdef MODULE_DEBUG
  perror("Disabling "+module->name+" # "+id+"\n");
#endif

  if(module["type"] & MODULE_EXTENSION)
  {
    string foo;
    for(pr=0; pr<10; pr++)
      foreach( indices (pri[pr]->extension_modules), foo )
        pri[pr]->extension_modules[ foo ]-= ({ me });
  }

  if(module["type"] & MODULE_FILE_EXTENSION)
  {
    string foo;
    for(pr=0; pr<10; pr++)
      foreach( indices (pri[pr]->file_extension_modules), foo )
        pri[pr]->file_extension_modules[foo]-=({me});
  }

  if(module->type & MODULE_PROVIDER) {
    for(pr=0; pr<10; pr++)
      m_delete(pri[pr]->provider_modules, me);
  }
  if(module->type & MODULE_PRECACHE) {
    for(pr=0; pr<10; pr++)
      pri[pr]->precache_modules -= ({ me });
  }
  
  if(module["type"] & MODULE_TYPES)
  {
    types_module = 0;
    types_fun = 0;
  }

  if(module->type & MODULE_MAIN_PARSER)
    parse_module = 0;

  if(module->type & MODULE_PARSER)
  {
    if(parse_module)
      parse_module->remove_parse_module( me );
    _toparse_modules -= ({ me, 0 });
  }

  if( module->type & MODULE_AUTH )
  {
    auth_module = 0;
    auth_fun = 0;
  }

  if( module->type & MODULE_DIRECTORIES )
    dir_module = 0;


  if( module->type & MODULE_LOCATION )
    for(pr=0; pr<10; pr++)
      pri[pr]->location_modules -= ({ me });

  if( module->type & MODULE_URL )
    for(pr=0; pr<10; pr++)
      pri[pr]->url_modules -= ({ me });

  if( module->type & MODULE_LAST )
    for(pr=0; pr<10; pr++)
      pri[pr]->last_modules -= ({ me });

  if( module->type & MODULE_FILTER )
    for(pr=0; pr<10; pr++)
      pri[pr]->filter_modules -= ({ me });

  if( module->type & MODULE_FIRST ) {
    for(pr=0; pr<10; pr++)
      pri[pr]->first_modules -= ({ me });
  }

  if( module->type & MODULE_LOGGER )
    for(pr=0; pr<10; pr++)
      pri[pr]->logger_modules -= ({ me });

  if( module->type & MODULE_ERROR )
    for(pr=0; pr<10; pr++)
      pri[pr]->error_modules -= ({ me });

  enabled_modules=retrieve("EnabledModules", this);

  if(enabled_modules[modname+"#"+id])
  {
    m_delete( enabled_modules, modname + "#" + id );
    store( "EnabledModules",enabled_modules, 1, this);
  }
  destruct(me);
  return 1;
}

//! find a module
//! @param name
//!   the name of the module to find, where name is the base filename (foo if the file is called foo.pike).
//! @returns
//!  the module, or the first of multiple modules, or zero if the module does not exist.
object|string find_module(string name)
{
  int id;
  sscanf(name, "%s#%d", name, id);
  if(modules[name])
  {
    if(modules[name]->copies)
      return modules[name]->copies[id];
    else 
      if(modules[name]->enabled)
        return modules[name]->enabled;
  }
  return 0;
}

//!
void register_module_load_hook( string modname, function fun, mixed ... args )
{
  object o;
#ifdef MODULE_DEBUG
  perror("Registering a hook for the module "+modname+"\n");
#endif
  if(o=find_module(modname))
  {
#ifdef MODULE_DEBUG
    perror("Already there!\n");
#endif
    fun( @args, o );
  } else
    if(!_hooks[modname])
      _hooks[modname] = ({ ({ fun, args }) });
    else
      _hooks[modname] += ({ ({ fun, args }) });
}

//!
int load_module(string module_file)
{
  int foo, disablep;
  mixed err;
  array module_data;
  mapping loaded_modules;
  object obj;
  program prog;
#if constant(gethrtime)
  int start_time = gethrtime();
#endif
  // It is not thread-safe to use this.
  caudium->current_configuration = this_object();
#ifdef MODULE_DEBUG
  perror("\nLoading " + module_file + "... ");
#endif
 
  if(prog = cache_lookup("modules", module_file)) {
    err = catch {
      obj = prog(this_object());
    };
  } else {
    string dir;
    object e = ErrorContainer();
//    master()->set_inhibit_compile_errors(e);
    err = catch {
      obj = caudium->load_from_dirs(caudium->QUERY(ModuleDirs), module_file,
                                    this_object());
      prog = object_program(obj);
    };
    if(strlen(e->get())) {
      report_error("Failed to compile module "+module_file+":\n"+e->get());
      return 0;
    }
    e->print_warnings("Warnings while compiling module "+module_file+":");
  }

  if (err) {
    report_error("Error while enabling module (" + module_file + "):\n" +
                 describe_backtrace(err) + "\n");
    return(0);
  } else if(!obj) {
    report_error("*** Module load failed: " + module_file + " (not found?)\n");
    return 0;
  }

  if (err = catch (module_data = obj->register_module(this_object()))) {
#ifdef MODULE_DEBUG
    perror("FAILED\n" + describe_backtrace( err ));
#endif
    report_error("Module loaded, but register_module() failed (" 
                 + module_file + ").\n"  +
                 describe_backtrace( err ));
    return 0;
  }

  err = "";
  caudium->somemodules[module_file]=
    ({ module_data[1], module_data[2]+"<p><i>"+
       replace(obj->file_name_and_stuff(),"0<br>", module_file+"<br>")
       +"</i>", module_data[0] });
  if (!arrayp( module_data ))
    err = "Register_module didn't return an array.\n";
  else switch (sizeof( module_data ))
  {
      case 5:
        foo = module_data[4];
        module_data = module_data[0..3];
      case 4:
        if (module_data[3] && !arrayp( module_data[3] ))
          err = "The fourth element of the array register_module returned "
            "(extra_buttons) wasn't an array.\n" + err;
      case 3:
        if (!stringp( module_data[2] ))
          err = "The third element of the array register_module returned "
            "(documentation) wasn't a string.\n" + err;
        if (!stringp( module_data[1] ))
          err = "The second element of the array register_module returned "
            "(name) wasn't a string.\n" + err;
        if (!intp( module_data[0] ))
          err = "The first element of the array register_module returned "
            "(type) wasn't an integer.\n" + err;
        break;

      default:
        err = "The array register_module returned was too small/large. "
          "It should have been three or four elements (type, name, "
          "documentation and extra buttons (optional))\n";
  }
  if (strlen(err))
  {
#ifdef MODULE_DEBUG
    perror("FAILED\n"+err);
#endif
    report_error( "Tried to load module " + module_file + ", but:\n" + err );
    if(obj) destruct( obj );
    return 0;
  } 
    
  if (sizeof(module_data) == 3)
    module_data += ({ 0 }); 

  if(!foo)
  {
    destruct(obj);
    obj=0;
  } else {
    otomod[obj] = module_file;
  }

  if(!modules[ module_file ])
    modules[ module_file ] = ([]);

  mapping tmpp = modules[ module_file ];

  tmpp->type  = module_data[0];
  tmpp->name  = module_data[1];
  tmpp->doc = module_data[2];
  tmpp->extra = module_data[3];
  tmpp->master  = obj;
  tmpp->copies  = (foo ? 0 : (tmpp->copies || ([])));
  tmpp->sname = module_file;
  tmpp["program"] = prog;
      
#ifdef MODULE_DEBUG
#if constant(gethrtime)
  perror(" Done (%3.3f seconds).\n", (gethrtime()-start_time)/1000000.0);
#else
  perror(" Done.\n");
#endif
#endif
  cache_set("modules", module_file, modules[module_file]["program"], 21600); // Chanhed to store cached module for 6 hours.
  return 1;
}

//�
int unload_module(string module_file)
{
  mapping module;
  int id;

  module = modules[ module_file ];

  if(!module) 
    return 0;

  if(objectp(module->master)) 
    destruct(module->master);

  cache_remove("modules", module_file);
  
  m_delete(modules, module_file);

  return 1;
}

//! add a set of modules to this configuration.
//! @param mods
//!   an array of module names to add, where the module name is the base name of the module file, minus any file extensions.
int add_modules (array(string) mods)
{
  foreach (mods, string mod)
    if(!modules[mod] || !modules[mod]->copies && !modules[mod]->master)
      enable_module(mod+"#0");
  if(caudium->root)
    caudium->configuration_interface()->build_root(caudium->root);
}

//!
int port_open(array prt)
{
  return(server_ports[MKPORTKEY(prt)] != 0);
}

//! Function to add the current webserver to netcraft :)
static string netcraft_submit()
{
  if (query("netcraft_done"))
    return "";

  string ret =
    "<blockquote><table width='400'><tr><td>" 
    "The Caudium Group would appreciate if you agreed to submit the name "
    "of this virtual domain to the <a href='http://netcraft.com' target='self_'>NetCraft.Com</a> "
    "server survey. That would help making Caudium more recognized and popular.<br>"
    "As soon as you click either button, this form will not be visible in this virtual "
    "host ever again.<br>"
    "Thank you in advance for your support!</td></tr>"
    "<tr><td>"
    "<form action='/(netcraft)/Configurations/%s/Global/netcraft_done' method='POST' name='netcraftform' target='self_'>"
    "<input type='hidden' name='/Configurations/%s/Global/netcraft_done' value='1'>"
    "<input type='hidden' name='URL' value='%s'>"
    "<input type='hidden' name='random' value='%d'>"
    "<input type='submit' name='goahead' value='OK, go ahead'>&nbsp;"
    "<input type='submit' name='forgetit' value='Forget it.'>"
    "</form></td></tr></table></blockquote><br>";

  return sprintf(ret, name, name, query("MyWorldLocation"), random(123456));
}

//!
string desc()
{
  string res="";
  array (string|int) port;

  if(!sizeof(QUERY(Ports)))
  {
/*    array ips = caudium->configuration_interface()->ip_number_list;*/
/*    if(!ips) caudium->configuration_interface()->init_ip_list;*/
/*    ips = caudium->configuration_interface()->ip_number_list;*/
/*    foreach(ips||({}), string ip)*/
/*    {*/
      
/*    }*/

    array handlers = ({});
    foreach(caudium->configurations, object c)
      if(c->modules["ip-less_hosts"] || c->modules["hostmatch"])
        handlers+=({({Caudium.http_encode_string("/Configurations/"+c->name),
                      strlen(c->query("name"))?c->query("name"):c->name})});

    
    if(sizeof(handlers)==1)
    {
      res = "This server is handled by the ports in <a href=\""+handlers[0][0]+
        "\">"+handlers[0][1]+"</a><br>\n";
    } else if(sizeof(handlers)) {
      res = "This server is handled by the ports in any of the following servers:<br>";
      foreach(handlers, array h)
        res += "<a href=\""+h[0]+"\">"+h[1]+"</a><br>\n";
    } else
      res=("There are no ports configured, and no virtual server seems "
           "to have support for ip-less virtual hosting enabled<br>\n");
  }
  
  foreach(QUERY(Ports), port)
  {
    string prt, prtfile, modprt;
    
    prtfile = port[1] + "://";
    switch(port[1][0..2])
    {
        case "ssl":
          prt = "https://";
          break;
        case "ftp":
          prt = "ftp://";
          break;
      
        default:
          prt = (modprt = make_proto_name(port[1]))+"://";
    }
    
    if(port[2] && port[2]!="ANY") {
      prt += port[2];
      prtfile += port[2] ;
    } 
#if constant(gethostname)
    else {
      prt += (gethostname()/".")[0] + "." + QUERY(Domain);
      prtfile = modprt ? replace(prt, modprt, port[1]) : prt;
    }
#endif
    prt += ":"+port[0]+"/";
    prtfile += ":" + port[0] + "/";

    if(port_open( port ))
      res += "<font color=darkblue><b>Open:</b></font> <a target=server_view href=\""+prt+"\">"+prtfile+"</a> \n<br>";
    else
      res += "<font color=red><b>Not open:</b> <a target=server_view href=\""+
        prt+"\">"+prtfile+"</a></font> <br>\n";
  }
  return (res+"<font color=darkgreen>Server URL:</font> <a target=server_view "
          "href=\""+query("MyWorldLocation")+"\">"+query("MyWorldLocation")+"</a><p>"
          + netcraft_submit());
}

// BEGIN SQL

//! The SQL urls 
mapping(string:string) sql_urls = ([]);

//! The SQL Cache
mapping(string|object:mapping|object) sql_cache = ([]);

//!
object sql_cache_get(string what)
{
#ifdef THREADS
#if !constant(this_thread)
  return Sql.Sql( what );
#else
  string key;
#if defined(__MAJOR__) && __MAJOR__ >= 7 
  // Reports has come in that this_thread() might return different
  // objects even if the thread is the same. We avoid this problem by using
  // the textual representation which includes the thread id. Only works
  // in Pike 7.0 where _sprintf is supported.
  key = sprintf("%O\n", this_thread());
#else
  key = this_thread();
#endif
  if(sql_cache[what] && sql_cache[what][key])
    return sql_cache[what][key];
  if(!sql_cache[what])
    sql_cache[what] =  ([ key:Sql.Sql( what ) ]);
  else
    sql_cache[what][ key ] = Sql.Sql( what );
  return sql_cache[what][ key ];
#endif   /* !this_thread */
#else /* !THREADS */
  if(!sql_cache[what])
    sql_cache[what] =  Sql.Sql( what );
  return sql_cache[what];
#endif
}

//! Backend use to do thread safe connect to SQL
//! @seealso
//!  @[SqlDB]
object sql_connect(string db)
{
  if (sql_urls[db]) {
    return(sql_cache_get(sql_urls[db]));
  } else {
    return(sql_cache_get(db));
  }
}

// END SQL

// This is the most likely URL for a virtual server.
private string get_my_url()
{
  string s;
#if constant(gethostname)
  s = (gethostname()/".")[0] + "." + query("Domain");
  s -= "\n";
#else
  s = "localhost";
#endif
  return "http://" + s + "/";
}
#ifdef THREADS
Thread.Mutex enable_modules_mutex = Thread.Mutex();
#define MODULE_LOCK() \
  Thread.MutexKey enable_modules_lock = enable_modules_mutex->lock (2)
#else
#define MODULE_LOCK()
#endif

int inited;

//! Enable all modules
void enable_all_modules()
{
  MODULE_LOCK();
  array err;
  inited = 1;
  if(err = catch { low_enable_all_modules();  })
    werror("Error while loading modules in configuration "+
           name+":\n"+ describe_backtrace(err)+"\n");
  
}

//!
void low_enable_all_modules() {
#if constant(gethrtime)
  int start_time = gethrtime();
#endif
  array modules_to_process=sort(indices(retrieve("EnabledModules",this)));
  string tmp_string;

  parse_log_formats();
  // Don't automatically open the log file until it's used.
  //  init_log_file();
  perror("\nEnabling all modules for "+query_name()+"... \n");

#if constant(_compiler_trace)
  // _compiler_trace(1);
#endif /* !constant(_compiler_trace) */
  
  // Always enable the user database module first.
  if(search(modules_to_process, "userdb#0")>-1)
    modules_to_process = (({"userdb#0"})+(modules_to_process-({"userdb#0"})));


  array err;
  foreach( modules_to_process, tmp_string )
    if(err = catch( enable_module( tmp_string ) ))
      report_error("Failed to enable the module "+tmp_string+". Skipping\n"
#ifdef MODULE_DEBUG
                   +describe_backtrace(err)+"\n"
#endif
                  );
  if(parse_module) parse_module->build_callers();
  caudium->current_configuration = 0;
#if constant(gethrtime)
  perror("\nAll modules for %s enabled in %4.3f seconds\n\n", query_name(),
         (gethrtime()-start_time)/1000000.0);
#endif
}

#ifdef ENABLE_RAM_CACHE
//! Cacher for super request speed.
class DataCache
{
  mapping(string:array(string|mapping(string:mixed))) cache = ([]);

  int current_size;
  int max_size, gc_size;
  int max_file_size;
  
  int hits, misses;

  //!
  static void clear_some_cache()
  {
    int i;
    array q = indices( cache );
    while(current_size > gc_size && i < sizeof(q))
    {
      current_size -= strlen( cache[ q[i] ][0] );
      m_delete( cache, q[i] );
      i++;
    }
  }

  //!
  void expire_entry( string url )
  {
    if( cache[ url ] )
    {
      current_size -= strlen(cache[url][0]);
      m_delete( cache, url );
    }
  }

  //!
  void set( string url, string data, mapping meta, int expire )
  {
    remove_call_out(url);
    call_out( expire_entry, expire, url );
    current_size += strlen(data);
    if(current_size > max_size)
      clear_some_cache();
    cache[url] = ({ data, meta });
  }
  
  //!
  array(string|mapping(string:mixed)) get( string url, mapping request_headers )
  {
    mixed res;
    
    if( res = cache[ url ] ) {
      // Fixme: we need ETag (If-Match, If-None-Match and Vary) processing here
      hits++;
    } else
      misses++;
    return res;
  }

  //!
  void init_from_variables(int _size, int _fsize, float gc_cleanup)
  {
    max_size = _size;
    max_file_size = _fsize;
    gc_size = (int)(max_size * (1 - gc_cleanup));
    while( current_size > max_size )
      clear_some_cache();
  }

  //!
  static void create(int _size, int _fsize, float gc_cleanup )
  {
    init_from_variables(_size,_fsize, gc_cleanup);
  }
};

object(DataCache) datacache;
#endif

//!
void create(string config)
{
  int|array currentipaddress = gethostbyname(gethostname()); // The ip address
                                                             // of this machine
  caudium->current_configuration = this;
  name=config;

  perror("Creating virtual server '"+config+"'\n");

  defvar("set_default_charset", 0, "Set the default charset", TYPE_FLAG,
         "If set then Caudium will set the specified charset "
	 "for the served document. The value can be overriden only by setting "
	 "a per-file character set from within RXML or Pike code.");
  
  defvar("content_charset", "iso-8859-1", "Default content charset", TYPE_STRING,
         "This variable specifies the default content charset for this server. "
         "This value is sent in the <strong>Content-Type</strong> response "
         "header. <strong>If this option is used, the &lt;meta&gt; tag which sets "
	 "the character set will be ignored.</strong><br>"
         "The format for this option is a valid ISO character set value in "
         "lowercase.", 0, default_charset_not_used);
  
  defvar("netcraft_done", 0, "Netcraft submission done", TYPE_INT | VAR_MORE,
         "If different than 0, the domain has been submitted to Netcraft "
         "already and the submission form won't appear at the top of the "
         "virtual server's description.");
  
#ifdef ENABLE_RAM_CACHE
// for now only theese two. In the future there might be more variables.
  defvar( "data_cache_size", 2048, "Data Cache:Cache size",
          TYPE_INT,"The size of the data cache used to speed up requests "
          "for commonly requested files, in KBytes");

  defvar( "data_cache_file_max_size", 50, "Data Cache:Max file size",
          TYPE_INT, "The maximum size of a file that is to be "
          "considered for the cache");
  defvar( "data_cache_gc_cleanup", 25, "Data Cache:Garbage Collection Percentage",
          TYPE_INT_LIST, "The amount of the cache space to clean up during "
          "a garbage collection run in percent. If you have a large cache, "
          "you can make this value lower. With a small cache and a small "
          "percentage the GC routine will run more often.",
          ({ 5, 10, 15, 20, 25, 30, 35, 40, 50 }));
#endif
  defvar("ErrorTheme", "", "Error Theme", TYPE_STRING,
         "This is the theme to apply to any error messages generated " +
         "automatically by this server. Please enter an absolute path on the virtual " +
         "filesystem(s), otherwise the system-wide default will be used." );
  
  defvar("Old404", 1, "Old-style 404's", TYPE_FLAG,
         "This allows you to override the new style error responses and use " +
         "the old fasioned 404 handling." );
  defvar("ZNoSuchFile", "<title>Sorry. I cannot find this resource</title>\n"
         "<body background='/(internal,image)/cowfish-bg' bgcolor='#ffffff'\n"
         "text='#000000' alink='#ff0000' vlink='#00007f' link='#0000ff'>\n"
         "<h2 align='center'><configimage src='cowfish-caudium' \n"
         "alt=\"File not found\"><p><hr noshade>\n"
         "\n<i>Sorry</i></h2>\n"
         "<br clear>\n<font size=\"+2\">The resource requested "
         "<i>$File</i>\ncannot be found.<p>\n\nIf you feel that this is a "
         "configuration error, please contact "
         "the administrators or the author of the\n"
         "<if referrer>"
         "<a href=\"<referrer>\">referring</a>"
         "</if>\n"
         "<else>referring</else>\n"
         "page."
         "<p>\n</font>\n"
         "<hr noshade>"
         "<version>, at <a href=\"$Me\">$Me</a>.\n"
         "</body>\n", 

         "No such file Message (eg. 404 error)", TYPE_TEXT_FIELD,
         "<b>This is depreciated, and will only work when &quot;Old-style 404's&quot; "
         "is turned on.</b><br>"
         "What to return when there is no resource or file available "
         "at a certain location. $File will be replaced with the name "
         "of the resource requested, and $Me with the URL of this server ");

  defvar("ZAuthenticationFailed", "<h1>Authentication Failed.</h1>\n",
         "Messages: Authentication Failed - Error 401", TYPE_TEXT_FIELD,
         "What to return when authentication has failed");

  defvar("comment", "", "Virtual server comment",
         TYPE_TEXT_FIELD|VAR_MORE,
         "This text will be visible in the configuration interface, it "
         " can be quite useful to use as a memory helper.");
  
  defvar("name", "", "Virtual server name",
         TYPE_STRING|VAR_MORE,
         "This is the name that will be used in the configuration "
         "interface. If this is left empty, the actual name of the "
         "virtual server will be used");
  defvar("LogFormat", 
         "*: $host - $user [$cern_date] \"$method $resource $protocol\" $response $length \"$referer\" \"$agent_unquoted\""
         ,
         "Logging: Format", 
         TYPE_TEXT_FIELD,  
         "What format to use for logging. The syntax is:\n"
         "<pre>"
         "response-code or *: Log format for that response acode\n\n"
         "Log format is normal characters, or one or more of the "
         "variables below:\n"
         "\n"
         "$host          -- The remote host name, or ip number.\n"
         "$ip_number     -- The remote ip number.\n"
         "$bin-ip_number -- The remote host id as a binary integer number.\n"
         "\n"
         "$cern_date     -- Cern Common Log file format date.\n"
         "$bin-date      -- Time, but as an 32 bit iteger in network byteorder\n"
         "\n"
         "$method        -- Request method\n"
         "$resource      -- Resource identifier\n"
         "$full_resource -- The full requested resource, with query fields and all\n"
         "$protocol      -- The protocol used (normally HTTP/1.0)\n"
         "$response      -- The response code sent\n"
         "$bin-response  -- The response code sent as a binary short number\n"
         "$length        -- The length of the data section of the reply\n"
         "$bin-length    -- Same, but as an 32 bit iteger in network byteorder\n"
         "$request-time  -- The time the request took (seconds)\n"
         "$referer       -- the header 'referer' from the request, or '-'.\n"
         "$user_agent    -- the header 'User-Agent' from the request, or '-'.\n\n"
         "$agent_unquoted -- the unquoted header 'User-Agent' from the request, or '-'.\n\n"
         "$user          -- the name of the auth user used, if any\n"
         "$user_id       -- A unique user ID, if cookies are supported,\n"
         "                  by the client, otherwise '0'\n"
         "</pre>", 0, log_is_not_enabled);
  
  defvar("max_open_time", 300, "Logging: Maximum idle time before closing",
         TYPE_INT_LIST,
         "This variables sets the idle timeout before in seconds an opened "
         "log file is closed. The benefit of this variable is that little "
         "used virtual servers won't waste file descriptors. Set to zero "
         "to disable this feature.", ({ 0, 60, 120, 180,240,300,400,500,600 }),
         log_is_not_enabled);
  defvar("PostBodySize", POST_MAX_BODY_SIZE, 
	 "Maximum body size for a POST request",
	 TYPE_INT, "This variable determines how large a body of a POST "
	 "request could become. If the value is -1 the size is unlimited."
	 "A value of 0 ignores the body completely.");

  defvar("Log", 1, "Logging: Enabled", TYPE_FLAG, "Log requests");
  
  defvar("LogFile", caudium->QUERY(logdirprefix)+
         Caudium.short_name(name)+"/Log", 

         "Logging: Log file", TYPE_FILE, "The log file. "
         ""
         "A file name. May be relative to "+getcwd()+"."
         " Some substitutions will be done:"
         "<pre>"
         "%y    Year  (i.e. '1997')\n"
         "%m    Month (i.e. '08')\n"
         "%d    Date  (i.e. '10' for the tenth)\n"
         "%h    Hour  (i.e. '00')\n"
         "%H    The hostname of the server machine.\n"
         "</pre>"
         ,0, log_is_not_enabled);
  
  defvar("NoLog", ({ }), 
         "Logging: No Logging for", TYPE_STRING_LIST|VAR_MORE,
         "Don't log requests from hosts with an IP number which matches any "
         "of the patterns in this list. This also affects the access counter "
         "log.\n",0, log_is_not_enabled);
  
  defvar("Domain", caudium->get_domain(), "Domain", TYPE_STRING,
         "Your domainname, should be set automatically, if not, "
         "enter the correct domain name here, and send a bug report to "
         "<a href=\"mailto:caudium-bugs@caudium.net\">caudium-bugs@caudium.net"
         "</a>");

  defvar("Ports", ({ }), 
         "Listen ports", TYPE_PORTS,
         "The ports this virtual instance of Caudium will bind to.\n");

  defvar("MyWorldLocation", get_my_url(), 
         "Server URL", TYPE_STRING,
         "This is where your start page is located.");


// This should be somewhere else, I think. Same goes for HTTP related ones

  defvar("FTPWelcome",  
         "              +--------------------------------------------------\n"
         "              +-- Welcome to the Caudium Webserver FTP server ---\n"
         "              +--------------------------------------------------\n",
         "FTP:FTP Welcome message",
         TYPE_TEXT_FIELD|VAR_MORE,
         "FTP Welcome answer; transmitted to new FTP connections if the file "
         "<i>/welcome.msg</i> doesn't exist.\n");
  
  defvar("named_ftp", 0, "FTP:Allow named FTP", TYPE_FLAG|VAR_MORE,
         "Allow ftp to normal user-accounts (requires an authentication "
         "module, e.g. 'User database and security').\n");

  defvar("passive_ftp", 1, "FTP:Allow passive FTP", TYPE_FLAG|VAR_MORE,
         "Allow passive transfers on ftp server.");
 
  defvar("restricpasv", 1, "FTP:Restrict Passive FTP ports", TYPE_FLAG|VAR_MORE,
         "Restrict passive FTP port to a specific range. For example when "
         "using Caudium as a FTP server behind a firewall or in a NATed "
         "environment.");

  defvar("lowpasvport",65000, "FTP:Passive FTP lowest port",TYPE_INT|VAR_MORE,
         "The lowest port to use when Restrict Passive FTP ports is set.");

  defvar("hipasvport",65530, "FTP:Passive FTP highest port",TYPE_INT|VAR_MORE,
         "The highest port to use when Restrict Passive FTP port is set.");

  defvar("maxpasvtry", 3, "FTP:Passive FTP max attempts", TYPE_INT|VAR_MORE,
         "Number of trys to open a Passive port when Restrict Passive FTP "
         "is set. Caudium will random the use of the range. If it cannot "
         "open a port then passive transfert will failled.");

  defvar("pasvnat", 0, "FTP:Passive FTP NAT support", TYPE_FLAG|VAR_MORE,
         "Enable NAT (Network Address Translation) support for Passive "
         "transferts. This allow you to specify the real IP address used "
         "by the NATed ftp server.");

  defvar("pasvipaddr", arrayp(currentipaddress)?currentipaddress[1][0]:"127.0.0.1",
         "FTP:Passive FTP NATed real address", TYPE_STRING|VAR_MORE,
         "When Passive FTP NAT support is set, can specify the real IP "
         "address to send in Passive transfert requests.");

  defvar("anonymous_ftp", 0, "FTP:Allow anonymous FTP", TYPE_FLAG|VAR_MORE,
         "Allows anonymous ftp.\n");

  defvar("guest_ftp", 0, "FTP:Allow FTP guest users", TYPE_FLAG|VAR_MORE,
         "Allows FTP guest users.\n");

  defvar("ftp_user_session_limit", 0,
         "FTP:FTP user session limit", TYPE_INT|VAR_MORE,
         "Limit of concurrent sessions a FTP user may have. 0 = unlimited.\n");

  defvar("shells", "/etc/shells", "FTP:Shell database", TYPE_FILE|VAR_MORE,
         "File which contains a list of all valid shells\n"
         "(usually /etc/shells). Used for named ftp.\n"
         "Specify the empty string to disable shell database lookup.\n");

  defvar("ftpnohomedeny", 0, "FTP: Deny named users with non-existant homedir",
         TYPE_FLAG|VAR_MORE,"Deny access to ftp named users when homedir "
         "exist.");
  // This one works only on Pike 7.0 do I need to make a condition on 1.1 ?
  // -- Xavier
  defvar("ftphomedircreate", 0, "FTP: Autocreate homedirs", TYPE_FLAG|VAR_MORE,
         "Autocreate the homedirectory if it doesn't exist.");
  
  defvar("ftphdirautoext", 0, "FTP: Autocreate homedirs extended", TYPE_FLAG|VAR_MORE,
         "If set to \"Yes\", then this will create also directories into "
         "homedirectory specified in Autocreate homedirs extras.");
  defvar("ftphdirxtra","htdocs:0755,cgi-bin:0755,logs:0775", "FTP: Autocreate homedirs extras", TYPE_STRING|VAR_MORE,
         "Coma-sparated homedirectory to be created also in homedirectory. "
         "You can add the default permissions for those directories by add "
         "the unix style octal permissions behind a ':'.<br />"
         "<i>Example:</i> <tt>htdocs:0755,cgi-bin:0755,logs:0775,tmp:1777</tt>"
         "<br />Used only if Autocreate homedirs <b>AND</b> Autocreate "
         "homedir extended are set to \"Yes\"");

  defvar("InternalLoc", "/_internal/", 
         "Internal module resource mountpoint", TYPE_LOCATION|VAR_MORE,
         "Some modules may want to create links to internal resources.  "
         "This setting configures an internally handled location that can "
         "be used for such purposes.  Simply select a location that you are "
         "not likely to use for regular resources.");
   
  defvar("use_scopes", "On/Conditional", "Scopes compatibility", TYPE_STRING_LIST,
         "<p>This compatibility option manages the new feature of the Caudium Webserver "
         "known as <em>scopes</em>.</p>"
         "<p>Under Roxen 1.3, variable names can contain periods "
         "(such as \"new.form.variable\") but with Caudium the "
         "scope-parsing code will attempt to make this a variable "
         "called \"form.variable\" in the \"new\" scope - and since "
         "there is no scope called \"new\", the action will fail - "
         "this breaks compatablity with existing RXML. A small example "
         "to illustrate the situation:</p>"
         "<blockquote><pre>"
         "&lt;if variable=\"new.formvar is \"&gt;\n"
         "\t&lt;set variable=\"new.formvar\" value=\"blargh\"&gt;\n"
         "&lt;/if&gt;\n"
         "&lt;formoutput&gt;\n"
         "\t&lt;form&gt;\n"
         "\t\t&lt;input name=\"new.formvar\""
         "value=\"#new.formvar#\"&gt;&lt;\n"
         "\t/form&gt;\n"
         "&lt;/formoutput&gt;"
         "</pre></blockquote>",
         ({ "On", "Off", "On/Conditional", "Off/Conditional" }));

  /* CONFIGS LOADER IS HERE!! AND I CURSE WHOMEVER CREATED THAT MESS! /grendel :P */
  setvars(retrieve("spider#0", this));

}

//! Used to print all configuration for a virtual server
string _sprintf( )
{
  return "Configuration("+name+")";
}

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
