/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 * $Id$
 */

/*
 * Authors : David Gourdelier <vida@caudium.net>
 */
 
constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#define TSESSION id->misc->session_variables->tabsort

#ifdef Caudium.parse_html
#define PARSER Caudium.parse_html
#else
#ifdef CAMAS.Parse.parse_html
#define PARSER CAMAS.Parse.parse_html
#else
#define PARSER parse_html
#endif
#endif

#define TDEBUG(X) if(QUERY(debug)) { report_debug("TABLESORT_DEBUG\t"__FILE__+"@"+__LINE__+": "+ X + "\n"); }

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER|MODULE_PROVIDER; 
constant module_name = "Table sort container";
constant module_doc  = #"Adds the &lt;tabsort&gt; &lt;/tabsort&gt; container.
	       This way you create sorting table more easily in your pike scripts.
	       This module is a provider and a container. That means it can only be used
    		 in Pike code (Caudium modules or script). You have to call the following
         functions before this module is parsed: <br/><br/>
         <ul><li>Set the elements of your table
         <pre>void id-&gt;conf-&gt;get_provider(&quot;tabsort&quot;)-&gt;set_table(object id, array(array) table, array(string) column_names, void|string col2sort, void|int backward_sort)</pre></li>
         <li>Set the current table to sort
         <ul><li>id: Caudium id object</li>
         <li>table: Your table to sort, each row is one row in the HTML output, each column is a column in
         the HTML output</li>
         <li>column_names: The column names to use for each column. The name you set here will be use in the
         RXML file</li>
         <li>col2sort: The table to sort if the user did not specify one</li>
         <li>backward_sort: Does the first sort should be a reverse sort ?</li></ul></ul>
         Then you can call these functions:<br/><br/>
         <ul><li>Get the array sorted according to user's need
         <br/><pre>array(array) id-&gt;conf-&gt;get_provider(&quot;tabsort&quot;)-&gt;array(array) get_table(object id);</pre></li></ul>
         In your RXML page, use the following code to display a  a navigation bar:
         <pre>&lt;table border=&quot;1&quot;&gt;
  &lt;tr&gt;
    &lt;!-- arrowup: an image to display when reverse searching on a given column --&gt;
    &lt;!-- arrowdown: an image to display when searching on a given column --&gt;
    &lt;!-- arrownone: an image to display when the column is not sorted --&gt;
    &lt;tabsort arrowup=&quot;images/arrowup.png&quot; arrowdown=&quot;images/arrowdown.png&quot; arrownone=&quot;images/arrownone.png&quot;&gt;
      &lt;!-- basehref: the path part of an URI to use for the link (optionnal) --&gt;
      &lt;!-- action=&quot;cn&quot;: if the user click to sort this column, the array given in the pike script will be
      sorted according to the column named cn --&gt;
      &lt;td&gt;&lt;sort_href basehref=&quot;/mail&quot; action=&quot;cn&quot;&gt;&lt;img_arrow border=&quot;0&quot;&gt;Name&lt;/img_arrow&gt;&lt;/sort_href&gt;&lt;/td&gt;
      &lt;td&gt;&lt;sort_href action=&quot;mail&quot;&gt;&lt;img_arrow border=&quot;0&quot;&gt;Mail&lt;/img_arrow&gt;&lt;/sort_href&gt;&lt;/td&gt;
    &lt;/tabsort&gt;
 &lt;/tr&gt;
&lt;/table&gt;
</pre>

Then in your pike script call :
<pre>
id-&gt;conf-&gt;get_provider(&quot;tabsort&quot;)-&gt;set_table(id,<br/>
              ({ ({ &quot;David Gourdelier&quot;, &quot;vida@caudium.net&quot; }),
                 ({ &quot;Bertrand Lupart&quot;, &quot;bertrand@caudium.net&quot; }),
              }),
              ({ &quot;cn&quot;, &quot;mail&quot; }), &quot;cn&quot;);
</pre>
To get the array sorted according to the user's need:
<pre>
id-&gt;conf-&gt;get_provider(&quot;tabsort&quot;)-&gt;array(array) get_table(id);</pre>";


constant module_unique = 1;

void create()
{
  defvar("session_module", "123session", "The session module to use",
        TYPE_STRING_LIST, "The session module to use", ({ "123session", "gsession" }));
#ifdef TDEBUG
  defvar("debug", 0, "Debug", TYPE_FLAG, "Enable debug");
#endif
}

string query_provides()
{
  return "tabsort";
}

/* PROVIDER PART */

private void create_session(object id)
{
  // don't create the session more than one time for each HTTP request
  if(!id->misc->tabsort_session_flushed)
  {
    TDEBUG("Creating session");
    TSESSION = allocate(2);
    id->misc->tabsort_session_flushed = 1;
  }
}

private void wrong_usage(object id)
{
   if(!TSESSION)
    throw("You must call set_table() before using this function\n");
}

