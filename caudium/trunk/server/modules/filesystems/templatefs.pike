// This is a roxen module. (c) Martin Baehr 1999-2003

// templatefs.pike 
// template adding filesystem
// based on an idea from per hedbor

//  This code is (c) 1999 Martin Baehr, and can be used, modified and
//  redistributed freely under the terms of the GNU General Public License,
//  version 2.
//  This code comes on a AS-IS basis, with NO WARRANTY OF ANY KIND, either
//  implicit or explicit. Use at your own risk.
//  You can modify this code as you wish, but in this case please
//  - state that you changed the code in the modified version
//  - do not remove my name from it
//  - send me a copy of the modified version or a patch, so that
//    I can include it in the 'official' release.
//  If you find this code useful, please e-mail me. It would definitely
//  boost my ego :)
//  
//  For risks and side-effects please read the code or ask your local 
//  unix or roxen-guru.

#include <module.h>
#include <stdio.h>
inherit "caudiumlib";
inherit "module";

constant cvs_version="$Id$";

//constant cvs_version = (my_cvs_version-"Exp $")+" / "
//             +((::cvs_version -" Exp $")-"$Id: ");

void create()
{
  Caudium.unload_program("utils");
  Caudium.unload_program("modules/filesystems/filesystem");

 // ::create();
  defvar("mountpoint", "/", "Mount point", TYPE_LOCATION, 
         "This is where the module will be inserted in the "+
         "namespace of your server.");

  defvar("dirtmpl", "template.dir", "directory template",
             TYPE_STRING, 
	     "Template for the directory it resides in. "
	     //"If it is missing the directory template from the parent dir "
	     //"will be applied."
	     );

// there still some issues to be resolved, essentially in one directory
// it should be possible to set a template for the current directory
// and one for all subdirs 

  defvar("filetmpl", "template.file", "file template",
             TYPE_STRING, 
	     "Template for each file in the current directory"
	     //"If it is missing the file template from the parent dir "
	     //"will be applied."
	     );
}

static private string doc()
{
  return "currently two types of templates are supported:<br>\n"
         "<dl>"
         "\n<dt><b>file templates</b>"
         "<dd>the file template is applied to files in the current directory "
         "\n(if the value starts with a / it is taken as an absolute path within the virtual filesystem)"
         "\n<dt><b>directory templates</b>"
         "<dd>these are applied after the file template has been applied, "
         "first the directory template residing in the same directory with "
         "the file, then successively each directory template up the path "
         "until the base directory of the filesystem is reached."
         "\n<dt>(each template type may be disabled by leaving the field empty)"
         "\n<dt>the following types are planned:"
         "\n<dt><b>recursive or default file templates</b>"
         "<dd>if there is no file template in the current directory, "
         "the path is searched upward until a default template is found."
         "\n<dt><b>recursive or default directory templates</b>"
         "<dd>like the default file template, if a directory template is "
         "missing the path will be searched upwards until a default "
         "directory template is found, and since directory templates are "
         "applied for each directory in the path, the same will happen here, "
         "thus eventually the same template may be applied multiple times."
         "</dl>\n"
         "in templates you may use the following tags and containers:"
         "<dl>"
         "\n<dt><b><tt>&lt;tmplinsertall&gt;</tt></b>"
         "<dd>will simply insert the whole contents"
         "\n<dt><b><tt>&lt;tmplinserblock&gt;</tt></b>"
         "<dd>will insert the contents of the container which is "
         "named in the argument <tt>container</tt>:"
         "\n<dt><b><tt>&lt;tmploutput&gt;&lt;/tmploutput&gt;</tt></b>"
         "<dd>will allow to insert all kinds of variables"
         "  <dl>"
         "  \n<dt><b>#file#</b>"
         "  <dd>the name of the directory (or file), the template is being "
         "  applied to"
         "  \n<dt><b>#path#</b>"
         "  <dd>the path to the directory (or file), the template is being "
         "  applied to"
         "  \n<dt><b>#base#</b>"
         "  <dd>the basename (the part of the filename before the first '.'"
         "  of the directory (or file), the template is being applied to"
         "  \n<dt><b>#targetfile#</b>"
         "  <dd>the name of the target file, (the one to which the "
         "  file template is being applied to)"
         "  \n<dt><b>#targetpath#</b>"
         "  <dd>the path to the target file."
         "  \n<dt><b>#targetdir#</b>"
         "  <dd>the name of the directory the targetfile resides in."
         "  \n<dt><b>#target#</b>"
         "  <dd>if the targetfile is an indexfile this is equal to the "
	 "  targetdir, otherwise it is equal to the targetfile."
         "</dl>";
}

