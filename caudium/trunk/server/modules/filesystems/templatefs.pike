constant cvs_version="$Id$";
#include <module.h>
inherit "modules/filesystems/filesystem";

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

string template_for( string f, object id )
{
  string current_dir = query_location()+dirname(f+"foo")+"/";
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
      return cd[..i]*"/"+"/template";
}

mixed find_file( string f, object id )
{
  mixed retval = ::find_file( f, id );
  if( intp( retval ) || mappingp( retval ) )
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
       return http_string_answer( parse_rxml("<use file="+template_for(f,id)+">"
                                             "<tmpl-head title=\""+f+"\">"+
                                             retval->read()+"<tmpl-foot>", id) );
    }
  }
  return retval;
} 
