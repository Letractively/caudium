/* Dear Emacs, please note this is a -*-pike-*- file. Thank you. */

/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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

/*
 * A sample documentation generator.
 * Generates documentation files out of the passed collection of
 * PikeFile and Module objects defined in the DocParser module
 */

import DocParser;

/*
 * Subdirectories created by the output classes in the target
 * directory.
 */
private static array(string) subdirs = ({"files","modules"});

/*
 * Array of template variables used when generating files
 */
private static array(string) template_vars =
({
    "@DATE@"
});

class DocGen 
{
    array(DocParser.PikeFile)     files;
    array(DocParser.Module)       modules;
    string                        rel_path;

    object(Stdio.File) create_file(string tdir, string fpath)
    {
        return 0;
    } 

    void close_file(Stdio.File f)
    {
        if (f)
            f->close();
    }
    
    void output_file(string tdir, DocParser.PikeFile|DocParser.Module f)
    {
        object(Stdio.File)    ofile;

        ofile = create_file(tdir, f->rfile);
        
        switch(f->myName) {
            case "PikeFile":
                break;

            case "Module":
                break;
        }
        
        close_file(ofile);
    }
    
    void generate(string tdir)
    {
        string  cwd = getcwd();
        
        /* First see whether the target directory exists and, if it
         * doesn't, try to create it.
         */
        foreach(subdirs, string d) {
            string   dir = tdir + "/" + d + "/";
            
            if (!cd(dir))
                if (!Stdio.mkdirhier(dir, 0755))
                    throw(({"Cannot create directory hierarchy " +dir + "\n", backtrace()}));
        }
        
        cd(tdir + "/");
        if (files) {
            foreach(files, DocParser.PikeFile f) {
                output_file(subdirs[0] + "/", f);
            }   
        }

        if (modules) {
            foreach(modules, DocParser.Module m) {
                output_file(subdirs[1] + "/", m);
            }
        }
        
        cd(cwd);
    }
    
    void create(array(object) f, array(object) m, string rpath)
    {
        files = f;
        modules = m;
        rel_path = rpath;
    }
}

class TreeMirror
{
    inherit DocGen;
    private string header = #string "header-tree.xml";
    private string footer = #string "footer-tree.xml";
    
    object(Stdio.File) create_file(string tdir, string fpath)
    {
        string   fname = replace(tdir + (fpath - rel_path), ".pike", ".xml");
        object(Stdio.File) f;
        
        if (!Stdio.mkdirhier(dirname(fname)))
            throw(({"Cannot create directory '" + dirname(fname) + "'\n", backtrace()}));
        
        f = Stdio.File(fname, "cw");
        if (f)
            f->write(replace(header,template_vars,({ctime(time())})));

        return f;
    }

    void close_file(Stdio.File f)
    {
        f->write(footer);
        f->close();
    }
    
    void create(array(object) f, array(object) m, string rpath)
    {
        ::create(f, m, rpath);
    }
}

class Monolith
{
    inherit DocGen;

    void create(array(object) f, array(object) m, string rpath)
    {
        ::create(f, m, rpath);
    }
}

