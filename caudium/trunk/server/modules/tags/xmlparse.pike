/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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


//! module: XML-Compliant RXML Parser
//!  This is a new XML-compliant RXML parser. It requires Pike 7.0 or
//!  newer, since it depends on Parser.HTML which doesn't exist in Pike
//!  0.6. Depending on the module is configured, it is more or less
//!  strict, in the XML-sense. Please note that although this parser
//!  handles XML-syntax, it never requires it. For example you can still
//!  use unquoted arguments.
//! cvs_version: $Id$

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <config.h>
#include <module.h>

inherit "module";
inherit "caudiumlib";

string date_doc=Stdio.read_bytes("modules/tags/doc/date_doc");
constant language = caudium->language;

constant module_type = MODULE_FILE_EXTENSION | MODULE_MAIN_PARSER | MODULE_PARSER | MODULE_PROVIDER;
constant module_name = "XML-Compliant RXML Parser";
constant module_doc  = "This is a new XML-compliant RXML parser. It requires \
Pike 7.0 or newer, since it depends on Parser.HTML which doesn't exist in \
Pike 0.6. Depending on the module is configured, it is more or less strict, \
in the XML-sense. Please note that although this parser handles XML-syntax, \
it never requires it. For example you can still use unquoted arguments. ";

constant module_unique = 1;

mapping (string:object) scopes;
array (mapping) tag_callers, container_callers;
mapping (string:mapping(int:function)) real_tag_callers, real_container_callers;
int bytes;
array (object) parse_modules = ({ });
object(Parser.HTML) parse_object;

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
	 
  defvar("no_parse_exec", 0, "Don't parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, no files with the exec bit set will be parsed. This is the "
	 "reverse of the 'Require exec bit on files for parsing' flag. "
	 "It is not very useful to set both variables.");
  
  defvar("max_parse", 200, "Maximum file size", TYPE_INT|VAR_MORE,
	 "Maximum file size to parse, in Kilo Bytes.");

  defvar("case_insensitive_tag", 1, "Parse options: Case insensitive parsing",
	 TYPE_FLAG,
	 "If enabled, the case of tags is ignored during parsing. When "
	 "disabled, &lt;TAG&gt; and &lt;tag&gt; are two different tags. ");
  defvar("lazy_argument_end", 0, "Parse options: Lazy argument end",
	 TYPE_FLAG,
	 "A '&gt;' in a tag argument closes both the argument and "
	 "the tag, even if the argument is quoted. ");
  defvar("lazy_entity_end", 0, "Parse options: Lazy entity end",
	 TYPE_FLAG,
	 "Normally, the parser search indefinitely for the entity end "
	 "character (i.e. ';'). When this flag is set, the characters '&mp;', "
	 "'&lt;', '&gt;', '\"', \"'\", and any whitespace breaks the search "
	 "for the entity end, and the entity text is then  ignored, i.e. "
	 "treated as data. ");
  
  defvar("recurse_levels", 50, "Parse options: Maximum Recursion Level",
	 TYPE_INT|VAR_MORE,
	 "This setting decides how deep the parser should recurse before "
	 "throwing an error. Recursion happens when a tag or entity returns "
	 "a simple string as opposed to a string in an array.",0, 
	 lambda() { return !Parser.HTML()->max_stack_depth; });
  defvar("match_tag", 1, "Parse options: Match tags",
	 TYPE_FLAG,
	 "Unquoted nested tag starters and enders will be balanced when "
	 "parsing tags. ");
  defvar("parse_arg_entities", 1, "Parse options: Parse entities in attributes",
	 TYPE_FLAG,
	 "If true, the values of attributes to tags and containers will be "
	 "parsed for entities (ie &amp;scope.name;). This is strongly "
	 "recommended as it allows for constructions like "
	 "&lt;gtext fg=\"&amp;form.fg;\"&gt; which otherwise would not "
	 "be allowed.");
  defvar("xml_conformance", 2, 
	 "Parse options: XML syntax conformance level",
	 TYPE_INT_LIST,
	 "Whether or not to use XML syntax to tell empty tags and  container "
	 "tags apart. "
	 "<br><b>0.</b> Use HTML syntax only. If there's a '/' last in a tag, it's "
	 "just treated as any other argument."
	 "<br><b>1.</b> Use HTML syntax, but ignore a '/' if it comes "
	 "last in a tag."
	 "<br><b>2.</b> Use XML syntax, but when a tag that does not end with '/>' is "
	 "found which only got a non-container tag callback, treat it as a "
	 "non-container (i.e. don't start to seek for the container "
	 "end). "
	 "<br><b>3.</b> Use XML syntax only. If a tag got both container and "
	 "non-container callbacks, the non-container callback is "
	 "called when the empty element form (i.e. the one ending "
	 "with '/>') is used, and the container callback otherwise. If "
	 "only a container callback exists, it gets the empty "
	 "string as content when  there's none to be parsed. If "
	 "only a non-container callback exists, it will be only be called "
	 "for tags with empty content (ie &lt;tag/&gt; or "
	 "&lt;tag&gt;&lt;/tag&gt;). Otherwise an error will be printed.",
	 ({ 0, 1, 2, 3 }) );
  
  
}

