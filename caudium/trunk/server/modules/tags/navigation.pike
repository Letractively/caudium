/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

//! module: Navigation
//!  This module makes losts of differents navigation menus.<br />
//!  Please see <tt>&lt;navigation help&gt;</tt> to more documentation about
//!  this module.
//! type: MODULE_PARSER | MODULE_LOCATION
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$
//! note: This module uses Image.???.* functions a lots =)

#include <config.h>
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version  = "$Id$";
constant thread_safe  = 1;
constant module_name  = "Navigation"; 
constant module_type  = MODULE_PARSER | MODULE_LOCATION;
constant module_doc   = "This module makes lots of differents navigation menus."
                        "<br />Please see <tt>&lt;navigation help&gt;</tt> to "
			"more documentation about this module.";
constant module_unique= 1;

#define pi       3.141592653589
#define MAX(a,b) ((a)<(b)?(b):(a))

#define use_contents_cache    1
#define empty_cache_on_start  0
#define dump_ppm              0
#define limit_length          150

mapping(string:string) contents_cache = ([]);

string nav_debug_string = "";
string container_navigation(string tag_name, mapping args, string contents,
			    object id, object file, mapping defines);


//  ===================================================================
//
//  Utility functions


constant nbsp = iso88591["&nbsp;"];
constant replace_from = indices( iso88591 )+ ({"&ss;","&lt;","&gt;","&amp;",});
constant replace_to   = values( iso88591 ) + ({ nbsp, "<", ">", "&", }); 

#define simplify_text( from ) replace(from,replace_from,replace_to)

void nsdebug(string format, mixed ... rest)
{
  nav_debug_string += sprintf(format,@rest)+"</pre><hr><pre>";
}

#ifdef NAV_DEBUG
#define ndebug(x) nsdebug("x: %O",x)
#else
#define ndebug(x)
#endif

void writeppm(string fn, mapping m, object o)
{
  object f=Stdio.File();
  f->open(fn,"wc");
  f->write(Image.PNM.encode(o));
  f->close();
  return;
}

int findcolor(array(array(int)) pal, array(int) col)
{
  foreach(pal,array a)
    if(equal(a,col))
      return 1;
  return 0;
}


int writegif(string fn, mapping m, object o)
{
  object f=Stdio.File();
  f->open(fn,"wc");
  array(int) transp;
  
  int num_cols=(int)m->quant;
  if(num_cols==0)
    num_cols=256;
  object ct=Image.colortable(o,num_cols);
  if(m->fs)
    ct->floyd_steinberg();
  if(m->transparent)
  {
//    if(transp=="transparent")
//      transp=parse_color(m->bodybg);
//    else
      transp=parse_color(m->transparent);
    int transp_present=findcolor((array)ct,transp);
    if(transp_present)
      f->write(Image.GIF.encode(o,ct,@transp));
    else
      f->write(Image.GIF.encode(o,ct));
  }
  else
    f->write(Image.GIF.encode(o,ct));
  f->close();
  return 1;
}


int writejpeg(string fn, string qual, object o)
{
#if constant(Image.JPEG.encode)
  int quality= (int)qual||80;
  object f=Stdio.File();
  string result;
  f->open(fn,"wc");
  f->write(Image.JPEG.encode(o, ([ "quality": (int)qual||80 ])));
  f->close();
  return 1;
#endif
  return 0;
}

int writepng(string fn, object o)
{
#if constant(Image.PNG.encode)
  object f=Stdio.File();
  string result;
  f->open(fn,"wc");
  f->write(Image.PNG.encode(o));
  f->close();
  return 1;
#endif
  return 0;
}

object load_font(string name)
{
  object o;
  if(stringp(name))
    o=resolve_font(name);
  if(!o)
    o = get_font(caudium->QUERY(default_font),
		 caudium->QUERY(default_font_size),
		 0,0,"left",0.0,0.0);
  return o;
}

#if !efun(make_matrix)
static private mapping (int:array(array(int))) matrixes = ([]);
array (array(int)) make_matrix(int size)
{
  if(matrixes[size]) return matrixes[size];
  array res;
  int i;
  int j;
  res = Array.map(allocate(size), lambda(int s, int size){
    return allocate(size); }, size);

  for(i=0; i<size; i++)
    for(j=0; j<size; j++)
      res[i][j] = (int)MAX((float)size/2.0-
			   sqrt((size/2-i)*(size/2-i) +
				(size/2-j)*(size/2-j)),0);
  return matrixes[size] = res;
}
#endif


object (Image.image) blur(object img, int amnt)
{
  img->setcolor(0,0,0);
  img = img->autocrop(amnt, 0,0,0,0, 0,0,0);

  for(int i=0; i<amnt; i++) 
    img = img->apply_matrix( make_matrix((int)sqrt(img->ysize()+20)));
  return img;
}

void zapcaches()
{
  foreach(get_dir(query("cachedir"))-({ ".",".." }),string dir)
  {
    werror(sprintf("zapping dir: %O\n",dir));
    catch{
      foreach(get_dir(query("cachedir")+"/"+dir),string file)
	rm(query("cachedir")+dir+"/"+file);
      rm(query("cachedir")+dir);
    };
  }
  contents_cache = ([]);
}

void start(int num, object configuration)
{
  module_dependencies(configuration,({ "graphic_text" }) );
  if(configuration)
    mkdirhier( query( "cachedir" )+"/.foo" );
}


object last_image;      // Cache the last image for a while.
string last_image_name;

object load_image(string filename, object id)
{
  if(last_image_name==filename) return last_image;
  string data;
  object file, img;
  data = id->conf->try_get_file(filename, id);
  if(!data)
    return 0;
  array decoders = ({ Image.PNM.decode });
#if constant(Image.GIF.decode)
  decoders += ({ Image.GIF.decode });
#endif  
#if constant(Image.PNG.decode)
  decoders += ({ Image.PNG.decode });
#endif  
#if constant(Image.JPEG.decode)
  decoders += ({ Image.JPEG.decode });
#endif
#if constatn(Image.ANY.decode)
  decoders += ({ Image.ANY.decoder });
#endif
  foreach(decoders, function decoder)
  {
    catch {
      img=decoder(data);
      if(img)
	break;
    };
  }
  if(!img)
    return 0;
  last_image_name=filename;
  last_image=img;
  return img;
}


array wordwrap(string text, object fnt, int maxwidth, float scale)
{
#if limit_length  
  text=text[..limit_length];
#endif  
  if(!maxwidth)
    maxwidth=5000;
  if(scale==0.0)
    scale=1.0;
  maxwidth=(int)(maxwidth/scale);
  array dest=({});
  array lines=({""});
  text-="\r";
  text=replace(text,"\n"," ");
  text=replace(text,"\\n","\n");
  string s;
  foreach(text/" "-({""}),string word)
    if(sizeof(lines[-1]))
      if(fnt->extents)
      {
        if(fnt->extents(s=lines[-1]+" "+word)[0]<=maxwidth)
          lines[-1]=s;
        else
          lines+=({word});
      }
      else
        lines[-1]=lines[-1]+" "+word;
    else
      lines[-1]=word;
  foreach(lines,string s1)
    foreach((s1)/"\n",string s2)
      dest+=({fnt->write(s2)->scale(scale)});
  return dest;
}


object tileimage(object img, int xs, int ys)
{
  object dest=Image.image(xs,ys);
  int srcx=img->xsize();
  int srcy=img->ysize();
  if(srcx <= 0 || srcy <= 0)
    return dest;
  
