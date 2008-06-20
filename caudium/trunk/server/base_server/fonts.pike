/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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
 */
/*
 * $Id: fonts.pike,v 1.15 2005-01-03 17:04:40 kiwi Exp $
 */
//! Font handler for Caudium
//! @fixme
//!   Document this !

constant cvs_version="$Id: fonts.pike,v 1.15 2005-01-03 17:04:40 kiwi Exp $";

#include <module.h>

//import Image;

#if constant(Image.Font)
constant Font = Image.Font;
#else
constant Font = Image.font;
#endif

//!
string fix_name(string in)
{
  return replace(lower_case(in), ({"-"," "}), ({ "_", "_" }));
}


#if !constant(caudium)
#define caudium caudiump()
#endif

// name:([ version:fname, version:fname, ... ])
mapping ttf_done = ([]);
mapping ttf_font_names_cache = ([]);

//!
string trimttfname( string n )
{
  n = reverse(n);
  sscanf("tb %s", n);
  sscanf(n, "tl %s", n);
  sscanf(n, "dm %s", n);
  sscanf(n, "kb %s", n);
  sscanf(n, "db %s", n);
  sscanf(n, "xe %s", n);
  sscanf(n, "nc %s", n);
  sscanf(n, "klb %s", n);
  return reverse(n);
}

//!
string translate_ttf_style( string style )
{
  switch( lower_case( (style-"-")-" " ) )
  {
   case "normal":
   case "regular":
     return "nn";
   case "italic":
     return "ni";
   case "oblique":
     return "ni";
   case "bold":
     return "bn";
   case "bolditalic":
   case "italicbold":
     return "bi";
     return "bi";
   case "black":
     return "Bn";
   case "blackitalic":
   case "italicblack":
     return "Bi";
     return "Bi";
   case "light":
     return "ln";
   case "lightitalic":
   case "italiclight":
     return "li";
  }
  if(search(lower_case(style), "oblique"))
    return "ni"; // for now.
  report_notice("Unknwon ttf style: %s\n");
  return "nn";
}

//!
array available_font_versions(string name, int size)
{
  string base_dir, dir;
  array available;
#if constant(Image.TTF)
  int ttffound;
  int ttffontschanged;

  if(ttf_font_names_cache[ name ])
    return indices(ttf_font_names_cache[ name ]);
  foreach(caudium->query("font_dirs"), dir)
  {
    foreach(get_dir( dir )||({}), string fname)
    {
      catch
      {
	if(!ttf_done[combine_path(dir+"/",fname)]++)
	{
	  //   report_debug("Trying TTF: "+combine_path(dir+"/",fname)+"\n");
	  object ttf = Image.TTF( combine_path(dir+"/",fname) );
	  if(ttf)
	  {
	    mapping n = ttf->names();
	    //        report_debug("okiedokie! "+n->family+"\n");
	    ttffontschanged++;
	    string f = lower_case(trimttfname(n->family));
	    if(!ttf_font_names_cache[f])
	      ttf_font_names_cache[f] = ([]);
	    ttf_font_names_cache[f][ translate_ttf_style(n->style) ] 
	      = combine_path(dir+"/",fname);
	    if(f == lower_case( name ))  ttffound++;
	  }
	}
      };
    }
  }
  if(ttffontschanged)
    catch{
      Stdio.File(caudium->QUERY(ConfigurationStateDir) + ".ttffontcache",
		 "wct")->write(encode_value(ttf_font_names_cache));
    };
  if(ttffound)
    return  indices(ttf_font_names_cache[ lower_case(name) ]);
#endif

  foreach(caudium->query("font_dirs"), dir)
  {
    base_dir = dir+size+"/"+fix_name(name);
    if((available = get_dir(base_dir)))
      break;
    base_dir=dir+"/"+caudium->query("default_font_size")+"/"+fix_name(name);
    if((available = get_dir(base_dir)))
      break;
    base_dir=dir+"/"+caudium->query("default_font_size")+"/"+caudium->query("default_font");
    if((available = get_dir(base_dir)))
      break;
  }
  if(!available) return 0;
  return available;
}

//!
string describe_font_type(string n)
{
  string res;
  if(n[1]=='i') res = "italic";
  else res="";

  switch(n[0])
  {
   case 'n': if(!strlen(res)) res="normal"; break;
   case 'B': res+=" black";  break;
   case 'b': res+=" bold";  break;
   case 'l': res+=" light";  break;
  }
  return res;
}

//!
array get_font_italic_bold(string n)
{
  int italic,bold;
  if(n[1]=='i') italic = 1;

  switch(n[0])
  {
   case 'B': bold=2; break;
   case 'b': bold=1; break;
   case 'l': bold=-1;  break;
  }
  return ({ italic, bold });
}

string make_font_name(string name, int size, int bold, int italic)
{
  string base_dir, dir;
  mixed available = available_font_versions( name,size );
  if(file_stat(name)) return name;

  string bc=(bold>=0?(bold==2?"B":(bold==1?"b":"n")):"l"), ic=(italic?"i":"n");
  if(available)
    available = mkmultiset(available);
  else
    return name+"/nope";
  if(available[bc+ic]) 
    return name+"/"+bc+ic;
  if(bc=="l") bc="n";
  if(available[bc+ic]) 
    return name+"/"+bc+ic;
  if(bc=="B") bc="b";
  if(available[bc+ic])     
    return name+"/"+bc+ic;
  if(bc=="b") bc="n";
  if(available[bc+ic])
    return name+"/"+bc+ic;
  if(ic=="i") ic="n";
  if(available[bc+ic])
    return name+"/"+bc+ic;

  foreach(({ "n","l","b", "B", }), bc)
    foreach(({ "n", "i" }), ic)
      if(available[bc+ic])
	return name+"/"+bc+ic;
  return 0;
}

