/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
 *
 */

//
//! module: Main RXML parser
//!  This module makes it possible for other modules to add
//!  new tags to the RXML parsing, in addition to the
//!  default ones.  The default error message (no such resource)
//!  use this parser, so if you do not want it, you will also
//!  have to change the error message.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FILE_EXTENSION | MODULE_MAIN_PARSER | MODULE_PARSER | MODULE_PROVIDER
//! cvs_version: $Id$
//

/*
 * The old-style RXML parser. If this module is not added to a configuration,
 * no RXML parsing will be done at all.
 *
 * The only thing located in this file is the main parser.
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <config.h>
#include <module.h>

inherit "module";
inherit "caudiumlib";

string date_doc=Stdio.read_bytes("modules/tags/doc/date_doc");
constant language = caudium->language;

constant module_type = MODULE_FILE_EXTENSION | MODULE_MAIN_PARSER | MODULE_PARSER | MODULE_PROVIDER;
constant module_name = "Main RXML parser";
constant module_doc  =
"This module makes it possible for other modules to add "
"new tags to the RXML parsing, in addition to the "
"default ones.  The default error message (no such resource) "
"use this parser, so if you do not want it, you will also "
"have to change the error message.";
constant module_unique = 1;

int cnum=0;
mapping scopes;
mapping (string:mixed) tag_callers, container_callers;
mapping (string:function) real_tag_callers, real_container_callers;
int bytes;
array (object) parse_modules = ({ });


#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

// Configuration interface fluff.
string comment()
{
  return query("toparse")*", ";
}

string status()
{
  return (bytes/1024) + " Kb parsed.";
}

void create()
{
  defvar("toparse", ({ "rxml", "html", "htm" }), "Extensions to parse", 
	 TYPE_STRING_LIST, "Parse all files ending with these extensions. "
	 "Note: This module must be reloaded for a change here to take "
	 "effect.");

  defvar("parse_exec", 0, "Require exec bit on files for parsing",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files has to have the execute bit (any of them) set "
	 "in order for them to be parsed by this module. The exec bit "
	 "is the one that is set by 'chmod +x filename'");
	 
  defvar("no_parse_exec", 0, "Don't Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, no files with the exec bit set will be parsed. This is the "
	 "reverse of the 'Require exec bit on files for parsing' flag. "
	 "It is not very useful to set both variables.");
	 
  defvar("max_parse", 200, "Maximum file size", TYPE_INT|VAR_MORE,
	 "Maximum file size to parse, in Kilo Bytes.");
}

void start(int cnt, object conf)
{
  module_dependencies(conf, ({ "rxmltags", "corescopes" }));
  build_callers();
}

array(string) query_file_extensions() 
{ 
  return query("toparse");
}


#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

string parse_doc(string doc, string tag)
{
  return replace(doc, ({"{","}","<tag>","<roxen-languages>"}),
		 ({"&lt;", "&gt;", tag, 
	String.implode_nicely(sort(indices(caudium->languages)), "and")}));
}

string handle_help(string file, string tag, mapping args)
{
  return parse_doc(replace(Stdio.read_bytes(file),
			   "<date-attributes>",date_doc),tag);
}



string call_user_tag(string tag, mapping args, int line, object id)
{
  id->misc->line = line;
  args = id->misc->defaults[tag]|args;
  if(!id->misc->up_args) id->misc->up_args = ([]);
  TRACE_ENTER("user defined tag &lt;"+tag+"&gt;", call_user_tag);
  array replace_from = ({"#args#"})+
    Array.map(indices(args)+indices(id->misc->up_args),
	      lambda(string q){return "&"+q+";";});
  array replace_to = (({make_tag_attributes( args + id->misc->up_args ) })+
		      values(args)+values(id->misc->up_args));
  foreach(indices(args), string a)
  {
    id->misc->up_args["::"+a]=args[a];
    id->misc->up_args[tag+"::"+a]=args[a];
  }
  string r = replace(id->misc->tags[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  return r;
}

string call_user_container(string tag, mapping args, string contents, int line,
			   object id)
{
  id->misc->line = line;
  args = id->misc->defaults[tag]|args;
  if(!id->misc->up_args) id->misc->up_args = ([]);
  if(args->preparse
     && (args->preparse=="preparse" || (int)args->preparse))
    contents = parse_rxml(contents, id);
  if(args->trimwhites) {
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
  }
  TRACE_ENTER("user defined container &lt;"+tag+"&gt", call_user_container);
  array replace_from = ({"#args#", "<contents>"})+
    Array.map(indices(args),
	      lambda(string q){return "&"+q+";";});
  array replace_to = (({make_tag_attributes( args  ),
			contents })+
		      values(args));
  string r = replace(id->misc->containers[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  return r;
}

string call_tag(string tag, mapping args, int line, 
		object id, object file, mapping defines,
		object client)
{
  string|function rf = real_tag_callers[tag];
  id->misc->line = (string)line;
  if(args->help && Stdio.file_size("modules/tags/doc/"+tag) > 0)
  {
    TRACE_ENTER("tag &lt;"+tag+" help&gt", rf);
    string h = handle_help("modules/tags/doc/"+tag, tag, args);
    TRACE_LEAVE("");
    return h;
  }
  if(stringp(rf)) return rf;

  TRACE_ENTER("tag &lt;" + tag + "&gt;", rf);
#ifdef MODULE_LEVEL_SECURITY
  if(id->conf->check_security(rf, id, id->misc->seclevel))
  {
    TRACE_LEAVE("Access denied");
    return 0;
  }
#endif
  mixed result=rf(tag,args,id,file,defines,client);
  TRACE_LEAVE("");
  return result;
}

string query_provides() { return "rxml:core"; }

array(string)|string call_container(string tag, mapping args, string contents,
				    int line, object id, object file,
				    mapping defines, object client)
{
  string|function rf;
  id->misc->line = (string)line;

  rf = real_container_callers[tag];
  if(args->help && Stdio.file_size("modules/tags/doc/"+tag) > 0)
  {
    TRACE_ENTER("container &lt;"+tag+" help&gt", rf);
    string h = handle_help("modules/tags/doc/"+tag, tag, args)+contents;
    TRACE_LEAVE("");
    return h;
  }
  if(stringp(rf)) return rf;
  TRACE_ENTER("container &lt;"+tag+"&gt", rf);
  if(args->preparse) contents = parse_rxml(contents, id);
  if(args->trimwhites) {
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
  }
#ifdef MODULE_LEVEL_SECURITY
  if(id->conf->check_security(rf, id, id->misc->seclevel))
  {
    TRACE_LEAVE("Access denied");
    return 0;
  }
#endif
  mixed result=rf(tag,args,contents,id,file,defines,client);
  TRACE_LEAVE("");
  if(args->noparse && stringp(result)) return ({ result });
  return result;
}

string do_parse(string to_parse, object id, object file, mapping defines,
		object my_fd)
{
  if(!id->misc->scopes)
    id->misc->scopes = mkmapping(indices(scopes), values(scopes)->clone());
  if(!id->misc->_tags) {
    id->misc->_tags = copy_value(tag_callers);
    id->misc->tags = ([]);
  }
  if(!id->misc->_containers) {
    id->misc->_containers = copy_value(container_callers);
    id->misc->containers = ([]);
  }
  id->misc->parse_level ++;

  to_parse =
    parse_html_lines(to_parse, id->misc->_tags, id->misc->_containers,
		     id, file, defines, my_fd);
  id->misc->parse_level --;
  return to_parse;
}

string tag_list_tags( string t, mapping args, object id, object f )
{
  int verbose;
  string res="";
  if(args->verbose) verbose = 1;

  res += ("<b><font size=+1>Listing of all tags: </b></font><p>");
  foreach(sort(indices(tag_callers)), string tag)
  {
    res += "  <a name=\""+replace(tag, "#", ".")+"\"><a href=\""+id->not_query+"?verbose="+replace(tag, "#","%23")+"#"+replace(tag, "#", ".")+"\">&lt;"+tag+"&gt;</a></a><br>";
    if(verbose || id->variables->verbose == tag)
    {
      res += "<blockquote><table><tr><td>";
      string tr;
      catch(tr = call_tag(tag, (["help":"help"]), 
			  id->misc->line,
			  id, f, id->misc->defines, id->my_fd ));
      if(tr) res += tr; else res += "no help";
      res += "</td></tr></table></blockquote>";
    }
  }
  
  res += ("<p><b><font size=+1>Listing of all containers: </b></font><p>");
  foreach(sort(indices(container_callers)), string tag)
  {
    res += " <a name=\""+replace(tag, "#", ".")+"\"><a href=\""+id->not_query+"?verbose="+replace(tag, "#", "%23")+"#"+replace(tag,"#",".")+"\">&lt;"+tag+"&gt;&lt;/"+tag+"&gt;</a></a><br>";
    if(verbose || id->variables->verbose == tag)
    {
      res += "<blockquote><table><tr><td>";
      string tr;
      catch(tr=call_container(tag, (["help":"help"]), "",
			      id->misc->line,
			      id,f, id->misc->defines, id->my_fd ));
      if(tr) res += tr; else res += "no help";
      res += "</td></tr></table></blockquote>";
    }
  }
  return res;
}

mapping handle_file_extension( object file, string e, object id)
{
  mixed err;
  string to_parse;
  mapping defines = id->misc->defines || ([]);

  id->misc->defines = defines;

  if(!defines->sizefmt)
  {
#if constant(set_start_quote)
    set_start_quote(set_end_quote(0));
#endif
    defines->sizefmt = "abbrev"; 

    _error=200;
    _extra_heads=([ ]);
    if(id->misc->stat)
      _stat=id->misc->stat;
    else
      _stat=file->stat();
    if(_stat[1] > (QUERY(max_parse)*1024))
      return 0; // To large for me..
  }

  if(QUERY(parse_exec) &&   !(_stat[0] & 07111)) return 0;
  if(QUERY(no_parse_exec) && (_stat[0] & 07111)) return 0;

  if(err=catch(to_parse = do_parse(file->read(),id,file,defines,id->my_fd )))
  {
    file->close();
    destruct(file);
    throw(err);
  }

  bytes += strlen(to_parse);

  if(file) {
    catch(file->close());
    destruct(file);
  }
  //   report_debug(sprintf("%O", id->misc->defines));
  return (["data":to_parse,
	   "type":(id->misc->_content_type || "text/html"), 
	   "stat":_stat,
	   "is_dynamic": 1,
	   "error":_error,
	   "rettext":_rettext,
	   "extra_heads":_extra_heads,
//	   "expires": time(1) - 100,
	   ]);
}
void build_callers()
{
   object o;
   tag_callers=([]);
   container_callers=([]);
   real_tag_callers=([]);
   real_container_callers=([]);
   scopes = ([]);

   parse_modules -= ({ 0 });

   foreach (parse_modules,o)
   {
     array|mapping foo;
     if(o->query_tag_callers)
     {
       foo=o->query_tag_callers();
       if(mappingp(foo)) {
	 real_tag_callers += foo;
       }
     }
     
     if(o->query_container_callers)
     {
       foo=o->query_container_callers();
       if(mappingp(foo)) {
	 real_container_callers += foo;
       }
     }
     if(o->query_scopes) {
       foo = o->query_scopes();
       if(arrayp(foo)) {
	 foreach(foo, mixed value) {
	   if(objectp(value) && functionp(value->query_name))
	     scopes[value->query_name()] = value;
	 }
       }
     }
   }
   tag_callers = mkmapping(indices(real_tag_callers),
			   allocate(sizeof(real_tag_callers), call_tag));
   container_callers = mkmapping(indices(real_container_callers),
				 allocate(sizeof(real_container_callers),
					  call_container));
}

void add_parse_module(object o)
{
  parse_modules |= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,1);
}

void remove_parse_module(object o)
{
  parse_modules -= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,1);
}

int may_disable()  { return 0; }

mapping query_tag_callers() {
  return ([ "list-tags":tag_list_tags ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: toparse
//! Parse all files ending with these extensions. Note: This module must be reloaded for a change here to take effect.
//!  type: TYPE_STRING_LIST
//!  name: Extensions to parse
//
//! defvar: parse_exec
//! If set, files has to have the execute bit (any of them) set in order for them to be parsed by this module. The exec bit is the one that is set by 'chmod +x filename'
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Require exec bit on files for parsing
//
//! defvar: no_parse_exec
//! If set, no files with the exec bit set will be parsed. This is the reverse of the 'Require exec bit on files for parsing' flag. It is not very useful to set both variables.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Don't Parse files with exec bit
//
//! defvar: max_parse
//! Maximum file size to parse, in Kilo Bytes.
//!  type: TYPE_INT|VAR_MORE
//!  name: Maximum file size
//
