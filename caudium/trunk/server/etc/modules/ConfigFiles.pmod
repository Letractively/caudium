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
//

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

    //! The storage area. Contains all the regions read from the config
    //! file and, within the regions, the variables defined for them.
    //! Each region is a mapping that maps a variable name to its value.
    mapping(string:mapping) regions;
    
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

        regions = ([]);
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

        
        return 0;
    }
    
    //! Parse the associated file. If the parsing is successful then the
    //! @[regions] mapping will contain all the variables defined in the
    //! file. Otherwise the mapping will be empty.
    //!
    //! @returns
    //! 0 (or any other integer) if there was no error parsing the file, an
    //! error message otherwise.
    //!
    int|string parse()
    {
        if (!my_dir || !mappingp(my_file_format) || !sizeof(my_file_format) || !my_file)
            return "Object not initialized properly.";

        regions = ([]);
        
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
