/* I'm -*-Pike-*-, dude 
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
static constant mime_type = "text/html";

static mapping empty_file = ([
    "data":#string "nofile.html",
    "type":mime_type]);

static string
replace_vars(string file, mapping(string:string) vars)
{
    if (!vars || !sizeof(vars))
        return file;

    array(string) from = ({}), to = ({});

    foreach(indices(vars), string var) {
        from += ({"$" + var});
        to += ({vars[var]});
    }

    return replace(file, from, to);
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
    
    if (basedir[-1] != '/')
        basedir += "/";

    while(sizeof(file) && file[0] == '/')
        file = file[1..];

    string fpath = basedir + file;

    if (!file_stat(fpath)) {
        empty_file->file = replace_vars(empty_file->file,
                                        (["fpath":fpath]));
        return empty_file;
    }
    
    return ([
        "data":replace_vars(Stdio.read_file(fpath), vars),
        "type":mime_type
    ]);
}
