/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2003-2004 The Caudium Group
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
 * $Id: navbar.pike,v 1.21.2.2 2004/03/22 13:20:31 vida Exp
 */

/*
 * Authors : David Gourdelier <vida@caudium.net>
 */
 
constant cvs_version = "$Id: navbar.pike,v 1.21.2.2 2004/03/22 13:20:31 vida Exp";
constant thread_safe=1;

#include <module.h>
#define NSESSION id->misc->session_variables->navbar

#define NDEBUG(X) if(QUERY(debug)) { report_debug("NAVBAR_DEBUG\t"__FILE__+"@"+__LINE__+": "+ X + "\n"); }


#define	NAV_NB_ELEM	0				// The number of total elements
#define	NAV_NB_ELEM_PAGE 1	// The number of element to display in a page
#define	NAV_CURRENT_PAGE 2	// The current page number
#define NAV_MAX_PAGES 10
inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER|MODULE_PROVIDER; 
constant module_name = "Navigation bar container";
constant module_doc  = "Adds the &lt;navbar&gt; &lt;/navbar&gt; container."
	       " This way you can have navigation bar more easily in your pike scripts. "
	       "This module is a provider and a container. That means it can only be used "
    		"in Pike code (Caudium modules or script). You have to call the following "
        "functions before this module is parsed: <br/><br/>"
        "<ul><li>Set the number of total elements"
        "<pre>id-&gt;conf-&gt;get_provider(&quot;navbar&quot;)-&gt;set_nb_elements(object id, int n)</pre></li>"
        "<li>Set the number of elements per page"
        "<pre>id-&gt;conf-&gt;get_provider(&quot;navbar&quot;)-&gt;set_nb_elements_per_page(object id, int x)</pre></li></ul>"
        "Then you can call these functions:<br/><br/>"
        "<ul><li>Get the minimum element number to display in this page"
        "<pre>id-&gt;conf-&gt;get_provider(&quot;navbar&quot;)-&gt;get_min_element(object id)</pre></li>"
        "<li>Get the maximum element number to display in this page"
        "<pre>id-&gt;conf-&gt;get_provider(&quot;navbar&quot;)-&gt;get_max_element(object id)</pre></li></ul>"
        "In your RXML page, use the following code to display a navigation bar:<pre>"
        "&lt;navbar&gt;<br/>"
        "&nbsp;&lt;!-- A link to go to the current page - 10, allows navigation when you have lots of pages --&gt;<br/>"
        "&nbsp;&lt;previous_group&gt; &lt;href action=\"previousgroup\"&gt; &amp;lt &lt;/href&gt; &lt;/previous_group&gt;<br/>"
        "&nbsp;&lt;!-- A link to go to the previous page --&gt;<br/>"
        "&nbsp;&lt;previous&gt; &lt;href action=\"prevpage\"&gt; &amp;lt &lt;/href&gt; &lt;/previous&gt;<br/>"
        "&nbsp;&lt;!-- the previous pages (numbered) --&gt;<br/>"
        "<-- You can use basehref to specify the path part of the URI -->"
        "&nbsp;&lt;emit source=\"navbar_loop_previous\" scope=\"loop_previous\""
        "&gt; &lt;href countpageloop=\"&loop_previous.number;\" basehref=\"/foobar\" action=\"gopage\"&gt; &loop_previous.number; &lt;/href&gt; &lt;/emit&gt;<br/>"
        "&nbsp;&lt;!-- the current page --&gt;<br/>"
        "&nbsp;&lt;current/&gt;<br/>"
        "&nbsp;&lt;!-- the next pages (numbered) --&gt;<br/>"
        "&nbsp;&lt;emit source=\"navbar_loop_next\" scope=\"loop_next\" "
        "&gt;&lt;href action=\"gopage\" countpageloop=\"&loop_next.number;\"&gt; &loop_next.number; &lt;/href&gt; &lt;/emit&gt;<br/>"
        "&nbsp;&lt;!-- A link to go to the next page --&gt;<br/>"
        "&nbsp;&lt;next&gt;  &lt;href action=\"nextpage\"&gt; &amp;gt &lt;/href&gt;  &lt;/next&gt;<br/>"
        "&nbsp;&lt;!-- A link to go to the current page + 10, allows navigation when you have lots of pages --&gt;<br/>"
        "&nbsp;&lt;next_group&gt; &lt;href action=\"nextgroup\"&gt; &amp;lt &lt;/href&gt; &lt;/next_group&gt;<br/>"
        "&lt;/navbar&gt;<br/>"
        "</pre>";

