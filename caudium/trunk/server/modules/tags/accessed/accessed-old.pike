/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
 */
/*
 * $Id$
 */

//! module: Accessed Counter Tag: Old Version
//!  This module will provide an &lt;accessed&gt; tag based
//!  on Core RXML Parser as it was done before.
//! type: MODULE_PARSER
//! cvs_version: $Id$"

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "caudiumlib14";

constant language = caudium->language;

constant module_type = MODULE_PARSER;
constant module_name = "Accessed Counter Tag: Old Version";
constant module_doc  = "This module will provide an &lt;accessed&gt; tag "
                       "based on Core RXML Parser as it was done before.";
constant module_unique = 1;

int cnum=0;
mapping fton=([]);

object database, names_file;

// Core RXML tags module from what we get some functions.
#define RXMLTAGS id->conf->get_provider("rxml:tags");

void create()
{
  defvar("Accesslog", 
	 GLOBVAR(logdirprefix)+
	 Caudium.short_name(caudium->current_configuration?
		            caudium->current_configuration->name:".")+"/Accessed", 
	 "Access log file", TYPE_FILE|VAR_MORE,
	 "In this file all accesses to files using the &lt;accessed&gt;"
	 " tag will be logged.");

  defvar("noparse", ({  }), "Extensions to access count",
          TYPE_STRING_LIST,
         "Always access count all files ending with these extensions. "
	 "Note: This module must be reloaded for a change here to take "
	 "effect.");

  defvar("close_db", 1, "Close the database if it is not used",
	 TYPE_FLAG|VAR_MORE,
	 "If set, the accessed database will be closed if it is not used for "
	 "8 seconds");
}

static string olf; // Used to avoid reparsing of the accessed index file...

static mixed names_file_callout_id;

inline void open_names_file()
{
  if(objectp(names_file)) return;
  remove_call_out(names_file_callout_id);
  names_file=open(QUERY(Accesslog)+".names", "wrca");
  names_file_callout_id = call_out(destruct, 1, names_file);
}

#ifdef THREADS
object db_lock = Thread.Mutex();
#endif /* THREADS */


static void close_db_file(object db)
{
#ifdef THREADS
  mixed key = db_lock->lock();
#endif /* THREADS */
  if (db) {
    destruct(db);
  }
}

static mixed db_file_callout_id;

inline mixed open_db_file()
{
  mixed key;
#ifdef THREADS
  catch { key = db_lock->lock(); };
#endif /* THREADS */
  if(objectp(database)) return key;
  if(!database)
  {
    if(db_file_callout_id) remove_call_out(db_file_callout_id);
    database=open(QUERY(Accesslog)+".db", "wrc");
    if (!database) {
      throw(({ sprintf("Failed to open \"%s.db\". "
		       "Insufficient permissions or out of fd's?\n",
		       QUERY(Accesslog)), backtrace() }));
    }
    if (QUERY(close_db)) {
      db_file_callout_id = call_out(close_db_file, 9, database);
    }
  }
  return key;
}


string status()
{
  return sizeof(fton)+" entries in the accessed database<br>";
}

void start()
{
  mixed tmp;

  if(olf != QUERY(Accesslog))
  {
    olf = QUERY(Accesslog);
    Stdio.mkdirhier(dirname(query("Accesslog")));
    if(names_file=open(olf+".names", "wrca"))
    {
      cnum=0;
      tmp=spider.parse_accessed_database(names_file->read(0x7ffffff));
      fton=tmp[0];
      cnum=tmp[1];
      names_file = 0;
    }
  }
}

static int mdc;
int main_database_created()
{
  if(!mdc)
  {
    mixed key = open_db_file();
    database->seek(0);
    sscanf(database->read(4), "%4c", mdc);
    return mdc;
  }
  return mdc;
}

int database_set_created(string file, void|int t)
{
  int p;

  p=fton[file];
  if(!p) return 0;
  mixed key = open_db_file();
  database->seek((p*8)+4);
  return database->write(sprintf("%4c", t||time(1)));
}

int database_created(string file)
{
  int p,w;

  p=fton[file];
  if(!p) return main_database_created();
  mixed key = open_db_file();
  database->seek((p*8)+4);
  sscanf(database->read(4), "%4c", w);
  if(!w || (w>>31) > 0)
  {
    w=main_database_created();
    database_set_created(file, w);
  }
  return w;
}