void start(int cnt, object conf)
{
  module_dependencies(conf, ({ "rxmltags", "corescopes" }));
  build_callers();
}

string query_provides() { return "rxml:core"; }

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

array(string)|string tag_with_contents(object parser, mapping args,
				      string contents,
				      mixed ... extra)
{
  array tag = parser->tag();
  string res;
  if(!strlen(contents)) {
    /* <foo></foo> should be the same as <foo/> */
    return call_tag(parser, args, @extra);
  }
  return 
    "<p><b>Syntax Error: Non-container &lt;"+tag[0]+"/&gt; called with content. "
    "Did you forget the /?</b></p>" + contents;
}

void parse_args(mapping args, object id, mixed ... extra) {
  object mp = Parser.HTML();
  mp->_set_entity_callback(entity_callback);
  mp->lazy_entity_end(QUERY(lazy_entity_end));
  mp->ignore_tags(1);
  mp->set_extra(id, @extra);
  id->misc->_default_encoding = "none";
  foreach(indices(args), string arg) {
    object mmp = mp->clone();
    args[arg] = mmp->finish(args[arg])->read();
  }
  m_delete(id->misc, "_default_encoding");
}
string call_tag(object parser, mapping args,
		object id, object file, mapping defines,
		object client)
{
  string tag = parser->tag_name();
  if(QUERY(case_insensitive_tag))
    tag = lower_case(tag);
  string|function rf = real_tag_callers[tag][0];
  id->misc->line = (string)parser->at_line();
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
  if(sizeof(args) && QUERY(parse_arg_entities)) {
    parse_args(args, id, file, defines, client);
  }
  mixed result=rf(tag,args,id,file,defines,client);
  TRACE_LEAVE("");
  return result;
}

array(string)|string 
call_container(object parser, mapping args, string contents,
	       object id, object file, mapping defines, object client)
{
  string tag = parser->tag_name();
  if(QUERY(case_insensitive_tag))
    tag = lower_case(tag);
  string|function rf = real_container_callers[tag][0];
  id->misc->line = (string)parser->at_line();
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
  if(sizeof(args) && QUERY(parse_arg_entities)) {
    parse_args(args, id, file, defines, client);
  }
  mixed result=rf(tag,args,contents,id,file,defines,client);
  TRACE_LEAVE("");
  if(args->noparse && stringp(result)) return ({ result });
  return result;
}



