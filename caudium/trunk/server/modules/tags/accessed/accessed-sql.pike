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

// From what module we take some functions
#define RXMLTAGS id->conf->get_provider("rxml:tags")

//! module: Accessed Counter Tag: SQL
//!  This module provides access counters, through the &lt;accessed&gt; tag.
//! type: MODULE_PARSER | MODULE_LOGGER | MODULE_EXPERIMENTAL
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$
// note: depends of module provider "rxml:tags"
#include <module.h>

inherit "module";
inherit "caudiumlib";

constant cvs_version   = "$Id$";
constant thread_safe    = 1;
constant module_type   = MODULE_PARSER | MODULE_LOGGER | MODULE_EXPERIMENTAL;
constant module_name   = "Accessed Counter Tag: SQL";
// Kiwi: we do not support yet entities so =)
//constant module_doc    = "This module provides access counters, through the "
constant module_doc    = "This module provides access counters, through the "
"<tt>&lt;accessed&gt;</tt> tag.";
constant module_unique=1;
constant language = roxen->language;

object counter;

string status() {
  return counter->size()+" entries in the accessed database.<br />";
}

void create(object c) {

  //------ Global defvars

  defvar("extcount", ({  }), "Extensions to access count",
          TYPE_STRING_LIST,
         "Always count accesses to files ending with these extensions. "
	 "By default only accessed to files that actually contain a "
	 "<tt>&lt;accessed&gt;</tt> tag or the <tt>&amp;page.accessed;</tt> "
	 "entity will be counted. "
	 "<p>Note: This module must be reloaded before a change of this "
	 "setting takes effect.</p>");

  defvar("restrict", 1, "Restrict reset", TYPE_FLAG, "Restrict the attribute reset "
	 "so that the resetted file is in the same directory or below.");

  defvar("sqldb", "mysql://localhost", "SQL Database", TYPE_STRING, 
	 "What database to use for the database backend." );

  defvar("table", "accessed", "SQL Table", TYPE_STRING,
	 "Which table should be used for the database backend." );

  defvar("serverinpath",1,"Add server Id in SQL table", TYPE_FLAG|VAR_MORE,
         "Add the server Id in the SQL table. <b>Note</b>: you will lose "
	 "Roxen 2.x compatibility if this enabled.");

  defvar("serverid","www.domain.com","Id to add in SQL table",
         TYPE_STRING|VAR_MORE,"This will be added in the SQL database as "
	 "unique Id. <b>Note</b>: if you change this Id, <b>ALL</b> "
	 "counter data will be reset to 0.");
}

void start(int cnt, object conf) {
  // Depends of rxmltags 
  module_dependencies(conf ,({ "rxmltags" }));
  //  query_tag_set()->prepare_context=set_entities;
  counter=SQLCounter();
}

// Kiwi: Can someone do an compatible entity for this module ???

//class Entity_page_accessed {
//  int rxml_var_eval(RXML.Context c) {
//    c->id->misc->cacheable=0;
//    if(!c->id->misc->accessed) {
//      counter->add(c->id->not_query, 1);
//      c->id->misc->accessed=1;
//    }
//    return counter->query();
//  }
//}

//void set_entities(RXML.Context c) {
//  c->set_var("accessed", Entity_page_accessed(), "page");
//}


class SQLCounter {
  // SQL backend counter.

  object db;

  string table,servername;
  int srvname = 0;

  void create() {
    db=Sql.Sql(module::query("sqldb"));
    table = module::query("table");
    if (module::query("serverinpath")) {
      srvname = 1;
      servername = module::query("serverid");
    }
    else {
      srvname = 0;
      servername= "";
    }
    catch {
      db->query("CREATE TABLE "+table+" (path VARCHAR(255) PRIMARY KEY,"
		" hits INT UNSIGNED DEFAULT 0, made INT UNSIGNED)");
      // Kiwi: need to be fixed (used if file doesn't exist)
      db->query("INSERT INTO "+table+" (path,made) VALUES ('///',"+time(1)+")" );
    };
  }

  int creation_date(void|string file) {
    if(!file) file="///";
    array x=db->query("SELECT made FROM "+table+" WHERE path='"+servername+fix_file(file)+"'");
    return x && sizeof(x) && (int)(x[0]->made);
  }

  private void create_entry(string file) {
    if(!cache_lookup("access_entry", file)) {
      catch(db->query("INSERT INTO "+table+" (path,made) VALUES ('"+servername+file+"',"+time(1)+")" ));
      cache_set("access_entry", file, 1);
    }
  }

  private string fix_file(string file) {
    if(sizeof(file)>255)
      file="//"+MIME.encode_base64(Caudium.Crypto.hash_md5(file),1);
    return db->quote(file);
  }

  void add(string file, int count) {
    file=fix_file(file);
    create_entry(file);
    db->query("UPDATE "+table+" SET hits=hits+"+(count||1)+" WHERE path='"+servername+file+"'" );
  }

  int query(string file) {
    file=fix_file(file);
    array x=db->query("SELECT hits FROM "+table+" WHERE path='"+servername+file+"'");
    return x && sizeof(x) && (int)(x[0]->hits);
  }

  void reset(string file) {
    file=fix_file(file);
    create_entry(file);
    db->query("UPDATE "+table+" SET hits=0 WHERE path='"+servername+file+"'");
  }

