// This is a roxen module. (c) Martin Baehr 1999

// templatefs.pike 
// template adding filesystem
// based on code from per hedbor

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
inherit "modules/filesystems/filesystem";
inherit "utils";
//inherit "relinsert.pike";

constant my_cvs_version="$Id$";

constant cvs_version = (my_cvs_version-"Exp $")+"<br>"
             +(((::cvs_version*"<br>") -" Exp $")-"$Id: ");

void create()
{
  unload_program("utils");
  //unload_program("relinsert");
  unload_program("modules/filesystems/filesystem");

  ::create();

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

array register_module()
{
  return ({
    MODULE_LOCATION,
    "template filesystem",
    "Indeed. Template adding filesystem with image viewing extras",
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
  if(id->conf->real_file(template, id))
  {
    file = read_file( id->conf->real_file(template, id));
    werror(" found\n");
    file = parse_html(file, ([]), ([ "tmploutput":icontainer_tmploutput ]), id, f);
    
    newfile = parse_html(file, ([ "tmplinsertall":itag_tmplinsertall ]), ([]), id, newfile);
  }
  else
    werror(" not found\n");

  return newfile;
}

string apply_all_templates( string f, string file, object id )
{
  array cd = ("/"+f) / "/";
  
  werror("templatefs: %s, %O\n", f, cd);

  //for(i=0; i<sizeof(cd)-1; i++)
  int i = sizeof(cd)-1;

  // first apply the file template

  string template=query_location()+cd[..i-1]*"/" + "/" + query("filetmpl");
  file = apply_template(file, "/"+f, template, id);

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
  string template, vtemplate;

  mixed retval = ::find_file( f, id );
  if( intp( retval ) || mappingp( retval ) )
    return retval;

  //if(!(template=id->conf->real_file(vtemplate = fix_relative(template_for(f,id),id),id)))
  //  return retval;
  
  if( id->variables["content-type"] )
    return http_file_answer( retval, id->variables["content-type"] );

  
  if( id->variables->show_img )
  {
    id->variables->image = id->not_query;
    m_delete( id->variables, "show_img" );
    return http_string_answer( parse_rxml( ::find_file( "/showimg", id )->read(), id ) );
  } 
  else 
  {
    if( notemplate( f, id ) )
      return retval;
    // add template to all rxml/html pages...
    string type = id->conf->type_from_filename( id->not_query );
    switch( type )
    {
     case "text/html":
     case "text/rxml":
     {
       string contents;
       string file=retval->read();

       werror("templatefs: %s", apply_all_templates(f, file, id));
       contents = apply_all_templates(f, file, id);
       
       //contents = parse_html(contents, ([ "tmplinsertall":itag_tmplinsertall ]), ([]), id, file);
       
       return http_string_answer(parse_rxml(contents, id));

     }
//       return http_string_answer( parse_rxml("<use file="+template_for(f,id)+">"
//                                             "<tmpl-head title=\""+f+"\">"+
//                                             retval->read()+"<tmpl-foot>", id) );
    }
  }
  return retval;
} 

string icontainer_tmploutput(string container, mapping arguments, string contents, object id, string path)
{
  string file, dirname;
  array thepath=path/"/";

  file = thepath[-1];
  dirname = simplify_path((thepath[..sizeof(thepath)-2])*"/");

  werror("templatefs: tmploutput: %s, %s\n", dirname, file);
  return replace(contents, ({ "#file#", "#path#", "#base#" }), ({ file, dirname, (file/".")[0] }));
}

string itag_tmplinsertall(string tag, mapping arguments, object id, string filecontents)
{
  return filecontents;
}
