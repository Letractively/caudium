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

//! module: Core RXML Tags
//!  The core RXML tags which were previously a part of the Main RXML Parser.
//!  To allow for alternative "main parsers", all tags were separated
//!  from the main parser. This module is added automatically
//!  when the chosen RXML parser is loaded.
//! type: MODULE_PARSER | MODULE_PROVIDER
//! provides: rxml:tags
//! cvs_version: $Id$";

#include <config.h>
#include <module.h>

inherit "module";
inherit "caudiumlib";

constant language = caudium->language;

constant module_type   = MODULE_PARSER | MODULE_PROVIDER;
constant module_name   = "Core RXML Tags";
constant module_doc    = "This module contains all the core RXML tags "
                         "that were previously in the Main RXML Parser.";
constant module_unique = 1;
constant thread_safe   = 1;
constant cvs_version   = "$Id$";

#define CALL_USER_TAG id->conf->parse_module->call_user_tag
#define CALL_USER_CONTAINER id->conf->parse_module->call_user_container

void create()
{
  defvar("compat_if", 0, "Compatibility with old &lt;if&gt;",
	 TYPE_FLAG|VAR_MORE,
	 "If set the &lt;if&gt;-tag will work in compatibility mode.\n"
	 "This affects the behaviour when used together with the &lt;else&gt;-"
	 "tag.\n");
	 
  defvar("max_insert_depth", 100, "Max file inclusion recursion depth",
         TYPE_INT,
	 "Max level of recursion when using &lt;insert file=\"...\"&gt;");
}

void start() {
  define_API_functions();
}

string query_provides() 
{ 
  return "rxml:tags";
}

#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)


/* standard roxen tags */

string tagtime(int t,mapping m)
{
  string s;
  mixed eris;
  string res;
  if (m->strftime || m->strfmt)
#if constant(Caudium.strftime)
    return Caudium.strftime( m->strftime || m->strfmt, t );
#else
    return "Your system lacks of strftime() function";
#endif /* constant(Caudium.strftime) */
  if (m->part)
  {
    string sp;
    if(m->type == "ordered")
    {
      m->type="string";
      sp = "ordered";
    }

    switch (m->part)
    {
     case "year":
      return Caudium.number2string((int)(localtime(t)->year+1900),m,
			   language(m->lang, sp||"number"));
     case "month":
      return Caudium.number2string((int)(localtime(t)->mon+1),m,
			   language(m->lang, sp||"month"));
     case "day":
     case "wday":
      return Caudium.number2string((int)(localtime(t)->wday+1),m,
			   language(m->lang, sp||"day"));
     case "date":
     case "mday":
      return Caudium.number2string((int)(localtime(t)->mday),m,
			   language(m->lang, sp||"number"));
     case "hour":
      return Caudium.number2string((int)(localtime(t)->hour),m,
			   language(m->lang, sp||"number"));
     case "min":
     case "minute":
      return Caudium.number2string((int)(localtime(t)->min),m,
			   language(m->lang, sp||"number"));
     case "sec":
     case "second":
      return Caudium.number2string((int)(localtime(t)->sec),m,
			   language(m->lang, sp||"number"));
     case "yday":
      return Caudium.number2string((int)(localtime(t)->yday),m,
			   language(m->lang, sp||"number"));
     default: return "";
    }
  } else if(m->type) {
    switch(m->type)
    {
     case "iso":
      eris=localtime(t);
      return sprintf("%d-%02d-%02d", (eris->year+1900),
		     eris->mon+1, eris->mday);

     case "discordian":
     case "disc":
#if constant(discdate)
      eris=discdate(t);
      res=eris[0];
      if(m->year)
	res += " in the YOLD of "+eris[1];
      if(m->holiday && eris[2])
	res += ". Celebrate "+eris[2];
      return res;
#else
      return "Discordian date support disabled";
#endif
     case "stardate":
     case "star":
#if constant(stardate)
      return (string)stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
     default:
    }
  }
  else if (m->dayssince)
  {
    int diffyear, diffmonth = 0, diffday;

    if (sscanf(m->dayssince, "%d-%d-%d", diffyear, diffmonth, diffday) != 3 &&
        sscanf(m->dayssince, "%d-%s-%d", diffyear, diffmonth, diffday) == 3)
    { diffmonth = ([ "jan":  1, "feb":  2, "mar":  3, "apr":  4,
                     "may":  5, "jun":  6, "jul":  7, "aug":  8,
                     "sep":  9, "oct": 10, "nov": 11, "dec": 12 ])
            [lower_case(sprintf("%s", diffmonth))[0..2]];
    }
    if (diffmonth >= 1 && diffmonth <= 12)
    { return sprintf("%d",
         Calendar.ISO.Year(localtime(t)->year+1900)->
                          month(localtime(t)->mon+1)->
                          day(localtime(t)->mday) -
         Calendar.ISO.Year(diffyear)->month(diffmonth)->day(diffday));
    }
    return "<b>(bad date format)</b>";
  }
  s=language(m->lang, "date")(t,m);
  if (m->upper) s=upper_case(s);
  if (m->lower) s=lower_case(s);
  if (m->cap||m->capitalize) s=capitalize(s);
  return s;
}

//! tag: date
//!  This tag prints the date and time.
//! attribute: brief
//!  Generates as brief a date as possible.
//! attribute: capitalize
//!  Capitalizes the first letter of the result.
//! attribute: date
//!  Shows the date only.
//! attribute: day
//!  Adds this number of days to the current date.
//! attribute: hour
//!  Adds this number of hours to the current date.
//! attribute: lang
//!  Used together with <tt>type=string</tt> and the <tt>part</tt>
//!  attribute to get written dates in the specified language. Available
//!  languages are ca, es_CA (Catala), hr (Croatian), cs (Czech), nl
//!  (Dutch), en (English), fi (Finnish), fr (French), de (German), hu
//!  (Hungarian), it (Italian), jp (Japanese), mi (Maori), no (Norwegian),
//!  pt (Portuguese), ru (Russian), sr (Serbian), si (Slovenian), es
//!  (Spanish) and sv (Swedish).
//! attribute: lower
//!  Prints the results in lower case.
//! attribute: minute
//!  Adds this number of minutes to the current date.
//! attribute: part
//!  Print the chosen part of the date:
//! <dl>
//! <dt>year</dt> <dd>The year.</dd>
//! <dt>month</dt> <dd>The month.</dd>
//! <dt>day</dt> <dd>The weekday, starting with Sunday.</dd>
//! <dt>date</dt> <dd>The number of days since the first this month.</dd>
//! <dt>hour</dt> <dd>The number of hours since midnight.</dd>
//! <dt>minute</dt> <dd>The number of minutes since the last full hour.</dd>
//! <dt>second</dt> <dd>The number of seconds since the last full minute.</dd>
//! <dt>yday</dt> <dd>The day since the first of January.</dd>
//! <p>The return value of these parts are modified by both
//! <tt>type</tt> and <tt>lang</tt>.</p></dl>
//! attribute: second
//!  Adds this number of seconds to the current date.
//! attribute: time
//!  Prints the time only.
//! attribute: type=number|string|roman|iso|discordian|stardate
//!  Specifies what type of date you want. Discordian and stardate only
//!  make a difference when <i>not</i> using <tt>part</tt>. Note that
//!  <tt>type=stardate</tt> has a separate companion attribute,
//!  <tt>prec</tt>, which sets the precision.
//! attribute: unix_time
//!  specified Unix time_t time as the starting time, instead of the
//!  current time. This is mostly useful when the <tt>&lt;date&gt;</tt> tag is
//!  used from a Pike-script or Roxen module.
//! attribute: upper
//!  Prints the result in upper case.
//! attribute: strftime
//!  Format the date according to the strftime format string.
//! attribute: strfmt
//!  Same as strftime. Here for Roxen 2.x compatibility reasons.
//! example: rxml
//!  {date part="day" type="string" lang="de"}

string tag_date(string q, mapping m, object id)
{
  int t=(int)m->unix_time || time(1);
  if(m->day)    t += (int)m->day * 86400;
  if(m->hour)   t += (int)m->hour * 3600;
  if(m->minute) t += (int)m->minute * 60;
  if(m->min)    t += (int)m->min * 60;
  if(m->sec)    t += (int)m->sec;
  if(m->second) t += (int)m->second;

  if(!(m->brief || m->time || m->date))
    m->full=1;

  if(!m->date)
  {
    if(!m->unix_time)
      NOCACHE();
  } else
    CACHE(60); // One minute is good enough.

  return tagtime(t,m);
}

inline string do_safe_replace(string s, mapping (string:string) m,
			      array(string) encodings)
{
  string quoted;
  s=replace(s, indices(m), values(m));
  foreach (encodings, string encoding)
    if( quoted = roxen_encode( s, encoding ) )
      return quoted;
    else
      return ("<b>Unknown encoding "+ encoding +" in &lt;insert&gt; </b>");
}

//! container: scope
//!  Creates a new scope for RXML variables. Variables can be changed within
//!  the <tt>&lt;scope&gt;</tt> tag without having any effect outside it.
//! attribute: extend
//!  Copy all variables from the outer scope.
//! bugs:
//!  This only applies to variables in the &amp;form; scope.
//! example: rxml
//!  {set variable="foo" value="World"}
//!  {scope}
//!   {h1}Hello {insert variable="foo"}{/h1}
//!   {set variable="foo" value="Duck"}
//!  {/scope}
//! 
//!  {scope extend}
//!  {h1}Hello {insert variable=foo}{/h1}
//!  {/scope}

array(string) tag_scope(string tag, mapping m, string contents, object id)
{
  mapping old_variables = id->variables;
  id->variables = ([]);
  if (m->extend) {
    id->variables += old_variables;
  }
  id->misc->parse_level --;  
  contents = parse_rxml(contents, id);
  id->misc->parse_level ++;
  id->variables = old_variables;
  return ({ contents });
}

//! tag: set
//!  This tag sets a variable to a new value.
//!  If none of the source attributes are specified, the variable is unset.
//!  If debug is currently on, more specific debug information is provided
//!  if the operation failed. If debug is off, error messages are sent to
//!  the debug log only.
//! attribute: variable
//!  The variable to set. It can be either a simple variable, i.e "variable", or a
//!  variable on in scope form, ie "var.name". If the scope is left out, the &amp;form;
//!  scope is used.
//!  If no value attribute is supplied, the variable will be unset (deleted).
//!  When unsetting variables, you may provide the exact name of the variable or
//!  you can have wildcards by using one or more asterisks in the variable.
//!  If an asterisk * is used in the value, all variables that match that wildcard
//!  will be unset.
//! attribute: scope
//!  Use this as the &amp;scope;. When used, the value of the variable attribute will be
//!  used as a simple name within this scope.
//! attribute: debug
//!  Provide debug messages in case the operation fails. <tt>&lt;set&gt;</tt>
//!  will normally fail silently.
//! attribute: define
//!  Set the variable to the contents of this define.
//! attribute: expr
//!  Set the variable to the result of a simple mathematical expression.
//!  Operators that can be used are +, -, *, /, % and |. Only numerical
//!  values can be used in the expression.
//! attribute: eval
//!  Set the variable to the result of this RXML expression.
//! attribute: from
//!  Set the variable to the value of the named variable (in simple of scope form).
//! attribute: other
//!  Set the variable to the value of this <i>other</i> variable. This is
//!  mostly useful from within <i>output</i> tags like <tt>&lt;sqloutput&gt;</tt>
//!  where all columns from the SQL result will be available as
//!  <i>other</i> variables.
//! attribute: value
//!  Set the variable to this value.
//! example: rxml
//!  {set variable="foo" value="Hello World"}
//!  {insert variable="foo"}
//! example: rxml
//!  {set variable="var.date" eval="{date}"}
//!  {insert variable="var.date"}