  int size() {
    array x=db->query("SELECT count(*) from "+table);
    return (int)(x[0]["count(*)"])-1;
  }
}

// --- Log callback ------------------------------------

int log(object id, mapping file) {
  if(id->misc->accessed || query("extcount")==({})) {
    return 0;
  }

  // Although we are not 100% sure we should make a count,
  // nothing bad happens if we shouldn't and still do.
  int a, b=sizeof(id->realfile);
  foreach(query("extcount"), string tmp)
    if(a=sizeof(tmp) && b>a &&
       id->realfile[b-a..]=="."+tmp) {
      counter->add(id->not_query, 1);
      id->misc->accessed = "1";
    }

  return 0;
}

// --- Tag definition ----------------------------------

// Cut & paste from rxmltags.pike (need to be tested)
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


string tag_accessed(string tag, mapping m, object id)
{
  NOCACHE();

  if(m->reset) {
    if( !query("restrict") || !search( (dirname(Caudium.fix_relative(m->file, id))+"/")-"//",
		 (dirname(Caudium.fix_relative(id->not_query, id))+"/")-"//" ) )
    {
      counter->reset(m->file);
      return "Number of counts for "+m->file+" is now 0.<br />";
    }
    else
      // On a web hotell you don't want the guests to be alowed to reset
      // eachothers counters.
      return "You do not have access to reset this counter.";
  }

  int counts = id->misc->accessed;

  if(m->file) {
    m->file = Caudium.fix_relative(m->file, id);
    if(m->add) counter->add(m->file, (int)m->add);
    counts = counter->query(m->file);
  }
  else {
    if(!Caudium._match(id->remoteaddr, id->conf->query("NoLog")) &&
       !id->misc->accessed) {
      counter->add(id->not_query, (int)m->add);
    }
    m->file=id->not_query;
    counts = counter->query(m->file);
    id->misc->accessed = counts;
  }
 
  if(m->silent)
    return "";

  if(m->since) {
    object rxmltags_module = RXMLTAGS;
    if (objectp(rxmltags_module))
    {
     if(m->database)
      return rxmltags_module->api_tagtime(counter->creation_date(), m, id, language); // From rxmltags
     return rxmltags_module->api_tagtime(counter->creation_date(m->file), m, id, language);
    }
    return "<!-- No RXML Tag module ? -->";
  }

  string real="<!-- ("+counts+") -->";

  counts += (int)m->cheat;

  if(m->factor)
    counts = (counts * (int)m->factor) / 100;

  if(m->per)
  {
    int timep=time(1) - counter->creation_date(m->file) + 1;

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
      return "Access count per what?";
    }
  }

  int prec, q;
  if(prec=(int)m->prec)
  {
    int n=10->pow(prec);
    while(counts>n) { counts=(counts+5)/10; q++; }
    counts*=10->pow(q);
  }

  string res;

  switch(m->type) {
  case "mcdonalds":
    q=0;
    while(counts>10) { counts/=10; q++; }
    res="More than "+language("eng", "number")(counts*10->pow(q))
        + " served.";
    break;

  case "linus":
    res=counts+" since "+ctime(counter->creation_date());
    break;

  case "ordered":
    m->type="string";
    res=Caudium.number2string(counts, m, language(m->lang, "ordered"));
    break;

  default:
    res=Caudium.number2string(counts, m, language(m->lang, "number"));
  }

  if(m->minlength) {
    m->minlength=(int)(m->minlength);
    if(m->minlength>10) m->minlength=10;
    if(m->minlength<2) m->minlength=2;
    if(!m->padding || !sizeof(m->padding)) m->padding="0";
    if(sizeof(res)<m->minlength)
      res=(m->padding[0..0])*(m->minlength-sizeof(res))+res;
  }

  return res+(m->addreal?real:"");
}

mapping query_tag_callers()
{
  // Kiwi: Renamed this to accessed when this module is marked as Ok =)
  return([ "accessed2":tag_accessed ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: extcount
//! Always count accesses to files ending with these extensions. By default only accessed to files that actually contain a <tt>&lt;accessed&gt;</tt> tag or the <tt>&amp;page.accessed;</tt> entity will be counted. <p>Note: This module must be reloaded before a change of this setting takes effect.</p>
//!  type: TYPE_STRING_LIST
//!  name: Extensions to access count
//
//! defvar: restrict
//! Restrict the attribute reset so that the resetted file is in the same directory or below.
//!  type: TYPE_FLAG
//!  name: Restrict reset
//
//! defvar: sqldb
//! What database to use for the database backend.
//!  type: TYPE_STRING
//!  name: SQL Database
//
//! defvar: table
//! Which table should be used for the database backend.
//!  type: TYPE_STRING
//!  name: SQL Table
//
//! defvar: serverinpath
//! Add the server Id in the SQL table. <b>Note</b>: you will lose Roxen 2.x compatibility if this enabled.
//!  type: TYPE_FLAG|VAR_MORE
//!  name: Add server Id in SQL table
//
//! defvar: serverid
//! This will be added in the SQL database as unique Id. <b>Note</b>: if you change this Id, <b>ALL</b> counter data will be reset to 0.
//!  type: TYPE_STRING|VAR_MORE
//!  name: Id to add in SQL table
//
