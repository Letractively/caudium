//  Button module. Generates graphical buttons for use in Roxen config
//  interface, Roxen SiteBuilder and other places.
//
//  Copyright © 1999-2000 Roxen IS. Author: Jonas Walldén, <jonasw@roxen.com>

constant cvs_version = "$Id$";
constant thread_safe = 1;

//
//! module: Graphics Button
//!  Provides the &lt;gbutton&gt; tag which enables one to create
//!  graphical buttons on the fly in any shape.
//
//! inherits: module
//! inherits: caudiumlib
//! inherits: images
//
//! type: MODULE_PARSER
//
//! cvs_version: $Id$
//

#include <module.h>
inherit "images";
inherit "module";
inherit "caudiumlib";

caudium.ImageCache  button_cache;

constant module_type = MODULE_PARSER | MODULE_PROVIDER;
constant module_name = "GButton";
constant module_doc  = 
"Provides the <tt>&lt;gbutton&gt;</tt> tag that is used to draw graphical "
"buttons.";

#define ST_MTIME 3

string query_provides() {
  return("gbutton");
}


function TIMER( function f )
{
#if 0
    return lambda(mixed ... args) {
               int h = gethrtime();
               mixed res;
               werror("Drawing ... ");
               res = f( @args );
               werror(" %.1fms\n", (gethrtime()-h)/1000000.0 );
               return res;
           };
#endif
    return f;
}

void start()
{
    button_cache = caudium.ImageCache("gbutton", TIMER(draw_button));
}

#if 0
string status() {
  array s=button_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n<b>Cache size:</b> %s",
		 s[0]/2, sizetostring(s[1]));
}
#endif

#ifndef CAUDIUM
//
// This is used in Roxen 2.x config interface
//
mapping(string:function) query_action_buttons() {
    return ([ "Clear cache":flush_cache ]);
}
#endif

void flush_cache() {
    button_cache->flush();
}

Image.Layer layer_slice( Image.Layer l, int from, int to )
{
    return Image.Layer( ([
        "image":l->image()->copy( from,0, to-1, l->ysize()-1 ),
        "alpha":l->alpha()->copy( from,0, to-1, l->ysize()-1 ),
    ]) );
}

Image.Layer stretch_layer( Image.Layer o, int x1, int x2, int w )
{
    Image.Layer l, m, r;
    int leftovers = w - (x1 + (o->xsize()-x2) );
    object oo = o;

    l = layer_slice( o, 0, x1 );
    m = layer_slice( o, x1+1, x2-1 );
    r = layer_slice( o, x2, o->xsize() );

    m->set_image( m->image()->scale( leftovers, l->ysize() ),
                  m->alpha()->scale( leftovers, l->ysize() ));

    l->set_offset(  0,0 );
    m->set_offset( x1,0 );
    r->set_offset( w-r->xsize(),0 );
    o = Image.lay( ({ l, m, r }) );
    o->set_mode( oo->mode() );
    o->set_alpha_value( oo->alpha_value() );
    return o;
}