string tag_set( string tag, mapping m, object id )
{
    if(m->help) 
        return ("<b>&lt;unset variable=...&gt;</b>: Unset the variable specified "
                "by the 'variable' argument.  If an asterisk '*' is used in the "
                "variable, all variables that match that wildcard will be unset. ");

    if (m->variable)
    {
        int ret;
        if (m->value) {
            // Set variable to value.
            ret = set_scope_var(m->variable, m->scope, m->value, id);
        } else if (m->expr) {
            ret = set_scope_var(m->variable, m->scope, Caudium.sexpr_eval( m->expr ), id);
        } else if (m->from) {
            mixed val;
            // Set variable to the value of another variable
            val = get_scope_var(m->from, 0, id);
            if(!val ) {
                if ((m->debug || id->misc->debug))
                    return "<b>&lt;"+tag+"&gt;: Variable "+m->from+" doesn't exist.</b>";
                else {
                    report_error("<%s>: Variable '%s' doesn't exist.\n", tag, m->from);
                    return "";
                }
            }
            ret = set_scope_var(m->variable, m->scope, val, id);
        } else if (m->other) {
            // Set variable to the value of a misc variable
            if (id->misc->variables && id->misc->variables[ m->other ])
                ret = set_scope_var(m->variable, m->scope, id->misc->variables[ m->other ], id);
            else {
                if (m->debug || id->misc->debug)
                    return "<b>&lt;"+tag+"&gt;: other variable doesn't exist.</b>";
                else {
                    report_error("<%s>: other variable doesn't exist.\n", tag);
                    return "";
                }
            }
        } else if(m->define) {
            // Set variable to the value of a define
            ret = set_scope_var(m->variable, 0, id->misc->defines[ m->define ], id);
        } else if (m->eval) {
            // Set variable to the result of some evaluated RXML
            ret = set_scope_var(m->variable, m->scope, parse_rxml(m->eval, id), id);
        } else {
            // Unset variable.
          if (search(m->variable,"*") >= 0) {
            if (m->scope == "var") {
              string group, variable;
              if (sscanf(m->variable, "%s.%s", group, variable) == 2) {
                if (search(group,"*") >= 0) {
                  foreach(indices(id->misc->scopes->var->sub_vars), string g) {
                    if (glob(group,g)) {
                      foreach(indices(id->misc->scopes->var->sub_vars[g]), string v) {
                        if (search(variable,"*") >= 0) {
                          if (glob(variable,v)) {
                            ret = set_scope_var(g + "." + v, "var", 0, id);
                          }
                        } else {
                          if (v == variable) {
                            ret = set_scope_var(g + "." + v, "var", 0, id);
                          }
                        }
                      }
                    }
                  }
                } else {
                  foreach(indices(id->misc->scopes->var->sub_vars), string g) {
                    if (g == group) {
                      foreach(indices(id->misc->scopes->var->sub_vars[g]), string v) {
                        if (glob(variable,v)) {
                          ret = set_scope_var(group + "." + v, "var", 0, id);
                        }
                      }
                    }
                  }
                }
              } else {
                foreach(indices(id->misc->scopes->var->sub_vars), string group) {
                  if (glob(m->variable,group)) {
                    foreach(indices(id->misc->scopes->var->sub_vars[group]), string v) {
                      ret = set_scope_var(group + "." + v, "var", 0, id);
                    }
                  }
                }
                foreach(indices(id->misc->scopes[m->scope]->top_vars), string v) {
                  if (glob(m->variable,v)) {
                    ret = set_scope_var(v, "var", 0, id);
                  }
                }
              }
            } else {
              foreach (indices(id->variables),string v) {
                if (glob(m->variable,v)) {
                  ret = set_scope_var(v, m->scope, 0, id);
                }
              }
            }
          } else {
            ret = set_scope_var(m->variable, m->scope, 0, id);
          }
        }
        if(!ret) {
            if (m->debug || id->misc->debug)
                return "<b>Set/unset failed or scope is read-only.</b>";
            else
                report_error("Set/unset failed or scope is read-only.");
        }
        return("");
    } else if (id->misc->defines) {
        if (m->debug || id->misc->debug)
            return("<!-- set (line "+id->misc->line+"): variable not specified -->");
        else {
            report_error("set (line %O): variable not specified\n", id->misc->line);
            return "";
        }
    } else {
        if (m->debug || id->misc->debug)
            return("<!-- set: variable not specified -->");
        else {
            report_error("set: variable not specified\n");
            return "";
        }
    }
}

//! tag: append
//!  Append a value to a variable.
//! attribute: variable
//!  The variable to append to.
//! attribute: [scope]
//!  The scope of the variable.
//! attribute: [debug]
//!  Provide debug messages in case the operation fails. <tt>&lt;append&gt;</tt>
//!  will normally fail silently.
//! attribute: define
//!  Append the contents of this define.
//! attribute: from
//!  Append the value of the named variable.
//! attribute: other
//!  Append the value of this <i>other</i> variable. This is mostly useful
//!  from within <i>output</i> tags like <tt>&lt;sqloutput&gt;</tt> where all
//!  columns from the sql result will be available as <i>other</i>
//!  variables.
//! attribute: value
//!  Append the variable to this value.
//! example: rxml
//!  {set variable=foo value="Hello"}
//!  {append variable="foo" value=" World"}
//!  {insert variable="foo"}

string tag_append( string tag, mapping m, object id )
{
  string val, to_add;
  int ret;
  if (m->variable)
  {
    if (m->value)
      // Set variable to value.
      to_add = m->value;
    else if (m->from) {
      // Set variable to the value of another variable
      to_add = get_scope_var(m->from, 0, id);
      if(!to_add && (m->debug || id->misc->debug))
	return "<b>Append: from variable doesn't exist</b>";
    } else if (m->other) {
      // Set variable to the value of a misc variable
      if (!(to_add =  id->misc->variables[ m->other ]) && 
	  (m->debug || id->misc->debug))
	return "<b>Append: other variable doesn't exist</b>";
    } else if(m->define) {
      // Set variable to the value of a define
      to_add = id->misc->defines[ m->define ];
    } else if (m->debug || id->misc->debug) {
      return "<b>Append: nothing to append from</b>";
    } else {
      return "";
    }
    if(!to_add) /* Nothing to add */
      return ""; 
    if(!(val = get_scope_var(m->variable, m->scope, id)))
      ret = set_scope_var(m->variable, m->scope, to_add, id);
    else {
      if(catch(ret = set_scope_var(m->variable, m->scope, val + to_add, id))) {
	return "<b>Append: Failed to add value to variable. Incompatible types.\n";
      }
    }
    if(!ret && (m->debug || id->misc->debug))
      return "<b>Append: Failed to set variable "+(m->scope?m->scope+".":"")
	+m->variable+" - read only scope? </b>";
    return "";
  }
  else if (m->debug || id->misc->debug)
    return("<b>Append: variable not specified</b>");
  else
    return "";
}

//! tag: use
//!  Reads tags, container tags and defines from a file or package. The
//!  <tt>&lt;use&gt;</tt> tag is much faster than the
//!  <tt>&lt;include&gt;</tt>, since the parsed definitions is cached.
//! bugs:
//!  Fix support for new-style scope/variables.
//! attribute: file
//!  Reads all tags and container tags and defines from the file.
//!  <p>This file will be fetched just as if someone had tried to fetch it
//!  with an HTTP request. This makes it possible to use Pike script
//!  results and other dynamic documents. Note, however, that the results of the
//!  parsing are heavily cached for performance reasons. If you do not want
//!  this cache, use <doc>{insert file="..." nocache="" /}</doc> instead.</p>
//! attribute: package
//!  Reads all tags, container tags and defines from the given
//!  package. Packages are files located in
//!  <i>local/rxml_packages/</i>. 
//!  <p>By default, the package <i>gtext_headers</i> is available, that
//!  replaces normal headers with graphical headers. It redefines the h1,
//!  h2, h3, h4, h5 and h6 container tags.</p>

string tag_use(string tag, mapping m, object id)
{
  mapping res = ([]);
  object nid = id->clone_me();

  nid->misc = ([]);
  nid->misc->tags = 0;
  nid->misc->containers = 0;
  nid->misc->defines = ([]);
  nid->misc->_tags = 0;
  nid->misc->_containers = 0;
  nid->misc->defaults = ([]);

  if(m->packageinfo)
  {
    string res ="<dl>";
    array dirs = get_dir("../rxml_packages");
    if(dirs)
      foreach(dirs, string f)
	catch 
	{
	  string doc = "";
	  string data = Stdio.read_bytes("../rxml_packages/"+f);
	  sscanf(data, "%*sdoc=\"%s\"", doc);
	  parse_rxml(data, nid);
	  res += "<dt><b>"+f+"</b><dd>"+doc+"<br>";
	  array tags = indices(nid->misc->tags||({}));
	  array containers = indices(nid->misc->containers||({}));
	  if(sizeof(tags))
	    res += "defines the following tag"+
	      (sizeof(tags)!=1?"s":"") +": "+
	      String.implode_nicely( sort(tags) )+"<br>";
	  if(sizeof(containers))
	    res += "defines the following container"+
	      (sizeof(tags)!=1?"s":"") +": "+
	      String.implode_nicely( sort(containers) )+"<br>";
	};
    else
      return "No package directory installed.";
    return res+"</dl>";
  }


  if(!m->file && !m->package) 
    return "<use help>";
  if(m->file)
    m->file = Caudium.fix_relative(m->file,nid);
  if(id->pragma["no-cache"] || 
     !(res = cache_lookup("macrofiles:"+ id->conf->name ,
			  (m->file || m->package))))
  {
    res = ([]);
    string foo;
    if(m->file)
      foo = nid->conf->try_get_file(m->file, nid );
    else 
      foo=Stdio.read_bytes("../rxml_packages/"+combine_path("/",m->package));
      
    if(!foo)
      if(id->misc->debug)
	return "Failed to fetch "+(m->file||m->package);
      else
	return "";
    parse_rxml( foo, nid );
    res->tags  = nid->misc->tags||([]);
    res->_tags = nid->misc->_tags||([]);
    foreach(indices(res->_tags), string t)
      if(!res->tags[t]) m_delete(res->_tags, t);
    res->containers  = nid->misc->containers||([]);
    res->_containers = nid->misc->_containers||([]);
    foreach(indices(res->_containers), string t)
      if(!res->containers[t]) m_delete(res->_containers, t);
    res->defines = nid->misc->defines||([]);
    res->defaults = nid->misc->defaults||([]);
    m_delete(res->defines, "line");
    cache_set("macrofiles:"+ id->conf->name, (m->file || m->package), res);
  }
  if(!id->misc->tags)
    id->misc->tags = res->tags;
  else
    id->misc->tags |= res->tags;

  if(!id->misc->containers)
    id->misc->containers = res->containers;
  else
    id->misc->containers |= res->containers;

  if(!id->misc->defaults)
    id->misc->defaults = res->defaults;
  else
    id->misc->defaults |= res->defaults;

  if(!id->misc->defines)
    id->misc->defines = copy_value(res->defines);
  else
    id->misc->defines |= copy_value(res->defines);

  foreach(indices(res->_tags), string t)
    id->misc->_tags[t] = res->_tags[t];

  foreach(indices(res->_containers), string t) 
    id->misc->_containers[t] = res->_containers[t];

  if(id->misc->_xml_parser) {
    id->misc->_xml_parser->add_tags(res->_tags);
    id->misc->_xml_parser->add_containers(res->_containers);
  }

  if(id->misc->debug)
    return sprintf("<!-- Using the file %s, id %O -->", m->file, res);
  else
    return "";
}

//! container: define
//!  Defines new tags, container tags or defines. You can use a few
//!  special tokens in the definition of tags and container tags:
//!  <dl>
//!   <p><dt><tt><b>#args#</b></tt></dt><dd>All arguments sent to the tag. Useful when
//!   defining a new tag that is more or less only an alias for an old one.</dd></p>
//!   <p><dt><tt><b>&amp;attribute;</b></tt></dt><dd>Inserts the value of that attribute.</dd></p>
//!  </dl>
//!  In a custom container, &lt;contents> will be replaced with the contents
//!  of the container.
//! bugs:
//!  Defined tags and containers DO NOT work with the XML compliant main
//!  parser. This is obviously an issue that needs to be fixed.
//! attribute: container
//!  Define a new RXML container tag, or override a previous definition.
//! attribute: name
//!  Sets the specified define. Can be inserted later by the
//!  <tt>&lt;insert&gt;</tt> tag.
//! attribute: tag
//!  Defines a new RXML tag, or overrides a previous definition.
//! attribute: default_XXX
//!  Set a default value for an attribute, that will be used when the
//!  attribute is not specified when the defined tag or container is used.
//! example: rxml
//!  {define container="h1"}
//!   {gtext fg="blue" #args#}{contents}{/gtext}
//!  {/define}
//!  {h1}Hello{/h1}
//! example: rxml
//!  {define container="h"1}
//!   {gtext fg="blue" #args#}{contents}{/gtext}
//!  {/define}
//!  {h1}Hello{/h1}
//! example: rxml
//!  {define tag="test" default_foo="foo"
//! 	      default_bar="bar"}
//!   The test tag: Testing testing.
//!   Foo is &foo;, bar is &bar;
//!  {/define}
//!  {test foo="Hello" bar="World"}
//!  {br}{test foo="Hello"}

