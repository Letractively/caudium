/* Dear Emacs, this is a -*-pike-*- source file */
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2002 The Caudium Group
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

//! This module implements parsing and management of the flatfile configs on
//! the local filesystem.
string cvs_version = "$Id$";

#define FORMAT_OLD  0
#define FORMAT_XML  1

private string xml_prolog = "<?xml version=\"1.0\"?>\n<caudiumcfg>\n";
private string xml_epilog = "</caudiumcfg>";

//! This class represents the whole config directory
//!
//! @todo
//! Add caching of directory entries.
class Dir
{
    private int     file_mode;
    private string  my_dir;
    
    //! Creates an object for the specified directory. If the specified
    //! directory doesn't exist an attempt is made to create it. Throws an
    //! error should there be problems with creating/accessing the
    //! indicated directory.
    //!
    //! @param dir
    //! The directory in which the config files reside
    //!
    //! @param nfmode
    //! Mode for the newly created files. Defaults to @tt{0660@}
    //!
    //! @param ndirmode
    //! Mode for the config directory in case should it have to be
    //! created. Defaults to @tt{0750@}.
    void create(string dir, int|void nfmode, int|void ndirmode)
    {
        if (!dir || !sizeof(dir))
            throw(({sprintf("Need a directory name\n"), backtrace()}));

        if (dir[-1] != '/')
            dir += "/";

        mixed       error;
        Stdio.Stat  fs;

        error = catch{
            fs = Stdio.Stat(file_stat(dir));
        };
        
        if (fs && !fs->isdir)
            throw(({sprintf("Location '%s' already exists and it's not a directory.\n", dir),
                    backtrace()}));
        else if (error || !fs) {
            if (!Stdio.mkdirhier(dir, ndirmode || 0750))
                throw(({sprintf("Unable to create the config directory '%s'.\n", dir),
                        backtrace()}));
        }

        file_mode = nfmode || 0660;
        my_dir = dir;
    }

    //! Check whether the specified file exists and is a valid config
    //! file. For more information about which files qualify as the config
    //! ones, please see the documentation of the @[Dir.list_files()]
    //! method.
    //!
    //! @param file
    //! File to check.
    //!
    //! @returns
    //! A mapping describing the file or 0 if the file is not a valid
    //! config one.
    //!
    //! @seealso
    //!  @[Dir.list_files()]
    int|mapping is_config_file(string file)
    {
        if (!file || !sizeof(file) || file[0] == '.')
            return 0;
            
        array(int) fs = (array(int))file_stat(file);
	
        if (fs && sizeof(fs) && fs[1] <= 0)
            return 0;

        string  fc = Stdio.read_file(my_dir + file, 0, 2);
        if (!fc || !sizeof(fc))
            return 0;
            
        if (fc[0] == '6') {
            return ([
                "name" : file,
                "format" : FORMAT_OLD
            ]);
        }

        if (fc == xml_prolog) {
            return ([
                "name" : file,
                "format" : FORMAT_XML
            ]);
        }

        return 0;
    }
    
    //! List all the config files in the directory. Config files are those
    //! whose names start with something else than a dot and whose first lines
    //! contain either a Caudium config file format version in the first
    //! line (the old format) or the appropriate XML prolog, in the
    //! first two lines. The XML lines that are recognized as the Caudium
    //! config file ID are as follows:
    //!
    //!  @pre{
    //!    <?xml version="1.0"?>
    //!    <caudiumcfg>
    //!  @}
    //!
    //! Only files with @b{exactly@} such formatted lines are considered to
    //! be the config files.
    //!
    //! @returns
    //! An array of mappings describing files in this directory. Each
    //! mapping has the following format:
    //!
    //!  @mapping
    //!    @member string name
    //!     The file name
    //!
    //!    @member int format
    //!     The config file format:
    //!
    //!      @int
    //!       @value 0
    //!        Old format (as used by Roxen 1.3+ and Caudium 1.0-1.2)
    //!       @value 1
    //!        New (XML) format (as used by Caudium 1.3+)
    //!      @endint
    //!  @endmapping
    array(mapping(string:string|int)) list_files()
    {
        array(string)                      dir;
        array(mapping(string:string|int))  cfiles = ({});

        dir = get_dir(my_dir);
        foreach(dir, string file) {
            mapping|int f = is_config_file(file);
            if (!f)
                continue;

            cfiles += ({f});
        }

        return cfiles;
    }

