/* Site-specific code. Here parsing and more of this site is.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

import spider;
//import "..";
import Headlines;

//#include "../base.pike"
#include <headlines/base.h>
//#include "../RDF.pike"
#include <headlines/RDF.h>

constant name = "mozillazine";
constant site = "MozillaZine";
constant url  = "http://www.mozillazine.org/";
constant path = "contents.rdf";
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


