/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

// Some 25% of the original RIS code remains in this file. The code lives
// in the following functions:
//
//  parse_rxml
//  do_output_tag (GROSS!!)
//  get_module
//  get_modname
//  roxen_encode

//! Caudiumlib is a collection of utility functions used by modules and
//! the Caudium core. 

// constant _cvs_version = "$Id$";
// This code has to work both in the roxen object, and in modules

#if !constant(caudium)
#define caudium caudiump()
#endif

#include <config.h>

#define ipaddr(x,y) (((x)/" ")[y])

#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]

//!  Run the RXML parser on a text string. This function is to be used if you
//!  explicitely want to parse some text. It's commonly used in custom modules
//!  or pike scripts.
//! @param what
//!  The text to parse
//! @param id
//!  The request object.
//! @param file
//!  File object, which is sent as the second custom argument to all callback
//!  functions.
//! @param defines
//!  The mapping with defines, sent as another optional argument to callback
//!  functions. It defaults to id->misc->defines.
//! @returns
//!  The RXML parsed result.
static string parse_rxml(string what, object id,
                         void|object file, void|mapping defines)
{
  if (!id)
    error("No id passed to parse_rxml\n");

  if (!defines) {
    defines = id->misc->defines||([]);
    if (!_error)
      _error=200;
    if (!_extra_heads)
      _extra_heads=([ ]);
  }

  if (!id->conf || !id->conf->parse_module)
    return what;
  
  what = id->conf->parse_module->
    do_parse(what, id, file||this_object(), defines, id->my_fd);

  if (!id->misc->moreheads)
    id->misc->moreheads= ([]);
  id->misc->moreheads |= _extra_heads;
  
  id->misc->defines = defines;

  return what;
}

//! Figures out the filename of the file which defines the program
//! for this object. Deprecated, use Pike __FILE__ instead if possibile
//! @deprecated
string program_filename()
{
  return caudiump()->filename(this_object()) ||
    search(master()->programs, object_program(this_object()));
}

//! Returns the directory part of @[program_filename].
string program_directory()
{
  array(string) p = program_filename()/"/";
  return (sizeof(p)>1? p[..sizeof(p)-2]*"/" : getcwd());
}

//! This function exist to aid in finding a module object identified by the
//! passed module name.
//!
//! @param modname
//!  Name of the requested module.
//!
//! @returns
//!  The corresponding module object (if any)
object get_module (string modname)
{
  string cname, mname;
  int mid = 0;

  if (sscanf (modname, "%s/%s", cname, mname) != 2 ||
      !sizeof (cname) || !sizeof(mname)) return 0;
  sscanf (mname, "%s#%d", mname, mid);

  foreach (caudiump()->configurations, object conf) {
    mapping moddata;
    if (conf->name == cname && (moddata = conf->modules[mname])) {
      if (mid >= 0) {
        if (moddata->copies)
          return moddata->copies[mid];
      } else if (moddata->enabled)
        return moddata->enabled;
      
      if (moddata->master)
        return moddata->master;
      return 0;
    }
  }

  return 0;
}

//!   Given a copy of a Caudium module object create a uniquely identifying
//!   for that object. Along the lines of localhost/filesystem#copy
//! @param module
//!   An object containing an active caudium module (probably this_object()
//!   from inside a modules namespace).
//! @returns
//!   A unique name string.
string get_modname (object module)
{
  if (!module)
    return 0;

  foreach (caudiump()->configurations, object conf) {
    string mname = conf->otomod[module];
    if (mname) {
      mapping moddata = conf->modules[mname];
      if (moddata)
        if (moddata->copies)
          foreach (indices (moddata->copies), int i) {
            if (moddata->copies[i] == module)
              return conf->name + "/" + mname + "#" + i;
          } else if (moddata->master == module || moddata->enabled == module)
            return conf->name + "/" + mname + "#0";
    }
  }

  return 0;
}

