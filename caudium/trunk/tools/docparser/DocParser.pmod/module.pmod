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
 * File parser.
 * On return it leaves two collections of objects: files and modules
 * describing, respectively, programmer's API and Caudium modules.
 */
import Stdio;

#undef DEBUG_PARSER

multiset wspace = (<' ', '\t', '\n'>);
multiset example_types = (<"rxml","pike">);

private constant kwtype_err = "Wrong keyword type for '%s' in class '%s'";
private constant kwname_err = "Unknown keyword '%s' for class '%s'";
private constant obtype_err = "Wrong object type '%s' for keyword '%s' in class '%s'";
private constant field_redef = "Field '%s' redefined in class '%s'";
private constant fappend_err = "Appending line to one-line field '%s' in class '%s'. Overriding value.";
private constant extype_err = "Unknown example type '%s' for class '%s'";

private int      curline;
private string   curpath;
private string   realfile;
private int      f_quiet;

private void
write_file(Stdio.File outfile, string str)
{
    if (f_quiet < 2) {
        string lead = f_quiet ? (curpath + "(%d): ") : ("%d: ");
        
        outfile->write(sprintf(lead + str + "\n", curline));
    }
}

void wrerr(string err)
{
    write_file(stderr, err);
}

void wrout(string str)
{
    write_file(stdout, str);
}

void trace(string str)
{
    if (f_quiet < 2)
        stdout->write(sprintf("%s\n", str));
}

#ifdef DEBUG_PARSER
static private void
debug(string str) 
{
    write(sprintf("%s(%d): %s\n", (curpath / "/")[-1], curline, str));
}
#else
#define debug(x)
#endif

/*
 * replace unsafe chars with appropriate entities
 */
string xml_encode_string(string str)
{
    return replace(str, ({"&", "<", ">", "\"", "\'", "\000", ":" }),
                   ({"&amp;", "&lt;", "&gt;", "&#34;", "&#39;", "&#0;", "&#58;"}));
}

/*
 * Classes corresponding to documentation classes
 */
class DocObject {
    string    lastkw;
    DocObject parent;
    
    string    rfile; /* real file */
    string    contents;
    string    first_line;
    string    myName;
    int       lineno;
    
    void wrong_keyword(string kw) 
    {
        wrerr(sprintf(kwname_err, kw, myName));
    }

    void wrong_kwtype(string kw) 
    {
        wrerr(sprintf(kwtype_err, kw, myName));
    }

    void wrong_otype(string kw, string ob)
    {
        wrerr(sprintf(obtype_err, ob, kw, myName));
    }

    void wrong_etype(string extp)
    {
        wrerr(sprintf(extype_err, extp, myName));
    }
    
    void field_redefined(string field)
    {
        wrerr(sprintf(field_redef, field, myName));
    }

    void wrong_field_append(string field)
    {
        wrerr(sprintf(fappend_err, field, myName));
    }
    
    void new_field(string|object newstuff, string kw)
    {}

    void append_field(string newstuff)
    {}
        
    /*  
     * This method is called for every line that should be added to this
     * object. If 'kw' is given, the keyword has just been parsed for the
     * first time and object should add this keyword and the corresponding
     * data (either a first line or a child object) to its collection. If
     * 'kw' is absent, object should add the passed line to the current
     * field contents. Note, that in the latter case, the function will
     * never be called with 'newstuff' being an object.
     */
    void add(string|object newstuff, void|string kw)
    {
        if (kw)
            lastkw = kw;
	
        if (kw)
            new_field(newstuff, kw);
        else {
            if(strlen(newstuff) && !wspace[newstuff[-1]])
                newstuff += " ";
            append_field(newstuff);
        }
    }    
    
    array(string) split_cvs_version()
    {
        return 0;
    }
    
    void create(object|void p)
    {
        rfile = realfile;
        contents = "";
        first_line = "";
        myName="DocObject";
        lastkw = "";
        lineno = curline;
        parent = p ? p : 0;
    }
};

class PikeFile {
    inherit DocObject;
    
    string          cvs_version;
    array(Method)   methods;
    array(GlobVar)  globvars;
    array(Class)    classes;
    array(string)   inherits;
    array(Defvar)   defvars;
    int             is_empty;
    