array register_module()
{
  return ({
    MODULE_LOCATION|MODULE_PARSER,
    "template filesystem",
    "Indeed. Template adding filesystem with image viewing extras "
    "(per hedbor)<p>\n"+doc(),
  });
}

int notemplate( string fn, object id )
{
  return (!!id->prestate->notmpl ||
          !!id->conf->stat_file( query_location() + 
                                 dirname( fn+"foo" ) + 
                                 "/.notmpl", id ));
}

string apply_template(string newfile, string f, string template, object id)
{
  string file;

  werror("templatefs: loop: %s ...", template);
  if(file=id->conf->try_get_file(template, id))
  {
    werror(" found\n");
    file = Caudium.parse_html(file, ([]), ([ "tmploutput":icontainer_tmploutput ]), id, f);
    
    newfile = Caudium.parse_html(file, ([ "tmplinsertall":itag_tmplinsertall, 
        "tmplinsertblock":itag_tmplinsertblock]), ([]), id, newfile);
  }
  else
    werror(" not found\n");

  return newfile;
}

string apply_all_templates( string f, string file, object id )
{
  string template="";
  array cd = ("/"+f) / "/";
  
  werror("templatefs: %s, %O\n", f, cd);

  //for(i=0; i<sizeof(cd)-1; i++)
  int i = sizeof(cd)-1;

  // first apply the file template

  if(query("filetmpl")[0]=='/')
    template=query("filetmpl");
  else
    template=query_location()+cd[..i-1]*"/" + "/" + query("filetmpl");
  if(!(<"", "NONE">)[query("filetmpl")])
    file = apply_template(file, "/"+f, template, id);

  if((<"", "NONE">)[query("dirtmpl")])
    return file;

  // and then step down the directory path and i
  // apply the directory template found in each dir.
  while( i-- )
  {
    werror("templatefs: outloop: %s ...", 
           query_location()+cd[..i]*"/" + "/" + query("dirtmpl"));

    template=query_location()+cd[..i]*"/" + "/" + query("dirtmpl");
    file = apply_template(file, query_location()+cd[..i+1]*"/", template, id);
  }  
  return file;
}

string template_for( string f, object id )
{
  string current_dir = query_location()+dirname(f+"foo")+"/";
  werror("templatefs: %s, %s\n", f, current_dir);
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
  {
    werror("templatefs: "+cd[..i]*"/"+"/template ...");
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
    {
      werror(" found\n");
      return cd[..i]*"/"+"/template";
    }
    else
      werror(" not found\n");
  }
}

mixed find_file( string f, object id )
{

  werror("templatefs:find_file%d: %s%s\n", id->misc->templatefs_internal_get, f, (id->query?"?"+id->query:""));

  if(id->misc->templatefs_internal_get)
    return 0;

  string template, vtemplate;

  mapping defines = id->misc->defines || ([]);
  id->misc->defines = defines;

  mapping file;
  catch
  {
    file = get_file( f, id);
  };

  if(!file)
    return 0;

  werror("templatefs:found: %s:%d\n", file->type, sizeof(file->data||""));

//    if( notemplate( f, id ) )
//      return retval;

    // add template to all rxml/html pages...
    switch( (file->type/";")[0] )
    {
     case "text/html":
     case "text/rxml":
     {
       string contents;
       contents = apply_all_templates(f, file->data, id);
       //werror("new contents: %s\n", contents);
       return http_string_answer(contents);
     }  
     default: return 0;
    }
}