  for(int x=0; x<=xs; x+=srcx)
    for(int y=0; y<=ys; y+=srcy)
      dest->paste(img,x,y);

  return dest;
}


object mirrortileimage(object img, int xs, int ys)
{
  object dest=Image.image(xs,ys);
  int srcx=img->xsize();
  int srcy=img->ysize();
  object bigimg=Image.image(srcx*2,srcy*2);
  if(srcx <= 0 || srcy <= 0)
    return dest;
  bigimg->paste(img,0,0);
  bigimg->paste(img->mirrorx(),srcx,0);
  bigimg->paste(img->mirrory(),0,srcy);
  bigimg->paste(img->mirrorx()->mirrory(),srcx,srcy);
  
  for(int x=0; x<=xs; x+=2*srcx)
    for(int y=0; y<=ys; y+=2*srcy)
      dest->paste(bigimg,x,y);

  return dest;
}


int newest_file(mapping m, object id)
{
  int t=0;
  array a;

  if(m->bgsrc)
    if(a=file_stat(m->bgsrc))
      t=MAX(t,a[3]);
  string s1,s2,s3,s4,s5;
  foreach(({"left", "leftpad", "middle", "rightpad", "right"}), s1)
    foreach(({"_top", "_text", "_delimit", "_bottom"}), s2)
      foreach(({"", "_selected", "_mouseover"}), s3)
	foreach(({"src", "alpha"}), s4)
	  if(m->boxstyles)
	    if(m->boxstyles[s1+s2+s3])
	      if(s5=m->boxstyles[s1+s2+s3][s4])
		if(a=stat_file((m->imgbase?(m->imgbase+s5):s5),id))
		  t=MAX(t,a[3]);
  return t;
}


mixed draw_rows(mapping m, object id)
{
  int totaltextheight=0;
  int maxtextwidth=0;
    
  int defaultwidth=160;
  int width,maxw,w,delimitheight=5;
  array text_masks=({});
    
  object dest;

  mapping imgs=([]);
  mapping alphas=([]);
  mapping dims=([]);
  mapping force=([]);
  mapping rowimgs=([]);
  mapping ret=([]);

  dims->xspacing=m->boxstyles->textstyle->xspacing;
  dims->yspacing=m->boxstyles->textstyle->yspacing;

  object fnt=load_font(m->font);
  if(fnt->height)
    dims->text=(int)(fnt->height()*((m->boxstyles->textstyle->scale)?
                                    m->boxstyles->textstyle->scale:1.0));
  else
    dims->text = (int)(fnt->write("Q")->ysize() * 
                       ((m->boxstyles->textstyle->scale)?
                        m->boxstyles->textstyle->scale:1.0));
  // Create textmasks and find the maximum width
  maxw=0;
  foreach(m->menuitems||({}),mapping item)
    text_masks+=({wordwrap(item->label,fnt,m->maxwidth?
			   ((int)m->maxwidth-2*(int)m->boxstyles->textstyle->xspacing):0,
			   m->boxstyles->textstyle->scale)});
  
  foreach(text_masks,array a)
  {
    totaltextheight+=2*dims->yspacing;
    foreach(a,object o)
    {
      totaltextheight+=dims->text;
      maxtextwidth=MAX(maxtextwidth,o->xsize());
    }
  }
  maxtextwidth+=2*dims->xspacing;
  dims->totaltextheight=totaltextheight;


  // determine width of the textboxes
  if(m->width)
    width=(int)m->width;
  else
  {
    width=maxtextwidth;  // maxtextwidth == max width of the text masks
    if(m->minwidth)
      if(width<m->minwidth)
	width=m->minwidth;
    if(m->maxwidth)
      if(width>(int)m->maxwidth)
	width=(int)m->maxwidth;
  }

  string s,s1,s2,s3,src,alpha;
  int w,rot,inverted;

  dims["middle"]=width;

  // determine all dimensions and load images and alpha images for the table
  foreach(({"left", "leftpad", "middle", "rightpad", "right"}), s1)
    foreach(({"_top", "_text", "_delimit", "_bottom"}), s2)
      foreach(({"", "_selected", "_mouseover"}), s3)
      {
	if(!dims[s1]) dims[s1]=0;
	if(!dims[s2[1..]]) dims[s2[1..]]=0;
	if(m->boxstyles[s1+s2+s3])
	{
	  if(src=m->boxstyles[s1+s2+s3]->src)      // load a src image
	  {
	    if(!(imgs[s1+s2+s3]=load_image(m->imgbase+src,id)))
	      return "Could not load "+s1+s2+s3+" image ("+m->imgbase+src+")";
	    if(rot=(int)m->boxstyles[s1+s2+s3]->rot)
	      imgs[s1+s2+s3]=imgs[s1+s2+s3]->rotate(-rot);
	    if(!force[s1])
	      dims[s1]=MAX(imgs[s1+s2+s3]->xsize(),dims[s1]);
	    if(!force[s2[1..]])
	      dims[s2[1..]]=MAX(imgs[s1+s2+s3]->ysize(),dims[s2]);
	  }
	  
	  if(alpha=m->boxstyles[s1+s2+s3]->alpha)
	  {
	    inverted=(m->boxstyles[s1+s2+s3]->alphainvert)?1:0;
	    // load an alpha image or create an alpha image from an alpha value
	    if((alpha=="0")||((int)alpha))   // argument is numeric
	      alphas[s1+s2+s3]=inverted?(255-(int)alpha):(int)alpha;
	    else    // argument is not numeric, try to load it
	    {
	      if(!(alphas[s1+s2+s3]=load_image(m->imgbase+alpha,id)))
		return "Could not load "+s1+s2+s3+" alpha image ("+m->imgbase+alpha+")";
	      if(rot=(int)m->boxstyles[s1+s2+s3]->rot)
	        alphas[s1+s2+s3]=alphas[s1+s2+s3]->rotate(-rot);
	      if(inverted)
		alphas[s1+s2+s3]=alphas[s1+s2+s3]->invert();
	    }
	    alpha=0;  // reset alpha variable
	  }
	  else
	    alphas[s1+s2+s3]=255;

	  if(w=(int)(m->boxstyles[s1+s2+s3]->width))
	  {
	    dims[s1]=w;
	    force[s1]=1;
	  }
	  
	  if(w=(int)(m->boxstyles[s1+s2+s3]->height))
	  {
	    dims[s2[1..]]=w;
	    force[s2[1..]]=1;
	  }
	}
      }

  // paste all images onto the corresponding row images
  int xpos;
  array col;
  
  dims->text+=2*dims->yspacing;
  
  foreach(({"top", "text", "text_selected", "text_mouseover","delimit", "bottom"}), s1)
  {
    if(s1[0..3]=="text")
      s2="text";
    else
      s2=s1;
    if(dims[s2])
    {
      int height=0,h=0;
      if(s2=="text")
	foreach(({"left", "middle", "right"}), s3)
	  catch{ if((h=imgs[s3+"_"+s1]->ysize())>height) height=h; };
      if(!height)
	height=dims[s2];
      rowimgs[s1]=Image.image(dims->left+dims->middle+dims->right,height); 
      rowimgs["alpha_"+s1]=Image.image(dims->left+dims->middle+dims->right,height);
      foreach(({"left", "middle", "right"}), s3)
	if(dims[s3])
	{
	  switch (s3)
	  {
	   case "left":   xpos=0; break;
	   case "middle": xpos=dims->left; break;
	   case "right":  xpos=dims->left+dims->middle; break;
	  }
	  if(imgs[s3+"_"+s1])           // if there is an image loaded for this cell
	  {
	    if(imgs[s3+"_"+s1]->xsize()==dims[s3])
	      rowimgs[s1]->paste(imgs[s3+"_"+s1],xpos,0);
	    else                        // if the size doesn't match, do something about it, perhaps
	    {
	      if(m->boxstyles[s3+"_"+s1]->scaletofit)
		rowimgs[s1]->paste(imgs[s3+"_"+s1]->scale(dims[s3],height),xpos,0);
	      else
	      if(m->boxstyles[s3+"_"+s1]->tile)
		rowimgs[s1]->paste(tileimage(imgs[s3+"_"+s1],dims[s3],dims[s2]),xpos,0);
	      else
	      if(m->boxstyles[s3+"_"+s1]->mirrortile)
		rowimgs[s1]->paste(mirrortileimage(imgs[s3+"_"+s1],dims[s3],dims[s2]),xpos,0);
	      else
		 rowimgs[s1]->paste(imgs[s3+"_"+s1],xpos,0);
	    }
	  }
	  else
	  {
	    if((m->boxstyles[s3+"_"+s1])&&(col=parse_color(m->boxstyles[s3+"_"+s1]->bg)))
	      rowimgs[s1]->box(xpos,0,xpos+dims[s3]-1,height-1,@col);
	  }
	  
	  if(intp(alphas[s3+"_"+s1]))  // argument is numeric  
	    rowimgs["alpha_"+s1]->box(xpos,0,xpos+dims[s3]-1,height-1,alphas[s3+"_"+s1],
				      alphas[s3+"_"+s1],alphas[s3+"_"+s1]);
	  else
	    rowimgs["alpha_"+s1]->paste(alphas[s3+"_"+s1]->scale(dims[s3],height),xpos,0);
	  
	}
    }
  }

  dims->text-=2*dims->yspacing;

  ret["rowimgs"]=rowimgs;
  ret["dims"]=dims;
  ret["text_masks"]=text_masks;
  return ret;
}