    private void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)) {
            switch (kw) {
                case "file":
                    first_line = newstuff;
		    is_empty = 0;
                    break;

                case "cvs_version":
                    if (cvs_version != "")
                        field_redefined(kw);
                    
                    cvs_version = newstuff;
                    break;
    
                case "inherits":
                    inherits += ({newstuff});
                    break;
		    
                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw) {
                case "method":
                    if (newstuff->myName != "Method") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }
                    
                    methods += ({newstuff});
                    break;
                    
                case "globvar":
                    if (newstuff->myName != "GlobVar") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }
                    
                    globvars += ({newstuff});
                    break;

                case "defvar":
                    if (newstuff->myName != "DefvarScope") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }
		    
                    defvars += ({newstuff});
                    break;

                case "class":
                    if (newstuff->myName != "Class") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }

                    classes += ({newstuff});
                    break;

                default:
                    wrong_keyword(kw);
                    break;
            }
        }        
    }

    private void append_field(string newstuff)
    {
        switch(lastkw) {
            case "file":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;
		
            case "cvs_version":
                wrong_field_append(lastkw);
                cvs_version = newstuff;
                break;

            case "inherits":
                inherits[-1] += newstuff;
                break;
		
            default:
                wrong_keyword(lastkw);
                break;
        }
    }
    
    array(string) split_cvs_version()
    {
        if (cvs_version)
            return (cvs_version[5 .. sizeof(cvs_version) - 3] / " ");
        else
            return 0;
    }
    
    void create(string line, object|void p)
    {
        ::create(p);
        
        myName = "PikeFile";
        
        first_line = line;
        cvs_version = "";
        methods = ({});
        globvars = ({});
        classes = ({});
        inherits = ({});
        defvars = ({});
	is_empty = 1;
    }
};

class Method {
    inherit DocObject;
    
    string                        name;
    string                        scope;
    array(mapping(string:string)) args;
    array(string)                 returns;
    array(string)                 seealso;
    array(string)                 notes;
    array(mapping(string:string)) examples;
    array(string)                 bugs;
    array(mapping(string:string)) altnames;

    private void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw) {
                case "method":
                    first_line = newstuff;
                    if (parent) {
                        debug(sprintf("Adding '%s' to parent '%s'",
                                      kw, parent->myName));
                        parent->add(this_object(), kw);
                    }
                    break;

                case "name":
                    name = newstuff;
                    break;

                case "scope":
                    scope = newstuff;
                    break;

                case "arg":
                    args += ({(["synopsis":newstuff])});
                    break;

                case "returns":
                    returns += ({newstuff + "\n"});
                    break;

                case "see_also":
                    seealso += ({newstuff + "\n"});
                    break;

                case "note":
                    notes += ({newstuff + "\n"});
                    break;

                case "example":
                    if (!example_types[newstuff]) {
                        wrong_etype(newstuff);
                        break;
                    }
                    examples += ({([])});
                    examples[-1]->first_line = xml_encode_string(newstuff);
                    examples[-1]->text = "";
                    break;

                case "bugs":
                    bugs += ({newstuff + "\n"});
                    break;

                case "alt":
                    altnames += ({([])});
                    altnames[-1]->first_line = newstuff;
                    altnames[-1]->contents = "";
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }
    
    private void append_field(string newstuff)
    {
        switch(lastkw) {
            case "method":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "name":
                if (name != "")
                    field_redefined(lastkw);
                name = newstuff;
                break;

            case "scope":
                if (scope != "")
                    field_redefined(lastkw);
                scope = newstuff;
                break;

            case "arg":
                if (!args[-1]->description)
                    args[-1]->description = newstuff + "\n";
                else
            	    args[-1]->description += newstuff + "\n";
                break;

            case "returns":
                returns[-1] += newstuff + "\n";
                break;

            case "see_also":
                seealso[-1] += newstuff + "\n";
                break;

            case "note":
                notes[-1] += newstuff + "\n";
                break;

            case "example":
                if (sizeof(examples))
            	    examples[-1]->text += xml_encode_string(newstuff) + "\n";
                break;

            case "bugs":
                bugs[-1] += newstuff + "\n";
                break;

            case "alt":
                if (sizeof(altnames))
                    altnames[-1]->contents += newstuff + "\n";
                break;
                
            default:
                wrong_keyword(lastkw);
                break;
        }
    }
    
    void create(string line, object|void p) 
    {
        ::create(p);

        myName = "Method";

        first_line = line;
        name = "";
        scope = "";
        args = ({});
        returns = ({});
        seealso = ({});
        examples = ({});
        bugs = ({});
        notes = ({});
        altnames = ({});
    }
};

