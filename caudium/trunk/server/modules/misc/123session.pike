/*
 * 123 Session Module
 * (c) Kai Voigt, k@123.org
 *
 * _very_ BETA version for Roxen 1.3, Roxen 2.0 and Caudium
 *
 * To use an SQL database for storing the session variables, specify
 * the database in the config interface and create a table "sessions"
 * with the following command within your database (this example is
 * from MySQL, you might need to modify it for other systems)
 *
 * create table sessions (id varchar(255) not null,
 *                        lastusage int,
 *                        svalues mediumtext,
 *                        key(id));
 *
 * In your documents, you can use id->misc->session_variables as a
 * mapping for variables that will be accessible during the entire
 * session.
 *
 * TODO: This module needs comments, documentation, testing and some
 * mutex stuff.  The file storage is not implemented yet, just the
 * stubs.  DBM storage can be added later.  Error handling is badly
 * needed to catch sql errors and the like.  Session ID encoding in
 * prestates is missing.
 *
 */

string cvs_version = "$Id$";

inherit "module";
inherit "roxenlib";
#include <module.h>
import Sql;

mapping (string:mixed) session_variables;
Configuration myconf;

int storage_is_not_sql() {
 return (query("storage") != "sql");
}

void start(int num, Configuration conf) {
  if (conf) { myconf = conf; }
}

void create() {
  defvar("secret", "ChAnGeThIs", "Secret Word", TYPE_STRING,
   "a secret word that is needed to create secure IDs." );
  defvar("garbage", 10, "Garbage Collection Frequency", TYPE_INT,
   "after how many connects expiration of old session should happen" );
  defvar("expire", 60, "Expiration Time", TYPE_INT,
   "after how many seconds an unactive session is removed" );
  defvar("storage", "memory",
   "Storage Method", TYPE_MULTIPLE_STRING,
   "The method to be used for storing the session variables."
   " Available are Memory, Database and File storage.  Each"
   " of them have their pros and cons regarding speed and"
   " persistance.",
   ({"memory", "sql"}));
  defvar("sql_url", "",
   "Database URL", TYPE_STRING,
   "Which database to use for the session variables, use"
   " a common database URL",
   0, storage_is_not_sql);
}

mixed register_module() {
  return ({ MODULE_FIRST | MODULE_FILTER | MODULE_PARSER,
    "123 Sessions",
    "This Module will provide each session with a distinct set "
    "of session variables."
    "<p>"
    "Warning: This module has not been tested a lot."
    "<br>"
    "Read the module code for instructions.",
    ({}), 1, });
}

int session_size_memory() {
  if (session_variables) {
    return (sizeof(session_variables));
  } else {
    return(0);
  }
}

int session_size_sql() {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
  string query = "select count(*) as size from sessions";
  array(mapping(string:mixed)) result = con->query(query);
  return ((int)result[0]->size);
}

// TODO
int session_size_file() {
 return (0);
}

string status() {
  string result = "";
  int size;

  switch(query("storage")) {
    case "memory":
      size = session_size_memory();
      break;
    case "sql":
      size = session_size_sql();
      break;
    case "file":
      size = session_size_file();
      break;
  }

  result += sprintf("%d session(s) active.<br>\n", size);
  return (result);
}

void session_gc_memory() {
  if (!session_variables) {
    return;
  }
  foreach (indices(session_variables), string session_id) {
    if (time() > (session_variables[session_id]->lastusage+query("expire"))) {
      m_delete(session_variables, session_id);
    }
  } 
}

void session_gc_sql() {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
  int exptime = time()-query("expire");
  con->query("delete from sessions where lastusage < '"+exptime+"'");
}

// TODO
void session_gc_file() {
}

void session_gc() {
  switch(query("storage")) {
    case "memory":
      session_gc_memory();
      break;
    case "sql":
      session_gc_sql();
      break;
    case "file":
      session_gc_file();
      break;
  }
}


mapping (string:mixed) session_retrieve_memory(string SessionID) {
  if (!session_variables) {
    session_variables = ([]);
  }
  if (!session_variables[SessionID]) {
    session_variables[SessionID] = ([]);
  }
  if (!session_variables[SessionID]->values) {
    session_variables[SessionID]->values = ([]);
  }
  return (session_variables[SessionID]->values);
}

mapping (string:mixed) session_retrieve_sql(string SessionID) {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
   string query = "select svalues from sessions where id='"+SessionID+"'";
  array(mapping(string:mixed)) result = con->query(query);
  if (sizeof(result) != 0) {
    return (string2values(result[0]->svalues));
  } else {
    return ([]);
  }
}

// TODO
mapping (string:mixed) session_retrieve_file(string SessionID) {
  return ([]);
}

mapping (string:mixed) session_retrieve(string SessionID) {
  switch(query("storage")) {
    case "memory":
      return (session_retrieve_memory(SessionID));
      break;
    case "sql":
      return (session_retrieve_sql(SessionID));
      break;
    case "file":
      return (session_retrieve_file(SessionID));
      break;
  }
}

void session_store_memory(string SessionID, mapping values) {
  session_variables[SessionID]->lastusage = time();
  session_variables[SessionID]->values = values;
}

string values2string(mixed values) {
  return (MIME.encode_base64(encode_value(values)));
}

mixed string2values(string encoded_string) {
  return (decode_value(MIME.decode_base64(encoded_string)));
}

void session_store_sql(string SessionID, mapping values) {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
  con->query("delete from sessions where id='"+SessionID+"'");
  con->query("insert into sessions (id, lastusage, svalues) values ('"+SessionID+"', '"+time()+"', '"+values2string(values)+"')");
}

// TODO
void session_store_file(string SessionID, mapping values) {
}

void session_store(string SessionID, mapping values) {
  switch(query("storage")) {
    case "memory":
      session_store_memory(SessionID, values);
      session_store_sql(SessionID, values);
      break;
    case "sql":
      session_store_sql(SessionID, values);
      break;
    case "file":
      session_store_file(SessionID, values);
      break;
  }
}

string sessionid_create() {
  object md5 = Crypto.md5();
  md5->update(query("secret"));
  md5->update(sprintf("%d", roxen->increase_id()));
  md5->update(sprintf("%d", time(1)));
  return(Crypto.string_to_hex(md5->digest()));
}

void sessionid_set_cookie(object id, string SessionID) {
  string Cookie = "SessionID="+SessionID+"; path=/";
  id->cookies->SessionID = SessionID;
  id->misc->moreheads = ([ "Set-Cookie": Cookie,
                           "Expires": "Mon, 26 Jul 1997 05:00:00 GMT",
                           "Pragma": "no-cache",
                           "Last-Modified": http_date(time(1)),
                           "Cache-Control": "no-cache, must-revalidate" ]);
}

void sessionid_set(object id, string SessionID) {
  // TODO: wrapper
  sessionid_set_cookie(id, SessionID);
}

string sessionid_get(object id) {
  string SessionID;

  if (id->cookies->SessionID) {
    SessionID = id->cookies->SessionID;
  }
  if (!SessionID) {
    SessionID = sessionid_create();
    sessionid_set(id, SessionID);
  }
  return (SessionID);
}

mixed first_try(object id) {
  if (random(query("garbage")) == 0) {
    session_gc();
  }

  string SessionID = sessionid_get(id);

  id->misc->session_variables = session_retrieve(SessionID);
  id->misc->session_id = SessionID;
}

void filter(mapping m, object id) {
  string SessionID = id->misc->session_id;
  session_store(SessionID, id->misc->session_variables);
}

