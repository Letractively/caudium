/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

//
//! module: Business Graphics
//!  Draws various diagrams for data presentation purposes.
//! inherits: module
//! inherits: caudiumlib
//! inherits: images.pike
//! type: MODULE_PARSER | MODULE_LOCATION
//! cvs_version: $Id$
//

/* 
 * Draws diagrams pleasing to the eye.
 * 
 * Made by Peter Bortas <peter@idonex.se> and Henrik Wallin <hedda@idonex.se>
 * in October 1997
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#include <caudium.h>

#define VOIDSYMBOL "\n"
#define SEP "\t"

inherit "module";
inherit "caudiumlib";
inherit "images";

constant module_type = MODULE_PARSER | MODULE_LOCATION;
constant module_name = "Business Graphics";
constant module_doc  =
"<font size=+1><b>The Business Graphics tag</b></font>\n<br>"
"Draws different kinds of diagrams.<br>"
"<p><pre>"
"\n&lt;<b>diagram</b>&gt; (container)\n"
"Options:\n"
"  <b>help</b>           Displays this text.\n"
"  <b>type</b>           Mandatory. Type of graph. Valid types are:\n"
"                 <b>sumbars</b>, <b>normsumbars</b>, <b>linechart</b>,"
" <b>barchart</b>,\n"
"                 <b>piechart</b> and <b>graph</b>\n"
#if constant(Image.JPEG.decode)
"  <b>background</b>     Takes the filename of a pnm-, gif- or\n"
"                 jpeg-image as input.\n"
#else
"  <b>background</b>     Takes the filename of a pnm image as input.\n"
#endif
"  <b>width</b>          Width of diagram image in pixels.\n"
"                 (will not have any effect below 100)\n"
"  <b>height</b>         Height of diagram image in pixels.\n"
"                 (will not have any effect below 100)\n"
"  <b>fontsize</b>       Height of text in pixels.\n"
"  <b>font</b>           Name of the font used. This can be\n"
"                 overridden in the legend-, axis- and\n"
"                 names-tags.\n"
"  <b>namefont</b>       Name of the font for the diagram name.\n"
"  <b>legendfontsize</b> Height of legend text in pixels.\n"
"                 <b>fontsize</b> is used if this is undefined.\n"
"  <b>name</b>           Writes a name at the top of the diagram.\n"
"  <b>namecolor</b>      The color of the name-text. Textcolor\n"
"                 is used if this is not defined.\n"
"  <b>namesize</b>       Height of the name text in pixels.\n"
"                 <b>Fontsize</b> is used if this is undefined.\n"
"  <b>grey</b>           Makes the default colors in greyscale.\n"

"  <b>3D</b>             Render piecharts on top of a cylinder, takes"
" the\n                 height in pixels of the cylinder as argument.\n"
/* " tone         Do nasty stuff to the background.\n"
   " Requires dark background to be visible.\n" */
"  <b>eng</b>            If present, numbers are shown like 1.2M.\n"
"  <b>neng</b>           As above but 0.1-1.0 is written 0.xxx .\n"
"  <b>tonedbox</b>       Creates a background shading between the\n"
"                 colors assigned to each of the four corners.\n"
"  <b>center</b>         (Only for <b>pie</b>) center=n centers the nth"
" slice\n"
"  <b>rotate</b>         (Only for <b>pie</b>) rotate=X rotate the pie"
" X degrees.\n"
"  <b>turn</b>           If given, the diagram is turned 90 degrees.\n"
"                 (To make big diagrams printable)\n"
"  <b>voidsep</b>        If this separator is given it will be used\n"
"                 instead of VOID (This option can also\n"
"                 be given i <b>xnames</b> and so on)\n"
"  <b>bgcolor</b>        Use this background color for antialias.\n"
"  <b>notrans</b>        If given, the bgcolor will be opaque.\n"

// Not supported any more!     "  <b>colorbg</b>        Sets the color for the background\n"
"  <b>textcolor</b>      Sets the color for all text\n"
"                 (Can be overrided)\n"
"  <b>labelcolor</b>     Sets the color for the labels of the axis\n"