string tag_define(string tag, mapping m, string str, object id, object file,
		  mapping defines)
{ 
  if(m->parse)
    str = parse_rxml( str, id );
  if (m->name) 
    defines[m->name]=str;
  else if(m->variable)
    id->variables[m->variable] = str;
  else if (m->tag) 
  {
    if(!id->misc->tags)
      id->misc->tags = ([]);
    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    m->tag = lower_case(m->tag);
    if(!id->misc->defaults[m->tag])
      id->misc->defaults[m->tag] = ([]);

    foreach( indices(m), string arg )
      if( arg[0..7] == "default_" )
	id->misc->defaults[m->tag] += ([ arg[8..]:m[arg] ]);
    
    id->misc->tags[m->tag] = str;
    id->misc->_tags[m->tag] = CALL_USER_TAG;
    if(id->misc->_xml_parser) 
      id->misc->_xml_parser->add_tag(m->tag, CALL_USER_TAG);
  }
  else if (m->container) 
  {
    if(!id->misc->containers)
      id->misc->containers = ([]);

    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    if(!id->misc->defaults[m->container])
      id->misc->defaults[m->container] = ([]);

    foreach( indices(m), string arg )
      if( arg[0..7] == "default_" )
	id->misc->defaults[m->container] += ([ arg[8..]:m[arg] ]);
    
    id->misc->containers[m->container] = str;
    id->misc->_containers[m->container] = CALL_USER_CONTAINER;
    if(id->misc->_xml_parser) 
      id->misc->_xml_parser->add_container(m->container, CALL_USER_CONTAINER);
  }
  else return "<!-- No name, tag or container specified for the define! "
	 "&lt;define help&gt; for instructions. -->";
  return ""; 
}

//! tag: undefine
//!  Undefines a previously defined tag, container tag or define.
//!  Wildcard globs with one or more asterisk make it possible to
//!  undefine more than one of a certain type at a time.
//! attribute: name
//!  Undefine this define.
//! attribute: tag
//!  Undefine this tag.
//! attribute: container
//!  Undefine this container tag.

string tag_undefine(string tag, mapping m, object id, object file,
		    mapping defines)
{ 
  if (m->name) 
  {
    if (search(m->name,"*") >= 0) {
      foreach (indices(defines),string d) {
        if (glob(m->name,d)) {
          m_delete(defines,d);
        }
      }
    } else {
    m_delete(defines,m->name);
    }
  }
  else if(m->variable)
  {
    if (search(m->variable,"*") >= 0) {
      foreach (indices(id->variables),string v) {
        if (glob(m->variable,v)) {
          m_delete(id->variables,v);
        }
      }
    } else {
    m_delete(id->variables,m->variable);
    }
  }
  else if (m->tag) 
  {
    if (search(m->tag,"*") >= 0) {
      foreach (indices(id->misc->tags),string t) {
        if (glob(m->tag,t)) {
          m_delete(id->misc->tags,t);
          m_delete(id->misc->_tags,t);
          if(id->misc->_xml_parser) {
            id->misc->_xml_parser->add_tag(t, 0);
          }
        }
      }
    } else {
    m_delete(id->misc->tags,m->tag);
    m_delete(id->misc->_tags,m->tag);
    if(id->misc->_xml_parser) 
      id->misc->_xml_parser->add_tag(m->tag, 0);
    }
  }
  else if (m->container) 
  {
    if (search(m->container,"*") >= 0) {
      foreach (indices(id->misc->containers),string c) {
        if (glob(m->container,c)) {
          m_delete(id->misc->containers,c);
          m_delete(id->misc->_containers,c);
          if(id->misc->_xml_parser) {
            id->misc->_xml_parser->add_container(c, 0);
          }
        }
      }
    } else {
    m_delete(id->misc->containers,m->container);
    m_delete(id->misc->_containers,m->container);
    if(id->misc->_xml_parser) 
      id->misc->_xml_parser->add_container(m->container, 0);
    }
  }
  else return "<!-- No name, tag or container specified for undefine! "
	 "&lt;undefine help&gt; for instructions. -->";
  return ""; 
}



string tag_echo(string tag,mapping m,object id,object file,
			  mapping defines)
{
  if(m->help) 
    return ("This tag outputs the value of different configuration and"
	    " request local variables. They are not really used by Caudium."
	    " This tag is included only to provide compatibility with"
	    " \"normal\" WWW-servers");
  if(!m->var)
  {
    if(sizeof(m) == 1)
      m->var = m[indices(m)[0]];
    else 
      return "<!-- �Que? -->";
  } else if(tag == "insert")
    return "";
  if(tag == "!--#echo" && id->misc->ssi_variables &&
     id->misc->ssi_variables[m->var])
    // Variables set with !--#set.
    return _Roxen.html_encode_string(id->misc->ssi_variables[m->var]);

  mapping myenv =  Caudium.Env.build_vars(0,  id, 0);
  m->var = lower_case(replace(m->var, " ", "_"));
  switch(m->var)
  {
   case "sizefmt":
   case "errmsg":
    return defines[m->var] || "";
   case "timefmt":
    return defines[m->var] || "%c";
    
   case "date_local":
    NOCACHE();
#if constant(Caudium.strftime)
    return Caudium.strftime(defines->timefmt || "%c", time(1));
#else
    return "Your system is lack of strftime() function";
#endif /* constant (Caudium.strftime) */

   case "date_gmt":
    NOCACHE();
#if constant(Caudium.strftime)
    return Caudium.strftime(defines->timefmt || "%c", time(1) + localtime(time(1))->timezone);
#else
    return "Your system is lack of strftime() function";
#endif /* constant (Caudium.strftime) */
      
   case "query_string_unescaped":
    return id->query || "";

   case "last_modified":
     // FIXME: Use defines->timefmt
    return tag_modified(tag, m, id, file, defines);
      
   case "server_software":
    return caudium->version();
      
   case "server_name":
    string tmp;
    tmp=id->conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    return tmp;
      
   case "gateway_interface":
    return "CGI/1.1";
      
   case "server_protocol":
    return "HTTP/1.0";
      
   case "request_method":
    return _Roxen.html_encode_string(id->method);

   case "auth_type":
    return (id->rawauth?(id->rawauth/" ")[0]:"");
      
   case "http_cookie": case "cookie":
    NOCACHE();
    return ( id->misc->cookies?_Roxen.html_encode_string(id->misc->cookies):"" );

   case "http_accept":
    NOCACHE();
    return (id->misc->accept && sizeof(id->misc->accept)? 
	    _Roxen.html_encode_string(id->misc->accept*", "): "None");
      
   case "http_user_agent":
    NOCACHE();
    return _Roxen.html_encode_string(id->useragent);
      
   case "http_referer":
   case "http_referrer":
    NOCACHE();
    return _Roxen.html_encode_string(id->referrer|| "Unknown");
      
   default:
    m->var = upper_case(m->var);
    if(myenv[m->var]) {
      NOCACHE();
      return _Roxen.html_encode_string(myenv[m->var]);
    }
    if(tag == "insert")
      return "";
    return "<i>Unknown variable</i>: '"+m->var+"'";
  }
}

//! tag: insert
//!  Inserts values from files, cookies, defines or variables. If used to
//!  insert cookies or variables <tt>&lt;insert&gt;</tt> will quote before
//!  inserting, to make it impossible to insert dangerous RXML tags.
//! attribute: cookie
//!  Inserts the value of the cookie.
//! attribute: cookies
//!  Inserts the value of all cookies. With the optional argument full, the
//!  insertion will be more verbose.
//! attribute: encode
//!  Determines what quoting method should be when inserting cookies or
//!  variables. Default is <i>html</i>, which means that &lt;, &gt; and
//!  &amp; will be quoted, to make sure you can't insert RXML tags. If you
//!  choose <i>none</i> nothing will be quoted. It will be possible to
//!  insert dangerous RXML tags so you must be of what your variables
//!  contain.
//! attribute: define
//!  Inserts this define, which must have been defined by the
//!  <tt>&lt;define&gt;</tt> tag before it is used. The define can be done in
//!  another file, if you have inserted the file. 
//! attribute: file
//!  Inserts the file. This file will then be fetched just as if someone
//!  had tried to fetch it through an HTTP request. This makes it possible to
//!  include things like the result of Pike scripts. It also has the side-effect
//!  that files that normally would be parsed (.rxml files for example)
//!  will be parsed before being inserted into the current file. 
//! 
//!  <p>If path does not begin with <i>/</i>, it is assumed to be a URL
//!  relative to the directory containing the page with the
//!  <tt>&lt;insert&gt;</tt> tag. Note that included files will be parsed if they
//!  are named with an extension the main RXML parser handles. This might
//!  cause unexpected behavior. For example, it will not be possible to
//!  share any macros defined by the <tt>&lt;define&gt;</tt> tags. </p>
//! 
//!  <p>If you want to have a file with often used macros you should name
//!  it with an extension that won't be parsed. For example, <i>.txt</i>.</p>
//! attribute: fromword=toword
//!  Replaces fromword with toword in the macro or file, before insering
//!  it. Note that only lower case character sequences can be replaced.
//! attribute: nocache
//!  Don't cache results when inserting files, but always fetch the file. 
//! attribute: variable
//!  Insert the named variable. It can be written on the simple form,
//!  "variable" or with the scope (which defaults to "form"),
//!  scope.variable.
//! attribute: scope
//!  Use this scope. The variable attribute will be considered to be a
//!  simple name when this attribute is present. I.e. &lt;insert
//!  variable="client.name" scope="var" />&gt; will insert the variable
//!  <tt>client.name</tt> from the scope <tt>var</tt>
//! example: rxml
//!  {define name="foo"}This is a foo{/define}
//!  {insert define="foo" /}
//!  {br /}{insert name="foo" foo="cat" /}
//!  {br /}{insert name="foo" a="some" foo="cats" is="are" /}

