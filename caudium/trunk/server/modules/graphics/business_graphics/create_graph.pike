#!NOMODULE
/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
 * Copyright � 1994-2000 Roxen Internet Software
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

#if constant(Image.image)
#define OLDSTYLE
#define IMAGE Image.image
#define FONT Image.font
#else
#define IMAGE Image.Image
#define FONT Image.Font
#endif
import Array;
import Stdio;

inherit "polyline.pike";

constant cvs_version = "$Id$";

/*
 * name = "BG: Create graphs";
 * doc = "Business Graphics sub-module for drawing graphs.";
 */

/*
These functions were written by Henrik "Hedda" Wallin (hedda@idonex.se)
Create_graph draws a graph but there are also some other functions
used by create_pie and create_bars.
*/ 

#define GETFONT(WHATFONT) notext=resolve_font(diagram_data->WHATFONT||diagram_data->font);



//Denna funktion ritar text-bilderna, initierar max, fixar till bk-bilder
//och allt annat som �r gemensamt f�r alla sorters diagram.
//Denna funktion anropas i create_XXX.


object tileimage(object img, int xs, int ys)
{
  //written by js@idonex.se

  object dest=IMAGE(xs,ys);
  int srcx=img->xsize();
  int srcy=img->ysize();
  if(srcx <= 0 || srcy <= 0)
    return dest;
  
  for(int x=0; x<=xs; x+=srcx)
    for(int y=0; y<=ys; y+=srcy)
      dest->paste(img,x,y);

  return dest;
}

//Key word eng:
//This function writes a float like on an engineer-format
string diagram_eng(float a)
{
  string foo="";
  if (a<0.0)
  {
    foo="-";
    a=-a;
  }
  array(string) pfix = ({ "a", "f", "p", "n", "�", "m", "",
			  "k", "M", "G", "T", "P", "E" });
  if (a == 0.0) return "0";
  float p = log(a)/log(1000.0);
  if (p < -6.0) p = 0.0;
  if (p >= 7.0) p = 0.0;
  int i = (int) floor(p+0.000001);
  string s;
  sscanf(sprintf("%g%s", a*exp(-i*log(1000.0)), pfix[6+i]), "%*[ ]%s", s);
  return foo+s;
}

//Key word neng:
//This function writes a float like on an engineer-format
//Exept for 0.1<a<1.0 
string diagram_neng(float a)
{
  string foo="";
  if (a<0.0)
  {
    foo="-";
    a=-a;
  }
  array(string) pfix;
  pfix = ({ "a", "f", "p", "n", "�", "m", "",
	    "k", "M", "G", "T", "P", "E" });
  if (a == 0.0) return "0";
  float p = log(a)/log(1000.0);
  if (p < -6.0) p = 0.0;
  if (p >= 7.0) p = 0.0;
  int i = (int) floor(p+0.000001);
  if ((a<1.0)&&(a>=0.0999999))
    i=0;
  string s; 
  sscanf(sprintf("%g%s", a*exp(-i*log(1000.0)), pfix[6+i]), "%*[ ]%s", s);
  return foo+s;
}

void draw(object(IMAGE) img, float h, array(float|string) coords,
	  void|int|float zerolength)
{
  if ((sizeof(coords)==2)||
      (sizeof(coords)==3))
  {
    array(float) foo=({(float)coords[0]-(float)zerolength,
		       (float)coords[1],
		       (float)coords[0]+(float)zerolength,
		       (float)coords[1]
    });
    img->polygone(make_polygon_from_line(h, foo,1, 1)[0]);
  }
  else
    for(int i=0; i<sizeof(coords)-3; i+=2)
    {
      if (coords[i]!=VOIDSYMBOL)
	if (coords[i+2]!=VOIDSYMBOL)
	  img->polygone( make_polygon_from_line(h, coords[i..i+3], 1, 1)[0] );
	  else
	    if ( ((i>0)&&(coords[i-2]==VOIDSYMBOL))||(i==0) )
	      img->polygone( make_polygon_from_line(h, coords[i..i+1],
						    1, 1)[0] );
      }
}

mapping(string:mixed) setinitcolors(mapping(string:mixed) diagram_data)
{
  //diagram_data["datasize"]=0;
  foreach(diagram_data["data"], mixed* fo)
    if (sizeof(fo)>diagram_data["datasize"])
      diagram_data["datasize"]=sizeof(fo);
  
  if (diagram_data["type"]=="sumbars")
    for(int i; i<sizeof(diagram_data["data"]); i++)
      diagram_data["data"][i]=diagram_data["data"][i]+
	allocate(diagram_data["datasize"]-sizeof(diagram_data["data"][i]));


  if ((diagram_data["type"]=="sumbars")||
      (diagram_data["type"]=="bars"))
    if (diagram_data["xdatanames"])
      if (sizeof(diagram_data["datasize"])<
	  sizeof(diagram_data["xdatanames"]))
	diagram_data["xdatanames"]=diagram_data["xdatanames"]
	  [..sizeof(diagram_data["datasize"])-1];
  


  object piediagram=diagram_data["image"];
  


  /*  if (diagram_data["xnames"]!=0)
    if (sizeof(diagram_data["xnames"])!=sizeof(diagram_data["data"][0]))
    diagram_data["xnames"]=0;*/
  if (diagram_data["datacolors"])
  {
    int cnum;
    if (diagram_data["type"]=="pie")
      cnum=diagram_data["datasize"];
    else
      cnum=sizeof(diagram_data["data"]);
    if (sizeof(diagram_data["datacolors"])<cnum)
      diagram_data["datacolors"]=0;
    else
      foreach(diagram_data["datacolors"], mixed color)
	if (sizeof(color)!=3)
	  diagram_data["datacolors"]=0;
  }

  if (!(diagram_data["datacolors"]))
  {
    int numbers;
    if (diagram_data["type"]=="pie")
      numbers=diagram_data["datasize"];
    else
      numbers=sizeof(diagram_data["data"]);
    
    int** carr=allocate(numbers);
    int steg=128+128/(numbers);

    switch( numbers ) {
     case 1:
       carr=({({19,200,102})});
       break;
     case 2:
       carr=({({190, 180, 0}), ({19, 19, 200})});
       break;
     case 3:
       carr=({({200, 19, 19}), ({19, 19, 200}), ({42, 200, 19})});
       break;
     case 4:
       carr=({({200, 19, 19}), ({19, 66, 200}), ({180, 180, 0}), ({19, 220, 102})});
       break;
     case 5:
       carr= ({({200, 19, 19}), ({19, 85, 200}), ({180, 180, 0}), ({129, 19, 200}), ({19, 200, 80})});
       break;
     case 6:
       carr= ({({200, 19, 19}), ({19, 85, 200}), ({180, 180, 0}), ({74, 220, 19}), ({100, 19, 200}), ({19, 200, 102})});
       break;
     case 7:
       carr= ({({200, 19, 19}), ({19, 85, 200}), ({180, 180, 0}), ({72, 19, 200}), ({74, 200, 19}), ({200, 19, 140}), ({19, 200, 102})});
       break;
     case 8:
       carr=({({200, 19, 19}), ({19, 110, 200}), ({180, 180, 0}), ({55, 19, 200}), ({96, 220, 19}), ({142, 19, 200}), ({19, 220, 69}), ({80, 19, 200})}) ;
       break;
     case 9:
       carr= ({({200, 19, 19}), ({19, 115, 200}), ({200, 115, 19}), ({19, 19, 200}), ({118, 200, 19}), ({115, 19, 200}), ({42, 220, 19}), ({200, 19, 118}), ({19, 200, 112})});
       break;
     case 10:
       carr=({({200, 19, 19}), ({19, 121, 200}), ({200, 104, 19}), ({19, 55, 200}), ({140, 200, 19}), ({88, 19, 200}), ({74, 220, 19}), ({130, 24, 130}), ({19, 220, 69}), ({180, 180, 0})}) ;
       break;
     case 11:
       carr=({({200, 19, 19}), ({19, 123, 200}), ({200, 99, 19}), ({19, 63, 200}), ({150, 200, 19}), ({74, 19, 200}), ({91, 220, 19}), ({134, 19, 200}), ({19, 200, 47}), ({200, 19, 115}), ({19, 200, 107})}) ;
       break;
     case 12:
       carr=({({200, 19, 19}), ({19, 126, 200}), ({200, 93, 19}), ({19, 72, 200}), ({200, 148, 19}), ({61, 19, 200}), ({107, 200, 19}), ({115, 19, 200}), ({53, 220, 19}), ({200, 109, 140}), ({19, 220, 80}), ({200, 19, 185})}) ;
       break;
     default:
	  //No colours given!
	  //Now we have the %-numbers in pnumbers
	  //Lets create a colourarray carr
	  for(int i=0; i<numbers; i++)
	      carr[i]=Colors.hsv_to_rgb((i*steg)%256,190,200);
    }

    if (diagram_data["bw"])
      for(int i=0; i<numbers; i++)
	carr[i]=({ (i*steg)%256,
		   (i*steg)%256, 
		   (i*steg)%256 });
      
      diagram_data["datacolors"]=carr;
    }

  diagram_data["image"]=piediagram;
  return diagram_data["image"];
}



