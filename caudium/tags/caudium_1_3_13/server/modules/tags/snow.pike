/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
/*
 * $Id$
 */

//
//! module: JS Snow
//!  This module add a new RXML tag &lt;snow&gt; tag. <br />
//!  The Javascript code is inspired from the Javascript code taken from
//!  <a href="http://www.altan.hr/snow/">http://www.altan.hr/snow</a><br />
//! inherits: module
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
#include <module.h>
inherit "module";

constant module_type   = MODULE_PARSER;
constant module_name   = "JS Snow";
constant module_doc    = "This module add a new RXML tag &lt;snow&gt; tag.<br />"
                         "The Javascript code is inspired from the Javascript "
			 "code taken from <a href=\"http://www.altan.hr/snow/\">"
			 "http://www.altan.hr/snow/</a><br />"
			 "Syntax for the &lt;snow&gt; tag is :<br />"
			 "<b>&lt;snow <i>image=snow.gif</i> <i>num=n</i>&gt;</b> "
			 "<br />where <b>image</b> is a URL where the image is "
			 "taken and <b>num</b> the number of snow to show.";
constant module_unique = 1;
constant cvs_version   = "$Id$";
constant thread_safe=1;

//
//! tag: snow
//!  Add snow on the top the layers on Netscape 4+ or MSIE 4+
//!
//! attribute: [image=URI]
//!  Set the image used by the Javascript using a URI to a new location
//! default: /(internal,image)/snow
//!
//! attribute: [num=int]
//!  Set the number of images (and layers) used for this snow
//! default: 10
//
string snow(string tag_name, mapping arg, object id, object file, mapping defines)
{
  string retval="";

  // Snow Effect Script
  // Created and submitted by Altan d.o.o. 
  // (snow@altan.hr,  http://www.altan.hr/snow/index.html)
  // Permission granted to Dynamicdrive.com to feature script in archive
  // For full source code and installation instructions to this script, 
  // visit http://dynamicdrive.com
 
  if (!id->supports->javascript) 
    return "<!-- Javascript not supported by this navigator -->";

  retval += "<script language=\"JavaScript1.2\">\n";

  //Configure below to change URL path to the snow image
  if (arg->image)
    retval+="var snowsrc=\""+arg->image+"\";\n";
  else
    retval+="var snowsrc=\"/(internal,image)/snow\";\n";
    //retval+="var snowsrc=\"http://www.ariom.se/snow.gif\";\n";
  // Configure below to change number of snow to render
  if (arg->num)
    retval+="var no = "+arg->num+";\n";
  else
    retval+="var no = 10;";
  
  retval += "var ns4up = (document.layers) ? 1 : 0;\n"; //Brownser sniffer
  retval += "var ie4up = (document.all) ? 1 : 0;\n"
            "var dx, xp, yp;\n"    // coordinate and position variables
            "var am, stx, sty;\n"  // amplitude and step variables
            "var i, doc_width = 800, doc_height = 600;\n"
  
            "if (ns4up) {\n"
            "  doc_width = self.innerWidth;\n"
            "  doc_height = self.innerHeight;\n"
            "} else if (ie4up) {\n"
            "  doc_width = document.body.clientWidth;\n"
            "  doc_height = document.body.clientHeight;\n"
            "}\n"

            "dx = new Array();\n"
            "xp = new Array();\n"
            "yp = new Array();\n"
            "am = new Array();\n"
            "stx = new Array();\n"
            "sty = new Array();\n"
  
            "for (i = 0; i < no; ++ i) {\n"  
            "  dx[i] = 0;\n"                            // set coordinate variables
            "  xp[i] = Math.random()*(doc_width-50);\n" // set position variables
            "  yp[i] = Math.random()*doc_height;\n"
            "  am[i] = Math.random()*20;\n"             // set amplitude variables
            "  stx[i] = 0.02 + Math.random()/10;\n"     // set step variables
            "  sty[i] = 0.7 + Math.random();\n";        // set step variables
  if(id->supports->msie) {
   retval +="  if(ie4up) {\n"
            "    document.write(\"<div id=\\\"dot\"+ i +\"\\\" style=\\\"POSITION: absolute; Z-INDEX: \"+ i +\"; VISIBILITY: visible; TOP: 15px; LEFT: 15px;\\\"><img src='\"+snowsrc+\"' border=\\\"0\\\"></div>\");\n"
            "  }\n"
            " }\n"
            "function snowIE() {\n"         // IE main animation function
            "for (i = 0; i < no; ++ i) {\n" // iterate for every dot
            " yp[i] += sty[i];\n"
            " if (yp[i] > doc_height-50) {\n"
            "  xp[i] = Math.random()*(doc_width-am[i]-30);\n"
            "  yp[i] = 0;\n"
            "  stx[i] = 0.02 + Math.random()/10;\n"
            "  sty[i] = 0.7 + Math.random();\n"
            "  doc_width = document.body.clientWidth;\n"
            "  doc_height = document.body.clientHeight;\n"
            " }\n"
            " dx[i] += stx[i];\n"
            " document.all[\"dot\"+i].style.pixelTop = yp[i];\n"
            " document.all[\"dot\"+i].style.pixelLeft = xp[i] + am[i]*Math.sin(dx[i]);\n"
            "}\n"
            "setTimeout(\"snowIE()\", 10);\n"
            "}\n"
	    "if (ie4up) snowIE();\n";
   } else {
   retval +="  if(ns4up) {\n"
            "    document.write(\"<layer name=\\\"dot\"+ i +\"\\\" left=\\\"15\\\" top=\\\"15\\\" visibility=\\\"show\\\"><img src='\"+snowsrc+\"' border=\\\"0\\\"></layer>\");\n"
            "  }\n"
            " }\n"
            "function snowNS() {\n"           // Netscape main animation function
            " for (i = 0; i < no; ++ i) {\n"  // iterate for every dot
            "  yp[i] += sty[i];\n"
            "  if (yp[i] > doc_height-50) {\n"
            "   xp[i] = Math.random()*(doc_width-am[i]-30);\n"
            "   yp[i] = 0;\n"
            "   stx[i] = 0.02 + Math.random()/10;\n"
            "   sty[i] = 0.7 + Math.random();\n"
            "   doc_width = self.innerWidth;\n"
            "   doc_height = self.innerHeight;\n"
            "  }\n"
            "  dx[i] += stx[i];\n"
            "  document.layers[\"dot\"+i].top = yp[i];\n"
            "  document.layers[\"dot\"+i].left = xp[i] + am[i]*Math.sin(dx[i]);\n"
            " }\n"
            " setTimeout(\"snowNS()\", 10);\n"
            "}\n"
            "if (ns4up) snowNS();\n";
   }
  retval += "</script>";
  return retval; 
}

// This is nessesay for the MODULE_PARSER here....
mapping query_tag_callers() { return (["snow":snow,]); }