int query_num(string file, int count) {
  int p, n;
  string f;

  mixed key = open_db_file();

  // if(lock) lock->aquire();
  
  if(!(p=fton[file]))
  {
    if(!cnum)
    {
      database->seek(0);
      database->write(sprintf("%4c", time(1)));
    }
    fton[file]=++cnum;
    p=cnum;

//  perror(file + ": New entry.\n");
    open_names_file();
//  perror(file + ": Created new entry.\n");
    names_file->write(file+":"+cnum+"\n");

    database->seek(p*8);
    database->write(sprintf("%4c", 0));
    database_set_created(file);
  }
  if(database->seek(p*8) > -1)
  {
    sscanf(database->read(4), "%4c", n);
//  perror("Old count: " + n + "\n");
    if (count) 
    { 
//    perror("Adding "+count+" to it..\n");
      n+=count; 
      database->seek(p*8);
      database->write(sprintf("%4c", n)); 
    }
    //lock->free();
    return n;
  } 
//perror("Seek failed\n");
  //lock->free();
  return 0;
}

// To inform Caudium that this module will handle some extensions (used
// to hanlde "always count" extensions.
array(string) query_file_extensions() {
  return QUERY(noparse); 
}

// Handle "always count" extensions.
mapping handle_file_extension( object file, string e, object id) {
  mapping defines = id->misc->defines || ([]);
  id->misc->defines = defines;

  if(search(QUERY(noparse),e)!=-1)
  {
    query_num(id->not_query, 1);
    defines->counted = "1";
  }
  return 0;
}

