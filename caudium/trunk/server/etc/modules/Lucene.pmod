/*
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

// $Id$

//! Glue for the Jakarta Lucene search engine

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

//!
string cvs_version = "$Id$";

//!
static constant jvm = Java.machine;

#if constant(jvm)

//!
static object throwable_class = FINDCLASS("java/lang/Throwable");

//!
static object stringwriter_class = FINDCLASS("java/io/StringWriter");

//!
static object printwriter_class = FINDCLASS("java/io/PrintWriter");

//!
static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");

//!
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");

//!
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");

//!
static object printwriter_flush = printwriter_class->get_method("flush", "()V");

//!
static object throwable_getmessage = throwable_class->get_method("getMessage", "()Ljava/lang/String;");

import Parser.XML.Tree;

//! produce an array of stopwords from an array of stopwords filenames
array load_stopwords(array fns)
{
  array stopwords=({});
  foreach(fns, mapping s) 
  {
    string f=Stdio.read_file(s->value);
    if(f)
      stopwords+=f/"\n";
  }
  stopwords-=({""});
  stopwords=Array.uniq(stopwords);
  return stopwords;
}

//! read an index profile from filename
mapping read_profile(string filename)
{
  mapping profile=([]);

  if(!file_stat(filename))
  {
    error("profile " + filename + " does not exist.\n");
  }

  string f=Stdio.read_file(filename);
  if(!f)
  {
    error("profile " + filename + " is empty.\n");
  }
  
  Node configxml = Parser.XML.Tree->parse_input(f);
  
  configxml->iterate_children(lambda(Node c, mapping profile){
    if(c->get_tag_name()=="profile")
    { 
       profile->name=c->get_attributes()["name"];
       c->iterate_children(parse_profile, profile);
    }}, profile);
  return profile;
}

private void parse_profile(Node p, mapping profile)
{
  if(p->get_node_type()==XML_ELEMENT)
    switch(p->get_tag_name())
    {
      case "indexer":
      case "crawler":
      case "index":
      case "converters":
        p->iterate_children(parse_section, p->get_tag_name(), profile);
        break;

      default:
        error("unknown profile section " + p->get_tag_name() + "\n");
    }
}

private void parse_section(Node s, string sect, mapping profile)
{
  if(s->get_node_type()==XML_ELEMENT)
  {
    if(!profile[sect])
      profile[sect]=([]);
    if(!profile[sect][s->get_tag_name()])
      profile[sect][s->get_tag_name()]=({});
    profile[sect][s->get_tag_name()]+=({ s->get_attributes() + (["value":s->value_of_node() ]) });
  }

}


//!
void check_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    jvm->exception_clear();
    object sw = stringwriter_class->alloc();
    stringwriter_init(sw);
    object pw = printwriter_class->alloc();
    printwriter_init(pw, sw);
/*
    if (e->is_instance_of(servlet_exc_class))
      {
        object re = servlet_exc_getrootcause(e);
        if (re)
          throwable_printstacktrace(re, pw);
      }
*/
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
    array bt = backtrace();
    // FIXME: KLUDGE: Sometimes the cast fails for some reason.
    string s = "Unknown Java exception (StringWriter failed)";
    catch {
      s = (string)sw;
    };
    throw(({s, bt[..sizeof(bt)-2]}));
  }
}

