/*
 * Description:
 *   This is a roxen module.
 *   Gives a <thumbnail> tag which displays a resized/cached image
 *
 * Copyright: GPL
 *
 * Authors:
 *   Chris Jantzen
 *
 * Bugs:
 *   - It does not scale images *up* to the thumbnail size. (option?)
 *   - Anybody in the world can use it. (needs referrer restrictions?)
 *   - Does Pike understand more than PNM/GIF/JPEG? It seems hackish
 *     to have to try all the different decode methods by hand.
 *
 * To Do:
 *   - It may be nice to have an href argument to autogenerate a link.
 *   - It may be worthwhile to pass through unsupported arguments so
 *     people can use more JavaScript.
 *   - (actually these are thoughts that I'm only lukewarm to)
 *
 * History:
 *   08 Oct 1998 v0.1 chris
 *     - First internal release
 *
 *   09 Oct 1998 v0.2 chris
 *     - First public release (many cosmetics)
 *
 * Comments:
 *   Some people may balk at my whitespace style. <boo-hoo> If you look
 *   closely, you'll probably note fragments of code that were liberally
 *   lifted from various other modules. ^_^
 *
 */

constant cvs_version = "$Id$";

#include <module.h>
inherit "module";
inherit "roxenlib";

import Image;
constant thread_safe = 1;

// HEX to Array Color conversion.
array (int) mkcolor(string color)
{
  int c = (int) ("0x"+(color-" "));
  return ({((c >> 16) & 0xff), ((c >>  8) & 0xff), (c & 0xff)});
}

// MODULE_LOCATION functions
mapping find_file(string f, object id)
{
  string filename, bg;
  int width, height, rot, trans;

  if(sscanf(f, "%d/%d/%s/%d/%d/$%s", trans, rot, bg, height, width,
	    filename) != 6 )
    return 0;

  // Retrieve thumbnail from cache. Load and scale, if it fails.
  object result = cache_lookup("thumbnail", f);

  if(!result) {

    int err;
    mixed t;
    string buff;

    t = id->conf->real_file(filename, id);

    if(!t) {
      return 0;
    }

    buff = Stdio.read_bytes(t);

    if(!buff) {
      return 0;
    }

    object ourimage;

    if(catch(ourimage = PNM.decode(buff))) {
      if(catch(ourimage = GIF.decode(buff))) {
	if(catch(ourimage = JPEG.decode(buff))) {
	  return 0;
	}
      }
    }

    float scale = 1.0;
    int xoffs = 0;
    int yoffs = 0;
    float xsize = (float) ourimage->xsize();
    float ysize = (float) ourimage->ysize();

    // Apply Transforms
    // result = result->copy(0, 0, result->xsize()-1, result->ysize()-1);
    if(height || width) {

      if(height && (float) height < ysize*scale) {
	scale = ((float) height)/ysize;
      }
      if(width && (float) width < xsize*scale) {
	scale = ((float) width)/xsize;
      }
      ourimage = ourimage->scale(scale);

      if(ysize*scale < (float) height) {
	yoffs = (int) (((float) height-ysize*scale)/2);
      }
      if(xsize*scale < (float) width) {
	xoffs = (int) (((float) width-xsize*scale)/2);
      }
      
    }
    
    result = image((width?width:(int) (xsize*scale)),
		   (height?height:(int) (ysize*scale)), @mkcolor(bg));

    result = result->paste(ourimage, xoffs, yoffs);

    if(rot)
      result = result->rotate(rot, @mkcolor(bg));
    
    cache_set("thumbnails", f, result);
  }

  // Apply Color Transform
  object ct = cache_lookup("thumbnail_coltables", filename);
  if(!ct) {
    // Make a suitable color table for this thumbnail.
    ct = colortable(result->copy(0, 0, result->xsize()-1, result->ysize()-1),
		    64)->cubicles(20, 20, 20);
    cache_set("thumbnail_coltables", filename, ct);
  }

  if(trans)
    return http_string_answer(GIF.encode_trans(result, ct, @mkcolor(bg)), 
			      "image/gif");
  else
    return http_string_answer(GIF.encode(result, ct), "image/gif");
}

// MODULE_TAG functions
string tag_thumbnail(string tag, mapping args, object id, object file, mapping defines)
{
  string url;
  if(!args->src) {
    url = "<br clear=\"all\"><p>Thumbnail tag needs src argument!</p>";
  }
  else {
    // Protect from people abusing the module
    int height = 0, width = 0;

    if(args->height) {
      height = (int) args->height;
      if(height > 512) {
	height = 512;
      }
    }
    if(args->width) {
      width = (int) args->width;
      if(width > 512) {
	width = 512;
      }
    }

    // Get the path if not absolute
    string filename = "";

    if(args->src[0..0] != "/") {
      array(string) parts = id->not_query/"/";
      for(int i = 0; i < sizeof(parts)-1; i++) {
	filename += parts[i]+"/";
      }
    }
    filename += args->src;

    url = "<img _parsed=\"1\" src=\""+query("mountpoint")+
      (args->trans?"1":"0")+"/"+
      (args->rot?args->rot:"0")+"/"+
      (args->bg?args->bg-"#":"ffffff")+"/"+
      height+"/"+width+"/$"+filename+"\""+
      (args->border?(" border=\""+args->border+"\""):"")+
      (args->align?(" align=\""+args->align+"\""):"")+">";
  }

  usecount++;
  return url;
}


// Required functions for Roxen modules--

int usecount;

string starttime = ctime(time());

void create()
{
  defvar("mountpoint", "/thumbnail/", "Mount point", TYPE_LOCATION, 
	 "Thumbnail result location in virtual filesystem "
	 "(trailing slash important).");

}

array register_module()
{
  return(({MODULE_PARSER | MODULE_LOCATION | MODULE_PROVIDER,
	     "Thumbnail tag",
	     "Automatic thumbnail tag (with caching)<P>"
	     "<PRE>&lt; thumbnail\n"
	     "      src=\"filename\"    | Image file location in virtual filesystem (required)\n"
	     "      height=\"y\"        | Vertical bounding size (in pixels)\n"
	     "      width=\"x\"         | Horizontal bounding size (in pixels)\n"
	     "      border=...        | Like &lt;IMG BORDER...&gt;\n"
	     "      align=...         | Like &lt;IMG ALIGN...&gt;\n"
	     "      bg=\"#rrggbb\"      | Background for thumbnail\n"
	     "      rot=\"n\"           | Rotate by n degrees\n"
	     "      trans &gt;           | Make background color transparent</PRE><P>",
	     0,
             1}));
}

string status()
{
   return "Called " + usecount + " times since " + starttime;
}

void start() // read the definitions from the config interface
{
  return;
}

string query_location()
{
  return query("mountpoint");
}

string query_provides()
{
  return "thumbnail";
} 

mapping query_tag_callers()
{
  return (["thumbnail":tag_thumbnail, "thumbnail_url":tag_thumbnail]);
}
