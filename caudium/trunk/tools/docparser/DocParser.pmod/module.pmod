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
 * File parser.
 * On return it leaves two collections of objects: files and modules
 * describing, respectively, programmer's API and Caudium modules.
 */
import Stdio;

multiset wspace = (<' ', '\t'>);

private constant kwtype_err = "Wrong keyword type for '%s' in class '%s'\n";
private constant kwname_err = "Unknown keyword '%s' for class '%s'\n";
private constant obtype_err = "Wrong object type '%s' for keyword '%s' in class '%s'\n";
private constant field_redef = "Field '%s' redefined in class '%s'\n";
private constant fappend_err = "Appending line to one-line field '%s' in class '%s'. Overriding value.\n";

private int      curline;
private string   curpath;
private string   realfile;
private int      f_quiet = 0;

private void wrerr(string err)
{
    if (f_quiet < 2) {
        string lead = f_quiet ? (curpath + "(%d): ") : ("%d: ");
        
        stderr->write(sprintf(lead + err, curline));
    }
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
        else
            append_field(newstuff);
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

    private void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)) {
            switch (kw) {
                case "file":
                    first_line = newstuff;
                    break;

                case "cvs_version":
                    if (cvs_version != "")
                        field_redefined(kw);
                    
                    cvs_version = newstuff;
                    break;
    
		case "inherits":
		    inherits = ({newstuff});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
    }
};

class Method {
    inherit DocObject;
    
    string                   name;
    string                   scope;
    array(mapping(string:string))   args;
    array(string)            returns;
    array(string)            seealso;
    array(string)            notes;
    array(string)            example;
    array(string)            bugs;

