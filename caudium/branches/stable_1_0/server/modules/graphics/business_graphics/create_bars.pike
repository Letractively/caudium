#!NOMODULE
/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2001 The Caudium Group
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

#define max(i, j) (((i)>(j)) ? (i) : (j))
#define min(i, j) (((i)<(j)) ? (i) : (j))
#define abs(arg) ((arg)*(1-2*((arg)<0)))

#define PI 3.14159265358979
#define VOIDSYMBOL "\n"
#define SEP "\t"

constant LITET = 1.0e-38;
constant STORTLITET = 1.0e-30;
constant STORT = 1.0e30;

import Array;
import Stdio;
#if constant(Image.image)
#define OLDSTYLE
#define IMAGE Image.image
#else
#define IMAGE Image.Image
#endif
inherit "polyline.pike";
inherit "create_graph.pike";

constant cvs_version = "$Id$";

/*
 * name = "BG: Create bars";
 * doc = "Business Graphics sub-module for drawing bars.";
 */

/*
These functions were written by Henrik "Hedda" Wallin (hedda@idonex.se)
Create_bars can draw normal bars, sumbars and normalized sumbars.
*/ 

#define GETFONT(WHATFONT) notext=resolve_font(diagram_data->WHATFONT||diagram_data->font);

mapping(string:mixed) create_bars(mapping(string:mixed) diagram_data)
{
  object notext;
#ifdef BG_DEBUG
  mapping bg_timers = ([]);
#endif

  //Supports only xsize>=100

  int si=diagram_data["fontsize"];
 
  //Fix defaultcolors!
  setinitcolors(diagram_data);


  string where_is_ax;

  object(IMAGE) barsdiagram;

#ifdef BG_DEBUG
  bg_timers->init_bg = gauge {
#endif
  init_bg(diagram_data);
#ifdef BG_DEBUG
  };
#endif
  barsdiagram=diagram_data["image"];

#ifdef BG_DEBUG
  bg_timers->set_legend_size = gauge {
#endif
  set_legend_size(diagram_data);
#ifdef BG_DEBUG
  };
#endif
  //write("ysize:"+diagram_data["ysize"]+"\n");
  diagram_data["ysize"]-=diagram_data["legend_size"];
  //write("ysize:"+diagram_data["ysize"]+"\n");
  
#ifdef BG_DEBUG
  bg_timers->init = gauge {
#endif

  //Best�m st�rsta och minsta datav�rden.
  init(diagram_data);
#ifdef BG_DEBUG
  };
#endif
  //Ta reda hur m�nga och hur stora textmassor vi ska skriva ut


#ifdef BG_DEBUG
  bg_timers->space = gauge {
#endif

  if (!(diagram_data["xspace"]))
  {
    //Initera hur l�ngt det ska vara emellan.
    
    float range=(diagram_data["xmaxvalue"]-
		 diagram_data["xminvalue"]);
    //write("range"+range+"\n");
    float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
    if (range/space>5.0)
    {
      if(range/(2.0*space)>5.0)
      {
	space=space*5.0;
      }
      else
	space=space*2.0;
    }
    else
      if (range/space<2.5)
	space*=0.5;
    diagram_data["xspace"]=space;      
  }
  if (!(diagram_data["yspace"]))
  {
    //Initera hur l�ngt det ska vara emellan.
    
    float range=(diagram_data["ymaxvalue"]-
		 diagram_data["yminvalue"]);
    float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
    if (range/space>5.0)
    {
      if(range/(2.0*space)>5.0)
	space *= 5.0;
      else
	space *= 2.0;
    }
    else
      if (range/space<2.5)
	space *= 0.5;
    diagram_data["yspace"]=space;      
  }
 
#ifdef BG_DEBUG
  };
#endif


#ifdef BG_DEBUG
  bg_timers->text = gauge {
#endif
    
    
  float start;
  start=diagram_data["xminvalue"]+diagram_data["xspace"]/2.0;
  diagram_data["values_for_xnames"]=allocate(sizeof(diagram_data["xnames"]));
  for(int i=0; i<sizeof(diagram_data["xnames"]); i++)
    diagram_data["values_for_xnames"][i]=start+start*2*i;

  if (!(diagram_data["values_for_ynames"]))
  {
    if ((diagram_data["yspace"]<LITET)
	&& (diagram_data["yspace"]>-LITET))
      throw( ({"Very bad error because yspace is zero!\n",
	       backtrace()}));
    float start;
    start=diagram_data["yminvalue"];
    start=diagram_data["yspace"]*ceil((start)/diagram_data["yspace"]);
    diagram_data["values_for_ynames"]=({start});
    while(diagram_data["values_for_ynames"][-1]<=
	  diagram_data["ymaxvalue"]-diagram_data["yspace"])
      diagram_data["values_for_ynames"]+=({start+=diagram_data["yspace"]});
  }
  
  function fun;
  if (diagram_data["eng"])
    fun=diagram_eng;
  else
    fun=diagram_neng;
  
  //Generera texten om den inte finns
  if (!(diagram_data["ynames"]))
    if (diagram_data["eng"]||diagram_data["neng"])
    {
      diagram_data["ynames"]=
	allocate(sizeof(diagram_data["values_for_ynames"]));
      array(mixed) v=diagram_data["values_for_ynames"];
      mixed m=diagram_data["ymaxvalue"];
      mixed mi=diagram_data["yminvalue"];
      for(int i=0; i<sizeof(v); i++)
	if (abs(v[i]*1000)<max(m, abs(mi)))
	  diagram_data["ynames"][i]="0";
	else	
	  diagram_data["ynames"][i]=
	    fun((float)(v[i]));
    }
    else
    {
      diagram_data["ynames"]=
	allocate(sizeof(diagram_data["values_for_ynames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_ynames"]); i++)
	diagram_data["ynames"][i]=
	  no_end_zeros((string)(diagram_data["values_for_ynames"][i]));
    }
  
  
  if (!(diagram_data["xnames"]))
  {
    diagram_data["xnames"]=
      allocate(sizeof(diagram_data["values_for_xnames"]));
      
    for(int i=0; i<sizeof(diagram_data["values_for_xnames"]); i++)
      diagram_data["xnames"][i]=
	no_end_zeros((string)(diagram_data["values_for_xnames"][i]));
  }


  //rita bilderna f�r texten
  //ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
  create_text(diagram_data);
  si=diagram_data["fontsize"];

#ifdef BG_DEBUG
  };
#endif

  //Skapa labelstexten f�r xaxlen
  object labelimg;
  string label;
  int labelx=0;
  int labely=0;
  if (diagram_data["labels"])
  {
    if (diagram_data["labels"][2] && sizeof(diagram_data["labels"][2]))
      label=diagram_data["labels"][0]+" ["+diagram_data["labels"][2]+"]"; //Xstorhet
    else
      label=diagram_data["labels"][0];

    GETFONT(xaxisfont);
    if ((label!="")&&(label!=0))
      labelimg=notext
	->write(label)->scale(0,diagram_data["labelsize"]);
    else
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);

    if (labelimg->xsize()<1)
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);

    if (labelimg->xsize()>
	diagram_data["xsize"]/2)
      labelimg=labelimg->scale(diagram_data["xsize"]/2, 0);

    labely=diagram_data["labelsize"];
    labelx=labelimg->xsize();
  }
  else
    diagram_data["labelsize"]=0;

  labely+=write_name(diagram_data);

  int ypos_for_xaxis; //avst�nd NERIFR�N!
  int xpos_for_yaxis; //avst�nd fr�n h�ger
  //Best�m var i bilden vi f�r rita graf
  diagram_data["ystart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["ystop"]=diagram_data["ysize"]-
    (int)ceil(diagram_data["linewidth"]+si)-labely;
  if (((float)diagram_data["yminvalue"]>-LITET)&&
      ((float)diagram_data["yminvalue"]<LITET))
    diagram_data["yminvalue"]=0.0;

  if (diagram_data["yminvalue"]<0)
  {
    //placera ut x-axeln.
    //om detta inte funkar s� rita xaxeln l�ngst ner/l�ngst upp och r�kna om diagram_data["ystart"]
    ypos_for_xaxis=((-diagram_data["yminvalue"])
		    * (diagram_data["ystop"] - diagram_data["ystart"]))
      /	(diagram_data["ymaxvalue"]-diagram_data["yminvalue"])
      + diagram_data["ystart"];
      
    int minpos;
    minpos=max(labely, diagram_data["ymaxxnames"])+si/2;
    if (minpos>ypos_for_xaxis)
    {
      ypos_for_xaxis=minpos;
      diagram_data["ystart"]=ypos_for_xaxis+
	diagram_data["yminvalue"]*(diagram_data["ystop"]-ypos_for_xaxis)/
	(diagram_data["ymaxvalue"]);
    }
    else
    {
      int maxpos;
      maxpos=diagram_data["ysize"]-
	(int)ceil(diagram_data["linewidth"]+si*2)
	- labely;
      if (maxpos<ypos_for_xaxis)
      {
	ypos_for_xaxis=maxpos;
	diagram_data["ystop"]=ypos_for_xaxis
	  + diagram_data["ymaxvalue"]*(ypos_for_xaxis-diagram_data["ystart"])
	  / (0-diagram_data["yminvalue"]);
      }
    }
  }
  else
    if (diagram_data["yminvalue"]==0.0)
    {
      // s�tt x-axeln l�ngst ner och diagram_data["ystart"] p� samma st�lle.
      diagram_data["ystop"]=diagram_data["ysize"]
	- (int)ceil(diagram_data["linewidth"]+si)-labely;
      ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si/2;
      diagram_data["ystart"]=ypos_for_xaxis;
    }
    else
    {
      //s�tt x-axeln l�ngst ner och diagram_data["ystart"] en aning h�gre
      diagram_data["ystop"]=diagram_data["ysize"]
	- (int)ceil(diagram_data["linewidth"]+si)-labely;
      ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si/2;
      diagram_data["ystart"]=ypos_for_xaxis+si*2;
    }
  
  //xpos_for_yaxis=diagram_data["xmaxynames"]+
  // si;

  //Best�m positionen f�r y-axeln
  diagram_data["xstart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["xstop"]=diagram_data["xsize"]-
    (int)ceil(diagram_data["linewidth"])-max(si,labelx+si/2)-
    diagram_data["xmaxxnames"]/2;
  if (((float)diagram_data["xminvalue"]>-LITET)&&
      ((float)diagram_data["xminvalue"]<LITET))
    diagram_data["xminvalue"]=0.0;
  
  if (diagram_data["xminvalue"]<0)
  {
    //placera ut y-axeln.
    //om detta inte funkar s� rita yaxeln l�ngst ner/l�ngst upp och r�kna om diagram_data["xstart"]
    xpos_for_yaxis=((-diagram_data["xminvalue"])
		    * (diagram_data["xstop"]-diagram_data["xstart"]))
      /	(diagram_data["xmaxvalue"]-diagram_data["xminvalue"])
      + diagram_data["xstart"];
      
    int minpos;
    minpos=diagram_data["xmaxynames"]+si/2;
    if (minpos>xpos_for_yaxis)
    {
      xpos_for_yaxis=minpos;
      diagram_data["xstart"]=xpos_for_yaxis+
	diagram_data["xminvalue"]*(diagram_data["xstop"]-xpos_for_yaxis)/
	(diagram_data["ymaxvalue"]);
    }
    else
    {
      int maxpos;
      maxpos=diagram_data["xsize"]-
	(int)ceil((float)diagram_data["linewidth"]+si*2+labelx);
      if (maxpos<xpos_for_yaxis)
      {
	xpos_for_yaxis=maxpos;
	diagram_data["xstop"]=xpos_for_yaxis+
	  diagram_data["xmaxvalue"]*(xpos_for_yaxis-diagram_data["xstart"])/
	  (0-diagram_data["xminvalue"]);
      }
    }
  }
  else
    if (diagram_data["xminvalue"]==0.0)
    {
      // s�tt y-axeln l�ngst ner och diagram_data["xstart"] p� samma st�lle.
      //write("\nNu blev xminvalue noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");
	
      diagram_data["xstop"]=diagram_data["xsize"]-
	(int)ceil(diagram_data["linewidth"])-max(si,labelx+si/2)-
	diagram_data["xmaxxnames"]/2;
      xpos_for_yaxis=diagram_data["xmaxynames"]+si/2+2;
      diagram_data["xstart"]=xpos_for_yaxis+si/2;
    }
    else
    {
      //s�tt y-axeln l�ngst ner och diagram_data["xstart"] en aning h�gre
      //write("\nNu blev xminvalue st�rre �n noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");
      
      diagram_data["xstop"]=diagram_data["xsize"]-
	(int)ceil(diagram_data["linewidth"])-max(si,labelx+si/2)-
	diagram_data["xmaxxnames"]/2;
      xpos_for_yaxis=diagram_data["xmaxynames"]+si/2;
      diagram_data["xstart"]=xpos_for_yaxis+si*2;
    }

  //R�kna ut lite skit
  float xstart=(float)diagram_data["xstart"];
  float xmore=(-xstart+diagram_data["xstop"])/
    (diagram_data["xmaxvalue"]-diagram_data["xminvalue"]);
  float ystart=(float)diagram_data["ystart"];
  float ymore=(-ystart+diagram_data["ystop"])/
    (diagram_data["ymaxvalue"]-diagram_data["yminvalue"]);
  
#ifdef BG_DEBUG
  bg_timers->draw_grid = gauge {
#endif

  draw_grid(diagram_data, xpos_for_yaxis, ypos_for_xaxis, 
	     xmore, ymore, xstart, ystart, (float) si);
  
#ifdef BG_DEBUG
  };
#endif


  //Rita ut bars datan
  int farg=0;
  //write("xstart:"+diagram_data["xstart"]+"\nystart"+diagram_data["ystart"]+"\n");
  //write("xstop:"+diagram_data["xstop"]+"\nystop"+diagram_data["ystop"]+"\n");


 
#ifdef BG_DEBUG
  bg_timers->draw_values = gauge {
#endif

  if (diagram_data["type"]=="sumbars")
  {
    int s=diagram_data["datasize"];
    float barw=diagram_data["xspace"]*xmore/3.0;
    for(int i=0; i<s; i++)
    {
      int j=0;
      float x,y;
      x=xstart+(diagram_data["xspace"]/2.0+diagram_data["xspace"]*i)*
	xmore;
      
      y=-(-diagram_data["yminvalue"])*ymore+
	diagram_data["ysize"]-ystart;	 
      float start=y;
      
      foreach(column(diagram_data["data"], i), float|string d)
      {
	if (d==VOIDSYMBOL)
	  d=0.0;
	y-=d*ymore;
	
	barsdiagram->setcolor(@(diagram_data["datacolors"][j++]));
	
	barsdiagram->polygone(
			      ({x-barw, y 
				, x+barw, y, 
				x+barw, start
				, x-barw, start
			      }));  
	/*   barsdiagram->setcolor(0,0,0);
	     draw(barsdiagram, 0.5, 
	     ({
	     x-barw, start,
	     x-barw, y 
	     , x+barw, y, 
	     x+barw, start
	     
	     })
	     );
	*/
	start=y;
      }
    }
  }
  else
  if (diagram_data["subtype"]=="line")
    if (diagram_data["drawtype"]=="linear")
      foreach(diagram_data["data"], array(float|string) d)
      {
	array(float|string) l=allocate(sizeof(d)*2);
	for(int i=0; i<sizeof(d); i++)
	  if (d[i]==VOIDSYMBOL)
	  {
	    l[i*2]=VOIDSYMBOL;
	    l[i*2+1]=VOIDSYMBOL;
	  }
	  else
	  {
	    l[i*2]=xstart+(diagram_data["xspace"]/2.0+
			   diagram_data["xspace"]*i)
	      * xmore;
	    l[i*2+1]=-(d[i]-diagram_data["yminvalue"])*ymore+
	      diagram_data["ysize"]-ystart;	  
	  }
	  
	  //Draw Ugly outlines
	  if ((diagram_data["backdatacolors"])&&
	      (diagram_data["backlinewidth"]))
	  {
	    barsdiagram->setcolor(@(diagram_data["backdatacolors"][farg]));
	    draw(barsdiagram, diagram_data["backlinewidth"],l,
		 diagram_data["xspace"] );
	  }

	  barsdiagram->setcolor(@(diagram_data["datacolors"][farg++]));
	  draw(barsdiagram, diagram_data["graphlinewidth"],l);
      }
    else
      throw( ({"\""+diagram_data["drawtype"]
	       + "\" is an unknown bars-diagram drawtype!\n",
	       backtrace()}));
  else
    if (diagram_data["subtype"]=="box")
      if (diagram_data["drawtype"]=="2D")
      {
	int s=sizeof(diagram_data["data"]);
	float barw=diagram_data["xspace"]*xmore/1.5;
	float dnr=-barw/2.0+ barw/s/2.0;
	barw/=s;
	barw/=2.0;
	farg=-1;
	float yfoo=(float)(diagram_data["ysize"]-ypos_for_xaxis);
	//"draw_values":3580,
	foreach(diagram_data["data"], array(float|string) d)
	{
	  farg++;
	  
	  for(int i=0; i<sizeof(d); i++)
	    if (d[i]!=VOIDSYMBOL)
	    {
	      float x,y;
	      x=xstart+(diagram_data["xspace"]/2.0+diagram_data["xspace"]*i)*
		xmore;
	      y=-(d[i]-diagram_data["yminvalue"])*ymore+
		diagram_data["ysize"]-ystart;	 
		    
	      // if (y>diagram_data["ysize"]-ypos_for_xaxis-diagram_data["linewidth"]) 
	      // y=diagram_data["ysize"]-ypos_for_xaxis-diagram_data["linewidth"];
		    
	      barsdiagram->setcolor(@(diagram_data["datacolors"][farg]));
	      
	      barsdiagram->polygone(
				    ({x-barw+dnr, y 
				      , x+barw+dnr, y, 
				      x+barw+dnr, yfoo
				      , x-barw+dnr, yfoo
				    })); 
	      /*  barsdiagram->setcolor(0,0,0);		  
		  draw(barsdiagram, 0.5, 
		  ({x-barw+dnr, y 
		  , x+barw+dnr, y, 
		  x+barw+dnr, diagram_data["ysize"]-ypos_for_xaxis
		  , x-barw+dnr,diagram_data["ysize"]- ypos_for_xaxis,
		  x-barw+dnr, y 
		  }));*/
	    }
	  dnr+=barw*2.0;
	}   
      }
      else
	throw( ({"\""+diagram_data["drawtype"]
		 + "\" is an unknown bars-diagram drawtype!\n", backtrace()}));
    else
      throw( ({"\""+diagram_data["subtype"]
	       +"\" is an unknown bars-diagram subtype!\n", backtrace()}));

#ifdef BG_DEBUG
  };
#endif
  
  //Rita ut axlarna
  barsdiagram->setcolor(@(diagram_data["axcolor"]));
  
  //write((string)diagram_data["xminvalue"]+"\n"+(string)diagram_data["xmaxvalue"]+"\n");

  //Rita xaxeln
  if ((diagram_data["xminvalue"]<=LITET)&&
      (diagram_data["xmaxvalue"]>=-LITET))
    barsdiagram->
      polygone(make_polygon_from_line(diagram_data["linewidth"], 
				      ({
					xpos_for_yaxis,
					diagram_data["ysize"]- ypos_for_xaxis,
					diagram_data["xsize"]-
					diagram_data["linewidth"]-labelx/2,  
					diagram_data["ysize"]-ypos_for_xaxis
				      }), 
				      1, 1)[0]);
  else
    if (diagram_data["xmaxvalue"]<-LITET)
    {
      //write("xpos_for_yaxis"+xpos_for_yaxis+"\n");
      
      //diagram_data["xstop"]-=(int)ceil(4.0/3.0*(float)si);
      barsdiagram
	->polygone(make_polygon_from_line(
                     diagram_data["linewidth"], 
		     ({
		       xpos_for_yaxis,
		       diagram_data["ysize"]-ypos_for_xaxis,
		       
		       xpos_for_yaxis-4.0/3.0*si, 
		       diagram_data["ysize"]-ypos_for_xaxis,
		       
		       xpos_for_yaxis-si, 
		       diagram_data["ysize"]-ypos_for_xaxis-si/2.0,
		       xpos_for_yaxis-si/1.5,
		       diagram_data["ysize"]-ypos_for_xaxis+si/2.0,
		       
		       xpos_for_yaxis-si/3.0,
		       diagram_data["ysize"]-ypos_for_xaxis,
		       
		       diagram_data["xsize"]-diagram_data["linewidth"]
		       - labelx/2, 
		       diagram_data["ysize"]-ypos_for_xaxis
		     }), 1, 1)[0]);
    }
    else
      if (diagram_data["xminvalue"]>LITET)
      {
	//diagram_data["xstart"]+=(int)ceil(4.0/3.0*(float)si);
	barsdiagram
	  ->polygone(make_polygon_from_line(
                       diagram_data["linewidth"], 
		       ({
			 xpos_for_yaxis,
			 diagram_data["ysize"]- ypos_for_xaxis,
			 
			 xpos_for_yaxis+si/3.0, 
			 diagram_data["ysize"]-ypos_for_xaxis,
			 
			 xpos_for_yaxis+si/1.5, 
			 diagram_data["ysize"]-ypos_for_xaxis-si/2.0,
			 xpos_for_yaxis+si, 
			 diagram_data["ysize"]-ypos_for_xaxis+si/2.0,
			 
			 xpos_for_yaxis+4.0/3.0*si, 
			 diagram_data["ysize"]-ypos_for_xaxis,
			 
			 diagram_data["xsize"]-diagram_data["linewidth"]
			 - labelx/2, 
			 diagram_data["ysize"]-ypos_for_xaxis
		       }), 1, 1)[0]);
      }
  
  //Rita pilen p� xaxeln
  if (diagram_data["subtype"]=="line")
    barsdiagram->polygone( ({
      diagram_data["xsize"]-diagram_data["linewidth"]/2-(float)si-labelx/2,
      diagram_data["ysize"]-ypos_for_xaxis-(float)si/4.0,
      
      diagram_data["xsize"]-diagram_data["linewidth"]/2-labelx/2,
      diagram_data["ysize"]-ypos_for_xaxis,
      
      diagram_data["xsize"]-diagram_data["linewidth"]/2-(float)si-labelx/2,
      diagram_data["ysize"]-ypos_for_xaxis+(float)si/4.0
    })
			   );  
  
  //Rita yaxeln
  if ((diagram_data["yminvalue"]<=LITET)&&
      (diagram_data["ymaxvalue"]>=-LITET))
  {
    if  ((diagram_data["yminvalue"]<=LITET)&&
	 (diagram_data["yminvalue"]>=-LITET)) 
      barsdiagram->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis,
					  diagram_data["ysize"]-ypos_for_xaxis,
					  // diagram_data["ysize"]-diagram_data["linewidth"],
					  xpos_for_yaxis,
					  si+labely
					  }), 1, 1)[0]);
    else
      barsdiagram->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis,
					  diagram_data["ysize"]
					  - diagram_data["linewidth"],
					  
					  xpos_for_yaxis,
					  si+labely
					  }), 1, 1)[0]);
    
  }
  else
    if (diagram_data["ymaxvalue"]<-LITET)
    {
      barsdiagram->
	polygone(make_polygon_from_line(
                   diagram_data["linewidth"], 
		   ({
		     xpos_for_yaxis,
		     diagram_data["ysize"]-diagram_data["linewidth"],
		     
		     xpos_for_yaxis,
		     diagram_data["ysize"]-ypos_for_xaxis+si*4.0/3.0,
		     
		     xpos_for_yaxis-si/2.0,
		     diagram_data["ysize"]-ypos_for_xaxis+si,
		     
		     xpos_for_yaxis+si/2.0,
		     diagram_data["ysize"]-ypos_for_xaxis+si/1.5,
		     
		     xpos_for_yaxis,
		     diagram_data["ysize"]-ypos_for_xaxis+si/3.0,
		     
		     xpos_for_yaxis,
		     si+labely
		   }), 1, 1)[0]);
    }
    else
      if (diagram_data["yminvalue"]>LITET)
      {
	barsdiagram->
	  polygone(make_polygon_from_line(
		     diagram_data["linewidth"], 
		     ({
		       xpos_for_yaxis,
		       diagram_data["ysize"]-diagram_data["linewidth"],
		       
		       xpos_for_yaxis,
		       diagram_data["ysize"]-ypos_for_xaxis-si/3.0,
		       
		       xpos_for_yaxis-si/2.0,
		       diagram_data["ysize"]-ypos_for_xaxis-si/1.5,
		       
		       xpos_for_yaxis+si/2.0,
		       diagram_data["ysize"]-ypos_for_xaxis-si,
		       
		       xpos_for_yaxis,
		       diagram_data["ysize"]-ypos_for_xaxis-si*4.0/3.0,
		       
		       xpos_for_yaxis,
		       si+labely
		     }), 1, 1)[0]);
      }
    
  //Rita pilen
  barsdiagram->
    polygone( ({
      xpos_for_yaxis-(float)si/4.0,
      diagram_data["linewidth"]/2.0+(float)si+labely,
				      
      xpos_for_yaxis,
      diagram_data["linewidth"]/2.0+labely,
	
      xpos_for_yaxis+(float)si/4.0,
      diagram_data["linewidth"]/2.0+(float)si+labely
    }) ); 

  //Placera ut texten p� X-axeln
  int s=sizeof(diagram_data["xnamesimg"]);


 