    //! Open the specified file in this directory and return a
    //! corresponding object. If the file doesn't exist it is created.
    //!
    //! @param fname
    //! Name of the config file
    //!
    //! @returns
    //! An object corresponding to the opened file or 0 if the file
    //! couldn't have been opened/created. File is opened in the read-write
    //! mode.
    //!
    //! @note
    //! No checks are made whether the specified file actually is a config
    //! file. It is assumed that the caller got the file name from the
    //! @[Dir.list_files()] routine which does check the content of the files
    //! before returning them.
    Stdio.File open_file(string fname)
    {
        if (!fname || !sizeof(fname))
            return 0;

        if (fname == "." || fname == "..")
            return 0;

        mixed      error;
        Stdio.Stat fs;

        error = catch {
            fs = Stdio.Stat(file_stat(my_dir + fname));
        };
        
        if (fs && !fs->isreg)
            return 0;
        
        Stdio.File ret = Stdio.File(fname, "rwc");

        if (ret && !fs)
            chmod(my_dir + fname, file_mode);

        return ret;
    }

    //! Move (rename) the file.
    //!
    //! @note
    //!  The files _must_ be on the same filesystem due to the limitation
    //!  in the Pike implementation of the mv() function!
    //!
    //! @param from
    //!  The source file - without path.
    //!
    //! @param to
    //!  Target file - without path.
    //!
    //! @returns
    //!  0 (zero) on failure, 1 otherwise.
    int move(string from, string to)
    {
        return mv(mydir + "/" + from, mydir + "/" + to);
    }
    
    //! Return the path this object is managing.
    string get_path()
    {
        return my_dir;
    }
    
    static string _sprintf(int f)
    {
        switch(f) {
            case 't':
                return "ConfigFiles.Dir";

            case 'O':
                return sprintf("%t(%s)", this_object(), my_dir);
        }
    }
};

//! Implements routines to read/write a config file.
class File
{
    private Dir        my_dir;
    private Stdio.File my_file;
    private mapping    my_file_format;
    private string     my_name;
    private string     indent;
    
    //! The storage area. Contains all the regions read from the config
    //! file and, within the regions, the variables defined for them.
    Config             regions;
    
    //! Open a config file in the indicated directory creating it if it
    //! doesn't exist. Throws an error should there be any problems.
    //!
    //! @param dir
    //! Object representing a config directory where the specified file
    //! should be looked for.
    //!
    //! @param fname
    //! The file that is to be opened (or created, if it doesn't exist)
    //!
    //! @seealso
    //! @[Dir.list_files()], @[Dir.is_config_file()]
    void create(Dir dir, string fname)
    {
        init_object(dir, fname);
    }

    private int init_object(Dir dir, string fname)
    {
        if (!objectp(dir))
            throw(({"Need a valid directory object.\n", backtrace()}));

        if (!fname || !sizeof(fname))
            throw(({"Need a non-empty file name.\n", backtrace()}));
        
        my_dir = dir;

        if (!(my_file_format = my_dir->is_config_file(fname)))
            throw(({sprintf("File '%s%s' is not a valid Caudium config file.\n",
                            my_dir->get_path(), fname), backtrace()}));
        
        my_file = my_dir->open_file(fname);
        if (!my_file)
            throw(({sprintf("Couldn't open/create the config file '%s%s'\n",
                            my_dir->get_path(), fname), backtrace()}));

        my_name = fname;
        
        regions = 0;

        return 1;
    }
    
