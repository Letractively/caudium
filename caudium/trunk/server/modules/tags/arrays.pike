/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Written by David Hedbor <david@caudium.net>
 *	      Rob Lanphier <robla@real.com>
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
**! module: Array Handling for RXML.
**!   A module to easily handle arrays from RXML. This can be very useful
**!   for example when when dealing with multi-select form variables
**!   (which normally are separated by \0).
**! type: MODULE_PARSER
**! cvs_version: $Id$
*/

string cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

#define STOR	id->misc->_extended_arrays
#define GET_ARRAY(x) do { if(!STOR) STOR=([]); x = STOR[args->name]; if(!x) x = STOR[args->name] = ({}); } while(0)
#define SET_ARRAY(x) do { if(!STOR) STOR=([]); STOR[args->name] = x; } while(0)
#define GET_ARRAY_BYNAME(x, y) do { if(!STOR) STOR=([]); x = STOR[y]; if(!x) x = STOR[y] = ({}); } while(0)
#define SET_ARRAY_BYNAME(x, y) do { if(!STOR) STOR=([]); STOR[y] = x; } while(0)

string docs = "<dl>\n\t<p><dt><b>&lt;arrayadd&gt;</b>\n\t<dd><p>Add a value to the end off an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to add value to\n\t\t\t<dt><b>value</b>\n\t\t\t<dd>element(s) to add\n\t\t\t<dt><b>delim</b>\n\t\t\t<dd>delimiter between elements, default \",\"\n\t\t</dl>\n\n\t<p><dt><b>&lt;arraycadd&gt;&lt;/arraycadd&gt;</b>\n\t<dd><p>Add values to the end off an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to add value to\n\t\t\t<dt><b>delim</b>\n\t\t\t<dd>delimiter between elements, default \"\\n\"\n\t\t</dl>\n\n\t<p><dt><b>&lt;arraycinsert&gt;&lt;/arraycinsert&gt;</b>\n\t<dd><p>Insert values after a specific position in an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to add value to\n\t\t\t<dt><b>index</b>\n\t\t\t<dd>insert values after this index. If it is larger than the\t current array, add entries to the end.\n\t\t\t<dt><b>delim</b>\n\t\t\t<dd>delimiter between elements, default \"\\n\"\n\t\t</dl>\n\n\t<p><dt><b>&lt;arrayclear&gt;</b>\n\t<dd><p>Empty the named array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of array to empty.\n\t\t</dl>\n\n\t<p><dt><b>&lt;arraycset&gt;&lt;/arraycset&gt;</b>\n\t<dd><p>Set an array to this value. Useful if you want to reset a currently used array. Same args as &lt;arraycadd&gt;. Can't be used to modify existing arrays (ie always clears the mapping first). \n\t\t<p><dl>\n\t\t</dl>\n\n\t<p><dt><b>&lt;arraycsubtract&gt;&lt;/arraycsubtract&gt;</b>\n\t<dd><p>Delete values from an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to add value to\n\t\t\t<dt><b>delim</b>\n\t\t\t<dd>delimiter between elements, default \"\\n\"\n\t\t</dl>\n\n\t<p><dt><b>&lt;arrayfetch&gt;</b>\n\t<dd><p>Fetch a single element from an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to retrieve value from\n\t\t\t<dt><b>index</b>\n\t\t\t<dd>element to return.\n\t\t\t<dt><b>encode</b>\n\t\t\t<dd>chose encoding of the inserted value.\n\t\t</dl>\n\n\t<p><dt><b>&lt;arrayinsert&gt;</b>\n\t<dd><p>Insert a value after a specific position in an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to add value to\n\t\t\t<dt><b>value</b>\n\t\t\t<dd>elements to add\n\t\t\t<dt><b>index</b>\n\t\t\t<dd>insert value after this index. If it is larger than the\t current array, add entry to the end.\n\t\t\t<dt><b>delim</b>\n\t\t\t<dd>delimiter between elements, default \",\"\n\t\t</dl>\n\n\t<p><dt><b>&lt;arrayoutput&gt;</b>\n\t<dd><p>Insert element(s) from arrays. Works like other &lt;*output&gt; tags. The replaced variables are array names and index. \n\t\t<p><dl>\n\t\t\t<dt><b>arrays</b>\n\t\t\t<dd>the name(s) of the array(s) to output, separated by commas.\n\t\t\t<dt><b>from</b>\n\t\t\t<dd>the index of the first element of index. Defaults to 0.\n\t\t\t<dt><b>to\t</b>\n\t\t\t<dd>the index of the last element to insert. Negative numbers are\t the end of th eindex array. Defaults to -1 (size of indexarray\t minus one).\n\t\t\t<dt><b>indexarray</b>\n\t\t\t<dd>Array referenced by the to attribute. Defaults to the largest\t\t array listed in the arrays attribute.\n\t\t\t<dt><b>[...]</b>\n\t\t\t<dd>all normal &lt;*output&gt; vars like encode and quote. \n\t\t</dl>\n\n\t<p><dt><b>&lt;arrayset&gt;</b>\n\t<dd><p>Change an existing index to a different value. If index is larger than the array, nothing changes. Indexing starts with 0. If index is missing, this tags works like &lt;arraycset&gt;, replacing the old array with the new one. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to change a value in\n\t\t\t<dt><b>value</b>\n\t\t\t<dd>value to change index to or elemets in the new array\n\t\t\t<dt><b>index</b>\n\t\t\t<dd>index to modify\n\t\t</dl>\n\n\t<p><dt><b>&lt;arraysize&gt;</b>\n\t<dd><p>Return the size of an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to retrieve value from\n\t\t\t<dt><b>set</b>\n\t\t\t<dd>if specified return nothing but set the specified\t variable to the number of indices instead.\n\t\t</dl>\n\n\t<p><dt><b>&lt;arraysubtract&gt;</b>\n\t<dd><p>Delete a value from an array. \n\t\t<p><dl>\n\t\t\t<dt><b>name</b>\n\t\t\t<dd>name of the array to add value to\n\t\t\t<dt><b>value</b>\n\t\t\t<dd>elements to subtract\n\t\t\t<dt><b>delim</b>\n\t\t\t<dd>delimiter between elements, default \",\"\n\t\t</dl>\n</dl>";