array(Image.Layer) draw_button(mapping args, string text, object id)
{
    Image.Image  text_img;
    mapping      icon;

    Image.Layer background;
    Image.Layer frame;
    Image.Layer mask;

    int left, right, top, middle, bottom; /* offsets */
    int req_width;

    mapping ll = ([]);
    
    void set_image( array layers )
    {
        foreach( layers||({}), object l )
        {
            if(!l->get_misc_value( "name" ) ) // Hm. Probably PSD
                continue;

            ll[lower_case(l->get_misc_value( "name" ))] = l;
            switch( lower_case(l->get_misc_value( "name" )) )
            {
                case "background": background = l; break;
                case "frame":      frame = l;     break;
                case "mask":       mask = l;     break;
            }
        }
    };
    
    if( args->border_image )
        set_image( load_layers(args->border_image, id) );

    //  otherwise load default images
    if ( !frame )
    {
        string data = Stdio.read_file("caudium-images/gbutton.xcf");
        if (!data)
            error ("Failed to load default frame image "
                   "(caudium-images/gbutton.xcf): " + strerror (errno()));
        mixed err = catch {
            set_image(Image.XCF.decode_layers(data));
        };
        if( !frame )
            if (err) {
                catch (err[0] = "Failed to decode default frame image "
                       "(caudium-images/gbutton.xcf): " + err[0]);
                throw (err);
            }
            else
                error("Failed to decode default frame image "
                      "(caudium-images/gbutton.xcf).\n");
    }


    // Translate frame image to 0,0 (left layers are most likely to the
    // left of the frame image)
    

    int x0 = frame->xoffset();
    int y0 = frame->yoffset();
    if( x0 || y0 )
        foreach( values( ll ), object l )
        {
            int x = l->xoffset();
            int y = l->yoffset();
            l->set_offset( x-x0, y-y0 );
        }

    if( !mask )
        mask = frame;

    array x = ({});
    array y = ({});
    foreach( frame->get_misc_value( "image_guides" ), object g )
        if( g->pos < 4096 )
            if( g->vertical )
                x += ({ g->pos-x0 });
            else
                y += ({ g->pos-y0 });

    sort( y );
    sort( x );

    if(sizeof( x ) < 2)
        x = ({ 5, frame->xsize()-5 });

    if(sizeof( y ) < 2)
        y = ({ 2, frame->ysize()-2 });

    left = x[0]; right = x[-1];    top = y[0]; middle = y[1]; bottom = y[-1];
    right = frame->xsize()-right;

    //  Text height depends on which guides we should align to
    int text_height;
    switch (args->icva) {
        case "above":
            text_height = bottom - middle;
            break;
        case "below":
            text_height = middle - top;
            break;
        default:
        case "middle":
            text_height = bottom - top;
            break;
    }

    //  Get icon
    if (args->icn)
        icon = low_load_image(args->icn, id);
    else if (args->icd)
        icon = low_decode_image(args->icd);

    int i_width = icon && icon->img->xsize();
    int i_height = icon && icon->img->ysize();
    int i_spc = i_width && sizeof(text) && 5;

    //  Generate text
    if (sizeof(text))
    {
        int os, dir;
        object button_font;
        int th = text_height;
        do
        {

			if( args->afont ) {
				button_font = resolve_font( args->afont+" "+th );
			} else {
				if(!args->nfont) args->nfont = args->font;
				int bold, italic;
				if(args->bold) bold=1;
				if(args->light) bold=-1;
				if(args->black) bold=2;
				if(args->italic) italic=1;
				button_font = get_font(args->nfont||"default",
						(int)args->font_size||32,bold,italic,
						lower_case(args->talign||"left"),
						(float)(int)args->xpad, (float)(int)args->ypad);
							
			}
	    if (!button_font)
		error("Failed to load font for gbutton");
            
	    text_img = button_font->write(@( args->encoding 
	    		? (Locale.Charset.decoder(args->encoding)->
			  feed(text)->drain())/"\n" 
			: text/"\n" ));
            
	    os = text_img->ysize();
            if( !dir )
                if( os < text_height )
                    dir = 1;
                else if( os > text_height )
                    dir =-1;
            if( dir > 0 && os > text_height ) break;
            else if( dir < 0 && os < text_height ) dir = 1;
            else if( os == text_height ) break;
            th += dir;
        } while( (text_img->ysize() - text_height)
                 && (th>0 && th<text_height*2));

        // fonts that can not be scaled.
        if( abs(text_img->ysize() - text_height)>2 )
            text_img = text_img->scale(0, text_height );
        else
        {
            int o = text_img->ysize() - text_height; 
            top -= o;
            middle -= o/2;
        }
        if (args->cnd)
            text_img = text_img->scale((int) round(text_img->xsize() * 0.8),
                                       text_img->ysize());
    }

    int t_width = text_img && text_img->xsize();

    //  Compute text and icon placement. Only incorporate icon width/spacing if
    //  it's placed inline with the text.
    req_width = t_width + left + right;
    if ((args->icva || "middle") == "middle")
        req_width += i_width + i_spc;
    if (args->wi && (req_width < args->wi))
        req_width = args->wi;

    int icn_x, icn_y, txt_x, txt_y;

    //  Are text and icon lined up or on separate lines?
    switch (args->icva) {
        case "above":
        case "below":
            //  Note: This requires _three_ guidelines! Icon and text can only be
            //  horizontally centered
            icn_x = left + (req_width - right - left - i_width) / 2;
            txt_x = left + (req_width - right - left - t_width) / 2;
            if (args->icva == "above") {
                txt_y = middle;
                icn_y = top + (middle - top - i_height) / 2;
            } else {
                txt_y = top;
                icn_y = middle + (bottom - middle - i_height) / 2;
            }
            break;

        default:
        case "middle":
            //  Center icon vertically on same line as text
            icn_y = icon && (frame->ysize() - icon->img->ysize()) / 2;
            txt_y = top;
    
            switch (args->al)
            {
                case "left":
                    //  Allow icon alignment: left, right
                    switch (args->ica)
                    {
                        case "left":
                            icn_x = left;
                            txt_x = icn_x + i_width + i_spc;
                            break;
                        default:
                        case "right":
                            txt_x = left;
                            icn_x = req_width - right - i_width;
                            break;
                    }
                    break;

                default:
                case "center":
                case "middle":
                    //  Allow icon alignment:
                    //  left, center, center-before, center-after, right
                    switch (args->ica)
                    {
                        case "left":
                            icn_x = left;
                            txt_x = (req_width - right - left - i_width - i_spc - t_width) / 2;
                            txt_x += icn_x + i_width + i_spc;
                            break;
                        default:
                        case "center":
                        case "center_before":
                        case "center-before":
                            icn_x = (req_width - i_width - i_spc - t_width) / 2;
                            txt_x = icn_x + i_width + i_spc;
                            break;
                        case "center_after":
                        case "center-after":
                            txt_x = (req_width - i_width - i_spc - t_width) / 2;
                            icn_x = txt_x + t_width + i_spc;
                            break;
                        case "right":
                            icn_x = req_width - right - i_width;
                            txt_x = left + (icn_x - i_spc - t_width) / 2;
                            break;
                    }
                    break;
      
                case "right":
                    //  Allow icon alignment: left, right
                    switch (args->ica)
                    {
                        default:
                        case "left":
                            icn_x = left;
                            txt_x = req_width - right - t_width;
                            break;
                        case "right":
                            icn_x = req_width - right - i_width;
                            txt_x = icn_x - i_spc - t_width;
                            break;
                    }
                    break;
            }
            break;
    }

    if( args->extra_frame_layers )
    {
        array l = ({ });
        foreach( args->extra_frame_layers/",", string q )
            l += ({ ll[q] });
        l-=({ 0 });
        if( sizeof( l ) )
            frame = Image.lay( l+({frame}) );
    }

    if( args->extra_mask_layers )
    {
        array l = ({ });
        foreach( args->extra_mask_layers/",", string q )
            l += ({ ll[q] });
        l-=({ 0 });
        if( sizeof( l ) )
        {
            if( mask )
                l = ({ mask })+l;
            mask = Image.lay( l );
        }
    }

    right = frame->xsize()-right;
    if (mask != frame)
    {
        Image.Image i = mask->image();
        Image.Image m = mask->alpha();
        int x0 = -mask->xoffset();
        int y0 = -mask->yoffset();
        int x1 = frame->xsize()-1+x0;
        int y1 = frame->ysize()-1+y0;
    
        i = i->copy(x0,y0, x1,y1);
        if( m )
            m = m->copy(x0,y0, x1,y1);
        mask->set_image( i, m );
        mask = stretch_layer( mask, left, right, req_width );
    }
    frame = stretch_layer( frame, left, right, req_width );
    array(Image.Layer) button_layers = ({
        Image.Layer( Image.Image(req_width, frame->ysize(), args->bg),
                     mask->alpha()->copy(0,0,req_width-1,frame->ysize()-1)),
    });


    if( args->extra_background_layers || background)
    {
        array l = ({ background });
        foreach( (args->extra_background_layers||"")/","-({""}), string q )
            l += ({ ll[q] });
        l-=({ 0 });
        foreach( l, object ll )
        {
            if( args->dim )
                ll->set_alpha_value( 0.3 );
            button_layers += ({ stretch_layer( ll, left, right, req_width ) });
        }
    }


    button_layers += ({ frame });
    frame->set_mode( "value" );

    if( args->dim )
    {
        //  Adjust dimmed border intensity to the background
        int bg_value = Image.Color(@args->bg)->hsv()[2];
        int dim_high, dim_low;
        if (bg_value < 128) {
            dim_low = max(bg_value - 64, 0);
            dim_high = dim_low + 128;
        } else {
            dim_high = min(bg_value + 64, 255);
            dim_low = dim_high - 128;
        }
        frame->set_image(frame->image()->
                         modify_by_intensity( 1, 1, 1,
                                              ({ dim_low, dim_low, dim_low }),
                                              ({ dim_high, dim_high, dim_high })),
                         frame->alpha());
    }

    //  Draw icon.
    if (icon)
        button_layers += ({
            Image.Layer( ([
                "alpha_value":(args->dim ? 0.3 : 1.0),
                "image":icon->img,
                "alpha":icon->alpha,
                "xoffset":icn_x,
                "yoffset":icn_y
            ]) )});

    //  Draw text
    if(text_img)
        button_layers += ({
            Image.Layer(([
                "alpha_value":(args->dim ? 0.5 : 1.0),
                "image":text_img->color(0,0,0)->invert()->color(@args->txt),
                "alpha":text_img,
                "xoffset":txt_x,
                "yoffset":txt_y,
            ]))
        });

    // 'plain' extra layers are added on top of everything else
    if( args->extra_layers )
    {
        array q = map(args->extra_layers/",",
                      lambda(string q) { return ll[q]; } )-({0});
        foreach( q, object ll )
        {
            if( args->dim )
                ll->set_alpha_value( 0.3 );
            button_layers += ({stretch_layer(ll,left,right,req_width)});
            button_layers[-1]->set_offset( 0,
                                           button_layers[0]->ysize()-
                                           button_layers[-1]->ysize() );
        }
    }

    button_layers  -= ({ 0 });
    // left layers are added to the left of the image, and the mask is
    // extended using their mask. There is no corresponding 'mask' layers
    // for these, but that is not a problem most of the time.
    if( args->extra_left_layers )
    {
        array l = ({ });
        foreach( args->extra_left_layers/",", string q )
            l += ({ ll[q] });
        l-=({ 0 });
        l->set_offset( 0, 0 );
        if( sizeof( l ) )
        {
            object q = Image.lay( l );
            foreach( button_layers, object b )
            {
                int x = b->xoffset();
                int y = b->yoffset();
                b->set_offset( x+q->xsize(), y );
            }
            q->set_offset( 0, button_layers[0]->ysize()-q->ysize() );
            button_layers += ({ q });
        }
    }

    // right layers are added to the right of the image, and the mask is
    // extended using their mask. There is no corresponding 'mask' layers
    // for these, but that is not a problem most of the time.
    if( args->extra_right_layers )
    {
        array l = ({ });
        foreach( args->extra_right_layers/",", string q )
            l += ({ ll[q] });
        l-=({ 0 });
        l->set_offset( 0, 0 );
        if( sizeof( l ) )
        {
            object q = Image.lay( l );
            q->set_offset( button_layers[0]->xsize()+
                           button_layers[0]->xoffset(),
                           button_layers[0]->ysize()-q->ysize());
            button_layers += ({ q });
        }
    }

//   if( !equal( args->pagebg, args->bg ) )
//   {
    // FIXME: fix transparency (somewhat)
    // this version totally destroys the alpha channel of the image,
    // but that's sort of the intention. The reason is that
    // the png images are generated without alpha.
    if (args->format == "png")
        return ({ Image.Layer(([ "fill":args->pagebg, ])) }) + button_layers;
    else
        return button_layers;
//   }
}


