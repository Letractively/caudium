/*
 * 123 Session Module
 * (c) Kai Voigt, k@123.org
 *
 * _very_ BETA version for Roxen 1.3, Roxen 2.0 and Caudium
 *
 * To use an SQL database for storing the session and user variables, specify
 * the database in the config interface and create a table "variables"
 * with the following command within your database (this example is
 * from MySQL, you might need to modify it for other systems)
 *
 * create table variables (id varchar(255) not null,
 *                         region varchar(255),
 *                         lastusage int,
 *                         svalues mediumtext,
 *                         key(id));
 *
 * In your documents, you can use id->misc->session_variables as a
 * mapping for session variables that will be accessible during the entire
 * session.
 *
 * User variables are accessible as id->misc->user_variables as well.
 *
 * TODO: This module needs comments, documentation, testing and some
 * mutex stuff.  DBM storage can be added later.  Error handling is badly
 * needed to catch sql errors and the like.
 *
 */

string cvs_version = "$Id$";

inherit "module";
inherit "roxenlib";
#include <module.h>
import Sql;

mapping (string:mapping (string:mixed)) _variables = ([]);
object myconf;
int foundcookieandprestate = 0;

int storage_is_not_sql() {
 return (query("storage") != "sql");
}

int storage_is_not_file() {
 return (query("storage") != "file");
}

void start(int num, object conf) {
  if (conf) { myconf = conf; }
}