    private void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw) {
                case "method":
                    first_line = newstuff;
		    if (parent)
			parent->add(this_object(), kw);
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
                    returns = ({newstuff});
                    break;

                case "see_also":
                    seealso = ({newstuff});
                    break;

                case "note":
                    notes = ({newstuff});
                    break;

                case "example":
                    example = ({newstuff});
                    break;

                case "bugs":
                    bugs = ({newstuff});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
		    args[-1]->description = newstuff;
		else
            	    args[-1]->description += newstuff;
                break;

            case "returns":
                returns[-1] += newstuff;
                break;

            case "see_also":
                seealso[-1] += newstuff;
                break;

            case "note":
                notes[-1] += newstuff;
                break;

            case "example":
                example[-1] += newstuff;
                break;

            case "bugs":
                bugs[-1] += newstuff;
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
        example = ({});
        bugs = ({});
        notes = ({});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
    
    string          scope;
    array(Method)   methods;
    array(GlobVar)  vars;
    array(string)   seealso;
    array(string)   examples;
    array(string)   bugs;
    array(string)   inherits;
    
    void new_field(string|object newstuff, string kw)
    {
        if (stringp(newstuff)){
            switch(kw){
                case "class":
                    first_line = newstuff;
                    break;

		case "inherits":
		    inherits = ({newstuff});
		    break;
		    
                case "scope":
                    scope = newstuff;
                    break;

                case "see_also":
                    seealso = ({newstuff});
                    break;

                case "example":
                    examples = ({newstuff});
                    break;

                case "bugs":
                    bugs = ({newstuff});
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
                    methods = ({newstuff});
                    break;

                case "globvar":
                    if (newstuff->myName != "GlobVar")
                        wrong_otype(kw, newstuff->myName);
                    vars = ({newstuff});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
                seealso[-1] += newstuff;
                break;

            case "example":
                examples[-1] += newstuff;
                break;

            case "bugs":
                bugs[-1] += newstuff;
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
    
    string           cvs_version;
    string           type;
    string           provides;
    array(Variable)  variables;
    array(Tag)       tags;
    array(Container) containers;
    array(Method)    methods;
    array(string)    inherits;
    
    void new_field(object|string newstuff, string kw)
    {
        if (stringp(newstuff)) {
            switch(kw) {
                case "module":
                    first_line = newstuff;
                    break;
    
		case "inherits":
		    inherits = ({newstuff});
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

                    variables = ({newstuff});
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

                    methods = ({newstuff});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
    
    array(string)    example;
    array(Attribute) attrs;
    array(string)    returns;
    array(string)    seealso;
    array(string)    notes;

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
                    returns = ({newstuff});
                    break;

                case "see_also":
                    seealso = ({newstuff});
                    break;

                case "note":
                    notes = ({newstuff});
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw){
                case "attribute":
                    attrs = ({newstuff});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
                break;

            case "returns":
                returns[-1] += newstuff;
                break;

            case "see_also":
                seealso[-1] += newstuff;
                break;

            case "note":
                notes[-1] = newstuff;
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
        example = ({});
        attrs = ({});
        returns = ({});
        seealso = ({});
        notes = ({});
    }
};

class Container {
    inherit DocObject;
    
    array(string)    example;
    array(Attribute) attrs;
    array(string)    returns;
    array(string)    seealso;
    array(string)    notes;

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
                    returns = ({newstuff});
                    break;

                case "see_also":
                    seealso = ({newstuff});
                    break;

                case "note":
                    notes = ({newstuff});
                    break;
                    
                default:
                    wrong_keyword(kw);
                    break;
            }
        } else {
            switch(kw){
                case "attribute":
                    attrs = ({newstuff});
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
                    contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
                break;

            case "returns":
                returns[-1] += newstuff;
                break;

            case "see_also":
                seealso[-1] += newstuff;
                break;

            case "note":
                notes[-1] += newstuff;
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
        example = ({});
        attrs = ({});
        returns = ({});
        seealso = ({});
        notes = ({});
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
		  contents += ((wspace[newstuff[0]] || contents == "") ? "" : " ") + newstuff;
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
static private void zero_return(object curob, string line)
{
    return 0;
}

mapping(string:object) file_scope = ([
    "module":lambda(object curob, string line) {
                 return Module(line);
             },
	     
    "cvs_version": zero_return,
    "inherits":zero_return,
    "method":lambda(object curob, string line) {
                 return Method(line, curob);
             },
	     
    "globvar":lambda(object curob, string line) {
                  return GlobVar(line, curob);
              },
    "class":lambda(object curob, string line) {
                return Class(line, curob);
            }
]);

mapping(string:object) module_scope = ([
    "file":lambda(object curob, string line) {
               return PikeFile(line);
           },
    "cvs_version": zero_return,
    "inherits":zero_return,
    "type": zero_return,
    "provides": zero_return,
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
             }
]);

mapping(string:object) tag_scope = ([
    "tag":lambda(object curob, string line) {
                    return Tag(line, curob);
                },
    "example": zero_return,
    "attribute":lambda(object curob, string line) {
                    return Attribute(line, curob);
                },
    
    "returns": zero_return,
    "see_also": zero_return,
    "note": zero_return,
    
]);

mapping(string:object) container_scope = ([
    "container":lambda(object curob, string line) {
                    return Container(line, curob);
                },
    "example": zero_return,
    "attribute":lambda(object curob, string line) {
                    return Attribute(line, curob);
                },
    "returns": zero_return,
    "see_also": zero_return,
    "note": zero_return,
]);

mapping(string:object) method_scope = ([
    "method":lambda(object curob, string line) {
               return Method(line, curob);
           },
    "name": zero_return,
    "scope": zero_return,
    "arg": zero_return,
    "returns": zero_return,
    "see_also": zero_return,
    "note": zero_return,
    "example": zero_return,
    "bugs": zero_return,
]);

mapping(string:object) globvar_scope = ([
    "globvar":lambda(object curob, string line) {
                  return GlobVar(line, curob);
              }
]);

mapping(string:object) class_scope = ([
    "class":lambda(object curob, string line) {
               return Class(line, curob);
           },
    "scope": zero_return,
    "inherits": zero_return,
    "method":lambda(object curob, string line) {
                 return Method(line, curob);
             },
    "globvar":lambda(object curob, string line) {
                  return GlobVar(line, curob);
              },
    "see_also": zero_return,
    "example": zero_return,
    "bugs": zero_return,
]);

mapping(string:object) variable_scope = ([
    "variable":lambda(object curob, string line) {
                   return Variable(line, curob);
               },
    "type": zero_return,
    "default": zero_return,
]);

mapping(string:object) attribute_scope = ([
    "attribute":lambda(object curob, string line) {
                    return Attribute(line, curob);
                },
    "default": zero_return,
]);

mapping(string:object) top_scope = ([
    "file":lambda(object curob, string line) {
               return PikeFile(line, curob);
           },
    "module":lambda(object curob, string line) {
                 return Module(line, curob);
             }
]);

mapping(string:object) cur_scope;

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
    "attribute": attribute_scope
]);

class Parse {
    private array          docmark = ({"**!", "**|", "//!", "//|"});
    private array(string)  curfile;
    private object(File)   f;
    private int            where;
    private int	           indent;
    private object(Regexp) kwreg = Regexp("(^[a-zA-Z0-9_]+):(.*)");
    private object         curob;
    private object         curparent;
    private string         lastkw;
    private int            fadded;
    private int            madded;
    
    array(PikeFile)        files;
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
    
    private void parse_line(string line)
    {
        array(string) spline;
        
        spline = kwreg->split(String.trim_whites(line));

        if (spline) {
            spline[0] = lower_case(spline[0]);
            
            if (!cur_scope[spline[0]]) {
                /*
                 * Keyword is invalid in this scope, but
                 * it might be switching scopes
                 */
                if (scopes[spline[0]]) {
                    cur_scope = scopes[spline[0]];
		    if (curob)
			curparent = curob->parent;
		} else
                    wrerr(sprintf("Unknown keyword in active scope '%s'\n", spline[0]));
            }
        
            if (cur_scope[spline[0]]) {
                object  o;
        
                lastkw = spline[0];
            
                o = cur_scope[lastkw](curparent, spline[1]);
            
                /* Check whether it's a new container */
                if (o) {
		    /* 
		     * If curparent isn't set, it means we're at
		     * the very top level and the object that's just
		     * been created is either a 'file' or 'module'
		     */
		    if (!curparent)
			curparent = curob;
//                    if (curob)
//                        curob->add(o, lastkw);
                    curob = o;
                    curob->add(String.trim_whites(spline[1]), lastkw);
                
                    if (scopes[lastkw])
                        cur_scope = scopes[lastkw];
                
                    return;
                }
            }
        }
        
        if (!curob) {
            stderr->write("  " + curline + ": no current container!\n");
            return;
        }

        if (spline) /* new keyword, but not an object */
            curob->add(String.trim_whites(spline ? spline[1] : line), lastkw);
        else
            curob->add(String.trim_whites(spline ? spline[1] : line));
        
        switch(curob->myName) {
            case "PikeFile":
                if (!files) {
                    files = ({curob});
                    fadded = 1;
                } else if (!fadded) {
                    files += ({curob});
                    fcount++;
                    fadded = 1;
                }
                break;
		
            case "Module":
                if (!modules) {
                    modules = ({curob});
                    madded = 1;
                } else if (!madded) {
                    modules += ({curob});
                    mcount++;
                    madded = 1;
                }
                break;
        }
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
	curparent = 0;
        fadded = madded = 0;
	
        cur_scope = top_scope;
	
        foreach(curfile, string line) {
            int       i = -1;
	    
            curline++;
            foreach(docmark, string mark)
                if ((i = search(line, mark)) >= 0)
                    break;
		    
            if (i < 0)
                continue;
            where = IN_DOC;
            parse_line(line[3..]);
        }
    }
    
    private void parse_tree(string top)
    {
        array(string)   dirs = ({}), files = ({});

        foreach(get_dir(top), string s) {
	  array(int) stbuf = (array)file_stat(top + s);

            if (glob("CVS", s))
                continue;
		
            if (stbuf[1] == -2)
                dirs += ({s});
            else if ((stbuf[1] > 0) && glob("*.pike", s))
                files += ({s});
        }
	
        foreach(dirs, string s)
            parse_tree(top + s + "/");

        if (!f_quiet)
            write(top + "   \n");
        
        foreach(files, string s)
            parse_file(top + s);
    }
    
    int parse(string path)
    {
        array(int)    stbuf;

        if (path[-1] != '/')
            path += "/";
        
        stbuf = (array(int))file_stat(path);
        if (!stbuf)
            throw(({"File not found: " + path + "\n", backtrace()}));

        if (stbuf[1] == -2)
            parse_tree(path);
        else
            parse_file(path);
    }
    
    void create(void|string flags)
    {
        if (flags)
            for(int i = 0; i < sizeof(flags); i++)
                switch(flags[i]) {
                    case 'q':
                        f_quiet = 1;
                        break;

                    case 'Q':
                        f_quiet = 2;
                        break;
                }
        
        f = 0;
        fcount = mcount = 0;	
    }
}

/*
 * Local variables:
 * font-lock-mode: 1
 * fill-column: 75
 * End:
 */