class GlobVar {
    inherit DocObject;

    private void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw) {
                case "globvar":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }

    private void append_field(string newstuff)
    {
        switch(lastkw) {
            case "globvar":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;
                
            default:
                wrong_keyword(lastkw);
                break;
        }     
    }
    
    void create(string line, void|object p) 
    {
        ::create(p);
        
        first_line = line;
    }
};

class Class {
    inherit DocObject;
    
    string                        scope;
    array(Method)                 methods;
    array(GlobVar)                vars;
    array(string)                 seealso;
    array(mapping(string:string)) examples;
    array(string)                 bugs;
    array(string)                 inherits;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw){
                case "class":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "inherits":
                    inherits += ({newstuff});
                    break;
		    
                case "scope":
                    scope = newstuff;
                    break;

                case "see_also":
                    seealso += ({newstuff + "\n"});
                    break;

                case "example":
                    if (!example_types[newstuff]) {
                        wrong_etype(newstuff);
                        break;
                    }
                    examples += ({([])});
                    examples[-1]->first_line = xml_encode_string(newstuff);
                    examples[-1]->text = "";
                    break;

                case "bugs":
                    bugs += ({newstuff});
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw){
                case "method":
                    if (newstuff->myName != "Method")
                        wrong_otype(kw, newstuff->myName);
                    methods += ({newstuff});
                    break;

                case "globvar":
                    if (newstuff->myName != "GlobVar")
                        wrong_otype(kw, newstuff->myName);
                    vars += ({newstuff});
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "class":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "inherits":
                inherits[-1] += newstuff;
                break;
		
            case "scope":
                if (scope != "")
                    field_redefined(lastkw);
                scope = newstuff;
                break;

            case "see_also":
                seealso[-1] += newstuff + "\n";
                break;

            case "example":
                if (sizeof(examples))
            	    examples[-1]->text += xml_encode_string(newstuff) + "\n";
                break;

            case "bugs":
                bugs[-1] += newstuff + "\n";
                break;
                    
            default:
                wrong_keyword(lastkw);
                break;
        }        
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "Class";

        first_line = line;
        methods = ({});
        vars = ({});
        seealso = ({});
        examples = ({});
        bugs = ({});
        inherits = ({});
    }
};

class Module {
    inherit DocObject;
    
    string             cvs_version;
    string             type;
    string             provides;
    array(Variable)    variables;
    array(Tag)         tags;
    array(Container)   containers;
    array(Method)      methods;
    array(string)      inherits;
    array(EntityScope) escopes;
    array(Defvar)      defvars;
    int                is_empty;
    
    void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)) {
            switch(kw) {
                case "module":
                    first_line = newstuff;
		    is_empty = 0;
                    break;
    
                case "inherits":
                    inherits += ({newstuff});
                    break;
		                    
                case "cvs_version":
                    if (cvs_version != "")
                        field_redefined(kw);

                    cvs_version = newstuff;
                    break;

                case "type":
                    if (type != "")
                        field_redefined(kw);

                    type = newstuff;
                    break;

                case "provides":
                    if (provides != "")
                        field_redefined(kw);

                    provides = newstuff;
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw) {
                case "variable":
                    if (newstuff->myName != "Variable") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }

                    variables += ({newstuff});
                    break;

                case "tag":
                    if (newstuff->myName != "Tag") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }

                    tags += ({newstuff});
                    break;

                case "container":
                    if (newstuff->myName != "Container") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }

                    containers += ({newstuff});
                    break;
                    
                case "method":
                    if (newstuff->myName != "Method") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }

                    methods += ({newstuff});
                    break;
                    
                case "defvar":
                    if (newstuff->myName != "DefvarScope") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }
		    
                    defvars += ({newstuff});
                    break;
		    
                case "entity_scope":
                    if (newstuff->myName != "EntityScope") {
                        wrong_otype(kw, newstuff->myName);
                        return;
                    }
		    
                    escopes += ({newstuff});
                    break;
		    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }

    void append_field(string newstuff)
    {
        switch(lastkw) {
            case "module":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;
                    
            case "inherits":
                inherits[-1] += newstuff;
                break;

            case "cvs_version":
                wrong_field_append(lastkw);
                cvs_version = newstuff;
                break;

            case "type":
                type += newstuff;
                break;

            case "provides":
                provides += newstuff;
                break;
                    
            default:
                wrong_keyword(lastkw);
                break;        
        }
    }
    
    array(string) split_cvs_version()
    {
        if (cvs_version)
            return (cvs_version[5 .. sizeof(cvs_version) - 3] / " ");
        else
            return 0;
    }
    
    void create(string line, void|object p)
    {
        ::create(p);
        
        myName = "Module";
        
        first_line = line;
        provides = "";
        cvs_version = "";
        type = "";
        methods = ({});
        variables = ({});
        tags = ({});
        containers = ({});
        inherits = ({});
        escopes = ({});
        defvars = ({});
	is_empty = 1;
    }
};

