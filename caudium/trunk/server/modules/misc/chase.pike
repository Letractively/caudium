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

mapping engines=([]);
mapping profiles=([]);
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

string status()
{
  return sizeof(engines) + " search profiles loaded";
}

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
  return (["chase_form": tag_chaseform, "chase_results": tag_chaseresults,
	"chase_powered" : tag_chasepowered]);
}


mapping pl_sizes = ([]);
string get_pl_size(string size, string color)
{
  if(pl_sizes[size+color])
      return pl_sizes[size+color];

  mapping file = caudium->IFiles->get("image://lucene-" + size + "-" + color + ".gif");

  if(!file)
      return "NONEXISTENT COMBINATION";

  return pl_sizes[size+color] = sprintf("width=\"%d\" height=\"%d\"",
                                        file->width, file->height);
}


string tag_chasepowered(string tagname, mapping m)
{
    string size = m->size || "small";
    string color = m->color || "outline";

    m_delete(m, "color");
    m_delete(m, "size");
    int w;

    if(get_pl_size(size,color)  == "NONEXISTENT COMBINATION")
        color = "outline";
    sscanf(get_pl_size(size,color), "%*swidth=\"%d", w);
    if(w != 0)
        m->width = (string)w;
    sscanf(get_pl_size(size,color), "%*sheight=\"%d", w);
    if(w != 0)
        m->height = (string)w;

    m->src = "/(internal,image)/lucene-"+size+"-"+color;

    if(!m->alt)
        m->alt="Powered by Jakarta Lucene";
    if(!m->border)
        m->border="0";

    m_delete(m, size);
    return ("<a href=\"http://jakarta.apache.org/lucene/\">"+Caudium.make_tag("img", m)+"</a>");
}	

mixed tag_chaseform (string tag_name, mapping args,
                    object id, object f,
                    mapping defines, object fd)
{
  string retval="<form action=\"" + id->not_query + "\" method=\"get\">";
  
  retval+="<input type=text size=20 name=q value=\"" + 
    (id->variables->q||"") +  "\">\n";
  if(!args->profile)
  {
    retval+="<select name=\"p\">";
    foreach(indices(profiles), string pn)
      retval+="<option>" + pn + "\n";
    retval+="</select>\n";
  }
  retval+="<input type=submit value=\"Search\">";
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

  if(id->pragma["no-cache"] || !result)
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
     return "No results were found for your query <i>" + id->variables->q + "</i>.";

  int pages=sizeof(result)/rpp;
  if(sizeof(result)%rpp) pages++;

  int displayfrom=(int)(id->variables->s||0);
  int displayto=((displayfrom+rpp)<=sizeof(result)?(displayfrom+rpp):sizeof(result));

  ret+="Found " + sizeof(result) + " matches to your query \"<i>" + id->variables->q + "</i>\":<p>\n"; 
  ret+="Displaying results " + (displayfrom+1) + "-" + displayto + " of " + sizeof(result);
  ret+="<br>\n";

  array rv=({});

  for(int i=0; i<pages; i++)
  {
    if((i*rpp)==displayfrom)
      rv+=({(i+1) + " "});
    else
      rv+=({"<a href=\"" + id->not_query + "?p=" + id->variables->p + 
        "&q=" + id->variables->q + "&s=" + (i*rpp) +"\">" + (i+1) + "</a>"});
    
  }  

  ret+=(rv*" | ");
  ret+="<p>\n";
  
  for(int i=displayfrom; i<(displayto); i++)
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
    mapping pr;
    mixed er=catch(pr=Lucene.read_profile(combine_path(p,filename)));
    if(er)
      throw(er);
    if(pr && pr->name)
      profiles[pr->name]=pr;
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

  engines[name]=Lucene.Index(profiles[name]->index->location[0]->value, stopwords);
}

#endif