mixed draw_cols(mapping m, object id)
{
  int totaltextwidth=0;
  int maxtextheight=0;
  int defaultwidth=160;
  int width,height,maxw,w,delimitheight=5;
  array  text_masks=({});
  string fontname;
    
  object dest;

  mapping imgs=([]);
  mapping alphas=([]);
  mapping dims=([]);
  mapping force=([]);
  mapping rowimgs=([]);
  mapping ret=([]);

  dims->xspacing=m->boxstyles->textstyle->xspacing;
  dims->yspacing=m->boxstyles->textstyle->yspacing;

  // Load font
  object fnt=load_font(m->font);

  dims->text=(int)(fnt->height()*((m->boxstyles->textstyle->scale)?
				  m->boxstyles->textstyle->scale:1.0));

  // Create textmasks and find the maximum width
  maxw=0;

  foreach(m->menuitems||({}),mapping item)
    text_masks+=({wordwrap(item->label,fnt,(int)m->maxwidth-
			   2*(int)m->boxstyles->textstyle->xspacing,
			   m->boxstyles->textstyle->scale)});

  foreach(text_masks,array a)
  {
    totaltextwidth+=2*dims->xspacing;
    int localheight=0;
    totaltextwidth+=a[0]->xsize();
    foreach(a,object o)
      localheight+=dims->text;
    localheight+=2*dims->yspacing;
    maxtextheight=MAX(maxtextheight,localheight);
  }

  dims->maxtextheight=maxtextheight;
  dims->totaltextwidth=totaltextwidth;


  // determine height of the textboxes
  if(m->height)
    height=(int)m->height;
  else
  {
    height=maxtextheight;  // maxtextheight == max height of the text masks
    if(m->minheight)
      if(height<m->minheight)
	height=m->minheight;
    if(m->maxheight)
      if(height>(int)m->maxheight)
	height=(int)m->maxheight;
  }

  string s,s1,s2,s3,src,alpha;
  int w,rot,inverted;

  dims["middle"]=height;

  // determine all dimensions and load images and alpha images for the table
  foreach(({"left", "leftpad", "middle", "rightpad", "right"}), s1)
    foreach(({"_top", "_text", "_delimit", "_bottom"}), s2)
      foreach(({"", "_selected", "_mouseover"}), s3)
      {
	if(!dims[s1]) dims[s1]=0;
	if(!dims[s2[1..]]) dims[s2[1..]]=0;
	if(m->boxstyles[s1+s2+s3])
	{
	  if(src=m->boxstyles[s1+s2+s3]->src)      // load a src image
	  {
	    if(!(imgs[s1+s2+s3]=load_image(m->imgbase+src,id)))
	      return "Could not load "+s1+s2+s3+" image ("+m->imgbase+src+")";
	    if(rot=(int)m->boxstyles[s1+s2+s3]->rot)
	      imgs[s1+s2+s3]=imgs[s1+s2+s3]->rotate(-rot);
	    if(!force[s1])
	      dims[s1]=MAX(imgs[s1+s2+s3]->xsize(),dims[s1]);
	    if(!force[s2[1..]])
	      dims[s2[1..]]=MAX(imgs[s1+s2+s3]->ysize(),dims[s2]);
	  }
	  
	  if(alpha=m->boxstyles[s1+s2+s3]->alpha)
	  {
	    inverted=(m->boxstyles[s1+s2+s3]->alphainvert)?1:0;
	    // load an alpha image or create an alpha image from an alpha value
	    if((alpha=="0")||((int)alpha))   // argument is numeric
	      alphas[s1+s2+s3]=inverted?(255-(int)alpha):(int)alpha;
	    else    // argument is not numeric, try to load it
	    {
	      if(!(alphas[s1+s2+s3]=load_image(m->imgbase+alpha,id)))
		return "Could not load "+s1+s2+s3+" alpha image ("+m->imgbase+alpha+")";
	      if(rot=(int)m->boxstyles[s1+s2+s3]->rot)
	        alphas[s1+s2+s3]=alphas[s1+s2+s3]->rotate(-rot);
	      if(inverted)
		alphas[s1+s2+s3]=alphas[s1+s2+s3]->invert();
	    }
	    alpha=0;  // reset alpha variable
	  }
	  else
	    alphas[s1+s2+s3]=255;

	  if(w=(int)(m->boxstyles[s1+s2+s3]->width))
	  {
	    dims[s1]=w;
	    force[s1]=1;
	  }
	  
	  if(w=(int)(m->boxstyles[s1+s2+s3]->height))
	  {
	    dims[s2[1..]]=w;
	    force[s2[1..]]=1;
	  }
	}
      }

    
  // paste all images onto the corresponding row images
  int xpos;
  array col;

  foreach(({"top", "text", "text_selected", "text_mouseover","delimit", "bottom"}), s1)
  {
    if(s1[0..3]=="text")
      s2="text";
    else
      s2=s1;
    if(dims[s2])
    {
      int height=0,h=0;
      if(s2=="text")
	foreach(({"left", "middle", "right"}), s3)
	  catch{ if((h=imgs[s3+"_"+s1]->xsize())>height) height=h; };
      if(!height)
	height=dims[s2];
      int delta=dims->left+dims->middle+dims->right;
      rowimgs[s1]=Image.image(height,delta);
      rowimgs["alpha_"+s1]=Image.image(height,delta);
      foreach(({"left", "middle", "right"}), s3)
	if(dims[s3])
	{
	  switch (s3)
	  {
	   case "left":   xpos=dims->middle+dims->right; break;
	   case "middle": xpos=dims->right; break;
	   case "right":  xpos=0; break;
	  }
	  if(imgs[s3+"_"+s1])           // if there is an image loaded for this cell
	  {
	    if(imgs[s3+"_"+s1]->ysize()==dims[s3])
	      rowimgs[s1]->paste(imgs[s3+"_"+s1],0,xpos);
	    else                        // if the size doesn't match, do something about it, perhaps
	    {
	      if(m->boxstyles[s3+"_"+s1]->scaletofit)
		rowimgs[s1]->paste(imgs[s3+"_"+s1]->scale(height,dims[s3]),0,xpos);
	      else
	      if(m->boxstyles[s3+"_"+s1]->tile)
		rowimgs[s1]->paste(tileimage(imgs[s3+"_"+s1],dims[s2],dims[s3]),0,xpos);
	      else
	      if(m->boxstyles[s3+"_"+s1]->mirrortile)
		rowimgs[s1]->paste(mirrortileimage(imgs[s3+"_"+s1],dims[s2],dims[s3]),0,xpos);
	      else
		 rowimgs[s1]->paste(imgs[s3+"_"+s1],0,xpos);
	    }
	  }
	  else
	  {
	    if((m->boxstyles[s3+"_"+s1])&&(col=parse_color(m->boxstyles[s3+"_"+s1]->bg)))
	      rowimgs[s1]->box(0,xpos,height-1,xpos+dims[s3]-1,@col);  // notice the 'height-1'...
	  }
	  
	  if(intp(alphas[s3+"_"+s1]))  // argument is numeric  
	    rowimgs["alpha_"+s1]->box(0,xpos,height-1,xpos+dims[s3]-1,alphas[s3+"_"+s1],
				      alphas[s3+"_"+s1],alphas[s3+"_"+s1]);
	  else
	    rowimgs["alpha_"+s1]->paste(alphas[s3+"_"+s1]->scale(height,dims[s3]),0,xpos);
	}
    }
  }

  ret["rowimgs"]=rowimgs;
  ret["dims"]=dims;
  ret["text_masks"]=text_masks;
  return ret;
}

