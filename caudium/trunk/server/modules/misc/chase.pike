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

//
//! module: Chase Search Engine
//!  Caudium Has A Search Engine, based on the Jakarta Lucene
//!  Full Text Engine
//! inherits: module
//! inherits: caudiumlib
//! inherits: http
//! type: MODULE_LOCATION
//! cvs_version: $Id$
//

#include <module.h>

string cvs_version = "$Id$";
int thread_safe=1;

inherit "module";
inherit "caudiumlib";
static inherit "http";

#if constant(Lucene.Index)

constant module_type = MODULE_PARSER;
constant module_name = "Chase Search Engine";
constant module_doc  = "Caudium Has A Search Engine, based on the"
    "Jakarta Lucene full text engine.";
constant module_unique = 1;

object index;
object cache;

void start()
{
  if(QUERY(dir))
  {
    start_engines(QUERY(dir));
  }
  if(!cache)
     cache=caudium->cache_manager->get_cache(
        my_configuration()->query("MyWorldLocation") 
       + "chase"); 
}

string status_info="";

string query_location()
{
}

string query_name()
{
}

void create()
{
  defvar( "dir", "../search_data", "Data Directory", TYPE_DIR,
    "Location where the search engine and indexer should store its profile data.");
}

mapping query_tag_callers()
{
  return (["lucene_search": tag_lucene]);
}

mixed tag_chaseform (string tag_name, mapping args,
                    object id, object f,
                    mapping defines, object fd)
{
  string retval="<form action=\"" + id->not_query + "\" method=\"get\">";
  
  retval+="<input type=text size=20 name=q value=\"" + 
    (id->variables->q||"") +  "\">\n";
  retval+="<input type=submit value=\"Search\">"
  if(!args->nohelp)
    retval+=" <a href=\"" + id->not_query + "?help=1\">QueryHelp</a>";
  retval+="</form>";

  return retval;
}

mixed tag_chaseresults(string tag_name, mapping args,
                    object id, object f,
                    mapping defines, object fd)
{
  if(!id->variables->q || id->variables->q=="") return "<!-- no query -->\n";
  if(!id->variables->p || id->variables->p=="") return "<!-- no profile  -->\n";

  string ret="";
  int ransearch=0;
  array result;

  result=cache->retrieve(id->variables->p + "|" + id->variables->q);

  if(pragma["no-cache"] || !result)
  {
    result=engines[id->variables->p]->search(id->variables->q);
    ransearch=1;
  }

  int rpp=20;
 
  if(args->resultsperpage)
    rpp=(int)(args->resultsperpage);

  if(sizeof(result)>rpp && ransearch)
  {
    // we have more than will fit on one page, so we cache the results
    cache->store(
      cache_pike(result, id->variables->p + "|" + id->variables->q));    
  }

  if(!result || sizeof(result)==0)
     return "No results were found for your query <i>" + args->query + "</i>.";

  int pages=result/rpp;
  if(result%rpp) pages++;

  int displayfrom=(int)(id->variables->s||1);
  int displayto=((displayfrom+rpp)<=sizeof(result)?(displayfrom+rpp):sizeof(result));

  ret+="Found " + sizeof(result) + " matches to your query \"<i>" + args->query + "</i>\":<p>\n"; 
  ret+="Displaying results " + displayfrom + "-" + displayto + " of " + sizeof(result);
  ret+="<br>\n";

  for(int i=1; i<=pages; i++)
  {
    if((i*rpp)==displayfrom)
      ret+=i + " ";
    else
      ret=ret+"<a href=\"" + id->not_query + "?p=" + id->variables->p + 
        "&q=" + id->variables->q + "&s=" + (i*rpp) +"\">" + i + "</a> ";
    
  }  

  ret+="<p>\n";
  
  for(int i=displayfrom-1; i<displayto; i++)
  {
    mapping r=result[i];

    ret+="<dt><a href=\"" +r->url + "\">" + r->title + "</a> ( " + 
	r->score + ", " + r->type + " )<br>\n"
       "<dd><i>" + r->desc + "</i> " + r->date + "<p>";
  }
  return ret;
  
}

void start_engines(string dir)
{
  array pfs=({});
  string p=combine_path(dir, "profiles");
  if(file_stat(p))
    pfs=get_dir(p);

  foreach(pfs, string filename)
  {
    mapping p;
    catch(p=Lucene.read_profile(Stdio.read_file(filename)));
    if(p && p->name)
      profiles[p->name]=p;
    else report_error("unable to read search profile %s\n", filename);
  }

  foreach(indices(profiles), string name)
  {
     start_engine(name);
  }
}

void start_engine(string name)
{
  array stopwords=({});
  if(profiles[name]->index->stopwordsfile)
    stopwords=Lucene->load_stopwords(profiles[name]->index->stopwordsfile);

  engines[name]=Lucene.Index(profiles[name]->index->location[0]->value, stopwords));
}

#endif