mapping find_internal(string f, object id)
{
    return button_cache->http_file_answer(f, id);
}

static array mk_url(object id, mapping args, string contents)
{
    string fi = args["frame-image"] || 
		( id->misc->defines["gbutton-frame-image"] 
		  	? id->misc->defines["gbutton-frame-image"] : 0);

    if (fi)
           fi = fix_relative(fi, id);

    args->icon_src = args["icon-src"] || args->icon_src || "";
    args->icon_data = args["icon-data"] || args->icon_data || "";
    args->align_icon = args["align-icon"] || args->align_icon || "";
    args->valign_icon = args["valign-icon"] || args->valign_icon || "middle";
    m_delete(args, "icon-src");
    m_delete(args, "icon-data");
    m_delete(args, "align-icon");
    m_delete(args, "valign-icon");

    /*
     * In the original module the entire mapping was created with all
     * the attributes - whether they existed or not. This, if the
     * atribute was zero_type() caused the Stdio.write to fail. The
     * code in ImageCache tests for that case now, but I felt that
     * adding non-existent attributes to the mapping below doesn't
     * make sense anyway, so I made it the way it is below.
     * /grendel
     */
    mapping new_args = ([
        "pagebg": Colors.parse_color(args->pagebgcolor ||
                              (id->misc->defines ? id->misc->defines->bgcolor : 0) ||
                              args->bgcolor ||
                              "#eeeeee"),
        "bg": Colors.parse_color(args->bgcolor ||
                          (id->misc->defines ? id->misc->defines->bgcolor : 0) ||
                          "#eeeeee"),
        "txt": Colors.parse_color(args->textcolor ||
                           (id->misc->defines ? id->misc->defines->fgcolor : 0) ||
                           "#000000"),
        "al": args->align || "left",
        "ica": lower_case(args->align_icon || "left"),
        "icva": lower_case(args->valign_icon || "middle"),
        "font": (args->font || (id->misc->defines ? id->misc->defines->font : 0) || caudium->query("default_font")),
        "format": args->format || "gif",
    ]);

    if (args->width)
        new_args->wi = (int)args->width;

    if (args->dim || (<"dim", "disabled">)[lower_case(args->state || "")])
        new_args->dim = "yes";

    if (args->icon_src) 
        new_args->icn = fix_relative(args->icon_src, id);

    if (args->icon_data)
        new_args->icd =  args->icon_data;        

    if (fi)
        new_args->border_image =fi;

    if (args["extra-layers"])
        new_args->extra_layers = args["extra-layers"];

    if (args["extra-left-layers"])
        new_args->extra_left_layers = args["extra-left-layers"];

    if (args["extra-right-layers"])
        new_args->extra_right_layers = args["extra-right-layers"];

    if (args["extra-background-layers"])
        new_args->extra_background_layers = args["extra-background-layers"];

    if (args["extra-mask-layers"])
        new_args->extra_mask_layers = args["extra-mask-layers"];

    if (args["extra-frame-layers"])
        new_args->extra_frame_layers = args["extra-frame-layers"];

    if (args->scale)
        new_args->scale = args["scale"];

    if (args->format)
        new_args->format = args["format"];

    if (args->gamma)
        new_args->gamma = args["gamma"];

    if (args->crop)
        new_args->crop = args["crop"];

    if (args->condensed || (lower_case(args->textstyle || "") == "condensed"))
        new_args->condensed = "yes";

    if (args->encoding) 
    	new_args->encoding=args["encoding"];
    
    new_args->quant = args->quant || 128;
    
    foreach(glob("*-*", indices(args)), string n)
        new_args[n] = args[n];

    string img_src = query_internal_location() +
        button_cache->store(({new_args, contents}), id);

    return ({img_src, new_args});
}

