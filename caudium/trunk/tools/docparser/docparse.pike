#!/usr/bin/pike7-cvs -M./

#error THIS IS A TEMPORARY SCRIPT - MODIFY BY HAND TO MAKE IT WORK
int main()
{
    object o = DocParser.Parse("q");
    object g;
    string topdir = "/usr/src/Caudium/caudium/server/";
    
    o->parse(topdir);
    g = DocGenerator.TreeMirror(o->files, o->modules, topdir);
    g->generate("./docs");
    
    return 0;
}