array(string)|string tag_insert(string tag,mapping m,object id,object file,mapping defines)
{
  string n, scope, var;
  mapping fake_id=([]);
  array encodings=({ "html" });
  mixed val;
  
  if(m->encode)
  {
    encodings=m->encode/",";
    m_delete( m, "encode" );
  }

  if (n=m->name || m->define)
  {
    m_delete(m, "name");
    m_delete(m, "define");
    return replace(defines[n]||
		      (id->misc->debug?"No such define: "+n:""), m);
  }

  if (n=m->variable) 
  {
    m_delete(m, "variable");  
    val = get_scope_var(n, m->scope, id);
    m_delete(m, "scope");
    if(arrayp(val))
      /* Safe value, won't be parsed */
      return val;
    return do_safe_replace(val||(id->misc->debug?"No such variable: "+n:""),
			   m, encodings);
  }
  
  if (n=m->variables) 
  {
    if(n!="variables")
      return Array.map(replace(n, ",", " ")/ " " - ({ "" }), 
		       lambda(string s, object id, mapping m, array encodings) {
			 mixed val;
			 val = get_scope_var(s, 0, id);
			 if(arrayp(val))
			   val = val[0];
			 return
			   sprintf("%s=%O\n<br>", s,
				   do_safe_replace(val||
						   (id->misc->debug ?
						    "No such variable: "+s:""),
						   m, encodings));
		       }, id, m, encodings)*"\n";
    return do_safe_replace(String.implode_nicely(indices(id->variables)),
			   m, encodings);
  }
  
  if (n=m->cookies) 
  {
    NOCACHE();
    if(n!="cookies")
      return Array.map(indices(id->cookies), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, id->cookies)*"\n";
    return do_safe_replace(String.implode_nicely(indices(id->cookies)),
			   m, encodings);
  }

  if (n=m->cookie) 
  {
    NOCACHE();
    m_delete(m, "cookie");
    return do_safe_replace(id->cookies[n]||
			   (id->misc->debug?"No such cookie: "+n:""),
			   m, encodings);
  }

  if (m->file) 
  {
    string s;
    string f;
    int    max_depth = QUERY(max_insert_depth);
    
    // try fighting with recursion
    if (!id->misc->include_depth)
	id->misc->include_depth = 1;
    else
	id->misc->include_depth++;

    if (id->misc->include_depth > max_depth)
	return id->misc->debug ? "Recursion too deep!" : "";

    f = Caudium.fix_relative(m->file, id);
    id = id->clone_me();
    if(m->nocache) {
      id->pragma["no-cache"] = 1;
      NOCACHE();
    }

    if(sscanf(m->file, "%*s?%s", s) == 2) {
      mapping oldvars = id->variables;
      id->variables = ([]);
      if(id->scan_for_query)
	f = id->scan_for_query( f );
      id->variables = oldvars | id->variables;
      id->misc->_temporary_query_string = s;
    }
    s = id->conf->try_get_file(f, id);


    if(!s) {
      if ((sizeof(f)>2) && (f[sizeof(f)-2..] == "--")) {
	// Might be a compat insert. <!--#include file=foo.html-->
	s = id->conf->try_get_file(f[..sizeof(f)-3], id);
      }
      if (!s) {

	// Might be a PATH_INFO type URL.
	if(id->misc->avoid_path_info_recursion++ < 5)
	{
	  array a = id->conf->open_file( f, "r", id );
	  if(a && a[0])
	  {
	    s = a[0]->read();
	    if(a[1]->raw)
	    {
	      s -= "\r";
	      if(!sscanf(s, "%*s\n\n%s", s))
		sscanf(s, "%*s\n%s", s);
	    }
	  }
	}
	if(!s)
	  return id->misc->debug?"No such file: "+f+"!":"";
      }
    }

    m_delete(m, "file");

    if (id->misc->include_depth)    
	id->misc->include_depth--;

    return replace(s, m);
  }
  return tag_echo(tag, m, id, file, defines);
}

//! tag: dec
//!  Decrement the integer value of the specified variable with the
//!  specified amount.
//! attribute: variable
//!  The variable to decrement.
//! attribute: [scope]
//!  The scope of the variable. See [set] for more information.
//! attribute: [val]
//!  The optional value to decrement the variable with. Defaults to 1.
//! see_also: inc
//! example: rxml
//!  {set variable="var.test" value="10 /}
//!  {dec variable="var.test" value="5" /}
//!  {insert variable="var.test" /}

string|array(string) tag_dec(string tag, mapping args, object id) {
  if(!args->variable)
    return ({ "<b>inc: Missing variable.</b>" });
  int val = -(int)args->value;
  if(!val && !args->value) val=-1;
  return inc(args, val, id);
}

//! tag: inc
//!  Increment the integer value of the specified variable with the
//!  specified amount.
//! attribute: variable
//!  The variable to increment.
//! attribute: [scope]
//!  The scope of the variable. See [set] for more information.
//! attribute: [val]
//!  The optional value to increment the variable with. Defaults to 1.
//! see_also: dec
//! example: rxml
//!  {set variable="var.test" value="10 /}
//!  {inc variable="var.test" value="5" /}
//!  {insert variable="var.test" /}

string|array(string) tag_inc(string tag, mapping args, object id) {
  if(!args->variable)
    return ({ "<b>inc: Missing variable.</b>" });
  int val = (int)args->value;
  if(!val && !args->value) val = 1;
  return inc(args, val, id);
}

static string|array(string) inc(mapping m, int val, object id)
{
  string scope, var;
  mixed curr;
  [scope,var] = parse_scope_var(m->variable, m->scope);
  if(!id->misc->scopes[scope])
    return ({"\n<b>Scope "+scope+" does not exist.</b>\n"});
  curr = get_scope_var(var, scope, id);
  catch {
    curr = (int)curr;
  };
  curr += val;
  if(!set_scope_var(var, scope, (string)curr, id))
    return ({"\n<b>Scope "+scope+" read-only.</b>\n"});
  return "";
}

string tag_modified(string tag, mapping m, object id, object file,
		    mapping defines)
{
  array (int) s;
  object f;
  
  if(m->by && !m->file && !m->realfile)
  {
    if(!id->conf->auth_module)
      return "<!-- modified by requires an user database! -->\n";
    m->name = caudium->last_modified_by(file, id);
    CACHE(10);
    return tag_user(tag, m, id, file, defines);
  }

  if(m->file)
  {
    m->realfile = id->conf->real_file(Caudium.fix_relative(m->file,id), id);
    m_delete(m, "file");
  }

  if(m->by && m->realfile)
  {
    if(!id->conf->auth_module)
      return "<!-- modified by requires an user database! -->\n";

    if(f = open(m->realfile, "r"))
    {
      m->name = caudium->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id, file,defines);
    }
    return "A. Nonymous.";
  }
  
  if(m->realfile)
    s = file_stat(m->realfile);

  if(!(_stat || s) && !m->realfile && id->realfile)
  {
    m->realfile = id->realfile;
    return tag_modified(tag, m, id, file, defines);
  }
  CACHE(10);
  if(!s) s = _stat;
  if(!s) s = id->conf->stat_file( id->not_query, id );
  return s ? tagtime(s[3], m) : "Error: Cannot stat file";
}

string tag_version(string tag, mapping m) 
{
    string ver = caudium->version();
    int    minor, major, release;
    
    if (!m || !sizeof(m))
        return ver;

    sscanf(ver, "Caudium/%d.%d.%d", major, minor, release);

    if (m->major)
        return (string)major;

    if (m->minor)
        return (string)minor;

    if (m->release)
        return (string)release;

    return "";
}

string tag_clientname(string tag, mapping m, object id)
{
  NOCACHE();
  if(m->full) 
    return _Roxen.html_encode_string(id->useragent);
  else if (m->short)
    return _Roxen.html_encode_string((((id->useragent/" ")[0])/"/")[0]);
  else if (m->version)
    return _Roxen.html_encode_string((((id->useragent/" ")[0])/"/")[1]);
  else
    return _Roxen.html_encode_string((id->useragent/" ")[0]);
}

string tag_signature(string tag, mapping m, object id, object file,
		     mapping defines)
{
  return "<right><address>"+tag_user(tag, m, id, file,defines)+"</address></right>";
}

string tag_user(string tag, mapping m, object id, object file,mapping defines)
{
  array(string) u;
  string b, dom;

  if(!id->conf->auth_module)
    return "<!-- user requires an user database! -->\n";

  if (m->queryname) 
  {
    int|mapping u=id->get_user();
    return (u?u->username:"");
  }

  if (!(b=m->name)) {
    return(tag_modified("modified", m | ([ "by":"by" ]), id, file,defines));
  }

  b=m->name;

  dom = id->conf->query("Domain");
  if(sizeof(dom) && (dom[-1]=='.'))
    dom = dom[0..strlen(dom)-2];
  if(!b) return "";
  u=id->conf->userinfo(b, id);
  if(!u) return "";
  
  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return "<a href=\"/~"+b+"/\">"+u[4]+"</a>";
    return u[4];
  }
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return "<a href=\"mailto:" + b + "@" + dom + "\">"
	+ b + "@" + dom + "</a>";
    return b + "@" + dom;
  }
  if(m->nolink && !m->link)
    return u[4] + " &lt;" + b + "@" + dom + "&gt;";
  return ("<a href=\"/~"+b+"/\">"+u[4]+"</a>"+
	  " <a href=\"mailto:" + b + "@" + dom + "\"> &lt;"+
	  b + "@" + dom + "&gt;</a>");
}

int match_passwd(string try, string org)
{
  if(!strlen(org))   return 1;
  if(crypt(try, org)) return 1;
}

string simple_parse_users_file(string file, string u)
{
 foreach(file/"\n", string line)
 {
   array(string) arr = line/":";
   if (arr[0] == u) {
     if (sizeof(arr) > 1) {
       return(arr[1]);
     }
   }
 }
 return 0;
}

int match_user(string raw, string user, string f, int wwwfile, object id)
{
  string s, pass;
  if(!raw || raw=="")
    return 0; // No auth sent
  if(!wwwfile)
    s=Stdio.read_bytes(f);
  else
    s=id->conf->try_get_file(f, id);
  if(!s)
    return 0;

  array u=MIME.decode_base64((raw/" ")[1] )/":";

  if(user!="" && u[0]!=user) return 0;
  pass=simple_parse_users_file(s, u[0]);
  if(!pass) return 0;
  if(id->get_user() && pass)
    return 1;
  return match_passwd(u[1], pass);
}

multiset simple_parse_group_file(string file, string g)
{
 multiset res = (<>);

 foreach(file/"\n", string line)
 {
   array(string) arr = line/":";
   if (arr[0] == g) {
     if (sizeof(arr) > 1) {
       res += (< @arr[-1]/"," >);
     }
   }
 }
 // roxen_perror(sprintf("Parse group:%O => %O\n", g, res));

 return res;
}

int group_member(string rawauth, string group, string groupfile, object id)
{
  if(!rawauth)
    return 0; // No auth sent

  string s;
  catch {
    s = Stdio.read_bytes(groupfile);
  };

  if (!s) {
    if (groupfile[0..0] != "/") {
      if (id->not_query[-1] != '/')
	groupfile = combine_path(id->not_query, "../"+groupfile);
      else
	groupfile = id->not_query + groupfile;
    }
    s = id->conf->try_get_file(groupfile, id);
  }

  if (!s) {
    return 0;
  }

  s = replace(s, ({ " ", "\t", "\r" }), ({ "", "", "" }));
  multiset(string) members = simple_parse_group_file(s, group);
  string u=(rawauth/" ")[1];
  u=(MIME.decode_base64(u)/":")[0];
  return members && members[replace(u,
				    ({ " ", "\t", "\r" }), ({ "", "", "" }))];
}

string tag_prestate(string tag, mapping m, string q, object id);
string tag_client(string tag,mapping m, string s,object id,object file);
string tag_deny(string a,  mapping b, string c, object d, object e, 
		mapping f, object g);


#define TEST(X)\
 do { if(X) if(m->or) {if (QUERY(compat_if)) return "<true>"+s; else return s+"<true>";} else ok=1; else if(!m->or) return "<false>"; } while(0)

#define IS_TEST(X, Y) do                		\
{							\
  if(m->X)						\
  {							\
    string a, b;					\
    if(sscanf(m->X, "%s is %s", a, b)==2)		\
      TEST(Caudium._match(Y[a], b/","));			\
    else						\
      TEST(Y[m->X]);					\
  }							\
} while(0)


