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
//! module: Redirect v3.0
//!  The redirect module. Redirects requests from one filename to
//!  another. This can be done using "internal" redirects (much
//!  like a symbolic link in unix), or with normal HTTP redirects.
//!
//!  This third version of the module is backwards compatible with
//!  version 2.0. The improvements are: <ul>
//!  <li>Patterns are matched in the order entered instead of random order.</li>
//!  <li>Greater control of the type of matching done using keywords.</li>
//!  <li>Added glob match method.</li>
//!  <li>Compilation of regular expression is cached, which should greatly
//!      improve matching speed when there are many regexp patterns.</li>
//!  </ul>
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
constant module_name = "Redirect v3.0";
constant module_doc  = "\
The redirect module. Redirects requests from one filename to \
another. This can be done using \"internal\" redirects (much \
like a symbolic link in unix), or with normal HTTP redirects. \
<p>This third version of the module is backwards compatible with \
version 2.0. The improvements are: <ul> \
 <li>Patterns are matched in the order entered instead of random order.</li> \
 <li>Greater control of the type of matching done using keywords.</li>\
 <li>Added glob match method.</li>\
 <li>Compilation of regular expression is cached, which should greatly \
     improve matching speed when there are many regexp patterns.</li> \
</ul>";

constant module_unique = 1;

private int redirs = 0;

void create()
{
  defvar("fileredirect", "", "Redirect patterns", TYPE_TEXT_FIELD, 
	 "\
The redirect patterns are used to rewrite a URL or send a redirect \n\
to an external URL. The syntax is: \n\
<blockquote><b>[type] matchstring destination</b></blockquote> \n\
The field separator can be one or more space or tab characters. Note that \n\
this disallows the use of these characters in the actual fields. \n\
Valid match types are: \n\
<dl> \n\
<p><dt><b>exact</b></dt><dd>The source resource must match \n\
<b>matchstring</b> exactly.</dd></p> \n\
 \n\
<p><dt><b>glob</b></dt><dd>The <b>matchstring</b> is a glob \n\
pattern.</dd></p> \n\
 \n\
<p><dt><b>prefix</b></dt><dd>The source resource much begin with \n\
<b>matchstring</b>. When using prefix matching, everything after the \n\
prefix is added last to the <b>destination</b> location.</dd></p> \n\
 \n\
<p><dt><b>regexp</b></dt><dd>The <b>matchstring</b> is a regular \n\
expression.</dd></p> \n\
 \n\
</dl>\
 \n\
<p>For v2.0 compatibility reasons, <b>[type]</b> can be omitted. Then the \n\
pattern type will be deducted automatically as follows: If \n\
<b>matchstring</b> contains a <b>*</b> character, it will be treated \n\
as a <b>regexp</b>. If not, it will be treated as a <b>prefix</b>.</p> \n\
 \n\
<p>The <b>destination</b> field can contain one or more special \n\
tokens. They will be replaced after matching is completed as described below.</p> \n\
 \n\
<p><dl compact=\"compact\"> \n\
<dt><b>%f</b></dt> \n\
<dd>The file name of the matched URL without the path.</dd> \n\
<dt><b>%p</b></dt> \n\
<dd>The full virtual path of the matched URL excluding the initial /.</dd> \n\
<dt><b>%u</b></dt> \n\
<dd>The manually configured server url. This is useful if you want  \n\
your redirect to be external instead of an internal rewrite and  \n\
don't want to hardcode the URL in the patterns.</dd> \n\
<dt><b>%h</b></dt> \n\
<dd>The accessed server url, determined by the HTTP host header. If  \n\
the host header is missing, the configured server url will be  \n\
used instead. This is useful if you want your external redirect to  \n\
to the same host as the user accessed (ie if they access the site  \n\
as http://www/ they won't get a redirect to http://www.domain.com/). \n\
</dd></dl></p> \n\
 \n\
<p>When using regular expression, '(' and ')' can be used to separate \n\
parts of the from-pattern. These parts can then be insterted into the \n\
<b>destination</b> using $1, $2 etc.</p> \n\
 \n\
<p>If <b>destination</b> file isn't a fully qualified URL, the \n\
redirect will always be handled internally. If you want an actual \n\
redirect, you can either use <b>%u</b> or enter the exact URL.</p> \n\
 \n\
<p>Some examples on how to use this module. The smaller, non-bold \n\
text is an example of the effect of all previous non-described lines.</p> \n\
 \n\
<p><pre>" 
	 "<b>prefix	/helpdesk/	http://helpdesk.domain.com/</b><br />"
	 "    <font size=\"-1\">Ex: redirects  /helpdesk/mice/ to http://helpdesk.domain.com/mice/</font><br />"

	 "<b>exact	/index.html	/index.cgi</b><br />"
	 "    <font size=\"-1\">Ex: rewrites only /index.html to /index.cgi</font><br />"
	 
	 "<b>glob	*		http://otherhost.com/%p</b><br />"
	 "<b>regexp	^/		http://otherhost.com/%p</b><br />"
	 "<b>regexp	^/(.*)		http://otherhost.com/$1</b><br />"
	 "<b>prefix	/		http://otherhost.com/</b><br />"
	 "    <font size=\"-1\">Ex: redirects all files to http://otherhost.com/</font><br />"

	 "<b>regexp	^/old[^/]*/	/newdir/%f</b><br />"
	 "    <font size=\"-1\">Ex: rewrites /olddocs/documents/file.html to /newdir/file.html</font><br />"

	 "<b>prefix	/oldfiles/	%h/</b><br />"
	 "    <font size=\"-1\">Ex: redirects /oldfiles/anypath/file.html to SERVERURL/anypath/file.html</font><br />"

	 "<b>regexp	^/old-([^/]*)/(.*)	%u/$1/$2</b><br />"
	 "    <font size=\"-1\">Ex: redirects /old-files/anything to SERVERURL/files/anything</font><br />"

	 "</pre></p>"
	 );
}