class Variable {
    inherit DocObject;
    
    string          type;
    string          def;

    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw){
                case "variable":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "type":
                    type = newstuff;
                    break;

                case "default":
                    def = newstuff;
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }        
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "variable":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "type":
                type += newstuff;
                break;

            case "default":
                def += newstuff;
                break;
                    
            default:
                wrong_keyword(lastkw);
                break;
        }        
    }
    
    void create(string line, void|object p) 
    {
        ::create(p);

        myName = "Variable";

        first_line = line;
        type = "";
        def = "";
    }
};

class Tag {
    inherit DocObject;
    
    array(mapping(string:string)) examples;
    array(Attribute)              attrs;
    array(string)                 returns;
    array(string)                 seealso;
    array(string)                 notes;
    array(string)                 bugs;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw){
                case "tag":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "returns":
                    returns += ({newstuff + "\n"});
                    break;

                case "see_also":
                    seealso += ({newstuff + "\n"});
                    break;

                case "note":
                    notes += ({newstuff + "\n"});
                    break;
                    
                case "example":
                    if (!example_types[newstuff]) {
                        wrong_etype(newstuff);
                        break;
                    }
                    examples += ({([])});
                    examples[-1]->first_line = xml_encode_string(newstuff);
                    examples[-1]->text = "";
                    break;
		    
                case "bugs":
                    bugs += ({newstuff});
                    break;

                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw){
                case "attribute":
                    attrs += ({newstuff});
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }        
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "tag":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "returns":
                returns[-1] += newstuff + "\n";
                break;

            case "see_also":
                seealso[-1] += newstuff + "\n";
                break;

            case "note":
                notes[-1] += newstuff + "\n";
                break;
                    
            case "example":
                if (sizeof(examples))
                    examples[-1]->text += xml_encode_string(newstuff) + "\n";
                break;
		
            case "bugs":
                bugs[-1] += newstuff + "\n";
                break;

            default:
                wrong_keyword(lastkw);
                break;
        }
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "Tag";

        first_line = line;
        examples = ({});
        attrs = ({});
        returns = ({});
        seealso = ({});
        notes = ({});
        bugs = ({});
    }
};

class Container {
    inherit DocObject;
    
    array(mapping(string:string)) examples;
    array(Attribute)              attrs;
    array(string)                 returns;
    array(string)                 seealso;
    array(string)                 notes;
    array(string)                 bugs;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw){
                case "container":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "returns":
                    returns += ({newstuff + "\n"});
                    break;

                case "see_also":
                    seealso += ({newstuff + "\n"});
                    break;

                case "note":
                    notes += ({newstuff + "\n"});
                    break;
                    
                case "example":
                    if (!example_types[newstuff]) {
                        wrong_etype(newstuff);
                        break;
                    }
                    examples += ({([])});
                    examples[-1]->first_line = xml_encode_string(newstuff);
                    examples[-1]->text = "";
                    break;
		    
                case "bugs":
                    bugs += ({newstuff + "\n"});
                    break;

                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw){
                case "attribute":
                    attrs += ({newstuff});
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }        
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "container":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "returns":
                returns[-1] += newstuff + "\n";
                break;

            case "see_also":
                seealso[-1] += newstuff + "\n";
                break;

            case "note":
                notes[-1] += newstuff + "\n";
                break;
                    
            case "example":
                if (sizeof(examples))
            	    examples[-1]->text += xml_encode_string(newstuff) + "\n";
                break;
		
            case "bugs":
                bugs[-1] += newstuff + "\n";
                break;

            default:
                wrong_keyword(lastkw);
                break;
        }
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "Container";

        first_line = line;
        examples = ({});
        attrs = ({});
        returns = ({});
        seealso = ({});
        notes = ({});
        bugs = ({});
    }
};

