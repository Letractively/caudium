/* I'm -*-Pike-*-, dude 
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 * $Id$
 */

static array(mapping) image_types =
({
    (["ext": "gif","type":"image/gif"]),
    (["ext": "png","type":"image/png"]),
    (["ext": "jpg","type":"image/jpeg"]),
    (["ext":"jpeg","type":"image/jpeg"]),
    (["ext": "xcf","type":"image/x-xcf"])
});

private Stdio.File
open_file(string path)
{
    Stdio.File imgfile;
    mixed err = catch {
      imgfile = Stdio.File(path, "r");
    };
    if (err)
    	return 0;
    if (!imgfile) 
        return 0;

    return imgfile;
}

private mapping(string:mixed)
    fetch_file(string basedir,
               array(string) file,
               mapping(string:mixed) query,
               mapping(string:string) vars,
               string special)
{
    mapping(string:mixed)   ret;
    
    /* TODO: implement the special handlers */
    /* TODO: maybe the files should be cached?? */
    
    if (!special) {
        array(string) fname = file[-1] / ".";
        Stdio.File    imgfile = 0;
        string        imgtype;
        string        myFile = file * "/";

        if (sizeof(fname) == 1 || fname[-1] == "") {
            /* Try to match several extensions */
            
            foreach(image_types, mapping(string:string) img) {
                imgfile = open_file(basedir + myFile + "." + img->ext);
                if (imgfile) {
                    imgtype = img->type;
                    break;
                }
            }
            if (!imgfile)
                return 0;
        } else {
            foreach(image_types, mapping(string:string) img) {
                if (img->ext == fname[-1]) {
                    imgfile = open_file(basedir + myFile);
                    if (!imgfile)
                        return 0;
                    imgtype = img->type;
                    break;
                }
            }

            if (!imgfile)
                return 0;
        }

        ret = ([]);
        ret->data = imgfile->read();
        ret->type = imgtype;
        imgfile->close();

        /* Get some information on the file */
        object img = Image.ANY.decode(ret->data);
        if (!img) {
            ret->width = 0;
            ret->height = 0;
        } else {
            ret->width = img->xsize();
            ret->height = img->ysize();
        }
        
        return ret;
    }

    return 0; /* for now */
}

mapping(string:string) handle(object id,
                              string file,
                              mapping(string:mixed) query,
                              mapping(string:string) vars,
                              string basedir)
{
    if (!basedir)
        throw(({"Must have a base directory!\n", backtrace()}));

    if (!file)
        throw(({"Missing file!\n", backtrace()}));

    array(string) parts = (file / "/") - ({""});
    string        special = 0;
    
    if (sizeof(parts) > 1)
        switch(parts[0]) {
            case "auto":
            case "button":
            case "cfgtab":
            case "logo":
                special = parts[0];
                parts = parts - ({parts[0]});
                break;
        }
    
    return fetch_file(basedir, parts, query, vars, special);
}
