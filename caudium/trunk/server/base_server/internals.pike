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
#define DEBUG_INTERNALS 1

/*
 * This is the main "broker" module for all kinds of internal
 * files/requests. All it does is parsing the request string in the
 * special format (see below) and return the result mapping from the
 * handler method. The request URI is as follows:
 *
 *   method://path/file
 *
 * The interpretation of the //path/file part depends on the
 * method:
 *
 *  method         description
 *  -----------------------------------------------------------------
 *
 *  image          fetch an internal Caudium image. The path/file is
 *                 the full graphics image path relative to the
 *                 configured internal image directory.
 *
 *  html           fetch some internal HTML file. The path/file is the
 *                 full HTML file path relative to the configured
 *                 internal HTML documents directory. The file itself
 *                 is processed by the handler to do variable
 *                 replacement. For details see HTML.pike in this
 *                 directory.
 *
 *  help           Request help on some object present in Caudium. The
 *                 path can be one of the following:
 *
 *                     module - help on module. /file is the module
 *                       name. Example:
 *                         help://module/gtext
 *
 *                     defvar - help on a defvar. /file can be
 *                       composed of at most 2 parts. If only one part
 *                       is present the /file designates a defvar name
 *                       in any module (or a globvar), for example:
 *                          help://defvar/myVar
 *                       If two parts are present, then the first one
 *                       designates a module name and the other the
 *                       defvar name, for example:
 *                          help://defvar/myModule/myVar
 *
 *                     tag - help on a tag. The syntax is as with
 *                       defvar only the single or the second /file
 *                       part designates a tag name.
 *
 *  error          Request a HTML file corresponding to some HTTP
 *                 error code. This option can be set per
 *                 virtual host. The syntax is error://errno
 *                 Example:
 *                    error://404
 */

static multiset(string) known_methods = (<
    "HTML", "IMAGE"
    >);

class InternalResolver 
{
    
//
// maps a module type to its associated files path
//
    private static mapping(string:string) paths;

//
// Process the passed URI, call the associated handler and return
// whatever it produced. Returns an empty mapping (NOT 0!!)
// if no handler present, otherwise
// any error throws an exception. The 'vars' mapping is used by some
// modules. If it is present but not needed, the method ignores it.
//
    mapping(string:mixed)
        get(string URI, mapping(string:string)|void vars, object|void id)
    {
        string method, file;

        if (sscanf(URI, "%s://%s", method, file) != 2)
            throw(({"Incorrect internal URI format\n", backtrace()}));
        
        method = upper_case(method);

#ifdef DEBUG_INTERNALS
        report_notice("Request for the '" + method + "' method\n");
#endif
        
        if (!known_methods[method]) {
            report_notice("No method handler for '" + method + "'!\n");
            return 0;
        }

        mapping qvars;
        mapping ret;
        string  query;

        if (file[0] != '/')
            file = "/" + file;
        
        if (sscanf("%s?%s", file, query) == 2)
	    Caudium.parse_query_string(query, qvars);
	
        switch(method) {
            case "HTML":
                ret = InternalFiles.HTML.handle(id, 
		                                file, 
						qvars, 
						vars, 
						paths[method]);
                break;
		
	    case "IMAGE":
	        ret = InternalFiles.IMAGE.handle(id,
		                                 file,
						 qvars,
						 vars,
						 paths[method]);
	        break;
        }
        
        return ret;
    }

    void create(mapping(string:string) p)
    {
        if (!p)
            return;
		
        report_notice("\nInitializing InternalFiles...");
	
        paths = p;

        foreach(indices(paths), string idx) {
            if (paths[idx][-1] != '/')
                paths[idx] += "/";
            
            paths[upper_case(idx)] = paths[idx];
            m_delete(paths, idx);
        }

        report_notice(" done\n");
    }
}