"  <b>horgrid</b>        If present a horizontal grid is drawn\n"
"  <b>vertgrid</b>       If present a vertical grid is drawn\n"
"  <b>xgridspace</b>     The space between two vertical grids in the\n"
"                 same unit as the data.\n"
"  <b>ygridspace</b>     The space between two horizontal grids in\n"
"                 the same unit as the data.\n"

"\n  You can also use the regular &lt;<b>img</b>&gt; arguments. They"
" will be passed\n  on to the resulting &lt;<b>img</b>&gt; tag.\n\n"
"The following internal tags are available:\n"
"\n&lt;<b>data</b>&gt; (container) Mandatory.\n"
"Tab and newline separated list of data values for the diagram."
" Options:\n"
"  <b>separator</b>      Use the specified string as separator instead"
" of tab.\n"
"  <b>lineseparator</b>  Use the specified string as lineseparator\n"
"                 instead of newline.\n"
"  <b>form</b>           Can be set to either row or column. Default\n"
"                 is row.\n"
"  <b>xnames</b>         If given, the first line or column is used as\n"
"                 xnames. If set to a number N, N lines or columns\n"
"                 are used.\n"
"  <b>xnamesvert</b>     If given, the xnames are written vertically.\n" 
"  <b>noparse</b>        Do not run the content of the tag through\n"
"                 the RXML parser before data extraction is done.\n"
"\n&lt;<b>colors</b>&gt; (container)\n"
"Tab separated list of colors for the diagram. Options:\n"
"  <b>separator</b>      Use the specified string as separator instead"
" of tab.\n"
"\n&lt;<b>legend</b>&gt; (container)\n"
"Tab separated list of titles for the legend. Options:\n"
"  <b>separator</b>      Use the specified string as separator instead"
" of tab.\n"
"\n&lt;<b>xnames</b>&gt; (container)\n"
"Tab separated list of datanames for the diagram. Options:\n"
"  <b>separator</b>      Use the specified string as separator instead"
" of tab.\n"
"  <b>orient</b>         If set to vert the xnames will be written"
" vertically.\n"
"\n&lt;<b>ynames</b>&gt; (container)\n"
"Tab separated list of datanames for the diagram. Options:\n"
"  <b>separator</b>      Use the specified string as separator instead"
" of tab.\n"
"\n&lt;<b>xaxis</b>&gt; and &lt;<b>yaxis</b>&gt; (tags)\n"
"Options:\n"
/* " name=        Dunno what this does.\n" */
//I know!!! /Hedda
"  <b>start</b>          Limit the start of the diagram at this"
" quantity.\n"
"                 If set to <b>min</b> the axis starts at the lowest"
" value.\n\n"
"  <b>stop</b>           Limit the end of the diagram at this"
" quantity.\n"
"  <b>quantity</b>       Name things represented in the diagram.\n"
"  <b>unit</b>           Name the unit.\n"
"</pre>";

#ifdef BG_DEBUG
  mapping bg_timers = ([]);
#endif

//FIXME (Inte alltid VOID!
#define VOIDCODE \
  do { voidsep = m->voidseparator||m->voidsep||res->voidsep||"VOID"; } while(0)

int loaded;

void start(int num, object configuration)
{
    if (!loaded) {
        string cdir = caudium->QUERY(argument_cache_dir) + "/" + QUERY(cachedir) + "/";
        
        loaded = 1;
        if (get_dir(cdir))
            foreach(get_dir(cdir), string file)
                rm(cdir+file);
        else
            if (!mkdirhier(cdir))
                report_warning ("BG: Cache directory "+
                                cdir+" can not be created.\n");
    }
}

void stop()
{
    string cdir = caudium->QUERY(argument_cache_dir) + "/" + QUERY(cachedir) + "/";
    if (get_dir(cdir))
        foreach(get_dir(cdir), string file)
            rm(cdir+file);
}