string icontainer_tmploutput(string container, mapping arguments, string contents, object id, string path)
{
  string file, dirname;
  string target, targetfile, targetpath, targetdirname;
  
  array thepath=path/"/";
  array thetarget=id->not_query/"/";

  file = thepath[-1];
  dirname = Caudium.simplify_path((thepath[..sizeof(thepath)-2])*"/");

  array indexfiles = id->conf->dir_module->query("indexfiles");

  targetfile = thetarget[-1];
  targetdirname = thetarget[sizeof(thetarget)-2];

  if(search(indexfiles, thetarget[-1])==-1)
    target = targetfile;
  else
    target = targetdirname;
  
  targetpath = Caudium.simplify_path((thetarget[..sizeof(thetarget)-2])*"/");

  werror("templatefs: tmploutput: %s, %s, %s, %s, %s, %s, %s, %s\n", dirname, file, (file/".")[0], targetfile, targetpath, targetdirname, target, id->not_query );
  return replace(contents, 
        ({ "#file#", "#path#", "#base#", "#targetfile#", "#targetpath#", "#targetdir#", "#target#" }), 
	({ file, dirname, (file/".")[0], targetfile, targetpath, targetdirname, target }));
}

string itag_tmplinsertblock(string tag, mapping arguments, object id, string filecontents)
{
  return Caudium.parse_html(filecontents, ([]), ([ arguments->container:
       lambda(string tag, mapping arguments, string contents)
       { return contents; }
       ]));
}

string itag_tmplinsertall(string tag, mapping arguments, object id, string filecontents)
{
  return filecontents;
}

string tag_templatefs(string name, 
                     mapping arguments, 
	             object id)
{
  if(arguments->help)
    return("<obox><title>the template filesystem</title>"+doc()+"</obox>");

}

string query_location()
{
  return QUERY(mountpoint);
}

mapping query_tag_callers()
{
  return ([ "templatefs":tag_templatefs ]);
}

mapping get_file(string s, object id, int|void nocache)
{
  string res="";
  mapping m;
  mapping result = ([ ]);

  id->misc->templatefs_internal_get=1;
  m = id->conf->get_file(id);

  werror("templatefs:get_file: %O\n", m);

  if(!m || !(< 0, 200, 201, 202, 203 >)[m->error]) 
    return 0;

  if(m->data) 
    res = m->data;
  m->data = 0;

  if(m->file)
  {
    res += m->file->read();
    destruct(m->file);
    m->file = 0;
  }

  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }

  result->type = m->type||"application/octet-stream";
  result->data = res;

  return result;
}

mapping try_get_file(string s, object id, int|void nocache)
{
  string res="";
  object fake_id;
  mapping m;
  mapping result = ([ ]);


  // id->misc->common makes it possible to pass information to
  // the originating request.
  if ( !id->misc )
    id->misc = ([]);
  if ( !id->misc->common )
    id->misc->common = ([]);

  fake_id = id->clone_me();
  fake_id->misc->common = id->misc->common;
  fake_id->query=id->query;
  fake_id->raw_url=id->raw_url;
  fake_id->not_query=id->not_query;
  fake_id->misc->templatefs_internal_get=1;

  m = id->conf->get_file(fake_id);

  werror("templatefs:try_get_file: %O\n", m);

  fake_id->end();

  if(!m || !(< 0, 200, 201, 202, 203 >)[m->error]) 
    return 0;

  if(m->data) 
    res = m->data;
  m->data = 0;

  if(m->file)
  {
    res += m->file->read();
    destruct(m->file);
    m->file = 0;
  }

  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }

  result->type = m->type||"application/octet-stream";
  result->data = res;

  return result;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: dirtmpl
//! Template for the directory it resides in. 
//!  type: TYPE_STRING
//!  name: directory template
//
//! defvar: filetmpl
//! Template for each file in the current directory
//!  type: TYPE_STRING
//!  name: file template
//
