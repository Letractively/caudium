/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "linuxgames";
constant site = "Linux Games";
constant url  = "http://www.linuxgames.com/";
constant path = "bin/mynetscape.pl";
constant names = ({ "title" });
constant titles = ({ "Headline" });

constant sub = "Entertainment/Computer Games";

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