class RegMatch {
  private object regexp;
  private string dest;
  private function split_fun;
  void create(string match, string to) {
    regexp = Regexp(match);
    split_fun = regexp->split;
    dest = to;
  }

  string match(string with, object id) {
    string to;
    array split, from;  
    if((split = split_fun(with)))  {
      from = Array.map(split, lambda(string s, mapping f) {
				return "$"+(f->num++);
			      }, ([ "num":1 ]));
      split = Array.map(split, lambda(mixed s) { return (string)s; });
      from = Array.map(from, lambda(mixed s) { return (string)s; });
      to = replace(dest, from, split);
    }
    return to;
  }
}

class ExactMatch {
  private string exact, dest;
  void create(string match, string to) {
    exact = match;
    dest = to;
  }
  string match(string with, object id) {
    if(exact == with) {
      return dest;
    }
    return 0;
  }
}


class PrefixMatch {
  private string prefix, dest;
  void create(string match, string to) {
    prefix = match;
    dest = to;
  }
  string match(string with, object id) {
    string to;
    if(!search(with, prefix))
    {
      to = dest + with[strlen(prefix)..];
      sscanf(to, "%s?", to);
    }
    return to;
  }
}

class GlobMatch {
  private string globstring, dest;
  void create(string match, string to) {
    globstring = match;
    dest = to;
  }
  string match(string with, object id) {
    if(glob(globstring, with)) {
      return dest;
    }
    return 0;
  }
}

array patterns;

void start()
{
  array a;
  string s;
  array new_patterns = ({});

  foreach(replace(QUERY(fileredirect), "\t", " ")/"\n", s)
  {
    a = s/" " - ({""});
    switch(sizeof(a)) {
    case 3:
      switch(a[0]) {
      case "exact":
	new_patterns += ({ ExactMatch(a[1], a[2]) });
	break;
      case "regexp":
      case "reg":
      case "rx":
	if(catch(new_patterns += ({ RegMatch(a[1], a[2]) }))) {
	  werror("Failed to compile pattern "+a[1]+"\n");
	}
	break;
      case "glob":
	new_patterns += ({ GlobMatch(a[1], a[2]) });
	break;
      case "prefix":
	new_patterns += ({ PrefixMatch(a[1], a[2]) });
	break;
      default:
	werror("Invalid redirect keyword: %s\n", a[0]);
	break;
      }
      break;
    case 2:
      if(search(a[0], "*") != -1) {
	if(catch { 
	  if(a[0][0] != '^') // compatibility
	    new_patterns += ({ RegMatch("^"+a[0], a[1]) });
	  else
	    new_patterns += ({ RegMatch(@a) });
	})
	  werror("Failed to compile pattern "+a[0]+"\n");
      } else {
	new_patterns += ({ PrefixMatch(@a) });
      }
      break;
    default:
      werror("Invalid pattern line: %s\n", s);
    }
  }
  patterns = new_patterns;
}