//
//! container: gbutton
//!  Creates graphical buttons.
//
//! attribute: [pagebgcolor=color]
//!  Set the page background color. If missing, the value is taken from 
//!  the bgcolor define (if present), from the bgcolor attribute to this
//!  container or set to <tt>#eeeeee</tt> as the last resort.
//! default: #eeeeee
//
//! attribute: [bgcolor=color]
//!  Sets the background for the button. If missing, the value is taken
//!  from the bgcolor define (if present), from the bgcolor attribute to
//!  this container or set to <tt>#eeeeee</tt> as the last resort.
//! default: #eeeeee
//
//! attribute: [textcolor=color]
//!  Sets the color of the text for the button. If missing, the value is taken
//!  from the fgcolor define (if present) or set to <tt>#000000</tt> 
//!  as the last resort.
//! default: #000000
//
//! attribute: [frame-image=path]
//!  Specifies the XCF image to be used as a frame for the button. The image is
//!  required to have at least the following layers: background, mask and frame.
//!  Caudium ships with two images of that kind - the default gbutton canvas
//!  (use path: /(internal,image)/gbutton.xcf) or the tab image canvas
//!  (use path: /(internal,image)/tabframe.xcf).
//! default: /(internal,image)/gbutton.xcf
//
//! attribute: [alt=string]
//!  Alternative button text.
//
//! attribute: [href=URI]
//!  Sets the button URI.
//
//! attribute: [textstyle={normal, condensed}]
//!  Sets the text output style, either <em>normal</em> or <em>condensed</em>
//!  spacing.
//! default: normal
//
//! attribute: [width=integer]
//!  Sets the maximum button width. Defaults to no limit.
//
//! attribute: [align={left, center, right}]
//!  Sets the text alignment. There are some restrictions when text alignment is either 
//!  <em>left</em> or <em>right</em> - the icons, if used, must also be aligned in 
//!  the same way as the text.
//! default: left
//
//! attribute: [state={enabled, disabled}]
//!  Sets the button state. Note that if state is <em>disabled</em> and you have
//!  used the <tt>href</tt> attribute, no anchor will be generated.
//! default: enabled
//
//! attribute: [icon-src=URI]
//!  Fetch the icon image from the given URI.
//
//! attribute: [icon-data=CDATA]
//!  The attribute contents will be used as the icon inline data.
//
//! attribute: [align-icon={left,center-before,center-after,right}]
//!  Sets the icon alignment:<br />
//!    
//!   <deftable>
//!	<row name="left">Place the icon on the left side of the text</row>
//!     <row name="center-before">Center the icon before the text. Requires the
//!                               <em>align="center"</em> attribute.</row>
//!     <row name="center-after">Center the icon after the text. Requires the
//!                               <em>align="center"</em> attribute.</row>
//!     <row name="right">Place the icon on the right side of the text</row>
//!   </deftable>
//! default: left
//
//! attribute: [valign-icon={above,middle,below}]
//!  Sets the icon vertical alignment. Requires three horizontal guidelines
//!  in the frame image. If set to <tt>above</tt>, the icon is placed between
//!  the first and the second guideline and the text goes inbetween the second
//!  and third one. If set to <tt>below</tt> the order is reversed. <tt>middle</tt>
//!  means neutral placement.
//! default: middle
//
//! attribute: [font=fontname]
//!  Sets the font for this button.
//! default: the default font as set in the Config Interface
//
//! attribute: [extra-layers={[], [first,last], [selected,unselected], [background,mask,frame,left,right]}]
//
//! attribute: [extra-left-layers={[], [first,last], [selected,unselected], [background,mask,frame,left,right]}]
//
//! attribute: [extra-right-layers={[], [first,last], [selected,unselected], [background,mask,frame,left,right]}]
//
//! attribute: [extra-background-layers={[], [first,last], [selected,unselected],[background,mask,frame,left,right]}]
//
//! attribute: [extra-mask-layers={[], [first,last], [selected,unselected], [background,mask,frame,left,right]}]
//
//! attribute: [extra-frame-layers={[], [first,last], [selected,unselected], [background,mask,frame,left,right]}]
//
//! attribute: [format={gif, jpeg, avs, bmp, gd, hrz, ilbm, pcx, pnm, ps, pvr, tga, tiff, wbf, xbm, xpm}]
//!  Sets the output format of the generated image:
//!
//!  <deftable>
//!     <row name="gif">Graphics Interchange Format</row>
//!     <row name="jpeg">Joint Photography Expert Group image compression</row>
//!     <row name="avs"></row>
//!     <row name="bmp">Windows or OS/2 BitMaP file</row>
//!     <row name="gd"></row>
//!     <row name="hrz">HRZ is (was?) used fo amateur radio slow-scan TV</row>
//!     <row name="ilbm"></row>
//!     <row name="pcx">Zsoft PCX file format (PC/DOS)</row>
//!     <row name="pnm">Portable aNy Map</row>
//!     <row name="ps">Adobe PostScript file</row>
//!     <row name="pvr">Power VR (dreamcast image)</row>
//!     <row name="tga">True Vision Targa (PC/DOS)</row>
//!     <row name="tiff">Tagged Image File Format</row>
//!     <row name="wbf">WAP Bitmap File</row>
//!     <row name="xbm">XWindows BitMap file</row>
//!     <row name="xpm">XWindows PixMap file</row>
//!  </deftable>
//! default: png
//
//! attribute: [quant=integer]
//!  Sets the quantization level of the generated image (i.e. the number of colors
//!  in the image's color map). Most image formats don't need this parameter and
//!  effectively ignore it. Only the indexed formats use colortables - those formats
//!  are, among others, GIF and PCX. For gif the default value is 32.
//
//! attribute: [dither={none,random,floyd-tsteinberg}]
//!  Sets the dithering method.
//!  
//!    <deftable>
//!       <row name="none">No dithering is performed at all</row>
//!       <row name="random">Random scatter dither. Not visually pleasing, but it is
//!                          useful for very high resolution printing</row>
//!       <row name="floyd-steinberg">Error diffusion dithering. Usually the best
//!                                   dithering method.</row>
//!    </deftable>
//! default: none
//
//! attribute: [true-alpha]
//!  If present, render a real alpha channel instead of on/off alpha. If the file
//!  format supports only the on/off alpha the alpha channel is dithered using
//!  the floyd-steinberg dithering algorithm.
//
//! attribute: [background-color=color]
//!  Set the color to render the image against.
//! default: taken from the page
//
//! attribute: [opaque-value=percentage]
//!  The transparency value to use, 100 is fully opaque and 0 is fully transparent.
//! default: 100
//
//! attribute: [cs-rgb-hsv={0,1}]
//!  Perform the RGB to HSV colorspace conversion
//! default: 0
//
//! attribute: [gamma=float-number]
//!  Perform gamma adjustment.
//! default: 1.0
//
//! attribute: [cs-grey={0,1}]
//!  Perform the RGB to greyscale colorspace conversion
//! default: 0
//
//! attribute: [cs-invert={0,1}]
//!  Invert all colors.
//! default: 0
//
//! attribute: [cs-hsv-rgb={0,1}]
//!  Perform the HSV to RGB colorspace conversion.
//! default: 0
//
//! attribute: [rotate-cw=number]
//!  Rotate the image clock-wise.
//! default: 0
//
//! attribute: [rotate-ccw=number]
//!  Rotate the image counter clock-wise.
//! default: 0
//
//! attribute: [rotate-unit={rad,deg,ndeg,part}]
//!  Select the unit to use when rotating.
//!  
//!    <deftable>
//!       <row name="rad">Radians</row>
//!       <row name="deg">Degrees</row>
//!       <row name="ndeg">'New' degrees (400 for each full rotation)</row>
//!       <row name="part">0 - 1.0 (1.0 == full rotation)</row>
//!    </deftable>
//! default: deg
//
//! attribute: [mirror-x={0,1}]
//!  Mirror the image around the X-axis.
//! default: 0
//
//! attribute: [mirror-y={0,1}]
//!  Mirror the image around the Y-axis.
//! default: 0
//
//! attribute: [scale=factor|x,y]
//!  Scale the image by the specified value (0.5 -> half the size, 2.0 -> double the size).
//!  If the second form is used (x,y) then scale the image exactly to be x pixels wide
//!  and y pixels tall.
//! default: 1.0
//
//! attribute: [max-width=number]
//!  Set the maximum width of the image to this value. If the image width exceedes this
//!  amount it will be scaled down while keeping the aspect.
//
//! attribute: [max-height=number]
//!  Set the maximum height of the image to this value. If the image height exceedes this
//!  amount it will be scaled down while keeping the aspect.
//
//! attribute: [x-offset=number]
//!  Cut 'number' pixels from the beginning of the X scale.
//! default: 0
//
//! attribute: [y-offset=number]
//!  Cut 'number' pixels from the beginning of the Y scale.
//! default: 0
//
//! attribute: [x-size=number]
//!  Keep 'number' pixels from the beginning of the X scale.
//! default: entire image
//
//! attribute: [y-size=number]
//!  Keep 'number' pixels from the beginning of the Y scale.
//! default: entire image
//
//! attribute: [crop=x0,y0-x1,y1]
//!  Crop the image to the rectangle specified by the coordinates given.
//! default: keep entire image intact
//
//! attribute: [jpeg-quality=percentage]
//!  Set the quality of the output jpeg image.
//! default: 75
//
//! attribute: [jpeg-optimize={0,1}]
//!  If 0, do not generate optimal tables. Somewhat faster but produces bigger
//!  files.
//! default: 1
//
//! attribute: [jpeg-progressive={0,1}]
//!  Generate progressive jpeg images if set to 1.
//! default: 0
//
//! attribute: [jpeg-smooth=0-100]
//!  Smooth the image while compressing it. This produces smaller files but might
//!  undo the effects of dithering.
//! default: 0
//
//! attribute: [bmp-bpp={1,4,8,24}]
//!  Set the Bits Per Pixel value for BMP images.
//! default: 24
//
//! attribute: [bmp-windows={0,1}]
//!  Set whether the Windows (1) or OS/2 (0) mode BMP files are to be produced.
//! default: 1
//
//! attribute: [bmp-rle={0,1}]
//!  Whether or not to use the RLE (Run-Length Encoding) compression of the BMP
//!  image.
//! default: 0
//
//! attribute: [gd-alpha_index=color]
//!  Color index into the image's colormap to make transparent in the GD images with
//!  alpha channel.
//! default: 0
//
//! attribute: [pcx-raw={0,1}]
//!  If 1 do not RLE-encode he PCX image.
//! default: 0
//
//! attribute: [pcx-dpy={0-10000000.0}]
//!  Resolution, in pixels per inch.
//! default: 0.75
//
//! attribute: [pcx-xdpy={0-10000000.0}]
//!  Resolution, in pixels per inch.
//! default: 0.75
//
//! attribute: [encoding=charset]
//!  text encoding, like iso-8859-1, iso-8859-2, UTF-8, etc...
//!    see also pike's Locale.Charset module for supported encodings
//! default: not-set
//