constant module_unique = 1;

void create()
{
  defvar("session_module", "123session", "The session module to use",
        TYPE_STRING_LIST, "The session module to use", ({ "123session", "gsession" }));
#ifdef NDEBUG
  defvar("debug", 0, "Debug", TYPE_FLAG, "Enable debug");
#endif
}

string query_provides()
{
  return "navbar";
}

/* PROVIDER PART */

private void create_session(object id)
{
  // don't create the session more than one time for each HTTP request
  if(!id->misc->navbar_session_flushed)
  {
    NDEBUG("Creating session");
    NSESSION = allocate(3);
    // page 0 does not exist, default to page 1
    NSESSION[NAV_CURRENT_PAGE] = 1;
    id->misc->navbar_session_flushed = 1;
  }
}

private void wrong_usage(object id)
{
  if(!NSESSION)
    throw(({ "You must call set_nb_elements() and "
          "set_nb_elements_per_page() before using this function\n", backtrace() }));
}

private void fetch_args(object id)
{
  // fetch arguments from links only one time for each HTTP request
  if(!id->misc->navbar_args_fetched)
  {
    NDEBUG("Fetching args");
    if(id->variables->navbarnextblock)
      set_current_page(id, get_current_page(id) + 1);
    if(id->variables->navbarprevblock)
      set_current_page(id, get_current_page(id) - 1);
    if(id->variables->navbarnextgroup)
      {
	int page_id = get_current_page (id) + NAV_MAX_PAGES;
	if (page_id>get_lastpage (id)) page_id =get_lastpage (id);
	set_current_page(id, page_id);
      }
    if(id->variables->navbarprevgroup)
      {
	int page_id = get_current_page(id) - NAV_MAX_PAGES;
	if (page_id<1) page_id =1;
	set_current_page(id, page_id);
      }
    if(id->variables->navbargotoblock)
      set_current_page(id, (int)id->variables->navbarelement);
    id->misc->navbar_args_fetched = 1;
  }
}

int get_current_page(object id)
{
  wrong_usage(id);
  if(id->misc->navbar_session_flushed)
  {
    NSESSION[NAV_CURRENT_PAGE] =
     ceil((float) NSESSION[NAV_NB_ELEM] / NSESSION[NAV_NB_ELEM_PAGE]);
    NSESSION[NAV_CURRENT_PAGE] = ((int) NSESSION[NAV_CURRENT_PAGE]) || 1;
    NDEBUG("get_current_page: page="+NSESSION[NAV_CURRENT_PAGE]);
  }
  return NSESSION[NAV_CURRENT_PAGE];
}

private int get_nb_elements(object id)
{
  NDEBUG("get_nb_elements: nb="+NSESSION[NAV_NB_ELEM]);
  return NSESSION[NAV_NB_ELEM];
}

private int get_nb_elements_per_page(object id)
{
  NDEBUG("get_nb_elements_per_page: nb="+NSESSION[NAV_NB_ELEM_PAGE]);
  return NSESSION[NAV_NB_ELEM_PAGE] || 10;
}

private int get_lastpage(object id)
{
  int lastpage = (int)ceil((float)get_nb_elements(id)/(float)get_nb_elements_per_page(id));
  NDEBUG("get_lastpage: page="+lastpage);
  return lastpage;
}

void start(int num, object conf)
{
  if(QUERY(session_module) == "123session")
    module_dependencies(conf, ({ "123session" }));
  if(QUERY(session_module) == "gsession")
    module_dependencies(conf, ({ "gsession" }));
}