class Attribute {
    inherit DocObject;
    
    string           def;

    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw){
                case "attribute":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "default":
                    def = newstuff;
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }        
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "attribute":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "default":
                def += newstuff;
                break;
                    
            default:
                wrong_keyword(lastkw);
                break;
        }        
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "Attribute";

        first_line = line;
        def = "";
    }
};

class Defvar {
    inherit DocObject;
    string type;
    string name;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw) {
                case "defvar":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "type":
                    type = newstuff;
                    break;
	    
                case "name":
                    name = newstuff;
                    break;
		    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "defvar":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "type":
                type += newstuff;
                break;
      
            case "name": 
                if (name != "")
                    field_redefined(lastkw);
                name = newstuff;
                break;

            default:
                wrong_keyword(lastkw);
                break;
        }        
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "DefvarScope";

        first_line = line;
    }
};

class Entity {
    inherit DocObject;
    
    array(mapping(string:string)) examples;
    array(string)                 seealso;
    array(string)                 notes;
    array(string)                 bugs;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw) {
                case "entity":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "see_also":
                    seealso += ({newstuff + "\n"});
                    break;

                case "note":
                    notes += ({newstuff + "\n"});
                    break;

                case "example":
                    if (!example_types[newstuff]) {
                        wrong_etype(newstuff);
                        break;
                    }
                    examples += ({([])});
                    examples[-1]->first_line = xml_encode_string(newstuff);
                    examples[-1]->text = "";
                    break;

                case "bugs":
                    bugs += ({newstuff + "\n"});
                    break;
		    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }

    void append_field(string newstuff)
    {
        switch(lastkw){
            case "entity":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "see_also":
                seealso[-1] += newstuff + "\n";
                break;

            case "note":
                notes[-1] += newstuff + "\n";
                break;

            case "example":
                if (sizeof(examples))
            	    examples[-1]->text += xml_encode_string(newstuff) + "\n";
                break;

            case "bugs":
                bugs[-1] += newstuff + "\n";
                break;

            default:
                wrong_keyword(lastkw);
                break;
        }        
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "EntityScope";

        first_line = line;
        examples = ({});
        seealso = ({});
        notes = ({});
        bugs = ({});
    }
};

class EntityScope {
    inherit DocObject;
    
    array(Entity)                 entities;
    array(mapping(string:string)) examples;
    array(string)                 seealso;
    array(string)                 notes;
    array(string)                 bugs;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw) {
                case "entity_scope":
                    first_line = newstuff;
                    if (parent)
                        parent->add(this_object(), kw);
                    break;

                case "see_also":
                    seealso += ({newstuff + "\n"});
                    break;

                case "note":
                    notes += ({newstuff + "\n"});
                    break;

                case "example":
                    if (!example_types[newstuff]) {
                        wrong_etype(newstuff);
                        break;
                    }
                    examples += ({([])});
                    examples[-1]->first_line = xml_encode_string(newstuff);
                    examples[-1]->text = "";
                    break;

                case "bugs":
                    bugs += ({newstuff + "\n"});
                    break;

                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw) {
                case "entity":
                    entities += ({newstuff});
                    break;
		    
                default:
                    wrong_keyword(kw);
                    break;
            }
        }
    }

    void append_field(string newstuff)
    {
        switch(lastkw) {
            case "entity_scope":
                if (newstuff == "")
                    contents += "\n";
                else
                    contents += newstuff + "\n";
                break;

            case "see_also":
                seealso[-1] += newstuff + "\n";
                break;

            case "note":
                notes[-1] += newstuff + "\n";
                break;

            case "example":
                if (sizeof(examples))
            	    examples[-1]->text += xml_encode_string(newstuff) + "\n";
                break;

            case "bugs":
                bugs[-1] += newstuff + "\n";
                break;

            default:
                wrong_keyword(lastkw);
                break;
        }        
    }
    
    void create(string line, void|object p)
    {
        ::create(p);

        myName = "EntityScope";

        first_line = line;
        entities = ({});
        examples = ({});
        seealso = ({});
        notes = ({});
        bugs = ({});
    }
};

/*
 * File parser
 */
constant IN_SPACE = 0;
constant IN_DOC = 1;

/*
 * keyword scopes
 *
 * Each mapping contains map from a keyword to a function which
 * returns an object corresponding to the current keyword or 0 if
 * the keyword is just an argument, not a container.
 */