string comment()
{
  return sprintf("Number of patterns: %d, Redirects so far: %d", 
		 sizeof(patterns), redirs);
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
  
  string m;
  int ok;
  m = id->not_query;
  if(id->query && sscanf(id->raw, "%*s?%[^\n\r ]", tmp))
    m += "?"+tmp;
  
  foreach(patterns, object pattern)
    if(to = pattern->match(m, id))
      break;

  if(!to)  return 0;

  string url,hurl;
  url = id->conf->query("MyWorldLocation");
  url = url[..strlen(url)-2];
  hurl = get_host_url(id)||url;
  
  to = replace(to, ({"%u", "%h", "%f", "%p" }),
	       ({ url, hurl,
		  ( ({""}) + (id->not_query / "/" - ({""})) )[-1],
		  id->not_query[1..] })
	       );
  if(to == url + id->not_query ||
     url == id->not_query ||
     to == hurl + id->not_query)
    // Prevent eternal redirects.
    return 0;
  
  redirs++;
  if((strlen(to) > 6 && 
      (to[3]==':' || to[4]==':' || 
       to[5]==':' || to[6]==':')))
  {
    to=replace(to, ({ "\000", " " }), ({"%00", "%20" }));
    return http_low_answer( 302, "You have been redirected!") 
      + ([ "extra_heads":([ "Location":to ]) ]);
  } else {
    id->misc->is_redirected = 1; // Prevent recursive internal redirects
    id->variables = ([]);
    id->raw_url = http_encode_string(to);
    id->not_query = id->scan_for_query( to );
  }
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: fileredirect
//! The redirect patterns are used to rewrite a URL or send a redirect 
//!to an external URL. The syntax is: 
//!<blockquote><b>[type] matchstring destination</b></blockquote> 
//!The field separator can be one or more space or tab characters. Note that 
//!this disallows the use of these characters in the actual fields. 
//!Valid match types are: 
//!<dl> 
//!<p><dt><b>exact</b></dt><dd>The source resource must match 
//!<b>matchstring</b> exactly.</dd></p> 
//! 
//!<p><dt><b>glob</b></dt><dd>The <b>matchstring</b> is a glob 
//!pattern.</dd></p> 
//! 
//!<p><dt><b>prefix</b></dt><dd>The source resource much begin with 
//!<b>matchstring</b>. When using prefix matching, everything after the 
//!prefix is added last to the <b>destination</b> location.</dd></p> 
//! 
//!<p><dt><b>regexp</b></dt><dd>The <b>matchstring</b> is a regular 
//!expression.</dd></p> 
//! 
//!</dl> 
//!<p>For v2.0 compatibility reasons, <b>[type]</b> can be omitted. Then the 
//!pattern type will be deducted automatically as follows: If 
//!<b>matchstring</b> contains a <b>*</b> character, it will be treated 
//!as a <b>regexp</b>. If not, it will be treated as a <b>prefix</b>.</p> 
//! 
//!<p>The <b>destination</b> field can contain one or more special 
//!tokens. They will be replaced after matching is completed as described below.</p> 
//! 
//!<p><dl compact="compact"> 
//!<dt><b>%f</b></dt> 
//!<dd>The file name of the matched URL without the path.</dd> 
//!<dt><b>%p</b></dt> 
//!<dd>The full virtual path of the matched URL excluding the initial /.</dd> 
//!<dt><b>%u</b></dt> 
//!<dd>The manually configured server url. This is useful if you want  
//!your redirect to be external instead of an internal rewrite and  
//!don't want to hardcode the URL in the patterns.</dd> 
//!<dt><b>%h</b></dt> 
//!<dd>The accessed server url, determined by the HTTP host header. If  
//!the host header is missing, the configured server url will be  
//!used instead. This is useful if you want your external redirect to  
//!to the same host as the user accessed (ie if they access the site  
//!as http://www/ they won't get a redirect to http://www.domain.com/). 
//!</dd></dl></p> 
//! 
//!<p>When using regular expression, '(' and ')' can be used to separate 
//!parts of the from-pattern. These parts can then be insterted into the 
//!<b>destination</b> using $1, $2 etc.</p> 
//! 
//!<p>If <b>destination</b> file isn't a fully qualified URL, the 
//!redirect will always be handled internally. If you want an actual 
//!redirect, you can either use <b>%u</b> or enter the exact URL.</p> 
//! 
//!<p>Some examples on how to use this module. The smaller, non-bold 
//!text is an example of the effect of all previous non-described lines.</p> 
//! 
//!<p><pre><b>prefix	/helpdesk/	http://helpdesk.domain.com/</b><br />    <font size="-1">Ex: redirects  /helpdesk/mice/ to http://helpdesk.domain.com/mice/</font><br /><b>exact	/index.html	/index.cgi</b><br />    <font size="-1">Ex: rewrites only /index.html to /index.cgi</font><br /><b>glob	*		http://otherhost.com/%p</b><br /><b>regexp	^/		http://otherhost.com/%p</b><br /><b>regexp	^/(.*)		http://otherhost.com/$1</b><br /><b>prefix	/		http://otherhost.com/</b><br />    <font size="-1">Ex: redirects all files to http://otherhost.com/</font><br /><b>regexp	^/old[^/]*/	/newdir/%f</b><br />    <font size="-1">Ex: rewrites /olddocs/documents/file.html to /newdir/file.html</font><br /><b>prefix	/oldfiles/	%h/</b><br />    <font size="-1">Ex: redirects /oldfiles/anypath/file.html to SERVERURL/anypath/file.html</font><br /><b>regexp	^/old-([^/]*)/(.*)	%u/$1/$2</b><br />    <font size="-1">Ex: redirects /old-files/anything to SERVERURL/files/anything</font><br /></pre></p>
//!  type: TYPE_TEXT_FIELD
//!  name: Redirect patterns
//
