/* Parsing of standard RDF XML files.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

static private string parse_it(string tag, mapping args, string|int contents,
			       mapping hl)
{
  mixed tmp;
  switch(tag)
  {
  case "item":
    hl = ([]);
    parse_html(contents, ([ ]), ([ "title": parse_it, "link": parse_it ]),
	       hl);
    headlines += ({ hl });
    break;

  case "link":
    tag = "url";
  default:
    hl[tag] = trim(contents);
    break;
  }
  return "";
}

private static void rdf_parse_reply(string data)
{
  parse_html(data, ([]), (["item" : parse_it ]) );
}

  
private static void fetch_failed(object http)
{
  werror("%s: failed to get headlines..\n", site);
}

