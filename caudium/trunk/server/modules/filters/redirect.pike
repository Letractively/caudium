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

//
//! module: Redirect Module v2.0
//!  The redirect module. Redirects requests from one filename to
//!  another. This can be done using "internal" redirects (much
//!  like a symbolik link in unix), or with normal HTTP redirects.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_FIRST
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
#include <pcre.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_FIRST;
constant module_name = "Redirect Module v2.0";
constant module_doc  = "The redirect module. Redirects requests from one filename to "
	      "another. This can be done using \"internal\" redirects (much"
	      " like a symbolik link in unix), or with normal HTTP redirects.";
constant module_unique = 1;

private int redirs = 0;

void create()
{
  defvar("fileredirect", "", "Redirect patterns", TYPE_TEXT_FIELD, 
	 "Redirect one file to another. The syntax is 'regexp to_URL',"
	 "or 'prefix to_URL', or 'exact file_name to_URL<p>Some examples:"
	 "<pre>"
         "	/from/.*      http://to.idonex.se/to/%f<br />"
         "	.*\\.cgi      http://cgi.foo.bar/cgi-bin/%p<br />"
	 "	/thb/.*       %u/thb_gone.html<br />"
	 "	/roxen/       http://www.roxen.com/<br />"
	 "	exact /       /main/index.html\n"
	 "</pre>"
	 "</p><p><b>Special Substitutions (in the 'to' field):</b><dl compact"
	 "=\"compact\">"
	 "<dt>%f</dt>"
	 "<dd>The file name of the matched URL without the path.</dd>\n"
	 "<dt>%p</dt>"
	 "<dd>The full virtual path of the matched URL.</dd>\n"
	 "<dt>%u</dt>"
	 "<dd>The manually configured Server URL. This is useful if you want "
	 "your redirect to be external instead of an internal rewrite and "
	 "don't want to hardcode the URL in the patterns.</dd>\n"
	 "<dt>%h</dt>"
	 "<dd>The accessed Server URL, using the HTTP host header. If "
	 "the host header is missing, the configured Server URL will be "
	 "used instead. This is useful if you want your external redirect to "
	 "to the same host as the user accessed (ie if they access the site "
	 "as http://www/ they won't get a redirect to http://www.domain.com/)."
	 "\n</dd></dl></p>\n\n<p>\n"
	 "The two last lines from the examples above are special cases. "
	 "If the first word on the line is 'exact', the filename following "
	 "must match _exactly_. This is equivalent to entering ^FILE$, but "
	 "faster. </p>"
	 "<p>You can use '(' and ')' in the regular expression to "
	 "separate parts of the from-pattern when using regular expressions." 
	 " The parts can then be insterted into the 'to' string with " 
	 " $1, $2 etc.\n</p>"
	 "<p>More examples:<pre>"
	 ".*/SE/liu/lysator/(.*)\.class    /java/classes/SE/liu/lysator/$1.class<br />"
	 "/(.*).en.html                   /(en)/$1.html<br />"
	 "(.*)/index.html                 %u/$1/\n</pre>"
	 "</p><p>"
	 "If the to file isn't an URL, the redirect will always be handled "
	 "internally, so add %u to generate an actual redirect.</p><p>"
	 "<b>Note:</b> "
	 "For speed reasons: If the from pattern does _not_ contain "
	 "any '*' characters, it will not be treated like a regular "
	 "expression, instead it will be treated as a prefix that must "
	 "match exactly.</p>" ); 
}

mapping redirect_patterns = ([]);
mapping exact_patterns = ([]);

void start()
{
  array a;
  string s;
  redirect_patterns = ([]);
  exact_patterns = ([]);
  foreach(replace(QUERY(fileredirect), "\t", " ")/"\n", s)
  {
    a = s/" " - ({""});
    if(sizeof(a)>=2)
    {
      if(a[0]=="exact" && sizeof(a)>=3)
	exact_patterns[a[1]] = a[2];
      else
	redirect_patterns[a[0]] = a[1];
    }
  }
}

string comment()
{
  return sprintf("Number of patterns: %d+%d=%d, Redirects so far: %d", 
		 sizeof(redirect_patterns),sizeof(exact_patterns),
		 sizeof(redirect_patterns)+sizeof(exact_patterns),
		 redirs);
}

string get_host_url(object id)
{
  string url;
  if(id->misc->host) {
    string p = ":80", prot = "http://";
    array h;
    if(id->ssl_accept_callback) {
      // This is an SSL port. Not a great check, but what is one to do?
      p = ":443";
      prot = "https://";
    }
    h = id->misc->host / p  - ({""});
    if(sizeof(h) == 1)
      // Remove redundant port number.
      url=prot+h[0];
    else
      url=prot+id->misc->host;
  }
  return url;
}

