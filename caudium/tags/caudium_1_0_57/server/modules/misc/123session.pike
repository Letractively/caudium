/*
 * 123 Session Module
 * (c) Kai Voigt, k@123.org
 *
 * BETA version for Roxen 1.3, Roxen 2.0, Roxen 2.1 and Caudium
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

//
//! module: 123 sessions
//!  This Module will provide each session with a distinct set
//!  of session variables.
//!  <p>Warning: This module has not been tested a lot.
//!  </p><br/>
//!  Read the module code for instructions.
//! inherits: module
//! inherits: roxenlib
//! type: MODULE_FIRST | MODULE_FILTER | MODULE_PARSER | MODULE_PROVIDER
//! cvs_version: $Id$
//

string cvs_version = "$Id$";

inherit "module";
inherit "roxenlib";
#include <module.h>

mapping (string:mapping (string:mixed)) _variables = ([]);
object myconf;
int foundcookieandprestate = 0;
string authtemplate = "";

int storage_is_not_sql() {
  return (QUERY(storage) != "sql");
}

int storage_is_not_file() {
  return (QUERY(storage) != "file");
}

int dont_use_formauth() {
  return (QUERY(use_formauth) != 1);
}

int dont_use_formauth_file() {
  return (QUERY(auth_template_file) != 1);
}

// cd34, 10/4/2001, regexp objects for include/exclude
object incl=0,excl=0;

void start(int num, object conf) {
  if (conf) { myconf = conf; }
  if (QUERY(storage) == "memory") {
    foreach (call_out_info (), array a)
      if ((sizeof (a) > 5) && (a[3] == "123_Survivor") && ((sizeof (a) < 7) || (a[6] == my_configuration ()))) {
        remove_call_out (a[5]);
	_variables = a[4]->_variables;
        break;
      }
  }
// cd34, 10/4/2001, code to exclude or include files for processing
  catch {
    if (strlen(query("regexpinclude")))
      incl = Regexp(query("regexpinclude"));
    if (strlen(query("regexpexclude")))
      excl = Regexp(query("regexpexclude"));
  };
  if (QUERY(auth_template_file))
     authtemplate = Stdio.read_file(QUERY(template_file));
  else
     authtemplate = QUERY(authpage);
}

void stop () {
  if (QUERY(storage) == "memory") {
    array a = ({ 0 });
    // Roxen tries to kill us. Escape...
    a[0] = call_out (lambda (mixed ... foo) { write ("Could not restore sessions\n"); }, 30, "123_Survivor",
	             new (object_program (this_object ()), _variables, variables), a, my_configuration ());
  }
}

void create (mixed ... foo) {
  if (sizeof (foo) == 2){
    _variables = foo[0];
    variables = foo[1];
    return;
  }

  defvar("inc_excl", "exclude",
         "Session URLs allocation", TYPE_MULTIPLE_STRING,
         "How should the sessions be allocated ?<br><ul>"
         "<li>if you choose 'include', sessions will only be allocated under the given hierarchy.</li>"
         "<li>if you choose 'exclude', sessions will be allocated for the whole site <b>except</b> the given dirs.</li>"
         "</ul>",
         ({"include", "exclude"}));
  defvar("include_urls", "", "Include URLs", TYPE_TEXT_FIELD,
         "URLs that should be branded with a Session Identifier."
         " Examples:<pre>"
         "/mail/\n"
         "</pre>", 0, lambda() { return (QUERY(inc_excl)!="include"); });
  defvar("exclude_urls", "", "Exclude URLs", TYPE_TEXT_FIELD,
         "URLs that shouldn't be branded with a Session Identifier."
         " Examples:<pre>"
         "/images/\n"
         "/download/files/\n"
         "</pre>", 0, lambda() { return (QUERY(inc_excl)=="include"); });
  defvar("secret", "ChAnGeThIs", "Secret Word", TYPE_STRING,
         "a secret word that is needed to create secure IDs." );
  defvar("dogc", 1, "Garbage Collection", TYPE_FLAG,
         "Garbage collection will be done by this module." );
  defvar("garbage", 100, "Garbage Collection Frequency", TYPE_INT,
         "after how many connects expiration of old session should happen", 0, hide_gc);
// cd34, 10/4/2001, Allow cookies to be set with expire times
  defvar("cookieexpire", -1, "Cookie Expiration Time", TYPE_INT,
         "if 0, do not set a cookie expiration, if &gt;0, set cookie expiration "
         "for that many seconds.  If &lt;0, set cookie with date 10 years in the future" );
  defvar("expire", 600, "Expiration Time", TYPE_INT,
         "after how many seconds an unactive session is removed", 0, hide_gc);
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
  defvar("use_formauth", 0, "Use Form based authentication", TYPE_FLAG,
         "You can protect single URLs with a HTML based form.");
  defvar("auth_urls", "", "Auth URLs", TYPE_TEXT_FIELD,
         "URLs that are protected by this module, i.e. URLs that"
         " only should be accessible by known users."
         " Examples:<pre>"
         "/login/\n"
         "/admin/\n"
         "</pre>",
         0, dont_use_formauth);
  defvar("auth_template_file", 0, "Auth template in file", TYPE_FLAG,
         "Auth form in file (instead in config)",
         0, dont_use_formauth);
  defvar("template_file", 0, "Template file", TYPE_FILE,
         "Path to auth template", 0, dont_use_formauth_file);
  defvar("authpage",
         "<html><head><title>Login</title></head><body>\n"
         "<form method=\"post\"><table>\n"
         "<tr><td>Username:</td>\n"
         "<td><input name=\"httpuser\" size=\"20\"/></tr>\n"
         "<tr><td>Password:</td>\n"
         "<td><input type=\"password\" name=\"httppass\" size=\"20\"/></tr>\n"
         "<tr><td>&nbsp;</td><td><input type=\"submit\" value=\"Login\"></tr>\n"
         "</table></form>\n"
         "</body></html>\n",
         "Form authentication page.",
         TYPE_TEXT_FIELD,
         "Should contain an form with input fields named <i>httpuser</i> "
         "and <i>httppass</i>.",
         0, dont_use_formauth);
  defvar("parseauthpage",0,"RXML parse authentication page.", TYPE_FLAG,
         "RXML parse the authentication page before sending the contents to "
	 "the client.",0,dont_use_formauth);
  defvar("secure", 0, "Secure Cookies", TYPE_FLAG,
	 "If used, cookies will be flagged as 'Secure' (RFC 2109)." );
  defvar("debug", 0, "Debug", TYPE_FLAG,
	 "When on, debug messages will be logged in Caudium's debug logfile. "
	 "This information is very useful to the developers when fixing bugs.");
// cd34, 10/4/2001, code to allow regexp includes/excludes & sql caching
  defvar("regexpinclude", ".*",
         "Regexp Include Specification", TYPE_STRING,
         "An expression here will include processing for anything that matches this Pike Syntax Regexp<br>"
         "For Example:<br>.*<br>will include processing for all files.  id->not_query is automatically "
         "lowercased");
  defvar("regexpexclude", "",
         "Regexp Exclude Specification", TYPE_STRING,
         "An expression here will exclude processing for anything that matches this Pike Syntax Regexp<br>"
         "For Example:<br>\\.(jpe*g|gif|png)$ <br>will exclude processing for jpg, gif and png files "
         "id->not_query is automatically lowercased");
  defvar("sql_cache", 1, "Cache SQL traffic?", TYPE_FLAG,
         "Implements a simple in-memory write-through cache when used with an SQL server",
         0, storage_is_not_sql);
  
  defvar ("remove", 0, "Remove the sessions", TYPE_CUSTOM,
	  "Pressing this button will remove all the sessions.",
	  // function callbacks for the configuration interface
	  ({ describe_remove, describe_form_remove, set_from_form_remove }),
	  lambda () { return (QUERY(storage) != "memory"); });
}

int hide_gc () { return (!QUERY(dogc)); }

mixed register_module() {
  return ({ MODULE_FIRST | MODULE_FILTER | MODULE_PARSER | MODULE_PROVIDER,
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
  object(Sql.sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(QUERY(sql_url));
  string query = "select count(*) as size from variables where region='session'";
  array(mapping(string:mixed)) result = con->query(query);
  return ((int)result[0]->size);
}

int session_size_file() {
  int result=0;
  foreach(get_dir(QUERY(filepath)), string filename) {
    if (filename[sizeof(filename)-8..] == ".session") {
      result++;
    }
  }
  return (result);
}

string status() {
  string result = "";
  int size;

  switch(QUERY(storage)) {
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

  result += sprintf("%d session%s active.<br>\n", size, (size != 1) ? "s" : "");
  return (result);
}

void session_gc_memory() {
  if (!_variables->session) {
    return;
  }
  foreach (indices(_variables->session), string session_id) {
    if (time() > (_variables->session[session_id]->lastusage+QUERY(expire))) {
      m_delete(_variables->session, session_id);
    }
  } 
}

void session_gc_sql() {
  object(Sql.sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(QUERY(sql_url));
  int exptime = time()-QUERY(expire);
  con->query("delete from variables where lastusage < '"+exptime+"' and region='session'");
}

void session_gc_file() {
  string filepath=QUERY(filepath);
  string sfile;
  int exptime = time()-QUERY(expire);
 
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
  switch(QUERY(storage)) {
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
  object(Sql.sql) con;
// cd34, 10/4/2001, SQL Caching
  array dbinfo;
  if (QUERY(sql_cache))
    dbinfo=cache_lookup("123"+region,key);
  if (dbinfo)
    return(sizeof(dbinfo[1])>0?string2values(dbinfo[1]):([]));
  function sql_connect = myconf->sql_connect;
  con = sql_connect(QUERY(sql_url));
   string query = "select svalues from variables where region='"+region+"' and id='"+key+"'";
  array(mapping(string:mixed)) result = con->query(query);
// cd34, 10/4/2001, SQL Caching
  if ( (QUERY(sql_cache)) && (!dbinfo) ) {
    dbinfo = ({ key, sizeof(result)?result[0]->svalues:([]) });
    cache_set("123"+region,key,dbinfo);
  }
  if (sizeof(result) != 0) {
    return (string2values(result[0]->svalues));
  } else {
    return ([]);
  }
}

mapping (string:mixed) variables_retrieve_file(string region, string key) {
  string sfile=combine_path(QUERY(filepath),key+"."+region);
  if (file_stat(sfile)) {
    return (string2values(Stdio.read_bytes(sfile)));
  }
  return ([]);
}

mapping (string:mixed) variables_retrieve(string region, string key) {
  switch(QUERY(storage)) {
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
  object(Sql.sql) con;
  function sql_connect = myconf->sql_connect;
  con = sql_connect(QUERY(sql_url));
  con->query("delete from variables where region='"+region+"' and id='"+key+"'");
  con->query("insert into variables(id, region, lastusage, svalues) values ('"+key+"', '"+region+"', '"+time()+"', '"+values2string(values)+"')");
// cd34, 10/4/2001, SQL Caching
  if (QUERY(sql_cache)) {
    array dbinfo = ({ key, values2string(values) });
    cache_set("123"+region,key,dbinfo);
  }
}

void variables_store_file(string region, string key, mapping values) {
  string sfile=combine_path(QUERY(filepath),key+"."+region);
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
  switch(QUERY(storage)) {
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
  // Kiwi: Add a Crypto.randomness.reasonably_random()->read(size) in this
  //       function may add some more random session id ?
  md5->update(QUERY(secret));
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

mixed sessionid_remove_prestate(object id) {   
  string url=strip_prestate(strip_config(id->raw_url));
  id->prestate = (<>);                                   
  // cd34, 10/30/2001
  return(http_redirect(id->not_query+(id->query ? "?"+id->query : ""), id));
}

void sessionid_set_cookie(object id, string SessionID) {
  string Cookie = "SessionID="+SessionID+"; path=/";
// cd34, 10/4/2001, set cookie expiration based on info in the config interface
  if (query ("cookieexpire") > 0)
    Cookie += "; Expires=" + http_date(time()+query("cookieexpire")) +";";
  if (query ("cookieexpire") < 0)
    Cookie += "; Expires=Fri, 31 Dec 2010 23:59:59 GMT;";
  if (query ("secure"))
    Cookie += "; Secure";
  id->cookies->SessionID = SessionID;
  id->misc->is_dynamic = 1;
  id->misc->moreheads = ([ "Set-Cookie": Cookie ]);
}

string sessionid_get(object id) {
  string SessionID;
  int foundcookie=0;
  int foundprestate=0;

  if (id->cookies->SessionID && sizeof (id->cookies->SessionID)) {
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

// cd34, 10/4/2001, code to exclude or include processing by regexp
  if (id->not_query && (incl && !incl->match(lower_case(id->not_query))) ||
      (excl &&  excl->match(lower_case(id->not_query)))) {
    return(0);
  }

  if (QUERY (inc_excl) == "exclude") {
    foreach (QUERY(exclude_urls)/"\n", string exclude) {
      if ((strlen(exclude) > 0) &&
          (exclude == id->not_query[..strlen(exclude)-1])) {
        return (0);
      }
    }
  }
  else {
    int bad = 1;
    foreach (QUERY(include_urls)/"\n", string include) {
      if ((strlen(include) > 0) &&
          (include == id->not_query[..strlen(include)-1])) {
        bad = 0;
        // write ("123session: good url: " + id->not_query[..strlen(include)-1] + "\n");
        break;
      }
    }

    if (bad)
      return 0;
  }

  if (query ("dogc") && (random (query ("garbage")) == 0)) {
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

  if (id->variables->logout) {
    if (id->misc->session_variables->username)
      if (id->variables->logout == id->misc->session_variables->username)
        store_user (id);

    delete_session (id, SessionID, 1);
    return (0);
   }

  if (!id->misc->session_variables->username && (query ("use_formauth"))) {
    int userauthrequired=0;
    foreach (QUERY(auth_urls)/"\n", string url) {
      if ((strlen(url) > 0) &&
          (url == id->not_query[..strlen(url)-1])) {
        userauthrequired=1;
      }
    }
    if (userauthrequired == 1) {
      if ((id->variables->httpuser) && (id->variables->httppass)) {
        string comb = id->variables->httpuser+":"+id->variables->httppass;
        array(string) auth = ({"Basic", comb});
        mixed result = id->conf->auth_module->auth(auth, id);
        if (result[0] == 1) {
          id->misc->session_variables->username = id->variables->httpuser;
        } else {
          return QUERY(parseauthpage)?http_string_answer(parse_rxml(authtemplate,id)):http_low_answer(200, authtemplate);
        }
      } else {
        return QUERY(parseauthpage)?http_string_answer(parse_rxml(authtemplate,id)):http_low_answer(200, authtemplate);
      }
    }
  }

  if (id->misc->session_variables->username) {
    id->misc->user_variables =
      variables_retrieve("user", id->misc->session_variables->username);
  } else {
    id->misc->user_variables = ([]);
  }
}

void store_user (object id) {
  if (id->misc->session_id) {
    if (id->misc->session_variables && id->misc->session_variables->username)
      if (id->misc->user_variables && sizeof (id->misc->user_variables))
        variables_store("user", id->misc->session_variables->username, id->misc->user_variables);
  }
}

void store_everything(object id) {
  if (id->misc->session_id) {
    string SessionID = id->misc->session_id;
    variables_store("session", SessionID, id->misc->session_variables);
    store_user (id);
  }
}

void filter(mapping m, object id) {
  store_everything(id);
}

mapping query_tag_callers() {
  return (["session_variable": tag_variables,
	   "user_variable": tag_variables,
	   "end_session" : tag_end_session,
	   "dump_session" : tag_dump_session,
	   "dump_sessions" : tag_dump_sessions,
	   "dump_user" : tag_dump_user]);
}

string tag_variables(string tag_name, mapping arguments, object id, object file, mapping defines) {
  if (!arguments->variable) {
    return "";
  }
  mapping region;
  if (tag_name == "session_variable") {
    region = id->misc->session_variables;
  }
  if (tag_name == "user_variable") {
    region = id->misc->user_variables;
  }
  if (arguments->value) {
    region[arguments->variable] = arguments->value;
    return "";
  } else {
    if (region[arguments->variable]) {
      return (string)(region[arguments->variable]);
    }
  }
}

void kill_session (string session_id) {
  variables_delete ("session", session_id);
}

void delete_session (object id, string session_id, void|int logout) {
  if (QUERY (debug))
    write ("123>> killing session " + session_id + "...\n");
  if (id->misc->session_variables) {
    if (id->misc->session_variables->username)
      m_delete (id->misc, "user_variables");
    
    kill_session (session_id);
    m_delete (id->misc, "session_variables");
  }
  m_delete (id->misc, "session_id");
  
  if (logout) {
    if (id->cookies->SessionID && sizeof (id->cookies->SessionID)) {
      string Cookie = "SessionID=; path=/";
      if (query ("secure"))
	Cookie += "; Secure";
      id->misc->is_dynamic = 1;
      id->misc->moreheads = ([ "Set-Cookie": Cookie ]);
      m_delete (id->cookies, "SessionID");
    }
    
    if (id->prestate && sizeof (id->prestate)) {
      string prestate = "SessionID=" + session_id;
      id->prestate -= (< prestate >);
    }
  }
}

void variables_delete_memory (string region, string key) {
  m_delete (_variables[region], key);
}

void variables_delete(string region, string key) {
  switch(QUERY(storage)) {
    case "memory":
      variables_delete_memory(region, key);
      break;
/*
    case "sql":
      variables_delete_sql(region, key);
      break;
    case "file":
      variables_delete_file(region, key);
      break; 
*/
  }
}

