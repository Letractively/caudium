// Version this module
constant cvs_version = "$Id$";

// Tell Roxen that this module is threadsafe. That is there is no
// request specific data in global variables.
#include <module.h>
inherit "module";
inherit "caudiumlib";
constant thread_safe=1;

array register_module()
{
  return ({ MODULE_PARSER,
            "Snow",
            ("This module add a new RXML &lt;snow&gt; tag.<br>"
            "This tags add some snow on the top of html page"
	    "<br>This tag can use the <b>image</b> as optional argument "
	    "to specify a new URL for the stars and <b>num</b> as numbers "
	    "of stars to display."
	    ""),
            0, 1
            });
}

string snow(string tag_name, mapping arg, object id, object file, mapping defines)
{
  string retval="";
  // Javascript start here =)

  /*
   Snow Effect Script
   Created and submitted by Altan d.o.o. (snow@altan.hr,  http://www.altan.hr/snow/index.html)
   Permission granted to Dynamicdrive.com to feature script in archive
   For full source code and installation instructions to this script, visit http://dynamicdrive.com
   */
  
  retval += "<script language=\"JavaScript1.2\">\n";

  //Configure below to change URL path to the snow image
  if (arg->image)
    retval+="var snowsrc=\""+arg->image+"\";\n";
  else
    retval+="var snowsrc=\"http://www.ariom.se/snow.gif\";\n";
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
            "  sty[i] = 0.7 + Math.random();\n"         // set step variables
            "  if (ns4up) {\n"                          // set layers
            "   if (i == 0) {\n"
            "    document.write(\"<layer name=\\\"dot\"+ i +\"\\\" left=\\\"15\\\" top=\\\"15\\\" visibility=\\\"show\\\"><a href=\\\"http://dynamicdrive.com/\\\"><img src='\"+snowsrc+\"' border=\\\"0\\\"></a></layer>\");\n"
            "   } else {\n"
            "    document.write(\"<layer name=\\\"dot\"+ i +\"\\\" left=\\\"15\\\" top=\\\"15\\\" visibility=\\\"show\\\"><img src='\"+snowsrc+\"' border=\\\"0\\\"></layer>\");\n"
            "   }\n"
            "  } else if (ie4up) {\n"
            "   if (i == 0) {\n"
            "    document.write(\"<div id=\\\"dot\"+ i +\"\\\" style=\\\"POSITION: absolute; Z-INDEX: \"+ i +\"; VISIBILITY: visible; TOP: 15px; LEFT: 15px;\\\"><a href=\\\"http://dynamicdrive.com\\\"><img src='\"+snowsrc+\"' border=\\\"0\\\"></a></div>\");\n"
            "   } else {\n"
            "    document.write(\"<div id=\\\"dot\"+ i +\"\\\" style=\\\"POSITION: absolute; Z-INDEX: \"+ i +\"; VISIBILITY: visible; TOP: 15px; LEFT: 15px;\\\"><img src='\"+snowsrc+\"' border=\\\"0\\\"></div>\");\n"
            "   }\n"
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

            "if (ns4up) {\n"
            "snowNS();\n"
            "} else if (ie4up) {\n"
            "snowIE();\n"
            "}\n"
            "</script>";


  return retval; 
}

// This is nessesay for the MODULE_PARSER here....
mapping query_tag_callers() { return (["snow":snow,]); }