    private int|string parse_old()
    {
        string c = my_file->read();
        
        if (!c || !sizeof(c))
            return sprintf("Error parsing the config file '%s%s'\n",
                           my_dir->get_path(), my_file_format->name);

        array(string) contents = (c / "\n")[1..];

        return parse_xml(xml_prolog + (contents * "\n") + xml_epilog);
    }

    private int|string parse_xml(void|string contents)
    {
        object root;
        
        if (contents)
            root = Parser.XML.Tree.parse_input(contents);
        else
            root = Parser.XML.Tree.parse_input(my_file->read());

        if (!root)
            return sprintf("Error parsing the config file '%s%s'\n",
                           my_dir->get_path(), my_file_format->name);

        // walk the tree and build the internal configuration storage
        regions = Config(root, my_name);

        return 0;
    }
    
    //! Parse the associated file. If the parsing is successful then the
    //! @[regions] object will contain all the variables defined in the
    //! file. Otherwise the object will be undefined.
    //!
    //! @returns
    //! 0 (or any other integer) if there was no error parsing the file, an
    //! error message otherwise.
    //!
    int|string parse()
    {
        if (!my_dir || !mappingp(my_file_format) || !sizeof(my_file_format) || !my_file)
            return "Object not initialized properly.";

        regions = 0;
        
        switch(my_file_format->format) {
            case FORMAT_OLD:
                return parse_old();
                break;

            case FORMAT_XML:
                return parse_xml();
                break;
        }

        return sprintf("Unknown file format %d\n", my_file_format->format);
    }

    private string render_xml(string tname, mapping attrs, string|void contents, int|void doindent)
    {
        string att = "";
        string fmt;
        
        if (!contents)
            contents = "";
        
        if (attrs && sizeof(attrs))
            foreach(sort(indices(attrs)), string idx)
                att += sprintf("%s%s='%s'", (att != "" ? " " : ""), idx, attrs[idx]);

        if (att != "")
            att = " " + att;
        
        if (!contents)
            return sprintf("<%s%s/>",  tname, att);

        return sprintf("<%s%s>%s%s</%s>", tname, att, doindent ? "\n" : "", contents, tname);
    }

    private string get_type_desc(mixed val)
    {
        if (intp(val))
            return render_xml("int", 0, (string)val);
        else if (stringp(val))
            return render_xml("str", 0, val);
        else if (arrayp(val)) {
            string  contents = "";

            foreach(val, mixed v) {
                contents += get_type_desc(v);
            }
            
            return render_xml("a", 0, contents);
        }
        
        return 0;
    }

    private string render_variable(mapping var)
    {
        string         vcontents;

        vcontents = get_type_desc((arrayp(var->value) ? var->value[0] : var->value));
        if (!vcontents)
            return "";

        return "\t" + render_xml("var", ([ "name" : var->name ]), vcontents) + "\n";
    }
    
    int|string save(int|void nobackup)
    {
        if (!regions || !sizeof(regions))
            return "Nothing to save";
        
        if (my_file && objectp(my_file) && functionp(my_file->close))
            my_file->close();

        if (!my_dir->move(my_name, my_name + "~"))
            return "Error creating a backup copy of the file";

        my_file = my_dir->open_file(my_name);

        if (!my_file) {
            // try to clean up...
            my_dir->mv(my_name + "~", my_name);
            return "Error writing the file";
        }

        my_file->write(xml_prolog);

        indent = "";
        
        foreach(indices(regions->regions), string reg) {
            string   rcont = "";

            indent += "  ";

            foreach(indices(regions->regions[reg]), string var) {
                if (var == "@name@")
                    continue;
                
                rcont += render_variable(regions->regions[reg][var]);
            }
            
            my_file->write(render_xml("region", ([ "name" : reg ]), rcont, 1) + "\n\n");
        }

        my_file->write(xml_epilog);
        my_file->close();

        init_object(my_dir, my_name);
        return parse();
    }
    
