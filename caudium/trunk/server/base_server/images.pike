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

/* _decode and decode_layers copied from _Image.pmod since it doesn't
   work with Pike 7.3 otherwise. It requires Protocols.HTTP.Query which
   breaks due to an incompatible SSL.pmod. Thus the functions aren't found.
   Very frustrating indeed.
*/
   

private mapping _decode( string data, mixed|void tocolor )
{
  Image.image i, a;
  string format;
  mapping opts;
  if(!data)
    return 0;

  if( mappingp( tocolor ) )
  {
    opts = tocolor;
    tocolor = 0;
  }

  // macbinary decoding
  if (data[102..105]=="mBIN" ||
      data[65..68]=="JPEG" ||    // wierd standard, that
      data[69..72]=="8BIM")
  {
     int i;
     sscanf(data,"%2c",i);
     // sanity check

     if (i>0 && i<64 && -1==search(data[2..2+i-1],"\0"))
     {
	int p,l;
	sscanf(data[83..86],"%4c",l);    // data fork size
	sscanf(data[120..121],"%2c",p);  // extra header size
	p=128+((p+127)/128)*128;         // data fork position

	if (p<strlen(data)) // extra sanity check
	   data=data[p..p+l-1];
     }
  }

  // Use the low-level decode function to get the alpha channel.
#if constant(Image.GIF) && constant(Image.GIF.RENDER)
  catch
  {
    array chunks = Image["GIF"]->_decode( data );

    // If there is more than one render chunk, the image is probably
    // an animation. Handling animations is left as an exercise for
    // the reader. :-)
    foreach(chunks, mixed chunk)
      if(arrayp(chunk) && chunk[0] == Image.GIF.RENDER )
        [i,a] = chunk[3..4];
    format = "GIF";
  };
#endif

  if(!i)
    foreach( ({ "JPEG", "XWD", "PNM", "RAS" }), string fmt )
    {
      catch {
        i = Image[fmt]->decode( data );
        format = fmt;
      };
      if( i )
        break;
    }

  if(!i)
    foreach( ({ "ANY", "XCF", "PSD", "PNG",  "BMP",  "TGA", "PCX",
                "XBM", "XPM", "TIFF", "ILBM", "PS", "PVR",
       /* Image formats low on headers below this mark */
                "DSI", "TIM", "HRZ", "AVS", "WBF",
       /* "XFace" Always succeds*/
    }), string fmt )
    {
      catch {
        mixed q = Image[fmt]->_decode( data );
        format = fmt;
        i = q->image;
        a = q->alpha;
      };
      if( i )
        break;
    }

  return  ([
    "format":format,
    "alpha":a,
    "img":i,
    "image":i,
  ]);
}

private array(Image.Layer) decode_layers( string data, mixed|void tocolor )
{
  array i;
  function f;
  if(!data)
    return 0;
  foreach( ({ "GIF", "XCF", "PSD","ILBM" }), string fmt )
    if( (f=Image[fmt]["decode_layers"]) && !catch(i = f( data,tocolor )) && i )
      break;

  if(!i) // No image could be decoded at all.
    catch
    {
      mapping q = _decode( data, tocolor );
      if( !q->img )
	return 0;
      i = ({
        Image.Layer( ([
          "image":q->img,
          "alpha":q->alpha
        ]) )
      });
    };

  return i;
}

//
// NOTE!!!!
// This file duplicates some routines from caudium.pike This is because
// I couldn't decide which ones to use and I think that the routines from
// caudium.pike that deal with images should be moved here. The only question
// is compatibility. Is moving the routines here going to break something?
// or maybe just make caudium.pike inherit this file? Dunno yet - after xmas :)
// /grendel
//
mapping low_decode_image(string data, void|mixed tocolor)
{
  mapping w = _decode( data, tocolor );
  if( w->image ) return w;
  return 0;
}

mapping low_load_image(string f, object id)
{
  string data;
  Stdio.File file;
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
#if 0
#ifdef THREADS
        catch
        {
          string host = "";
          sscanf( f, "http://%[^/]", host );
          if( sscanf( host, "%*s:%*d" ) != 2)
            host += ":80";
          mapping hd = 
                  ([
                    "User-Agent":version(),
                    "Host":host,
                  ]);
          data = Protocols.HTTP.get_url_data( f, 0, hd );
        };
#endif
#endif
      if( !data )
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data) return 0;
  return low_decode_image( data );
}

array(Image.Layer) load_layers(string f, object id, mapping|void opt)
{
  string data;
  Stdio.File file;
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
#if 0
#ifdef THREADS
        catch
        {
          data = Protocols.HTTP.get_url_nice( f )[1];
        };
#endif
#endif
      if( !data )
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data) return 0;
  return decode_layers( data, opt );
}

Image.Image load_image(string f, object id)
{
  mapping q = low_load_image( f, id );
  if( q ) return q->img;
  return 0;
}
