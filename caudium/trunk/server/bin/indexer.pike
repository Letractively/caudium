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

  index=Lucene.Indexer(profile->dbdir);


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

#endif