    //! Retrieves the given variable from the given region in this
    //! configuration.
    //!
    //! @param region
    //!  The region name
    //!
    //! @param var
    //!  The variable name
    //!
    //! @returns
    //!  value of the variable or 0, if the variable/region don't exist.
    mixed retrieve(string region, string var)
    {
        if (regions)
            return regions->retrieve(region, var);

        return 0;
    }

    //! Stores (and creates if it doesn't exist) a variable in the
    //! specified region. The allowed variable types are 'string', 'int'
    //! and 'array' (containing either of the three supported types).
    //!
    //! @param region
    //!  The region to store the variable in.
    //!
    //! @param var
    //!  The variable name.
    //!
    //! @param val
    //!  The variable value.
    //!
    //! @param docheck
    //!  If different than 0, the passed value will be checked for type
    //!  correctness.
    //!
    //! @returns
    //!  1 on success, 0 on failure.
    int store(string region, string var, mixed value, int|void docheck)
    {
        if (regions)
            return regions->store(region, var, value, docheck);

        return 0;
    }
    
    static string _sprintf(int f)
    {
        switch(f) {
            case 't':
                return "ConfigFiles.File";

            case 'O':
                return sprintf("%t(%s%s)", this_object(), my_dir->get_path(), my_file_format->name);
        }
    }
};

static private mapping(int:string) nodevis = ([
    Parser.XML.Tree.STOP_WALK:"STOP_WALK",
    Parser.XML.Tree.XML_ROOT:"XML_ROOT",
    Parser.XML.Tree.XML_ELEMENT:"XML_ELEMENT",
    Parser.XML.Tree.XML_TEXT:"XML_TEXT",
    Parser.XML.Tree.XML_HEADER:"XML_HEADER",
    Parser.XML.Tree.XML_PI:"XML_PI",
    Parser.XML.Tree.XML_COMMENT:"XML_COMMENT",
    Parser.XML.Tree.XML_DOCTYPE:"XML_DOCTYPE",
    Parser.XML.Tree.XML_ATTR:"XML_ATTR",
    Parser.XML.Tree.XML_NODE:"XML_NODE"
]);

//! Class that stores the contents of a parsed configuration file
class Config
{
    mapping(string:mapping)           regions;

    private mapping                   creg;
    private mapping                   cvar;
    private mapping                   carray;
    private int                       array_nest;
    
    //! Create the configuration object and populate it with data retrieved
    //! from the parsed XML file.
    //!
    //! @param root
    //!  The root of the XML tree as returned from the XML parser.
    void create(object root, string cfgname)
    {
        regions = ([]);

        cvar = 0;
        
        if (!walk_tree(root))
            throw(({sprintf("Error while traversing the config tree for '%s'\n", cfgname),
                    backtrace()}));
    }

    //! Retrieves the given variable from the given region in this
    //! configuration.
    //!
    //! @param region
    //!  The region name
    //!
    //! @param var
    //!  The variable name
    //!
    //! @returns
    //!  value of the variable or 0, if the variable/region don't exist.
    mixed retrieve(string region, string var)
    {
        if (!regions || !sizeof(regions))
            return 0;

        if (!regions[region] || !regions[region][var])
            return 0;

        if (mappingp(regions[region][var]))
            return regions[region][var]->value;

        return 0;
    }

    //! Stores (and creates if it doesn't exist) a variable in the
    //! specified region. The allowed variable types are 'string', 'int'
    //! and 'array' (containing either of the three supported types).
    //!
    //! @param region
    //!  The region to store the variable in.
    //!
    //! @param var
    //!  The variable name.
    //!
    //! @param val
    //!  The variable value.
    //!
    //! @param docheck
    //!  If different than 0, the passed value will be checked for type
    //!  correctness.
    //!
    //! @returns
    //!  1 on success, 0 on failure.
    int store(string region, string var, mixed value, int|void docheck)
    {
        if (docheck && !var_valid(value))
            return 0;
        
        if (!regions)
            regions = ([]);

        if (!regions[region])
            regions[region] = ([]);
        
        regions[region][var] = ([
            "name" : var,
            "value" : value
        ]);

        return 1;
    }