mapping(string:mixed) init(mapping(string:mixed) diagram_data)
{
  float xminvalue=0.0, xmaxvalue=-STORT, yminvalue=0.0, ymaxvalue=-STORT;
  
  if (diagram_data["xmin"])
    xminvalue=STORT;
  if (diagram_data["ymin"])
    yminvalue=STORT;
  
  if (diagram_data["labelcolor"]==0)
    diagram_data["labelcolor"]=diagram_data["textcolor"];
  if (diagram_data["labelcolor"] && sizeof(diagram_data["labelcolor"])!=3)
    diagram_data["labelcolor"]=diagram_data["textcolor"];
  diagram_data["linewidth"]=(float)diagram_data["linewidth"];
  if ( diagram_data["linewidth"]< 0.01)
     diagram_data["linewidth"]=1.0;

  //Oulinecolors
  if ((diagram_data["backdatacolors"]==0)&&
      (diagram_data["backlinewidth"]))
  {
    int dcs=sizeof(diagram_data["datacolors"]);
    diagram_data["backdatacolors"]=allocate(dcs);
    for(int i=0; i<dcs; i++)
      diagram_data["backdatacolors"][i]=({255-diagram_data["datacolors"][i][0],
					  255-diagram_data["datacolors"][i][1],
					  255-diagram_data["datacolors"][i][2]
      });
      
    }
  //diagram_data["backlinewidth"]=diagram_data["linewidth"]+1.0;
  
  if (!(diagram_data["legendcolor"]))
    diagram_data["legendcolor"]=diagram_data["bgcolor"];
  
  if (diagram_data["type"]=="graph")
    diagram_data["subtype"]="line";
  
  if (diagram_data["type"]=="bars")
    diagram_data["xminvalue"]=0;

  if (diagram_data["type"]=="sumbars")
  {
    diagram_data["xminvalue"]=0;
    if (diagram_data["subtype"]=="norm")
    {
      diagram_data["yminvalue"]=0;
      if (!(diagram_data["labels"]))
	diagram_data["labels"]=({"", "%", "", ""});
    }
  }
  if ((diagram_data["subtype"]==0) ||
      (diagram_data["subtype"]==""))
    diagram_data["subtype"]="line";

  if (diagram_data["subtype"]=="line")
    if ((!(diagram_data["drawtype"])) ||
	(diagram_data["drawtype"]==""))
      diagram_data["drawtype"]="linear";

  if (diagram_data["subtype"]=="box")
    if ((!(diagram_data["drawtype"])) ||
	(diagram_data["drawtype"]==""))
      diagram_data["drawtype"]="2D";

  if (diagram_data["type"]=="sumbars")
  {
    diagram_data["data"]=Array.map(diagram_data["data"], replace,
				   VOIDSYMBOL, 0.0);
    
    int j=sizeof(diagram_data["data"]);
    float k;
    if (diagram_data["subtype"]=="norm")
    {
      int j2=diagram_data["datasize"];
      for(int i=0; i<j2; i++)
      {
	k=`+(@column(diagram_data["data"], i));
	if (k<LITET)
	  k=LITET;
	else
	  k=100.0/k;
	for(int i2=0; i2<j; i2++)
	  diagram_data["data"][i2][i]*=k;
      }
      yminvalue=0.0;
      ymaxvalue=100.0;
      
    }
    else
      for(int i=0; i<diagram_data["datasize"]; i++)
      {
	if (yminvalue>(k=`+(@column(diagram_data["data"], i))))
	  yminvalue=k;
	if (ymaxvalue<(k))
	  ymaxvalue=k;
      }
    xminvalue=0.0;
    xmaxvalue=10.0;
      
  }
  else
    foreach(diagram_data["data"], array(float|string) d)
    {
      int j=sizeof(d);
	
      if (diagram_data["type"]=="graph")
      {
	d-=({VOIDSYMBOL});
	j=sizeof(d)-1;
	for(int i=0; i<j; i++)
	{
	  float k;
	  if (xminvalue>(k=d[i]))
	    xminvalue=k;
	  if (xmaxvalue<(k))
	    xmaxvalue=k;
	  if (yminvalue>(k=d[++i]))
	    yminvalue=k;
	  if (ymaxvalue<(k))
	    ymaxvalue=k;
	}
      }
      else
	if (diagram_data["type"]=="bars")
	{
	  for(int i; i<j; i++)
	    if (floatp(d[i]))
	    {
	      float k; 
	      if (yminvalue>(k=d[i]))
		yminvalue=k;
	      if (ymaxvalue<(k))
		ymaxvalue=k;
	    }
	  xminvalue=0.0;
	  xmaxvalue=10.0;
	}
	else
	  if (diagram_data["type"]=="pie")
	  {
	    for(int i; i<j; i++)
	    {
	      if (!floatp(d[i]))
		d[i]=0;
	      
	      float k; 
	      if (yminvalue>(k=d[i]))
		yminvalue=k;
	      if (ymaxvalue<(k))
		ymaxvalue=k;
	    }
	    xminvalue=0.0;
	    xmaxvalue=10.0;
	  }
	  else
	    throw( ({"\""+diagram_data["type"]
		     + "\" is an unknown graph type!\n", backtrace()}));
    }

  if (diagram_data["type"]=="sumbars")
    diagram_data["box"]=0;

  if (diagram_data["type"]=="pie")
  {
    diagram_data["vertgrid"]=0;
    diagram_data["horgrid"]=0;
  }

  xmaxvalue=max(xmaxvalue, xminvalue+STORTLITET);
  ymaxvalue=max(ymaxvalue, yminvalue+STORTLITET);


  if (!(diagram_data["xminvalue"]))
    diagram_data["xminvalue"]=xminvalue;
  if ((!(diagram_data["xmaxvalue"])) ||
      (diagram_data["xmaxvalue"]<xmaxvalue))
    if (xmaxvalue<0.0)
      diagram_data["xmaxvalue"]=0.0;
    else
      diagram_data["xmaxvalue"]=xmaxvalue;
  if (!(diagram_data["yminvalue"]))
    diagram_data["yminvalue"]=yminvalue;
  if ((!(diagram_data["ymaxvalue"])) ||
      (diagram_data["ymaxvalue"]<ymaxvalue))
    if (ymaxvalue<0.0)
      diagram_data["ymaxvalue"]=0.0;
    else
      diagram_data["ymaxvalue"]=ymaxvalue;

  //Ge tomma namn p� xnames om namnen inte finns
  //Och ge bars max och minv�rde p� x-axeln.
  if ((diagram_data["type"]=="bars")||(diagram_data["type"]=="sumbars"))
  {
    if (!(diagram_data["xnames"]))
      diagram_data["xnames"]=allocate(diagram_data["datasize"]);
  }

  //Om xnames finns s� s�tt xspace om inte values_for_xnames finns
  if (diagram_data["xnames"] && sizeof(diagram_data["xnames"])==0)
    diagram_data["xnames"]=0;
  if (diagram_data["type"]!="graph")
    if (diagram_data["xnames"])
      diagram_data["xspace"]=max((diagram_data["xmaxvalue"]-
				  diagram_data["xminvalue"])
				 /(float)(max(sizeof(diagram_data["xnames"]), 
					      diagram_data["datasize"])),
				 LITET*20);
  
  //Om ynames finns s� s�tt yspace.
  if (diagram_data["ynames"])
  {
    diagram_data["ynames"]=({" "})+diagram_data["ynames"];
    diagram_data["yspace"]=(diagram_data["ymaxvalue"]-
			    diagram_data["yminvalue"])
      /(float)sizeof(diagram_data["ynames"]);
  }
  //Check if labelsize is to big:
  if (diagram_data["labelsize"]>diagram_data["ysize"]/5)
    diagram_data["labelsize"]=diagram_data["ysize"]/5;
  
  return diagram_data;
};