string call_user_tag(object parser, mapping args,
		     object id, object file, mapping defines,
		     object client)
{
  string tag = parser->tag_name();
  if(QUERY(case_insensitive_tag))
    tag = lower_case(tag);
  id->misc->line = (string)parser->at_line();
  args = id->misc->defaults[tag]|args;
  if(!id->misc->up_args) id->misc->up_args = ([]);
  TRACE_ENTER("user defined tag &lt;"+tag+"&gt;", call_user_tag);
  array replace_from = ({"#args#"})+
    Array.map(indices(args) + indices(id->misc->up_args),
	      lambda(string q) { return "&"+q+";"; });
  array replace_to = (({ make_tag_attributes( args + id->misc->up_args ) })+
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

array(string)|string 
call_user_container(object parser, mapping args, string contents,
	       object id, object file, mapping defines, object client)
{
  string tag = parser->tag_name();
  if(QUERY(case_insensitive_tag))
    tag = lower_case(tag);
  string|function rf = real_container_callers[tag][0];
  id->misc->line = (string)parser->at_line();
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

string do_parse(string to_parse, object id, object file, mapping defines,
		object my_fd)
{
  object my_parser = (id->misc->_xml_parser || parse_object)->clone();
  if(!id->misc->scopes)
    id->misc->scopes = mkmapping(indices(scopes), values(scopes)->clone());
  
  id->misc->_xml_parser = my_parser;
  if(!id->misc->_tags)
    id->misc->_tags = ([]);
  if(!id->misc->_containers)
    id->misc->_containers = ([]);
  id->misc->parse_level ++;
  my_parser->set_extra(id, file, defines, my_fd);
  to_parse = my_parser->finish(to_parse)->read();
  id->misc->parse_level --;
  return to_parse;
}

string tag_list_tags( string t, mapping args, object id, object f )
{
  int verbose;
  string res="";
  if(args->verbose) verbose = 1;

  for(int i = 0; i<sizeof(tag_callers); i++)
  {
    res += ("<b><font size=+1>Tags at prioity level "+i+": </b></font><p>");
    foreach(sort(indices(tag_callers[i])), string tag)
    {
      res += "  <a name=\""+replace(tag+i, "#", ".")+"\"><a href=\""+id->not_query+"?verbose="+replace(tag+i, "#","%23")+"#"+replace(tag+i, "#", ".")+"\">&lt;"+tag+"&gt;</a></a><br>";
      if(verbose || id->variables->verbose == tag+i)
      {
	res += "<blockquote><table><tr><td>";
	string tr;
	catch(tr=call_tag(id->misc->_xml_parser, (["help":"help"]), 
			  id, f, id->misc->defines, id->my_fd ));
	if(tr) res += tr; else res += "no help";
	res += "</td></tr></table></blockquote>";
      }
    }
  }

  for(int i = 0; i<sizeof(container_callers); i++)
  {
    res += ("<p><b><font size=+1>Containers at prioity level "+i+": </b></font><p>");
    foreach(sort(indices(container_callers[i])), string tag)
    {
      res += " <a name=\""+replace(tag+i, "#", ".")+"\"><a href=\""+id->not_query+"?verbose="+replace(tag+i, "#", "%23")+"#"+replace(tag+i,"#",".")+"\">&lt;"+tag+"&gt;&lt;/"+tag+"&gt;</a></a><br>";
      if(verbose || id->variables->verbose == tag+i)
      {
	res += "<blockquote><table><tr><td>";
	string tr;
	catch(tr=call_container(id->misc->_xml_parser, (["help":"help"]), "",
				id,f, id->misc->defines, id->my_fd ));
	if(tr) res += tr; else res += "no help";
	res += "</td></tr></table></blockquote>";
      }
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
#if efun(set_start_quote)
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

/* parsing modules */
void insert_in_map_list(mapping to_insert, string map_in_object)
{
  function do_call = this_object()["call_"+map_in_object];

  array (mapping) in = this_object()[map_in_object+"_callers"];
  mapping (string:mapping) in2=this_object()["real_"+map_in_object+"_callers"];

  
  foreach(indices(to_insert), string s)
  {
    if(!in2[s]) in2[s] = ([]);
    int i;
    for(i=0; i<sizeof(in); i++)
      if(!in[i][s])
      {
	in[i][s] = do_call;
	in2[s][i] = to_insert[s];
	break;
      }
    if(i==sizeof(in))
    {
      in += ({ ([]) });
      if(map_in_object == "tag")
	container_callers += ({ ([]) });
      else
	tag_callers += ({ ([]) });
      in[i][s] = do_call;
      in2[s][i] = to_insert[s];
    }
  }
  this_object()[map_in_object+"_callers"]=in;
  this_object()["real_"+map_in_object+"_callers"]=in2;
}

void sort_lists()
{
  array ind, val, s;
  foreach(indices(real_tag_callers), string c)
  {
    ind = indices(real_tag_callers[c]);
    val = values(real_tag_callers[c]);
    sort(ind);
    s = Array.map(val, lambda(function f) {
       if(functionp(f)) return function_object(f)->query("_priority");
       return 5;
    });
    sort(s,val);
    real_tag_callers[c]=mkmapping(ind,val);
  }
  foreach(indices(real_container_callers), string c)
  {
    ind = indices(real_container_callers[c]);
    val = values(real_container_callers[c]);
    sort(ind);
    s = Array.map(val, lambda(function f) {
      if (functionp(f)) return function_object(f)->query("_priority");
      return 5;
    });
    sort(s,val);
    real_container_callers[c]=mkmapping(ind,val);
  }
}

string|array(string)|int entity_callback(object parser, string entity,
					 object id, mixed ... extra) {
  string scope, name, encoding;
  array tmp = (parser->tag_name()) / ":";
  mixed ret;
  entity = tmp[0];
  encoding = tmp[1..] * ":";
  if(!encoding || !strlen(encoding))
    encoding = id->misc->_default_encoding || "html";
  if(sscanf(entity, "%s.%s", scope, name) != 2)
    return 0;
  if(id->misc->scopes[scope]) {
    ret =  id->misc->scopes[scope]->get(name, id, @extra);
    if(!ret) return "";
    if(stringp(ret)) return roxen_encode(ret, encoding);
    if(arrayp(ret)) return Array.map(ret, roxen_encode, encoding);
  }
  return 0;
}

void build_callers()
{
   object o;
   real_tag_callers = ([]);
   real_container_callers = ([]);
   scopes = ([]);
//   misc_cache = ([]);
   tag_callers = ({ ([]) });
   container_callers = ({ ([]) });

   parse_modules -= ({0});

   foreach (parse_modules,o)
   {
     array|mapping foo;
     if(o->query_tag_callers)
     {
       foo=o->query_tag_callers();
       if(mappingp(foo)) {
	 if(QUERY(case_insensitive_tag))
	   foo = mkmapping(Array.map(indices(foo), lower_case), values(foo));
	 insert_in_map_list(foo, "tag");
       }
     }
     
     if(o->query_container_callers)
     {
       foo=o->query_container_callers();
       if(mappingp(foo)) {
	 if(QUERY(case_insensitive_tag))
	   foo = mkmapping(Array.map(indices(foo), lower_case), values(foo));
	 insert_in_map_list(foo, "container");
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
   sort_lists();
   parse_object = Parser.HTML();
   for(int i = 0; i < sizeof(tag_callers); i++) {
     parse_object->add_tags(tag_callers[i]);
     if(QUERY(xml_conformance) == 3)
       /* Add a "container" for each tag so we can report errors */
       parse_object->add_containers(mkmapping(indices(tag_callers[i]),
					      allocate(sizeof(tag_callers[i]),
						       tag_with_contents)));

     parse_object->add_containers(container_callers[i]);
   }
   parse_object->case_insensitive_tag(QUERY(case_insensitive_tag));
   parse_object->ignore_unknown(0);
   parse_object->xml_tag_syntax(QUERY(xml_conformance));
   parse_object->lazy_argument_end(QUERY(lazy_argument_end));
   parse_object->lazy_entity_end(QUERY(lazy_entity_end));
   parse_object->match_tag(QUERY(match_tag));
   parse_object->splice_arg("::");
   parse_object->_set_entity_callback(entity_callback);
   if(parse_object->max_stack_depth)
     parse_object->max_stack_depth(QUERY(recurse_levels));
}

void add_parse_module(object o)
{
  parse_modules |= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,0);
}

void remove_parse_module(object o)
{
  parse_modules -= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,0);
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
//!  name: Don't parse files with exec bit
//
//! defvar: max_parse
//! Maximum file size to parse, in Kilo Bytes.
//!  type: TYPE_INT|VAR_MORE
//!  name: Maximum file size
//
//! defvar: case_insensitive_tag
//! If enabled, the case of tags is ignored during parsing. When disabled, &lt;TAG&gt; and &lt;tag&gt; are two different tags. 
//!  type: TYPE_FLAG
//!  name: Parse options: Case insensitive parsing
//
//! defvar: lazy_argument_end
//! A '&gt;' in a tag argument closes both the argument and the tag, even if the argument is quoted. 
//!  type: TYPE_FLAG
//!  name: Parse options: Lazy argument end
//
//! defvar: lazy_entity_end
//! Normally, the parser search indefinitely for the entity end character (i.e. ';'). When this flag is set, the characters '&mp;', '&lt;', '&gt;', '"', "'", and any whitespace breaks the search for the entity end, and the entity text is then  ignored, i.e. treated as data. 
//!  type: TYPE_FLAG
//!  name: Parse options: Lazy entity end
//
//! defvar: match_tag
//! Unquoted nested tag starters and enders will be balanced when parsing tags. 
//!  type: TYPE_FLAG
//!  name: Parse options: Match tags
//
//! defvar: parse_arg_entities
//! If true, the values of attributes to tags and containers will be parsed for entities (ie &amp;scope.name;). This is strongly recommended as it allows for constructions like &lt;gtext fg="&amp;form.fg;"&gt; which otherwise would not be allowed.
//!  type: TYPE_FLAG
//!  name: Parse options: Parse entities in attributes
//
//! defvar: xml_conformance
//! Whether or not to use XML syntax to tell empty tags and  container tags apart. <br /><b>0.</b> Use HTML syntax only. If there's a '/' last in a tag, it's just treated as any other argument.<br /><b>1.</b> Use HTML syntax, but ignore a '/' if it comes last in a tag.<br /><b>2.</b> Use XML syntax, but when a tag that does not end with '/>' is found which only got a non-container tag callback, treat it as a non-container (i.e. don't start to seek for the container end). <br /><b>3.</b> Use XML syntax only. If a tag got both container and non-container callbacks, the non-container callback is called when the empty element form (i.e. the one ending with '/>') is used, and the container callback otherwise. If only a container callback exists, it gets the empty string as content when  there's none to be parsed. If only a non-container callback exists, it will be only be called for tags with empty content (ie &lt;tag/&gt; or &lt;tag&gt;&lt;/tag&gt;). Otherwise an error will be printed.
//!  type: TYPE_INT_LIST
//!  name: Parse options: XML syntax conformance level
//