    private int var_valid(mixed value)
    {
        return 1;
    }
    
    private int handle_region(object element, mapping attrs)
    {
        if (!attrs || !sizeof(attrs)) {
            write("No attributes for the 'region' tag\n");
            return 0;
        }

        if (!attrs->name || !sizeof(attrs->name)) {
            write("'region' tag without name\n");
            return 0;
        }

        if (regions[attrs->name]) {
            write("Warning: duplicate region '%s'. Ignoring.\n", attrs->name);
            return 1;
        }

        regions += ([ attrs->name : ([]) ]);
        creg = regions[attrs->name];
        creg["@name@"] = attrs->name;

        int ret = walk_children(element);

        creg = 0;
        
        return ret;
    }

    private int handle_var(object element, mapping attrs)
    {
        if (!creg || !creg["@name@"]) {
            werror("Variable found outside of any region\n");
            return 1;
        }
        
        if (!attrs || !attrs->name || !sizeof(attrs->name)) {
            werror("Invalid variable syntax in region '%s' (missing or invalid 'name' attribute)\n",
                   creg["@name@"]);
            return 1;
        }

        cvar = ([
            "name" : attrs->name
        ]);

        carray = 0;
        
        int ret = walk_children(element);

        creg[attrs->name] = cvar;
        
        return ret;
    }

    private int handle_int(object element, mapping attrs)
    {
        string txt = String.trim_all_whites(return_text(element));
        
        if (carray) {
            carray->data += ({ (int)txt });
            return 1;
        }
        
        cvar->value = (int)txt;
        
        return 1;
    }

    private int handle_str(object element, mapping attrs)
    {
        string txt = return_text(element);
        
        if (carray) {
            carray->data += ({ txt });
            return 1;
        }
        
        cvar->value = txt;
        
        return 1;
    }

    private array convert_mappings(mapping m)
    {
        array   ret = ({});

        foreach(m->data, mixed i) {
            if (mappingp(i))
                ret += ({ convert_mappings(i) });
            else
                ret += ({ i });
        }

        return ret;
    }
    
    private int handle_a(object element, mapping attrs)
    {
        mapping        prevarray = carray;
        mapping        tmp = ([
            "data" : ({})
        ]);        

        if (!array_nest)
            cvar->value = tmp;
        else
            carray->data += ({ tmp });

        carray = tmp;
        
        array_nest++;
        int ret = walk_children(element);
        array_nest--;

        carray = prevarray;

        if (!array_nest)
            // time to clean the mess up...
            cvar->value = ({ convert_mappings(tmp) });
        
        return ret;
    }

    private int handle_caudiumcfg(object element, mapping attrs)
    {
        return walk_children(element);
    }
    
    private int process_element(object element)
    {
        switch(element->get_tag_name()) {
            case "region":
                return handle_region(element, element->get_attributes());

            case "var":
                return handle_var(element, element->get_attributes());

            case "int":
                return handle_int(element, element->get_attributes());

            case "str":
                return handle_str(element, element->get_attributes());

            case "a":
                return handle_a(element, element->get_attributes());

            case "caudiumcfg":
                return handle_caudiumcfg(element, element->get_attributes());
        }
        
        return 1;
    }

    private string return_text(object element)
    {
        string          ret = "";
        array(object)   children = element->get_children();

        foreach(children, object child)
            if (child->get_node_type() == Parser.XML.Tree.XML_TEXT)
                ret += child->get_text();
        
        return ret;
    }
    
    private int walk_children(object root)
    {
        array(object) children  = root->get_children();
        
        if (children && sizeof(children))
            foreach(children, object child)
                if (!walk_tree(child))
                    return 0;

        return 1;
    }
    
    private int walk_tree(object root)
    {
        int    flag = 1;
        
        if (!root)
            return 0;

        int      nt = root->get_node_type();

        if (nt == Parser.XML.Tree.XML_ELEMENT)
            return process_element(root);
        
        return walk_children(root);
    }
};
