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
//! module: Spindle Search Engine
//!  An interface to the Lucene based Spindle Search engine
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
constant module_name = "Lucene Search Engine";
constant module_doc  = "A search engine built on the Lucene text index engine.";
constant module_unique = 1;

//
// usage: <lucene_search query="search query">
//

object index;

void start()
{
  if(QUERY(dir))
  {
    start_engines(QUERY(dir));
  }
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

mixed tag_lucene (string tag_name, mapping args,
                    object id, object f,
                    mapping defines, object fd)
{
  if(!args->query) return "<!-- no query specified -->";
  
  string ret="";

  array result=index->search(args->query);

  if(!result || sizeof(result)==0)
     return "no results found for your query <i>" + args->query + "</i>.";

  ret+="Found " + sizeof(result) + " matches to your query \"<i>" + args->query + "</i>\":<p>\n"; 

  foreach(result, mapping r)
    ret+="<dt><a href=\"" +r->url + "\">" + r->title + "</a> ( " + 
	r->score + ", " + r->type + " )<br>\n"
       "<dd><i>" + r->desc + "</i> " + r->date + "<p>";

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