//!
class Indexer
{

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

//!
static object class_class = FINDCLASS("java/lang/Class");

//!
static object classloader_class = FINDCLASS("java/lang/ClassLoader");

//!
static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

//!
static object dictionary_class = FINDCLASS("java/util/Dictionary");

//!
static object array_class = FINDCLASS("java/lang/reflect/Array");

//!
static object arraylist_class = FINDCLASS("java/util/ArrayList");

//!
static object list_class = FINDCLASS("java/util/List");

//!
static object hashmap_class = FINDCLASS("java/util/HashMap");

//!
static object collection_class = FINDCLASS("java/util/Collection");

//!
static object string_class = FINDCLASS("java/lang/String");

//!
static object arraylist_init = arraylist_class->get_method("<init>", "()V");

//!
static object arraylist_get = list_class->get_method("get", "(I)Ljava/lang/Object;");

//!
static object arraylist_size = collection_class->get_method("size", "()I");

//!
static object hashmap_get = hashmap_class->get_method("get", "(Ljava/lang/Object;)Ljava/lang/Object;");


//!
static object array_newinstance = array_class->get_static_method("newInstance", "(Ljava/lang/Class;I)Ljava/lang/Object;");

//!
static object array_set = array_class->get_static_method("set", "(Ljava/lang/Object;ILjava/lang/Object;)V");

//!
static object array_get = array_class->get_static_method("get", "(Ljava/lang/Object;I)Ljava/lang/Object;");

//!
static object index_class = FINDCLASS("net/caudium/search/Indexer");

//!
static object summary_class = FINDCLASS("net/caudium/search/URLSummary");

//!
static object index_init = index_class->get_method("<init>", "(Ljava/lang/String;[Ljava/lang/String;Z)V");

//!
static object summary_init = summary_class->get_method("<init>", "()V");

//!
static object index_close = index_class->get_method("close", "()V");

//!
static object index_add = index_class->get_method("add", "(Lnet/caudium/search/URLSummary;)V");

//!
static object summary_url=summary_class->get_field("url", "Ljava/lang/String;");

//!
static object summary_body=summary_class->get_field("body", "Ljava/lang/String;");

//!
static object summary_desc=summary_class->get_field("desc", "Ljava/lang/String;");

//!
static object summary_title=summary_class->get_field("title", "Ljava/lang/String;");

//!
static object summary_type=summary_class->get_field("type", "Ljava/lang/String;");

//!
static object summary_date=summary_class->get_field("date", "Ljava/lang/String;");

//!
object ie;

//! create a new indexer
void create(string datadir, array stopwords)
{
  object sw=array_newinstance(string_class, sizeof(stopwords));
  for(int i=0; i<sizeof(stopwords); i++)
    array_set(sw, i, stopwords[i]);

  ie=index_class->alloc();
  index_init(ie, datadir, sw, 0);
  Lucene->check_exception();
}

//!
void destroy()
{
  index_close(ie);
}
 
//! close the index
void close()
{
  index_close(ie);
}

//! add a document to the index
int index(string uri, string data, string title, string type, string date)
{
  data=replace(data, ({"\r", "\n"}), ({" ", " "}));

  data=(((data/" ")-({""}))*" ");

  //report_debug(data + "\n\n");
  object us=summary_class->alloc();
  Lucene->check_exception();
  summary_init(us);
  Lucene->check_exception();
  summary_url->set(us, uri);
  Lucene->check_exception();
  summary_body->set(us, data);
  Lucene->check_exception();
  summary_title->set(us, title);
  Lucene->check_exception();
  summary_desc->set(us, (sizeof(data)<254?data:data[0..253]+"..."));
  Lucene->check_exception();
  summary_date->set(us, date);
  Lucene->check_exception();
  summary_type->set(us, type);
  Lucene->check_exception();
  index_add(ie, us);
  Lucene->check_exception();
//report_debug((string)us);
  return 1;
}

//! used for internal pike converters
  class PikeFilter(function convert)
  {

  }

//! a filter for programs that act as filters (read on stdin and write the 
//! converted data on stdout.
  class Filter(string command)
  {

    //!
    string convert(string data)
    {
       string ret="";
       object i=Stdio.File();
       object o=Stdio.File();
       object e=Stdio.File();
       array args=command/" ";

       object p=Process.create_process(args, (["stdin": i->pipe(), "stdout": o->pipe(), "stderr": 
         e->pipe()]));

       i->write(data);
       i->close();

       mixed r;
       do
       {  
         r=o->read(1024, 1);
         if(sizeof(r)>0)
           ret+=r;
         else break;
       } 
       while(1);
	report_debug(e->read(1024,1));
       return ret;
    }
  }

//! this is a filter for programs that do not act as filters (they read a 
//!   file and write converted output on stdout.
  class Converter(string command, string tempdir)
  {
    int i=0;

