/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
 * Copyright © 2002 Davies, Inc
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
/*
 * See http://www.daviesinc.com/modules/ for more informations.
 */
#include <module.h>
inherit "module";
inherit "caudiumlib";

// Module Parser, allows definition of tags, etc.
constant module_type = MODULE_PARSER;
constant module_name = "Harry Potter Container Module";
// Note the first \n is where the CIF decides where to wrap for 
// Less Documentation/More Documentation
constant module_doc  = #"This module was designed to show how a container module works.<p>\n
                        Usage:<p>
11.23 USD =<br>
&lt;usdtohp>11.23&lt;/usdtohp><br>
&lt;p><br>
2 Galleons, 5 Sickle, and 14 Knuts = <br>
&lt;hptousd><br>
&lt;galleons>2&lt;/galleons><br>
&lt;sickles>5&lt;/sickles><br>
&lt;knuts>14&lt;/knuts><br>
&lt;/hptousd> USD<br>
<p>\n";
constant module_unique = 1;
constant thread_safe=1;

// Initialize two counters just so we can keep track of how many 
// firstyears are reloading the pages
int	hptousdcount = 0;
int	usdtohpcount = 0;

string container_usdtohp(string t, mapping m, string contents, object id)
{
  usdtohpcount++;

// How do we know this?
// Price of book, $3.99 (14 sickles, 3 knuts)
// 29 knuts in a sickle, 17 sickles in a galleon

int knutindollar = 15 + 3*29;
int knutsinsickle = 29;
int knutsingalleon = 17 * knutsinsickle;

float dollars = (float)contents;
int totalknuts = (int)(dollars*knutindollar+0.5);

int galleons = totalknuts / knutsingalleon;
int sickles = (totalknuts - (galleons * knutsingalleon)) / knutsinsickle;
int knuts = totalknuts - (galleons * knutsingalleon) - (sickles * knutsinsickle);

return(sprintf("%d galleons, %d sickles and %d knuts",galleons,sickles,knuts));

}

string container_hptousd(string t, mapping m, string contents, object id)
{
  hptousdcount++;

// How do we know this?
// Price of book, $3.99 (14 sickles, 3 knuts)
// 29 knuts in a sickle, 17 sickles in a galleon
float knutindollar = (float)(15 + 3*29);
int knutsinsickle = 29;
int knutsingalleon = 17 * knutsinsickle;

// Parse the contents of the container to set id->misc with the appropriate 
// values
string parsed = parse_rxml(contents, id);
int galleons = (int)id->misc->galleons;
int sickles = (int)id->misc->sickles;
int knuts = (int)id->misc->knuts;
float dollars = 0.0;

int totalknuts = (galleons * knutsingalleon) + (sickles * knutsinsickle) + knuts;

return(sprintf("%.2f",totalknuts/knutindollar));

}

// We define a container that is called by 3 different containers in the 
// html.  Since we can see the tag name that was called, we can save time
// and have the same routine called for each tag rather than writing 
// 3 different functions


string container_hpmoney(string tag, mapping m, string contents, object id)
{
// we store the value of the contents in the container in id->misc
  id->misc[tag] = (int)contents;
// Note: Evidently you must have a non-zero return or Caudium ignores 
// the callback
  return("");
}

mapping query_container_callers()
{
  return ([ "usdtohp":container_usdtohp,"hptousd":container_hptousd,
            "galleons":container_hpmoney,"sickles":container_hpmoney,
            "knuts":container_hpmoney
         ]);
}

string status()
{
// This is displayed in the Config Interface, Status
  return("The USDtoHP tag was called "+(string)usdtohpcount+" time(s)<br>"
         "The HPtoUSD tag was called "+(string)hptousdcount+" time(s)<br>");
}