string tag_gbutton(string tag, mapping args, string contents,
                   object id, object|void foo, mapping|void defines)
{
    string result = "";
    string img_align = args["img-align"];
    m_delete(args, "img-align");

    [string img_src, mapping new_args] = mk_url(id, args, contents);

    mapping img_attrs = ([ "src" : img_src,
                           "alt" : args->alt || contents,
                           "border" : args->border || "",
                           "hspace" : args->hspace || "",
                           "vspace" : args->vspace || "" ]);

    if (img_align)
        img_attrs->align = img_align;

    if (mapping size = button_cache->metadata(new_args, id, 1)) {
        img_attrs->width = size->xsize;
        img_attrs->height = size->ysize;
    }

    result = make_tag("img", img_attrs);

    if (args->href && !new_args->dim)
    {
        mapping a_attrs = ([ "href" : args->href ]);

        foreach(indices(args), string arg)
            if (has_value("target/onmousedown/onmouseup/onclick/ondblclick/"
                          "onmouseout/onmouseover/onkeypress/onkeyup/"
                          "onkeydown" / "/", lower_case(arg)))
                a_attrs[arg] = args[arg];

        result = make_container("a", a_attrs, result);
    }
    if (tag == "gbutton-url") return img_attrs->src;
    return result;
}

mapping query_container_callers()
{
    return ([ "gbutton": tag_gbutton,
              "gbutton-url": tag_gbutton
    ]);
}
