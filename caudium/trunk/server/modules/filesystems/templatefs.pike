constant cvs_version="$Id$";
#include <module.h>
#include <stdio.h>
inherit "modules/filesystems/filesystem";
inherit "utils.pike";
inherit "relinsert.pike";

void create()
{
  unload_program("utils");
  unload_program("relinsert");
  unload_program("modules/filesystems/filesystem");

  ::create();
}

array register_module()
{
  return ({
    MODULE_LOCATION,
    "per.hedbor.org filesystem",
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

string apply_template( string f, string newfile, object id )
{
  string file; 
  array cd = ("/"+f) / "/";
  
  werror("templatefs: %s, %O\n", f, cd);

  //for(i=0; i<sizeof(cd)-1; i++)
  int i = sizeof(cd)-1;
  while( i-- )
  {
    werror("templatefs: loop: %s", query_location()+cd[..i]*"/"+"/template ...");
    if(file = read_file( id->conf->real_file(query_location()+cd[..i]*"/"+"/template", id )))
    {
      werror(" found\n");
      file = parse_html(file, ([]), ([ "tmploutput":icontainer_tmploutput ]), id, query_location()+cd[..i+1]*"/");
      file = parse_html(file, ([ "path":itag_path ]), ([]), id, query_location()+cd[..i]*"/"+"/");
      //contents = parse_html(contents, ([ "path":itag_path, "relinsert":itag_relinsert ]), ([]), id, vtemplate);
      newfile = parse_html(file, ([ "tmplinsertall":itag_tmplinsertall ]), ([]), id, newfile);
//      return query_location()+cd[..i]*"/"+"/template";
    }
    else
      werror(" not found\n");
  }
  return newfile;
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

  if(!(template=id->conf->real_file(vtemplate = fix_relative(template_for(f,id),id),id)))
    return retval;
  
  if( id->variables["content-type"] )
    return http_file_answer( retval, id->variables["content-type"] );

  
  if( id->variables->show_img )
  {
    id->variables->image = id->not_query;
    m_delete( id->variables, "show_img" );
    return http_string_answer( parse_rxml( ::find_file( "/showimg", id )->read(), id ) );
  } else {
    if( notemplate( f, id ) )
      return retval;
    // add template to all rxml/html pages...
    string type = id->conf->type_from_filename( id->not_query );
    switch( type )
    {
     case "text/html":
     case "text/rxml":
     {
       string contents = read_file(template);
       string file=retval->read();

       werror("templatefs: %s", apply_template(f, file, id));
       contents = apply_template(f, file, id);
       
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
  return replace(contents, ({ "#file#", "#path#" }), ({ file, dirname }));
}

string itag_tmplinsertall(string tag, mapping arguments, object id, string filecontents)
{
  return filecontents;
}