//! tag: accessed
//!  <tt>&lt;accessed&gt;</tt> generates an access counter that shows how many
//!  times the page has been accessed. In combination with the
//!  <tt>&lt;gtext&gt;</tt>tag you can generate one of those popular graphical
//!  counters.
//!  <p>A file, <i>Accesslog</i>, in the logs directory is used to
//!  store the number of accesses to each page. Thus it will use more
//!  resources than most other tags and can therefore be deactivated.
//!  By default the access count is only kept for files that actually
//!  contain an <tt>&lt;accessed&gt;</tt> tag, but you can optionally
//!  force access counting on file extension basis.</p>
//! 
//! attribute: add
//!  Increments the number of accesses with this number instead of one,
//!  each time the page is accessed.
//! attribute: addreal
//!  Prints the real number of accesses as an HTML comment. Useful if you
//!  use the <tt>cheat</tt> attribute and still want to keep track of the
//!  real number of accesses.
//! attribute: capitalize
//!  Capitalizes the first letter of the result.
//! attribute: cheat
//!  Adds this number of accesses to the actual number of accesses before
//!  printing the result. If your page has been accessed 72 times and you
//!  add <doc>{accessed cheat="100"}</doc> the result will be 172.
//! attribute: factor
//!  Multiplies the actual number of accesses by the factor.
//! attribute: file
//!  Shows the number of times the page <i>filename</i> has been
//!  accessed instead of how many times the current page has been accessed.
//!  If the filename does not begin with "/", it is assumed to be a URL
//!  relative to the directory containing the page with the
//!  <tt>&lt;accessed /&gt;</tt> tag. Note, that you have to type in the full name
//!  of the file. If there is a file named tmp/index.html, you cannot
//!  shorten the name to tmp/, even if you've set Caudium up to use
//!  index.html as a default page. The <i>filename</i> refers to the
//!  <b>virtual</b> filesystem.
//! 
//!  <p>One limitation is that you cannot reference a file that does not
//!  have its own <doc>{accessed}</doc> tag. You can use <doc>{accessed
//!  silent="silent" /}</doc> on a page if you want it to be possible to count accesses
//!  to it, but don't want an access counter to show on the page itself.</p>
//! attribute: lang
//!  Will print the result as words in the chosen language if used together
//!  with <tt>type=string</tt>. Available languages are ca, es_CA
//!  (Catala), hr (Croatian), cs (Czech), nl (Dutch), en (English), fi
//!  (Finnish), fr (French), de (German), hu (Hungarian), it (Italian), jp
//!  (Japanese), mi (Maori), no (Norwegian), pt (Portuguese), ru (Russian),
//!  sr (Serbian), si (Slovenian), es (Spanish) and sv (Swedish).
//! attribute: lower
//!  Prints the result in lowercase.
//! attribute: per
//!  Shows the number of accesses per unit of time (one of minute, hour, 
//!  day, week and month).
//! attribute: prec
//!  Rounds the number of accesses to this number of significant digits. If
//!  <tt>prec="2"</tt> show 12000 instead of 12148.
//! attribute: reset
//!  Resets the counter. This should probably only be done under very
//!  special conditions, maybe within an <doc>{if}{/if}</doc> statement.
//!  <p>This can be used together with the file argument, but it is limited
//!  to files in the current- and sub-directories.</p>
//! attribute: silent
//!  Print nothing. The access count will be updated but not printed. This
//!  option is useful because the access count is normally only kept for
//!  pages with actual <tt>&lt;access&gt;</tt> on them. <doc>{accessed
//!  file="filename" /}</doc> can then be used to get the access count for the
//!  page with the silent counter.
//! attribute: upper
//!  Print the result in uppercase.
//! attribute: since
//!  Inserts the date that the access count started. The language will
//!  depend on the <tt>lang</tt> tag, default is English. All normal [date]
//!  related attributes can be used. See the <tt>&lt;date&gt;</tt> tag.
//! attribute: type
//!  Specifies how the count are to be presented. Some of these are only
//!  useful together with the <tt>since</tt> attribute.
//! example: rxml
//!  This page has been accessed
//!  {accessed type="string" cheat="90" addreal /}
//!  times since {accessed since="since" /}.
//
string tag_accessed(string tag,mapping m,object id,object file, 
		    mapping defines) {
  int counts, n, prec, q, timep;
  string real, res;

  NOCACHE();
  if(m->file)
  {
    m->file = Caudium.fix_relative(m->file, id);
    if(m->add) 
      counts = query_num(m->file, (int)m->add||1);
    else
      counts = query_num(m->file, 0);
  } else {
    if(Caudium._match(id->remoteaddr, id->conf->query("NoLog")))
      counts = query_num(id->not_query, 0);
    else if(defines->counted != "1") 
    {
      counts =query_num(id->not_query, 1);
      defines->counted = "1";
    } else {
      counts = query_num(id->not_query, 0);
    }
      
    m->file=id->not_query;
  }
  
  if(m->reset)
  {
    if( !search( (dirname(m->file)+"/")-"//",
		 (dirname(id->not_query)+"/")-"//" ) )
    {
      query_num(m->file, -counts);
      database_set_created(m->file, time(1));
      return "Number of counts for "+m->file+" is now 0.<br>";
    } else {
      // On a web hotell you don't want the guest to be able to reset
      // eachothers counters.
      return "You do not have access to reset this counter.";
    }
  }

  if(m->silent)
    return "";

  if(m->since) {
    object rxmltags_module = RXMLTAGS;
    if(objectp(rxmltags_module)) {
      if(m->database)
        return rxmltags_module->tagtime(database_created(0),m);
      return rxmltags_module->tagtime(database_created(m->file),m);
   }
  }

  real="<!-- ("+counts+") -->";

  counts += (int)m->cheat;

  if(m->factor)
    counts = (counts * (int)m->factor) / 100;

  if(m->per)
  {
    timep=time(1) - database_created(m->file) + 1;
    
    switch(m->per)
    {
     case "second":
      counts /= timep;
      break;

     case "minute":
      counts = (int)((float)counts/((float)timep/60.0));
      break;

     case "hour":
      counts = (int)((float)counts/(((float)timep/60.0)/60.0));
      break;

     case "day":
      counts = (int)((float)counts/((((float)timep/60.0)/60.0)/24.0));
      break;

     case "week":
      counts = (int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/7.0));
      break;

     case "month":
      counts = (int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/30.42));
      break;

     case "year":
      counts=(int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/365.249));
      break;

    default:
      return "<!-- Per what? -->";
    }
  }

  if(prec=(int)m->precision || (int)m->prec)
  {
    n=Caudium.ipow(10, prec);
    while(counts>n) { counts=(counts+5)/10; q++; }
    counts*=Caudium.ipow(10, q);
  }

  switch(m->type)
  {
   case "mcdonalds":
    q=0;
    while(counts>10) { counts/=10; q++; }
    res="More than "+caudium->language("eng", "number")(counts*Caudium.ipow(10, q))
        + " served.";
    break;
    
   case "linus":
    res=counts+" since "+ctime(database_created(0));
    break;

   case "ordered":
    m->type="string";
    res=Caudium.number2string(counts,m,language(m->lang, "ordered"));
    break;

   default:
    res=Caudium.number2string(counts,m,language(m->lang, "number"));
  }
  return res+(m->addreal?real:"");
}                  

mapping query_tag_callers()
{
   return (["accessed":tag_accessed,
   ]);
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: noparse
//! Always access count all files ending with these extensions. Note: This module must be reloaded for a change here to take effect.
//!  type: TYPE_STRING_LIST
//!  name: Extensions to access count
//
//! defvar: close_db
//! If set, the accessed database will be closed if it is not used for 8 seconds
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Close the database if it is not used
//
