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
import Stdio;

/*
 * Subdirectories created by the output classes in the target
 * directory.
 */
private static array(string) subdirs = ({"files","modules"});

/*
 * Array of template variables used when generating files.
 */
private static mapping(string:string|function) template_vars =
([
    "@DATE@":lambda(object o){
                 if (functionp(o->setdate))
                     return o->setdate();

                 string t = ctime(time());
                 return t[0..(sizeof(t) - 2)];
             }
]);

class DocGen 
{
    array(DocParser.PikeFile)     files;
    array(DocParser.Module)       modules;
    string                        rel_path;
    array(string)                 tvars;
    
    object(Stdio.File) create_file(string tdir, string fpath)
    {
        return 0;
    } 

    void close_file(Stdio.File f)
    {
        if (f)
            f->close();
    }

    private string xml_comment(string cmt) 
    {
        return "<!-- " + cmt + " -->\n";
    }

    private string ob_unnamed(DocParser.DocObject o) 
    {
        return "unnamed at " + o->rfile + "(" + o->lineno + ")";
    }
    
    /* File header output */
    private string f_file(DocParser.PikeFile f)
    {
        string ret = "";

        /* File header */
        if (f->first_line)
            ret = "<file name=\"" + f->first_line + "\">\n";
        else
            ret = "<file name=\"unnamed_file\">\n";

        /* File description */
        ret += "<description>\n";
        if (f->inherits) {
            string    tmp;

            /* Inherited stuff */
            switch(sizeof(f->inherits)) {
                case 0:
                    break;

                case 1:
                    tmp = f->inherits[0];
                    ret += "inherits <link to=\"" + tmp + "\">" +
                        tmp + "</link><br><br>\n";
                    break;

                default:
                    ret += "<strong>inherits:</strong>\n<ul>\n";
                    foreach(f->inherits, tmp)
                        ret += "\t<li><link to=\"" + tmp + "\">" +
                            tmp + "</link><li>\n";
                    ret += "</ul><br><br>\n";
                    break;
            }
        }
        
        if (f->contents && f->contents != "")
            ret += f->contents + "\n";
        ret += "</description>\n\n";

        /* CVS version */
        ret += "<version>\n";
        if (f->cvs_version && f->cvs_version != "")
            ret += this_object()->special_cvs_version ?
                this_object()->special_cvs_version(f->cvs_version) : f->cvs_version;
        ret += "\n</version>\n\n";

        return ret;
    }

    /* GlobVar output */
    private string do_f_globvar(DocParser.GlobVar gv)
    {
        string   ret = "";

        if (gv->first_line && gv->first_line != "")
            ret += "<globvar synopsis=\"" + gv->first_line + "\">\n";
        else
            ret += "<globvar synopsis=\"" + ob_unnamed(gv) + "\">\n";

        if (gv->contents && gv->contents != "")
            ret += gv->contents + "\n";
        else
            ret += "unknown\n";

        ret += "</globvar>\n\n";
        
        return ret;
    }
    
    private string f_globvars(DocParser.PikeFile f)
    {
        string   ret = "";

        if (!sizeof(f->globvars))
            return "";
	ret = "<globvars>\n";
        foreach(f->globvars, object gv)
            ret += do_f_globvar(gv);
	ret += "</globvars>\n";

        return ret;
    }

    /* Method output */
    private mapping(string:string|array(string)) 
    dissect_method(string s)
    {
	object(Regexp)    fn = Regexp("([a-zA-Z_0-9]+)[ \t]+([_a-zA-Z0-9]+)[ \t]*(.*)");
	mapping(string:string|array(string)) ret = ([]);
	array(string) split;
    
	if ((split = fn->split(s))) {
	    if (sizeof(split) != 3) {
		stderr->write("Incorrect method synopsis\n");
		return ret;
	    }
	
	    ret->type = split[0];
	    ret->name = split[1];
	    ret->args = ({});
	    foreach(split[-1][1..(sizeof(split[-1]) - 2)] / ",", string arg)
		ret->args += ({String.trim_whites(arg)});
	}
    
	return ret;
    }
    
    private string pretty_syntax(mapping(string:string|array(string)) m)
    {
	string ret = "";
	
	ret += m->type + " <strong>" + m->name + "</strong> ( ";
	if (m->args)
		ret += m->args * ", ";
	ret += " )";

        return ret;
    }
    