#ifdef BG_DEBUG
  bg_timers->text_on_axis = gauge {
#endif

  for(int i=0; i<s; i++)
    if ((diagram_data["values_for_xnames"][i]<diagram_data["xmaxvalue"])&&
	(diagram_data["values_for_xnames"][i]>diagram_data["xminvalue"]))
    {
      barsdiagram->paste_alpha_color(
                    diagram_data["xnamesimg"][i], 
		    @(diagram_data["textcolor"]), 
		    (int)floor((diagram_data["values_for_xnames"][i]
				- diagram_data["xminvalue"])*xmore+xstart
			       - diagram_data["xnamesimg"][i]->xsize()/2), 
		    (int)floor(diagram_data["ysize"]-ypos_for_xaxis+si/4.0));
    }

  //Placera ut texten p� Y-axeln
  s=min(sizeof(diagram_data["ynamesimg"]), 
	sizeof(diagram_data["values_for_ynames"]));
  for(int i=0; i<s; i++)
    if ((diagram_data["values_for_ynames"][i]<=diagram_data["ymaxvalue"])&&
	(diagram_data["values_for_ynames"][i]>=diagram_data["yminvalue"]))
    {
      //write("\nYmaXnames:"+diagram_data["ymaxynames"]+"\n");
      barsdiagram->setcolor(@diagram_data["textcolor"]);
      barsdiagram->paste_alpha_color(
                     diagram_data["ynamesimg"][i], 
		     @(diagram_data["textcolor"]), 
		     (int)floor(xpos_for_yaxis-
				si/4.0-diagram_data["linewidth"]-
				diagram_data["ynamesimg"][i]->xsize()),
		     (int)floor(-(diagram_data["values_for_ynames"][i]-
				  diagram_data["yminvalue"])
				*ymore+diagram_data["ysize"]-ystart
				-
				diagram_data["ymaxynames"]/2));
      
      barsdiagram->setcolor(@diagram_data["axcolor"]);
      barsdiagram->
	polygone(make_polygon_from_line(
                   diagram_data["linewidth"], 
		   ({
		     xpos_for_yaxis-si/4,
		     (-(diagram_data["values_for_ynames"][i]
			- diagram_data["yminvalue"])*ymore
		      + diagram_data["ysize"]-ystart),
		     
		     xpos_for_yaxis+si/4,
		     (-(diagram_data["values_for_ynames"][i]
			- diagram_data["yminvalue"])*ymore
		      + diagram_data["ysize"]-ystart)
		   }), 1, 1)[0]);
    }


  //S�tt ut labels ({xstorhet, ystorhet, xenhet, yenhet})
  if (diagram_data["labelsize"])
  {
    barsdiagram
      ->paste_alpha_color(labelimg, 
			  @(diagram_data["labelcolor"]), 
			  diagram_data["xsize"]-labelx
			  - (int)ceil((float)diagram_data["linewidth"]),
			  diagram_data["ysize"]
			  - (int)ceil((float)(ypos_for_xaxis-si/2)));
      
    string label;
    int x;
    int y;

    if (diagram_data["labels"][3] && sizeof(diagram_data["labels"][3]))
      label=diagram_data["labels"][1]+" ["+diagram_data["labels"][3]+"]"; //Ystorhet
    else
      label=diagram_data["labels"][1];
    GETFONT(yaxisfont);
    if ((label!="")&&(label!=0))
      labelimg=notext
	->write(label)->scale(0,diagram_data["labelsize"]);
    else
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);
    
    if (labelimg->xsize()<1)
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);
    
    if (labelimg->xsize()>
	diagram_data["xsize"])
      labelimg=labelimg->scale(diagram_data["xsize"], 0);

    //if (labelimg->xsize()> barsdiagram->xsize())
    //labelimg->scale(barsdiagram->xsize(),labelimg->ysize());
      
    x=max(2,((int)floor((float)xpos_for_yaxis)-labelimg->xsize()/2));
    x=min(x, barsdiagram->xsize()-labelimg->xsize());
      
    y=0; 
      
    if (label && sizeof(label))
      barsdiagram->paste_alpha_color(labelimg, 
				     @(diagram_data["labelcolor"]), 
				     x,
				     2+labely-labelimg->ysize());
  }

 
#ifdef BG_DEBUG
  };
#endif

  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=barsdiagram;

#ifdef BG_DEBUG
  diagram_data->bg_timers=bg_timers;
#endif
  return diagram_data;
}