//! Quote content in a multitude of ways. Used primarily by do_output_tag
//!
//! @param val
//!  Value to encode.
//!
//! @param encoding
//!  Desired string encoding on return:
//!
//!  @dl
//!    @item none
//!      Returns the value verbatim
//!    @item http
//!      HTTP encoding.
//!    @item cookie
//!      HTTP cookie encoding
//!    @item url
//!      HTTP encoding, including special characters in URLs
//!    @item html
//!      For generic html text and in tag arguments. Does
//!      not work in RXML tags (use dtag or stag instead)
//!    @item dtag
//!      Quote quotes for a double quoted tag argument. Only
//!      for internal use, i.e. in arguments to other RXML tags
//!    @item stag
//!      Quote quotes for a single quoted tag argument. Only
//!      for internal use, i.e. in arguments to other RXML tags
//!    @item pike
//!      Pike string quoting (e.g. for use in the &lt;pike&gt; tag)
//!    @item js|javascript
//!      Javascript string quoting
//!    @item mysql
//!      MySQL quoting
//!    @item mysql-dtag
//!      MySQL quoting followed by dtag quoting
//!    @item mysql-pike
//!      MySQL quoting followed by Pike string quoting
//!    @item sql|oracle
//!      SQL/Oracle quoting
//!    @item sql-dtag/oracle-dtag
//!      SQL/Oracle quoting followed by dtag quoting
//!  @enddl
//!
//! @returns
//!  The encoded string
string roxen_encode( string val, string encoding )
{
  switch (encoding) {
      case "none":
      case "":
        return val;
   
      case "http":
        // HTTP encoding.
        return Caudium.http_encode_string (val);
     
      case "cookie":
        // HTTP cookie encoding.
        return Caudium.http_encode_cookie (val);
     
      case "url":
        // HTTP encoding, including special characters in URL:s.
        return Caudium.http_encode_url (val);
       
      case "html":
        // For generic html text and in tag arguments. Does
        // not work in RXML tags (use dtag or stag instead).
        return _Roxen.html_encode_string (val);
     
      case "dtag":
        // Quote quotes for a double quoted tag argument. Only
        // for internal use, i.e. in arguments to other RXML tags.
        return replace (val, "\"", "\"'\"'\"");
     
      case "stag":
        // Quote quotes for a single quoted tag argument. Only
        // for internal use, i.e. in arguments to other RXML tags.
        return replace(val, "'", "'\"'\"'");
       
      case "pike":
        // Pike string quoting (e.g. for use in a <pike> tag).
        return replace (val,
                        ({ "\"", "\\", "\n" }),
                        ({ "\\\"", "\\\\", "\\n" }));

      case "js":
      case "javascript":
        // Javascript string quoting.
        return replace (val,
                        ({ "\b", "\014", "\n", "\r", "\t", "\\", "'", "\"" }),
                        ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
                           "\\'", "\\\"" }));
       
      case "mysql":
        // MySQL quoting.
        return replace (val,
                        ({ "\"", "'", "\\" }),
                        ({ "\\\"" , "\\'", "\\\\" }) );
       
      case "sql":
      case "oracle":
        // SQL/Oracle quoting.
        return replace (val, "'", "''");
       
      case "mysql-dtag":
        // MySQL quoting followed by dtag quoting.
        return replace (val,
                        ({ "\"", "'", "\\" }),
                        ({ "\\\"'\"'\"", "\\'", "\\\\" }));
       
      case "mysql-pike":
        // MySQL quoting followed by Pike string quoting.
        return replace (val,
                        ({ "\"", "'", "\\", "\n" }),
                        ({ "\\\\\\\"", "\\\\'",
                           "\\\\\\\\", "\\n" }) );
       
      case "sql-dtag":
      case "oracle-dtag":
        // SQL/Oracle quoting followed by dtag quoting.
        return replace (val,
                        ({ "'", "\"" }),
                        ({ "''", "\"'\"'\"" }) );
       
      default:
        // Unknown encoding. Let the caller decide what to do with it.
        return 0;
  }
}