string draw_images_vert(string cache_id, mapping m, object id)
{
  object dest;

  mapping dims=([]);
  mapping rowimgs=([]);

  mixed rows=draw_rows(m,id);
  if(stringp(rows))
    return rows;

  rowimgs=rows->rowimgs;
  dims=rows->dims;
  array (object) text_masks=rows->text_masks;

  if(!m->menuitems)
    return "No menuitems";

  int totalwidth=dims->left+dims->middle+dims->right;
  int totalheight=dims->totaltextheight+
    dims->top+dims->bottom+
    (sizeof(m->menuitems||({}))-1)*dims->delimit;
  if(m->bottomdelimit)
    totalheight+=dims->delimit;

  //  werror("Dims: %O\nTotalheight: %O\n",dims,totalheight);

  dest=Image.image(totalwidth,totalheight,@parse_color(m->bg));

  ndebug(totalheight);
  
  object bgmap=load_image(m->imgbase+m->bgsrc,id);
  if(!bgmap&&m->bgsrc)
    return "Could not load background image!";
  if(bgmap)
  {
    if(m->tile)
      dest=tileimage(bgmap,totalwidth,totalheight);
    else if(m->mirrortile)
      dest=mirrortileimage(bgmap,totalwidth,totalheight);
    else if(m->scaletofit)
      dest=bgmap->scale(totalwidth,totalheight);
    else
      dest->paste(bgmap);
  }
  
  object texture;
  int ypos;
  int xpos;
  mapping destimages = ([]);
  object d;
  array col;
  
  array used_styles=({"text", "text_selected", "text_mouseover"});
  
  // create all three different images
  foreach(used_styles, string s1)
    if(m->boxstyles["middle_"+s1])
    {
      d=destimages[s1]=dest->clone();
      
      if(m->activestyles->top&&dims->top)
	d->paste_mask(rowimgs->top,rowimgs->alpha_top,0,0);


      if(!(texture=load_image(m->imgbase+m->boxstyles["middle_"+s1]->fg,id)))
	texture=Image.image(dims->left+dims->middle+dims->right,dims->text,
			    @parse_color(m->boxstyles["middle_"+s1]->fg));
      
      texture=mirrortileimage(texture,dims->left+dims->middle+dims->right,dims->text);

      ypos=dims->top;
      int num_lines;
      for(int i=0;i<sizeof(m->menuitems);i++)
      {
	num_lines=sizeof(text_masks[i]);
	if(m->abs_top)
	  d->paste_mask(
	    rowimgs[s1]->copy(0,ypos,rowimgs[s1]->xsize()-1,
			      ypos+2*dims->yspacing+num_lines*dims->text),
	    rowimgs["alpha_"+s1]->copy(0,ypos,rowimgs[s1]->xsize()-1,
				       ypos+2*dims->yspacing+num_lines*dims->text),
	    0,ypos);
	else
	  d->paste_mask(
	    rowimgs[s1]->scale(rowimgs[s1]->xsize(),
			       2*dims->yspacing+num_lines*dims->text),
	    rowimgs["alpha_"+s1]->scale(rowimgs[s1]->xsize(),
					2*dims->yspacing+num_lines*dims->text),
	    0,ypos);

	ypos+=dims->yspacing;
	mixed bof = text_masks[i];
	//foreach(text_masks[i],object t)
	foreach(bof,object t)
	{
	  xpos=0;
	  if(m->center)
	    xpos=(dims->middle-t->xsize()-2*dims->xspacing)/2;
	  if(m->right)
	    xpos=(dims->middle-t->xsize()-2*dims->xspacing);
	  xpos+=dims->xspacing;

	  string shadow;
	  if(shadow=m->boxstyles["middle_"+s1]->shadow)
	  {
	    string color="black";
	    int distance=3, blur_amount=2, direction=135;
	    sscanf(shadow,"%s,%d,%d,%d",color,distance,blur_amount,direction);
	    float angle=((float)direction)*pi/180.0;
	    d->paste_alpha_color((blur_amount?(blur(t,blur_amount)):t),@parse_color(color),
				 dims->left+xpos+(int)(sin(angle)*(float)distance),
				 ypos-(int)(cos(angle)*(float)distance));
	  }
	  
	  d->paste_mask(texture,t,dims->left+xpos,ypos);
	  ypos+=dims->text;
	}
	ypos+=dims->yspacing;
	if(i<(sizeof(m->menuitems)-1)||(m->bottomdelimit))
	  if(rowimgs->delimit)
	  {
	    d->paste_mask(rowimgs->delimit,rowimgs->alpha_delimit,0,ypos);
	    ypos+=dims->delimit;
	  }
      }
       if(m->activestyles->bottom&&dims->bottom)
 	d->paste_mask(rowimgs->bottom,rowimgs->alpha_bottom,0,ypos);

    }

  dims["menusize"]=sizeof(m->menuitems);

//  werror("gazonk: %O\n",m);
  
  // Save all the dimensions in the array dims->positions
  dims->positions=({});
  ypos=0;
  dims->positions+=({ypos});
  ypos+=dims->top;
  for(int i=0; i<sizeof(text_masks); i++)
  {
    dims->positions+=({ypos});
    if((m->delimitabove&&i!=0)||
       (!m->delimitabove))
      ypos+=dims->delimit;
    ypos+=dims->text*sizeof(text_masks[i])+2*dims->yspacing;
  }
  if(m->delimitabove)
    ypos+=dims->delimit;
  dims->positions+=({ypos});
  if(!m->bottomdelimit)
  {
    dims->positions[-1]-=dims->delimit;
    ypos-=dims->delimit;
  }
  ypos+=dims->bottom;
  dims->positions+=({ypos});
  id->misc->dims=dims;


  // create all gifs (or jpegs) and place them in the disk cache
  object o;
  foreach(({"text", "text_selected", "text_mouseover"}), string menutype)
    for(int menunum=-3; menunum<dims->menusize; menunum++)
    {
      if(!((menunum==-1)||
	   (!(dims->top)&&menunum==-2)||
	   (!(dims->bottom)&&menunum==-3)||
	   (menutype!="text"&&menunum<0)))
	    
      {
	int ypos1=0,ypos2=1;
	switch (menunum)
	{
	 case -2:
	  ypos1=0;
	  ypos2=dims->positions[1];
	  break;
	 case -3:
	  ypos1=dims->positions[-2];
	  ypos2=dims->positions[-1];
	  break;
	 default:
	  ypos1=dims->positions[menunum+1];
	  ypos2=dims->positions[menunum+2];
	}
	if(destimages[menutype])
	{
	  o=destimages[menutype]->copy(0,ypos1,
				       dims->left+dims->middle+dims->right-1,
				       ypos2-1);

	  string prefix=query("cachedir")+"/"+cache_id+"/";
	  mkdirhier(prefix+".foo");
	  prefix+=menutype+(string)menunum;
	  if(dump_ppm)
	    writeppm(prefix+".ppm",m,o);
	
	  if(m->jpeg)
	    writejpeg(prefix+".jpeg", m->jpeg, o);
	  else if(m->png)
	  {
	    writepng(prefix+".png",o);
	    writegif(prefix+".gif",m,o); // GIF file saved for old browsers
	  }
	  else
	    writegif(prefix+".gif",m,o);
	}
      }
    }
  
  return "";
}