string tag_allow(string a, mapping (string:string) m, 
		 string s, object id, object file, 
		 mapping defines, object client)
{
  int ok;

  if(m->help)
    return ("DEPRECATED: Kept for compatibility reasons.");
  if(m->not)
  {
    m_delete(m, "not");
    return tag_deny("", m, s, id, file, defines, client);
  }

  if(m->eval) TEST((int)parse_rxml(m->eval, id));

  if(m->module)
    TEST(id->conf && id->conf->modules[m->module]);
  
  if(m->exists) {
    CACHE(10);
    TEST(id->conf->try_get_file(Caudium.fix_relative(m->exists,id),id,1,1));
  }

  if(m->filename)
    TEST(Caudium._match(id->not_query, m->filename/","));

  if(m->language)
  {
    NOCACHE();
    if(!id->misc["accept-language"])
    {
      if(!m->or)
	return "<false>";
    } else {
      TEST(Caudium._match(lower_case(id->misc["accept-language"]*" "),
		  ("*"+(lower_case(m->language)/",")*"*,*"+"*")/","));
    }
  }

  if(m->variable)
  {							
    string a, b;					
    if(sscanf(m->variable, "%s is %s", a, b) == 2) {
      if(a = get_scope_var(a, m->scope, id)) {
	TEST(Caudium._match(a, b/","));
      }
    } else {
      TEST(get_scope_var(m->variable, m->scope, id));
    }
  }

  if(m->cookie) NOCACHE();
  IS_TEST(cookie, id->cookies);
  IS_TEST(defined, defines);

  if (m->successful) TEST (_ok);
  if (m->failed) TEST (!_ok);

  if (m->match) {
    string a, b;
    if(sscanf(m->match, "%s is %s", a, b)==2)
      TEST(Caudium._match(a, b/","));
  }

  if(m->accept)
  {
    NOCACHE();
    if(!id->misc->accept)
    {
      if(!m->or)
	return "<false>";
    } else {
      TEST(glob("*"+m->accept+"*",id->misc->accept*" "));
    }
  }
  if((m->referrer) || (m->referer))
  {
    NOCACHE();
    if (!m->referrer) {
      m->referrer = m->referer;		// Backward compat
    }
    if(id && id->referrer)
    {
      if(m->referrer-"r" == "efee")
      {
	if(m->or) {
	  if (QUERY(compat_if)) 
	    return "<true>" + s;
	  else
	    return s + "<true>";
	} else
	  ok=1;
      } else if (Caudium._match(id->referrer, m->referrer/",")) {
	if(m->or) {
	  if (QUERY(compat_if))
	    return "<true>" + s;
	  else
	    return s + "<true>";
	} else
	  ok=1;
      } else if(!m->or) {
	return "<false>";
      }
    } else if(!m->or) {
      return "<false>";
    }
  }

  if(m->date)
  {
    CACHE(60);

    int tok, a, b;
    mapping c;
    c=localtime(time(1));
    b=(int)sprintf("%02d%02d%02d", c->year, c->mon + 1, c->mday);
    a=(int)m->date;
    if(a > 999999) a -= 19000000;
    if(m->inclusive || !(m->before || m->after) && a==b)
      tok=1;

    if(m->before && a>b)
      tok=1;
    else if(m->after && a<b)
      tok=1;

    TEST(tok);
  }


  if(m->time)
  {
    CACHE(60);

    int tok, a, b, d;
    mapping c;
    c=localtime(time(1));

    b=(int)sprintf("%02d%02d", c->hour, c->min);
    a=(int)m->time;

    if(m->until) {
      d = (int)m->until;
      if (d > a && (b > a && b < d) )
        tok = 1 ;
      if (d < a && (b > a || b < d) )
        tok = 1 ;
      if (m->inclusive && ( b==a || b==d ) )
        tok = 1 ;
    }
    else if(m->inclusive || !(m->before || m->after) && a==b)
      tok=1;
    if(m->before && a>b)
      tok=1;
    else if(m->after && a<b)
      tok=1;

    TEST(tok);
  }
 

  if(m->supports || m->name)
  {
    NOCACHE();

    string q;
    q=tag_client("", m, s, id, file);
    TEST(q != "" && q);
  }

  if(m->wants)  m->config = m->wants;
  if(m->configured)  m->config = m->configured;

  if(m->config)
  {
    NOCACHE();

    string c;
    foreach(m->config/",", c)
      TEST(id->config[c]);
  }

  if(m->prestate)
  {
    string q;
    q=tag_prestate("", mkmapping(m->prestate/",",m->prestate/","), s, id);
    TEST(q != "" && q);
  }

  if(m->host)
  {
    NOCACHE();
    TEST(Caudium._match(id->remoteaddr, m->host/","));
  }

  if(m->domain)
  {
    NOCACHE();
    TEST(Caudium._match(caudium->quick_ip_to_host(id->remoteaddr), m->domain/","));
  }
  
  if(m->user)
  {
    NOCACHE();

    if(m->user == "any")
    {
      // are we supplying our own auth file?
      if(m->file && id->rawauth) {
	// FIXME: wwwfile attribute doesn't work.
	TEST(match_user(id->rawauth, "", Caudium.fix_relative(m->file,id),
			!!m->wwwfile, id));
       }
       else
 	TEST(id->get_user);
    }
    else
      if(m->file && id->auth) {
	// FIXME: wwwfile attribute doesn't work.
	TEST(match_user(id->rawauth,m->user,Caudium.fix_relative(m->file,id),
			!!m->wwwfile, id));
      } else
      {
        int|mapping u=id->get_user();
	TEST(u && search(m->user/",", u->username)
	     != -1);
      }
  }

  if (m->group) {
    NOCACHE();

    if (m->groupfile && sizeof(m->groupfile)) {
      TEST(group_member(id->rawauth, m->group, m->groupfile, id));
    } else { // we can use the nifty new group functionality.
      int|mapping u=id->get_user();
      if(!u) return "<false>";
      else if(search(u->groups, m->group)!=-1) return "<true>";
      else return "<false>";
    }
  }

  return ok?(QUERY(compat_if)?"<true>"+s:s+"<true>"):"<false>";
}

string tag_configurl(string f, mapping m, object id)
{
  return caudium->config_url(id);
}

string tag_configimage(string f, mapping m)
{
  string args="";

  while(sizeof(m))
  {
    string q;
    switch(q=indices(m)[0])
    {
     case "src":
      args += " src=\"/(internal,image)/"+ (m->src-".png") + "\"";
      break;
     default:
      args += " "+q+"=\""+m[q]+"\"";
    }
    m_delete(m, q);
  }
  return ("<img border=0 "+args+">");
}

string tag_aprestate(string tag, mapping m, string q, object id)
{
  string href, s;
  array(string) foo;
  multiset prestate=(< >);

  if(!(href = m->href))
    href=Caudium.strip_prestate(Caudium.strip_config(id->raw_url));
  else 
  {
    if ((sizeof(foo = href / ":") > 1) && (sizeof(foo[0] / "/") == 1))
      return Caudium.make_container("a",m,q);
    href=Caudium.fix_relative(href, id);
    m_delete(m, "href");
  }
  
  if(!strlen(href))
    href="";

  prestate = (< @indices(id->prestate) >);

  foreach(indices(m), s) {
    if(m[s]==s) {
      m_delete(m,s);

      if(strlen(s) && s[0] == '-')
	prestate[s[1..]]=0;
      else
	prestate[s]=1;
    }
  }
  m->href = Caudium.add_pre_state(href, prestate);
  return Caudium.make_container("a",m,q);
}

string tag_aconfig(string tag, mapping m, string q, object id)
{
  string href;
  mapping(string:string) cookies = ([]);
  
  if(m->help) return "Alias for &lt;aconf&gt;";

  if(!m->href)
    href=Caudium.strip_prestate(Caudium.strip_config(id->raw_url));
  else 
  {
    href=m->href;
    if (search(href, ":") == search(href, "//")-1)
      return sprintf("<!-- Cannot add configs to absolute URLs -->\n"
		     "<a href=\"%s\">%s</a>", href, q);
    href=Caudium.fix_relative(href, id);
    m_delete(m, "href");
  }

  foreach(indices(m), string opt) {
    if(m[opt]==opt) {
      if(strlen(opt)) {
	switch(opt[0]) {
	case '+':
	  m_delete(m, opt);
	  cookies[opt[1..]] = opt;
	  break;
	case '-':
	  m_delete(m, opt);
	  cookies[opt] = opt;
	  break;
	}
      }
    }
  }
  m->href = Caudium.add_config(href, indices(cookies), id->prestate);
  return Caudium.make_container("a", m, q);
}

string add_header(mapping to, string name, string value)
{
  if(to[name])
    if(arrayp(to[name]))
      to[name] += ({ value });
    else
      to[name] = ({ to[name], value });
  else
    to[name] = value;
}

