/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

//
//! module: mnoGoSearch
//!  Support for the mnoGoSearch search engine using the Pike API module.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant module_type   = MODULE_PARSER;
constant module_name   = "mnoGoSearch";
constant module_doc    = "Support for the mnoGoSearch search engine using the Pike API module. "
#if !constant(mnoGo.Query)
"<p><font color=\"red\">The mnoGo Pike Extension module is not available!</font></p>"
#endif
;

constant module_unique = 1;
constant cvs_version   = "$Id$";
constant thread_safe=1;


//! tag: mnogosearch
//!  Insert the mnoGoSearch form and result.
//!
//! attribute: source
//!  The source location of the search database using URL format.
//!  I.e &lt;DBType&gt;:[//[DBUser[:DBPass]@]DBHost[:DBPort]]/DBName/
//! attribute: dbmode
//!  The storage mode of the database (as defined in index.conf). One of
//!  single, multi, crc or crc-multi.
//!  default: single
//! attribute res-per-page
//!  Comma-separated list of integers specifying the options for number
//!  of results per page.
//!  default: 20
//! attribute: tags
//!  List with tags used to limit the result set to a certain subsection
//!  as defined in the mnoGoSearch indexer.conf. The format is
//!  tag:displayname, tag2:displayname2 etc. The tag '*' is used to allow
//!  searching of the entire database. 
//!  default: Search the entire database.
//! attribute: cache
//!  Enable search result cache if <b>yes</b>.
//!  default: no
#if constant(mnoGo.Query)
string tag_mnogosearch(string tag, mapping m, object id)
{
  mnoGo.Result res;
  string err;
  mapping v = id->variables;
  int sp;
  if(v->q) {
    string cache_key;
    mnoGo.Query qobj;
    if(!m->source)
      return "<p><b>MNOGOSEARCH ERROR: Missing database source!</b></p>";
    
    cache_key = m->source + sprintf("%O\n", this_thread());
    if(!(qobj = cache_lookup("mnogo", cache_key))) {
      qobj = mnoGo.Query(m->source, m->dbmode || "simgle");
      cache_set("mnogo", cache_key, qobj);
    }
    
    qobj->set_param(mnoGo.PARAM_PAGE_SIZE, (int)v->rpp || 20);
    qobj->set_param(mnoGo.PARAM_PAGE_NUM, sp = (int)v->sp);
    res = qobj->big_query(v->q);
    if(!res) err =  qobj->error();
  }

  string ret =
    sprintf("<form method=get action=\"%s\">\n"
	    "Search for: <input name=\"q\" SIZE=50 VALUE=\"%s\">"
	    "<INPUT TYPE=\"submit\" VALUE=\"Search!\"><BR>\n"
	    "</form>", id->not_query, v->q || "");
  if(res) {
    if(res->num_rows()) {
      array nextprev = ({});
      if(!has_value(id->query, "sp=")) {
	id->query += "&sp="+sp;
      }
      if(sp) {
	nextprev += ({  sprintf("<a href=\"%s?%s\"><- Previous Page </a>",
				http_encode_string(id->not_query),
				replace(id->query||"", "sp="+sp,
					"sp="+(sp-1))) });
      }
      if(res->last_doc() < res->total_found()) {
	nextprev += ({  sprintf("<a href=\"%s?%s\">Next Page -></a>",
				http_encode_string(id->not_query),
				replace(id->query||"", "sp="+sp,
					"sp="+(sp+1))) });
      }
      ret += sprintf("<font size=4>Showing document %d-%d of %d matching the "
		     "query.</font><br>Word count: %s.\n"
		     "<hr noshade size=0>%s%s",
		     res->first_doc(), res->last_doc(), res->total_found(),
		     html_encode_string(res->wordinfo()),
		     (nextprev * " - "),
		     sizeof(nextprev) ? "<hr noshade size=0>" : "");
      while(mapping row = res->fetch_row()) {
	row->url = html_encode_string(row->url);
	ret += sprintf("<p><b>%d. %s</b><br>%s<br><a href=\"%s\">%s</a> - %s</p>",
		       row->order, 
		       html_encode_string(row->title),
		       html_encode_string(row->text),
		       row->url, row->url,
		       sizetostring(row->size));
      }

      if(sizeof(nextprev)) {
	ret += "<hr noshade size=0>"+(nextprev * " - ")+"<hr noshade size=0>";
      }
    } else {
      ret += "<font size=4><b>No documents found</b></font>";
    }
  } else if(err){
    ret += "<font size=4><b>MNOGOSEARCH ERROR: "+err+"</b></font>";
  }
  return ret;
}
#else
string tag_mnogosearch(string tag, mapping m, object id) {
  return "<h1>mnoGoSearch support not available!</h1>";
}
#endif


mapping query_tag_callers() {
  return ([ "mnogosearch": tag_mnogosearch]);
}
