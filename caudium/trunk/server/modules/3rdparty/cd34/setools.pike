/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 *
 */

/*
 * The Search Engine Tools module and the accompanying code is 
 * Copyright © 2002 Davies, Inc.
 *
 * This code is released under the GPL license and is part of the Caudium
 * WebServer.
 *
 * Authors:
 *   Chris Davies <mcd@daviesinc.com>
 *
 */

#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version   = "$Id$";
// Module Parser, allows definition of tags, etc.
constant module_type = MODULE_PARSER;
constant module_name = "Search Engine Tools";
// Note the first \n is where the CIF decides where to wrap for 
// Less Documentation/More Documentation

constant module_doc  = #"This module is the base module for a number of tools to help with Search Engine placement and positioning.
<p>
This module was written to allow people running Caudium to overcome 
certain problems with dynamically generated sites when confronted
with a search engine.
<p>
Typically Search Engines deal with content that is placed closer to
the top of the HTML, and consequently, with tables, headers, dynamically
generated content, banners, headers, etc., your content is usually 
further in the html file, and consequently the fluff ahead is indexed
before your content.
<p>
With these tags, you can put a quick link map in the &lt;se> tag, 
and can wrap your banners and other information near the top of the 
page in the &lt;nose> tag so that your page content is more visible.
<p>
Another potential use is to hide your meta tags from prying eyes.  Once
you obtain your good positioning, you can hide the tags that got you
near the top.  Some Search Engines consider this to be cloaking and
might ban you for this if you are deemed to be 'spamming' the search
engine or misleading the engine to get traffic that is not topical
for your site.
<p>
For those of you with a templated site that want to bump keyword relevence
up for a site, there is the &lt;randomkeyword> container which will parse the 
, delimited contents of the container and return 1 of the items.  You can
put this within an &lt;a> container to provide a random keyword so that you
can boost relevence, without having the same keyword present on 2000
dynamically generated pages.
<p>
As with all Search Engine Manipluation, Use this module and its tools with caution.
<p>
<ul>
<li><a href=\"#nose\">&lt;nose> and &lt;se></a></li>
<li><a href=\"#randomkeyword\">&lt;randomkeyword></a></li>
</ul>
<p>
<a name=\"nose\"><strong>&lt;nose> and &lt;se></strong></a><p>
The first two containers allow you to block or show page content specifically for search engines.
<p>Usage:<p>
&lt;se><br>
Content within the &lt;se> container is shown only when the useragent matches<br>
the regexp specified in the Configuration Interface<br>
&lt;/se><br>
<p>
&lt;nose><br>
Content within the &lt;nose> container is shown only when the useragent matches<br>
the regexp specified in the Configuration Interface<br>
&lt;/nose><br>
<p>
<a name=\"randomkeyword\"><strong>&lt;randomkeyword></strong></a><p>
The Random Keyword container works like this:<br>
&lt;a href=\"http://site.com\"><br>
&lt;randomkeyword>Running Shoes,Kids Shoes,Dress Shoes&lt;/randomkeyword><br>
&lt;/a><p>
In order to boost keyword relevency, it is important to remember that 
a link like &lt;a href=\"http://nike.com\">Nike&lt;/a> will boost relevence
in the search engines for the word Nike.  In most cases, you are not really
trying to push the trademark or brand name, but get your site positioned with
the right relevent keywords.  In this case, &lt;a href=\"http://nike.com\">Running
Shoes&lt;/a> might be a better choice.  On a single page, that link is more
than adequate to raise the relevence of the keywords Running Shoes for Nike.
However, with a database or template driven site that may have the same template
running on 1500 pages, having the same keyword repeated over and over on a 
per page basis may not help the keyword relevence as much.  Additionally,
using different keywords can help immensely when launching a new site.
";
constant module_unique = 1;
constant thread_safe=1;

// define an object for the Regexp so that it doesn't need to be parsed
// every time
object searchengine=0;

void create() {
  defvar("searchengineregexp", 
         "^(Googlebot|Scooter|FAST-WebCrawler|Openfind|Inktomi|Slurp|Infoseek|NationalDirectory|Gigabot|Teradax|metacarta|ah-ha)",
         "Search Engine Regexp", TYPE_STRING,
         "A Pike Regexp that specifies the User Agents that match typical"
         "Search engines<p>" 
         "For Example:<br>"
         "^(Googlebot|Scooter|FAST-WebCrawler|Openfind|Inktomi|Slurp|Infoseek|NationalDirectory|Gigabot|\\(Teradax|metacarta|ah-ha)");
}

void start(int num, object conf) {
  catch {
    if (strlen(query("searchengineregexp")))
      searchengine = Regexp(query("searchengineregexp"));
  };
}

string container_se(string tag, mapping m, string contents, object id)
{
  catch {
    if ( (tag == "se") && (searchengine->match(lower_case((string)id->useragent))) ||
         (tag == "nose") && !(searchengine->match(lower_case((string)id->useragent))) )
      return(contents);

// Note: Evidently you must have a non-zero return or Caudium ignores 
// the callback
    return("");
  };
  
// If for some reason we fail, we always return the contents of the container
  return(contents);
}

string container_randomkeywords(string tag, mapping m, string contents, object id)
{
  catch {
    return(random(contents / ","));
  }; 
  return(contents);
}

mapping query_container_callers()
{
  return ([ "nose":container_se,"se":container_se,
            "randomkeywords":container_randomkeywords,
         ]);
}