mapping(string:object|string) file_scope = ([
    "cvs_version":"",
    "inherits":"",
    "defvar":lambda(object curob, string line) {
                 return Defvar(line, curob);
             },
    "method":lambda(object curob, string line) {
                 return Method(line, curob);
             },
	     
    "globvar":lambda(object curob, string line) {
                  return GlobVar(line, curob);
              },
    "class":lambda(object curob, string line) {
                return Class(line, curob);
            },
    "ScopeName":"file"
]);

mapping(string:object|string) module_scope = ([
    "cvs_version":"",
    "inherits":"",
    "type":"",
    "provides":"",
    "defvar":lambda(object curob, string line) {
                 return Defvar(line, curob);
             },
    "variable":lambda(object curob, string line) {
                   return Variable(line, curob);
               },
    "tag":lambda(object curob, string line) {
              return Tag(line, curob);
          },
    "container":lambda(object curob, string line) {
                    return Container(line, curob);
                },    
    "method":lambda(object curob, string line) {
                 return Method(line, curob);
             },
    "entity_scope":lambda(object curob, string line) {
                       return EntityScope(line, curob);
                   },
    "ScopeName":"module"
]);

mapping(string:object|string) tag_scope = ([
    "example":"",
    "attribute":lambda(object curob, string line) {
                    return Attribute(line, curob);
                },
    
    "returns":"",
    "see_also":"",
    "note":"",
    "bugs":"",
    "ScopeName":"tag"
]);

mapping(string:object|string) container_scope = ([
    "example":"",
    "attribute":lambda(object curob, string line) {
                    return Attribute(line, curob);
                },
    "returns":"",
    "see_also":"",
    "note":"",
    "bugs":"",
    "ScopeName":"container"
]);

mapping(string:object|string) method_scope = ([
    "name":"",
    "scope":"",
    "arg":"",
    "returns":"",
    "see_also":"",
    "note":"",
    "example":"",
    "bugs":"",
    "alt":"",
    "ScopeName":"method"
]);

mapping(string:object|string) globvar_scope = ([
    "ScopeName":"globvar"
]);

mapping(string:object|string) class_scope = ([
    "scope":"",
    "inherits":"",
    "method":lambda(object curob, string line) {
                 return Method(line, curob);
             },
    "globvar":lambda(object curob, string line) {
                  return GlobVar(line, curob);
              },
    "see_also":"",
    "example":"",
    "bugs":"",
    "ScopeName":"class"
]);

mapping(string:object|string) variable_scope = ([
    "type":"",
    "default":"",
    "ScopeName":"variable"
]);

mapping(string:object|string) attribute_scope = ([
    "default":"",
    "ScopeName":"attribute"
]);


mapping(string:object|string) defvar_scope = ([
    "type":"",
    "name":"",
    "ScopeName":"defvar"
]);

mapping(string:object|string) entityscope_scope = ([
    "entity":lambda(object curob, string line) {
                 return Entity(line, curob);
             },
    "bugs":"",
    "see_also":"",
    "note":"",
    "example":"",
    "ScopeName":"entity_scope"
]);

mapping(string:object|string) entity_scope = ([
    "bugs":"",
    "see_also":"",
    "note":"",
    "example":"",
    "ScopeName":"entity"
]);

mapping(string:object|string) top_scope = ([
    "file":lambda(object curob, string line) {
               return PikeFile(line, curob);
           },
    "module":lambda(object curob, string line) {
                 return Module(line, curob);
             },
    "ScopeName":"top"
]);

/*
 * Scope environment.
 *
 */
mapping(string:mixed) cur_scope = ([
    "parent":0, /* Previous scope, 0 if this is top */
    "child":0,  /* Immediate ancestor scope */
    "curob":0,  /* Current object (father of child objects) */
    "scope":0   /* Current scope of keywords */
]);

/*
 * Scope switching keywords
 */
mapping(string:mapping) scopes = ([
    "file" : file_scope,
    "module" : module_scope,
    "method" : method_scope,
    "class": class_scope,
    "tag": tag_scope,
    "container": container_scope,
    "attribute": attribute_scope,
    "entity_scope": entityscope_scope,
    "entity": entity_scope,
    "defvar": defvar_scope
]);