#ifndef CAUDIUM
object get_font(string j, int p, int t, int h, string fdg, int s, int hd)
{
  return FONT()->load("avant_garde");
};
#endif

//rita bilderna f�r texten
//ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
mapping(string:mixed) create_text(mapping(string:mixed) diagram_data)
{
  object notext;
  int tobig=1;
  int xmaxynames=0, ymaxynames=0, xmaxxnames=0, ymaxxnames=0;
  int r=0;
  while(tobig)
  {
    r++;
    if (r>9)
      throw( ({"Very bad error while trying to resize the textfont!\n",
	       backtrace()}));
      
    GETFONT(xnamesfont);
    int j;
    diagram_data["xnamesimg"]=allocate(j=sizeof(diagram_data["xnames"]));
    for(int i=0; i<j; i++)
    {
      if ( ((diagram_data["values_for_xnames"][i]>LITET)
	    || (diagram_data["values_for_xnames"][i]<-LITET))
	   && ((diagram_data["xnames"][i])
	       && sizeof(diagram_data["xnames"][i])))
	diagram_data["xnamesimg"][i]=notext->write(diagram_data["xnames"][i])
	  -> scale(0,diagram_data["fontsize"]);
      else
	diagram_data["xnamesimg"][i]=
	  IMAGE(diagram_data["fontsize"],diagram_data["fontsize"]);
      
      if (diagram_data["xnamesimg"][i]->xsize()<1)
	diagram_data["xnamesimg"][i]=IMAGE(diagram_data["fontsize"],
					   diagram_data["fontsize"]);
    }
      
    GETFONT(ynamesfont);

    diagram_data["ynamesimg"]=allocate(j=sizeof(diagram_data["ynames"]));
    if ((diagram_data["type"]=="bars")||
	(diagram_data["type"]=="sumbars"))
      for(int i=0; i<j; i++)
      {
	if ((diagram_data["ynames"][i]) && (sizeof(diagram_data["ynames"][i])))
	{
	  if (diagram_data["ynames"][i]=="-0")
	    diagram_data["ynames"][i]="0";
	  diagram_data["ynamesimg"][i]=notext->write(diagram_data["ynames"][i])
	    ->scale(0,diagram_data["fontsize"]);
	}
	else
	  diagram_data["ynamesimg"][i]=
	    IMAGE(diagram_data["fontsize"],diagram_data["fontsize"]);
	
	if (diagram_data["ynamesimg"][i]->xsize()<1)
	  diagram_data["ynamesimg"][i]=IMAGE(diagram_data["fontsize"],
					     diagram_data["fontsize"]);
      }
    else
      for(int i=0; i<j; i++)
      {
	if (((diagram_data["values_for_ynames"][i]>LITET)
	     || (diagram_data["values_for_ynames"][i]<-LITET))
	    && ((diagram_data["ynames"][i])
		&& (sizeof(diagram_data["ynames"][i]))))
	  diagram_data["ynamesimg"][i]=notext->write(diagram_data["ynames"][i])
	    ->scale(0,diagram_data["fontsize"]);
	else
	  diagram_data["ynamesimg"][i]=
	    IMAGE(diagram_data["fontsize"],diagram_data["fontsize"]);
	
	if (diagram_data["ynamesimg"][i]->xsize()<1)
	  diagram_data["ynamesimg"][i]=IMAGE(diagram_data["fontsize"],
					     diagram_data["fontsize"]);
      }
      
      if (diagram_data["orient"]=="vert")
	for(int i; i<sizeof(diagram_data["xnamesimg"]); i++)
	  diagram_data["xnamesimg"][i]=diagram_data["xnamesimg"][i]
	    ->rotate_ccw();
      
      
      xmaxynames=0, ymaxynames=0, xmaxxnames=0, ymaxxnames=0;
      
      foreach(diagram_data["xnamesimg"], object img)
	if (img->ysize()>ymaxxnames) 
	  ymaxxnames=img->ysize();
      
      foreach(diagram_data["xnamesimg"], object img)
	if (img->xsize()>xmaxxnames) 
	  xmaxxnames=img->xsize();
      
      foreach(diagram_data["ynamesimg"], object img)
	if (img->ysize()>ymaxynames) 
	  ymaxynames=img->ysize();
      
      foreach(diagram_data["ynamesimg"], object img)
	if (img->xsize()>xmaxynames) 
	  xmaxynames=img->xsize();
      
      diagram_data["ymaxxnames"]=ymaxxnames;
      diagram_data["xmaxxnames"]=xmaxxnames;
      diagram_data["ymaxynames"]=ymaxynames;
      diagram_data["xmaxynames"]=xmaxynames;
      
      if (ymaxxnames+xmaxynames>diagram_data["ysize"]/2)
      {
	tobig+=2;
	diagram_data["fontsize"]=diagram_data["fontsize"]
	  * diagram_data["ysize"]/2/(ymaxxnames+xmaxynames);
      }
      
      if (ymaxynames>diagram_data["ysize"]/3)
      {
	tobig+=2;
	diagram_data["fontsize"]=diagram_data["fontsize"]
	  * diagram_data["ysize"]/3/ymaxynames;
      }
      
      if (xmaxynames>diagram_data["xsize"]/2)
      {
	tobig+=2;
	diagram_data["fontsize"]=diagram_data["fontsize"]
	  * diagram_data["xsize"]/2/xmaxynames;
      }
      
      if (xmaxxnames>diagram_data["xsize"]/3)
      {
	tobig+=2;
	diagram_data["fontsize"]=diagram_data["fontsize"]
	  * diagram_data["xsize"]/3/xmaxxnames;
      }
      
      if (tobig==1)
	tobig=0;
      else
	tobig--;
      
  } 
}