string tag_add_cookie(string tag, mapping m, object id, object file,
		      mapping defines)
{
  string cookies;
  int    t;     //time

  if(m->name)
    cookies = m->name+"="+Caudium.http_encode_cookie(m->value||"");
  else
    return "<!-- set_cookie requires a `name' -->";

  if(m->persistent)
    t=(3600*(24*365*2));
  else
  {
    if (m->hours)   t+=((int)(m->hours))*3600;
    if (m->minutes) t+=((int)(m->minutes))*60;
    if (m->seconds) t+=((int)(m->seconds));
    if (m->days)    t+=((int)(m->days))*(24*3600);
    if (m->weeks)   t+=((int)(m->weeks))*(24*3600*7);
    if (m->months)  t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
    if (m->years)   t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
  }

  if(t) cookies += "; expires="+Caudium.HTTP.date(t+time());

  //obs! no check of the parameter's usability
  cookies += "; path=" +(Caudium.http_encode_cookie(m->path||"/"));
  if(m->domain)
    cookies += "; domain="+Caudium.http_encode_cookie(m->domain);
  add_header(_extra_heads, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, object id, object file,
			 mapping defines)
{
  string cookies;
  if(m->name)
    cookies = m->name+"="+Caudium.http_encode_cookie(m->value||"")+
      "; expires="+Caudium.HTTP.date(0)+"; path=/";
  else
    return "<!-- remove_cookie requires a `name' -->";

  add_header(_extra_heads, "Set-Cookie", cookies);
  return "";
}

string tag_addprestate(string tag, mapping m, string q, object id)
{
  return "(" + sort(indices(id->prestate)) * "," + ")";
} 
  
string tag_prestate(string tag, mapping m, string q, object id)
{
  if(m->help) return "DEPRECATED: This tag is here for compatibility reasons only";
  int ok, not=!!m->not, or=!!m->or;
  multiset pre=id->prestate;
  string s;

  foreach(indices(m), s)
    if(pre[s])
    {
      if(not) 
	if(!or)
	  return "";
	else
	  ok=0;
      else if(or)
	return q;
      else
	ok=1;
    } else {
      if(not)
	if(or)
	  return q;
	else
	  ok=1;
      else if(!or)
	return "";
    }
  return ok?q:"";
}

string tag_false(string tag, mapping m, object id, object file,
		 mapping defines, object client)
{
  _ok = 0;
  return "";
}

string tag_true(string tag, mapping m, object id, object file,
		mapping defines, object client)
{
  _ok = 1;
  return "";
}

string tag_if(string tag, mapping m, string s, object id, object file,
	      mapping defines, object client)
{
  string res, a, b;

  //<otherwise> will be removed in 1.4, so _don't_ use it.
  if(sscanf(s, "%s<otherwise>%s", a, b) == 2)
  {
    // compat_if mode?
    if (QUERY(compat_if)) {
      res=tag_allow(tag, m, a, id, file, defines, client);
      if (res == "<false>") {
	return b;
      }
    } else {
      res=tag_allow(tag, m, a, id, file, defines, client) +
	"<else>" + b + "</else>";
    }
  } else {
    res=tag_allow(tag, m, s, id, file, defines, client);
  }
  return res;
}

string tag_deny(string tag, mapping m, string s, object id, object file, 
		mapping defines, object client)
{
  if(m->help) return ("DEPRECATED. This tag is only here for compatibility reasons");
  if(m->not)
  {
    m->not = 0;
    return tag_if(tag, m, s, id, file, defines, client);
  }
  if(tag_if(tag,m,s,id,file,defines,client) == "<false>") {
    if (QUERY(compat_if)) {
      return "<true>"+s;
    } else {
      return s+"<true>";
    }
  }
  return "<false>";
}


string tag_else(string tag, mapping m, string s, object id, object file, 
		mapping defines) 
{ 
  return _ok?"":s; 
}
string tag_then(string tag, mapping m, string s, object id, object file, 
		mapping defines) 
{ 
  return _ok?s:""; 
}

string tag_elseif(string tag, mapping m, string s, object id, object file, 
		  mapping defines, object client) 
{ 
  if(m->help) return ("alias for &lt;elseif&gt;");
  return _ok?"":tag_if(tag, m, s, id, file, defines, client); 
}

string tag_client(string tag,mapping m, string s,object id,object file)
{
  int isok, invert;

  NOCACHE();

  if(m->help) return ("DEPRECATED, This is a compatibility tag");
  if (m->not) invert=1; 

  if (m->supports)
    isok=!! id->supports[m->supports];

  if (m->support)
    isok=!!id->supports[m->support];

  if (!(isok && m->or) && m->name)
    isok=Caudium._match(id->useragent,
		Array.map(m->name/",", lambda(string s){return s+"*";}));
  return (isok^invert)?s:""; 
}

string tag_return(string tag, mapping m, object id, object file,
		  mapping defines)
{
  if(m->code)_error=(int)m->code || 200;
  if(m->text)_rettext=m->text;
  return "";
}

string tag_error( string tag, mapping m, object id, object file,
		  mapping defines)
{
    if (! m->code && m->name && m->message ) {
        return "<!-- requires arguments -->";
    } else if ( m->help ) {
	return "<b>Usage: &lt;error code=&quot;404&quot; name=&quot;File not found&quot; message=&quot;The system was unable to locate the file you asked for. Sorry&quot;&gt;</b>";
    } else {
	_error = (int)m->code;
	_rettext = (int)m->name;
        mapping error_page = caudium->http_error->handle_error( (int)m->code, m->name, m->message, id );
	return error_page->data;
    }
}

string tag_referrer(string tag, mapping m, object id, object file,
		   mapping defines)
{
  NOCACHE();
  return _Roxen.html_encode_string(id->referrer || (m->alt ? m->alt : ".."));
}

string tag_header(string tag, mapping m, object id, object file,
		  mapping defines)
{
  if(m->name == "WWW-Authenticate")
  {
    string r;
    if(m->value)
    {
      if(!sscanf(m->value, "Realm=%s", r))
	r=m->value;
    } else {
      r="Users";
    }
    m->value="basic realm=\""+r+"\"";
  } else if(m->name=="URI") {
    m->value = "<" + m->value + ">";
  }
  
  if(!(m->value && m->name))
    return "<!-- Header requires both a name and a value. -->";

  add_header(_extra_heads, m->name, m->value);
  return "";
}

string tag_redirect(string tag, mapping m, object id, object file,
		    mapping defines)
{
  if (!(m->to && sizeof (m->to))) {
    return("<!-- Redirect requires attribute \"to\". -->");
  }

  multiset(string) orig_prestate = id->prestate;
  multiset(string) prestate = (< @indices(orig_prestate) >);
  foreach(indices(m), string s)
    if(m[s]==s && sizeof(s))
      switch (s[0]) {
	case '+': prestate[s[1..]] = 1; break;
	case '-': prestate[s[1..]] = 0; break;
      }
  id->prestate = prestate;
  mapping r = Caudium.HTTP.redirect(m->to, id);
  id->prestate = orig_prestate;

  if (r->error) {
    _error = r->error;
  }
  if (r->extra_heads) {
    _extra_heads += r->extra_heads;
  }
  if (m->text) {
    _rettext = m->text;
  }
  return("");
}

string tag_auth_required (string tagname, mapping args, object id,
			  object file, mapping defines)
{
  mapping hdrs = Caudium.HTTP.auth_required (args->realm, args->message);
  if (hdrs->error) _error = hdrs->error;
  if (hdrs->extra_heads) _extra_heads += hdrs->extra_heads;
  if (hdrs->text) _rettext = hdrs->text;
  return "";
}

string tag_expire_time(string tag, mapping m, object id, object file,
		       mapping defines)
{
  int t=time();
  if(!m->now)
  {
    if (m->hours) t+=((int)(m->hours))*3600;
    if (m->minutes) t+=((int)(m->minutes))*60;
    if (m->seconds) t+=((int)(m->seconds));
    if (m->days) t+=((int)(m->days))*(24*3600);
    if (m->weeks) t+=((int)(m->weeks))*(24*3600*7);
    if (m->months) t+=((int)(m->months))*(24*3600*30+37800); /* 30.46d */
    if (m->years) t+=((int)(m->years))*(3600*(24*365+6));   /* 365.25d */
    CACHE(max(t-time(),0));
  } else
    NOCACHE();

  add_header(_extra_heads, "Expires", t ? Caudium.HTTP.date(t) : "0");
  if(m->now)
    id->since=Caudium.HTTP.date(0);

  return "";
}

string tag_file(string tag, mapping m, object id)
{
  if(m->raw)
    return id->raw_url;
  else
    return id->not_query;
}

string tag_realfile(string tag, mapping m, object id)
{
  return id->realfile || "unknown";
}

string tag_vfs(string tag, mapping m, object id)
{
  return id->virtfile || "unknown";
}

string tag_language(string tag, mapping m, object id)
{
  NOCACHE();

  if(!id->misc["accept-language"])
    return "None";

  if(m->full)
    return _Roxen.html_encode_string(id->misc["accept-language"]*",");
  else
    return _Roxen.html_encode_string((id->misc["accept-language"][0]/";")[0]);
}

string tag_quote(string tagname, mapping m)
{
#if constant(set_start_quote)
  if(m->start && strlen(m->start))
    set_start_quote(m->start[0]);
  if(m->end && strlen(m->end))
    set_end_quote(m->end[0]);
#endif
  return "";
}

string tag_ximage(string tagname, mapping m, object id)
{
  string tmp="";
  if(m->src)
  {
    array a;
    string fname=id->conf->real_file(Caudium.fix_relative(m->src||"", id),id);

    if(fname)
    {
      object file=Stdio.File();
      if(file->open(fname,"r"))
      {
	array(int) xysize;
	if(xysize=Image.Dims.get(file))
	{
	  m->width=(string)xysize[0];
	  m->height=(string)xysize[1];
	}else{
	  m->err="Image.Dims failed";
	}
      }else{
	m->err="Failed to find file";
      }
    }else{
      m->err="Virtual path failed";
    }
  }
  return Caudium.make_tag("img", m);
}

mapping pr_sizes = ([]);
string get_pr_size(string size, string color)
{
  if(pr_sizes[size+color])
      return pr_sizes[size+color];

  mapping file = caudium->IFiles->get("image://power-" + size + "-" + color + ".gif");
  
  if(!file)
      return "NONEXISTENT COMBINATION";

  return pr_sizes[size+color] = sprintf("width=\"%d\" height=\"%d\"",
                                        file->width, file->height);
}

string tag_pr(string tagname, mapping m)
{
    string size = m->size || "small";
    string color = m->color || "red";    
    
    if(m->list)
    {
        string res = "<table><tr><td><b>size</b></td><td><b>color</b></td></tr>";
        foreach(sort(get_dir("caudium-images")), string f)
            if(sscanf(f, "power-%s", f))
                res += "<tr><td>"+replace(f-".gif","-","</td><td>")+"</tr>";
        return res + "</table>";
    }
    m_delete(m, "color");
    m_delete(m, "size");
    int w;

    if(get_pr_size(size,color)  == "NONEXISTENT COMBINATION")
        color = "red";
    sscanf(get_pr_size(size,color), "%*swidth=\"%d", w);
    if(w != 0)
        m->width = (string)w;
    sscanf(get_pr_size(size,color), "%*sheight=\"%d", w);
    if(w != 0)
        m->height = (string)w;

    m->src = "/(internal,image)/power-"+size+"-"+color;
    
    if(!m->alt)
        m->alt="Powered by Caudium Webserver";
    if(!m->border)
        m->border="0";
    
    m_delete(m, size);
    return ("<a href=\"http://caudium.net/\">"+Caudium.make_tag("img", m)+"</a>");
}

string tag_ipv6(string tagname, mapping m, object id)
{
    mapping   inetopt = 0;
    
    if (objectp(id->my_fd) && functionp(id->my_fd->get_inet_options))
	inetopt = id->my_fd->get_inet_options();

    report_notice(sprintf("inetopt == %O.\n", inetopt));
    report_notice(sprintf("my_fd addr == %O.\n", id->my_fd->query_socket_info()));
    if (inetopt && inetopt->curr_af == 10) { // Stdio.AF_INET6
       m->src = "/(internal,image)/ipv6.png";
       if(!m->alt)
          m->alt="IPv6 Connection!";
       if(!m->border)
          m->border="0";
	  
       string from = "";
       if (id->remoteaddr)
          from = sprintf("<br /><font size='-1'>Coming from <strong>%s</strong></font>",
	                 id->remoteaddr);
       return (Caudium.make_tag("img", m) + from);
    } else
       return "&nbsp;";
}

string tag_number(string t, mapping args)
{
  return language(args->language||args->lang, 
		  args->type||"number")( (int)args->num );
}

string tag_debug( string tag_name, mapping args, object id )
{
  if (args->off)
    id->misc->debug = 0;
  else if (args->toggle)
    id->misc->debug = !id->misc->debug;
  else
    id->misc->debug = 1;
  return "";
}

string tag_line( string t, mapping args, object id)
{
  return id->misc->line;
}

string tag_help(string t, mapping args, object id)
{
  array tags = sort(Array.filter(get_dir("modules/tags/doc/"),
			     lambda(string tag) {
			       if(tag[0] != '#' &&
				  tag[-1] != '~' &&
				  tag[0] != '.' &&
				  tag != "CVS")
				 return 1;
			     }));
  string help_for = args["for"] || id->variables->_r_t_h;

  if(!help_for)
  {
    string out = "<h3>Caudium Interactive RXML Help</h3>"
      "<b>Here is a list of all documented tags. Click on the name to "
      "receive more detailed information.</b><p>";
    array tag_links = ({});
    foreach(tags, string tag)
    {
      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>",
			      id->not_query, tag, tag) });
    }
    return out + String.implode_nicely(tag_links);
  } else {
    help_for = replace(help_for, ({"/","\\"}), ({"",""}));

    if(Stdio.file_size("modules/tags/doc/"+help_for) > 0) {
      string h =
	id->conf->parse_module->handle_help("modules/tags/doc/"+help_for,
					    help_for, args);
      return h;
    } else {
      return "<h3>No help available for "+help_for+".</h3>";
    }
  }
}

string tag_cache(string tag, mapping args, string contents, object id)
{
#define HASH(x) (x+id->not_query+id->query+id->realauth +id->conf->query("MyWorldLocation"))
  string key = Caudium.Crypto.hash_md5(contents);
  
  if(args->key)
    key += args->key;
  string parsed = cache_lookup("tag_cache", key);
  if(!parsed) {
    parsed = parse_rxml(contents, id);
    cache_set("tag_cache", key, parsed);
  }
  return parsed;
#undef HASH
}

string tag_fsize(string tag, mapping args, object id)
{
  catch {
    array s = id->conf->stat_file( Caudium.fix_relative( args->file, id ), id );
    if (s && (s[1]>= 0)) {
      return (string)s[1];
    }
  };
  if(string s=id->conf->try_get_file(Caudium.fix_relative(args->file, id), id ) )
    return (string)strlen(s);
}

//! tag: remoteip
//!  returns the IP number of the client accessing the page.
string tag_remoteip(string tag, mapping args, object id)
{
    return id->remoteaddr;
}

//! tag: pike_version
//!  returns the pike version used by the server. If no parameters are given
//!  returns the full Pike version string (as returned by version()).
//
//! attribute: [major]
//!  Returns the major Pike version number.
//
//! attribute: [minor]
//!  Returns the minor Pike version number.
//          
//! attribute: [release]
//!  Returns teh release Pike version number.
//          
string tag_pikeversion(string tag, mapping args, object id)
{
    if (args->major)
        return (string)__REAL_MAJOR__;

    if (args->minor)
        return (string)__REAL_MINOR__;

    if (args->release)
        return (string)__REAL_BUILD__;

    return version();
}



mapping query_tag_callers()
{
   return ([ 
            "modified":tag_modified,
            "pr":tag_pr,
            "ipv6":tag_ipv6,
            "remoteip":tag_remoteip,
            "pike_version":tag_pikeversion,
            "pike-version":tag_pikeversion,
	    "use":tag_use,
	    "set-max-cache":lambda(string t, mapping m, object id) { 
			      id->misc->cacheable = (int)m->time; 
			    },
	    "number":tag_number,
	    "imgs":tag_ximage,
	    "ximg":tag_ximage,
	    "version":tag_version,
	    "set":tag_set,
	    "dec":tag_dec,
	    "inc":tag_inc,
	    "dice":tag_dice,
	    "append":tag_append,
	    "unset":tag_set,
	    "undefine":tag_undefine,
 	    "set_cookie":tag_add_cookie,
 	    "remove_cookie":tag_remove_cookie,
	    "clientname":tag_clientname,
	    "configurl":tag_configurl,
	    "configimage":tag_configimage,
	    "date":tag_date,
	    "referer":tag_referrer,
	    "referrer":tag_referrer,
	    "accept-language":tag_language,
	    "insert":tag_insert,
	    "return":tag_return,
	    "httperror":tag_error,
	    "file":tag_file,
	    "realfile":tag_realfile,
	    "vfs":tag_vfs,
	    "fsize":tag_fsize,
	    "header":tag_header,
	    "redirect":tag_redirect,
	    "auth-required":tag_auth_required,
	    "expire-time":tag_expire_time,
	    "expire_time":tag_expire_time, /* Someone documented both */
	    "signature":tag_signature,
	    "user":tag_user,
	    "line":tag_line,
 	    "quote":tag_quote,
	    "true":tag_true,	// Used internally
	    "false":tag_false,	// by <if> and <else>
	    "echo":tag_echo,           /* These commands are */
	    "debug" : tag_debug,
	    "help": tag_help
   ]);
}


