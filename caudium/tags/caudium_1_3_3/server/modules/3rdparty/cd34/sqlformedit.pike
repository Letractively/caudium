// SQL Form Edit
//
// Written by Chris Davies
// http://daviesinc.com/modules/
// v 0.1, 2002-02-20

int thread_safe=1;
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_LOCATION;
constant module_name = "SQL Form Edit: Form Data Saved to SQL";

constant module_doc  = #"This MODULE_LOCATION allows you to do easy editing of SQL data via forms.<p>
The hidden field <b>unique</b> defines the SQL field name in the table that 
defines the where clause in the SQL Update.<br>
The hidden field <b>tablename</b> defines the SQL table that is being updated.
<br>
The hidden field <b>successpage</b> defines the page that the person will
be sent to after a successful update.<br>
The hidden field <b>errorpage</b> defines the page where a surfer will be 
sent if there is an error during the SQL Update.<p>
An example form follows:<p>\n\n
&lt;form method=\"post\" action=\"/form/sqlsave\"><br>
&lt;input type=\"hidden\" name=\"unique\" value=\"sequence\"><br>
&lt;input type=\"hidden\" name=\"tablename\" value=\"links\"><br>
&lt;input type=\"hidden\" name=\"successpage\" value=\"/success.rxml\"><br>
&lt;input type=\"hidden\" name=\"errorpage\" value=\"/form.rxml\"><br>
&lt;sqloutput query=\"select * from links where sequence=3\"><br>
&lt;input type=\"hidden\" name=\"sequence\" value=\"#sequence#\"><br>
&lt;table><br>
&lt;tr>&lt;td>title&lt;/td>&lt;td>&lt;input type=\"text\" name=\"title\" value=\"#title#\" size=80>&lt;/td>&lt;/tr><br>
&lt;tr>&lt;td>descr&lt;/td>&lt;td>&lt;input type=\"text\" name=\"descr\" value=\"#descr#\" size=80>&lt;/td>&lt;/tr><br>
&lt;tr>&lt;td>returnlink&lt;/td>&lt;td>&lt;input type=\"text\" name=\"returnlink\" value=\"#returnlink#\" size=80>&lt;/td>&lt;/tr><br>
&lt;/table><br>
&lt;/sqloutput><br>
&lt;input type=\"submit\" value=\"save\"><br>
&lt;/form><br>
";

// If module_unique is set to 1, you would not be able to have multiple 
// copies of this to process multiple forms.  However, this module is 
// really designed to be data driven and not hardcoded to a particular
// setup.
constant module_unique = 1;

void create()
{
//
// Defining the location tells Caudium what URL to answer for
// In this case, the URL that this module would respond to would be
//
//  http://domain.com/form/sqlsave
//
// This would correspond to <form action="http://domain.com/form/sqlsave">
//
  defvar("location", "/form/sqlsave", "Mount point", TYPE_LOCATION,
	     "Location");

// This is a standard definition for the SQL Server that you will be
// updating.  Saving this information in the Config Interface keeps 
// certain information from being available on the web.
  defvar ("sqldb", "localhost", "SQL server",
    TYPE_STRING,
    "This is the host running the SQL server with the "
    "authentication information.<br>\n"
    "Specify an \"SQL-URL\":<ul>\n"
    "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
    "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
    "Valid values for \"sqlserver\" depend on which "
    "sql-servers your pike has support for, but the following "
    "might exist: msql, mysql, odbc, oracle, postgres.\n",
  );

}
mapping find_file(string f,object id)
{

// Create an object to talk with the SQL server.  If there is a connection
// already created by Caudium, this will create a new communications
// thread as Caudium will maintain a persistent connection to the SQL
// server
  object db;
  if (id->conf->sql_connect)
    db = id->conf->sql_connect(QUERY(sqldb));
  else
    perror("REFER: Error: no connect<p>\n");

// This defines the field that is the 'auto_increment' or unique field 
// identifiers to make sure that we are editing and updating the correct
// record in the SQL server database
  string unique = (string)id->variables->unique;

// Get the list of field names from the SQL database that is being edited
  array fields = 
         indices(db->query("select * from "+(string)id->variables->tablename+
                           " limit 1")[0]);

// Walk through the indices to see what field names could be updated in the 
// edit.  Then, remove the tablename.fieldname variables, see which 
// form values are defined in the form post and update only those fields
// that exist in the form that is submitted.
  string update = "";
  foreach (fields,string field) {
    if (field[0..(sizeof((string)id->variables->tablename))] != 
        (string)id->variables->tablename+".")
      if (id->variables[field])
        update += "," + field + " = '" + 
                  db->quote((string)id->variables[field]) + "'";
  }

// remove the leading , 
  update = update[1..];

// This builds the query that needs to be sent to the SQL server and is
// as data driven as possible
  update = "update " + (string)id->variables->tablename + " set " + update +
           " where " + (string)id->variables->unique + "='" + 
           (string)id->variables[(string)id->variables->unique] + "'";
  
// Mysql returns 0 rows updated if there is no change, so the only thing
// we can really do here is check to make sure there is no error when 
// the SQL statement is executed.
  catch {
    db->query(update);
    return http_redirect((string)id->variables->successpage,id);
  };
  return http_redirect((string)id->variables->errorpage,id);
}
