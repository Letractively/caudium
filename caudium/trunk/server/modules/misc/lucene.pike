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
// usage: <lucene_search db="/path/to/lucene/db" query="search query">
//

/* Doesn't work on NT yet */
#if constant(Java)

static constant jvm = Java.machine;

object spindle;

string status_info="";

void stop()
{
}

void start(int x, object conf)
{
  spindle=Spindle();
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
}

mapping query_tag_callers()
{
  return (["lucene_search": tag_lucene]);
}

mixed tag_lucene (string tag_name, mapping args,
                    object id, object f,
                    mapping defines, object fd)
{
  if(!args->db) return "<!-- no database directory specified -->";
  if(!args->query) return "<!-- no query specified -->";
  
  string ret="";

  array result=spindle->search(args->db, args->query);

  if(!result || sizeof(result)==0)
     return "no results found for your query <i>" + args->query + "</i>.";

  ret+="Found " + sizeof(result) + " matches to your query \"<i>" + args->query + "</i>\":<p>\n"; 

  foreach(result, array r)
    ret+="<dt><a href=\"" + r[0] + "\">" + r[1] + "</a> ( " + r[2] + " )<br>\n"
       "<dd><i>" + r[3] + "</i><p>";

  return ret;
  
}

class Spindle
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


static object search_class = FINDCLASS("com/bitmechanic/spindle/Search");
static object search_init = search_class->get_method("<init>", "()V");


object setdir_function=search_class->get_method("setDir", "(Ljava/lang/String;)V");
object setquery_function=search_class->get_method("setQuery", "(Ljava/lang/String;)V");
object search_function=search_class->get_static_method("search", "(Ljava/lang/String;Ljava/lang/String;)Ljava/util/ArrayList;");

object se;

void create()
{
  se=search_class->alloc();
}

array search(string db, string q)
{
  object result;

  array sr=({});

  check_exception();

  result=search_function(db, q);  
  check_exception();

  for(int i=0; i< arraylist_size(result); i++)
  {
    object re=arraylist_get(result, i);
    sr+=({ ({  (string)hashmap_get(re, "url"),
               (string)hashmap_get(re, "title"),
               (string)hashmap_get(re, "score"),
               (string)hashmap_get(re, "desc")
         }) });

  }

  return sr;

}


#define error(X) throw(({(X), backtrace()}))

static void check_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    object sw = stringwriter_class->alloc();
    stringwriter_init(sw);
    object pw = printwriter_class->alloc();
    printwriter_init(pw, sw);
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
    jvm->exception_clear();
    array bt = backtrace();
    throw(({(string)sw, bt[..sizeof(bt)-2]}));
  }
}


}

#endif