// This method needs lot of work... but so does the rest of the system too
// RXML needs types
private int compare( string a, string b ) // what a mess!
{
  if (!a)
    if (b)
      return -1;
    else
      return 0;
  else if (!b)
    return 1;
  else if ((string)(int)a == a && (string)(int)b == b)
    if ((int )a > (int )b)
      return 1;
    else if ((int )a < (int )b)
      return -1;
    else
      return 0;
  else
    if (a > b)
      return 1;
    else if (a < b)
      return -1;
    else
      return 0;
}

//! method for use by tags that replace variables in their content, like
//! formoutput, sqloutput and others
//!
//! @param args
//!  Arguments that influence the way the output tag does its job.
//!
//!    @mapping
//!      @member string "quote"
//!       The placeholder value quoting character. Defaults to @tt{#@}
//!      @member mixed "preprocess"
//!       If present, the passed contents string is parsed using
//!       @[parse_rxml()] before replacing the placeholders.
//!      @member string "debug-input"
//!       If present and set to one of the supported values, this attribute
//!       allows the programmer to see some debugging output. Supported
//!       values:
//!
//!         @dl
//!           @item log
//!            Debugging information is sent to the default caudium log.
//!           @item comment
//!            Debugging information is sent to the browser in form of a
//!            HTML comment.
//!           @item any_other_value
//!            The debugging info is presented as a bold, preformated text
//!            between the square brackets.
//!         @enddl
//!
//!      @member string "sort"
//!       The array of variables is sorted relatively to the passed,
//!       comma-separated, list of values.
//!
//!      @member string "range"
//!       Only the variables from the passed array enclosed in the given
//!       range (using the @code{X..Y@} syntax) are used for the
//!       output.
//!
//!      @member string "replace"
//!       If absent, or its value is different than "no", the tag will
//!       perform the actual replacement. Each variable can have a number
//!       of options attached to it. The options are attached by using the
//!       syntax presented below:
//!
//!        @code{
//!          #variable:option=value:option=value#
//!        @}
//!
//!        The @tt{#@} character above is, in reality, the value of
//!        @tt{args->quote@} and is the default quoting
//!        character. Available options are presented below:
//!
//!          @dl
//!           @item empty
//!             The value given to variables that have no value
//!             assigned. See also @[args->empty].
//!           @item zero
//!             The value assigned to the variables that are
//!             uninitialized. See also @[args->zero].
//!           @item multisep|multi_separator
//!             Separator for variables whose content is a list. The
//!             variable value will be divided on this string.
//!           @item quote
//!             The quote character to be used for the given variable
//!             only. See also @[args->quote].
//!           @item encode
//!             The encoding for the given variable only.
//!          @enddl
//!
//!       @member string "zero"
//!         The default value returned for all variables which aren't
//!         initialized.
//!
//!       @member string "empty"
//!         The default value returned for all variables which have no
//!         value assigned.
//!
//!       @member string "delimiter"
//!         A string put after each replaced variable.
//!    @endmapping
//!
//! @param var_arr
//!   An array of mappings describing all the variables that can be
//!   replaced. Each mapping index is the name of a quoted variable in the
//!   passed contents. For example, if the passed mapping contains an index
//!   called 'test' then its corresponding variable in the contents string
//!   (assuming the default @tt{#@} quote character is used) will be
//!   @tt{#test@}.
//!
//! @param contents
//!   The contents of the that called this function container.
//!
//! @param id
//!   The request id.
//!
//! @example
//! //
//! // a simple tag that outputs a list of parts of 'something'
//! // it defines an array of mappings containing two indexes:
//! //  'url' and 'name'. The sample usage of the container is:
//! //
//! // <show_parts><a href='#url#'>#name#</a></show_parts>
//! //
//! array(string) show_parts(string tag, mapping args, string
//!                          contents, object id, mapping defines) {
//!   array(mapping)   rep = ({});
//!   int              i = 0;
//!
//!   foreach(configs, mapping cfg) {
//!       mapping nmap = ([]);
//!
//!       nmap->url = sprintf("%s(showpart)/?name=%d",
//!                         id->conf->query("MyWorldLocation"),
//!                         i);
//!       nmap->name = sprintf("Part %d", i++);
//!       rep += ({nmap});
//!   }
//!
//!   return ({ do_output_tag(args, rep, contents, id) });
//! }
//!
//! @returns
//!  Contents with all the variables found in @[var_arr] replaced with
//!  their values.
string do_output_tag( mapping args, array (mapping) var_arr, string contents,
                      object id )
{
  string quote = args->quote || "#";
  mapping other_vars = id->misc->variables;
  string new_contents = "", unparsed_contents = "";
  int first;