string no_end_zeros(string f)
{
  if (search(f, ".")!=-1)
  {
    int j;
    /* FIXME  Vad i Hvte g�r du h�r?! */
    //Jag vet vad jag g�r! Idi! :-)
    for(j=sizeof(f)-1; f[j]=='0'; j--)
    {}
    if (f[j]=='.')
      return f[..--j];
    else
      return f[..j];
  }
  return f;
}


//Denna funktion ritar ut griden i bilden.
mapping draw_grid(mapping diagram_data, int|float xpos_for_yaxis,
		   int|float ypos_for_xaxis, float xmore, float ymore, 
		   float xstart, float ystart, float si)
{
  //Placera ut vert griden
  int s=sizeof(diagram_data["xnames"]);
  object graph=diagram_data["image"];
  if (!diagram_data["gridwidth"])
    diagram_data["gridwidth"]=diagram_data["linewidth"]/4.0;

  graph->setcolor(@diagram_data["gridcolor"]);
  float gw=(float)diagram_data["gridwidth"];
  if ((diagram_data["vertgrid"])&&
      (gw>LITET))
    {
      mixed vfx=diagram_data["values_for_xnames"];
      float ystop=(float)(diagram_data["ysize"]-diagram_data["ystop"]);
      float ystart=(float)(diagram_data["ysize"]-ystart);
      float gw2=gw/2.0;
      float xmin=(float)diagram_data["xminvalue"];
      float xmax=(float)diagram_data["xmaxvalue"];
      for(int i=0; i<s; i++)
	if ((vfx[i]>xmin)&&
	    (vfx[i]<xmax))
	  {
	    float temp;
	    graph->
	      polygone(({ 
		(temp=(vfx[i]- diagram_data["xminvalue"])* xmore+xstart)-gw2,
		ystart,
		
		temp+gw2,
		ystart,

		temp+gw2,
		ystop,

		temp-gw2,
		  ystop}));
	    /*
	    make_polygon_from_line(
					      gw,
					      ({
						((diagram_data["values_for_xnames"][i]
						  - diagram_data["xminvalue"])
						 * xmore+xstart),
						diagram_data["ysize"]-ystart,
						
						((diagram_data["values_for_xnames"][i]
						  - diagram_data["xminvalue"])
						 * xmore+xstart),
						diagram_data["ysize"]
						- diagram_data["ystop"]
					      }), 
					      1, 1)[0]);
	    */
      }
    }
  //Placera ut horgriden
  s=sizeof(diagram_data["values_for_ynames"]);
  if ((diagram_data["horgrid"])
      && (gw>LITET))
    for(int i=0; i<s; i++)
      if ((diagram_data["values_for_ynames"][i]>diagram_data["yminvalue"])&&
	  (diagram_data["values_for_ynames"][i]<diagram_data["ymaxvalue"]))
      {
	graph->
	  polygone(make_polygon_from_line(
		     gw,
		     ({
		       xstart,
		       (-(diagram_data["values_for_ynames"][i]-
			  diagram_data["yminvalue"])
			*ymore+diagram_data["ysize"]-ystart),
		       
		       diagram_data["xstop"],
		       (-(diagram_data["values_for_ynames"][i]-
			  diagram_data["yminvalue"])
			*ymore+diagram_data["ysize"]-
			ystart)
		     }), 
		     1, 1)[0]);
      }
}