void set_nb_elements(object id, int nb)
{
  if(nb < 0)
    throw(({ "Can't set a negative number of elements", backtrace() }));
  if(!NSESSION)
  {
    create_session(id);
    NSESSION[NAV_NB_ELEM] = nb;
    NDEBUG("set_nb_elements: nb="+nb);
  }
  if(nb != NSESSION[NAV_NB_ELEM])
  {
    int old_nb = NSESSION[NAV_NB_ELEM];
    NSESSION[NAV_NB_ELEM] = nb;
    // we were on the last page and one element come
    // put the last page again so that the user can see
    // the new element more easily
    if(NSESSION[NAV_CURRENT_PAGE] == get_lastpage(id) - 1 &&
        (int)ceil((float)old_nb/(float)get_nb_elements_per_page(id)) < get_lastpage(id))
    {
      NSESSION[NAV_CURRENT_PAGE]++;
    }
    // overflow: we have less page(s) now than before
    if(NSESSION[NAV_CURRENT_PAGE] > get_lastpage(id))
    {
      // page 0 does not exist, default to page 1
      NSESSION[NAV_CURRENT_PAGE] = get_lastpage(id);
    }
    NDEBUG("set_nb_elements: nb="+nb);
  }
}

void set_nb_elements_per_page(object id, int nb)
{
  if(nb <= 0)
    throw(({ "Can't set a negative or null number of elements per page\n", backtrace() }));
  if(!NSESSION || nb != NSESSION[NAV_NB_ELEM_PAGE])
  {
    create_session(id);
    NSESSION[NAV_NB_ELEM_PAGE] = nb;
    NDEBUG("set_nb_elements_per_page: nb="+nb);
  }
}

void set_current_page(object id, int page)
{
  wrong_usage(id);
  if(page <= 0)
    throw(({ "Can't set a negative or null page\n", backtrace() }));
  NSESSION[NAV_CURRENT_PAGE] = page;
  NDEBUG("set_current_page: page="+page);
}

int get_min_element(object id)
{
  wrong_usage(id); 
  fetch_args(id);
  int min_elem = (get_current_page(id) -1) * get_nb_elements_per_page(id);
  int offset = min_elem%get_nb_elements_per_page(id);

  // always begin the list at the beginning of a page
  if(offset != 0)
    min_elem -= offset;
  // overflow management
  if(min_elem > get_nb_elements(id))
    min_elem = 0;
  if(min_elem < 0)
    min_elem = 0;
  NDEBUG("get_min_element: min_elem="+min_elem);
  return min_elem;
}

int get_max_element(object id)
{
  wrong_usage(id);
  fetch_args(id);
  int max_elem = get_min_element(id) + get_nb_elements_per_page(id) - 1;
  // overflow management
  if(max_elem >= get_nb_elements(id))
  {
    if(get_nb_elements_per_page(id) + get_min_element(id) < get_nb_elements(id))
      max_elem = get_nb_elements_per_page(id) + get_min_element(id);
    else
      max_elem = get_nb_elements(id) - 1;
  }
  NDEBUG("get_max_element: max_elem="+max_elem);
  return max_elem;
}

/* PARSER PART */
mapping query_container_callers ()
{
  return ([
      "navbar": container_navbar
    ]);
}

mapping query_emit_callers()
{
  return ([
      "navbar_loop_previous": emit_loop_navbar,
      "navbar_loop_next": emit_loop_navbar,
  ]);
}

//! container: navbar
//!  Zone for the navigation bar
//! childcontainer : current
//! childcontainer : previous
//! childcontainer : loop_previous
//! childcontainer : loop_next
//! childcontainer : next
string container_navbar(string tag_name, mapping args, string contents,object id)
{
  string out = "";                                              // string to output

  if(get_nb_elements(id) > get_nb_elements_per_page(id))
  {
    out = Caudium.parse_html(contents,
                      ([
                       "current"       : tag_navbar_current,
                       ]),
                      ([
                     "previous_group": container_noloop_navbar,
                     "previous"      : container_noloop_navbar,
                     "next"          : container_noloop_navbar,
                     "next_group"    : container_noloop_navbar,
                     "href"          : container_navbar_href
                       ]),
                      id);
  }
  return out;
}