  // multi_separator must default to \000 since one sometimes need to
  // pass multivalues through several output tags, and it's a bit
  // tricky to set it to \000 in a tag..
  string multi_separator = args->multi_separator || args->multisep || "\000";

  if (args->preprocess)
    contents = parse_rxml( contents, id );

  switch (args["debug-input"]) {
      case 0:
        break;
        
      case "log":
        report_debug ("tag input: %s\n", contents);
        break;
        
      case "comment":
        new_contents = "<!--\n" + _Roxen.html_encode_string (contents) + "\n-->";
        break;
        
      default:
        new_contents = "\n<br><b>[</b><pre>" +
          _Roxen.html_encode_string (contents) + "</pre><b>]</b>\n";
  }

  if (args->sort) {
    array order;

    order = args->sort / "," - ({ "" });
    var_arr = Array.sort_array( var_arr,
                                lambda (mapping m1, mapping m2, array order)
                                {
                                  int tmp;

                                  foreach (order, string field)
                                  {
                                    int tmp;
            
                                    if (field[0] == '-')
                                      tmp = compare( m2[field[1..]],
                                                     m1[field[1..]] );
                                    else if (field[0] == '+')
                                      tmp = compare( m1[field[1..]],
                                                     m2[field[1..]] );
                                    else
                                      tmp = compare( m1[field], m2[field] );
                                    if (tmp == 1)
                                      return 1;
                                    else if (tmp == -1)
                                      return 0;
                                  }
                                  return 0;
                                }, order );
  }

  if (args->range) {
    int begin, end;
    string b, e;
    

    sscanf( args->range, "%s..%s", b, e );
    if (!b || b == "")
      begin = 0;
    else
      begin = (int )b;

    if (!e || e == "")
      end = -1;
    else
      end = (int )e;

    if (begin < 0)
      begin += sizeof( var_arr );

    if (end < 0)
      end += sizeof( var_arr );

    if (begin > end)
      return "";

    if (begin < 0)
      if (end < 0)
        return "";
      else
        begin = 0;
    var_arr = var_arr[begin..end];
  }