string draw_images_horiz(string cache_id, mapping m, object id)
{
  object dest;

  mapping dims=([]);
  mapping rowimgs=([]);

  mixed rows=draw_cols(m,id);
  if(stringp(rows))
    return rows;

  rowimgs=rows->rowimgs;
  dims=rows->dims;

  array (object) text_masks=rows->text_masks;

  int totalheight=dims->right+dims->middle+dims->left;
  int totalwidth=
    dims->top+
    dims->totaltextwidth+
    dims->bottom+
    (sizeof(m->menuitems ||({}) )-1)*dims->delimit;
  dims->totalwidth=totalwidth;

  dest=Image.image(totalwidth,totalheight,@parse_color(m->bg));
  object bgmap=load_image(m->imgbase+m->bgsrc,id);
  if(!bgmap&&m->bgsrc)
    return "Could not load background image!";
  if(bgmap)
  {
    if(m->tile)
      dest=tileimage(bgmap,totalwidth,totalheight);
    else if(m->mirrortile)
      dest=mirrortileimage(bgmap,totalwidth,totalheight);
    else
      dest->paste(bgmap);
  }
  
  object texture;
  int ypos;
  int xpos;
  mapping destimages = ([]);
  object d;
  array col;
  
  array used_styles=({"text", "text_selected", "text_mouseover"});
  
  // create all three different images
  foreach(used_styles, string s1)
    if(m->boxstyles["middle_"+s1])
    {
      d=destimages[s1]=dest->clone();
      
      if(m->activestyles->top&&dims->top)
	d->paste_mask(rowimgs->top,rowimgs->alpha_top,0,0);

      if(!(texture=load_image(m->imgbase+m->boxstyles["middle_"+s1]->fg,id)))
	texture=Image.image(dims->left+dims->middle+dims->right,dims->text,
			    @parse_color(m->boxstyles["middle_"+s1]->fg));
      
      texture=mirrortileimage(texture,dims->totaltextwidth,dims->middle);

      xpos=dims->top;
      int num_lines;
      int height=dims->middle+dims->left+dims->right;
      for(int i=0;i<sizeof(m->menuitems);i++)
      {
	int width=0;
	mixed bog0=text_masks[i];
	foreach(bog0,object t)
	  width=MAX(width,t->xsize());
	width+=2*dims->xspacing;

	d->paste_mask(
	  rowimgs[s1]->scale(width,height),
     	  rowimgs["alpha_"+s1]->scale(width,height),
	  xpos,0);
	
	ypos=dims->right+dims->yspacing;
	mixed bog1=text_masks[i];
	foreach(bog1,object t)
	{
	  int dxpos=0;
	  if(m->center)
	    dxpos=(width-t->xsize()-2*dims->xspacing)/2;
	  if(m->right)
	    dxpos=(width-t->xsize()-2*dims->xspacing);
	  dxpos+=dims->xspacing;

	  string shadow;
	  if(shadow=m->boxstyles["middle_"+s1]->shadow)
	  {
	    string color="black";
	    int distance=3, blur_amount=2, direction=135;
	    sscanf(shadow,"%s,%d,%d,%d",color,distance,blur_amount,direction);
	    float angle=((float)direction)*pi/180.0;
	    d->paste_alpha_color((blur_amount?(blur(t,blur_amount)):t),@parse_color(color),
				 xpos+dxpos+(int)(sin(angle)*(float)distance),
				 ypos-(int)(cos(angle)*(float)distance));
	  }
	  d->paste_mask(texture,t,xpos+dxpos,ypos);
	  ypos+=dims->text;
	}
	xpos+=width;
	if(i<(sizeof(m->menuitems)-1))
	  if(rowimgs->delimit)
	  {
	    d->paste_mask(rowimgs->delimit,rowimgs->alpha_delimit,xpos,0);
	    xpos+=dims->delimit;
	  }
      }
      if(m->activestyles->bottom&&dims->bottom)
	d->paste_mask(rowimgs->bottom,rowimgs->alpha_bottom,xpos,0);
    }

  dims["menusize"]=sizeof(m->menuitems);

  // Save all the dimensions in the array dims->positions
  dims->positions=({});
  xpos=0;
  dims->positions+=({xpos});
  xpos+=dims->top;
  //foreach(text_masks,array a)
  foreach(text_masks,mixed a)
  {
    dims->positions+=({xpos});

    int width=0;
    foreach(a,object t)
      width=MAX(width,t->xsize());
    width+=2*dims->xspacing;
    
    xpos+=width+dims->delimit;
  }
  dims->positions+=({xpos});
  dims->positions[-1]-=dims->delimit;
  xpos-=dims->delimit;
  xpos+=dims->bottom;
  dims->positions+=({xpos});

  id->misc->dims=dims;


  // create all gifs (or jpegs) and place them in the disk cache
  object o;
  foreach(({"text", "text_selected", "text_mouseover"}), string menutype)
    for(int menunum=-3; menunum<dims->menusize; menunum++)
    {
      if(!((menunum==-1)||
	   (!(dims->top)&&menunum==-2)||
	   (!(dims->bottom)&&menunum==-3)||
	   (menutype!="text"&&menunum<0)))
	    
      {
	int xpos1,xpos2;
	switch (menunum)
	{
	 case -2:
	  xpos1=0;
	  xpos2=dims->positions[1];
	  break;
	 case -3:
	  xpos1=dims->positions[-2];
	  xpos2=dims->positions[-1];
	  break;
	 default:
	  xpos1=dims->positions[menunum+1];
	  xpos2=dims->positions[menunum+2];
	}

	if(destimages[menutype])
	{
	o=destimages[menutype]->copy(xpos1,0,xpos2-1,dims->left+dims->middle+dims->right-1);
	
	string prefix=query("cachedir")+"/"+cache_id+"/";
	mkdirhier(prefix+".foo");
	prefix+=menutype+(string)menunum;
	if(dump_ppm)
	  writeppm(prefix+".ppm",m,o);
	
	if(m->jpeg)
	  writejpeg(prefix+".jpeg", m->jpeg, o);
	else if(m->png)
	  writepng(prefix+".png",o);
	else
	  writegif(prefix+".gif",m,o);
	}
      }
    }
  
  return "";
}