string tag_source(string tag, mapping m, string s, object id,object file)
{
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return ("<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
	  +"</pre>"+sep+s);
}

string tag_source2(string tag, mapping m, string s, object id,object file)
{
  if(!m["magic"])
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"{","}","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "{", "}", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
  else 
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
}

string tag_autoformat(string tag, mapping m, string s, object id,object file)
{
  s-="\r";
  if(m->p)
    s = replace(s, "\n\n", "<p>");
  else if(!m->nobr)
    s = replace(s, "\n", "<br>\n");
  return s;
}

string tag_smallcaps(string t, mapping m, string s)
{
    string build = "";
    string uc = upper_case(s);
    int end = sizeof(s);
    int last_cut = 0;
    int i = 0;
    string bigsize = "0";
    string smallsize = "-1";

    if (m->size) {
        bigsize = m->size;
        if ((int)bigsize && (bigsize[0..0] == "+"))
            smallsize = "+"+((int)bigsize-1);
        else
            smallsize = ""+((int)bigsize-1);
    }
    if (m->small) { smallsize = m->small; }

    string switch_to_small =
        ((int)bigsize  ? "</font>" : "") +
        ((int)smallsize ? ("<font size=\""+smallsize+"\">") : "");

    string switch_to_big =
        ((int)smallsize ? "</font>" : "") +   
        ((int)bigsize ? ("<font size=\""+bigsize+"\">") : "");

    if ((int)bigsize) build = "<font size=\""+bigsize+"\">";

    while(i < end) {
        if (s[i] == '<') {
            while ((i < end) && (s[i] != '>')) i++;
            build += s[last_cut..(i-1)];
            last_cut = i+1;
        } else if (s[i] == '&') {
            while ((i < end) && (s[i] != ';') && (s[i] != ' ') && (s[i] != '\t') && (s[i] != '\n')) i++;
            build += s[last_cut..(i-1)];
        } else if (s[i] != uc[i]) {
            while ((i < end) && (s[i] != uc[i])) i++;
            build += switch_to_small+
                uc[last_cut..(i-1)]+
                switch_to_big;
        } else {
            while ((i < end) &&
                   (s[i] == uc[i]) &&
                   (s[i] != '<') && (s[i] != '&')) i++;
            build += s[last_cut..(i-1)];
        }
        last_cut = i;
    }

    if ((int)bigsize) build += "</font>";
    return build;
}

string tag_random(string tag, mapping m, string s)
{
  mixed q;
  if(!(q=m->separator || m->sep))
    return (q=s/"\n")[random(sizeof(q))];
  else
    return (q=s/q)[random(sizeof(q))];
}

//! tag: dice
//!  Simulates a D&amp;D style dice algorithm. Useful for generating
//!  random numbers.
//! attribute: value
//!  Describes the dices. A six sided dice is called 'D6' or '1D6', while
//!  two eight sided dices is called '2D8' or 'D8+D8'. Constants may also
//!  be used, so that a random number between 10 and 20 could be written
//!  as 'D9+10' (excluding 10 and 20, including 10 and 20 would be 'D11+9').
//!  The character 'T' may be used instead of 'D'. The default value is D6.
//! attribute: variable
//!  Store the result in this variable.
//! attribute: [scope]
//!  The scope of the variable.

array(string) tag_dice(string tag, mapping args,object id)
{
  int value;
  NOCACHE();
  if(!args->type) args->type="D6";
  else            args->type = replace( args->type, "T", "D" );
  args->type=replace(args->type, "-", "+-");
  foreach(args->type/"+", string dice) {
    if(has_value(dice, "D")) {
      if(dice[0]=='D')
	value += random((int)dice[1..])+1;
      else {
	array(int) x=(array(int))(dice/"D");
	if(sizeof(x)!=2)
	  return ({ "\n<b>dice: Malformed dice type '"+dice+"'.</b>\n" });
	value+=x[0]*(random(x[1])+1);
      }
    }
    else
      value += (int)dice;
  }
  
  if(args->variable)
    set_scope_var(args->variable, args->scope, value, id);
  else
    return ({ (string)value });
}

string tag_right(string t, mapping m, string s, object id)
{
  if(m->help) 
    return "DEPRECATED: compatibility alias for &lt;p align=right&gt;";
  if(id->supports->alignright)
    return "<p align=right>"+s+"</p>";
  return "<table width=100%><tr><td align=right>"+s+"</td></tr></table>";
}

array(string) tag_formoutput(string tag_name, mapping args, string contents,
			     object id, mapping defines)
{
  return ({do_output_tag( args, ({ id->variables }), contents, id )});
}

string tag_gauge(string tag, mapping args, string contents, 
		 object id, object f, mapping defines)
{
  NOCACHE();

#if constant(gethrtime)
  int t = gethrtime();
  contents = parse_rxml( contents, id );
  t = gethrtime()-t;
#else
  int t = gauge {
    contents = parse_rxml( contents, id );
  } * 1000;
#endif
  string define = args->define?args->define:"gauge";

  defines[define+"_time"] = sprintf("%3.6f", t/1000000.0);
  defines[define+"_result"] = contents;

  if(args->silent) return "";
  if(args->timeonly) return sprintf("%3.6f", t/1000000.0);
  if(args->resultonly) return contents;
  return ("<br><font size=-1><b>Time: "+
	  sprintf("%3.6f", t/1000000.0)+
	  " seconds</b></font><br>"+contents);
} 

// Changes the parsing order by first parsing it's contents and then
// morphing itself into another tag that gets parsed. Makes it possible to
// use, for example, tablify together with sqloutput.
string tag_preparse( string tag_name, mapping args, string contents,
		     object id )
{
  return Caudium.make_container( args->tag, args - ([ "tag" : 1 ]),
			 parse_rxml( contents, id ) );
}

// Removes empty lines
mixed tag_trimlines( string tag_name, mapping args, string contents,
		      object id )
{
  contents = replace(parse_rxml( contents, id ),
		     ({ "\r\n","\r" }), ({"\n", "\n"}));
  return ({ (contents / "\n" - ({ "" })) * "\n" });
}

// Internal method for the default tag
private mixed tag_input( string tag_name, mapping args, string name,
			  multiset (string) value )
{
  if (name && args->name != name)
    return 0;
  if (args->type == "checkbox" || args->type == "radio")
    if (args->value)
      if (value[ args->value ])
	if (args->checked)
	  return 0;
	else
	  args->checked = "checked";
      else
	if (args->checked)
	  m_delete( args, "checked" );
	else
	  return 0;
    else
      if (value[ "on" ])
	if (args->checked)
	  return 0;
	else
	  args->checked = "checked";
      else
	if (args->checked)
	  m_delete( args, "checked" );
	else
	  return 0;
  else
    return 0;
  return ({ Caudium.make_tag( tag_name, args ) });
}

private string remove_leading_trailing_ws( string str )
{
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str ); 
  sscanf( str, "%*[\t\n\r ]%s", str ); str = reverse( str );
  return str;
}

// Internal method for the default tag
private mixed tag_option( string tag_name, mapping args, string contents,
				  multiset (string) value )
{
  if (args->value)
    if (value[ args->value ])
      if (args->selected)
	return 0;
      else
	args->selected = "selected";
    else
      return 0;
  else
    if (value[ remove_leading_trailing_ws( contents ) ])
      if (args->selected)
	return 0;
      else
	args->selected = "selected";
    else
      return 0;
  return ({Caudium.make_container( tag_name, args, contents )});
}

// Internal method for the default tag
private mixed tag_select( string tag_name, mapping args, string contents,
			   string name, multiset (string) value )
{
  array (string) tmp;
  int c;
  
  if (name && args->name != name)
    return 0;
  tmp = contents / "<option";
  for (c=1; c < sizeof( tmp ); c++)
    if (sizeof( tmp[c] / "</option>" ) == 1)
      tmp[c] += "</option>";
  contents = tmp * "<option";
  mapping m = ([ "option" : tag_option ]);
  contents = Caudium.parse_html( contents, ([ ]), m, value );
  return ({ Caudium.make_container( tag_name, args, contents ) });
}

// The default tag is used to give default values to forms elements,
// without any fuss.
string tag_default( string tag_name, mapping args, string contents,
		    object id, object f, mapping defines, object fd )
{
  string multi_separator = args->multi_separator || "\000";

  contents = parse_rxml( contents, id );
  if (args->value)
    return Caudium.parse_html( contents, ([ "input" : tag_input ]),
		       ([ "select" : tag_select ]),
		       args->name, mkmultiset( args->value
					       / multi_separator ) );
  else if (args->variable && id->variables[ args->variable ])
    return Caudium.parse_html( contents, ([ "input" : tag_input ]),
		       ([ "select" : tag_select ]),
		       args->name,
		       mkmultiset( id->variables[ args->variable ]
				   / multi_separator ) );
  else    
    return contents;
}

string|array(string) tag_noparse(string t, mapping m, string c, object id)
{
  if(m->until && (max((int)m->until, 1)) < id->misc->parse_level)
    return ({ "<noparse until='"+m->until+"'>"+c+"</noparse>" });
  return ({ c });
}

string tag_nooutput(string t, mapping m, string c, object id)
{
  parse_rxml(c, id);
  return "";
}

string tag_sort(string t, mapping m, string c, object id)
{
  if(!m->separator)
    m->separator = "\n";

  string pre="", post="";
  array lines = c/m->separator;

  while(lines[0] == "")
  {
    pre += m->separator;
    lines = lines[1..];
  }

  while(lines[-1] == "")
  {
    post += m->separator;
    lines = lines[..sizeof(lines)-2];
  }

  return pre + sort(lines)*m->separator + post;
}

//! container: strlen
//!  Returns the length of the contents. 

array(string) tag_strlen(string t, mapping m, string c, object id)
{
  return ({ (string)strlen(c) });
}

string tag_case(string t, mapping m, string c, object id)
{
  if(m->lower)
    c = lower_case(c);
  if(m->upper)
    c = upper_case(c);
  if(m->capitalize)
    c = capitalize(c);
  return c;
}

string tag_recursive_output (string tagname, mapping args, string contents,
			     object id, object file, mapping defines)
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit) {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->multisep || ",") : ({});
    outside = args->outside ? args->outside / (args->multisep || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      return "\n<b>'inside' and 'outside' replacement sequences "
	"aren't of same length</b>\n";
  }

  if (limit <= 0) return contents;

  int save_limit = id->misc->recout_limit;
  string save_inside = id->misc->recout_inside, save_outside = id->misc->recout_outside;

  id->misc->recout_limit = limit;
  id->misc->recout_inside = inside;
  id->misc->recout_outside = outside;

  string res = parse_rxml (
    Caudium.parse_html (
      contents,
      (["recurse": lambda (string t, mapping a, string c) {return ({c});}]), ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) + "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return res;
}

class Tracer
{
  inherit "caudiumlib";
  string resolv="<ol>";
  int level;

  mapping et = ([]);
#if constant(gethrvtime)
  mapping et2 = ([]);
#endif

  string module_name(function|object m)
  {
    if(!m)return "";
    if(functionp(m)) m = function_object(m);
    return (strlen(m->query("_name")) ? m->query("_name") :
	    (m->query_name&&m->query_name()&&strlen(m->query_name()))?
	    m->query_name():m->register_module()[1]);
  }

  void trace_enter_ol(string type, function|object module)
  {
    level++; 

    string efont="", font="";
    if(level>2) {efont="</font>";font="<font size=-1>";} 
    resolv += (font+"<b><li></b> "+type+" "+module_name(module)+"<ol>"+efont);
#if constant(gethrvtime)
    et2[level] = gethrvtime();
#endif
#if constant(gethrtime)
    et[level] = gethrtime();
#endif
  }