//!
class TTFWrapper
{
  int size;
  object real;

  //!
  int height( )
  {
    return size;
  }

  //!
  array text_extents( string what )
  {
    object o = real->write( what );
    return ({ o->xsize(), o->ysize() });
  }

  //!
  void create(object r, int s)
  {
    real = r;
    size = s;
    real->set_height( size );
  }

  //!
  object write( string ... what )
  {
    return real->write(@Array.map( (array(string))what,replace,"�",""));
  }
}

//!
object get_font(string f, int size, int bold, int italic,
		string justification, float xspace, float yspace)
{
  object fnt;
  string key, name;
  mixed err;
  if(f == "")  f = "default";  // To load the default font if
                               // it is badly specified.

  key = f+size+bold+italic+justification+xspace+yspace;
  if(fnt=cache_lookup("fonts", key))
    return fnt;

  err = catch {
    name=make_font_name(f,size,bold,italic);
#if constant(Image.TTF)
    if(ttf_font_names_cache[ lower_case(f) ])
    {
      f = lower_case(f);
      if( ttf_font_names_cache[ lower_case(f) ][ (name/"/")[1] ] )
      {
	object f = Image.TTF( ttf_font_names_cache[ lower_case(f) ][(name/"/")[1]]);
	f = TTFWrapper( f(), size );
	cache_set("fonts", key, f); 
	return f;
      }
      object f = Image.TTF( values(ttf_font_names_cache[ lower_case(f) ])[0]);
      return TTFWrapper( f(), size );
    }
#endif
    fnt = Font();
    foreach(caudium->query("font_dirs"), string f)
    {
      name = fix_name(name);
      if(file_stat( f + size + "/" + name ))
      {
	name = f+size+"/"+name;
	break;
      }
    }
    if(!fnt->load( name ))
    {
      if(f == caudium->QUERY(default_font))
      {
	report_error("Failed to load the default font.\n");
	return 0;
      }
      return get_font(caudium->QUERY(default_font), 
		      size,bold,italic,justification,xspace,yspace);
    }
    if(justification=="right") fnt->right();
    if(justification=="center") fnt->center();
    fnt->set_x_spacing((100.0+(float)xspace)/100.0);
    fnt->set_y_spacing((100.0+(float)yspace)/100.0);
    cache_set("fonts", key, fnt);
    return fnt;
  };
  report_error(sprintf("get_font(): Error opening font %O:\n"
		       "%s\n", f, describe_backtrace(err)));
  // Error if the font-file is not really a font-file...
  return 0;
}

//!
object resolve_font(string f, string|void justification)
{
  int bold, italic;
  float xspace=0.0;
  string a,b;
  if( !f ) 
    f = caudium->query("default_font");
  if(sscanf(f, "%sbold%s", a,b)==2)
  {
    bold=1;
    f = a+b;
  }
  if(sscanf(f, "%sblack%s", a,b)==2)
  {
    bold=2;
    f = a+b;
  }
  if(sscanf(f, "%slight%s", a,b)==2)
  {
    bold=-1;
    f = a+b;
  }
  if(sscanf(f, "%sitalic%s", a,b)==2)
  {
    italic=1;
    f = a+b;
  }
  if(sscanf(f, "%sslant%s", a,b)==2)
  {
    italic=-1;
    f = a+b;
  }
  if(sscanf(f, "%scompressed%s", a,b)==2)
  {
    xspace = -20.0;
    f = a+b;
  }
  if(sscanf(f, "%sspaced%s", a,b)==2)
  {
    xspace = 20.0;
    f = a+b;
  }
  if(sscanf(f, "%scenter%s", a, b)==2)
  {
    justification="center";
  }
  if(sscanf(f, "%sright%s", a, b)==2)
  {
    justification="right";
  }
  int size=32;
  sscanf(f, "%s %d", f, size);
  object fn;
  fn = get_font((f/" ")[0], size, bold, italic, 
	      justification||"left",xspace, 0.0);
  if(!fn)
    fn = get_font(caudium->query("default_font"),size,bold,italic,
		  justification||"left",xspace, 0.0);
  if(!fn)
    report_error("failed miserably to open the default font ("+
                 caudium->query("default_font")+")\n");
  return fn;
}

//!
array available_fonts( )
{
  array res = ({});
#if constant(Image.TTF)
  // Populate the TTF font cache.
  available_font_versions( "No, there is no such font as this",32 );
#endif
  foreach(caudium->query("font_dirs"), string dir)
  {
    dir+="32/";
    array d;
    if(array d = get_dir(dir))
    {
      foreach(d,string f)
      {
	if(f=="CVS") continue;
	Stdio.Stat a;
	if((a=file_stat(dir+f)) && (a[1]==-2))
	  res |= ({ replace(f,"_"," ") });
      }
    }
  }
  return sort(res|indices(ttf_font_names_cache));
}


//!
void create()
{
  add_constant("get_font", get_font);
  add_constant("available_font_versions", available_font_versions);
  add_constant("describe_font_type", describe_font_type);
  add_constant("get_font_italic_bold", get_font_italic_bold);
  add_constant("resolve_font", resolve_font);
  add_constant("available_fonts", available_fonts);

#if constant(Image.TTF)
  catch {
    ttf_font_names_cache =
      decode_value(Stdio.read_bytes(caudium->QUERY(ConfigurationStateDir) + ".ttffontcache"));
  };
#endif
}
