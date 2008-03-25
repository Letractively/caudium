/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2005 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

#include <module.h>
inherit "module";
inherit "caudiumlib";
inherit "images";

constant module_type = MODULE_PARSER;
constant module_name = "Image converter";
constant module_doc  = "Provides a tag 'cimg'. Usage: "
      "&lt;cimg src=indata format=outformat [quant=numcolors] [img args]&gt;";
constant cvs_version="$Id$";
constant thread_safe = 1;

caudium.ImageCache the_cache;


void start(object id)
{
  the_cache = caudium.ImageCache(sprintf("cimg-%s", id->site_id), generate_image );
}

mapping generate_image( mapping args, object id )
{
  return low_load_image( args->src, id );
}

mapping find_internal( string f, object id )
{
	// Find the file identifier by removing the original filename
	string file = (f/"-")[0];

  return the_cache->http_file_answer( file, id );
}

string tag_cimg( string t, mapping args, object id )
{
	// src="" is mandatory. If missing, just output an empty string
  if(!args->src)
  {
    werror("%O: %O: Missing src attribute in cimg\n", id->site_id, id->not_query);
    return "";
  }

	string orig_src = args->src;

  // Strip the original extension
  array parts = orig_src/".";
	if(sizeof(parts)>1)
    orig_src = parts[0..sizeof(parts)-2]*"";

  mapping a = 
  ([  
    "src":Caudium.fix_relative( args->src, id ),
    "quant":args->quant,
    "format":args->format,
    "maxwidth":args->maxwidth,
    "maxheight":args->maxheight,
    "scale":args->scale,
    "dither":args->dither,
  ]);

  foreach( glob( "*-*", indices(args)), string n )
    a[n] = args[n];

  args -= a;

	// Build a webcrawler safe image filename
  args->src = query_internal_location()+the_cache->store( a, id )+"-"+orig_src;

  if( mapping size = the_cache->metadata( a, id, 1 ) ) 
  {
    // image in cache (1 above prevents generation on-the-fly)
    args->width = (string)size->xsize;
    args->height = (string)size->ysize;
  }
  return Caudium.make_tag( "img", args, id->misc->is_xml );
}

string tag_cimg_url( string t, mapping args, object id )
{
	string orig_src=args->src;

  // Strip the original extension
  array parts = orig_src/".";
  if(sizeof(parts)>1)
    orig_src = parts[0..sizeof(parts)-2]*"";

  mapping a = 
  ([  
    "src":Caudium.fix_relative( args->src, id ),  "quant":args->quant,
    "format":args->format, "maxwidth":args->maxwidth,
    "maxheight":args->maxheight, "scale":args->scale,
    "dither":args->dither,
  ]);

  foreach( glob( "*-*", indices(args)), string n )
    a[n] = args[n];

	// Keep web crawler safe by appending the original image filename
  return query_internal_location()+the_cache->store( a, id )+"-"+orig_src;
}

mapping query_tag_callers()
{
  return ([ "cimg":tag_cimg,
	    "cimg-url":tag_cimg_url ]);
}
