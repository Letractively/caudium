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

//! This class should be inherited by any code that implements a Caudium
//! module. It defines all the API that must be found in any Caudium module
//! and provides reasonable defaults for the elements not implemented in
//! the inheriting class.

#include <module.h>
#include <pcre.h>

inherit "cachelib";

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

//! The module variable store.
mapping (string:array) variables=([]);

constant is_module = 1;
constant module_type   = MODULE_ZERO;
constant module_name   = "Unnamed module";
constant module_doc    = "Undocumented";
constant module_unique = 1;
object this = this_object();

//! Remove cvs marker: "$", "Id: " and "Exp $"
//!
//! @param from
//!  String to be cleaned
//!
//! @returns
//!  String cleaned
//!
//! @note
//!   Non-RIS code
string fix_cvs(string from)
{
  from -= "$";
  sscanf(from, "Id: %*s,v %s  Exp ", from);
  return from;
}

//! Makes sure that all the modules required by the caller module are
//! present before it initializes. Should be called as the first function
//! in your @[start()] method.
//!
//! @param configuration
//!  The @[id->conf] configuration object.
//!
//! @param modules
//!  An array of module names this function should load.
//!  The module name is typically the filename of the module minus any 
//!  extension.
//!
//! @example
//!  // we need to require the obox (outline box) module.
//!  module_dependencies(conf, ({"obox"}));
//!
int module_dependencies(object configuration, array (string) modules)
{
  if(configuration) configuration->add_modules (modules);
  mixed err;
  //  if (err = catch (_do_call_outs()))
  //    report_error ("Error doing call outs:\n" + describe_backtrace (err));
  return 1;
}

//! Returns file name and cvs version for the current module
string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+(caudium->filename(this))+"<br>"+
          (this->cvs_version?"<b>CVS Version: </b>"+fix_cvs(this->cvs_version)+"<nr>\n":""));
}

static private object _my_configuration;

//! Returns the module's configuration object.
//!
//! Useful for working outside a request (when you don't have request_id).
object my_configuration()
{
  if(_my_configuration)
    return _my_configuration;
  object conf;
  foreach(caudium->configurations, conf)
    if(conf->otomod[this])
      return conf;
  return 0;
}

string module_creator;
string module_url;

nomask void set_configuration(object c)
{
  if(_my_configuration && _my_configuration != c)
    error("set_configuration() called twice.\n");
  _my_configuration = c;
}

//! Sets the module creator.
void set_module_creator(string c)
{
  module_creator = c;
}

//! Returns the module creator.
string get_module_creator()
{
  return module_creator;
}

//! Sets the module url.
void set_module_url(string to)
{
  module_url = to;
}

//! Returns the module url.
string get_module_url()
{
  return module_url;
}

//! Removes the specified variable from the variable store.
//!
//! @param var
//!  Name of the variable to be removed.
int killvar(string var)
{
  if(!variables[var]) error("Killing undefined variable.\n");
  m_delete(variables, var);
  return 1;
}

//!
void free_some_sockets_please(){}

//! The first method called when the module is loaded. It is called only
//! once when the module is initialized (loaded or reloaded).
//!
//! @param num
//!  If the module can exist in several copies, this parameter gives the
//!  number saying which copy the new instance is.
//!
//! @param conf
//!  The configuration object.
void start(void|int num, void|object conf) {}

//! Module-specific status information. You can return anything that has
//! any meaning for the module.
//!
//! @returns
//!  The status string displayed in the CIF
string status() {}

//! Returns information about the module.
string info(object conf)
{ 
  return this->register_module()[2];
}

//!
static class ConfigurableWrapper
{
  int mode;
  function f;

  //!
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

  //!
  //! @param mode_
  //!   Specifies the mode that the wrapper should work in.
  //!   May contain the bitwise OR of VAR_EXPERT and VAR_MORE.
  //!
  //! @param f_
  //!   The function to be called if we are not in mode_.
  //! 
  //! @returns
  //!    1 if we are not in mode, or f_() otherwise.
  //!
  void create(int mode_, function f_)
  {
    mode = mode_;
    f = f_;
  }
};