    private string do_f_method(DocParser.Method m)
    {
        string                                 ret = "";
	mapping(string:string|array(string))   method;
	
	method = dissect_method(m->first_line);
	
	/* Method start */
	ret += "<method name=\"" + method->name + "\">\n";
	
	/* Short description */
	ret += "<short>\n\t" + m->name + "\n</short>\n\n";

	/* Synopsis */
	ret += "<syntax>\n\t" + pretty_syntax(method) + "\n</syntax>\n\n";

        /* Description */
	if (m->contents && m->contents != "")
	    ret += "<description>\n" + m->contents + "\n</description>\n\n";
	else
	    ret += "<description>\nNO DESCRIPTION</description>\n\n";

	/* Arguments */
	if (m->args) {
	    ret += "<arguments>\n";
	    foreach(m->args, mapping(string:string) a) {
		ret += "\t<argument>\n\t\t<syntax>\n\t\t\t";
		if (a->synopsis)
		    ret += a->synopsis;
		else
		    ret += "NO SYNOPSIS";
		ret += "\n\t\t</syntax>\n";
		
		ret += "\t\t<description>\n\t\t\t";
		if (a->description)
		    ret += a->description;
		else
		    ret += "NO DESCRIPTION";
		ret += "\n\t\t</description>\n\t</argument>\n\n";
	    }
	    ret += "</arguments>\n\n";
	}
	
	/* Returns */
	if (m->returns)
	    foreach(m->returns, string r)
		if (r != "")
		    ret += "<returns>\n" + r + "\n</returns>\n\n";
		
	/* Notes */
	if (m->notes) {
	    switch(sizeof(m->notes)) {
		case 0:
		    break;
		    
		case 1:
		    if (m->notes[0] != "")
			ret += "<note>\n" + m->notes[0] + "\n</note>\n\n";
		    break;
		    
		default:
		    ret += "<ul>\n";
		    foreach(m->notes, string n)
			if (n != "")
			    ret += "<li><note>\n" + n + "</note></li>\n";
		    ret += "</ul>\n\n";
		    break;
	    }
	}
	
	/* El Final Grande */
	ret += "</method>\n\n";
		
	return ret;
    }
    
    private string f_methods(DocParser.PikeFile f)
    {
        string   ret = "";

        if (!sizeof(f->methods))
            return "";
	ret = "<methods>\n";
        foreach(f->methods, object m)
            ret += do_f_method(m);
	ret += "</methods>\n";
        return ret;
    }
    
    /* Class output */
    private string f_classes(DocParser.PikeFile f)
    {
	string   ret = "";
	
	return ret;
    }
    
    void do_file(string tdir, DocParser.PikeFile f, Stdio.File ofile)
    {
        /* First take care of the file itself */
        if (f->first_line)
            ofile->write(f_file(f));

        /* Now the globvars */
        if (f->globvars)
            ofile->write(f_globvars(f));

        /* Next the methods */
        if (f->methods)
            ofile->write(f_methods(f));
	    
	/* And Classes */
	if (f->classes)
	    ofile->write(f_classes(f));

	ofile->write("</file>");
    }

    void do_module(string tdir, DocParser.Module f, Stdio.File ofile)
    {
    }
    
    void output_file(string tdir, DocParser.PikeFile|DocParser.Module f)
    {
        object(Stdio.File)    ofile;

        ofile = create_file(tdir, f->rfile);
        
        switch(f->myName) {
            case "PikeFile":
                do_file(tdir, f, ofile);
                break;

            case "Module":
                do_module(tdir, f, ofile);
                break;
        }
        
        close_file(ofile);
    }
    
    void generate(string tdir)
    {
        string  cwd = getcwd();
        tdir = combine_path(cwd, tdir);
        /* First see whether the target directory exists and, if it
         * doesn't, try to create it.
         */
        foreach(subdirs, string d) {
	  string   dir = combine_path(tdir, d);
            
	  if (!cd(dir))
	    if (!Stdio.mkdirhier(dir, 0755))
	      throw(({"Cannot create directory hierarchy " +dir + "\n", backtrace()}));
        }
        
        cd(tdir);
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

    /*
     * This method maps the variables whose names are in 'tvars' above
     * to their values as stored in the template_vars mapping. Returns
     * an array that can be used with the replace function.
     */
    array(string) map_variables(array(string)|void tv)
    {
        array(string) tmp = tvars;
        array(string) ret = ({});
        
        if (tv)
            tmp = tv;
        
        foreach(tmp, string var) {
            if (template_vars[var])
                if (functionp(template_vars[var])) {
                    ret += ({template_vars[var](this_object())});
                } else if (stringp(template_vars[var])) {
                    ret += ({template_vars[var]});
                } else {
                    ret += ({""}); /* we mustn't have holes in this
                                    * array */
                }
        }

        return ret;
    }
    
    void create(array(object) f, array(object) m, string rpath)
    {
        files = f;
        modules = m;
        rel_path = rpath;

        /*
         * Create a table holding all the template variables we
         * define. The set of variables won't change, so we can safely
         * generate it here and forget about it until it's needed.
         */
        tvars = ({});
        foreach(indices(template_vars), string var)
            tvars += ({var});
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
            f->write(replace(header, tvars, map_variables()));

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

