#!/usr/bin/pike7-cvs -M./

//#error THIS IS A TEMPORARY SCRIPT - MODIFY BY HAND TO MAKE IT WORK
int main(int argc, array argv)
{
    object o = DocParser.Parse("q");
    object g;

    string topdir;
    if(argc == 2) 
      topdir = argv[1];
    else
      topdir = "/usr/src/Grendel/cvs/Caudium/caudium/server/";
    if(topdir[-1] != '/') topdir += "/";
    o->parse(topdir);
    g = DocGenerator.TreeMirror(o->files, o->modules, topdir);
    g->generate("./docs");
    
    return 0;
}