//!  Define a configuration variable in the CIF, with error checking.
//!  Usually called by the constructor of the module (create()).
//!
//! @param var
//!  Name used to identify the variable.
//!
//! @param value
//!  Variable's default value.
//!
//! @param name
//!  Name the variable will be given in the configuration interface.
//!  A colon (":") in the name can be used to build submenus.
//!
//! @param type
//!  Variable's type. The data input by the user will be checked.
//!  Available types are:
//!  @int
//!   @value TYPE_FLAG
//!    yes/no choice. Stored as an int.
//!   @value TYPE_INT
//!    integer number.
//!   @value TYPE_INT_LIST
//!    list of int. Stored as an array of int.
//!   @value TYPE_MULTIPLE_INT
//!    int chosen from a list.
//!   @value TYPE_FLOAT
//!    floating point number.
//!   @value TYPE_STRING
//!    string.
//!   @value TYPE_STRING_LIST
//!    list of strings. Stored as an array os string.
//!   @value TYPE_MULTIPLE_STRING
//!    string chosen from a list.
//!   @value TYPE_TEXT
//!    text. Stored as a string.
//!   @value TYPE_TEXT_FIELD
//!    multiple lines text. Stored as a string.
//!   @value TYPE_FILE
//!    path to a file in the filesystem. Stored as a string.
//!   @value TYPE_FILE_LIST
//!    list of paths (files/directories) in the filesystem. Stored as an array of string.
//!   @value TYPE_DIR
//!    path to a dir in the filesystem. Stored as a string.
//!   @value TYPE_DIR_LIST
//!    list of directories. Stored as an array of string.
//!   @value TYPE_LOCATION
//!    mountpoint in virtual filesystem. Stored as a string.
//!   @value TYPE_COLOR
//!    int containing 24bit RGB color value.
//!   @value TYPE_PASSWORD
//!    password. Stored via unix crypt().
//!   @value TYPE_CUSTOM
//!    custom variable type. if used, the misc field must be an array of 
//!    function pointers: ({describe,describe_form,set_from_form})
//!  @endint
//!
//! @param doc_str
//!  Documentation for the variable.
//!  If a newline (\n) is present in the first line, the user will have a
//!  "more documentation" button for accessing following lines.
//!
//! @param misc
//!  Only used for TYPE_MULTIPLE_* types.
//!  This field contains array(int|string) for possible values. Ignore or set
//!  to 0 for other types.
//!
//! @param not_in_config
//!  Integer value or function.
//!  If integer or return of the function is 0, then the variable will be
//!  shown. It will be hidden otherwise.
//!  Usefull for hidding a variable depending of the value of another variable.
void defvar(string|void var, mixed|void value, string|void name,
            int|void type, string|void doc_str, mixed|void misc,
            int|function|void not_in_config)
{
  if(!strlen(var))
    error("No name for variable!\n");

//  if(var[0]=='_' && previous_object() != roxen)
//    error("Variable names beginning with '_' are reserved for"
//	    " internal usage.\n");

  if (!stringp(name))
    name = var;

  if((search(name, "\"") != -1))
    error("Please do not use \" in variable names");
  
  if (!stringp(doc_str))
    doc_str = "No documentation";
  
  switch (type & VAR_TYPE_MASK)
  {
      case TYPE_NODE:
        if(!arrayp(value))
          error("TYPE_NODE variables should contain a list of variables "
                "to use as subnodes.\n");
        break;
      case TYPE_CUSTOM:
        if(!misc
           && arrayp(misc)
           && (sizeof(misc)>=3)
           && functionp(misc[0])
           && functionp(misc[1])
           && functionp(misc[2]))
          error("When defining a TYPE_CUSTOM variable, the MISC "
                "field must be an array of functionpointers: \n"
                "({describe,describe_form,set_from_form})\n");
        break;

      case TYPE_TEXT_FIELD:
      case TYPE_FILE:
      case TYPE_EXISTING_FILE:
      case TYPE_STRING:
      case TYPE_LOCATION:
      case TYPE_PASSWORD:
        if(value && !stringp(value)) {
          report_error(sprintf("%s:\nPassing illegal value (%t:%O) "
                               "to string type variable.\n",
                               caudium->filename(this), value, value));
        }
        break;
    
      case TYPE_FLOAT:
        if(!floatp(value))
          report_error(sprintf("%s:\nPassing illegal value (%t:%O) "
                               "(not float) to floating point "
                               "decimal number variable.\n",
                               caudium->filename(this), value, value));
        break;
      case TYPE_INT:
        if(!intp(value))
          report_error(sprintf("%s:\nPassing illegal value (%t:%O) "
                               "(not int) to integer number variable.\n",
                               caudium->filename(this), value, value));
        break;
     
      case TYPE_MODULE_LIST:
        value = ({});
        break;
    
      case TYPE_MODULE:
        /* No default possible */
        value = 0;
        break;

      case TYPE_DIR_LIST:
        int i;
        if(!arrayp(value)) {
          report_error(sprintf("%s:\nIllegal type %t to TYPE_DIR_LIST, "
                               "must be array.\n",
                               caudium->filename(this), value));
          value = ({ "./" });
        } else {
          for(i=0; i<sizeof(value); i++) {
            if(strlen(value[i])) {
              if(value[i][-1] != '/')
                value[i] += "/";
            } else {
              value[i]="./";
            }
          }
        }
        break;

      case TYPE_DIR:
        if(value && !stringp(value))
          report_error(sprintf("%s:\nPassing illegal value (%t:%O) (not string) "
                               "to directory variable.\n",
                               caudium->filename(this), value, value));
    
        if(value && strlen(value) && ((string)value)[-1] != '/')
          value+="/";
        break;
    
      case TYPE_INT_LIST:
      case TYPE_STRING_LIST:
        if(!misc && value && !arrayp(value)) {
          report_error(sprintf("%s:\nPassing illegal misc (%t:%O) (not array) "
                               "to multiple choice variable.\n",
                               caudium->filename(this), value, value));
        } else {
          if(misc && !arrayp(misc)) {
            report_error(sprintf("%s:\nPassing illegal misc (%t:%O) (not array) "
                                 "to multiple choice variable.\n",
                                 caudium->filename(this), misc, misc));
          }
          if(misc && value && search(misc, value)==-1) {
            roxen_perror(sprintf("%s:\nPassing value (%t:%O) not present "
                                 "in the misc array.\n",
                                 caudium->filename(this), value, value));
          }
        }
        break;
    
      case TYPE_FLAG:
        value=!!value;
        break;
    
      case TYPE_ERROR:
        break;

      case TYPE_COLOR:
        if (!intp(value))
          report_error(sprintf("%s:\nPassing illegal value (%t:%O) (not int) "
                               "to color variable.\n",
                               caudium->filename(this), value, value));
        break;
    
      case TYPE_FILE_LIST:
      case TYPE_PORTS:
      case TYPE_FONT:
        // FIXME: Add checks for these.
        break;

      default:
        report_error(sprintf("%s:\nIllegal type (%s) in defvar.\n",
                             caudium->filename(this), type));
        break;
  }

  variables[var]=allocate( VAR_SIZE );
  if(!variables[var])
    error("Out of memory in defvar.\n");
  variables[var][ VAR_VALUE ]=value;
  variables[var][ VAR_TYPE ]=type&VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]=doc_str;
  variables[var][ VAR_NAME ]=name;

  type &= ~VAR_TYPE_MASK;		// Probably not needed, but...
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

  variables[var][ VAR_MISC ]=misc;
  variables[var][ VAR_SHORTNAME ]= var;
}

