/* Dear Emacs, please note this is a -*-pike-*- file. Thank you. */

/*
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

/*
 * A sample documentation generator.
 * Generates documentation files out of the passed collection of
 * PikeFile and Module objects defined in the DocParser module
 */
#pike 7.0

import DocParser;
import Stdio;

private int f_quiet;

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

/*
 * A hierarchical index storage class.
 */
class Entry
{
    private constant        STATE_OPEN = 0;
    private constant        STATE_CLOSED = 1;
    
    private string          myName;
    private string          myTitle;
    private string          myPath;
    private string          myType;
    
    private int             myState;
    
    private array(Entry)    children;

    int                     myMode;
    
    /*
     * Private methods
     */
    private void
    out_start(Stdio.File outfile, int recurse)
    {
        outfile->write(sprintf("%s<entry type=\"%s\" name=\"%s\" path=\"%s\" ",
                               String.strmult(" ", recurse),
                               myType,
                               myName,
                               myPath));
        if (myTitle)
            outfile->write(sprintf("title=\"%s\" ", myTitle));

        if (children && sizeof(children))
            outfile->write(">\n");
        else
            outfile->write("/>\n");
    }

    private void
    out_end(Stdio.File outfile, int recurse)
    {
        if (!children || !sizeof(children))
            return;

        outfile->write(sprintf("%s</entry>\n",
                               String.strmult(" ", recurse)));
    }
    
    /*
     * Public methods
     */

    /*
     * Follow down the children chain (if any) and close the last
     * child in it. The one before last becomes the globally current
     *  index object.
     */
    Entry close()
    {        
        /* If no children, then we're the ones being closed */
        if (!children || !sizeof(children)) {
            myState = STATE_CLOSED;
            return 0;
        }
        
        /* Always the last child is the current one */
        if (children[-1]->isClosed()) {
            myState = STATE_CLOSED;
            return 0;
        }
        
        Entry ret = children[-1]->close();

        /*
         * If the child returned zero then it means we are to become
         * the current container in the entire index. Return
         * ourselves.
         */
        if (!ret) {
            return this_object();
        }
        
        return ret; /* This is the current global object */
    }

    /*
     * Add a child to this entry and make it the globally current
     * object in the index. Until that child is closed no more
     * children can be added to this object.
     */
    Entry add(Entry newentry)
    {
        if (!newentry)
            return this_object();
        
        children += ({newentry});

        return newentry;
    }

    /*
     * Output this entry and all of its children, if any
     */
    void output(Stdio.File outfile, int recurse)
    {
        out_start(outfile, recurse);

        if (children && sizeof(children))
            foreach(children, Entry child)
                child->output(outfile, recurse + 1);
        
        out_end(outfile, recurse);
    }

    int isClosed()
    {
        return (myState == STATE_CLOSED);
    }
    
    void create(string path, string type, string name, string title, int mode)
    {
        myPath = path;
        myType = type;
        myName = name;
        myTitle = title;
        myMode = mode;
        
        myState = STATE_OPEN;
        
        children = ({});
    }
};

class Index
{
    constant MODE_FILE = 1;
    constant MODE_MODULE = 2;
    
    private array(Entry)     entries;
    private int              curmode;
    private Entry            cur;
    private string           cur_path;
    
    void mode(int m, string path)
    {
        switch(m) {
            case MODE_FILE:
            case MODE_MODULE:
                curmode = m;
                break;
		
            default:
                throw(({"Incorrect mode in Index\n", backtrace()}));
        }	

        cur_path = path;
    }
    
    void add(string type, 
             string name, 
             string|void title)
    {
        Entry newentry = Entry(cur_path, type, name, title, curmode);
        
        if (cur) {
            cur = cur->add(newentry);
            return;
        }

        entries += ({newentry});
        cur = newentry;
    }
    
    void close_entry()
    {
        if (!entries || !sizeof(entries))
            return;

        cur = entries[-1]->close();
    }