//Denna funktion skriver ocks� ut infon i Legenden
mapping set_legend_size(mapping diagram_data)
{
  if (!(diagram_data["legendfontsize"]))
    diagram_data["legendfontsize"]=diagram_data["fontsize"];
  int raws;
  //Check if the font is to big:
  
  int tobig=1;
  int j=0;
  int xmax=0, ymax=0;
  int b;
  int columnnr;
  array(object(IMAGE)) texts;
  array(mixed) plupps; //Det som ska ritas ut f�re texterna
  object notext;


  if (diagram_data["legend_texts"])
  {
    if (sizeof(diagram_data["legend_texts"])>
	sizeof(diagram_data["datacolors"]))
      diagram_data["legend_texts"]=diagram_data["legend_texts"]
	[..sizeof(diagram_data["datacolors"])-1];
    
    int r=0;
    while(tobig)
    {
      r++;
      if (r>3)
	throw( ({"Very bad error while trying to resize the legendfonts!\n",
		 backtrace()}));
      {
	texts=allocate(sizeof(diagram_data["legend_texts"]));
	plupps=allocate(sizeof(diagram_data["legend_texts"]));
	
	GETFONT(legendfont);
	
	j=sizeof(texts);
	if (!diagram_data["legendcolor"])
	  diagram_data["legendcolor"]=diagram_data["bgcolor"];
	for(int i=0; i<j; i++)
	{
	  if (diagram_data["legend_texts"][i]
	      && (sizeof(diagram_data["legend_texts"][i])))
	    texts[i]=notext->write(diagram_data["legend_texts"][i])
	      ->scale(0,diagram_data["legendfontsize"]);
	  else
	    texts[i]=
	      IMAGE(diagram_data["legendfontsize"],
		    diagram_data["legendfontsize"]);
		
	  if (texts[i]->xsize()<1)
	    texts[i]=IMAGE(diagram_data["legendfontsize"],
			   diagram_data["legendfontsize"]);
	}
	    
	xmax=0, ymax=0;
	
	foreach(texts, object img)
	  if (img->ysize()>ymax) 
	    ymax=img->ysize();

	foreach(texts, object img)
	  if (img->xsize()>xmax) 
	    xmax=img->xsize(); 
	  
	//Skapa strecket f�r graph/boxen f�r bars.
	if ((diagram_data["type"]=="graph") ||
	    (diagram_data["type"]=="bars") ||
	    (diagram_data["type"]=="sumbars") ||
	    (diagram_data["type"]=="pie"))
	  for(int i=0; i<j; i++)
	  {
	    plupps[i]=IMAGE(diagram_data["legendfontsize"],
			    diagram_data["legendfontsize"]);
		
	    plupps[i]->setcolor(255,255,255);
	    if ( (diagram_data["linewidth"]*1.5
		  < (float)diagram_data["legendfontsize"])
		 && (diagram_data["subtype"]=="line")
		 && (diagram_data["drawtype"]!="level") )
	      plupps[i]->polygone(make_polygon_from_line(
				   diagram_data["linewidth"], 
				   ({
				     (float)(diagram_data["linewidth"]/2+1),
				     (float)(plupps[i]->ysize()-
					     diagram_data["linewidth"]/2-2),
				     (float)(plupps[i]->xsize()-
					     diagram_data["linewidth"]/2-2),
				     (float)(diagram_data["linewidth"]/2+1)
				   }), 
				   1, 1)[0]);
	    else
	      plupps[i]->box( 1, 1, plupps[i]->xsize()-2,
			      plupps[i]->ysize()-2 );
	  }
	else
	  throw( ({"\""+diagram_data["type"]+"\" is an unknown graph type!\n",
		   backtrace()}));
	  
	//Ta redap� hur m�nga kolumner vi kan ha:
	b;
	columnnr=(diagram_data["image"]->xsize()-4)/
	  (b=xmax+2*diagram_data["legendfontsize"]);
	  
	if (columnnr==0)
	{
	  int m=((diagram_data["image"]->xsize()-4)-2*diagram_data["legendfontsize"]);
	  if (m<4) m=4;
	  for(int i=0; i<sizeof(texts); i++)
	    if (texts[i]->xsize()>m)
	    {
	      texts[i]=
		texts[i]->scale((int)m,0);
	      //write("x: "+texts[i]->xsize()+"\n");
	      //write("y: "+texts[i]->ysize()+"\n");
	    }
	  columnnr=1;
	}
	
	raws=(j+columnnr-1)/columnnr;
	diagram_data["legend_size"]=raws*diagram_data["legendfontsize"];
	
	
	if (diagram_data["image"]->ysize()/2>=raws
	    * diagram_data["legendfontsize"])
	  tobig=0;
	else
	{
	  tobig++;
	  if (tobig==2)
	    diagram_data["legendfontsize"]=diagram_data["image"]->ysize()/raws;
	  else
	    diagram_data["legendfontsize"]=diagram_data["image"]
	      -> ysize()/2/raws;
	}
      }
      
    }
  }
  //placera ut bilder och text.
  
  if (diagram_data["legend_texts"])
  {
    for(int i=0; i<j; i++)
    {
      diagram_data["image"]
	->paste_alpha_color(plupps[i], 
			    @(diagram_data["datacolors"][i]), 
			    (i/raws)*b,
			    (i%raws)*diagram_data["legendfontsize"]
			    +diagram_data["image"]
			    ->ysize()-diagram_data["legend_size"] );
      diagram_data["image"]->setcolor(0,0,0);
      draw( diagram_data["image"], 0.5,
	    ({(i/raws)*b, (i%raws)*diagram_data["legendfontsize"]+
	      diagram_data["image"]->ysize()-diagram_data["legend_size"]+1,
	      (i/raws)*b+plupps[i]->xsize()-1.0,
	      (i%raws)*diagram_data["legendfontsize"]
	      + diagram_data["image"]->ysize()-diagram_data["legend_size"]+1, 
	      (i/raws)*b+plupps[i]->xsize()-1.0,
	      (i%raws)*diagram_data["legendfontsize"]
	      + diagram_data["image"]->ysize()-diagram_data["legend_size"]
	      + plupps[i]->ysize()-1,
	      (i/raws)*b+1,
	      (i%raws)*diagram_data["legendfontsize"] + diagram_data["image"]
	      -> ysize()-diagram_data["legend_size"]+plupps[i]->ysize()-1,
	      (i/raws)*b, (i%raws)*diagram_data["legendfontsize"]
	      + diagram_data["image"]->ysize()-diagram_data["legend_size"]+1
	    })); 
      
      
      diagram_data["image"]
	->paste_alpha_color(texts[i], 
			    @(diagram_data["textcolor"]), 
			    (i/raws)*b+1+diagram_data["legendfontsize"],
			    (i%raws)*diagram_data["legendfontsize"]+
			    diagram_data["image"]->ysize()
			    - diagram_data["legend_size"] );
    }
  }
  else
    diagram_data["legend_size"]=0;
}

mapping(string:mixed) init_bg(mapping diagram_data)
{
  if (diagram_data["bgcolor"])
    diagram_data["image"]=IMAGE(diagram_data["xsize"],diagram_data["ysize"],
				@(diagram_data["bgcolor"]));
  else
    if ((diagram_data["xsize"]==0)||(0==diagram_data["ysize"]))
    {
      diagram_data["xsize"]=diagram_data["image"]->xsize();
      diagram_data["ysize"]=diagram_data["image"]->ysize();
    }
    else
      if (diagram_data["image"]&&(diagram_data["image"]->xsize()>4)&&
	  (diagram_data["image"]->ysize()>4))
	diagram_data["image"]=tileimage(diagram_data["image"], 
					diagram_data["xsize"], 
					diagram_data["ysize"]);
      else
	diagram_data["image"]=IMAGE(diagram_data["xsize"],
				    diagram_data["ysize"],
				    255,255,255);
}

int write_name(mapping diagram_data)
{
  object notext;
  if (!diagram_data["name"])
    return 0;
  GETFONT(namefont);

  object text;
  int y,x;
  if (diagram_data["namesize"])
    y=diagram_data["namesize"];
  else
    y=diagram_data["fontsize"];
  
  text=notext->write(diagram_data["name"])->scale(0,y);
  
  if (text->xsize()>=diagram_data["xsize"])
    text->scale(diagram_data["xsize"]-1,0);
  
  array color;
  if (diagram_data["namecolor"])
    color=diagram_data["namecolor"];
  else
    color=diagram_data["textcolor"];
  

  diagram_data["image"]
    -> paste_alpha_color( text, @(color),
			  diagram_data["xsize"]/2-text->xsize()/2, 2 );
	  
  return text->ysize()+2;
}