//!  Hide the variable from the configuration view.
//! 
//!  @param var
//!   the name of the variable to hide
//!  @param not_in_config
//!    a boolean, 1 to hide the variable, 0 to show or a 
//!    function that returns 0 to hide the variable or 1 to show
//!    the variable.
void set_hidden(string var, int|function not_in_config)
{
  if (functionp(not_in_config)) {
    variables[var][ VAR_CONFIGURABLE ] = not_in_config;
  } 
  else if(intp(not_in_config))
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
}

//! Convenience function, define an invisible variable, this variable
//! will be saved, but it won't be visible in the configuration interface.
//! It's a wrapper for @[defvar()] with not_in_config set to 1.
//!
//! @param name
//!  The variable name
//!
//! @param value
//!  The variable value.
//!
//! @param type
//!  The variable type. For the list of types, see @[defvar()].
//!
//! @param misc
//!  Miscelanneous data that depends on the variable type.
//!
//! @seealso
//!  @[defvar()]
void definvisvar(string name, mixed value, int type, mixed|void misc)
{
  defvar(name, value, "", type, "", misc, 1);
}

//! Check a variable if 'value' is OK to store into variable 's'.
//! If so, return 0 otherwise return a string describing the error.
//!
//! @param s
//!  The variable name to check (that is given in @[defvar()] function)
//!
//! @param value
//!  The value given but CIF user
//!
//! @returns
//!  0 if ok, otherwise a string with the error.
//!
//! @fixme
//!  Type of this function shouldn't be int|string ???
string check_variable( string s, mixed value )
{
  // Check if `value' is O.K. to store in the variable `s'.  If so,
  // return 0, otherwise return a string, describing the error.

  return 0;
}

