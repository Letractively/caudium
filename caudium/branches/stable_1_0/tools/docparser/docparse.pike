#!/usr/local/bin/pike -M./
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 *
 */
import Getopt;

/*
 * Usage:
 *
 * ./docparse.pike [options] topdir
 *
 * where, options are:
 *
 *   -t, --tree       - generate a documentation tree mirroring the
 *                      original directory structure of the parsed
 *                      source tree.
 *   -m, --monolith   - generate single file per documentation set
 *                      (i.e. API and module interface)
 *   -t, --target=DIR - specify the target directory
 *   -q, --quiet      - be somewhat quiet
 *   -s, --shutup     - be completely quiet
 *   -h, --help       - show usage information
 *
 * topdir is a directory where the source files to be parsed for
 * documentation are located. All subdirectories will be searched and
 * all *.pike files will be examined.
 */
array options = ({
    ({"tree", NO_ARG, ({"--tree", "-t"}), 0, 1}),
    ({"monolith", NO_ARG, ({"--monolith", "-m"})}),
    ({"target", HAS_ARG, ({"--target", "-t"})}),
    ({"quiet", NO_ARG, ({"--quiet", "-q"})}),
    ({"shutup", NO_ARG, ({"--shutup", "-s"})}),
    ({"help", NO_ARG, ({"--help", "-h"})})
});

static int gen_type = 0;
static string quiet = "";
static string target_dir = "./docs";

void usage() 
{
    string u = "Usage:\n\n"
        "docparse.pike [options] topdir\n\n"
        "where, options are:\n\n"
        "  -t, --tree       - generate a documentation tree mirroring the\n"
        "                     original directory structure of the parsed\n"
        "                     source tree.\n"
        "  -m, --monolith   - generate single file per documentation set\n"
        "                     (i.e. API and module interface)\n"
        "  -t, --target=DIR - specify the target directory\n"
        "  -q, --quiet      - be somewhat quiet\n"
        "  -s, --shutup     - be completely quiet\n"
        "  -h, --help       - show this screen\n\n"
        "topdir is a directory where the source files to be parsed for\n"
        "documentation are located. All subdirectories will be searched and\n"
        "all *.pike files will be examined.\n\n";

    write(u);
}

int main(int argc, array(string) argv)
{
    array  option;

    foreach(find_all_options(argv, options), option) {
        switch(option[0]) {
            case "tree":
                gen_type = 0;
                break;

            case "monolith":
                gen_type = 1;
                break;

            case "target":
                target_dir = option[1];
                break;

            case "quiet":
                quiet = "q";
                break;

            case "shutup":
                quiet = "Q";
                break;

            case "help":
                usage();
                return 0;
        }
    }
    argv = get_args(argv);

    if (sizeof(argv) < 2) {
        write("You must give the starting directory on command line\n");
        return 1;
    }

    object o = DocParser.Parse(quiet);
    object g;
    
    o->parse(argv[1]);
    
    switch (gen_type) {
        case 0:
            g = DocGenerator.TreeMirror(o->files, o->modules, o->dircounts, argv[1]);
            break;

        case 1:
            g = DocGenerator.Monolith(o->files, o->modules, o->dircounts, argv[1]);
            break;
    }
    
    g->generate(target_dir);
    
    return 0;
}