void create()
{
  defvar( "location", "/diagram/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	  "The URL-prefix for the diagrams." );
  defvar( "maxwidth", 3000, "Limits:Max width", TYPE_INT,
	  "Maximal width of the generated image." );
  defvar( "maxheight", 1000, "Limits:Max height", TYPE_INT,
	  "Maximal height of the generated image." );
  defvar( "maxstringlength", 60, "Limits:Max string length", TYPE_INT,
	  "Maximal length of the strings used in the diagram." );
  defvar( "cachedir", "bgcache/", "Cache directory", TYPE_DIR|VAR_MORE,
	  "The directory that will be used to store diagrams. This is "
	  "relative to the argument cache directory." );
}

string itag_xaxis(string tag, mapping m, mapping res)
{
#ifdef BG_DEBUG
  bg_timers->xaxis = gauge {
#endif
  int l=QUERY(maxstringlength)-1;

  res->xaxisfont = m->font || m->nfont || res->xaxisfont;

  if(m->name) res->xname = m->name[..l];  
  if(m->start) 
    if (lower_case(m->start[0..2])=="min")
      res->xmin=1;
    else 
      res->xstart = (float)m->start;
  if(m->stop) res->xstop = (float)m->stop;
  if(m->quantity) res->xstor = m->quantity[..l];
  if(m->unit) res->xunit = m->unit[..l];
#ifdef BG_DEBUG
  };
#endif

  return "";
}

string itag_yaxis(string tag, mapping m, mapping res)
{
#ifdef BG_DEBUG
  bg_timers->yaxis = gauge {
#endif
  int l=QUERY(maxstringlength)-1;

  res->yaxisfont = m->font || m->nfont || res->yaxisfont;

  if(m->name) res->yname = m->name[..l];
  if(m->start) 
    if (lower_case(m->start[0..2])=="min")
      res->ymin=1;
    else 
      res->ystart = (float)m->start;
  if(m->stop) res->ystop = (float)m->stop;
  if(m->quantity) res->ystor = m->quantity[..l];
  if(m->unit) res->yunit = m->unit[..l];
#ifdef BG_DEBUG
  };
#endif

  return "";
}

/* Handle <xnames> and <ynames> */
string itag_names(string tag, mapping m, string contents,
		      mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->names += gauge {
#endif
  int l=QUERY(maxstringlength)-1;

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;

  string voidsep;
  VOIDCODE;

  array foo;

  if( contents-" " != "" )
  {
    if(tag=="xnames")
    {
      res->xnamesfont = m->font || m->nfont || res->xnamesfont;

      foo=res->xnames = contents/sep;
      if(m->orient) 
	if (m->orient[0..3] == "vert")
	  res->orientation = "vert";
	else 
	  res->orientation="hor";
    }
    else
    {
      foo=res->ynames = contents/sep;
      
      res->ynamesfont = m->font || m->nfont || res->ynamesfont;
    }
  }
  else
     return "";
  
  for(int i=0; i<sizeof(foo); i++)
    if (voidsep==foo[i])
      foo[i]=" ";
    else
      foo[i]=foo[i][..l];
#ifdef BG_DEBUG
  };
#endif

  return "";
}

float|string floatify( string in , string voidsep )
{
  if (voidsep==in)
    return VOIDSYMBOL;
  else
    return (float)in;
}

/* Handle <xvalues> and <yvalues> */
string itag_values(string tag, mapping m, string contents,
		   mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->values += gauge {
#endif

  string voidsep;
  VOIDCODE;

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;
  
  if( contents-" " != "" )
  {
    if(tag=="xvalues")
      res->xvalues = Array.map( contents/sep, floatify, voidsep );
    else
      res->yvalues = Array.map( contents/sep, floatify, voidsep );
  }
#ifdef BG_DEBUG
  };
#endif

  return "";
}

string itag_data(string tag, mapping m, string contents,
		 mapping res, object id)
{
#ifdef BG_DEBUG
  bg_timers->data += gauge {
#endif

  string voidsep;
  VOIDCODE;

  string sep = m->separator || SEP;

  if (sep=="")
    sep=SEP;

  string linesep = m->lineseparator || "\n";

  if (linesep=="")
    linesep="\n";
  
  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if ((sep!="\t")&&(linesep!="\t"))
    contents = contents - "\t";

  array lines = contents/linesep-({""});
  array foo = ({});
  array bar = ({});
  int maxsize=0;

  if (sizeof(lines)==0)
  {
    res->data=({});
    return 0;
  }

#ifdef BG_DEBUG
  bg_timers->data_foo = gauge {
#endif
 
  bar=allocate(sizeof(lines));
  int gaba=sizeof(lines);

  for(int j=0; j<gaba; j++)
  {
    foo=lines[j]/sep - ({""});
    foo=replace(foo, voidsep, VOIDSYMBOL);
    if (sizeof(foo)>maxsize)
      maxsize=sizeof(foo);
    bar[j] = foo;
  }
#ifdef BG_DEBUG
  };
#endif

  if (sizeof(bar[0])==0)
  {
    res->data=({});
    return 0;
  }

#ifdef BG_DEBUG
  bg_timers->data_bar = gauge {
#endif
  if (m->form)
    if (m->form[0..2] == "col")
      {
	for(int i=0; i<sizeof(bar); i++)
	  if (sizeof(bar[i])<maxsize)
	    bar[i]+=allocate(maxsize-sizeof(bar[i]));
	
	array bar2=allocate(maxsize);
	for(int i=0; i<maxsize; i++)
	  bar2[i]=column(bar, i);
	res->data=bar2;
      } 
    else
      res->data=bar;
  else
    res->data=bar;
#ifdef BG_DEBUG
  };
#endif

  if (m->xnames)
    if (!(int)(m->xnames))
      m->xnames=1;
    else
      m->xnames=(int)(m->xnames);
  
  if ((m->xnames)&&(sizeof(res->data)>m->xnames))
  {
    res->xnames=res->data[..m->xnames-1];
    int j=sizeof(res->xnames[0]);
    mixed foo=allocate(j);
    for(int i=0; i<j; i++)
      foo[i]=(column(res->xnames, i)-({VOIDSYMBOL}))*" ";
    res->xnames=foo;
    res->data=res->data[m->xnames..];
  }
  
  if (m->xnamesvert)
    res->orientation = "vert"; 
  
#ifdef BG_DEBUG
  bg_timers->data_gaz = gauge {
#endif
    mixed b;
    mixed c;

  bar=res->data;
  int basonk=sizeof(bar);
  for(int i=0; i<basonk; i++)
    {
      c=bar[i];
      int k=sizeof(c);
      for(int j=0; j<k; j++)
	if ((b=c[j])!=VOIDSYMBOL)
	  c[j]=(float)(b);
    }
  res->data=bar;
#ifdef BG_DEBUG
  };
#endif
#ifdef BG_DEBUG
  };
#endif

  return 0;
}

string itag_colors(string tag, mapping m, string contents,
		   mapping res, object id)
{
  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;
  
  res->colors = map(contents/sep, Colors.parse_color); 

  return "";
}

string itag_legendtext(string tag, mapping m, string contents,
		       mapping res, object id)
{
  int maxlen = QUERY(maxstringlength)-1;

  string voidsep;
  VOIDCODE;

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  string sep = m->separator || SEP;

  res->legendfont = m->font || m->nfont || res->legendfont;

  res->legend_texts = contents/sep;

  array foo = res->legend_texts;

  for(int i=0; i<sizeof(foo); i++)
    if (voidsep == foo[i])
      foo[i]=" ";
    else
      foo[i]=foo[i][..maxlen];

  return "";
}

string syntax( string error )
{
  return "<hr noshade><font size=+1><b>Syntax error</b></font>&nbsp;&nbsp;"
         "(&lt;<b>diagram help</b>&gt;&lt;/<b>diagram</b>&gt; gives help)<p>"
    + error
    + "<hr noshade>";
}

//mapping(string:mapping) cache = ([]);
mapping(string:object) palette_cache = ([]);
int datacounter = 0; 

string quote(mapping in)
{
  // Don't try to be clever here. It will break threads.
  /*
  string out;
  cache[ out =
       sprintf("%d%08x%x", ++datacounter, random(99999999), time(1)) ] = in;
  */
  //NU: Create key
  string data=encode_value(in);
  object o=Crypto.sha();
  o->update(data);
  string out=replace(http_encode_string(MIME.encode_base64(o->digest(),1)),
		     "/", "$");
  string cdir = caudium->QUERY(argument_cache_dir) + "/" + QUERY(cachedir) + "/";
  
  if (file_stat(cdir+out)) return out;
  
  //NU: Create the file <Key>

  Stdio.write_file(cdir+out, data);
  
  return out;
}

constant _diagram_args =
({ "xgridspace", "ygridspace", "horgrid", "size", "type", "3d",
   "templatefontsize", "fontsize", "tone", "background","colorbg", "subtype",
   "dimensions", "dimensionsdepth", "xsize", "ysize", "fg", "bg",
   "orientation", "xstart", "xstop", "ystart", "ystop", "data", "colors",
   "xnames", "xvalues", "ynames", "yvalues", "axcolor", "gridcolor",
   "gridwidth", "vertgrid", "labels", "labelsize", "legendfontsize",
   "legendfont",
   "legend_texts", "labelcolor", "axwidth", "linewidth", "center",
   "rotate", "image", "bw", "eng", "neng", "xmin", "ymin", "turn", "notrans",
   "colortable_cache"});
constant diagram_args = mkmapping(_diagram_args,_diagram_args);

constant _shuffle_args = 
({ "dimensions", "dimensionsdepth", "ygridspace", "xgridspace",
   "xstart", "xstop", "ystart", "ystop", "colors", "xvalues", "yvalues",
   "axwidth", "xstor", "ystor", "xunit", "yunit", "fg", "bg", "voidsep" });
constant shuffle_args = mkmapping( _shuffle_args, _shuffle_args );

string tag_diagram(string tag, mapping m, string contents,
		   object id, object f, mapping defines)
{
  int l=QUERY(maxstringlength)-1;
  contents=replace(contents, "\r\n", "\n");
  contents=replace(contents, "\r", "\n");

#ifdef BG_DEBUG
  bg_timers->names = 0;
  bg_timers->values = 0;
  bg_timers->data = 0;
#endif

  mapping(string:mixed) res=([]);

#ifdef BG_DEBUG
  bg_timers->all = gauge {
#endif

  if(m->help) return module_doc;

  if(m->colortable_cache) res->colortable_cache=m->colortable_cache;
  if(m->type) res->type = m->type;
  else return syntax("You must specify a type for your table.<br>"
		     "Valid types are: "
		     "<b>sumbars</b>, "
		     "<b>normsumbars</b>, "
		     "<b>linechart</b>, "
		     "<b>barchart</b>, "
		     "<b>piechart</b> and "
		     "<b>graph</b>");

  if(m->background)
    res->background =
      combine_path( dirname(id->not_query), (string)m->background);

  if (m->name)
  {
    res->name=m->name[..l];
    if (m->namesize)
      res->namesize=(int)m->namesize;
    if (m->namecolor)
      res->namecolor=Colors.parse_color(m->namecolor);
    else
      res->namecolor=Colors.parse_color(defines->fg);
  }

  res->voidsep = m->voidseparator || m->voidsep;

  res->font = m->font || m->nfont;

  if(m->namefont)
    res->namefont=m->namefont;

  if (m->tunedbox)
    m->tonedbox=m->tunedbox;
  if(m->tonedbox) {
    array a = m->tonedbox/",";
    if(sizeof(a) != 4)
      return syntax("tonedbox must have a comma separated list of 4 colors.");
    res->tonedbox = map(a, Colors.parse_color);
  }
  else if (m->colorbg)
    res->colorbg=Colors.parse_color(m->colorbg);
  
  if ((m->bgcolor)&&(m->notrans))
  {
    res->colorbg=Colors.parse_color(m->bgcolor);
    m_delete(m, "bgcolor");
  }
  else
    if (m->notrans)
      res->colorbg=Colors.parse_color("white");
  
  res->drawtype="linear";

  switch(res->type[0..3]) {
   case "pie":
   case "piec":
     res->type = "pie";
     res->subtype="pie";
     res->drawtype = "2D";
     break;
   case "bar":
   case "bars":
   case "barc":
     res->type = "bars";
     m_delete( res, "drawtype" );
     break;
   case "line":
     res->type = "line";
     break;
   case "norm":
     res->type = "norm";
     break;
   case "grap":
     res->type = "graph";
     res->subtype = "line";
     break;
   case "sumb":
     res->type = "sumbars";
     //res->subtype = "";
     break;
   default:
     return syntax("\""+res->type+"\" is an FIX unknown type of diagram\n");
  }

  if(m["3d"])
  {
    res->drawtype = "3D";
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];    
    else
      res->dimensionsdepth = 20;
  }

  parse_html(contents,
	     ([ "xaxis":itag_xaxis,
	        "yaxis":itag_yaxis ]),
	     ([ "data":itag_data,
		"xnames":itag_names,
		"ynames":itag_names,
		"xvalues":itag_values,
		"yvalues":itag_values,
		"colors":itag_colors,
		"legend":itag_legendtext ]),
	     res, id );

  if ( !res->data || !sizeof(res->data))
    return syntax("No data for the diagram");

  res->bg = Colors.parse_color(m->bgcolor || defines->bg || "white");
  res->fg = Colors.parse_color(m->textcolor || defines->fg || "black");

  if(m->center) res->center = (int)m->center;
  if(m->eng) res->eng=1;
  if(m->neng) res->neng=1;

  res->fontsize       = (int)m->fontsize || 16;
  res->legendfontsize = (int)m->legendfontsize || res->fontsize;
  res->labelsize      = (int)m->labelsize || res->fontsize;

  if(m->labelcolor) res->labelcolor=Colors.parse_color(m->labelcolor || defines->fg);
  res->axcolor   = Colors.parse_color(m->axcolor || defines->fg);
  res->gridcolor = Colors.parse_color(m->gridcolor || defines->fg);
  res->linewidth = m->linewidth || "2.2";
  res->axwidth   = m->axwidth || "2.2";

  if(m->rotate) res->rotate = m->rotate;
  if(m->grey) res->bw = 1;

  if(m->width) {
    if((int)m->width > QUERY(maxwidth))
      m->width  = (string)QUERY(maxwidth);
    if((int)m->width < 100)
      m->width  = "100";
  } else if(!res->background)
    m->width = "350";

  if(m->height) {  
    if((int)m->height > QUERY(maxheight))
      m->height = (string)QUERY(maxheight);
    if((int)m->height < 100)
      m->height = "100";
  } else if(!res->background)
    m->height = "250";

  if(!res->background)
  {
    if(m->width) res->xsize = (int)m->width;
    else         res->xsize = 400; // A better algo for this is coming.

    if(m->height) res->ysize = (int)m->height;
    else res->ysize = 300; // Dito.
  } else {
    if(m->width) res->xsize = (int)m->width;
    if(m->height) res->ysize = (int)m->height;
  }

  if(m->tone) res->tone = 1;

  if(!res->xnames)
    if(res->xname) res->xnames = ({ res->xname });
      
  if(!res->ynames)
    if(res->yname) res->ynames = ({ res->yname });

  if(m->gridwidth) res->gridwidth = m->gridwidth;
  if(m->vertgrid) res->vertgrid = 1;
  if(m->horgrid) res->horgrid = 1;

  if(m->xgridspace) res->xgridspace = (int)m->xgridspace;
  if(m->ygridspace) res->ygridspace = (int)m->ygridspace;

  if (m->turn) res->turn=1;

  m -= diagram_args;

  // Start of res-cleaning
  res->textcolor = res->fg;
  res->bgcolor = res->bg;

  m_delete( res, "voidsep" );

  if (res->xstop)
    if(res->xstart > res->xstop) m_delete( res, "xstart" );

  if (res->ystop)
    if(res->ystart > res->ystop) m_delete( res, "ystart" );

  res->labels = ({ res->xstor, res->ystor, res->xunit, res->yunit });

  if(res->dimensions) res->drawtype = res->dimensions;
  if(res->dimensionsdepth) res["3Ddepth"] = res->dimensionsdepth;
  if(res->ygridspace)  res->yspace = res->ygridspace;
  if(res->xgridspace)  res->xspace = res->xgridspace;
  if(res->orientation) res->orient = res->orientation;
  if((int)res->xstart)  res->xminvalue  = (float)res->xstart;
  if((int)res->xstop)   res->xmaxvalue  = (float)res->xstop;
  if(res->ystart)  res->yminvalue  = (float)res->ystart;
  if(res->ystop)   res->ymaxvalue  = (float)res->ystop;
  if(res->colors)  res->datacolors = res->colors;
  if(res->xvalues) res->values_for_xnames = res->xvalues;
  if(res->yvalues) res->values_for_ynames = res->yvalues;
  if((int)res->linewidth) res->graphlinewidth = (float)res->linewidth;
  else m_delete( res, "linewidth" );
  if((int)res->axwidth) res->linewidth  = (float)res->axwidth;

  res -= shuffle_args;

  m->src = QUERY(location) + quote(res) + ".gif";
  if ((res->name)&&(!m->alt))
    m->alt=res->name;

  if (res->turn)
  {
    int t;
    t=m->width;
    m->width=m->height;
    m->height=t;
  }
#ifdef BG_DEBUG
  };
#endif


#ifdef BG_DEBUG
  if(id->prestate->debug)
    return(sprintf("<pre>Timers: %O\n</pre>", bg_timers) + make_tag("img", m));
#endif

  return make_tag("img", m);
}