mixed first_try(object id)
{
  string f, to;
  mixed tmp;

  if(id->misc->is_redirected)
    return 0;

  if(catch {
    string m;
    int ok;
    m = id->not_query;
    if(id->query)
       if(sscanf(id->raw, "%*s?%[^\n\r ]", tmp))
	  m += "?"+tmp;

    foreach(indices(exact_patterns), f)
    {
      if(m == f)
      {
	to = exact_patterns[f];
	ok=1;
	break;	
      }
    }
    if(!ok)
      foreach(indices(redirect_patterns), f)
	if(!search(m, f))
	{
	  to = redirect_patterns[f] + m[strlen(f)..];
	  sscanf(to, "%s?", to);
	  break;
	} else if(search(f, "*")!=-1) {
	  array foo;
	  function split;
	  if(f[0] != '^')
	    split = Regexp("^"+f)->split;
	  else
	    split = Regexp(f)->split;
	  
	  if((foo=split(m)))
	  {
	    array bar = Array.map(foo, lambda(string s, mapping f) {
	      return "$"+(f->num++);
	    }, ([ "num":1 ]));
	    foo +=({(id->not_query/"/"-({""}))[-1], id->not_query[1..] });
	    bar +=({ "%f", "%p" });
	    foo = Array.map(foo, lambda(mixed s) { return (string)s; });
	    bar = Array.map(bar, lambda(mixed s) { return (string)s; });
	    to = replace(redirect_patterns[f], bar, foo);
	    break;
	  }
	}
  })
    report_error("REDIRECT: Compile error in regular expression. ("+f+")\n");

  if(!to)
    return 0;
  string url,hurl;
  url = id->conf->query("MyWorldLocation");
  url = url[..strlen(url)-2];
  hurl = get_host_url(id)||url;
  
  to = replace(to, ({"%u", "%h"}), ({ url, hurl}));
  if(to == url + id->not_query ||
     url == id->not_query ||
     to == hurl + id->not_query)
    // Prevent eternal redirects.
    return 0;

  id->misc->is_redirected = 1; // Prevent recursive internal redirects

  redirs++;
  if((strlen(to) > 6 && 
      (to[3]==':' || to[4]==':' || 
       to[5]==':' || to[6]==':')))
  {
     to=replace(to, ({ "\000", " " }), ({"%00", "%20" }));

     return http_low_answer( 302, "") 
	+ ([ "extra_heads":([ "Location":to ]) ]);
  } else {
     id->variables = ([]);
     id->raw_url = http_encode_string(to);
     id->not_query = id->scan_for_query( to );
  }
}



/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: fileredirect
//! Redirect one file to another. The syntax is 'regexp to_URL',or 'prefix to_URL', or 'exact file_name to_URL<p>Some examples:<pre>	/from/.*      http://to.idonex.se/to/%f<br />	.*\.cgi      http://cgi.foo.bar/cgi-bin/%p<br />	/thb/.*       %u/thb_gone.html<br />	/roxen/       http://www.roxen.com/<br />	exact /       /main/index.html
//!</pre></p><p><b>Special Substitutions (in the 'to' field):</b><dl compact="compact"><dt>%f</dt><dd>The file name of the matched URL without the path.</dd>
//!<dt>%p</dt><dd>The full virtual path of the matched URL.</dd>
//!<dt>%u</dt><dd>The manually configured Server URL. This is useful if you want your redirect to be external instead of an internal rewrite and don't want to hardcode the URL in the patterns.</dd>
//!<dt>%h</dt><dd>The accessed Server URL, using the HTTP host header. If the host header is missing, the configured Server URL will be used instead. This is useful if you want your external redirect to to the same host as the user accessed (ie if they access the site as http://www/ they won't get a redirect to http://www.domain.com/).
//!</dd></dl></p>
//!
//!<p>
//!The two last lines from the examples above are special cases. If the first word on the line is 'exact', the filename following must match _exactly_. This is equivalent to entering ^FILE$, but faster. </p><p>You can use '(' and ')' in the regular expression to separate parts of the from-pattern when using regular expressions. The parts can then be insterted into the 'to' string with  $1, $2 etc.
//!</p><p>More examples:<pre>.*/SE/liu/lysator/(.*).class    /java/classes/SE/liu/lysator/$1.class<br />/(.*).en.html                   /(en)/$1.html<br />(.*)/index.html                 %u/$1/
//!</pre></p><p>If the to file isn't an URL, the redirect will always be handled internally, so add %u to generate an actual redirect.</p><p><b>Note:</b> For speed reasons: If the from pattern does _not_ containany '*' characters, it will not be treated like an regularexpression, instead it will be treated as a prefix that must match exactly.</p>
//!  type: TYPE_TEXT_FIELD
//!  name: Redirect patterns
//