  void trace_leave_ol(string desc)
  {
#if constant(gethrtime)
    int delay = gethrtime()-et[level];
#endif
#if constant(gethrvtime)
    int delay2 = gethrvtime()-et2[level];
#endif
    level--;
    string efont="", font="";
    if(level>1) {efont="</font>";font="<font size=-1>";} 
    resolv += (font+"</ol>"+
#if constant(gethrtime)
	       "Time: "+sprintf("%.5f",delay/1000000.0)+
#endif
#if constant(gethrvtime)
	       " (CPU = "+sprintf("%.2f)", delay2/1000000.0)+
#endif /* constant(gethrvtime) */
	       "<br>"+_Roxen.html_encode_string(desc)+efont)+"<p>";

  }

  string res()
  {
    while(level>0) trace_leave_ol("");
    return resolv+"</ol>";
  }
  
}

class SumTracer
{
  inherit Tracer;
#if 0
  mapping levels = ([]);
  mapping sum = ([]);
  void trace_enter_ol(string type, function|object module)
  {
    resolv="";
    ::trace_enter_ol();
    levels[level] = type+" "+module;
  }

  void trace_leave_ol(string mess)
  {
    string t = levels[level--];
#if constant(gethrtime)
    int delay = gethrtime()-et[type+" "+module_name(module)];
#endif
#if constant(gethrvtime)
    int delay2 = +gethrvtime()-et2[t];
#endif
    t+=_Roxen.html_encode_string(mess);
    if( sum[ t ] ) {
      sum[ t ][ 0 ] += delay;
#if constant(gethrvtime)
      sum[ t ][ 1 ] += delay2;
#endif
    } else {
      sum[ t ] = ({ delay, 
#if constant(gethrvtime)
		    delay2 
#endif
      });
    }
  }

  string res()
  {
    foreach(indices());
  }
#endif
}

array(string) tag_trace(string tag, mapping args, string c , object id)
{
  NOCACHE();
  object t;
  if(args->summary)
    t = SumTracer();
  else
    t = Tracer();
  function a = id->misc->trace_enter;
  function b = id->misc->trace_leave;
  id->misc->trace_enter = t->trace_enter_ol;
  id->misc->trace_leave = t->trace_leave_ol;
  t->trace_enter_ol( "tag &lt;trace&gt;", tag_trace);
  id->misc->parse_level --;  
  string r = parse_rxml(c, id);
  id->misc->parse_level ++;  
  id->misc->trace_enter = a;
  id->misc->trace_leave = b;
  return ({ r + "<h1>Trace report</h1>"+t->res()+"</ol>" });
}

string tag_for(string t, mapping args, string c, object id)
{
  string v = args->variable;
  int from = (int)args->from;
  int to = (int)args->to;
  int step = (int)args->step||1;
  
  m_delete(args, "from");
  m_delete(args, "to");
  m_delete(args, "variable");
  string res="";
  if(step<0)
    for(int i=from; i>=to; i+=step)
      res += "<set variable="+v+" value="+i+">"+c;
  else
    for(int i=from; i<=to; i+=step)
      res += "<set variable="+v+" value="+i+">"+c;
  return res;
}

/*
 * This tag controls the scopes usage from within RXML. It's a container
 * which takes the following attributes:
 *
 *   cond   - whether the scope status is conditional or not
 *   on     - whether the scope is on or off
 *   global - should the change be global or just for this container
 *
 * All attributes take the following values for "true":
 *
 *   yes
 *   1
 *   true
 *   on
 *
 * Any other value is considered "false" and turns the corresponding switch
 * off.
 */
string tag_scopecontrol(string t, mapping args, string c, object id)
{
    int    cond = 0, on = 0, globl = 0;

    if (args->cond) {
        switch(lower_case(args->cond)) {
            case "yes":
            case "on":
            case "1":
            case "true":
                cond = 1;
                break;
        }
        m_delete(args, "cond");
    }

    if (args->on) {
        switch(lower_case(args->on)) {
            case "yes":
            case "on":
            case "1":
            case "true":
                on = 1;
                break;
        }
        m_delete(args, "on");
    }

    if (args["global"]) {
        switch(lower_case(args["global"])) {
            case "yes":
            case "on":
            case "1":
            case "true":
                globl = 1;
                break;
        }
        m_delete(args, "global");
    }

    int usval = 0;
    int oldus = id->misc->_use_scopes;
    int oldss = id->misc->_scope_status;
    
    if (on)
        usval |= 0x01;
    if (cond)
        usval |= 0x02;

    id->misc->_use_scopes = usval;
    id->misc->_scope_status = usval & 0x01;
    
    string ret = parse_rxml(c, id);

    if (!globl) {
        id->misc->_use_scopes = oldus;
        id->misc->_scope_status = oldss;
    }

    return ret;
}

//! container: urldecode
//!  Decode the URL-encoded contents of the container
string tag_urldecode (string tagname, mapping args, string contents,
                      object id, object file, mapping defines)
{
    if (!contents)
        return "";

    return Caudium.HTTP.decode_url(contents);
}

mapping query_pi_callers() {
  return ([ "?comment": "" ]);
}

mapping query_container_callers()
{
  return ([
           "comment":lambda(){ return ""; },
           "crypt":lambda(string t, mapping m, string c){
        	     if(m->compare)
        	       return (string)crypt(c,m->compare);
        	     else
        	       return crypt(c);
        	   },
           "cache":tag_cache,
           "for":tag_for,
           "trace":tag_trace,
           "urldecode":tag_urldecode,
           "cset":lambda(string t, mapping m, string c, object id)
        	  { return tag_set("set",m+([ "value":Protocols.HTTP.unentity(c) ]),
        		    id); },
           "source":tag_source,
           "case":tag_case,
           "noparse":tag_noparse,
           "catch":lambda(string t, mapping m, string c, object id) {
        	     string r;
        	     array e = catch(r=parse_rxml(c, id));
        	     if(e) return e[0];
        	     return r;
        	   },
           "throw":lambda(string t, mapping m, string c) {
	             if(c[-1] != '\n') c+="\n";
	             throw( ({ c, backtrace() }) );
        	   },
           "nooutput":tag_nooutput,
           "sort":tag_sort,
           "doc":tag_source2,
           "autoformat":tag_autoformat,
           "random":tag_random,
           "define":tag_define,
           "scope":tag_scope,
           "right":tag_right,
           "client":tag_client,
           "if":tag_if,
           "elif":tag_elseif,
           "elseif":tag_elseif,
           "else":tag_else,
           "then":tag_then,
           "gauge":tag_gauge,
           "strlen":tag_strlen,
           "allow":tag_if,
           "prestate":tag_prestate,
           "apre":tag_aprestate,
	   "add_pre_state":tag_addprestate,
           "aconf":tag_aconfig,
           "aconfig":tag_aconfig,
           "deny":tag_deny,
           "smallcaps":tag_smallcaps,
           "formoutput":tag_formoutput,
           "preparse" : tag_preparse,
           "trimlines" : tag_trimlines,
           "default" : tag_default,
           "recursive-output": tag_recursive_output,
           "scopecontrol": tag_scopecontrol,
        ]);
}


int api_query_num(object id, string f, int|void i)
{
  NOCACHE();
  return 0;
  // FIXME: Is this really usefull ????
#if 0
  return query_num(f, i);
#endif
}

string api_parse_rxml(object id, string r)
{
  return parse_rxml( r, id );
}


string api_tagtime(object id, int ti, string t, string l)
{
  mapping m = ([ "type":t, "lang":l ]);
  NOCACHE();
  return tagtime( ti, m );
}

string api_relative(object id, string path)
{
  return Caudium.fix_relative( path, id );
}

string api_set(object id, string what, string to)
{
  tag_set("set",(["variable":what, "value":to]) , id);
  return ([])[0];
}

string api_define(object id, string what, string to)
{
  tag_define("define",(["name":what]), to, id,id,id->misc->defines);
  return ([])[0];
}


string api_query_define(object id, string what)
{
  return id->misc->defines[what];
}

string api_query_variable(object id, string what)
{
  return id->variables[what];
}

string api_read_file(object id, string f)
{
  mapping m = ([ "file":f ]);
  return tag_insert("insert", m, id, id, id->misc->defines);
}

string api_query_cookie(object id, string f)
{
  mapping m = ([ "cookie":f ]);
  return tag_insert("insert", m, id, id, id->misc->defines);
}

string api_query_modified(object id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id, id->misc->defines);
}

void api_add_header(object id, string h, string v)
{
  add_header(id->misc->defines[" _extra_heads"], h, v);
}

void api_set_cookie(object id, string c, string v)
{
  tag_add_cookie( "add_cookie", (["name":c,"persistent":1,"value":v]),
		  id, id, id->misc->defines);
}

void api_remove_cookie(object id, string c, string v)
{
  tag_remove_cookie( "remove_cookie", (["name":c,"value":v]),
		     id, id, id->misc->defines);
}

int api_prestate(object id, string p)
{
  return id->prestate[p];
}

int api_set_prestate(object id, string p)
{
  return id->prestate[p]=1;
}

int api_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p];
}

int api_set_supports(object id, string p)
{
  NOCACHE();
  return id->supports[p]=1;
}


int api_set_return_code(object id, int c, string p)
{
  tag_return("return", ([ "code":c, "text":p ]), id,id,id->misc->defines);
  return ([])[0];
}

string api_get_referrer(object id)
{
  NOCACHE();
  if(id->referrer) return id->referrer;
  return ([])[0];
}

string api_html_quote(object id, string what)
{
  return replace(what, ({ "<", ">", "&" }),({"&lt;", "&gt;", "&amp;" }));
}

constant replace_from = indices( Caudium.Const.iso88591 )+ ({"&lt;","&gt;", "&amp;","&#022;"});
constant replace_to   = values( Caudium.Const.iso88591 )+ ({"<",">", "&","\""});

string api_html_dequote(object id, string what)
{
  return replace(what, replace_from, replace_to);
}

string api_html_quote_attr(object id, string value)
{
  return sprintf("\"%s\"", replace(value, "\"", "&quot;"));
}

void add_api_function( string name, function f, void|array(string) types)
{
  if(this_object()["_api_functions"])
    this_object()["_api_functions"][name] = ({ f, types });
}

void define_API_functions()
{
// FIXME: ???? What as these for ???
#if 0
  add_api_function("accessed", api_query_num, ({ "string", 0,"int" }));
#endif
  add_api_function("parse_rxml", api_parse_rxml, ({ "string" }));
  add_api_function("tag_time", api_tagtime, ({ "int", 0,"string", "string" }));
  add_api_function("fix_relative", api_relative, ({ "string" }));
  add_api_function("set_variable", api_set, ({ "string", "string" }));
  add_api_function("define", api_define, ({ "string", "string" }));

  add_api_function("query_define", api_query_define, ({ "string", }));
  add_api_function("query_variable", api_query_variable, ({ "string", }));
  add_api_function("query_cookie", api_query_cookie, ({ "string", }));
  add_api_function("query_modified", api_query_modified, ({ "string", }));

  add_api_function("read_file", api_read_file, ({ "string", 0,"int"}));
  add_api_function("add_header", api_add_header, ({"string", "string"}));
  add_api_function("add_cookie", api_set_cookie, ({"string", "string"}));
  add_api_function("remove_cookie", api_remove_cookie, ({"string", "string"}));

  add_api_function("html_quote", api_html_quote, ({"string"}));
  add_api_function("html_dequote", api_html_dequote, ({"string"}));
  add_api_function("html_quote_attr", api_html_quote_attr, ({"string"}));

  add_api_function("prestate", api_prestate, ({"string"}));
  add_api_function("set_prestate", api_set_prestate, ({"string"}));

  add_api_function("supports", api_supports, ({"string"}));
  add_api_function("set_supports", api_set_supports, ({"string"}));

  add_api_function("set_return_code", api_set_return_code, ({ "int", 0, "string" }));
  add_api_function("query_referer",  api_get_referrer,
		   ({ "int", 0, "string" }));
  add_api_function("query_referrer", api_get_referrer,
		   ({ "int", 0, "string" }));
  add_api_function("roxen_version", tag_version, ({}));
  add_api_function("config_url", tag_configurl, ({}));
}

int may_disable()  { return 0; }

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: compat_if
//! If set the &lt;if&gt;-tag will work in compatibility mode.
//!This affects the behaviour when used together with the &lt;else&gt;-tag.
//!
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Compatibility with old &lt;if&gt;
//
//! defvar: max_insert_depth
//! Max level of recursion when using &lt;insert file="..."&gt;
//!  type: TYPE_INT
//!  name: Max file inclusion recursion depth
//
