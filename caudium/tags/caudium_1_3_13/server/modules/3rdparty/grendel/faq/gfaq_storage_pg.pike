/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
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
 * $Id$
 */

/*
 *
 * The gFaq module and the accompanying code is 
 * Copyright © 2002 Davies, Inc
 *
 * This code is released under the LGPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *  Marek Habersack <grendel@caudium.net>
 */

constant cvs_version = "$Id$";

#include <module.h>
#include <caudium.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PROVIDER;
constant module_name = "gFAQ PostgreSQL Storage Provider";
constant module_doc  = "Module implementing a PostgreSQL storage provider for the gFAQ module.";
constant module_unique = 0;

#if constant(thread_create)
constant thread_safe = 1;

private static object db_lock;
#define LOCK() do { object key; if (db_lock) db_lock = Thread.Mutex(); catch(key = db_lock->lock())
#define UNLOCK() key = 0; } while(0)
#else
constant thread_safe = 0;
#define LOCK()
#define UNLOCK()
#endif

static private object   db = 0;

void create()
{
  defvar("pg_db", "postgres://localhost/faq", "Database URI", TYPE_STRING,
         "URI of the database with the FAQ data. This module <strong>REQUIRES</strong> "
         "the database to be PostgreSQL.");
}

void start(int count, object conf)
{
  module_dependencies(conf, ({"gfaq"}));
}

string query_provides()
{
  return "faq_storage_pg";
}

private void open_database(object id)
{
  if (db && objectp(db))
    return;

  mixed error;
  
  LOCK();
  if (id->conf->sql_connect)
    db = id->conf->sql_connect(QUERY(pg_db));
  else
    db = Sql.sql(QUERY(pg_db));
  UNLOCK();

  if (!db)
    throw(({"Unable to open the FAQ database", backtrace()}));
}

array(mapping) get_entries(object id, mapping options, string|void path)
{
  mixed   error;
  
  error = catch {
    open_database(id);
  };

  if (error) {
    report_error("gFAQ_pg: error opening database: %s\n",
                 error[0]);
    return ({});
  }

  if (!options)
    options = ([]);

  if (!path)
    path = "/0";
  
  array   results;
  // ugliness!!!! :->>
  string  regexp, select = "q.id,q.section,q.has_annot,q.question,q.path,q.isqa,q.rating,q.votes,q.users,q.groups,q.seealso,s.question as squestion,s.path as spath,s.id as sid";
  string  fixed_path;

  if (sizeof(path) >= 2 && path[-1] == '/')
    fixed_path = path[0..(sizeof(path) - 2)];
  else
    fixed_path = path;
  
  if (!options->titleonly)
    select += ",q.answer";

  if (options->sections)
    regexp = ".*";
  else if (!fixed_path || !sizeof(fixed_path) || fixed_path == "/0") {
    regexp = "^/[0-9]*";

    // reset them here - they're also kept in the session store, but that's
    // handled below
    id->variables->cursectiontitle = "Index";
    id->variables->cursectionnum = "0";
  } else {
    regexp = "^" + fixed_path + "/";
    regexp += "[0-9]*";
  }

  if (!options->tree)
      regexp += "$";
  
  string query = sprintf("select %s from faq q, faq s where q.section = s.id and (q.path ~ '%s' or q.path = '%s')%s",
                         select, regexp, fixed_path, options->sections ? " and q.isqa = 'f'" : "");
  
  error = catch {
    results = db->query(query);
  };

  report_notice("result (query %O): %O\n", query, results);

  // convert all the results to the format expected by the FAQ module
  array(mapping)    ret = ({});

  if (!id->misc->session_variables->gfaq)
    id->misc->session_variables->gfaq = ([]);
  id->misc->session_variables->gfaq->current_entry = 0;
  
  foreach(results, mapping result) {
    string sectnum = replace(result->spath, "/", ".")[1..];

    if (result->isqa[0] == 'f' && result->path == fixed_path) {
      if (id->misc->session_variables) {
        id->misc->session_variables->gfaq->last_section_title = result->squestion;
        id->misc->session_variables->gfaq->last_section_path = result->spath;
        id->misc->session_variables->gfaq->last_section_num = sectnum;
      }

      id->variables->cursectiontitle = result->squestion;
      id->variables->cursectionnum = sectnum;
      
      continue;
    } else if (result->isqa[0] != 'f') {
      id->variables->cursectiontitle = result->squestion;
      id->variables->cursectionnum = sectnum;
    }
    
    ret += ({([])});
    ret[-1]->contents = ([]);
    ret[-1]->contents->title = result->question;
    ret[-1]->contents->rating = result->rating;
    ret[-1]->contents->votes = result->votes;
    ret[-1]->contents->number = replace(result->path, "/", ".")[1..];
    ret[-1]->contents->isqa = result->isqa[0] == 't' ? "yes" : "no";
    ret[-1]->contents->annotated = result->has_annot[0] == 't' ? "yes" : "no";
    
    if (!options->titleonly)
      ret[-1]->contents->text = result->answer;
    ret[-1]->path = result->path;
    if (result->seealso != "")
      ret[-1]->see_also = result->seealso[1..(strlen(result->seealso)-2)] / ",";
    else
      ret[-1]->see_also = ({});

    if (result->groups != "")
      ret[-1]->groups = result->groups[1..(strlen(result->groups)-2)] / ",";
    else
      ret[-1]->groups = ({});

    if (result->users != "")
      ret[-1]->users = result->users[1..(strlen(result->users)-2)] / ",";
    else
      ret[-1]->users = ({});
    
    ret[-1]->squestion = result->squestion;
    ret[-1]->spath = result->spath;
    ret[-1]->section = result->section;
    ret[-1]->id = result->id;
    ret[-1]->sid = result->sid;
    
    if (result->path == fixed_path)
      id->misc->session_variables->gfaq->current_entry = ret[-1];
  }

  report_notice("returning: %O\n", ret);
  
  return ret;
}

