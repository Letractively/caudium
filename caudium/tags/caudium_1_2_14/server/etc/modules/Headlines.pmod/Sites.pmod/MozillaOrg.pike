/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "mozillaorg";
constant site = "Mozilla dot Org";
constant url  = "http://www.mozilla.org/";
constant path = "news.rdf";
constant names = ({ "title" });
constant titles = ({ "Title" });
constant sub = "Computing/Mozilla";

array headlines;

function parse_reply = rdf_parse_reply;

string entry2txt(mapping hl)
{
  return sprintf("Title:    %s\n"
		 "URL:      %s\n"
		 "\n",
		 hl->title||"None", 
		 HTTPFetcher()->encode(hl->url||""),
		 );
}


