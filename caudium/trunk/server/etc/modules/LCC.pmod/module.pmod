/* Dear Emacs, it's -*-pike-*-
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
 */
constant cvs_version = "$Id$";

private void insert_attr(string atype, string|array(string) value,
                         string op, mapping(string:array(string)) data)
{
    int do_op = 0, opval;
    
    data[atype] = ({});

    switch(op) {
        case "replace":
            opval = do_op = 2;
            break;

        case "delete":
            opval = do_op = 1;
            break;
            
        case "modify":
        case "add":
            opval = 0;
            do_op = 1;
            break;
    }

    if (do_op)
        data[atype] += ({opval});

    if (stringp(value))
        data[atype] += ({value});
    else if (value)
        data[atype] += value;
}

void add_attribute(string name, string|array(string) value, mapping(string:array(string)) data)
{
    insert_attr(name, value, "add", data);
}

void replace_attribute(string name, string|array(string) value, mapping(string:array(string)) data)
{
    insert_attr(name, value, "replace", data);
}

void add_class(string|array(string) name, mapping(string:array(string)) data)
{
    insert_attr("objectClass", name, "add", data);
}

void replace_class(string name, mapping(string:array(string)) data)
{
    insert_attr("objectClass", name, "replace", data);
}

void delete_attribute(string name, mapping(string:array(string)) data)
{
    insert_attr(name, 0,  "delete", data);
}

void delete_class(string name, mapping(string:array(string)) data)
{
    insert_attr(name, 0,  "delete", data);
}