    void generate(string topdir, int single_file)
    {
        Stdio.File outfile;

        if (single_file)
            outfile = Stdio.File(topdir + "/index.xml", "wct");
        else
            outfile = Stdio.File(topdir + "/files_index.xml", "wct");

        if (!outfile)
            throw(({"Cannot create output index file!\n", backtrace()}));

        if (!entries || !sizeof(entries))
            return;

        /*
         * Files always go first, modules after them
         */
        foreach(entries, Entry entry) {
            if (entry->myMode == MODE_FILE) {
                entry->output(outfile, 0);
                outfile->write("\n");
            }
        }

        if (!single_file) {
            outfile->close();
            outfile = Stdio.File(topdir + "/modules_index.xml", "wct");
            if (!outfile)
                throw(({"Cannot create output index file!\n", backtrace()}));
        }

        foreach(entries, Entry entry) {
            if (entry->myMode == MODE_MODULE) {
                entry->output(outfile, 0);
                outfile->write("\n");
            }
        }

        outfile->close();
    }
    
    void create()
    {
        curmode = 0;
        entries = ({});
        cur = 0;
    }
};

class DocGen 
{
    array(DocParser.PikeFile)     files;
    array(DocParser.Module)       modules;
    mapping(string:int)           dirs;
    string                        rel_path;
    array(string)                 tvars;
    object(Index)                 index;
    function                      sym_fn; /* current symbol index function */
    function                      close_fn; /* current index close entry fn */
    string                        fname; /* current file path */
    
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