constant module_type = MODULE_PARSER;
constant module_name = "Array Handling for RXML";
constant module_doc  = "This module implements a number of tags that enabled you to do "
      "more complex variable handling through RXML. Code for mappings and "
      "arrays are given.<p>"; // + docs;
constant module_unique = 1;

array register_module()
{
    return
    ({
      MODULE_PARSER,
      "Array Handling for RXML",
      "This module implements a number of tags that enabled you to do "
      "more complex variable handling through RXML. Code for mappings and "
      "arrays are given.<p>" + docs,
      0, 1
    });
}

string array_container(string tag, mapping args, string data, object id)
{
  array work, elems;
  if(!args->name)    return "";
  elems = data / (args->delim || "\n");
  
  switch(tag) {
   case "arraycadd":
    GET_ARRAY(work);
    work += elems;
    SET_ARRAY(work);
    break;

   case "arraycsubtract":
    GET_ARRAY(work);
    work -= elems;
    SET_ARRAY(work);
    break;

   case "arraycinsert":
    int index = (int)args->index;
    GET_ARRAY(work);
    if(index > sizeof(work))
      work += elems;
    else if(index <= 0)
      work = elems + work;
    else 
      work = work[..index-1] + elems + work[index..];
    SET_ARRAY(work);
    break;

   case "arraycset":
    SET_ARRAY(elems);
    break;
  }
  if(args->debug) {
    GET_ARRAY(work);
    return sprintf("<pre>%s result: %O</pre>", tag, work);
  }
  return "";
}

