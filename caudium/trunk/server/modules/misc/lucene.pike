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


#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

string cvs_version = "$Id$";
int thread_safe=1;

inherit "module";
inherit "caudiumlib";
static inherit "http";

constant module_type = MODULE_PARSER;
constant module_name = "Lucene bridge";
constant module_doc  = "An interface to the Lucene search engine via Bitmechanics' Spindle.";
constant module_unique = 1;

//
// usage: <lucene_search query="search query">
//

/* Doesn't work on NT yet */
#if constant(Java)

static constant jvm = Java.machine;

object index;

void start()
{
  if(QUERY(dir))
    index=Index(QUERY(dir));
}


string status_info="";

void stop()
{
}

string status()
{
}

string query_location()
{
}

string query_name()
{
}

void create()
{
 defvar( "dir", "../search_data", "Data Directory", TYPE_STRING,
          "This is the directory where Lucene has stored its data." );

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

class Index
{

static constant jvm = Java.machine;

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))
static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");

static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");
static object dictionary_class = FINDCLASS("java/util/Dictionary");
static object arraylist_class = FINDCLASS("java/util/ArrayList");
static object list_class = FINDCLASS("java/util/List");
static object hashmap_class = FINDCLASS("java/util/HashMap");
static object collection_class = FINDCLASS("java/util/Collection");
static object string_class = FINDCLASS("java/lang/String");

static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");


static object arraylist_init = arraylist_class->get_method("<init>", "()V");
static object arraylist_get = list_class->get_method("get", "(I)Ljava/lang/Object;");
static object arraylist_size = collection_class->get_method("size", "()I");
static object hashmap_get = hashmap_class->get_method("get", "(Ljava/lang/Object;)Ljava/lang/Object;");


static object search_class = FINDCLASS("net/caudium/search/Search");
static object search_init = search_class->get_method("<init>", "(Ljava/lang/String;)V");
static object search_search = search_class->get_static_method("search", "(Ljava/lang/String;)Ljava/util/ArrayList;");

object se;

void create(string dir)
{
  se=search_class->alloc();
  search_init(se, dir);
  check_exception();
}

array search(string q)
{
  array res=({});
  object r=search_search(q);
  if(arraylist_size(r)>0)
    for(int i=0; i< arraylist_size(r); i++)
    {
       object re=arraylist_get(r, i);
       res+=({ ([
         "url": hashmap_get(re,"url"),
         "title":  hashmap_get(re,"title"),
         "type": hashmap_get(re,"type"),
         "date": hashmap_get(re,"date"),
         "desc": hashmap_get(re,"desc")
	 ]) });
  }

  return res;
}

#define error(X) throw(({(X), backtrace()})) 
static void check_exception() {
 jvm->exception_describe();
}

}

#endif