    private string example_subst(string exm)
    {
        return replace(exm, ({"\{","{","\}","}"}),({"{","&lt;","}","&gt;"}));
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

        index->add("globvar", gv->first_line);
        
        if (gv->first_line && gv->first_line != "")
            ret += "<globvar synopsis=\"" + gv->first_line + "\"";
        else
            ret += "<globvar synopsis=\"" + ob_unnamed(gv) + "\"";

        if (gv->contents && strlen(gv->contents))
            ret += ">\n"+gv->contents + "\n</globvar>\n";
        else
            ret += "/>\n";

        index->close_entry();
        
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
        index->add("tag", tag->first_line);

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
                index->add("attribute", a->first_line);
                
                if (a->first_line)
                    ret += " syntax=\""+a->first_line+"\"";
                if (a->def && strlen(a->def))
                    ret += " default=\""+a->def+"\"";
                if (a->contents && strlen(a->contents))
                    ret += ">\n\t\t"+a->contents+"\n\t</attribute>\n";
                else
                    ret += "/>\n";
                
                index->close_entry();
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

        /* Examples */
        if (tag->examples && sizeof(tag->examples)) {
            ret += "<examples>\n";
            foreach(tag->examples, mapping ex)
                if (ex->text != "")
                    ret += sprintf("\t<example type=\"%s\">\n%s\n\t</example>\n\n",
                                   ex->first_line, example_subst(ex->text));
            ret += "</examples>\n\n";
        }

        ret += "</tag>\n\n";

        index->close_entry();
        
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

    private string f_defvar(DocParser.PikeFile|DocParser.Module f)
    {
        string   ret = "";
        if (!sizeof(f->defvars))
            return "";
        ret = "<defvars>\n";
        foreach(f->defvars, DocParser.Defvar dv)
        {
            array parts = dv->first_line / ":" - ({""});
            if(!sizeof(parts)) 
                continue;
            
            if(sizeof(parts) == 1) {
                ret += " <defvar name=\""+dv->first_line+"\"";
                index->add("defvar", dv->first_line, dv->name);
            } else {
                ret += " <defvar group=\""+String.trim_whites(parts[0])+" \"name=\""+
                    String.trim_whites(parts[1..]*":")+"\"";
                index->add("defvar", String.trim_whites(parts[1..]*":"));
            }
            index->close_entry();
            
            if (dv->name)
                ret += " short=\"" + dv->name + "\"";
	
            if(dv->type && strlen(dv->type))
                ret += " type=\""+dv->type+"\"";
            if(strlen(dv->contents))
            {
                ret += ">"+dv->contents+"</defvar>\n";
            } else
                ret += "/>\n";
        }
        ret += "</defvars>\n";
        return ret;
    }

    /* Method output */
    private mapping(string:string|array(string)) 
        dissect_method(string s)
    {
        object(Regexp)    fn = Regexp("([a-zA-Z_0-9:()|]+)[ \t]+([_a-zA-Z0-9]+)[ \t]*(.*)");
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

        index->add("method", method->name);
        
        /* Method start */
        ret += "<method name=\"" + method->name + "\">\n";
	
        /* Short description */
        if(m->name)
            ret += "<short>\n\t" + m->name + "\n</short>\n\n";

        /* Synopsis */
        ret += "<syntax>\n\t" + pretty_syntax(method) + "\n</syntax>\n\n";

        /* Alternative synopses */
        if (m->altnames && sizeof(m->altnames))
            foreach(m->altnames, mapping an)
                ret += "<syntax>\n\t" + pretty_syntax(dissect_method(an->first_line)) + "\n</syntax>\n\n";
        
        /* Description(s) */
        /* First determine whether we have one description and many forms */
        int  manydesc = 0;
        if (m->altnames && sizeof(m->altnames))
            foreach(m->altnames, mapping an)
                if (an->contents && an->contents != "")
                    manydesc++;
		    
        if (m->contents && m->contents != "")
            manydesc++;
	    
        if (manydesc) {
            if (manydesc == 1) {
                if (m->contents && m->contents != "") {
                    ret += sprintf("<description>\n%s\n</description>\n\n",
                                   m->contents);
                } else {
                    foreach(m->altnames, mapping an)
                        if (an->contents && an->contents != "")
                            ret += sprintf("<description>\n%s\n</description>\n\n",
                                           an->contents);
                }
            } else {
                if (m->contents && m->contents != "")
                    ret += sprintf("<description%s>\n%s\n</description>\n\n",
                                   (m->altnames && sizeof(m->altnames)) ? " form=\"1\"" : "",
                                   m->contents);
        
                /* Descriptions of alternative forms */
                if (m->altnames && sizeof(m->altnames)) {
                    int cnt = 1;
            
                    foreach(m->altnames, mapping an)
                        if (an->contents && an->contents != "") {
                            cnt++;
                            ret += sprintf("<description form=\"%d\">\n%s\n</description>",
                                           cnt, an->contents);
                        }
    		    }
    	    }
        }
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

        index->close_entry();
        
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

        index->add("class", c->first_line);
        
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
            ret += "\t</methods>\n";
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
            foreach(c->examples, mapping ex)
                if (ex->text != "")
                    ret += sprintf("\t<example type=\"%s\">\n%s\n\t</example>\n\n",
                                   ex->first_line, example_subst(ex->text));
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

        index->close_entry();
        
        return ret;
    }
    
    private int compare_class(object one, object two)
    {
        if (!one->first_line || !two->first_line)
            return 0;
	    
        return (one->first_line > two->first_line);
    }
    
    private string f_classes(DocParser.PikeFile f)
    {
        string   ret = "";
	
        if (!sizeof(f->classes))
            return "";
        ret = "<classes>\n";
	
        array(object) sorted = Array.sort_array(f->classes, compare_class);
	
        foreach(sorted, object c)
            ret += do_f_class(c);
        ret += "</classes>\n";
	
        return ret;
    }

    private string do_f_entity(DocParser.Entity e)
    {
        string ret = "";	

        index->add("entity", e->first_line);
        
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
            foreach(e->examples, mapping ex)
                if (ex->text != "")
                    ret += sprintf("\t<example type=\"%s\">\n%s\n\t</example>\n\n",
                                   ex->first_line, example_subst(ex->text));
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

        index->close_entry();
        
        return ret;
    }
    
    private string do_f_escope(DocParser.EntityScope es)
    {
        string ret = "";
	
        index->add("scope", es->first_line);
        
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
            foreach(es->examples, mapping ex)
                if (ex->text != "")
                    ret += sprintf("\t<example type=\"%s\">\n%s\n\t</example>\n\n",
                                   ex->first_line, example_subst(ex->text));
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

        index->close_entry();
        
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
        index->add("file", f->first_line);
        
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

        if (f->defvars)
            ofile->write(f_defvar(f));

        ofile->write("</file>");
        index->close_entry();
    }

    void do_module(string tdir, DocParser.Module f, Stdio.File ofile)
    {
        index->add("module", f->first_line);
        
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

        /* Defvar */
        if (f->defvars)
            ofile->write(f_defvar(f));

        /* Some entities, please */
        if (f->escopes)
            ofile->write(f_entities(f));
	 
        ofile->write("</module>\n\n");
        index->close_entry();
    }
    
    void output_file(string tdir, DocParser.PikeFile|DocParser.Module f)
    {
        object(Stdio.File)    ofile;

        ofile = create_file(tdir, f->rfile);
        
        switch(f->myName) {
            case "PikeFile":
                index->mode(Index.MODE_FILE, fname);
                do_file(tdir, f, ofile);
                break;

            case "Module":
                index->mode(Index.MODE_MODULE, fname);
                do_module(tdir, f, ofile);
                break;
        }

        close_file(ofile);
    }
    
    void generate(string tdir)
    {
        DocParser.trace("Generating documentation...");
        
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
        index = Index();

        if (files) {
            DocParser.trace("  ==> Files");
            foreach(files, DocParser.PikeFile f) {
                output_file(subdirs[0] + "/", f);
                end_output();
            }   
        }

        if (modules) {
            DocParser.trace("  ==> Modules");
            foreach(modules, DocParser.Module m) {
                output_file(subdirs[1] + "/", m);
                end_output();
            }
        }
        
        DocParser.trace("  ==> Index");
        index->generate(".", 1);

        DocParser.trace("Done generating");
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
    
    void create(array(object) f, array(object) m, mapping(string:int) dircounts, string rpath, int q)
    {
        files = f;
        modules = m;
        rel_path = rpath;
        dirs = dircounts;
        f_quiet = q;
        
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
    
    private int single_file = 0;
    private int write_header;
    
    /*
     * This function determines whether the original directory
     * of the source files contains the .docs file. If so, it
     * returns the same name for every file in that directory.
     * Otherwise return fname.
     */
    private string get_fname(string fname)
    {
        string srcdir =  "../" + rel_path + (dirname(fname) / "/")[1..] * "/";
        
        if (!single_file && file_stat(srcdir + "/.docs")) {
            srcdir = combine_path(getcwd(), srcdir);

            single_file = dirs[srcdir];
            write_header = 1;
            return dirname(fname) + "/docs.xml";
        } else if (single_file && file_stat(srcdir + "/.docs")) {
            write_header = 0;
            return dirname(fname) + "/docs.xml";
        } else {
            single_file = 0;
            write_header = 1;
        }
        
        return fname;
    }
    
    object(Stdio.File) create_file(string tdir, string fpath)
    {
        object(Stdio.File) f;
        fname = replace(tdir + (fpath - rel_path), ({".pike",".c",".h",".pmod"}), ({".pike.xml", ".c.xml", ".h.xml",".pmod.xml"}));
         
        if (!Stdio.mkdirhier(dirname(fname)))
            throw(({"Cannot create directory '" + dirname(fname) + "'\n", backtrace()}));
        
        string oflags = "cwt";
        if (single_file)
            oflags = "wa";
        
        f = Stdio.File(get_fname(fname), oflags);
        if (f && write_header)
            f->write(replace(header, tvars, map_variables()));

        return f;
    }

    void close_file(Stdio.File f)
    {
        if (single_file)
            single_file--;

        if (!single_file)
            f->write(footer);
        f->close();
    }
    
    void create(array(object) f, array(object) m, mapping d, string rpath, int q)
    {
        ::create(f, m, d, rpath, q);
        single_file = 0;
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
        
        fname = tdir + "/docs.xml";

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
    
    void create(array(object) f, array(object) m, mapping d, string rpath, int q)
    {
        ::create(f, m, d, rpath, q);
        fout = 0;
    }
}