string array_tag(string tag, mapping args, object id)
{
  array work;
  string quoted;
  int index;
  if(!args->name)    return "";
  switch(tag) { 
   case "arrayclear":
    SET_ARRAY( ({}) );
    break;
   case "arrayfetch":
    GET_ARRAY(work);
    index = (int)args->index;
    if(index > 0 && index > sizeof(work))     return "";
    if(index < 0 && (-index) >= sizeof(work)) return "";
    if(args->encode && (quoted = roxen_encode(work[index], args->encode)))
      return quoted;
    return work[index];
    
   case "arrayset":
    if(!args->value) return "";
    GET_ARRAY(work);
    if(args->index) { /* if index is missing, work as a cset */
      index = (int)args->index;
      if(index > 0 && index > sizeof(work))     return "";
      if(index < 0 && (-index) >= sizeof(work)) return "";
      work[index] = args->value;
      break;
    }
    /* FALLTHROUGH */

   case "arrayadd":
   case "arraysubtract":
   case "arrayinsert":
    tag = "arrayc"+(tag - "array");
    if(!args->delim) args->delim = ",";
    return array_container(tag, args, args->value, id);  
   case "arraysize":
    GET_ARRAY(work);
    if(args->set && sizeof(args->set))
      id->variables[args->set] = (string)sizeof(work);
    else 
      return (string)sizeof(work);
    break;
  }
  if(args->debug) {  
    GET_ARRAY(work);
    return sprintf("<pre>%s result: %O</pre>", tag, work);
  }
  return "";
}

string array_output(string tag, mapping args, string contents, object id)
{
  //  <arrayoutput arrays="array_one,array_two" indexarray="array_two" from=0 to="-1">

  array(mapping) replaceme = ({});
  mapping(string:array) work = ([]);
  int firstindex = 0;
  int lastindex = 0;
  array arraylist = ({});
  int g1 = gauge { 
    if(args->arrays) {
      arraylist = (args->arrays - " ") / ",";
    }
    else {
      if(args->strict) {
	return "Error: Must include 'arrays' attribute<false>";
      } else {
	return "";
      }
    }
    foreach(arraylist, string arrayname) {
      GET_ARRAY_BYNAME(work[arrayname], arrayname);
    }

    // compute firstindex
    if((int)args->from >= 0) {
      firstindex = (int)args->from;
    }
  
    // compute lastindex
    if(args->to && (int)args->to >= 0) {
      lastindex = (int)args->to;
    }
    else {
      if(args->indexarray) {
	// check if it's in arrays, and that it's non-zero
	// if so, use it to compute the value of lastindex 
	if(!work[args->indexarray]) {
	  return "Error: indexarray " + args->indexarray + " not there<false>";
	}
      }
      else {
	// need to find the largest array, and use that as a reference
	foreach(arraylist, string arrayname) {
	  if ((sizeof(work[arrayname])-1)>lastindex) {
	    lastindex=(sizeof(work[arrayname])-1);
	  }
	}
      }
      if ((int)args->to < -1) {
	lastindex -= (((int)args->to)-1);
	if(lastindex < 0) {
	  if (args->strict) {
	    return "No lastindex<false>";
	  }
	  else {
	    return "";
	  }
	}
      }
    }

    if ((lastindex-firstindex)<0) {
      if (args->strict) {
	return "Error: lastindex smaller than firstindex<false>";
      }
      else {
	return "";
      }
    }

    // populate array
    replaceme = allocate(lastindex - firstindex + 1, ([]));
    for(int i=firstindex; i<=lastindex; i++) {
      replaceme[i]->index = (string)i;
      foreach(arraylist, string arrayname) {
	if (work[arrayname] && (sizeof(work[arrayname])>i)) {
	  (replaceme[i])[arrayname] = (work[arrayname])[i];
	}
      }
    }
  };
  mixed res;
  int g2 = gauge {
    res = do_output_tag( args, replaceme, contents, id );
  };
  werror("In: %d, Out: %d\n", g1, g2);
  return res;
}

mapping query_container_callers()
{
  return ([ "arraycadd": array_container,
	    "arraycsubtract": array_container,
	    "arraycinsert": array_container,
	    "arraycset": array_container,
	    "arrayoutput": array_output,
  ]);
} 