string tag_end_session (string tag_name, mapping args, object id, mapping defines) {
  if (id->misc->session_id)
    delete_session (id, id->misc->session_id, 1);
  return "";
}

string tag_dump_session (string tag_name, mapping args, object id, object file)
{
  return (id->misc->session_variables) ? (sprintf ("<pre>id->misc->session_variables : %O\n</pre>", id->misc->session_variables)) : "";
}

string tag_dump_sessions (string tag_name, mapping args, object id, object file)
{
  return (_variables) ? (sprintf ("<pre>_variables : %O\n</pre>", _variables)) : "";
}

string tag_dump_user (string tag_name, mapping args, object id, object file)
{
  return (id->misc->session_variables && id->misc->session_variables->username && id->misc->user_variables) ?
    (sprintf ("<pre>id->misc->user_variables (%s) : %O\n</pre>", id->misc->session_variables->username, id->misc->user_variables)) : "";
}

mapping sessions () {
  return _variables->session;
}

string describe_remove () {
  return "";
}

string describe_form_remove (array var, mixed path) {
  string ret = "<input type=\"hidden\" name=\"foo\" value=bar>"; /* strange,
								    but won't work
								    without */
  ret += "<input type=\"submit\" value=\"Reset\">";
  return ret;
}

void set_from_form_remove (string val, int type, object o) {
  _variables = ([ ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: inc_excl
//! How should the sessions be allocated ?<br /><ul><li>if you choose 'include', sessions will only be allocated under the given hierarchy.</li><li>if you choose 'exclude', sessions will be allocated for the whole site <b>except</b> the given dirs.</li></ul>
//!  type: TYPE_MULTIPLE_STRING
//!  name: Session URLs allocation
//
//! defvar: include_urls
//! URLs that should be branded with a Session Identifier. Examples:<pre>/mail/
//!</pre>
//!  type: TYPE_TEXT_FIELD
//!  name: Include URLs
//
//! defvar: exclude_urls
//! URLs that shouldn't be branded with a Session Identifier. Examples:<pre>/images/
//!/download/files/
//!</pre>
//!  type: TYPE_TEXT_FIELD
//!  name: Exclude URLs
//
//! defvar: secret
//! a secret word that is needed to create secure IDs.
//!  type: TYPE_STRING
//!  name: Secret Word
//
//! defvar: dogc
//! Garbage collection will be done by this module.
//!  type: TYPE_FLAG
//!  name: Garbage Collection
//
//! defvar: garbage
//! after how many connects expiration of old session should happen
//!  type: TYPE_INT
//!  name: Garbage Collection Frequency
//
//! defvar: cookieexpire
//! if 0, do not set a cookie expiration, if &gt;0, set cookie expiration for that many seconds.  If &lt;0, set cookie with date 10 years in the future
//!  type: TYPE_INT
//!  name: Cookie Expiration Time
//
//! defvar: expire
//! after how many seconds an unactive session is removed
//!  type: TYPE_INT
//!  name: Expiration Time
//
//! defvar: storage
//! The method to be used for storing the session and user variables. Available are Memory, Database and File storage.  Each of them have their pros and cons regarding speed and persistance.
//!  type: TYPE_MULTIPLE_STRING
//!  name: Storage Method
//
//! defvar: sql_url
//! Which database to use for the session and user variables, use a common database URL
//!  type: TYPE_STRING
//!  name: Database URL
//
//! defvar: filepath
//! The storage directory for File Method
//!  type: TYPE_DIR
//!  name: File Method Path
//
//! defvar: use_formauth
//! You can protect single URLs with a HTML based form.
//!  type: TYPE_FLAG
//!  name: Use Form based authentication
//
//! defvar: auth_urls
//! URLs that are protected by this module, i.e. URLs that only should be accessible by known users. Examples:<pre>/login/
//!/admin/
//!</pre>
//!  type: TYPE_TEXT_FIELD
//!  name: Auth URLs
//
//! defvar: auth_template_file
//! Auth form in file (instead in config)
//!  type: TYPE_FLAG
//!  name: Auth template in file
//
//! defvar: template_file
//! Path to auth template
//!  type: TYPE_FILE
//!  name: Template file
//
//! defvar: authpage
//! Should contain an form with input fields named <i>httpuser</i> and <i>httppass</i>.
//!  type: TYPE_TEXT_FIELD
//!  name: Form authentication page.
//
//! defvar: parseauthpage
//! RXML parse the authentication page before sending the contents to the client.
//!  type: TYPE_FLAG
//!  name: RXML parse authentication page.
//
//! defvar: secure
//! If used, cookies will be flagged as 'Secure' (RFC 2109).
//!  type: TYPE_FLAG
//!  name: Secure Cookies
//
//! defvar: debug
//! When on, debug messages will be logged in Caudium's debug logfile. This information is very useful to the developers when fixing bugs.
//!  type: TYPE_FLAG
//!  name: Debug
//
//! defvar: regexpinclude
//! An expression here will include processing for anything that matches this Pike Syntax Regexp<br />For Example:<br />.*<br />will include processing for all files.  id->not_query is automatically lowercased
//!  type: TYPE_STRING
//!  name: Regexp Include Specification
//
//! defvar: regexpexclude
//! An expression here will exclude processing for anything that matches this Pike Syntax Regexp<br />For Example:<br />\.(jpe*g|gif|png)$ <br />will exclude processing for jpg, gif and png files id->not_query is automatically lowercased
//!  type: TYPE_STRING
//!  name: Regexp Exclude Specification
//
//! defvar: sql_cache
//! Implements a simple in-memory write-through cache when used with an SQL server
//!  type: TYPE_FLAG
//!  name: Cache SQL traffic?
//
//! defvar: remove
//! Pressing this button will remove all the sessions.
//!  type: TYPE_CUSTOM
//!  name: Remove the sessions
//