//! tag: current
//!  Zone for current page
//! parentcontainer : navbar
string tag_navbar_current(string tag_name, mapping args, object id)
{
  return (string)get_current_page(id);
}

// Code for <navbar></> nested containers
string container_noloop_navbar(string tag_name, mapping args, string contents, object id)
{
  string out = "";                                              // The string to output
  string originalcontents = contents;                           // Backup the original contents for parsing it several times

  switch(tag_name)
  {
    case "previous_group":
      //! container: previous_group
      //!  Zone for the previous_group screen
      //! parentcontainer : navbar
      //! note: screen: mailindex
      if (get_current_page(id) > NAV_MAX_PAGES)
      {
        out = contents;
      }
      break;

    case "previous":
      //! container: previous
      //!  Zone for the previous screen
      //! parentcontainer : navbar
      //! note: screen: mailindex
      if (get_current_page(id) > 1)
      {
        out = contents;
      }
      break;

    case "next":
      //! container: next
      //!  Zone for the next screen
      //! parentcontainer : navbar
      //! note: screen: mailindex
      if (get_current_page(id) < get_lastpage(id))
      {
        out = contents;
      }
      break;

    case "next_group":
      //! container: next_group
      //!  Zone for the next_group screen
      //! parentcontainer : navbar
      //! note: screen: mailindex
      if (get_current_page(id) < get_lastpage(id) - NAV_MAX_PAGES)
      {
        out = contents;
      }
      break;
  }

  return out;
}

//! container: href
//!  Links for going to the correct page
//! parentcontainer : navbar
string container_navbar_href(string tag_name, mapping args, string contents, object id)
{
  mapping vars = ([ ]);
 
  switch(args->action)
  {
    case "nextpage":
      vars->navbarnextblock = "1";
    break;

    case "nextgroup":
      vars->navbarnextgroup = "1";
    break;

    case "previouspage":
    case "prevpage":
      vars->navbarprevblock = "1";
    break;

    case "previousgroup":
      vars->navbarprevgroup = "1";
    break;

    case "gopage":
      if(!args->countpageloop)
        return "<!-- This container requires the countpageloop argument -->\n";
      vars->navbargotoblock ="1";
  }
  m_delete(args, "action");

  string baseuri = args->basehref || id->not_query;
  args->href = Caudium.add_pre_state(baseuri, id->prestate) + "?" + 
    Protocols.HTTP.http_encode_query(vars); 
  if(args->countpageloop)
  {
    args->href += "&amp;navbarelement=" + args->countpageloop;
    m_delete(args, "countpageloop");
  }

  return Caudium.make_container("a", args, contents);
}

// Code for <navbar></> nested loop containers
array(mapping) emit_loop_navbar(mapping args, object id)
{
  int count = 0;
  int offset = 0;
  int i = 0;

  switch(args->source)
  {
    case "navbar_loop_previous":
      //! container: loop_previous
      //!  Zone for each previous page available
      int first_page = get_current_page(id) - NAV_MAX_PAGES;
      offset = abs(1 - first_page);
      if (first_page < 1)
	    {
	      first_page = 1;
	    }

      array outlet = allocate(get_current_page(id) - first_page);
      for(count=first_page; count<get_current_page(id); count++)
      {
        int countpageloop=count;
        outlet[i++] = ([ "number" : (string)count ]);
      }
      return outlet;

    case "navbar_loop_next":
      //! container: loop_next
      //!  Zone for each next page available
      int last = get_current_page(id) + NAV_MAX_PAGES - offset;
      if (last > get_lastpage(id))
	    {
	      last = get_lastpage(id);
	    }
      outlet = allocate(last - get_current_page(id));
      for(count=get_current_page(id)+1; count<=last; count++)
      {
        int countpageloop=count;
        outlet[i++] =  ([ "number" : (string)count ]);
      }
      return outlet;
  }
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