//! Return the value of a variable.
//!
//! @param var
//!  Variable name (first param in @[defvar()])
//!
//! @param ok
//!  If it is ok for the variable to be absent, set this parameter to a
//!  value different than 0 - otherwise an exception will be thrown and
//!  your module will fail to load (which is a desirable behavior when
//!  developing the module)
//!
//! @returns
//!  The module variables stored.
mixed query(string|void var, int|void ok)
{
  if(var) {
    if(variables[var])
      return variables[var][VAR_VALUE];
    else if(!ok)
      error("Querying undefined variable.\n");
  }

  return variables;
}

//! 
void set_module_list(string var, string what, object to)
{
  int p;
  p = search(variables[var][VAR_VALUE], what);
  if(p == -1)
  {
#ifdef MODULE_DEBUG
    perror("The variable '"+var+"': '"+what+"' found by hook.\n");
    perror("Not found in variable!\n");
#endif
  } else 
    variables[var][VAR_VALUE][p]=to;
}

private string _module_identifier;

//!  returns the module identifier, used to uniquely identify this module
//!  in the server
string module_identifier()
{
  if (!_module_identifier) {
    string|mapping name = this->register_module()[1];
    if (mappingp (name)) name = name->standard;
    string cname = sprintf ("%O", my_configuration());
    if (sscanf (cname, "Configuration(%s", cname) == 1 &&
	sizeof (cname) && cname[-1] == ')')
      cname = cname[..sizeof (cname) - 2];
    _module_identifier = sprintf ("%s,%s", name || module_name, cname);
  }
  return _module_identifier;
}

//!
string _sprintf()
{
  return "CaudiumModule(" + module_identifier() + ")";
}


//! Used to register module
//!
//! @note 
//!  On new API this is deprecated.
array register_module()
{
  return ({
    module_type,
    module_name,
    module_doc,
    0,
    module_unique,
  });
}

//! Method used to set the value of a configuration variable within the module.
//!
//! @param var
//!  Name of the variable (first param in @[defvar()])
//!
//! @param value
//!  Value the variable should be given
void set(string var, mixed value)
{
  if(!variables[var])
    error( "Setting undefined variable.\n" );
  else
    if(variables[var][VAR_TYPE] == TYPE_MODULE && stringp(value))
      caudiump()->register_module_load_hook( value, set, var );
    else if(variables[var][VAR_TYPE] == TYPE_MODULE_LIST)
    {
      variables[var][VAR_VALUE]=value;
      if(arrayp(value))
	foreach(value, value)
	  if(stringp(value))
	    caudiump()->register_module_load_hook(value,set_module_list,var,value);
    }
    else
      variables[var][VAR_VALUE]=value;
}

//! Wrapper for bulk calling @[set()]
//!
//! @param vars
//!  Mapping containing the var:value pairs
//!
//! @returns
//!  Seems to allways return true
int setvars( mapping (string:mixed) vars )
{
  string v;
  int err;

  foreach( indices( vars ), v )
    if(variables[v])
      set( v, vars[v] );
  return !err;
}


//! Return the comment.
string comment()
{
  return "";
}

//! Return internal mountpoint of this module
//! Requests done to this mountpoint (eg http://domain.tld/_internal/mount/)
//! will be sent to the module's @[find_internal()] method
string query_internal_location()
{
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  return _my_configuration->query_internal_location(this_object());
}

//! Return the mountpoint in the virtual filesystem
//! It is rarely necessary to implement since this information can be
//! automatically obtained via a defvar named 'location' or whose type is
//! TYPE_LOCATION.
//! The mountpoint should allways be configurable by the administrator
string query_location()
{
  string s;
  mixed err = catch{
    s = query("location");
  };
  if (err) s = "";
  return s;
}

//! Set the service the module provides.
//! Then, another module can rely on this service by implementing the
//! @[module_dependencies()] method
//!
//! @note
//!  By default, provide nothing.
string query_provides() { return 0; } 

/*
 * Parse and return a parsed version of the security levels for this module
 *
 */

//!
class IP_with_mask {
  int net;
  int mask;
  static private int ip_to_int(string ip)
  {
    int res;
    foreach(((ip/".") + ({ "0", "0", "0" }))[..3], string num) {
      res = res*256 + (int)num;
    }
    return(res);
  }