string|int put_entries(object id, mapping data, array(mapping) entries)
{
  report_notice("put_entries data: %O\nput_entries entries: %O\n",
                data, entries);

  mixed   error;
  
  error = catch {
    open_database(id);
  };

  if (error) {
    report_error("gFAQ_pg: error opening database: %s\n",
                 error[0]);
    return "Error opening database";
  }
  
  string tquery = "update faq set ";
  array  results = ({});

  error = catch {
    results = db->query("begin transaction");
  };

  array(string) queries = ({});

  // for now let's disallow updating the section - it requires either
  // recursive queries or a separate query before performing the update
  foreach(entries, mapping entry) {
    queries += ({""});
    queries[-1] = tquery;
    
    entry->contents->text = data->text;
    queries[-1] += sprintf(" answer = '%s'", data->text);

#if 0    
    entry->contents->title = data->title;
    queries[-1] += sprintf(",question = '%s'", data->title);
#endif
    
    entry->groups = replace(data->groups, ({" ", "\t", "\r"}), ({"\n", "\n", "\n"})) / "\n" - ({}) - ({""});
    if (entry->groups && sizeof(entry->groups))
      queries[-1] += sprintf(",groups = '{%s}'", entry->groups * ",");
    else
      queries[-1] += ",groups = '{}'";

    entry->users = replace(data->users, ({" ", "\t", "\r"}), ({"\n", "\n", "\n"})) / "\n" - ({}) - ({""});
    if (entry->users && sizeof(entry->users))
      queries[-1] += sprintf(",users = '{%s}'", entry->users * ",");
    else
      queries[-1] += ",users = '{}'";

    entry->see_also = replace(data->see_also, ({" ", "\t", "\r"}), ({"\n", "\n", "\n"})) / "\n" - ({}) - ({""});
    if (entry->see_also && sizeof(entry->see_also))
      queries[-1] += sprintf("seealso = '{%s}' ", entry->see_also * ",");
    else
      queries[-1] += ",seealso = '{}'";

    // it requires testing for path clashes...
    if (sizeof(data->number)) {
      if (!sizeof(data->section))
        entry->path = sprintf("/%s", data->number);
      else
        entry->path = sprintf("/%s/%s", replace(data->section,".","/"), data->number);
      queries[-1] += sprintf(",path = '%s'", entry->path);
    }

    queries[-1] += sprintf(" where id = '%s'", entry->id);
  }
  
  report_notice("update queries: %O\n", queries);

  foreach(queries, string query) {
    error = catch {
      results = db->query(query);
    };
    
    if (error) {
      report_error("Query error: %O\nQuery exception: %O", results, error);
      
      error = catch {
        db->query("rollback transaction");
      };
      return "Error updating data";
    }
  }

  error = catch {
    results = db->query("commit transaction");
  };

  report_notice("Finished updating\n");
  
  return 0;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: pg_db
//! URI of the database with the FAQ data. This module <strong>REQUIRES</strong> the database to be PostgreSQL.
//!  type: TYPE_STRING
//!  name: Database URI
//
