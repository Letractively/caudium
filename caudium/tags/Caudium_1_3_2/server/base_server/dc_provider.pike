/*
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
 */

/*
 * $Id$
 */
#include <caudium.h>

constant RET_IGNORE = -1;
constant RET_OK = 0;

void make_variable(string name, string value, mapping variables, int|void overwrite)
{
    if (!zero_type(variables[name]) && !overwrite)
        return;

    variables[name] = value;
}

void make_tag(string name, string value, mapping tags,
              mapping|void defaults, int|void overwrite)
{
    if (!zero_type(tags[name]) && !overwrite)
        return;

    tags[name] = value;
    
    if (defaults && sizeof(defaults)) {
        if (!tags->__defaults)
            tags->__defaults = ([]);
        tags->__defaults[name] = ([]);
        foreach(indices(defaults), string idx)
            tags->__defaults[name] += ([idx : defaults(idx)]);
    }
}

void make_container(string name, string value, mapping containers,
                    mapping|void defaults, int|void overwrite)
{
    if (!zero_type(containers[name]) && !overwrite)
        return;

    containers[name] = value;
    
    if (defaults && sizeof(defaults)) {
        if (!containers->__defaults)
            containers->__defaults = ([]);
        containers->__defaults[name] = ([]);
        foreach(indices(defaults), string idx)
            containers->__defaults[name] += ([idx : defaults(idx)]);
    }
}

mapping error_string(string error, void|string title, void|string charset)
{
    return ([
        "text" : error,
        "title" : title ? title : "Error",
        "charset" : charset ? charset : "ISO-8859-1"
    ]);
}

mapping error_redirect(string uri)
{
    return ([
        "url" : uri
    ]);
}

mapping|int process(object id, mapping data,
                    mapping variables, mapping tags,
                    mapping containers)
{
    return RET_IGNORE;
}

mapping|int finale(object id, mapping data,
                   mapping variables, mapping tags,
                   mapping containers)
{
    return RET_IGNORE;
}