  first = 1;
  foreach (var_arr, mapping vars) {
    if (args->set)
      foreach (indices (vars), string var) {
        mixed val = vars[var];
        if (!val)
          val = args->zero || "";
        else {
          if (arrayp( val ))
            val = Array.map (val, lambda (mixed v) {return (string) v;}) *
              multi_separator;
          else
            val = replace ((string) val, "\000", multi_separator);
          if (!sizeof (val)) val = args->empty || "";
        }
        
        id->variables[var] = val;
      }

    id->misc->variables = vars;

    if (!args->replace || lower_case( args->replace ) != "no") {
      array exploded = contents / quote;
      if (!(sizeof (exploded) & 1))
        return "<b>Contents ends inside a replace field</b>";

      for (int c=1; c < sizeof( exploded ); c+=2)
        if (exploded[c] == "")
          exploded[c] = quote;
        else {
          array(string) options =  exploded[c] / ":";
          string var = String.trim_all_whites(options[0]);
          mixed val = vars[var];
          array(string) encodings = ({});
          string multisep = multi_separator;
          string zero = args->zero || "";
          string empty = args->empty || "";

          foreach (options[1..], string option) {
            array (string) pair = option / "=";
            string optval = String.trim_all_whites (pair[1..] * "=");

            switch (lower_case (String.trim_all_whites( pair[0] ))) {
                case "empty":
                  empty = optval;
                  break;
                  
                case "zero":
                  zero = optval;
                  break;
                  
                case "multisep":
                case "multi_separator":
                  multisep = optval;
                  break;
                  
                case "quote": // For backward compatibility.
                  optval = lower_case (optval);
                  switch (optval) {
                      case "mysql": case "sql": case "oracle":
                        encodings += ({optval + "-dtag"});
                        break;
                        
                      default:
                        encodings += ({optval});
                  }
                  break;
                  
                case "encode":
                  encodings += Array.map (lower_case (optval) / ",",
                                          String.trim_all_whites);
                  break;
                  
                default:
                  return "<b>Unknown option "
                    + String.trim_all_whites (pair[0])
                    + " in replace field " + ((c >> 1) + 1) + "</b>";
            }
          }

          if (!val)
            if (zero_type (vars[var]) && (args->debug || id->misc->debug))
              val = "<b>No variable " + options[0] + "</b>";
            else
              val = zero;
          else {
            if (arrayp( val ))
              val = Array.map (val, lambda (mixed v) {return (string) v;}) *
                multisep;
            else
              val = replace ((string) val, "\000", multisep);
            if (!sizeof (val))
              val = empty;
          }

          if (!sizeof (encodings))
            encodings = args->encode ?
              Array.map (lower_case (args->encode) / ",",
                         String.trim_all_whites) : ({"html"});

          string tmp_val;
          foreach (encodings, string encoding)
            if (!(val = roxen_encode( val, encoding )))
              return ("<b>Unknown encoding " + encoding
                      + " in replace field " + ((c >> 1) + 1) + "</b>");

          exploded[c] = val;
        }

      if (first)
        first = 0;
      else if (args->delimiter)
        new_contents += args->delimiter;
      new_contents += args->preprocess ? exploded * "" :
        parse_rxml (exploded * "", id);
      if (args["debug-output"])
        unparsed_contents += exploded * "";
    } else {
      new_contents += args->preprocess ? contents : parse_rxml (contents, id);
      if (args["debug-output"])
        unparsed_contents += contents;
    }
  }

  switch (args["debug-output"]) {
      case 0:
        break;
        
      case "log":
        report_debug ("tag output: %s\n", unparsed_contents);
        break;
        
      case "comment":
        new_contents += "<!--\n" + _Roxen.html_encode_string (unparsed_contents) + "\n-->";
        break;
        
      default:
        new_contents = "\n<br><b>[</b><pre>" + _Roxen.html_encode_string (unparsed_contents) +
          "</pre><b>]</b>\n";
  }

  id->misc->variables = other_vars;
  return new_contents;
}

//! method: string fix_relative(string file, object id)
//!  Transforms relative paths to absolute ones in the virtual filesystem
//! arg: string file
//!  The relative path to transform
//! arg: object id
//!  The caudium id object
//! returns:
//!  A string containing the absolute path in he virtual filesystem
string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') 
    ;
  else if(file != "" && file[0] == '#') 
    file = id->not_query + file;
  else
    file = dirname(id->not_query) + "/" +  file;
  
  return Caudium.simplify_path(file);
}


//!  Return the scope and variable name based on the input data.
//! @param variable
//!  The variable to parse. Should be either "variable" or "scope.variable".
//!  If a specific scope is sent to the function, the variable is uses as-is
//!  for the variable name.
//! @param scope
//!  The optional scope. If present, this overrides any scope specification
//!  in the variable name. If left out, the scope is parsed from the variable
//!  name. 
//! @returns
//!  An array consisting of the scope and the variable.
//!
//! @note
//!  Non-RIS code
array(string) parse_scope_var(string variable, string|void scope)
{
  array scvar = allocate(2);
  if (scope) {
    scvar[0] = scope;
    scvar[1] = variable;
  } else {
    if (sscanf(variable, "%s.%s", scvar[0], scvar[1]) != 2) {
      scvar[0] = "form";
      scvar[1] = variable;
    }
  }
  
  return scvar;
}

