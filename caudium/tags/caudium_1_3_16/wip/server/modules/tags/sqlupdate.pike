#include <module.h>
inherit "module";
inherit "caudiumlib";

mapping sql_update(object db, array(mapping) data, string unique, string tablename, object id, void|string uniquevalue, void|string passthrough)
{

  werror("sql_update!!\n");
// 'unique' defines the field that is the 'auto_increment' or unique field 
// identifiers to make sure that we are editing and updating the correct
// record in the SQL server database

// Get the list of field names from the SQL database that is being edited
  array fields = 
         indices(db->query("select * from "+tablename+
                           " limit 1")[0]);

// Walk through the indices to see what field names could be updated in the 
// edit.  Then, remove the tablename.fieldname variables, see which 
// form values are defined in the form post and update only those fields
// that exist in the form that is submitted.

  foreach(data, mapping row)
  {
    werror("%O\n", row);
    string update = "";
    foreach (fields,string field) 
    {
      if (field[0..(sizeof(tablename))] != (tablename+"."))
        if (row[field])
          update += "," + field + " = '" + 
                    db->quote((string)row[field]) + "'";
    }

    // remove the leading , 
    update = update[1..];

    // the contents of passthrough are append that to every update query
    passthrough = (passthrough?(","+passthrough):"");


    // This builds the query that needs to be sent to the SQL server and is
    // as data driven as possible
    update = "update " + tablename + " set " + update +
             passthrough + " where " + unique + "='" + 
             (uniquevalue||(string)row[unique]) + "'";

    // Mysql returns 0 rows updated if there is no change, so the only thing
    // we can really do here is check to make sure there is no error when 
    // the SQL statement is executed.
    perror("q: "+update+"\n");
    //  catch {
      db->query(update);
  }
      return http_redirect((string)id->variables->successpage,id);
    //  };
  return http_redirect((string)id->variables->errorpage + "?" + 
                       (string)id->variables->unique + "=" +
                       (string)id->variables[(string)id->variables->unique],id);
}