  //!
  void create(string _ip, string|int _mask)
  {
    net = ip_to_int(_ip);
    if (intp(_mask)) {
      if (_mask > 32) {
        report_notice("Bad netmask: %s/%d\n"
                      "Using %s/32\n", _ip, _mask, _ip);
        _mask = 32;
      }
      mask = ~0<<(32-_mask);
    } else {
      mask = ip_to_int(_mask);
    }
    if (net & ~mask) {
      report_notice("Bad netmask: %s for network %s\n"
                    "Ignoring node-specific bits\n", _ip, _mask);
      net &= mask;
    }
  }

  //!
  int `()(string ip)
  {
    return((ip_to_int(ip) & mask) == net);
  }
};

//! returns the module security rules.
//! @note 
//!   document the security level format
array query_seclevels()
{
  array patterns=({ });

  if(catch(query("_seclevels"))) {
    return patterns;
  }
  
  foreach(replace(query("_seclevels"),
                  ({" ","\t","\\\n"}),
                  ({"","",""}))/"\n", string sl) {
    if(!strlen(sl) || sl[0]=='#')
      continue;

    string type, value;
    if(sscanf(sl, "%s=%s", type, value)==2)
    {
      array(string|int) arr;
      int i;
      switch(lower_case(type))
      {
          case "allowip":
            if (sizeof(arr = (value/"/")) == 2) {
              // IP/bits
              arr[1] = (int)arr[1];
              patterns += ({ ({ MOD_ALLOW, IP_with_mask(@arr) }) });
            } else if ((sizeof(arr = (value/":")) == 2) ||
                       (sizeof(arr = (value/",")) > 1)) {
              // IP:mask or IP,mask
              patterns += ({ ({ MOD_ALLOW, IP_with_mask(@arr) }) });
            } else {
              // Pattern
              value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
              patterns += ({ ({ MOD_ALLOW, Regexp(value)->match, }) });
            }
            break;

          case "acceptip":
            // Short-circuit version of allow ip.
            if (sizeof(arr = (value/"/")) == 2) {
              // IP/bits
              arr[1] = (int)arr[1];
              patterns += ({ ({ MOD_ACCEPT, IP_with_mask(@arr) }) });
            } else if ((sizeof(arr = (value/":")) == 2) ||
                       (sizeof(arr = (value/",")) > 1)) {
              // IP:mask or IP,mask
              patterns += ({ ({ MOD_ACCEPT, IP_with_mask(@arr) }) });
            } else {
              // Pattern
              value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
              patterns += ({ ({ MOD_ACCEPT, Regexp(value)->match, }) });
            }
            break;

          case "denyip":
            if (sizeof(arr = (value/"/")) == 2) {
              // IP/bits
              arr[1] = (int)arr[1];
              patterns += ({ ({ MOD_DENY, IP_with_mask(@arr) }) });
            } else if ((sizeof(arr = (value/":")) == 2) ||
                       (sizeof(arr = (value/",")) > 1)) {
              // IP:mask or IP,mask
              patterns += ({ ({ MOD_DENY, IP_with_mask(@arr) }) });
            } else {
              // Pattern
              value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
              patterns += ({ ({ MOD_DENY, Regexp(value)->match, }) });
            }
            break;

          case "allowuser":
            value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
            array(string) users = (value/"," - ({""}));
	
            for(i=0; i < sizeof(users); i++) {
              if (lower_case(users[i]) == "any") {
                if(this->register_module()[0] & MODULE_PROXY) 
                  patterns += ({ ({ MOD_PROXY_USER, lambda(){ return 1; } }) });
                else
                  patterns += ({ ({ MOD_USER, lambda(){ return 1; } }) });
                break;
              } else {
                users[i & 0x0f] = "(^"+users[i]+"$)";
              }
              if ((i & 0x0f) == 0x0f) {
                value = users[0..0x0f]*"|";
                if(this->register_module()[0] & MODULE_PROXY) {
                  patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
                } else {
                  patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
                }
              }
            }
            if (i & 0x0f) {
              value = users[0..(i-1)&0x0f]*"|";
              if(this->register_module()[0] & MODULE_PROXY) {
                patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
              } else {
                patterns += ({ ({ MOD_USER, Regexp(value)->match, }) });
              }
            }
            break;

          case "acceptuser":
            // Short-circuit version of allow user.
            // NOTE: MOD_PROXY_USER is already short-circuit.
            value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
            users = (value/"," - ({""}));
	
            for(i=0; i < sizeof(users); i++) {
              if (lower_case(users[i]) == "any") {
                if(this->register_module()[0] & MODULE_PROXY) 
                  patterns += ({ ({ MOD_PROXY_USER, lambda(){ return 1; } }) });
                else
                  patterns += ({ ({ MOD_ACCEPT_USER, lambda(){ return 1; } }) });
                break;
              } else {
                users[i & 0x0f] = "(^"+users[i]+"$)";
              }
              if ((i & 0x0f) == 0x0f) {
                value = users[0..0x0f]*"|";
                if(this->register_module()[0] & MODULE_PROXY) {
                  patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
                } else {
                  patterns += ({ ({ MOD_ACCEPT_USER, Regexp(value)->match, }) });
                }
              }
            }
            if (i & 0x0f) {
              value = users[0..(i-1)&0x0f]*"|";
              if(this->register_module()[0] & MODULE_PROXY) {
                patterns += ({ ({ MOD_PROXY_USER, Regexp(value)->match, }) });
              } else {
                patterns += ({ ({ MOD_ACCEPT_USER, Regexp(value)->match, }) });
              }
            }
            break;

          case "acceptgroup":
            value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
            array(string) groups = (value/"," - ({""}));
            string groupregex = 0;
            
            if (groups && sizeof(groups)) {
              foreach(groups, string group) {
                if (lower_case(group) == "any")
                  patterns += ({ ({ MOD_ACCEPT_GROUP, lambda() { return 1; } }) });
                else {
                  if (!groupregex)
                    groupregex = "(^" + group + "$)";
                  else
                    groupregex += "|(^" + group + "$)";
                }
              }
              
              if (groupregex)
                patterns += ({ ({ MOD_ACCEPT_GROUP, Regexp(groupregex)->match, }) });
            }
            break;
            
          case "secuname":
            value = replace(value, ({ "?", ".", "*" }), ({ ".", "\\.", ".*" }));
            users = (value/"," - ({""}));
            mapping(string:int) userlevels = ([]);	
            array(string) tmp;
            int           i;
	
            report_notice("SecUname found (" + sizeof(users) + " users)\n");
            for(i = 0; i < sizeof(users); i++) {
              tmp = users[i] / ":";
              if (lower_case(tmp[0]) == "any") {
                patterns += ({ ({ MOD_USER_SECLEVEL, (["any":tmp[1]]), }) });
                break;
              } else {
                userlevels += ([tmp[0]:tmp[1]]);
              }	    
            }
            patterns += ({ ({ MOD_USER_SECLEVEL, userlevels, }) });
            break;
	
          case "secgname":
            break;

          default:
            report_error(sprintf("Unknown Security:Patterns directive: "
                                 "type=\"%s\"\n", type));
            break;
      }
    } else {
      report_error(sprintf("Syntax error in Security:Patterns directive: "
                           "line=\"%s\"\n", sl));
    }
  }
  return patterns;
}

//!
mixed stat_file(string f, object id){}

//!
mixed find_dir(string f, object id){}

//!
mapping(string:array(mixed)) find_dir_stat(string f, object id)
{
  TRACE_ENTER("find_dir_stat(): \""+f+"\"", 0);

  array(string) files = find_dir(f, id);
  mapping(string:array(mixed)) res = ([]);

  foreach(files || ({}), string fname) {
    TRACE_ENTER("stat()'ing "+ f + "/" + fname, 0);
    array(mixed) st = stat_file(f + "/" + fname, id);
    if (st) {
      res[fname] = st;
      TRACE_LEAVE("OK");
    } else {
      TRACE_LEAVE("No stat info");
    }
  }

  TRACE_LEAVE("");
  return(res);
}

//!
mixed real_file(string f, object id){}

//!
mapping _api_functions = ([]);

//!
void add_api_function( string name, function f, void|array(string) types)
{
  _api_functions[name] = ({ f, types });
}

//!
mapping api_functions()
{
  return _api_functions;
}

//!
object get_font_from_var(string base)
{
  int weight, slant;
  switch(query(base+"_weight"))
  {
      case "light": weight=-1; break;
      default: weight=0; break;
      case "bold": weight=1; break;
      case "black": weight=2; break;
  }
  switch(query(base+"_slant"))
  {
      case "obligue": slant=-1; break;
      default: slant=0; break;
      case "italic": slant=1; break;
  }
  return get_font(query(base+"_font"), 32, weight, slant, "left", 0, 0);
}
