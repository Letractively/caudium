/*
 * Reponsenet.Com Java Articles
 */

import Headlines;

#include <headlines/base.h>
#include <headlines/RDF.h>

constant name = "reponsenetjava";
constant site = "Reponse Net Java";
constant url  = "http://java.reponsenet.com/";
constant path  = "rss.xml?site=java";

constant names = ({ "title", "time", "description" });
constant titles = ({" Application ", " Date ", " Description " });

constant sub = "Computing/Languages";
array headlines;

string entry2txt(mapping hl)
{
  return sprintf("Program: %s\n"
		 "URL:     %s\n"
		 "Date:    %s\n\n",
		 hl->title||"None", HTTPFetcher()->encode(hl->url||""),
		 hl->time);
}

private static void parse_reply(string data)
{
  rdf_parse_reply(data);

  foreach(headlines, mapping hl) {
    array tmp = hl->url / "/";
    hl->time = ctime((int)tmp[-1])[4..23];
  }
}
