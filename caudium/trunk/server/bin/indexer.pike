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

#if constant(Java)

static constant jvm = Java.machine;

string profile_path;
int verbose;
object index;
mapping profile=([]);
object crawler;

void display_help()
{
   werror("usage: indexer.pike [-v] --profile=/path/to/profile\n");
   exit(0);
}

void read_profile(string filename)
{
  if(!file_stat(filename))
  {
    werror("profile " + filename + " does not exist.\n");
    exit(1);
  }

  string f=Stdio.read_file(filename);
  if(!f)
  {
    werror("profile " + filename + " is empty.\n");
    exit(1);
  }

  array lines=f/"\n";

  profile->dbdir=lines[0];
  profile->site=lines[1];

  return;
}

void error_cb(mixed real_uri, int status, mapping headers)
{
//  werror("error " + status + " received for " + (string)real_uri + "\n");
}
void done_cb()
{
  werror("done\n");
  quit();
}

object parser, stripper;
object current_uri;

array page_cb(Standards.URI uri, mixed data, mapping headers, mixed ... args)
{
  if(verbose)
    werror("got page " + (string)uri + "\n");
  page_urls=({});
  current_uri=uri;
  parser->feed(data);  
  data=parser->read();
  stripper->feed(data);
  data=stripper->read();
  if(verbose)
    werror("title: " + title + "\n");
  title="";
  string type=(headers["content-type"]/";")[0]||"text/html";
  string date=headers["last-modified"]||"";
  if(verbose)
    werror(type  + "\n");
  if(type=="text/html" || type=="text/plain")
    index->index((string)uri, data, title, type, date);
  return page_urls;
}

string title;
array page_urls=({});

mixed set_title(Parser.HTML p, mapping args, string content)
{
  title=content;
  return "";
}

mixed add_url(Parser.HTML p, mapping args, string content)
{
  if(args->href)
  {
    // remove any targets
    args->href=(args->href/"#")[0];
    page_urls+=({Standards.URI(args->href, current_uri)});
  }
  return content;
}

object q;

void quit()
{
  destruct(index);
  exit(1);
}

mixed strip_tag(Parser.HTML p, string t)
{
  return "";
}

int main(int argc, array argv)
{
   signal(2, quit);

  array options=({ ({"profile", Getopt.HAS_ARG, ({"--profile"}) }),
        ({"verbose", Getopt.NO_ARG, ({"-v", "--verbose"}) }),
        ({"help", Getopt.NO_ARG, ({"-h", "--help"}) }) });
  array args=Getopt.find_all_options(argv, options);

  foreach(args, array a)
  {
    if(a[0]=="profile")
      profile_path=a[1];
    if(a[0]=="verbose")
      verbose=1;
    if(a[0]=="help")
      display_help();
  }

  if(!profile_path)
  {
    werror("no profile specified.\n");
    exit(1);
  }

  read_profile(profile_path);

  index=Indexer(profile->dbdir);


   mixed url=profile->site;
   parser=Parser.HTML();
   stripper=Parser.HTML();
   parser->add_container("title", set_title);
   parser->add_container("a", add_url);
   parser->add_container("script", strip_tag);
   parser->add_container("style", strip_tag);
   stripper->_set_tag_callback(strip_tag);

   object allow=Web.Crawler.RuleSet();
   object deny=Web.Crawler.RuleSet();

   allow->add_rule(Web.Crawler.GlobRule(profile->site + "*"));
   q=Web.Crawler.MemoryQueue(Web.Crawler.Stats(2,1),Web.Crawler.Policy(), allow, deny);


crawler=Web.Crawler.Crawler(
q,
page_cb, 
error_cb,
done_cb, 
0, url, 0); 
   return -1;
}


class Indexer
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


static object index_class = FINDCLASS("net/caudium/search/Indexer");
static object summary_class = FINDCLASS("net/caudium/search/URLSummary");

static object index_init = index_class->get_method("<init>", "(Ljava/lang/String;Z)V");
static object summary_init = summary_class->get_method("<init>", "()V");
static object index_close = index_class->get_method("close", "()V");
static object index_add = index_class->get_method("add", "(Lnet/caudium/search/URLSummary;)V");

static object summary_url=summary_class->get_field("url", "Ljava/lang/String;");
static object summary_body=summary_class->get_field("body", "Ljava/lang/String;");
static object summary_desc=summary_class->get_field("desc", "Ljava/lang/String;");
static object summary_title=summary_class->get_field("title", "Ljava/lang/String;");
static object summary_type=summary_class->get_field("type", "Ljava/lang/String;");
static object summary_date=summary_class->get_field("date", "Ljava/lang/String;");

object ie;

void create(string datadir)
{
  ie=index_class->alloc();
  index_init(ie, datadir, 0);
  check_exception();
}

void destroy()
{
  if(verbose)
    werror("closing db\n");
  index_close(ie);
}
 
void close()
{
  index_close(ie);
}

int index(string uri, string data, string title, string type, string date)
{
  //werror(data + "\n\n");
  object us=summary_class->alloc();
  check_exception();
  summary_init(us);
  check_exception();
  summary_url->set(us, uri);
  check_exception();
  summary_body->set(us, data);
  check_exception();
  summary_title->set(us, title);
  check_exception();
  summary_desc->set(us, (sizeof(data)<254?data:data[0..253]+"..."));
  check_exception();
  summary_date->set(us, date);
  check_exception();
  summary_type->set(us, type);
  check_exception();
  index_add(ie, us);
  check_exception();
//werror((string)us);
  return 1;
}

#define error(X) throw(({(X), backtrace()})) 
static void check_exception() {
 jvm->exception_describe();
}

}

#endif
