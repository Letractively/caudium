/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
 * Copyright © 2002 Davies, Inc
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
constant cvs_version = "$Id$";

int hide_mail()
{
  if(QUERY(mail) == 0)
    return 1;
  return 0;
}

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
  defvar("mail", 0, "Mail: Send mail",
	 TYPE_FLAG,
	 "Allow sending a mail when a wiki is send");
  defvar("maildomain","caudium.net", "Mail: Domain",
         TYPE_STRING,
         "The domain that will be used for sending mail\n",
         0, hide_mail);
  defvar("mailto", "hostmaster@localhost" ,"Mail: where to send email",
         TYPE_STRING,
         "Specifing an alias can be useful to contact several people.\n",
         0, hide_mail);
  defvar("mailfrom", "wiki@caudium.net" ,
         "Mail: where does the email come from", TYPE_STRING,
         "", 0, hide_mail);
  defvar("mailserver", "mail", "Mail: Address of your mail server",
         TYPE_STRING,
         "For now this field is mandatory.\n",
         0, hide_mail);
  defvar("subject", "New wiki online", "Mail: Subject of the message",
         TYPE_STRING,
         "Subject of the message sent by the module.\n",
         0, hide_mail);
  
}

void simple_mail(string msg, object id)
{
  string tmp;
  tmp = "The following message has just been added to the\n";
  tmp += " "+(string)id->referrer+"\n\n"+msg;
  tmp += "\n\n--\nThis message was sent by the pseudo-wiki module,\n";
  tmp += "check headers of this mail for more informations.";

#if constant(Protocols.ESMTP)
  Protocols.ESMTP.client(QUERY(mailserver), 25,
  QUERY(maildomain))->send_message(QUERY(mailfrom), ({ QUERY(mailto) }),
              (string)MIME.Message(tmp, (["MIME-Version":"1.0",
                                          "Subject":QUERY(subject),
                                          "From":QUERY(mailfrom),
                                          "To":QUERY(mailto),
                                          "Content-Type":
					  "text/plain; charset=\"iso-8859-1\"",
                                          "Content-Transfer-Encoding":
                                          "8bit",
					  "X-Originating-IP":
					  (string) id->remoteaddr,
					  "User-Agent": 
					  (string) id->useragent,
					  "X-Referrer": 
					  (string) id->referrer])));
#else
  QUERY(maildomain))->send_message(QUERY(mailfrom), ({ QUERY(mailto) })
  Protocols.SMTP.client(QUERY(mailserver), 25)->send_message(QUERY(mailfrom), ({ QUERY(mailto) }),
                (string)MIME.Message(tmp, (["MIME-Version":"1.0",
                                            "Subject":QUERY(subject),
                                            "From":QUERY(from),
                                            "To":QUERY(to),
                                            "Content-Type":
					    "text/plain; charset=\"iso-8859-1\"",
                                            "Content-Transfer-Encoding":
                                            "8bit",
					    "X-Originating-IP": 
					    (string) id->remoteaddr,
					    "User-Agent": 
					    (string) id->useragent,
					    "X-Referrer": 
					    (string) id->referrer])])));
#endif
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

// mapping integer:reason where integer is returned by valid() and reason
// is the reason why the comment is rejected
mapping reason = ([
	-1: "it is too small.",
	-2: "this wiki is not intended for you to test.",
	-3: "your text must contain at least characters.",
	-4: "you have to wait 30 seconds between each comment.",
	1: "...is valid, please retry again"
]);

// return negative integer value if wrong output is submited
// the meaning of this value is known with the reason mapping
int is_valid(object id)
{
  string content = id->variables->content;
  object db;

  // too small content
  if(sizeof(content) < 10)
    return -1;
  // we don't want tests
  if(String.trim_all_whites(lower_case(content)) == "test")
    return -2;
  // reject any comments that doesn't contain char.
  if(!Regexp("[a-zA-Z]+")->match(content))
    return -3;

  if (id->conf->sql_connect)
    db = id->conf->sql_connect(QUERY(sqldb));
  else
    perror("pswiki : error: no connect<p>\n");

  // does he already post ?
  if((int)db->query("select count(*) as nb_visits from content where hostname='"
    + id->variables->hostname + "'")->nb_visits[0] > 0)
  {
    // prevent users from sending more than 1 message per 30 seconds
    if(time() - (int)db->query("select UNIX_TIMESTAMP(max(created)) as lasttime from content where hostname='" + id->variables->hostname + "'")->lasttime[0] < 30)
     return -4;
   }
   return 1;
}

mapping query_tag_callers()
{
  return ([ "pswik":tag_pswik, ]);
}

mapping find_file(string f,object id)   
{
  object db;
 
  // anti lammer detection
  if(is_valid(id) < 0)
  {
    string error = "<html><body><font color=\"red\">";
    error += "The comment you added is not valid because " +
             reason[is_valid(id)] + "</font>";
    error += "<br><a href=\"" + id->variables->filepath + "\">Go back</a>";
    error += "</body></html>";
    return Caudium.HTTP.string_answer(error);
  }
  
  if (id->conf->sql_connect)
    db = id->conf->sql_connect(QUERY(sqldb));
  else
    perror("pswiki : error: no connect<p>\n");

  db->query("insert into content (hostname,filepath,wiki) values ('"+
            db->quote((string)id->variables->hostname)+"','"+
            db->quote((string)id->variables->filepath)+"','"+
            db->quote((string)id->variables->content)+"')");
 
  if(QUERY(mail)) {
    mixed err = catch {
      simple_mail((string)id->variables->content, id); 
    };
    if (err) {
      // Send it again    
      perror("pswiki: cannot send mail, trying again\n");
      err = catch {
        simple_mail((string)id->variables->content, id); 
      };
      if (err) {
        perror("pswiki: mail not sent\n");
      }
    }
  }      
  return Caudium.HTTP.redirect((string)id->variables->filepath,id);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: location
//! When the PSeudoWIKi saves its output, this is the location on theserver that services the request to save the data to the MySQLserver
//!  type: TYPE_LOCATION
//!  name: Mount point
//
//! defvar: sqldb
//! This is the host running the SQL server with the authentication information.<br />
//!Specify an "SQL-URL":<ul>
//!<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@][<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br />
//!Valid values for "sqlserver" depend on which sql-servers your pike has support for, but the following might exist: msql, mysql, odbc, oracle, postgres.
//!
//!  type: TYPE_STRING
//!  name: SQL server
//
