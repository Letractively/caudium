/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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

/*
 * The Storage module and the accompanying code is Copyright © 2002 James Tyson.
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   James Tyson	<jnt@caudium.net>
 *
 */

constant storage_type    = "MySQL";
constant storage_doc     = "Please enter the SQL URL for the mysql server you would like "
                            "to store data in.";
constant storage_default = "mysql://localhost/caudium";

#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#define PRELOCK() object __key
#define LOCK() __key = mutex->lock()
#define UNLOCK() destruct(__key)
#else
#define PRELOCK()
#define LOCK()
#define UNLOCK()
#endif
#define DB() get_database()

static string sqlurl;
static string version = sprintf("%d.%d.%d", __MAJOR__, __MINOR__, __BUILD__); 
static object db;

void create(string _sqlurl) {
  PRELOCK();
  LOCK();
  sqlurl = _sqlurl;
  if (catch(Sql.Sql(sqlurl)))
    throw(({"Unable to connect to database", backtrace()}));
  UNLOCK();
  init_tables();
}

void store(string namespace, string key, string value) {
  PRELOCK();
  object db = DB();
  LOCK();
  array res = db->query("select dkey from storage where namespace = %s and dkey = %s", namespace, key);
  if (sizeof(res) > 0)
    db->query("update storage set value = %s where namespace = %s and dkey = %s", value, namespace, key);
  else
    db->query("insert into storage values (%s, %s, %s, %s)", version, namespace, key, value);
}

mixed retrieve(string namespace, string key) {
  PRELOCK();
  object db = DB();
  LOCK();
  array result = db->query("select value from storage where namespace = %s and dkey = %s", namespace, key);
  if (sizeof(result))
    return result[0]->value;
  else
    return 0;
}

void unlink(string namespace, void|string key) {
  PRELOCK();
  LOCK();
  object db = DB();
  UNLOCK();
  if (stringp(key))
    db->query("delete from storage where namespace = %s and dkey = %s", namespace, key);
  else
    db->query("delete from storage where namespace = %s", namespace);
}

void unlink_regexp(string namespace, string regexp) {
  PRELOCK();
  LOCK();
  object db = DB();
  UNLOCK();
  db->query("delete from storage where namespace = %s and dkey regexp %s", namespace, regexp);
}

static object get_database() {
  PRELOCK();
  LOCK();
  if (!objectp(db))
    db = Sql.Sql(sqlurl);
  return db;
}

static object init_tables() {
  PRELOCK();
  LOCK();
  object db = DB();
  UNLOCK();
  multiset tables = (multiset)db->list_tables();
  if (!tables->storage)
    db->query(
      "create table storage(\n"
      "  pike_version varchar(255),\n"
      "  namespace varchar(250),\n"
      "  dkey varchar(250),\n"
      "  value longblob,\n"
      "  UNIQUE KEY storage (namespace, dkey)\n"
      ")"
    );
}

int size(string namespace) {
  PRELOCK();
  LOCK();
  object db = DB();
  UNLOCK();
  int total;
  array result = db->query("select length(value) as size from storage where namespace = %s", namespace);
  if (!sizeof(result))
    return 0;
  else
    foreach(result, mapping row) {
      total += (int)row->size;
    }
  return total;
}

array list(string namespace) {
  PRELOCK();
  LOCK();
  object db = DB();
  UNLOCK();
  return db->query("select dkey from storage where namespace = %s", namespace)->dkey;
}