string draw_menu_text(mapping m, int subnum, string submenu, int javascriptsupports)
{
  string s="";
  string w=(m->width?(" width="+m->width):"");
  mapping textstyle=m->boxstyles->textstyle;

  s+="<table border=0 cellpadding=0 cellspacing=0><tr><td width="+
    (string)(m->indent)+">"+((int)m->indent?"&nbsp;":"")+"</td><td>";
  s+="<table border=0 cellpadding=0 cellspacing=0"+w+">"+
    "<tr><td bgcolor="+textstyle->framecol+"><table border=0 cellpadding="+
    (string)textstyle->spacing+" cellspacing="+
    (textstyle->framewidth?textstyle->framewidth:"0")+" width=100%>";
  int i;
  for(i=0;i<sizeof(m->menuitems);i++)
  {
    mapping item=m->menuitems[i];
    string magic=((javascriptsupports&&item->status)?("onMouseOver=\"self.status='"+item->status+"'; return true;\""):"");
    if(!m->horiz)
      s+="<tr>";
    s+="<td bgcolor="+((m->menuitems[i]->selected)?
      (textstyle->textbgsel?textstyle->textbgsel:"pink"):
      (textstyle->textbg?textstyle->textbg:"white"))+
      "><a "+magic+" href=\""+item->href+"\">"+
      (textstyle->textcol?("<font color="+textstyle->textcol+">"):"")+
      (textstyle->font?("<font face="+textstyle->font+">"):"")+
      (textstyle->size?("<font size="+textstyle->size+">"):"")+
      item->label+
      (textstyle->size?("</font>"):"")+
      (textstyle->font?("</font>"):"")+
      (textstyle->textcol?("</font>"):"")+
      "</a></td>";

    if(i==subnum)
      if(i<sizeof(m->menuitems)-1)
	s+="</table></td></table>"+submenu+
           "<table border=0 cellpadding=0 cellspacing=0"+w+">"+
           "<tr><td bgcolor=black><table border=0 cellpadding="+
	  (string)m->boxstyles->textstyle->spacing+" cellspacing=0 width=100%>";
      else
	s+="</table></td></table>"+submenu;
  }
  if(i!=subnum)
    s+="</table></td></table>";
  s+="</td></table>";
    
  return s;
}


void create()
{
  defvar("location", "/navigation/", "Mountpoint", TYPE_LOCATION,
	 "The URL-prefix for the menu images.");
  defvar("cachedir", "../navigation_cache/", "Cache directory", TYPE_DIR,
	 "The location of the disk cache in the physical filesystem.");
}

string query_location()
{
  return query("location");
}

string callback_textstyle(string tag, mapping args, object id, mapping oa)
{
  id->misc->boxstyles->textstyle=([           "font"    : args->font,
					      "scale"    : (float)args->scale,
					      "size"     : args->size,
					      "maxwidth" : (int)args->maxwidth, 
					      "spacing"  : (int)args->spacing,
					      "xspacing" : (int)args->xspacing,
					      "yspacing" : (int)args->yspacing,
					      "bevel"    : (int)args->bevel,
					      "left"     : args->left,
					      "center"   : args->center,
					      "right"    : args->right,
					      "textbg"   : args->textbg,
					      "textbgsel": args->textbgsel,
					      "textcol"  : args->textcol,
					      "framewidth": args->framewidth,
					      "framecol" : args->framecol,
					      "bold"     : args->bold,
					      "italic"   : args->italic,
					      "light"    : args->light
  ]);
  return "";
}


string callback_boxstyle(string tag, mapping args, object id, mapping oa)
{
  string  s;
  string idx="";
  int found=0;
  foreach(indices((<"left", "leftpad", "middle", "rightpad", "right">)), s)
    if(args[s])
    {
      idx+=s;
      id->misc->activestyles[s]=1;
      found++;
    }
  idx+="_";

  foreach(indices((<"top", "text", "delimit", "bottom">)), s)
    if(args[lower_case(s)])
    {
      idx+=s;
      id->misc->activestyles[s]=1;
      found++;
    }

  if(found!=2)
  {
    werror("Boxtype not specified in <boxstyle>\n");
    return "";
  }

  if(args->selected)
  {
    oa->selected=1;
    idx+="_selected";
  }
  if(args->mouseover||args->current)
  {
    oa->mouseover=1;
    idx+="_mouseover";
  }

  if(args->text&&args->middle)
    id->misc->boxstyles[idx] =(["src":args->src,
				"alpha"    : args->alpha, //( ((int)args->alpha)?(int)args->alpha:0),
				"bg"       : args->bg,
				"fg"       : args->fg,
				"shadowcol": args->shadowcol,
				"align"    : args->align,
				"scale"    : (float)args->scale,
				"shadow"   : args->shadow,
				"align"    : args->align,
				"maxwidth" : (int) args->maxwidth,
				"minwidth" : (int) args->minwidth,
				"width"    : (int) args->width,
				"height"   : (int) args->height,
				"alphainvert" : (args->alphainvert?1:0),
				"scaletofit": args->scaletofit,
				"tile"      : args->tile,
				"rot"      : (int)args->rot,
				"mirrortile": args->mirrortile
    ]);
  else
    id->misc->boxstyles[idx] =(["src":args->src,
				"alpha"    : args->alpha,
				"bg"       : args->bg,
				"rot"      : (int)args->rot,
				"height"   : (int)args->height,
				"width"    : (int)args->width,
				"alphainvert" : (args->alphainvert?1:0),
				"scaletofit": args->scaletofit,
				"tile"      : args->tile,
				"mirrortile": args->mirrortile				
    ]); 
  return "";
}


string callback_mi(string tag, mapping args, string contents, object id, mapping oa)
{
  id->misc->menuitems += ({ ([
    "href"     :  args->href, 
    "label"    :  simplify_text(contents),
    "status"  :  args->status,
    "selected" :  (args->selected?1:0)  ]) }); 
  return "";
}

string callback_magic(string tag, mapping args, object id, mapping oa)
{
  if(!args->name) return "";
  id->misc->magic[args->name]=args;
}

string callback_navigation(string tag, mapping args, string contents, object id, mapping oa)
{
  int subnum=sizeof(id->misc->menuitems);
  mapping misc=copy_value(id->misc);
  string result=container_navigation("navigation", oa|args, contents, id,
				     0, id->misc->defines||([]));
  id->misc=misc|(["nav_id":id->misc->nav_id+1]);  //FIXME, Kludge
  return (string)subnum+"_"+result;
}


string sanity_checking(mapping m)
{
 mixed error=catch {
   if(!m->textstyle->activestyles->middle_text)
     return "There must be a middle_text box";
   if(!m->foobar->textstyle->activestyles->middle_text)
     return "There must be a middle_text box";
   if(!sizeof(m->menuitems))
     return "No menuitems in menu";
 };
  return "";
}