mapping query_tag_callers()
{
  return ([
    "arrayclear": array_tag,
    "arrayfetch": array_tag,
    "arrayadd": array_tag,
    "arraysubtract": array_tag,
    "arrayinsert": array_tag,
    "arrayset": array_tag,
    "arraysize": array_tag,
  ]);
  
} 


/*
**! container: arrayoutput
**!   Insert element(s) from arrays. Works like other <*output> tags. The
**!   replaced variables are array names and index. 
**! attribute: arrays
**!   The name(s) of the array(s) to output, separated by commas.
**! attribute: from
**!   The index of the first element of index. Defaults to 0.
**! attribute: to
**!   The index of the last element to insert. Negative numbers are
**!   the end of th eindex array. Defaults to -1 (size of indexarray
**!   minus one). 
**! attribute: indexarray
**!   Array referenced by the to attribute. Defaults to the largest
**!   array listed in the arrays attribute. 
**! attribute: std output attributes
**!   all normal <*output> vars like encode and quote (see formoutput).
**! 
**! tag: arrayfetch
**!   Fetch a single element from an array.
**! attribute: name
**!   Name of the array to retrieve value from
**! attribute: index
**!   Element to return.
**! attribute: encode
**!   Chose encoding of the inserted value.
**! 
**! tag: arraysize
**!   Return the size of an array. 
**! attribute: name
**!  Name of the array to retrieve value from
**! attribute: set
**!  If specified return nothing but set the specified variable to the
**!  number of indices instead.
**! 
**! tag: arrayadd
**!   Add a value to the end off an array.
**! attribute: name
**!   Name of the array to add value to
**! attribute: value
**!   Element(s) to add
**! attribute: delim
**!   Delimiter between elements
**!   default: ,
**! 
**! container: arraycadd
**!   Add values to the end off an array.
**! attribute: name
**!   Name of the array to add value to
**! attribute: delim
**!   Delimiter between elements.
**!   default: \n
**! 
**! tag: arraysubtract
**!   Delete a value from an array.
**! attribute: name
**!   Name of the array to add value to.
**! attribute: value
**!   Elements to subtract.
**! attribute: index
**!   List of indexes to remove. 
**! attribute: delim
**!   Delimiter between elements
**!   default: ,
**! 
**! container: arraycsubtract
**!   Delete values from an array.
**! attribute: name
**!   Name of the array to add value to
**! attribute: delim
**!   Delimiter between elements
**!   default: \n
**! 
**! tag: arrayinsert
**!   Insert a value after a specific position in an array. 
**! attribute: name
**!   Name of the array to add value to
**! attribute: value
**!   Elements to add
**! attribute: index
**!   Insert value after this index. If it is larger than the
**!   current array, add entry to the end. 
**! attribute: delim
**!   Delimiter between elements
**!   detault: ,
**! 
**! container: arraycinsert
**!   Insert values after a specific position in an array. 
**! attribute: name
**!   Name of the array to add value to
**! attribute: index
**!   Insert values after this index. If it is larger than the
**!   current array, add entries to the end. 
**! attribute: delim
**!   Delimiter between elements
**!   default: \n
**! 
**! tag: arrayset
**!   Change an existing index to a different value. If index is larger
**!   than the array, nothing changes. Indexing starts with 0. If index is
**!   missing, this tags works like <arraycset>, replacing the old array
**!   with the new one.
**! attribute: name
**!   Name of the array to change a value in
**! attribute: value
**!   Value to change index to or elemets in the new array
**! attribute: index
**!   Index to modify
**! 
**! tag: arraycset
**!   Set an array to this value. Useful if you want to reset a currently
**!   used array. Can't be used to modify existing arrays (ie always
**!   clears the mapping first).
**! attribute: name
**!   Name of the array to add value to
**! attribute: delim
**!   Delimiter between elements.
**!   default: \n
**! 
**! tag: arrayclear
**!   Empty the named array.
**! attribute: name
**!   Name of array to empty.
*/
