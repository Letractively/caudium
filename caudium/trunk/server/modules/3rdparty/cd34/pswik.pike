/*
 * Caudium - An extensible World Wide Web server
 * Copyright \xa9 2002 The Caudium Group
 * Copyright \xa9 2002 Davies, Inc
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
 * See http://www.daviesinc.com/modules/ for more information.
 */

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER|MODULE_LOCATION;
constant module_name = "PseudoWiki";
constant module_version = "pswik.pike v0.1 16-June-2002";
constant module_doc  = #"This module creates a simple wiki with little to no administration capability.\n
<p>
&lt;pswik host=\"hostname\" instructions=\"newinstructions\" rows=\"5\" cols=\"60\" />
<p>
&lt;pswik help />
<p>
Database Definition for mysql<p>
CREATE TABLE `content` (<br>
&nbsp;&nbsp;`hostname` varchar(80) default NULL,<br>
&nbsp;&nbsp;`filepath` varchar(80) default NULL,<br>
&nbsp;&nbsp;`wiki` text,<br>
&nbsp;&nbsp;`created` timestamp(14) NOT NULL,<br>
&nbsp;&nbsp;`username` varchar(12) default NULL,<br>
&nbsp;&nbsp;`wikiid` bigint(20) unsigned NOT NULL auto_increment,<br>
&nbsp;&nbsp;PRIMARY KEY  (`wikiid`),<br>
&nbsp;&nbsp;KEY `content` (`hostname`,`filepath`,`created`)<br>
) TYPE=MyISAM<br>
";
constant module_unique = 1;
constant thread_safe=1;

void create()
{
  defvar("location", "/NONE/", "Mount point", TYPE_LOCATION,
         "When the PSeudoWIKi saves its output, this is the location on the"
         "server that services the request to save the data to the MySQL"
         "server");

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

string tag_pswik(string t, mapping m, object id)
{
  string out = "";

  if (m->help) {
    out += #"
&lt;pswik host=\"differenthostname.com\" <br>
instructions=\"Enter your manual addition\"<br>
rows=\"5\"<br>
cols=\"60\" /><p>
host: specify the hostname to be used in the database, overriding the server's
guess at the hostname<p>
instructions: this allows you to change the text above the textarea box
to instruct the web surfer (Default: Add a comment below)<p>
rows: Specify the number of rows in the textarea box (Default = 5)<p>
cols: Specify the number of columns in the textarea box (Default = 80)<p>
";
  } else {
    string filepath = id->not_query;
    string hostname = (m->host?m->host:id->host);
    object db;
    if (id->conf->sql_connect)
      db = id->conf->sql_connect(QUERY(sqldb));
    else
      out += "Error: no connect<p>\n";

    array result = db->query("select *,date_format(created,'%b %e, %Y - %h:%i %p') as time from content where hostname='"+hostname+"' and filepath='"+filepath+"' order by created");

    if (result) {
      foreach (result,array res) {
        out += "Added <strong>"+(string)res->time + "</strong><br>\n";
        out += "<table width=\"90%\"><tr><td>" + (string)res->wiki + "</td></tr></table>\n";
      }
      out += "<p>";
    }
  
    out += (m->instructions?m->instructions:"Add a comment below");

    out += "<form action=\""+QUERY(location)+"\" method=\"post\">";
    out += "<input type=\"hidden\" name=\"hostname\" value=\""+hostname+"\">";
    out += "<input type=\"hidden\" name=\"filepath\" value=\""+filepath+"\">";
    out += "<table><tr><td valign=\"top\">";
    out += "<textarea name=\"content\" rows=\""+(m->rows?m->rows:5)+"\" cols=\""+(m->cols?m->cols:80)+"\" wrap=\"physical\"></textarea></td>";
    out += "<td valign=\"top\"><input type=\"submit\" value=\"Save!\"></td></tr></table>";
    out += "</form>";
  
  } // if (m->help) 

  return(out);
}

mapping query_tag_callers()
{
  return ([ "pswik":tag_pswik, ]);
}

mapping find_file(string f,object id)   
{
  string out = "";
  object db;
  if (id->conf->sql_connect)
    db = id->conf->sql_connect(QUERY(sqldb));
  else
    out += "Error: no connect<p>\n";

  db->query("insert into content (hostname,filepath,wiki) values ('"+
            db->quote((string)id->variables->hostname)+"','"+
            db->quote((string)id->variables->filepath)+"','"+
            db->quote((string)id->variables->content)+"')");

  return http_redirect((string)id->variables->filepath,id);
}