    //!
    string convert(string data)
    {
       string ret="";
       i++;       
       string t=MIME.encode_base64(Crypto.MD5()->update(data + i)->update((string)time())->digest());

       t=(string)hash(t);

       string tempfile=combine_path(tempdir, t);

       Stdio.write_file(tempfile, data);

       if(file_stat(tempfile))
       {
       string ncommand=(command/"%f")*(string)tempfile;
       array args=ncommand/" ";
         object o=Stdio.File();
         object e=Stdio.File();
         object p=Process.create_process(args, (["stdout": o->pipe(), "stderr": e->pipe()]));

      
         mixed r;
         do
         {  
           r=o->read(1024, 1);
           if(sizeof(r)>0)
             ret+=r;
           else break;
          } 
         while(1);
         report_debug(e->read(1024,1));
         do
         {
           p->wait();
         }
         while(p && p->status()==0);

       }

       if(file_stat(tempfile))
       {
         rm(tempfile);
       }
       tempfile="";
       return ret;
    }
  }
}

//! impliments a Lucene searcher
class Index
{

//!
static object class_class = FINDCLASS("java/lang/Class");

//!
static object classloader_class = FINDCLASS("java/lang/ClassLoader");

//!
static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");

//!
static object throwable_class = FINDCLASS("java/lang/Throwable");

//!
static object stringwriter_class = FINDCLASS("java/io/StringWriter");

//!
static object printwriter_class = FINDCLASS("java/io/PrintWriter");

//!
static object dictionary_class = FINDCLASS("java/util/Dictionary");

//!
static object array_class = FINDCLASS("java/lang/reflect/Array");

//!
static object arraylist_class = FINDCLASS("java/util/ArrayList");

//!
static object list_class = FINDCLASS("java/util/List");

//!
static object hashmap_class = FINDCLASS("java/util/HashMap");

//!
static object collection_class = FINDCLASS("java/util/Collection");

//!
static object string_class = FINDCLASS("java/lang/String");

//!
static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");

//!
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");

//!
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");

//!
static object printwriter_flush = printwriter_class->get_method("flush", "()V");


//!
static object array_newinstance = array_class->get_static_method("newInstance", "(Ljava/lang/Class;I)Ljava/lang/Object;");

//!
static object array_set = array_class->get_static_method("set", "(Ljava/lang/Object;ILjava/lang/Object;)V");

//!
static object array_get = array_class->get_static_method("get", "(Ljava/lang/Object;I)Ljava/lang/Object;");

//!
static object arraylist_init = arraylist_class->get_method("<init>", "()V");

//!
static object arraylist_get = list_class->get_method("get", "(I)Ljava/lang/Object;");

//!
static object arraylist_size = collection_class->get_method("size", "()I");

//!
static object hashmap_get = hashmap_class->get_method("get", "(Ljava/lang/Object;)Ljava/lang/Object;");


//!
static object search_class = FINDCLASS("net/caudium/search/Search");

//!
static object search_init = search_class->get_method("<init>", "(Ljava/lang/String;[Ljava/lang/String;)V");

//!
static object search_search = search_class->get_method("search", "(Ljava/lang/String;)Ljava/util/ArrayList;");

private object se;
private object sw;
private string dbdir;

//! create a new Lucene searcher
void create(string _dbdir, array stopwords)
{
  dbdir=_dbdir;

  sw=array_newinstance(string_class, sizeof(stopwords));
  for(int i=0; i<sizeof(stopwords); i++)
    array_set(sw, i, stopwords[i]);

  se=search_class->alloc();
}

//! return an array of search results from the Lucene text query string q
array(mapping) search(string q)
{
  search_init(se, dbdir, sw);
  Lucene->check_exception();

  array results=({});

  object r=search_search(se,q);
  Lucene->check_exception();
  for(int i=0; i< arraylist_size(r); i++)
  {
     mapping row=([]);
     object re=arraylist_get(r, i);
     Lucene->check_exception();
    
     row->url=(string)hashmap_get(re,"url");
     row->title=(string)hashmap_get(re,"title");
     row->type=(string)hashmap_get(re,"type");
     row->date=(string)hashmap_get(re,"date");
     row->desc=(string)hashmap_get(re,"desc");
     row->score=(float)((string)hashmap_get(re,"score"));

     results+=({ row });
  }

  return results;
}

}


#endif


