#!/usr/local/bin/pike

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

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

string cvs_version = "$Id$";

//
// usage: <lucene_search db="/path/to/lucene/db" query="search query">
//

#if constant(Java)

static constant jvm = Java.machine;

object index;

string status_info="";

int main(int argc, array argv)
{
 start();
  index->search(argv[1]);
}

void start()
{
  index=Index();
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

void create()
{
  se=search_class->alloc();
  search_init(se, "db");
  check_exception();
}

void search(string q)
{
  object r=search_search(q);
  for(int i=0; i< arraylist_size(r); i++)
  {
     object re=arraylist_get(r, i);
     werror((string)hashmap_get(re,"url")  + "\n");
     werror((string)hashmap_get(re,"title")  + "\n");
     werror((string)hashmap_get(re,"type")  + "\n");
     werror((string)hashmap_get(re,"date")  + "\n");
     werror((string)hashmap_get(re,"desc")  + "\n");
     werror("\n");
  }
}

#define error(X) throw(({(X), backtrace()})) 
static void check_exception() {
 jvm->exception_describe();
}

}

#endif
