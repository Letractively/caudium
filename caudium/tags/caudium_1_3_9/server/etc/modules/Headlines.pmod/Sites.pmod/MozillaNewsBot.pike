/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "mozillanewsbot";
constant site = "Mozilla NewsBot";
constant url  = "http://www.mozilla.org/newsbot/";
constant path = "newsbot.rdf";
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