mapping query_container_callers()
{
  return ([ "diagram" : tag_diagram ]);
}

int|object PPM(string fname, object id)
{
  if( objectp(fname) )
    perror("fname: %O\n",indices(fname));
  string q;
  q = id->conf->try_get_file( fname, id );

  if(!q) perror("Diagram: Unknown image '"+fname+"'\n");

  object g;
  if (sizeof(indices( g=Gz )))
    if (g->inflate)
      catch { q = g->inflate()->inflate(q); };

  if(q)
  { 
    object img_decode;
#if constant(Image.ANY.decode)
    if (!catch{img_decode = Image.ANY.decode(q);})
      return img_decode;
    else
#endif
    if (q[0..2] == "GIF")
      if (catch{img_decode = Image.GIF.decode(q);})
	return 1;
      else
	return img_decode;
#if constant(Image.JPEG.decode)
    else if (search(q[0..13],"JFIF")!=-1)
      if (catch{img_decode = Image.JPEG.decode(q);})
	return 1;
      else
	return img_decode;
#endif
    else  if (q[0..0]=="P")
      if (catch{img_decode = Image.PNM.decode(q);})
	return 1;
      else
	return img_decode;
    
#if constant(Image.JPEG.decode)
    perror("Diagram: Unknown image type for '"+fname+"', "
	   "only GIF, jpeg and pnm is supported.\n");
    return 1;
#else
    perror("Diagram: Unknown image type for '"+fname+"', "
	   "only pnm is supported.\n");
    return 1;
#endif
  }
  else
    return 1;
}