class Parse {
    private array          docmark = ({"**!", "**|", "//!", "//|"});
    private array(string)  curfile;
    private object(File)   f;
    private int            where;
    private int	           indent;
    private object(Regexp) kwreg = Regexp("(^[a-zA-Z0-9_-]+):(.*)");
    private object         curob;
    private string         lastkw;
    private int            fadded;
    private int            madded;
    
    array(PikeFile)        files;
    mapping(string:int)    dircounts;
    array(Module)          modules;
    int                    fcount;
    int                    mcount;
    
    private int find_first_nonwhite(string line) 
    {
        int i = 0;
	
        while(i < sizeof(line))
            if ((line[i] != ' ') && (line[i] != '\t'))
                return i;
            else
                i++;
		
        return 0;
    }

    /*
     * This function goes up the chain of scopes starting
     * from 'cs' until it finds scope that contains 'kw'
     * or hits the top scope. Returns the matching scope
     * or 0 if none matched.
     */
    private mapping find_parent_scope(mapping cs, string kw)
    {
        mapping rets = cs->parent;
	    
        while(rets) {
            debug(sprintf("  Spying scope '%s'", rets->scope->ScopeName));
            if (rets->scope && rets->scope[kw]) {
                debug(sprintf("   Has the '%s' keyword. Returning scope '%s'",
                              kw, rets->child->scope->ScopeName));
                return rets;
            } else
                rets = rets->parent;
        }
	
        return rets;
    }
    
    private int parse_line(string line)
    {
        array(string) spline;

        spline = kwreg->split(String.trim_whites(line));

        if (spline) {
            /* We have something that ends with ':' */
            lastkw = lower_case(spline[0]);
            
            if (!cur_scope->scope[lastkw]) {
                debug(sprintf("Keyword '%s' unknown in scope '%s'\n",
                              lastkw, cur_scope->scope->ScopeName));
                mapping ns = find_parent_scope(cur_scope, lastkw);
		
                if (!ns) {
                    wrerr(sprintf("Keyword '%s' is unknown/illegal in current context.", 
                                  lastkw));
                    return 0;
                }
		
                ns->child = 0;
                cur_scope = ns;
		
                debug(sprintf("Keyword switched the scope to '%s'\n", cur_scope->scope->ScopeName));
            }            	    
	    
            /* Is it a keyword in the current scope? */
            if (cur_scope->scope[lastkw]) {
                /* Yes, see whether it's an object or just a field */
                debug(sprintf("Keyword '%s' in scope '%s' found", lastkw, cur_scope->scope->ScopeName));

                if (functionp(cur_scope->scope[lastkw])) {
                    /* We have an object here */
                    object curob = cur_scope->curob;

                    debug(sprintf("Keyword creates an object (%s)",
                                  curob ? "child of " + curob->myName : "top-level"));
                    
                    object o = cur_scope->scope[lastkw](curob, "");
                    o->add(String.trim_whites(spline[1]), lastkw);
		    
                    /* Does the object switch scopes? */
                    if (scopes[lastkw]) {
                        /* Yep. Make it happen. */
                        cur_scope->child = ([]);
                        cur_scope->child->scope = scopes[lastkw];
                        cur_scope->child->parent = cur_scope;
                        cur_scope->child->child = 0;
                        cur_scope = cur_scope->child;

                        debug(sprintf("Scope switched to '%s' by object '%s'",
                                      cur_scope->scope->ScopeName, o->myName));
                        
                        cur_scope->curob = o;
                        debug(sprintf("Object '%s' set current for scope '%s'",
                                      o->myName, cur_scope->scope->ScopeName));
                    } else {
                        /* Nope. It just becomes current for this scope. */
                        cur_scope->curob = o;
                        debug(sprintf("Object '%s' set current for scope '%s'\n",
                                      o->myName, cur_scope->scope->ScopeName));                        
                    }
                } else {
                    /*
                     * We have a simple field. Add it to the current object
                     * in this scope
                     */
                    debug(sprintf("Keyword is a field of %s\n", cur_scope->curob->myName));
                    cur_scope->curob->add(String.trim_whites(spline[1]), lastkw);
                }   
            } 
        } else {
            /*
             * It's a normal line - it will be appended to the current
             * object/field
             */
            if (!cur_scope->curob) {
                wrerr(sprintf("No current container in scope '%s'!", cur_scope->scope->ScopeName));
                return 0;
            }
            if (cur_scope->curob->lastkw == lastkw)
                // cur_scope->curob->add(String.trim_whites(line));
                cur_scope->curob->add(line);
            else
                // cur_scope->curob->add(String.trim_whites(line), lastkw);
                cur_scope->curob->add(line, lastkw);
        }

        if (!cur_scope->curob) {
            wrerr(sprintf("No current container in scope '%s'!", cur_scope->scope->ScopeName));
            return 0;
        }
        
	if (cur_scope->curob->is_empty)
	    return 0;
	
        switch(cur_scope->curob->myName) {
            case "PikeFile":
                if (!files) {
                    files = ({cur_scope->curob});
                    fadded = 1;
                } else if (!fadded) {
                    files += ({cur_scope->curob});
                    fcount++;
                    fadded = 1;
                }
                break;
		
            case "Module":
                if (!modules) {
                    modules = ({cur_scope->curob});
                    madded = 1;
                } else if (!madded) {
                    modules += ({cur_scope->curob});
                    mcount++;
                    madded = 1;
                }
                break;
        }
	
	return 1;
    }
    
