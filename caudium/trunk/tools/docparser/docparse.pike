#!/usr/bin/pike7-cvs -M./

#
# THIS IS JUST A SAMPLE SCRIPT.
# It will be turned into a real program RSN - just as soon as
# the DocGenerator is finished.
#
int main()
{
    object o = DocParser.Parse("q");
    object g;
    string topdir = "/usr/src/Grendel/cvs/Caudium/caudium/server/";
    
    o->parse(topdir);
    g = DocGenerator.TreeMirror(o->files, o->modules, topdir);
    g->generate("./docs");
    
    return 0;
}