private void fetch_args(object id)
{
  // fetch arguments from links only one time for each HTTP request
  if(!id->misc->tabsort_args_fetched)
  {
    TDEBUG(sprintf("Fetching args %O", id->variables));
    if(id->variables->changesort)
      set_col(id, id->variables->col);
    if(id->variables->togglesortorder)
      change_sortorder(id, !get_sortorder(id));
    id->misc->tabsort_args_fetched = 1;
  }
}

array(array) get_table(object id)
{
  wrong_usage(id);
  fetch_args(id);
  if(!get_sortorder(id))
    id->misc->tabsort_table = id->misc->tabsort_table->sort(get_col(id));
  else
    id->misc->tabsort_table = id->misc->tabsort_table->rsort(get_col(id));
  return values(id->misc->tabsort_table); 
}

private void set_col(object id, string column_name)
{
  wrong_usage(id);
  if(TSESSION[1] != column_name)
  {
    TSESSION[1] = column_name;
    TDEBUG("Set new sorting column:" + column_name);
    id->misc->tabsort_table->sort(TSESSION[1]);
  }
}

private string get_col(object id)
{
  wrong_usage(id);
  return TSESSION[1];
}

private void change_sortorder(object id, int order)
{
  wrong_usage(id);
  TDEBUG("Changing sort order\n");
  if(TSESSION[0] != order)
    TSESSION[0] = order;
}

private int get_sortorder(object id)
{
  wrong_usage(id);
  return TSESSION[0]; 
}

void set_table(object id, array(array) table, array(string) column_names,
    void|string col2sort, int|void backward_order)
{
  id->misc->tabsort_table = ADT.Table.table(table, column_names);
  TDEBUG(sprintf("Table is %O, column_names=%O\n", table, column_names));
  if(!TSESSION)
  {
    create_session(id);
    if(backward_order)
      change_sortorder(id, !get_sortorder(id));
    if(col2sort)
      set_col(id, col2sort);
  }
}

void start(int num, object conf)
{
  if(QUERY(session_module) == "123session")
    module_dependencies(conf, ({ "123session" }));
  if(QUERY(session_module) == "gsession")
    module_dependencies(conf, ({ "gsession" }));
}

/* PARSER PART */
mapping query_container_callers ()
{
  return ([
      "tabsort": container_tabsort
    ]);
}

//! container: tabsort
//!  Zone for the table sort
//! childcontainer : sortcol
//! attribute : arrowup
//!  Link to the image displayed when column is sorting
//! attribute : arrownone
//!  Link to the image when column is not sorted
//! attribute : arrowdown
//!  Link to the image when column is reverse sorting
string container_tabsort(string tag_name, mapping args, string contents, object id)
{
  string out = "";                                              // string to output

  out += PARSER(contents,
                      ([
                       ]),
                      ([
                         "sort_href": container_tabsort_sort_href
                       ]),
                      id, args->arrowup, args->arrowdown, args->arrownone);
  return out;
}


//! container: sortcol
string container_tabsort_sort_href(string tag_name, mapping args, string contents, object id, 
    string arrowup, string arrowdown, string arrownone)
{
  string out = "";                                              // string to output

  // by default, sort on the first column
  string column = zero_type(args->action) ? indices(id->misc->tabsort_table)[0] : args->action;

  mapping vars = ([ ]);

  if (column == get_col(id))
    vars += ([ "togglesortorder" : "1" ]);
  else
    vars += ([
              "changesort" : "1",
              "col"              : column,
    ]);
 
  string baseuri = args->basehref || id->not_query;
  args->href = add_pre_state(baseuri, id->prestate)
    + "?" + Protocols.HTTP.http_encode_query(vars); 
  args->target = "_self";

  out = CAMAS.Parse.parse_html(contents,
                   ([
                       "img_arrow"        : tag_tabsort_sort_href_img,
                    ]),
                   ([
                    ]),
                   id, column, arrowup, arrowdown, arrownone);
  out = CAMAS.Tools.make_container("a", args, out);

  return out;
}

string tag_tabsort_sort_href_img(string tag_name, mapping args, object id, 
    string column, string arrowup, string arrowdown, string arrownone)
{
  if(column == get_col(id))
  {
    if(get_sortorder(id))
    {
      if(arrowup)
      {
        args->src = arrowup;
      	args->alt = "/\\";
        m_delete(args, "arrowup");
      	return make_tag("img", args);
      }
      else
        return "/\\";
    }
    else if(!get_sortorder(id))
    {
      if(arrowdown)
      {
        args->src = arrowdown;
      	args->alt = "\\/";
      	m_delete(args, "arrowdown");
        return make_tag("img", args);
      }
      else
        return "\\/";
    }
  }
  else
  {
    if(arrownone)
    {
      args->src = arrownone;
      args->alt = "-";
      m_delete(args, "arrownone");
      return make_tag("img", args);
    }
    else
      return "-";
  }

  return "";
}

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