    private void parse_file(string path)
    {
        if (!f)
            f = File();

        if (!f->open(path, "r"))
            throw(({"Cannot open file " + path + "\n", backtrace()}));



        realfile = path;
        curpath = f_quiet ? path : (path / "/")[-1];

        if (!f_quiet)
            write("   " + curpath + "\n");
        
        curfile = f->read() / "\n";
        f->close();
        curline = 0;
        indent = -1;
        where = IN_SPACE;
        curob = 0;
        fadded = madded = 0;
	
        cur_scope->scope  = top_scope;
        cur_scope->parent = 0;
        cur_scope->child = 0;
        cur_scope->curob = 0;
	
	int stored = 0;
	
        foreach(curfile, string line) {
            int       i = -1;
	    
            curline++;
            foreach(docmark, string mark)
                if ((i = search(line, mark)) >= 0)
                    break;
		    
            if (i < 0)
                continue;
            where = IN_DOC;
            stored = parse_line(line[i+3..]);
        }
	
	if (stored) {
	    string fullpath = combine_path(getcwd(), dirname(path));

	    if (!dircounts[fullpath])
		dircounts += ([fullpath:1]);
	    else
		dircounts[fullpath]++;
	}
    }
    
    private void parse_tree(string top)
    {
        array(string)   dirs = ({}), files = ({});
        object(Regexp)  fpatt = Regexp(".*\.(pike$|c$|h$|pmod$)");
        
        foreach(get_dir(top), string s) {
            mixed st = file_stat(top + s);
            array(int) stbuf;
            if(st)
                stbuf = (array(int))st;	      

            if (glob("CVS", s))
                continue;
		
            if (stbuf[1] == -2)
                dirs += ({s});
            else if ((stbuf[1] > 0) && fpatt->match(s))
                files += ({s});
        }
	
        foreach(dirs, string s)
            parse_tree(top + s + "/");

        if (!f_quiet)
            write(top + "   \n");
        
	/*
	 * See whether we are to enforce some order on the files
	 */
	string order = read_file(top + "/.docs");
	if (order && sizeof(order)) {
	    /* First process the files given in the .docs file */
#if 0
	    foreach(files & (order / "\n"), string f) {
                files -= ({f});
                parse_file(top + f);
	    }
#else
	    /* 
	     * We have to do it this ugly way, since the above code
	     * reverse sorts the product array and that's not what
	     * we want here.
	     */
	    foreach(order / "\n", string f)
		foreach(files, string f2)
		    if (f == f2) {
			files -= ({f});
			parse_file(top + f);
		    }
#endif
	}
        
        foreach(files, string s)
            parse_file(top + s);
    }
    
    int parse(string path)
    {
        object|array(int)    stbuf;

        if (path[-1] != '/')
            path += "/";
        
        stbuf = file_stat(path);
        if (!stbuf)
            throw(({"File not found: " + path + "\n", backtrace()}));
        stbuf = (array(int))stbuf;
        if (stbuf[1] == -2) {
            trace("Parsing tree...");
            parse_tree(path);
        } else {
            trace("Parsing a file...");
            parse_file(path);
        }

        trace("Done parsing");
    }
    
    void create(void|int flags)
    {
        f_quiet = flags;
        
        f = 0;
        fcount = mcount = 0;
        dircounts = ([]);
    }
}

/*
 * Local variables:
 * font-lock-mode: 1
 * fill-column: 75
 * End:
 */
