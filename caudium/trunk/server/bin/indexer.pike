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

import Parser.XML.Tree;

#if constant(Java)

static constant jvm = Java.machine;

int start;
int files;
int filesize;
string profile_path;
int verbose;
object index;
mapping profile=([]);
mapping converters=([]);
multiset allowed_types=(<>);
multiset denied_types=(<>);
object crawler;

void display_help()
{
   werror("usage: indexer.pike [-v] --profile=/path/to/profile\n");
   exit(0);
}

void error_cb(mixed real_uri, int status, mapping headers)
{
  werror("error " + status + " received for " + (string)real_uri + "\n");
}
void done_cb()
{
  if(verbose)
  {
    werror("Indexer finished at " + ctime(time()) + "\n");
    werror(" Indexed " + files + " files, " + filesize + " bytes in " + (time()-start) + "  seconds.\n");
  } 
  if(verbose)
    werror("Moving old database out of the way.\n");
  destruct(index);
  mv(profile->index->location[0]->value, 
    profile->index->location[0]->value + ".old");
  if(verbose)
    werror("Moving new database into place.\n");
  mv(profile->index->location[0]->value + ".work", 
    profile->index->location[0]->value);
  if(verbose)
    werror("Deleting old database.\n");
  Stdio.recursive_rm(profile->index->location[0]->value + ".old");
  quit();
}

void abort()
{
   werror("aborting crawl. existing data will not be replaced.\n");
   destruct(index);
   Stdio.recursive_rm(profile->index->location[0]->value + ".work");
   quit();
}

object parser, stripper;
object current_uri;

int allowed_type(string type)
{
   foreach(indices(denied_types), string t)
   {
     if(glob(t, type)) return 0;
   }
   foreach(indices(allowed_types), string t)
   {
     if(glob(t, type)) return 1;
   }
   return 0;
}

array prepare_cb(Standards.URI uri)
{
  if(profile->crawler->http_user||profile->crawler->http_password)
  {
    string s=profile->crawler->http_user[0]->value + ":" + 
      profile->crawler->http_password[0]->value;
    return ({uri, (["authorization": "Basic " + MIME.encode_base64(s)])});
  }

  return ({uri, ([])}); 
}

array page_cb(Standards.URI uri, mixed data, mapping headers, mixed ... args)
{
  werror((string)uri + "\n");
  if(!allowed_type((headers["content-type"]/";")[0]))
    return ({});
  files++;
  filesize+=sizeof(data);
  page_urls=({});
  current_uri=uri;
  string type=(headers["content-type"]/";")[0]||"unknown/unknown";
  string date=headers["last-modified"]||"";
  if(verbose)
    werror("  Content type: " + type  + "\n");


  if(converters[type])
  {
    data=converters[type]->convert(data);
  }
  if(!data || !strlen(data)) 
  {
     if(verbose)
       werror("  ...converter returned no data\n");
  }
  else
  {
//    data=map(data, lambda(mixed x){catch { if((int)(x)>254) return; else return x; };});
//    werror("data: " + data);
     parser->feed(data);  
    data=parser->read();
//    werror("data2: " + data);
    stripper->feed(data);
    data=stripper->read();
//    werror("data3: " + data);
    if(verbose)
      werror("  ...indexing\n");
    index->index((string)uri, data, title, type, date);    
    title="";
  }
  if(verbose && sizeof(page_urls)) werror(sprintf("  Possible new URLS: %O\n", page_urls));
  return page_urls;
}

string title;
array page_urls=({});

mixed set_title(Parser.HTML p, mapping args, string content)
{
werror("set title " + content + "\n");
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
    exit(1);
}

mixed strip_tag(Parser.HTML p, string t)
{
  return "";
}

mixed continue_tag(Parser.HTML p, mapping args, string t)
{
   werror("continuing on " + t + "\n");
  return 0;
}

