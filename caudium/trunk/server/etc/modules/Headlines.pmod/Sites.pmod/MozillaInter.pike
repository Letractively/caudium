/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import "..";

#include "../base.pike"
#include "../RDF.pike"

constant site = "Mozilla Internationalization";
constant url  = "http://www.mozilla.org/projects/intl/";
constant path = "moz-i18n.rdf";
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