string magic_image(int xsize, int ysize, string serialnum, int num, int selected,
		   mixed preload, string url, string alt, string location,
		   string status, int mouseover, int nav_id, string imagetype, object id)
{
  string s="";
  string img="img"+nav_id+"_"+(string)num;
  mixed magic_status="";
  if(status)
    magic_status=" self.status=\""+status+"\";";

  if(id->supports->netscape_javascript&&mouseover)
  {
    s+="<script>\n";
    s+=sprintf("  %sl = new Image(%d,%d); %sl.src = \"%s/%d/%s/_.%s\";\n",
	       img,xsize,ysize,img,location+serialnum,
	       num,selected?"text_selected":"text",imagetype);
    s+=sprintf("  %sh = new Image(%d,%d); %sh.src = \"%s/%d/%s/_.%s\";\n",
	       img,xsize,ysize,img,location+serialnum,
	       num,"text_mouseover",imagetype);
    s+="</script>";
    s+=sprintf("<a href=\"%s\" onMouseover='document.images[\"%s\"].src"
	       " = %sh.src;",
	       url,img,img);
    if(status)
      s+=" self.status=\""+status+"\";";

    if(sizeof(id->misc->magic))
      foreach(indices(id->misc->magic), string name)
	s+=sprintf(" document.images[\"magic_img_%s\"].src = magic_img_%s_%d.src;",
		   name,name,num);

    s+=sprintf(" return true;' onMouseout='document.images[\"%s\"].src"
	       " = %sl.src;",img,img);

    if(sizeof(id->misc->magic))
      foreach(indices(id->misc->magic), string name)
	s+=sprintf(" document.images[\"magic_img_%s\"].src = magic_img_%s_normal.src;",
		   name,name);
    s+=sprintf("'><img width=%d height=%d src=\"%s/%d/%s/_.%s\""
	       " border=0 name=img%d_%d alt=\"%s\"></a>",
	       xsize,ysize,location+serialnum,num,
	       (selected?"text_selected":"text"),
	       imagetype,nav_id,num,alt);
  } 
  else
    s+="<a href=\""+url+"\"><img width="+xsize+" height="+ysize+" src=\""+
      location+serialnum+"/"+(string)num+"/"+(selected?"text_selected":"text")+
      "/_."+imagetype+"\" border=0  alt=\""+alt+"\"></a>";
    
  return s;
}

string unique_encode(mixed m)
{
  switch(sprintf("%t",m))
  {
   case "string":
   case "int":
   case "float":
   case "array":  // only works with array(string)
    return encode_value(m)+"\0";

   case "mapping":  // only works with string:mixed mappings..
    array a = indices(m);
    array b = values(m);
    sort(a,b);
    string res="";
    foreach(a, string index)
         res+=unique_encode(m[index]);
    return a*"\0"+"\0"+res;
  }
}

string unique_encode_mapping_fast(mixed m)
{
  array a = indices(m);
  array b = values(m);
  sort(a,b);
  return a*"\0"+"\0\0"+b*"\0";
}

mapping find_file(string file, object id)
{
  string cache_id;
  string result;
  int menunum;
  string menutype;
  string imagetype;
  if(sscanf(file,"%s/%s/%s/_.%s", cache_id,menunum,menutype,imagetype)<4)
    return 0;

  object f=Stdio.File();
  //werror("banan\n");
  if(!f->open(query("cachedir")+"/"+cache_id+"/"+menutype+menunum+"."+imagetype,"r"))
  {
    //werror(query("cachedir")+"/"+cache_id+"/"+menutype+menunum+"."+imagetype);
    
    return 0;
//     f->close();
//     object fi=Stdio.File();
    
//     if(!fi->open(query("cachedir")+cache_id+".info","r"))
//     {
//       return http_string_answer(
// 	load_font("")->write("Please reload this page")->togif(),"image/gif")
// 	| ([ "extra_heads":
// 	     (["Expires": http_date(0),
// 	       "Last-Modified": http_date(time(1)) ]) ]);
//     }
    
//     mapping args=decode_value(fi->read());
//     m_delete(args,"dims");
//     fi->close();
    
//     if(args->horiz)
//       draw_images_horiz(cache_id,args, id);
//     else
//       draw_images_vert(cache_id,args, id);
  }
  return http_file_answer(f,"image/"+imagetype);
}


array fix_menuitem_args(array args)
{
  args = copy_value(args);
  foreach(args, mapping mi) m_delete(mi, "selected");
  return args;
}

string container_navigation(string tag_name, mapping args, string contents,
			  object id, object file, mapping defines)
{
  if(args->version)
    return
      "$Id$"+
      contents;
  if(args->zapcache)
  {
    zapcaches();
    return contents;
  }
  if(args->debug)
  {
    string res="<pre>"+nav_debug_string+"</pre>"+contents;
    nav_debug_string="";
    return res;
  }
  id->misc->nav_id++;
  string name = query_location();
  int selected=-1;
  int cache_id;
  string s="";

  contents = parse_rxml(contents, id);

#if use_contents_cache  
  object md5 = Crypto.md5();
  md5->update(contents+"\0"+
	      unique_encode_mapping_fast(args)+"\0"+
	      (string)id->supports->netscape_javascript+"\0"+
	      (string)id->supports->jpeginline+"\0"+
	      (string)id->supports->pnginline+"\0"+
	      (string)id->supports->images+"\0"+
	      (string)id->misc->nav_id);
  
  string key=md5->digest();
  if(contents_cache[key]&&!id->pragma["no-cache"])
    return contents_cache[key];
#endif  
  

  id->misc->menuitems = ({});
  id->misc->boxstyles = ([]);
  id->misc->magic = ([]);
  id->misc->activestyles = ([]);
  id->misc->boxstyles->textstyle=([  "font"     : "",
				     "scale"    : 0.5,
				     "maxwidth" : 0x7fffffff,
				     "spacing"  : 5,
				     "xspacing" : 5,
				     "yspacing" : 5,
				     "bevel"    : 0,
				     "left"     : 1,
				     "center"   : 0,
				     "right"    : 0,
				     "textbg"   : "lightblue",
				     "textbgsel": "darkblue" ]);

  if(!args->imgbase)
    args->imgbase="";
  args->bodybg=defines->bg||"#ffffff";

  string substr;
  substr=parse_html(contents,
		    ([ "boxstyle"  : callback_boxstyle,
		       "textstyle" : callback_textstyle,
		       "magic"     : callback_magic
		    ]), 
 		    ([ "mi"        : callback_mi,
		       "submenu"   : callback_navigation
		    ]), id, args);

//   ndebug("boxstyles: %O",mkmapping(indices(id->misc->boxstyles),
// 				   values(id->misc->boxstyles)));

  if(sizeof(id->misc->menuitems)==0)
  {
    s="";
#if use_contents_cache  
    if(id->pragma["no-cache"]&&contents_cache[key]!=s)  //Invalidate cache
      contents_cache=([]);
    contents_cache[key]=s;
#endif    
    return s;
  }
  
  if(id->misc->mouseover)
    args->mouseover=1;
  if(id->misc->selected)
    args->selected=1;

   if(!args->maxwidth)
     args->maxwidth=id->misc->boxstyles->textstyle->maxwidth;
  if(id->misc->boxstyles->textstyle->right)
    args->right=1;
  if(id->misc->boxstyles->textstyle->center)
    args->center=1;
  
  int subnum=-1;
  string submenu="";
  sscanf(substr,"%d_%s",subnum,submenu);
  subnum--;

  if(id->misc->boxstyles->textstyle->spacing)
  {
    id->misc->boxstyles->textstyle->xspacing=id->misc->boxstyles->textstyle->spacing;
    id->misc->boxstyles->textstyle->yspacing=id->misc->boxstyles->textstyle->spacing;
  }
  