void create() {
  defvar("exclude_urls", "", "Exclude URLs", TYPE_TEXT_FIELD,
         "URLs that shouldn't be branded with a Session Identifier."
         " Examples:<pre>"
         "/images/\n"
         "/download/files/\n"
         "</pre>");
  defvar("secret", "ChAnGeThIs", "Secret Word", TYPE_STRING,
         "a secret word that is needed to create secure IDs." );
  defvar("garbage", 100, "Garbage Collection Frequency", TYPE_INT,
         "after how many connects expiration of old session should happen" );
  defvar("expire", 600, "Expiration Time", TYPE_INT,
         "after how many seconds an unactive session is removed" );
  defvar("storage", "memory",
         "Storage Method", TYPE_MULTIPLE_STRING,
         "The method to be used for storing the session and user variables."
         " Available are Memory, Database and File storage.  Each"
         " of them have their pros and cons regarding speed and"
         " persistance.",
         ({"memory", "sql", "file"}));
  defvar("sql_url", "",
         "Database URL", TYPE_STRING,
         "Which database to use for the session and user variables, use"
         " a common database URL",
         0, storage_is_not_sql);
  defvar("filepath", "",
         "File Method Path", TYPE_DIR,
         "The storage directory for File Method",
         0, storage_is_not_file);
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

string query_provides() {
  return("123sessions");
}

int session_size_memory() {
  if (_variables->session) {
    return (sizeof(_variables->session));
  } else {
    return(0);
  }
}

int session_size_sql() {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
  string query = "select count(*) as size from variables where region='session'";
  array(mapping(string:mixed)) result = con->query(query);
  return ((int)result[0]->size);
}

int session_size_file() {
  int result=0;
  foreach(get_dir(query("filepath")), string filename) {
    if (filename[sizeof(filename)-8..] == ".session") {
      result++;
    }
  }
  return (result);
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
  if (!_variables->session) {
    return;
  }
  foreach (indices(_variables->session), string session_id) {
    if (time() > (_variables->session[session_id]->lastusage+query("expire"))) {
      m_delete(_variables->session, session_id);
    }
  } 
}

void session_gc_sql() {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
  int exptime = time()-query("expire");
  con->query("delete from variables where lastusage < '"+exptime+"' and region='session'");
}

void session_gc_file() {
  string filepath=query("filepath");
  string sfile;
  int exptime = time()-query("expire");
 
  foreach (get_dir(filepath), string filename) {
    if (filename[sizeof(filename)-8..] == ".session") {
      sfile=combine_path(filepath,filename);
      if (file_stat(sfile)[2] < exptime) {
        rm(sfile);
      }
    }
  }
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

mapping (string:mixed) variables_retrieve_memory(string region, string key) {
  if (!_variables[region]) {
    _variables[region] = ([]);
  }
  if (!_variables[region][key]) {
    _variables[region][key] = ([]);
  }
  if (!_variables[region][key]->values) {
    _variables[region][key]->values = ([]);
  }
  return (_variables[region][key]->values);
}

mapping (string:mixed) variables_retrieve_sql(string region, string key) {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
   string query = "select svalues from variables where region='"+region+"' and id='"+key+"'";
  array(mapping(string:mixed)) result = con->query(query);
  if (sizeof(result) != 0) {
    return (string2values(result[0]->svalues));
  } else {
    return ([]);
  }
}

mapping (string:mixed) variables_retrieve_file(string region, string key) {
  string sfile=combine_path(query("filepath"),key+"."+region);
  if (file_stat(sfile)) {
    return (string2values(Stdio.read_bytes(sfile)));
  }
  return ([]);
}

mapping (string:mixed) variables_retrieve(string region, string key) {
  switch(query("storage")) {
    case "memory":
      return (variables_retrieve_memory(region, key));
      break;
    case "sql":
      return (variables_retrieve_sql(region, key));
      break;
    case "file":
      return (variables_retrieve_file(region, key));
      break;
  }
}

void variables_store_memory(string region, string key, mapping values) {
  if (!_variables[region]) {
    _variables[region] = ([]);
  }
  if (!_variables[region][key]) {
    _variables[region][key] = ([]);
  }
  _variables[region][key]->lastusage = time();
  _variables[region][key]->values = values;
}

string values2string(mixed values) {
  return (MIME.encode_base64(encode_value(values)));
}

mixed string2values(string encoded_string) {
  return (decode_value(MIME.decode_base64(encoded_string)));
}

void variables_store_sql(string region, string key, mapping values) {
  object(sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(query("sql_url"));
  con->query("delete from variables where region='"+region+"' and id='"+key+"'");
  con->query("insert into variables(id, region, lastusage, svalues) values ('"+key+"', '"+region+"', '"+time()+"', '"+values2string(values)+"')");
}

void variables_store_file(string region, string key, mapping values) {
  string sfile=combine_path(query("filepath"),key+"."+region);
  if (file_stat(sfile)) {
    rm(sfile);
  }
  object sf=Stdio.File();
  sf->open(sfile,"wct");
  sf->write(values2string(values));
  sf->close();
  destruct(sf);
}

void variables_store(string region, string key, mapping values) {
  switch(query("storage")) {
    case "memory":
      variables_store_memory(region, key, values);
      break;
    case "sql":
      variables_store_sql(region, key, values);
      break;
    case "file":
      variables_store_file(region, key, values);
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

mixed sessionid_set_prestate(object id, string SessionID) {
  string url=strip_prestate(strip_config(id->raw_url));
  string new_prestate = "SessionID="+SessionID;
  id->prestate += (<new_prestate>);
  return(http_redirect(url, id));
}

// Code by Allen
mixed sessionid_remove_prestate(object id) {   
  string url=strip_prestate(strip_config(id->raw_url));
  id->prestate = (<>);                                   
  return(http_redirect(id->not_query));             
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

string sessionid_get(object id) {
  string SessionID;
  int foundcookie=0;
  int foundprestate=0;

  if (id->cookies->SessionID) {
    SessionID = id->cookies->SessionID;
    foundcookie=1;
  }
  
  foreach (indices(id->prestate), string prestate) {
    if (prestate[..8] == "SessionID" ) {
      SessionID = prestate[10..];
      foundprestate=1;
    }
  }

  if ((foundcookie == 1) && (foundprestate == 1)) {
    foundcookieandprestate = 1;
  }

  return(SessionID);
}

mixed first_try(object id) {
  
  foreach (query("exclude_urls")/"\n", string exclude) {
    if ((strlen(exclude) > 0) &&
        (exclude == id->not_query[..strlen(exclude)-1])) {
      return (0);
    }
  }

  if (random(query("garbage")) == 0) {
    session_gc();
  }

  string SessionID = sessionid_get(id);

  if (!SessionID) {
    SessionID = sessionid_create();
    sessionid_set_cookie(id, SessionID);
    return (sessionid_set_prestate(id, SessionID));
  }

  if (foundcookieandprestate == 1) {
    foundcookieandprestate = 0;
    return (sessionid_remove_prestate(id));
  }

  id->misc->session_variables = variables_retrieve("session", SessionID);
  id->misc->session_id = SessionID;

  if (id->misc->session_variables->username) {
    id->misc->user_variables =
      variables_retrieve("user", id->misc->session_variables->username);
  } else {
    id->misc->user_variables = ([]);
  }
}

void filter(mapping m, object id) {
  string SessionID = id->misc->session_id;
  variables_store("session", SessionID, id->misc->session_variables);
  if (id->misc->session_variables->username) {
    variables_store("user", id->misc->session_variables->username, id->misc->user_variables);
  }
}