mapping http_img_answer( string msg )
{
  return http_string_answer( msg );
}

mapping unquote( string f )
{
  //NU: Load the file f

  if (catch {
    return decode_value(Stdio.read_file(caudium->QUERY(argument_cache_dir) + "/" + QUERY(cachedir) + "/" + f));
  })
    return 0;
  
  //  return cache[ f ];
}

mapping find_file(string f, object id)
{
#ifdef BG_DEBUG
  //return 0;
#endif

  //NU: If the file <f>.gif exists return it
  string temp;
  string cdir = caudium->QUERY(argument_cache_dir) + "/" + QUERY(cachedir) + "/";
  
  if (temp=Stdio.read_file(cdir+f+".gif"))
    return http_string_answer(temp, "image/gif");


  if (f[sizeof(f)-4..] == ".gif")
    f = f[..sizeof(f)-5];

  if( f=="" )
    return http_img_answer( "This is BG's mountpoint." );

  mapping res = copy_value( unquote( f ) );

  //FIXME Ta bort f?

  if(!res)
    return http_img_answer( "Please reload this page." );

  if(id->prestate->debug)
    return http_string_answer( sprintf("<pre>%O\n", res) );
  
  mapping(string:mixed) diagram_data;

  array back=0;
  if (res->bgcolor)
    back = res->bgcolor;

  if(res->background)
  {
    m_delete( res, "bgcolor" );
    res->image = PPM(res->background, id);

    /* Image was not found or broken */
    if(res->image == 1) 
    {
      res->image=get_font(0, 24, 0, 0,"left", 0, 0);
      if (!(res->image))
	throw(({"Missing font or similar error!\n", backtrace() }));
      res->image=res->image->
#if constant(Image.JPEG.decode)
	write("The file was", "not found ",
	      "or was not a","jpeg-, gif- or","pnm-picture.");
#else
	write("The file was","not found ",
	      "or was not a","pnm-picture.");
#endif
    }
  } else if(res->tonedbox) {
    m_delete( res, "bgcolor" );
    res->image = Image.Image(res->xsize, res->ysize)->
      tuned_box(0, 0, res->xsize, res->ysize, res->tonedbox);
  }
  else if (res->colorbg)
  {
    back=0; //res->bgcolor;
    m_delete( res, "bgcolor" );
    res->image = Image.Image(res->xsize, res->ysize, @res->colorbg);
  } 
  /*else if (res->notrans)
    {
      res->image = image(res->xsize, res->ysize, @res->bgcolor);
      m_delete( res, "bgcolor" );
    }
  */
  if(res->font)
    res->font = resolve_font(res->font);
  else
    res->font = resolve_font("default");
  
  diagram_data = res;
  Image.Image img;

  if(res->image)
    diagram_data["image"] = res->image; //FIXME: Why is this here?

#ifdef BG_DEBUG
  bg_timers->drawing = gauge {
#endif
    switch(diagram_data->type) {
    case "pie":
      img = Graphics.Graph.pie(diagram_data);
      break;
    case "bars":
      img = Graphics.Graph.bars(diagram_data);
      break;
    case "sumbars":
      img = Graphics.Graph.bars(diagram_data);
      break;
    case "norm":
      img = Graphics.Graph.norm(diagram_data);
      break;
    case "line":
      img = Graphics.Graph.line(diagram_data);
      break;
    case "graph":
      img = Graphics.Graph.graph(diagram_data);
      break;
    }
#ifdef BG_DEBUG
  };
  if (diagram_data->bg_timers)
    bg_timers+=diagram_data->bg_timers;
#endif
  object ct;
  if(res->colortable_cache)
  {
    ct = palette_cache[res->colortable_cache];
    if(!ct)
      ct = palette_cache[res->colortable_cache] =
	   Image.colortable(img)->nodither();
  }

  if (res->turn)
    img=img->rotate_ccw();
	
#ifdef BG_DEBUG
  if(id->prestate->debug)
    werror("Timers: %O\n", bg_timers);
#endif
  if(!ct) ct = Image.Colortable(img)->nodither();

  //NU: Save the created gif as <f>.gif!

  if(back)
  {
    string foo=Image.GIF.encode(img, ct, @back);
    Stdio.write_file(cdir+f+".gif", foo);
    return http_string_answer(foo, "image/gif");
  }
  else
  {
    string foo=Image.GIF.encode(img, ct);
    Stdio.write_file(cdir+f+".gif", foo);
    return http_string_answer(foo, "image/gif");
  }
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: location
//! The URL-prefix for the diagrams.
//!  type: TYPE_LOCATION|VAR_MORE
//!  name: Mountpoint
//
//! defvar: maxwidth
//! Maximal width of the generated image.
//!  type: TYPE_INT
//!  name: Limits:Max width
//
//! defvar: maxheight
//! Maximal height of the generated image.
//!  type: TYPE_INT
//!  name: Limits:Max height
//
//! defvar: maxstringlength
//! Maximal length of the strings used in the diagram.
//!  type: TYPE_INT
//!  name: Limits:Max string length
//
//! defvar: cachedir
//! The directory that will be used to store diagrams. This is relative to the argument cache directory.
//!  type: TYPE_DIR|VAR_MORE
//!  name: Cache directory
//
