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

    void end_output()
    {
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
    private string f_file(DocParser.PikeFile f, string what)
    {
        string ret = "";

        /* File header */
        if (f->first_line)
	  ret = "<"+what+" name=\"" + f->first_line + "\">\n";
        else
	  ret = "<"+what+" name=\"unnamed_file\">\n";

        if (f->inherits) {
	  foreach(f->inherits, string tmp)
	    ret += "<inherits link=\"" + tmp + "\"/>\n";
	}
	
        /* File description */
        
        if (f->contents && f->contents != "") 
	  ret += "<description>\n"+ f->contents + "\n" + "</description>\n\n";
	  
	/* CVS version */
	if (f->cvs_version && f->cvs_version != "") {
	  ret += "<version>\n" +
	    (this_object()->special_cvs_version ?
	     this_object()->special_cvs_version(f->cvs_version) :
	     f->cvs_version) + "\n</version>\n\n";
	}
        /* Type if any */
        if (f->type && f->type != "") {
	  ret += "<type>"+f->type+"</type>\n";
	}
	
        /* Provides if any */
        if (f->provides && f->provides != "") {
	  ret += "<provides>"+f->provides+"</provides>\n";
	}
	
        return ret;
    }

    /* GlobVar output */
    private string do_f_globvar(DocParser.GlobVar gv)
    {
        string   ret = "";

        if (gv->first_line && gv->first_line != "")
            ret += "<globvar synopsis=\"" + gv->first_line + "\"";
        else
            ret += "<globvar synopsis=\"" + ob_unnamed(gv) + "\"";

        if (gv->contents && strlen(gv->contents))
	  ret += ">\n"+gv->contents + "\n</globvar>\n";
	else
	  ret += "/>\n";
        
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

  /* GlobVar output */
  private string do_f_tag(DocParser.Tag|DocParser.Container tag,
			  int|void is_container)
  {
    string   ret = "";
    
    if (tag->first_line && tag->first_line != "") {
      if(is_container)
	ret += "<tag name=\""+tag->first_line+"\" synopsis=\"&lt;" + tag->first_line + "&gt;"
	  "&lt;/" + tag->first_line + "&gt;\">\n";
      else
	ret += "<tag name=\""+tag->first_line+"\" synopsis=\"&lt;" + tag->first_line + "&gt;\">\n";
    } else
      ret += "<tag synopsis=\"" + ob_unnamed(tag) + "\">\n";
    
    if (tag->contents && tag->contents != "")
      ret += "<description>\n"+tag->contents + "\n</description>\n";

    /* Attributes */
    if (tag->attrs && sizeof(tag->attrs)) {
      ret += "<attributes>\n";
      foreach(tag->attrs, DocParser.Attribute a) {
	ret += "\t<attribute";
	if (a->first_line)
	  ret += " syntax=\""+a->first_line+"\"";
	if (a->def && strlen(a->def))
	  ret += " default=\""+a->def+"\"";
	if (a->contents && strlen(a->contents))
	  ret += ">\n\t\t"+a->contents+"\n\t</attribute>\n";
	else
	  ret += "/>\n";
      }
      ret += "</attributes>\n\n";
    }
	
    /* Returns */
    if (tag->returns)
      foreach(tag->returns, string r)
	if (r != "")
	  ret += "<returns>\n" + r + "\n</returns>\n\n";
    
    /* Notes */
    if (tag->notes && sizeof(tag->notes)) {
      ret  += "<notes>\n";
      foreach(tag->notes, string n)
	if (n != "")
	  ret += "\t<note>\n" + n + "\n\t</note>\n";
      ret += "</notes>\n";
    }

    /* See Also */
    if (tag->seealso && sizeof(tag->seealso)) {
      ret  += "<links>\n";
      foreach(tag->seealso, string n)
	if (strlen(n))
	  ret += "\t<link to=\""+ n + "\"/>\n";
      ret += "</links>\n";
    }

    ret += "</tag>\n\n";
        
    return ret;
  }
  
  private string f_tags(DocParser.PikeFile f)
  {
    string   ret = "";
    if (!sizeof(f->tags))
      return "";
    ret = "<tags>\n";
    foreach(f->tags, object tag)
      ret += do_f_tag(tag);
    ret += "</tags>\n";

    return ret;
  }
  
  private string f_containers(DocParser.PikeFile f)
  {
    string   ret = "";
    if (!sizeof(f->containers))
      return "";
    ret = "<containers>\n";
    foreach(f->containers, object tag)
      ret += do_f_tag(tag, 1);
    ret += "</containers>\n";

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
	if(m->name)
	  ret += "<short>\n\t" + m->name + "\n</short>\n\n";

	/* Synopsis */
	ret += "<syntax>\n\t" + pretty_syntax(method) + "\n</syntax>\n\n";

        /* Description */
	if (m->contents && m->contents != "")
	  ret += "<description>\n" + m->contents + "\n</description>\n\n";

	/* Arguments */
	if (m->args && sizeof(m->args)) {
	  ret += "<arguments>\n";
	  foreach(m->args, mapping(string:string) a) {
	    ret += "\t<argument";
	    if (a->synopsis)
	      ret += " syntax=\""+a->synopsis+"\"";
	    if (a->description && strlen(a->description)) 
	      ret += ">\n\t\t"+ a->description +"\n\t</argument>\n";
	    else
	      ret += "/>\n";
		
	  }
	  ret += "</arguments>\n\n";
	}
	
	/* Returns */
	if (m->returns)
	  foreach(m->returns, string r)
	    if (r != "")
	      ret += "<returns>\n" + r + "\n</returns>\n\n";
	
	/* Notes */
	if (m->notes && sizeof(m->notes)) {
	  ret  += "<notes>\n";
	  foreach(m->notes, string n)
	    if (n != "")
	      ret += "\t<note>\n" + n + "\n\t</note>\n";
	  ret += "</notes>\n";
	}

	/* See Also */
	if (m->seealso && sizeof(m->seealso)) {
	  ret  += "<links>\n";
	  foreach(m->seealso, string n)
	    if (n != "")
	      ret += "\t<link to=\""+ n + "\"/>\n";
	  ret += "</links>\n";
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
    private string do_f_class(DocParser.Class c)
    {
	string   ret = "";
	
	/* Header */
	ret = "<class name=\"" + c->first_line + "\">\n";
	
	/* Description */
	ret += "<description>\n\t" + c->contents + "\n</description>\n\n";
	
	/* Scope */
	ret += "\t<scope>" + c->scope + "</scope>\n";
	
	/* Methods */
	if (c->methods && sizeof(c->methods)) {
	    ret += "\t<methods>\n";
	    foreach(c->methods, object m)
		ret += do_f_method(m);
	    ret += "\t<methods>\n";
	}
	
	/* Globvars */
	if (c->globvars && sizeof(c->globvars)) {
	    ret += "\t<globvars>\n";
	    foreach(c->globvars, object gv)
		ret += do_f_globvar(gv);
	    ret += "\t</globvars>\n";
	}
	
	/* See Also */
	if (c->seealso && sizeof(c->seealso)) {
	    ret  += "\t<links>\n";
	    foreach(c->seealso, string n)
		if (n != "")
	    	    ret += "\t\t<link to=\""+ n + "\"/>\n";
	    ret += "\t</links>\n";
	}
	
	/* Examples */
	if (c->examples && sizeof(c->examples)) {
	    ret += "\t<examples>\n";
	    foreach(c->examples, string e)
		if (e != "")
		    ret += "\t\t<example>\n\t\t\t" + e + "\n\t\t</example>\n";
	    ret += "\t</examples>\n";
	}
	
	/* Bugs/fixme */
	if (c->bugs && sizeof(c->bugs)) {
	    ret += "\t<bugs>\n";
	    foreach(c->bugs, string b)
		if (b != "")
		    ret += "\t\t<bug>\n\t\t\t" + b + "\n\t\t</bug>\n";
	    ret += "\t</bugs>\n";
	}
	
	ret += "</class>\n\n";
	
	return ret;
    }
    
    private string f_classes(DocParser.PikeFile f)
    {
	string   ret = "";
	
	if (!sizeof(f->classes))
	    return "";
	ret = "<classes>\n";
	foreach(f->classes, object c)
	    ret += do_f_class(c);
	ret += "</classes>\n";
	
	return ret;
    }

    private string do_f_entity(DocParser.Entity e)
    {
	string ret = "";
	
	ret = "<entity name=\"" + e->first_line + "\">\n\t";
	
	/* See Also */
	if (e->seealso && sizeof(e->seealso)) {
    	    ret  += "<links>\n";
    	    foreach(e->seealso, string n)
	    if (strlen(n))
		ret += "\t<link to=\""+ n + "\"/>\n";
    	    ret += "</links>\n";
	}
	
	/* Examples */
	if (e->examples && sizeof(e->examples)) {
	    ret += "\t<examples>\n";
	    foreach(e->examples, string e)
		if (e != "")
		    ret += "\t\t<example>\n\t\t\t" + e + "\n\t\t</example>\n";
	    ret += "\t</examples>\n";
	}
	
	/* Bugs/fixme */
	if (e->bugs && sizeof(e->bugs)) {
	    ret += "\t<bugs>\n";
	    foreach(e->bugs, string b)
		if (b != "")
		    ret += "\t\t<bug>\n\t\t\t" + b + "\n\t\t</bug>\n";
	    ret += "\t</bugs>\n";
	}
	
	/* Notes */
	if (e->notes && sizeof(e->notes)) {
    	    ret  += "<notes>\n";
    	    foreach(e->notes, string n)
		if (n != "")
	    ret += "\t<note>\n" + n + "\n\t</note>\n";
    	    ret += "</notes>\n";
	}
	
	ret += e->contents + "\n</entity>\n\n";
	
	return ret;
    }
    
    private string do_f_escope(DocParser.EntityScope es)
    {
	string ret = "";
	
	ret = "<scope name=\"" + es->first_line + "\">\n";
	ret += "<description>\n\t" + es->contents + "\n</description>\n\n";
	
	/* See Also */
	if (es->seealso && sizeof(es->seealso)) {
    	    ret  += "<links>\n";
    	    foreach(es->seealso, string n)
	    if (strlen(n))
		ret += "\t<link to=\""+ n + "\"/>\n";
    	    ret += "</links>\n";
	}
	
	/* Examples */
	if (es->examples && sizeof(es->examples)) {
	    ret += "\t<examples>\n";
	    foreach(es->examples, string e)
		if (e != "")
		    ret += "\t\t<example>\n\t\t\t" + e + "\n\t\t</example>\n";
	    ret += "\t</examples>\n";
	}
	
	/* Bugs/fixme */
	if (es->bugs && sizeof(es->bugs)) {
	    ret += "\t<bugs>\n";
	    foreach(es->bugs, string b)
		if (b != "")
		    ret += "\t\t<bug>\n\t\t\t" + b + "\n\t\t</bug>\n";
	    ret += "\t</bugs>\n";
	}
	
	/* Notes */
	if (es->notes && sizeof(es->notes)) {
    	    ret  += "<notes>\n";
    	    foreach(es->notes, string n)
		if (n != "")
	    ret += "\t<note>\n" + n + "\n\t</note>\n";
    	    ret += "</notes>\n";
	}
	
	if (sizeof(es->entities))
	    foreach(es->entities, object e)
		ret += do_f_entity(e);
	ret += "</scope>\n\n";
	
	return ret;
    }
    
    private string f_entities(DocParser.Module m)
    {
	string ret = "";
	
	if (!sizeof(m->escopes))
	    return "";
	    
	ret = "<entities>\n";
	foreach(m->escopes, object es)
	    ret += do_f_escope(es);
	ret += "</entities>\n\n";
	
	return ret;
    }
        
    void do_file(string tdir, DocParser.PikeFile f, Stdio.File ofile)
    {
        /* First take care of the file itself */
        if (f->first_line)
	  ofile->write(f_file(f, "file"));

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
        /* First take care of the file itself */
        if (f->first_line)
            ofile->write(f_file(f, "module"));

        /* Now the globvars */
        if (f->globvars)
            ofile->write(f_globvars(f));

        /* Next the methods */
        if (f->methods)
            ofile->write(f_methods(f));
	    
	/* And Classes */
	if (f->classes)
	    ofile->write(f_classes(f));

	/* And Tags */
	if (f->tags)
	  ofile->write(f_tags(f));

	/* And containers */
	if (f->containers)
	  ofile->write(f_containers(f));
	  
	/* Some entities, please */
	if (f->escopes)
	  ofile->write(f_entities(f));
	 
	ofile->write("</module>");
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
		end_output();
            }   
        }

        if (modules) {
            foreach(modules, DocParser.Module m) {
                output_file(subdirs[1] + "/", m);
		end_output();
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
        
        f = Stdio.File(fname, "cwt");
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
    private string header = #string "header-monolith.xml";
    private string footer = #string "footer-monolith.xml";
    private Stdio.File fout;
    
    object(Stdio.File) create_file(string tdir, string fpath)
    {
        if (fout) {
            fout->write(sprintf("\n\n<!-- %s -->\n", fpath));
            return fout;
        }
        
        string fname = tdir + "/docs.xml";

        if (!Stdio.mkdirhier(dirname(fname)))
            throw(({"Cannot create directory '" + dirname(fname) + "'\n", backtrace()}));

        fout = Stdio.File(fname, "cwt");
        if (fout)
            fout->write(replace(header, tvars, map_variables()));

        fout->write(sprintf("\n\n<!-- %s -->\n", fpath));
        
        return fout;
    }

    void close_file(Stdio.File f)
    {
        f->write("\n<!-- file end -->\n");
    }

    void end_output()
    {
        if (fout) {
            fout->write(footer);
            fout->close();
        }
        fout = 0;
    }
    
    void create(array(object) f, array(object) m, string rpath)
    {
        ::create(f, m, rpath);
        fout = 0;
    }
}
