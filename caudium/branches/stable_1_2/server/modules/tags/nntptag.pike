/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2004 The Caudium Group
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
 * $Id$
 */

#include <module.h>
inherit "module";
inherit "caudiumlib";

import Array;		// Is this needed ? I don't think so ?

//! module: NNTP module
//!  This module gives the tag &lt;article&gt; and &lt;group&gt;<br />
//!  <ul><li><p>&lt;article&gt; display an article. The variables 
//!  available are based on the name of the header.</p>
//!  <p>&lt;formoutput&gt;&lt;article group=ece.assos.iteam msgid=1034&gt;From:#from# Subject:#subject# x-complaints-to:#x-complaints-to# Body:#body#&lt;/article &gt;&lt;/formoutput&gt;</p></li>
//!  <li><p>&lt;group&gt; display headers of news within a group.
//!  This mean it works like the sqloutput tag by running a loop
//!  for every article within the group. The min argument is the
//!  id of the first article. By default it is the last id - 25.
//!  The max argument is the id the last article.</p>
//!  <p>&lt;formoutput&gt;&lt;group group=ece.assos.iteam min=900 max=1000&gt;#article# #subject# #from# #date# #group#&lt;/group&gt;&lt;/formoutput&gt;</p></li></ul>
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$

constant module_type = MODULE_PARSER;
constant module_name = "NNTP module";
constant module_doc  = "This module gives the tag &lt;article&gt; and &lt;group&gt;<br>\n"
 "<ul><li><p>&lt;article&gt; display an article. The variables available are based on the name of the header.</p>"
         "<p>&lt;formoutput&gt;&lt;article group=ece.assos.iteam msgid=1034&gt;From:#from# Subject:#subject# x-complaints-to:#x-complaints-to# Body:#body#&lt;/article &gt;&lt;/formoutput&gt;</p></li>"
	         "<li><p>&lt;group&gt; display headers of news within a group. This mean it works like the sqloutput tag by running a loop for every article within the group. The min argument is the id of the first article. By default it is the last id - 25. The max argument is the id the last article.</p>"
		          "<p>&lt;formoutput&gt;&lt;group group=ece.assos.iteam min=900 max=1000&gt;#article# #subject# #from# #date# #group#&lt;/group&gt;&lt;/formoutput&gt;</p></li></ul>";
constant cvs_version="$Id$";
constant thread_safe=1;
constant module_unique = 1;

#define LDAPTAGDEBUG
#ifdef LDAPTAGDEBUG
#define DEBUGLOG(s) perror("NNTPtag: " + s + "\n")
#else
#define DEBUGLOG(s)
#endif

array(object) nntps = ({});

string mime_decode(string str)
{
  array res = map(str / " ", MIME.decode_word);
  array result = ({});
  array temp;

  foreach (res, temp) result += ({ temp[0] });

  return result * " ";
}

object pop_nntp()
{
  object nntp = 0;
  int result = 1;

  if (sizeof(nntps) == 0)
  {
     nntp = Protocols.NNTPClient.connection(QUERY(nntpserver));
     nntp->reader();
  }
  else
  {
     nntp = nntps[0];
     nntps = nntps[1..];
  }

  if (!nntp->reader())
  {
     nntp = Protocols.NNTPClient.connection(QUERY(nntpserver));
     result = nntp->reader();
  }

  if (result) return nntp;
  else return 0;
}

void push_nntp(object nntp)
{
  if (nntp->reader()) nntps += ({ nntp });
}

/* tags */

string article_tag(string tag_name, mapping args, string contents,
                   object request_id, object f, mapping defines, object fd)
{
  /*
      XXX here make all headers nad body avaliable
          via first element of result array
   */

  array(mapping) result = ({ });
  string art = "";
  object msg = 0;
  mixed res = 0;
  object nntp = 0;
  mapping hdrs = ([]);

  nntp = pop_nntp();

  if (!nntp) return "<font color=\"red\">Can't connect to NNTP server</font><br>";

  if (args->group) res = nntp->group(args->group);

  if (args->msgid) art = nntp->article(args->msgid);
  else if (args->article) art = nntp->article(args->article);

  push_nntp(nntp);

  if (art) msg = MIME.Message(art);

  foreach (indices(msg->headers), string ind)
    hdrs[ind] = mime_decode(msg->headers[ind]);

  result += ({ hdrs });

  result[0]->body = msg->getdata() || "<font color=\"red\">No article body</font><br>";

  result[0]->body = mime_decode(result[0]->body);

  contents = do_output_tag(args, result, contents, request_id);

  return contents;
}

string group_tag(string tag_name, mapping args, string contents,
                 object request_id, object f, mapping defines, object fd)
{
  /*
      XXX here list group
   */

  array(mapping) result = ({ });
  object msg = 0;
  array grp = 0;
  mapping xover = 0;
  object nntp = 0;

  nntp = pop_nntp();

  if (!nntp) return "<font color=\"red\">Can't connect to NNTP server</font><br>";

  if (args->group) grp = nntp->group(args->group);

  if (grp) xover = nntp->xover(sprintf("%d-%d", (args->min || grp[2] - 25),
						(args->max || grp[2])));

  push_nntp(nntp);

  if (!xover) return "<font color=\"red\">No articles in group</font><br>";

  foreach (sort(indices(xover)), int article)
  {
    mapping art = ([]);

    art->article = article;
    art->subject = mime_decode(xover[article][0]);
    art->from = mime_decode(xover[article][1]);
    art->date = xover[article][2];
    art->group = args->group;

    result += ({ art });
  }

  contents = do_output_tag( args, result, contents, request_id );

  return contents;
}

void create()
{
  defvar("nntpserver", "localhost", "News server",
	 TYPE_STRING,
	 "Specifies the default NNTP server.\n");
}

/*
 * More interface functions
 */

object conf;

void start(int level, object _conf)
{
  if (_conf) {
    conf = _conf;
  }

  foreach (nntps, object nntp) destruct(nntp);

  nntps = ({});
}

void stop()
{
  foreach (nntps, object nntp) destruct(nntp);
}

string status()
{
  string result = "";

  result += "<p><font color=\"red\">Enabled</font><br>\n";
  result += "<p>" + sizeof(nntps) + " active connections in queue<br>\n";

  return result;
}

mapping query_container_callers()
{
  return( ([ 
		"article":article_tag,
		"group":group_tag
	   ]) );
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: nntpserver
//! Specifies the default NNTP server.
//!
//!  type: TYPE_STRING
//!  name: News server
//