mapping(string:mixed) create_graph(mapping diagram_data)
{
  //Supportar bara xsize>=100
  int si=diagram_data["fontsize"];
  object notext;  
  string where_is_ax;
  
  //No uneven data
  
  for(int i=0; i<sizeof(diagram_data["data"]); i++)
    if (sizeof(diagram_data["data"][i])%2)
      diagram_data["data"][i]
	= diagram_data["data"][i][..sizeof(diagram_data["data"][i])-2];

  //Fixa defaultf�rger!
  setinitcolors(diagram_data);

  object(IMAGE) graph;
  init_bg(diagram_data);
  graph=diagram_data["image"];

  set_legend_size(diagram_data);

  diagram_data["ysize"]-=diagram_data["legend_size"];
  
  //Best�m st�rsta och minsta datav�rden.
  init(diagram_data);

  //Ta reda hur m�nga och hur stora textmassor vi ska skriva ut
  if (!(diagram_data["xspace"]))
    if (diagram_data["xnames"])
    {
      diagram_data["xnames"]=({" "})+diagram_data["xnames"];
      diagram_data["xspace"]=(diagram_data["xmaxvalue"]
			      - diagram_data["xminvalue"])/
	(LITET+sizeof(diagram_data["xnames"]));
    }
    else
      {
	//Initera hur l�ngt det ska vara emellan.
	float range=(diagram_data["xmaxvalue"]
		     - diagram_data["xminvalue"]);
	if ((range>-LITET)&&
	    (range<LITET))
	  range=LITET*10.0;
	
	float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
	if ( range/space > 5.0 )
	{
	  if(range/(2.0*space)>5.0)
	    space *= 5.0;
	  else
	    space *= 2.0;
	}
	else
	  if (range/space<2.5)
	    space *= 0.5;
	diagram_data["xspace"]=space;
      }
  if (!(diagram_data["yspace"]))
  {
    //Initera hur l�ngt det ska vara emellan.
      
    float range=(diagram_data["ymaxvalue"]
		 - diagram_data["yminvalue"]);
    if ((range>-LITET)&&
	(range<LITET))
      range=LITET*10.0;

    float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
    if (range/space>5.0)
      if(range/(2.0*space)>5.0)
	space *= 5.0;
      else
	space *= 2.0;
    else
      if (range/space<2.5)
	space *= 0.5;
    diagram_data["yspace"]=space;      
  }
 
  if (!(diagram_data["values_for_xnames"]))
  {
    if ((diagram_data["xspace"]<LITET)&&
	(diagram_data["xspace"]>-LITET))
      throw( ({"Very bad error because xspace is zero!\n", backtrace()}));
    float start;
    start=diagram_data["xminvalue"];
    start=diagram_data["xspace"]*ceil((start)/diagram_data["xspace"]);
    diagram_data["values_for_xnames"]=({start});
    while(diagram_data["values_for_xnames"][-1]
	  <= diagram_data["xmaxvalue"]-diagram_data["xspace"])
      diagram_data["values_for_xnames"]+=({start+=diagram_data["xspace"]});
  }
  if (!(diagram_data["values_for_ynames"]))
  {
    if ((diagram_data["yspace"]<LITET)&&
	(diagram_data["yspace"]>-LITET))
      throw( ({"Very bad error because yspace is zero!\n", backtrace()}));
    
    float start;
    start=diagram_data["yminvalue"];
    start=diagram_data["yspace"]*ceil((start)/diagram_data["yspace"]);
    diagram_data["values_for_ynames"]=({start});
    while(diagram_data["values_for_ynames"][-1]
	  <= diagram_data["ymaxvalue"]-diagram_data["yspace"])
      diagram_data["values_for_ynames"]+=({start+=diagram_data["yspace"]});
  }
  
  //Generate the texten if it doesn't exist
  if (!(diagram_data["ynames"]))
    if (diagram_data["eng"])
      {
	diagram_data["ynames"]=
	  allocate(sizeof(diagram_data["values_for_ynames"]));
	
	for(int i=0; i<sizeof(diagram_data["values_for_ynames"]); i++)
	  diagram_data["ynames"][i]=
	    diagram_eng((float)(diagram_data["values_for_ynames"][i]));
      } 
    else if (diagram_data["neng"])
      {
	diagram_data["ynames"]=
	  allocate(sizeof(diagram_data["values_for_ynames"]));
	
	for(int i=0; i<sizeof(diagram_data["values_for_ynames"]); i++)
	  diagram_data["ynames"][i]=
	    diagram_neng((float)(diagram_data["values_for_ynames"][i]));
      } else {
	diagram_data["ynames"]=
	  allocate(sizeof(diagram_data["values_for_ynames"]));
	
	for(int i=0; i<sizeof(diagram_data["values_for_ynames"]); i++)
	  diagram_data["ynames"][i]=
	    no_end_zeros((string)(diagram_data["values_for_ynames"][i]));
      }
  

    
  if (!(diagram_data["xnames"]))
    if (diagram_data["eng"])
    {
      diagram_data["xnames"]=
	allocate(sizeof(diagram_data["values_for_xnames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_xnames"]); i++)
	diagram_data["xnames"][i]=
	  diagram_eng((float)(diagram_data["values_for_xnames"][i]));
    }
    else if (diagram_data["neng"])
    {
      diagram_data["xnames"]=
	allocate(sizeof(diagram_data["values_for_xnames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_xnames"]); i++)
	diagram_data["xnames"][i]=
	  diagram_neng((float)(diagram_data["values_for_xnames"][i]));
    }
    else
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

  //Skapa labelstexten f�r xaxlen
  object labelimg;
  string label;
  int labelx=0;
  int labely=0;

  GETFONT(xaxisfont);

  if (diagram_data["labels"])
  {
    if (diagram_data["labels"][2] && sizeof(diagram_data["labels"][2]))
      label=diagram_data["labels"][0]+" ["+diagram_data["labels"][2]+"]"; //Xstorhet
    else
      label=diagram_data["labels"][0];
    if ((label!="")&&(label!=0))
      labelimg=notext
	-> write(label)->scale(0,diagram_data["labelsize"]);
    else
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);
      
    if (labelimg->xsize()<1)
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);

    if (labelimg->xsize()>
	diagram_data["xsize"]/2)
      labelimg=labelimg->scale(diagram_data["xsize"]/2,0);

    labely=diagram_data["labelsize"];
    labelx=labelimg->xsize();
  }
  
  labely+=write_name(diagram_data);

  int ypos_for_xaxis; //avst�nd NERIFR�N!
  int xpos_for_yaxis; //avst�nd fr�n h�ger
  //Best�m var i bilden vi f�r rita graf
  diagram_data["ystart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["ystop"]=diagram_data["ysize"]
    - (int)ceil((float)diagram_data["linewidth"]+si)-labely;
  if (((float)diagram_data["yminvalue"]>-LITET)&&
      ((float)diagram_data["yminvalue"]<LITET))
    diagram_data["yminvalue"]=0.0;
  
  if (diagram_data["yminvalue"]<0)
  {
    //placera ut x-axeln.
    //om detta inte funkar s� rita xaxeln l�ngst ner/l�ngst upp och r�kna om diagram_data["ystart"]
    ypos_for_xaxis=((-diagram_data["yminvalue"])*(diagram_data["ystop"]-diagram_data["ystart"]))/
      (diagram_data["ymaxvalue"]-diagram_data["yminvalue"])+diagram_data["ystart"];
      
    int minpos;
    minpos=max(labely, diagram_data["ymaxxnames"])+si/2;
    if (minpos>ypos_for_xaxis)
    {
      ypos_for_xaxis=minpos;
      diagram_data["ystart"]=ypos_for_xaxis+
	diagram_data["yminvalue"]*(diagram_data["ystop"]-ypos_for_xaxis)/
	(diagram_data["ymaxvalue"]);
    } else {
      int maxpos;
      maxpos=diagram_data["ysize"]-
	(int)ceil(diagram_data["linewidth"]+si*2)-
	labely;
      if (maxpos<ypos_for_xaxis)
      {
	ypos_for_xaxis=maxpos;
	diagram_data["ystop"]=ypos_for_xaxis+
	  diagram_data["ymaxvalue"]*(ypos_for_xaxis-diagram_data["ystart"])/
	  (0-diagram_data["yminvalue"]);
      }
    }
  }
  else
    if (diagram_data["yminvalue"]==0.0)
    {
      // s�tt x-axeln l�ngst ner och diagram_data["ystart"] p� samma st�lle.
      diagram_data["ystop"]=diagram_data["ysize"]-
	(int)ceil(diagram_data["linewidth"]+si)-labely;
      ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si/2;
      diagram_data["ystart"]=ypos_for_xaxis;
    }
    else
    {
      //s�tt x-axeln l�ngst ner och diagram_data["ystart"] en aning h�gre
      diagram_data["ystop"]=diagram_data["ysize"]-
	(int)ceil(diagram_data["linewidth"]+si)-labely;
      ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si/2;
      diagram_data["ystart"]=ypos_for_xaxis+si*2;
    }
  
  //xpos_for_yaxis=diagram_data["xmaxynames"]+
  // si;
  
  //Best�m positionen f�r y-axeln
  diagram_data["xstart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["xstop"]=diagram_data["xsize"]-
    (int)ceil(diagram_data["linewidth"])-max(si,labelx+si/2)
    - diagram_data["xmaxxnames"]/2;
  if (((float)diagram_data["xminvalue"]>-LITET)&&
      ((float)diagram_data["xminvalue"]<LITET))
    diagram_data["xminvalue"]=0.0;
  
  if (diagram_data["xminvalue"]<0.0)
  {
    //placera ut y-axeln.
    //om detta inte funkar s� rita yaxeln l�ngst ner/l�ngst upp och r�kna om diagram_data["xstart"]
    xpos_for_yaxis=((-diagram_data["xminvalue"])*(diagram_data["xstop"]
						  - diagram_data["xstart"]))/
      (diagram_data["xmaxvalue"]-diagram_data["xminvalue"])
      + diagram_data["xstart"];
      
    int minpos;
    minpos=diagram_data["xmaxynames"]+si/2+
      diagram_data["linewidth"]+2;
    if (minpos>xpos_for_yaxis)
    {
      xpos_for_yaxis=minpos;
      diagram_data["xstart"]=xpos_for_yaxis+
	diagram_data["xminvalue"]*(diagram_data["xstop"]-xpos_for_yaxis)/
	(diagram_data["ymaxvalue"]);
    } else {
      int maxpos;
      maxpos=diagram_data["xsize"]-
	(int)ceil(diagram_data["linewidth"])-si*2-labelx;
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
	
      diagram_data["xstop"]=diagram_data["xsize"]
	- (int)ceil(diagram_data["linewidth"])-max(si,labelx+si/2)-diagram_data["xmaxxnames"]/2;
      xpos_for_yaxis=diagram_data["xmaxynames"]+si/2+
	diagram_data["linewidth"]+2;
      diagram_data["xstart"]=xpos_for_yaxis;
    } else {
	//s�tt y-axeln l�ngst ner och diagram_data["xstart"] en aning h�gre
	//write("\nNu blev xminvalue st�rre �n noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");

      diagram_data["xstop"]=diagram_data["xsize"]-
	(int)ceil(diagram_data["linewidth"])-max(si,labelx+si/2)
	- diagram_data["xmaxxnames"]/2;
      xpos_for_yaxis=diagram_data["xmaxynames"]+si/2+
	diagram_data["linewidth"]+2;
      diagram_data["xstart"]=xpos_for_yaxis+si*2;
    }

  //Rita ut axlarna
  graph->setcolor(@(diagram_data["axcolor"]));
  
  //Rita xaxeln
  if ((diagram_data["xminvalue"]<=LITET)&&
      (diagram_data["xmaxvalue"]>=-LITET))
    graph->
      polygone(make_polygon_from_line(diagram_data["linewidth"], 
				      ({
					diagram_data["linewidth"],
					diagram_data["ysize"]- ypos_for_xaxis,
					diagram_data["xsize"]-
					si-labelx/2, 
					diagram_data["ysize"]-ypos_for_xaxis
				      }), 
				      1, 1)[0]);
  else
    if (diagram_data["xmaxvalue"]<-LITET)
    {
      graph->
	polygone(make_polygon_from_line(
		   diagram_data["linewidth"], 
		   ({
		     diagram_data["linewidth"],
		     diagram_data["ysize"]- ypos_for_xaxis,
		     
		     xpos_for_yaxis-4.0/3.0*si, 
		     diagram_data["ysize"]-ypos_for_xaxis,
		     
		     xpos_for_yaxis-si, 
		     diagram_data["ysize"]-ypos_for_xaxis-
		     si/2.0,
		     xpos_for_yaxis-si/1.5, 
		     diagram_data["ysize"]-ypos_for_xaxis+
		     si/2.0,
		     
		     xpos_for_yaxis-si/3.0, 
		     diagram_data["ysize"]-ypos_for_xaxis,
		     
		     diagram_data["xsize"]-si-labelx/2, 
		     diagram_data["ysize"]-ypos_for_xaxis
		     
		   }), 
		   1, 1)[0]);
    }
    else
      if (diagram_data["xminvalue"]>LITET)
      {
	graph->
	  polygone(make_polygon_from_line(
		     diagram_data["linewidth"], 
		     ({
		       diagram_data["linewidth"],
		       diagram_data["ysize"]- ypos_for_xaxis,
		       
		       xpos_for_yaxis+si/3.0, 
		       diagram_data["ysize"]-ypos_for_xaxis,
		       
		       xpos_for_yaxis+si/1.5, 
		       diagram_data["ysize"]-ypos_for_xaxis-
		       si/2.0,
		       xpos_for_yaxis+si, 
		       diagram_data["ysize"]-ypos_for_xaxis+
		       si/2.0,
		       
		       xpos_for_yaxis+4.0/3.0*si, 
		       diagram_data["ysize"]-ypos_for_xaxis,
		       
		       diagram_data["xsize"]-si-labelx/2, 
		       diagram_data["ysize"]-ypos_for_xaxis
		       
		     }), 
		     1, 1)[0]);
	
      }
  
  graph->polygone(
		  ({
		    diagram_data["xsize"]-
		    diagram_data["linewidth"]/2-
		    (float)si-labelx/2, 
		    diagram_data["ysize"]-ypos_for_xaxis-
		    (float)si/4.0,
		    
		    diagram_data["xsize"]-
		    diagram_data["linewidth"]/2-labelx/2, 
		    diagram_data["ysize"]-ypos_for_xaxis,
		    
		    diagram_data["xsize"]-
		    diagram_data["linewidth"]/2-
		    (float)si-labelx/2, 
		    diagram_data["ysize"]-ypos_for_xaxis+
		    (float)si/4.0
		  })
		  );
  

  //Rita yaxeln
  if ((diagram_data["yminvalue"]<=LITET)&&
      (diagram_data["ymaxvalue"]>=-LITET))
    graph->
      polygone(make_polygon_from_line(
                 diagram_data["linewidth"], 
		 ({
		   xpos_for_yaxis,
		   diagram_data["ysize"]-diagram_data["linewidth"],
		   xpos_for_yaxis,
		   si+labely
		 }), 
		 1, 1)[0]);
  else
    if (diagram_data["ymaxvalue"]<-LITET)
    {
      graph->
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
		   }), 
		   1, 1)[0]);
    }
    else
      if (diagram_data["yminvalue"]>LITET)
      {
	graph->
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
		     }), 
		     1, 1)[0]);
      }
    
  //Rita pilen
  graph->
    polygone(
	     ({
	       xpos_for_yaxis-
	       (float)si/4.0,
	       diagram_data["linewidth"]/2.0+
	       (float)si+
	       labely,
				      
	       xpos_for_yaxis,
	       diagram_data["linewidth"]/2.0+
	       labely,
	
	       xpos_for_yaxis+
	       (float)si/4.0,
	       diagram_data["linewidth"]/2.0+
	       (float)si+
	       labely
	     })); 
  

  //R�kna ut lite skit
  float xstart=(float)diagram_data["xstart"];
  float xmore=(-xstart+diagram_data["xstop"])/
    (diagram_data["xmaxvalue"]-diagram_data["xminvalue"]);
  float ystart=(float)diagram_data["ystart"];
  float ymore=(-ystart+diagram_data["ystop"])/
    (diagram_data["ymaxvalue"]-diagram_data["yminvalue"]);
  
  /*  for(int i=0; i<sizeof(diagram_data["ynamesimg"]); i++)
    if (diagram_data["ynamesimg"][i]->ysize()>=
	(int)floor(diagram_data["yspace"]*ymore))
      diagram_data["ynamesimg"][i]=diagram_data["ynamesimg"][i]->
	scale(0, (int)floor(diagram_data["yspace"]*ymore));
  */
  
  draw_grid(diagram_data, xpos_for_yaxis, ypos_for_xaxis, 
	    xmore, ymore, xstart, ystart, (float) si);
  
  //Placera ut texten p� X-axeln
  int s=sizeof(diagram_data["xnamesimg"]);
  for(int i=0; i<s; i++)
    if ((diagram_data["values_for_xnames"][i]<diagram_data["xmaxvalue"])&&
	(diagram_data["values_for_xnames"][i]>diagram_data["xminvalue"]))
    {
      graph->setcolor(@diagram_data["textcolor"]);
      graph->paste_alpha_color(diagram_data["xnamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor((diagram_data["values_for_xnames"][i]
					   - diagram_data["xminvalue"])
					  * xmore+xstart
					  - diagram_data["xnamesimg"][i]
					  -> xsize()/2), 
			       (int)floor(diagram_data["ysize"]-ypos_for_xaxis
					  + si/2.0));
      graph->setcolor(@diagram_data["axcolor"]);
      graph->
	polygone(make_polygon_from_line(
		   diagram_data["linewidth"], 
		   ({
		     ((diagram_data["values_for_xnames"][i]
		       - diagram_data["xminvalue"]) * xmore+xstart),
		     diagram_data["ysize"]-ypos_for_xaxis+si/4,
		     ((diagram_data["values_for_xnames"][i]-
		       diagram_data["xminvalue"])
		      *xmore+xstart),
		     diagram_data["ysize"]-ypos_for_xaxis-si/4
		   }), 
		   1, 1)[0]);
    }

  //Placera ut texten p� Y-axeln
  s=sizeof(diagram_data["ynamesimg"]);
  for(int i=0; i<s; i++)
    if ((diagram_data["values_for_ynames"][i]<diagram_data["ymaxvalue"])&&
	(diagram_data["values_for_ynames"][i]>diagram_data["yminvalue"]))
    {
      //write("\nYmaXnames:"+diagram_data["ymaxynames"]+"\n");
      graph->setcolor(@diagram_data["textcolor"]);
      graph->paste_alpha_color(
               diagram_data["ynamesimg"][i], 
	       @(diagram_data["textcolor"]), 
	       (int)floor(xpos_for_yaxis-
			  si/4.0-diagram_data["linewidth"]-
			  diagram_data["ynamesimg"][i]->xsize()),
	       (int)floor(-(diagram_data["values_for_ynames"][i]-
			    diagram_data["yminvalue"])
			  *ymore+diagram_data["ysize"]-ystart
			  - diagram_data["ymaxynames"]/2));
      graph->setcolor(@diagram_data["axcolor"]);
      graph->
	polygone(make_polygon_from_line(
          diagram_data["linewidth"], 
	  ({
	    xpos_for_yaxis - si/4,
	    (-(diagram_data["values_for_ynames"][i]
	       - diagram_data["yminvalue"])
	     *ymore+diagram_data["ysize"]-ystart),
	    
	    xpos_for_yaxis+
	    si/4,
	    (-(diagram_data["values_for_ynames"][i]-
	       diagram_data["yminvalue"])
	     *ymore+diagram_data["ysize"]-ystart)
	  }), 
	  1, 1)[0]);
    }


  //S�tt ut labels ({xstorhet, ystorhet, xenhet, yenhet})
  if (diagram_data["labelsize"])
  {
    graph->paste_alpha_color(labelimg, 
			     @(diagram_data["labelcolor"]), 
			     diagram_data["xsize"]-labelx
			     - (int)ceil((float)diagram_data["linewidth"]),
			     diagram_data["ysize"]
			     - (int)ceil((float)(ypos_for_xaxis-si/2)));
    
    string label;
    int x;
    int y;
    GETFONT(yaxisfont);
    if (diagram_data["labels"][3] && sizeof(diagram_data["labels"][3]))
      label=diagram_data["labels"][1]+" ["+diagram_data["labels"][3]+"]"; //Ystorhet
    else
      label=diagram_data["labels"][1];
    if ((label!="")&&(label!=0))
      labelimg=notext->write(label)
	-> scale(0,diagram_data["labelsize"]);
    else
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);
    
    if (labelimg->xsize()<1)
      labelimg=IMAGE(diagram_data["labelsize"],diagram_data["labelsize"]);
    
    //if (labelimg->xsize()> graph->xsize())
    //labelimg->scale(graph->xsize(),labelimg->ysize());

    if (labelimg->xsize()>
	diagram_data["xsize"])
      labelimg=labelimg->scale(diagram_data["xsize"], 0);
    
    
    x=max(2,((int)floor((float)xpos_for_yaxis)-labelimg->xsize()/2));
    x=min(x, graph->xsize()-labelimg->xsize());
      
    y=0; 

    if (label && sizeof(label))
      graph->paste_alpha_color(labelimg, 
			       @(diagram_data["labelcolor"]), x,
			       2+labely-labelimg->ysize());
      
  }

  //Rita ut datan
  int farg=0;
  
  foreach(diagram_data["data"], array(float) d)
  {
    d-=({VOIDSYMBOL});
    for(int i=0; i<sizeof(d)-1; i++)
    {
      d[i]=(d[i]-diagram_data["xminvalue"])*xmore+xstart;
      i++;
      d[i]=-(d[i]-diagram_data["yminvalue"])*ymore+diagram_data["ysize"]
	- ystart;	  
    }

    graph->setcolor(@(diagram_data["datacolors"][farg++]));
    
    draw(graph, diagram_data["linewidth"],d);
  }
  
  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=graph;
  return diagram_data;
}