int main(int argc, array argv)
{
   signal(2, abort);
   signal(3, abort);
   signal(6, abort);
   signal(9, abort);

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

  start=time();
  profile=Lucene->read_profile(profile_path);
  werror("Indexer starting at " + (ctime(start)-"\n") + " for profile " 
    + profile->name + "\n");

  // load the stopwords file, if any.
  array stopwords=({});
  if(profile->index->stopwordsfile)
  {
    stopwords=Lucene->load_stopwords(profile->index->stopwordsfile);
  }
  werror("Lucene Database location: " + profile->index->location[0]->value + "\n");
  index=Lucene.Indexer(profile->index->location[0]->value + ".work", stopwords);


  // load the starting urls
   array urls=({});
   if(profile->crawler->startingpoint)
     foreach(profile->crawler->startingpoint, mapping s)
     {
       werror("Adding Starting Point " + s->value + "\n");
       urls+=({s->value});
     }

   // now we do the allow/deny rules
   object allow=Web.Crawler.RuleSet();
   object deny=Web.Crawler.RuleSet();
   if(profile->crawler->allow)
     foreach(profile->crawler->allow, mapping s)
     {
       werror("Adding Allow Rule " + s->type + " " + s->value + "\n");
       if(s->type=="glob")
         allow->add_rule(Web.Crawler.GlobRule(s->value));
       if(s->type=="regexp")
         allow->add_rule(Web.Crawler.RegexpRule(s->value));
     }
   if(profile->crawler->deny)
     foreach(profile->crawler->deny, mapping s)
     {
       werror("Adding Deny Rule " + s->type + " " + s->value + "\n");
       if(s->type=="glob")
         deny->add_rule(Web.Crawler.GlobRule(s->value));
       if(s->type=="regexp")
         deny->add_rule(Web.Crawler.RegexpRule(s->value));
     }
    
   // set up allowed/denied types
   if(profile->indexer->allowtype)
     foreach(profile->indexer->allowtype, mapping t)
     {
        werror("Adding Allowed datatype " + t->value + "\n");
        allowed_types+=(<t->value>);
     }
   if(profile->indexer->denytype)
     foreach(profile->indexer->denytype, mapping t)
     {
        werror("Adding Denied datatype " + t->value + "\n");
        denied_types+=(<t->value>);
     }


   setup_converters();

   q=Web.Crawler.MemoryQueue(Web.Crawler.Stats(2,1),Web.Crawler.Policy(), allow, deny);


   call_out(print_update, 60);

  crawler=Web.Crawler.Crawler(q, page_cb, error_cb, done_cb, prepare_cb, urls, 0); 
  return -1;
}

void print_update()
{
  werror("Indexed " + files + ", " + filesize + " bytes\n" );
  call_out(print_update, 60);
}

void setup_converters()
{
  setup_html_converter();
  if(profile->converters->converter)
    foreach(profile->converters->converter, mapping c)
    {
      werror("Configuring converter for " + c->mimetype + "\n");
      if(c->type=="filter")
        converters[c->mimetype]=Lucene.Indexer.Filter(c->value);
      if(c->type=="converter")
        converters[c->mimetype]=Lucene.Indexer.Converter(c->value, profile->indexer->temp[0]->value);
      else werror("unknown converter type " + c->type +  " for mime type " + c->mimetype + "\n");
    }

      werror("Configuring internal converter for text/plain\n");
  converters["text/plain"]=Lucene.Indexer.PikeFilter(lambda(string d){ return d;});
      werror("Configuring internal converter for text/html\n");
  converters["text/html"]=Lucene.Indexer.PikeFilter(lambda(string d){ return d;});

}

void setup_html_converter()
{
   parser=Parser.HTML();
   stripper=Parser.HTML();
/*
   parser->case_insensitive_tag(1);
   stripper->case_insensitive_tag(1);
   parser->lazy_entity_end(1);
   parser->ignore_unknown(1);
   stripper->lazy_entity_end(1);
*/
   parser->add_container("title", set_title);
//   parser->add_container("pre", continue_tag);
   parser->add_container("a", add_url);
   parser->add_container("script", strip_tag);
   parser->add_container("style", strip_tag);
   stripper->_set_tag_callback(strip_tag);
}

#endif