  // Patch to make gtext font modifyers compatible with navigation.
  if(id->misc->boxstyles->textstyle->bold)
    id->misc->boxstyles->textstyle->font+=" bold";
  if(id->misc->boxstyles->textstyle->italic)
    id->misc->boxstyles->textstyle->font+=" italic";
  if(id->misc->boxstyles->textstyle->light)
    id->misc->boxstyles->textstyle->font+=" light";
  // End of patch.
  args->font=id->misc->boxstyles->textstyle->font;
  args->boxstyles = id->misc->boxstyles;
  args->activestyles= id->misc->activestyles;

  if(args->text||!id->supports->images)
  {
    args->menuitems = id->misc->menuitems;
    return draw_menu_text(args,subnum,submenu,id->supports->netscape_javascript);
  }

  args->newest_file = newest_file(args,id);
  args->default_font = (string)caudium->QUERY(default_font)+":"+
                       (string)caudium->QUERY(default_font_size);
  
  
  args->hash_menuitems=({});
  foreach(id->misc->menuitems, mapping mi)
    args->hash_menuitems += ({ mi->label });

  if(args->selected)
  {
    selected=(int)args->selected;
    m_delete(args,"selected" );
  }
  object md5 = Crypto.md5();
  md5->update(unique_encode(args));
  string hsh_s="";
  foreach(md5->digest()/"",string char)
    hsh_s+=sprintf("%02X",char[0]);
  hsh_s=lower_case(hsh_s);

  m_delete(args, "hash_menuitems");
  mapping dims;

  args->menuitems = id->misc->menuitems;
  if(!file_stat(query("cachedir")+"/"+hsh_s+"/info"))
  {
    // Sanity checking
    args->menuitems = fix_menuitem_args(id->misc->menuitems);
    if((s=sanity_checking(args))!="")
      return "<gtext scale=0.6>"+s+"</gtext>";
    if((s=(args->horiz?
	   (draw_images_horiz(hsh_s,args, id)):
	   (draw_images_vert(hsh_s,args, id))))!="")
    {
      s="Navigation error: "+s;
      return "<pre>"+s+"</pre>";
    }
    dims=id->misc->dims;
    args->dims=id->misc->dims;
    object f=Stdio.File();
    mkdir(query("cachedir")+"/"+hsh_s);
    f->open(query("cachedir")+"/"+hsh_s+"/info","wc");
    f->write(encode_value(args));
    f->close();
  }
  else
  {       // read dims
    object f=Stdio.File();
    f->open(query("cachedir")+hsh_s+"/info","r");
    args=decode_value(f->read());
    f->close();
    dims=args->dims;
    args->menuitems = id->misc->menuitems;
  }
  m_delete(args,"dims");

  ndebug(dims);
  
  int xsize=dims->left+dims->middle+dims->right;

  // magic images
  args->menuitems = id->misc->menuitems;


  if(sizeof(id->misc->magic)&&id->supports->netscape_javascript)
  {
    s+="<script>\n";
    foreach(indices(id->misc->magic), string name)
    {
      mapping a=id->misc->magic[name];
      for(int i=0; i<dims->menusize; i++)
      {
	s+=sprintf("  magic_img_%s_%d = new Image(%d,%d);",
		   a->name,i,(int)a->width,(int)a->height);
	s+=sprintf(" magic_img_%s_%d.src = \"%s\";\n",
		   a->name,i,a->prefix+i+a->suffix);
	if(args->menuitems[i]->selected)
	  id->misc["magic-navigation-img-"+a->name]=a->prefix+i+a->suffix;
      }
    }
    s+="</script>\n";
  }

  string indent=(int)args->indent?
    ("<td width="+(int)args->indent+"></td>"):"";  //FIXME

  string imagetype="gif";
  if(args->jpeg && id->supports->jpeginline)
    imagetype="jpeg";
  if(args->png && id->supports->pnginline)
    imagetype="png";
  
  s+="<table border=0 cellpadding=0 cellspacing=0><tr>"+indent;

  s+="<td>";
  string tr_if_vert=args->horiz?"":"</tr><tr>";
  if(dims->top)
  {
    if(args->horiz)
      s+="<img alt='' width="+dims->top+" height="+xsize+" src=\""+name+hsh_s+
	"/-2/text/_."+imagetype+"\" border=0>";
    else
      s+="<img alt='' width="+xsize+" height="+dims->top+" src=\""+name+hsh_s+
	"/-2/text/_."+imagetype+"\" border=0>";
    s+="</td>"+tr_if_vert+indent+"<td>";
  }
  
  for(int i=0;i<dims->menusize;i++)
  {

    if(args->horiz)
      s+=magic_image(dims->positions[i+2]-dims->positions[i+1], xsize,
		     hsh_s, i, 
		     args->menuitems[i]->selected, 
		     args->preload, args->menuitems[i]->href, 
		     args->menuitems[i]->label,
		     name,args->menuitems[i]->status,
		     (args->noselectedmouseover?
		      (args->menuitems[i]->selected?0:args->mouseover)
		      :args->mouseover),id->misc->nav_id,imagetype,id);
    else
      s+=magic_image(xsize, dims->positions[i+2]-dims->positions[i+1], 
		     hsh_s, i, 
		     args->menuitems[i]->selected,
		     args->preload, args->menuitems[i]->href, 
		     args->menuitems[i]->label,
		     name,args->menuitems[i]->status, 
		     (args->noselectedmouseover?
		      (args->menuitems[i]->selected?0:args->mouseover)
		      :args->mouseover),id->misc->nav_id,imagetype,id);
    
    if(i==subnum)
    {
      s+="</td></tr></table>";
      s+=submenu;
      if(i<dims->menusize-1||dims->bottom)
	s+="<table border=0 cellpadding=0 cellspacing=0><tr>"+indent+"<td>";
    }
    else
      if(i<dims->menusize-1||dims->bottom)
	s+="</td>"+tr_if_vert+indent+"<td>";
      else
	s+="</td></tr></table>";
  }

  if(dims->bottom)
  {
    if(args->horiz)
      s+="<img alt='' width="+dims->bottom+" height="+xsize+" src=\""+name+hsh_s+
	"/-3/text/_."+imagetype+"\" border=0></a>";
    else
      s+="<img alt='' width="+xsize+" height="+dims->bottom+" src=\""+name+hsh_s+
	"/-3/text/_."+imagetype+"\" border=0></a>";
    s+="</td></tr></table>";
  }

#if use_contents_cache  
  if(id->pragma["no-cache"]&&contents_cache[key]!=s)  //Invalidate cache
    contents_cache=([]);
  contents_cache[key]=s;
#endif  
  return s;
}

string fake_container_magic(string tag_name, mapping args, string contents, object id)
{
  string rest_of_page=parse_rxml(contents,id);
  // Args:
  // name=tjosan
  // prefix=/bilder/
  // suffix=.jpg
  // width=435
  // height=34
  //  => /bilder/magic_tjosan_0.jpg
  if(!id->supports->images)
    return rest_of_page;
  
  string defaultpic="";
  if(defaultpic=id->misc["magic-navigation-img-"+args->name])
    args->src=defaultpic;
     
  if(!id->supports->netscape_javascript)
    return make_tag("img",args)+rest_of_page;

  args->name="magic_img_"+args->name;
  
  string s="<script>";
  s+=sprintf("  %s_normal = new Image(%d,%d); %s_normal.src = \"%s\";\n</script>",
	     args->name,(int)args->width, (int)args->height,args->name,args->src);
  return s+make_tag("img",args)+rest_of_page;
}

mapping query_container_callers()
{
  return ([ "navigation":container_navigation,
	    "magic-navigation-img":fake_container_magic]);
}