//!  Return the value of the specified variable in the specified scope.
//! @param variable
//!  The variable to fetch from the scope.
//! @param scope
//!  The scope of the variable. If zero, the scope will be extracted from
//!  the variable using [parse_scope_var].
//! @param id
//!  The request id object.
//! @returns
//!  The value of the variable or zero if the variable or scope doesn't
//!  exist.
//! @seealso
//!   @[set_scope_var()], @[parse_scope_var()]
//!
//! @note
//!  Non-RIS code
mixed get_scope_var(string variable, void|string scope, object id)
{
  function _get;

  if (!id->misc->_scope_status) {
    if (id->variables && id->variables[variable])
      return id->variables[variable];
    return 0;
  }
  
  if(!scope)
    [scope,variable] = parse_scope_var(variable);
  
  if(!id->misc->scopes[scope])
    return 0;
  
  if(!(_get = id->misc->scopes[scope]->get))
    return 0;
  
  return _get(variable, id);
}

//!  Set the specified variable in the specified scope to the value.
//! @param variable
//!  The variable to fetch from the scope.
//! @param scope
//!  The scope of the variable. If zero, the scope will be extracted from
//!  the variable using [parse_scope_var].
//! @param value
//!  The value to set the variable to.
//! @param id
//!  The request id object.
//! @returns
//!  1 if the variable was set correctly, 0 if it failed.
//! 
//! @seealso
//!  @[get_scope_var()], @[parse_scope_var()]
//!
//! @note
//!  non-RIS code
int set_scope_var(string variable, void|string scope, mixed value, object id)
{
  function _set;

  if (!id->misc->_scope_status) {
    id->variables[variable] = value;
    return 1;
  }
  
  if(!scope)
    [scope,variable] = parse_scope_var(variable);
  
  if(!id->misc->scopes[scope])
    return 0;
  
  if(!(_set = id->misc->scopes[scope]->set))
    return 0;
  
  return _set(variable, value, id);
}

//!  Parse the data for entities.
//! @param data
//!  The text to parse.
//! @param cb
//!  The function called when an entity is encountered. Arguments are:
//!  the parser object, the entity scope, the entity name, the request id
//!  and any extra arguments specified.
//! @param id
//!  The request id object.
//! @param extra
//!  Optional arguments to pass to the callback function.
//! @returns
//!  The parsed result.
//!
//! @note
//!  non-RIS code
static mixed cb_wrapper(object parser, string entity, object id, function cb,
                        mixed ... args) {
  string scope, name, encoding;
  array tmp = (parser->tag_name()) / ":";
  entity = tmp[0];
  encoding = tmp[1..] * ":";

  if (!encoding || !strlen(encoding))
    encoding = (id && id->misc->_default_encoding) || "html";
  if (sscanf(entity, "%s.%s", scope, name) != 2)
    return 0;
  
  mixed ret = cb(parser, scope, name, id, @args);
  
  if(!ret)
    return 0;
  if(stringp(ret))
    return roxen_encode(ret, encoding);
  if(arrayp(ret))
    return Array.map(ret, roxen_encode, encoding);    
}

//! Parse the passed string looking for entities referring to the scopes
//! defined in Caudium.
//!
//! @param data
//!  The string to parse
//!
//! @param cb
//!  The callback for extra data found in the string.
//!
//! @param id
//!  The request ID in which context the function is called.
//!
//! @param extra
//!  Extra parameters sent to the @tt{cb@} callback
//!
//! @returns
//!  The input string with all the defined entities replaced.
//!
//! @note
//!  non-RIS code
string parse_scopes(string data, function cb, object id, mixed ... extra) {
  object mp = Parser.HTML();
  mp->lazy_entity_end(1);
  mp->ignore_tags(1);
  mp->set_extra(id, cb, @extra);

  mp->_set_entity_callback(cb_wrapper);
  return mp->finish(data)->read();
}

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
