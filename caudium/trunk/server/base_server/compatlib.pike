/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2003 The Caudium Group
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
 */
/* 
 * $Id$ 
 */

//! Compatibility Library for Roxen and Caudium
//! $Id$
//! @note
//!   All theses calls are here to allow transparent migration
//!   between Roxen 1.3 and Caudium. This allows also some modules
//!   designed for Caudium to run without modifications. This Library
//!   contains also some compat call for Pike as well.

constant cvs_version = "$Id$";

// Private functions
// Used for backtrace work
static private string dbt(array t) {
  if(!arrayp(t) || (sizeof(t)<2)) return "";
  return (((t[0]||"Unknown program")-(getcwd()+"/"))-"base_server/")+":"+t[1];
}        

#define WCOMPAT(Y,X) report_error("Compat "+X+"() used in %s, please consider using "+Y+"."+X+"() instead\n",dbt(backtrace()[-2]));

#define WCOMPAT2(Y,X) report_error("Compat "+X+"() used in %s, please consider using "+Y+"() instead\n",dbt(backtrace()[-2]));

//! Compat call of Stdio.mkdirhier
//! @deprecated
static int mkdirhier(string pathname, void|int mode) {
   WCOMPAT("Stdio","mkdirhier");
   return Stdio.mkdirhier(pathname, mode);
}

//! Compat call of _Roxen.http_decode_string
//! @deprecated
static string http_decode_string(string m) {
   WCOMPAT("_Roxen","http_decode_string");
   return _Roxen.http_decode_string(m);
}

//! Compat call of _Roxen.html_encode_string
//! @deprecated
static string html_encode_string(string m) {
   WCOMPAT("_Roxen","html_encode_string");
   return _Roxen.html_encode_string(m);
}

//! Compat call of Protocols.HTTP.unentity
//! @deprecated
static string html_decode_string(string m) {
   WCOMPAT2("Protocols.HTTP.unentity","html_decode_string");
   return Protocols.HTTP.unentity(m);
}

//! Compat call of Caudium.http_encode_string
//! @deprecated
static string http_encode_string(string m) {
   WCOMPAT("Caudium","http_encode_string");
   return Caudium.http_encode_string(m);
}

//! Compat call of Caudium.HTTP.decode_url
//! @deprecated
static string http_decode_url(string m) {
   WCOMPAT2("Caudium.HTTP.decode_url","http_decode_url");
   return Caudium.HTTP.decode_url(m);
}
  

//! Compat call of Caudium.http_encode_cookie
//! @deprecated
static string http_encode_cookie(string m) {
   WCOMPAT("Caudium","http_encode_cookie");
   return Caudium.http_encode_cookie(m);
}

//! Compat call of Caudium.http_encode_url
//! @deprecated
static string http_encode_url(string m) {
   WCOMPAT("Caudium","http_encode_url");
   return Caudium.http_encode_url(m);
}

//! Compat call of Caudium.HTTP.cern_date
//! @deprecated
static string cern_http_date(int t) {
   WCOMPAT2("Caudium.HTTP.cern_date","cern_http_date");
   return Caudium.HTTP.cern_date(t);
}

//! Compat call of Caudium.HTTP.date
//! @deprecated
static string http_date(int t) {
   WCOMPAT2("Caudium.HTTP.date","http_date");
   return Caudium.HTTP.date(t);
}

//! Compat call of Caudium.HTTP.res_to_string
//! @deprecated
static string http_res_to_string(mapping file, object id) {
   WCOMPAT2("Caudium.HTTP.res_to_string", "http_res_to_string");
   return Caudium.HTTP.res_to_string(file, id);
}

//! Compat call of Caudium.HTTP.low_answer
//! @deprecated
static mapping http_low_answer(int errno, string data, void|int dohtml) {
   WCOMPAT2("Caudium.HTTP.low_answer", "http_low_answer");
   return Caudium.HTTP.low_answer(errno, data, dohtml);
} 

//! Compat call of Caudium.HTTP.pipe_in_progress
//! @deprecated
static mapping http_pipe_in_progress() {
   WCOMPAT2("Caudium.HTTP.pipe_in_progress", "http_pipe_in_progress");
   return Caudium.HTTP.pipe_in_progress();
}

//! Compat call of Caudium.HTTP.rxml_answer
//! @deprecated
static mapping http_rxml_answer(string rxml, object id,
                               void|object(Stdio.File) file, string|void type) {
   WCOMPAT2("Caudium.HTTP.rxml_answer", "http_rxml_answer");
   return Caudium.HTTP.rxml_answer(rxml, id, file, type);
}

//! Compat call of Caudium.HTTP.error_answer
//! @deprecated
static mapping http_error_answer(object id, void|int error_code,
                                 void|string name, void|string message) {
   WCOMPAT2("Caudium.HTTP.error_answer", "http_error_answer");
   return Caudium.HTTP.error_answer(id,error_code,name,message);
}

//! Compat call of Caudium.HTTP.string_anwser
//! @deprecated
static mapping http_string_answer(string text, string|void type) {
   WCOMPAT2("Caudium.HTTP.string_answer", "http_string_answer");
   return Caudium.HTTP.string_answer(text,type);
}

//! Compat call of Caudium.HTTP.make_htmldoc_string
//! @deprecated
static string make_htmldoc_string(string contents, string title, void|mapping meta,
                            void|mapping|string style, string|void dtype) {
   WCOMPAT("Caudium.HTTP", "make_htmldoc_string");
   return Caudium.HTTP.make_htmldoc_string(contents,title,meta,style,dtype);
}

//! Compat call of Caudium.HTTP.htmldoc_answer
//! @deprecated
static mapping http_htmldoc_answer(string contents, string title, void|mapping meta,
                            void|mapping|string style, string|void dtype) {
   WCOMPAT2("Caudium.HTTP.htmldoc_answer", "http_htmldoc_answer");
   return Caudium.HTTP.htmldoc_answer(contents,title,meta,style,dtype);
}

//! Compat call of Caudium.HTTP.file_answer
//! @deprecated
static mapping http_file_answer(object fd, string|void type, void|int len) {
   WCOMPAT2("Caudium.HTTP.file_answer", "http_file_answer");
   return Caudium.HTTP.file_answer(fd,type,len);
}

//! Compat call of Caudium.HTTP.config_cookie
//! @deprecated
static string http_caudium_config_cookie(string from) {
   WCOMPAT2("Caudium.HTTP.config_cookie", "http_caudium_config_cookie");
   return Caudium.HTTP.config_cookie(from);
}

//! Compat call of Caudium.HTTP.id_cookie
//! @deprecated
static string http_caudium_id_cookie() {
   WCOMPAT2("Caudium.HTTP.id_cookie", "http_caudium_id_cookie");
   return Caudium.HTTP.id_cookie();
}

//! Compat call of Caudium.HTTP.redirect
//! @deprecated
static mapping http_redirect(string url, object|void id) {
   WCOMPAT2("Caudium.HTTP.redirect", "http_redirect");
   return Caudium.HTTP.redirect(url,id);
}

//! Compat call of Caudium.HTTP.stream
//! @deprecated
mapping http_stream(object from) {
   WCOMPAT2("Caudium.HTTP.stream", "http_stream");
   return Caudium.HTTP.stream(from);
}

//! Compat call of Caudium.HTTP.auth_required
//! @deprecated
static mapping http_auth_required(string realm,string|void message,void|int dohtml) {
   WCOMPAT2("Caudium.HTTP.auth_required", "http_auth_required");
   return Caudium.HTTP.auth_required(realm,message,dohtml);
}

//! Compat call of Caudium.HTTP.proxy_auth_required
//! @deprecated
static mapping http_proxy_auth_required(string realm,void|string message) {
   WCOMPAT2("Caudium.HTTP.proxy_auth_required", "http_proxy_auth_required");
   return Caudium.HTTP.auth_required(realm,message);
}

//! Compat Call of Caudium.HTTP.proxy_auth_needed
//! @deprecated
static mapping proxy_auth_needed(object id) {
   WCOMPAT2("Caudium.HTTP.proxy_auth_needed", "http_proxy_auth_needed");
   return Caudium.HTTP.proxy_auth_needed(id);
}

// Some spider calls are not under spider module so here is some compat
// things

//! Compat call of Caudium.add_pre_state
//! @deprecated
static string add_pre_state(string url, multiset state) {
   WCOMPAT("Caudium","add_pre_state");
   return Caudium.add_pre_state(url,state);
}

//! Compat call of Caudium._match
//! @deprecated
static int _match(string w, array(string) a) {
   WCOMPAT("Caudium","_match");
   return Caudium._match(w,a);
}

//! Compat call of Caudium.short_name
//! @deprecated
static string short_name(string name) {
   WCOMPAT("Caudium","short_name");
   return Caudium.short_name(name);
}

//! Compat call of Caudium.strip_config
//! @deprecated
static string strip_config(string from) {
   WCOMPAT("Caudium","strip_config");
   return Caudium.strip_config(from);
}

//! Compat call of Caudium.strip_prestate
//! @deprecated
static string strip_prestate(string from) {
   WCOMPAT("Caudium","strip_prestate");
   return Caudium.strip_prestate(from);
}

//! Compat call of Caudium.short_date
//! @deprecated
static string short_date(int t) {
   WCOMPAT("Caudium","short_date");
   return Caudium.short_date(t);
}

//! Compat call of Caudium.is_modified
//! @deprecated
static int is_modified(string a, int t, void|int len) {
   WCOMPAT("Caudium","is_modified");
   return Caudium.is_modified(a,t,len);
}

//! Compat call of Caudium.html_to_unicade
//! @deprecated
static string html_to_unicode(string str) {
   WCOMPAT("Caudium","html_to_unicode");
   return Caudium.html_to_unicode(str);
}

//! Compat call of Caudium.unicode_to_html
//! @deprecated
static string unicode_to_html(string str) {
   WCOMPAT("Caudium","unicode_to_html");
   return Caudium.unicode_to_html(str);
}

//! Compat call of Caudium.parse_html
//! @deprecated
static string parse_html(mixed ... args) {
   WCOMPAT("Caudium","parse_html");
   return Caudium.parse_html(@args);
}

//! Compat call of Caudium.is_safe_string
//! @deprecated
static int is_safe_string(string in) {
   WCOMPAT("Caudium","is_safe_string");
   return Caudium.is_safe_string(in);
}

//! Compat call of Caudium.make_tag_attribute
//! @deprecated
static string make_tag_attributes(mapping in) {
   WCOMPAT("Caudium","make_tag_attributes");
   return Caudium.make_tag_attributes(in);
}

//! Compat call of Caudium.make_tag
//! @deprecated
static string make_tag(string tag, mapping in) {
   WCOMPAT("Caudium","make_tag");
   return Caudium.make_tag(tag,in);
}

//! Compat call of Caudium.make_container
//! @deprecated
static string make_container(string tag, mapping in, string contents) {
   WCOMPAT("Caudium","make_container");
   return Caudium.make_container(tag,in,contents);
}

//! Compat call of Caudium.add_config
//! @deprecated
static string add_config(string url, array config, multiset prestate) {
   WCOMPAT("Caudium","add_config");
   return Caudium.add_config(url,config,prestate);
}

//! Compat call of Caudium.msectos
//! @deprecated
static string msectos(int t) {
   WCOMPAT("Caudium","msectos");
   return Caudium.msectos(t);
}

//! Compat call of Caudium.backup_extension
//! @deprecated
static int backup_extension(string f) {
   WCOMPAT("Caudium","backup_extension");
   return Caudium.backup_extension(f);
}

//! Compat call of Caudium.get_size
//! @deprecated
static int get_size(mixed f) {
   WCOMPAT("Caudium","get_size");
   return Caudium.get_size(f);
}

//! Compat call of Caudium.ipow
//! @deprecated
static int ipow(int what, int how) {
   WCOMPAT("Caudium","ipow");
   return Caudium.ipow(what,how);
}

//! Compat call of simplify_path
//! @deprecated
static string simplify_path(string file) {
   WCOMPAT("Caudium","file");
   return Caudium.simplify_path(file);
}

//! Compat call of Caudium.httpdate_to_time
//! @deprecated
static int httpdate_to_time(string date) {
   WCOMPAT("Caudium","httpdate_to_time");
   return Caudium.httpdate_to_time(date);
}

//! Compat call of Caudium.int2roman
//! @deprecated
static string int2roman(int m) {
   WCOMPAT("Caudium","int2roman");
   return Caudium.int2roman(m);
}

//! Compat call of Caudium.number2string
//! @deprecated
static string number2string(int num, mapping params, mixed named) {
   WCOMPAT("Caudium","number2string");
   return Caudium.number2string(num,params,named);
}

//! Compat call of Caudium.image_from_type
//! @deprecated
static string image_from_type(string t) {
   WCOMPAT("Caudium","image_from_type");
   return Caudium.image_from_type(t);
}

//! Compat call of Caudium.parse_html_lines
//! @deprecated
static string parse_html_lines(mixed ... args) {
   WCOMPAT("Caudium","parse_html_lines");
   return Caudium.parse_html_lines(@args);
}

//! Compat call of Caudium.Env.build_vars
//! @deprecated
//! @seealso
//!  @[Caudium.Env.build_vars]
static mapping build_env_vars(string f, object id, string path_info) {
   WCOMPAT2("Caudium.Env.build_vars", "build_env_vars");
   return Caudium.Env.build_vars(f,id,path_info);
}

//! Compat call of Caudium.Env.build_caudium_vars
//! @deprecated
//! @seealso
//!  @[Caudium.Env.build_caudium_vars]
static mapping build_caudium_env_vars(object id) {
   WCOMPAT2("Caudium.Env.build_caudium_vars", "build_caudium_env_vars");
   return Caudium.Env.build_caudium_vars(id);
}

//! Compat call of spider.parse_accessed_database
//! @deprecated
//! @seealso
//!  @[spider.parse_accessed_database]
static mixed parse_accessed_database(mixed ... args) {
   WCOMPAT("spider","parse_accessed_database");
   return spider.parse_accessed_database(@args);
}

// some API calls thats are not used in current caudium.

//!  Get the size in pixels of the file pointed to by the
//!  object gif.
//! @param gif
//!  The opened Stdio.File object with the GIF image.
//! @returns
//!  The size of the image as a string in a format suitable for use
//!  in a HTML &lt;img&gt; tag (width=&quot;XXX&quot; height=&quot;YYY&quot;).
static string gif_size(object gif)
{
  report_error("Compat gif_size() used in %s, please consider using Image.Dims functions instead\n",dbt(backtrace()[-2]));

  array size;
  mixed err;
  
  err = catch{
  size = Image.Dims.get(gif);
  };
  if(err) return "";
  else {
    if(arrayp(size))
      return "width=\""+size[0]+"\" height=\""+size[1]+"\"";
    else
      return "";
  }
  return "";
}

// Pike API compat (taken from pike 7.4 sources)

//!   Instantiate a program (Pike 7.2 compatibility).
//!
//!   A new instance of the class @[prog] will be created.
//!   All global variables in the new object be initialized, and
//!   then @[lfun::create()] will be called with @[args] as arguments.
//!
//!   This function was removed in Pike 7.3, use
//!   @code{((program)@[prog])(@@@[args])@}
//!   instead.
//!
//! @deprecated
//!
//! @seealso
//!   @[destruct()], @[compile_string()], @[compile_file()], @[clone()]
//!
object new(string|program prog, mixed ... args)
{
  report_error("Compat new() used in %s, please consider using Pike 7.4 (program) cast instead\n",dbt(backtrace()[-2]));
  if(stringp(prog))
  {
    if(program p=(program)(prog, backtrace()[-2][0]))
      return p(@args);
    else
      error("Failed to find program %s.\n", prog);
  }
  return prog(@args);
}

//! @decl object clone(string|program prog, mixed ... args)
//!
//!   Alternate name for the function @[new()] (Pike 7.2 compatibility).
//!
//!   This function was removed in Pike 7.3, use
//!   @code{((program)@[prog])(@@@[args])@}
//!   instead.
//!
//! @deprecated
//!
//! @seealso
//!   @[destruct()], @[compile_string()], @[compile_file()], @[new()]

object clone(mixed ... args) {
  report_error("Compat clone() used in %s, please consider using Pike 7.4 (program) cast instead\n",dbt(backtrace()[-2]));
  return new(@args);
}

// Roxenlib / Caudiumlib API compat

// This is inside caudiumlib14
static mapping build_caudium_env_vars(object id);

//! Backward compatibility with Roxen
//! @deprecated
static mixed build_roxen_env_vars(mixed ... args) {
  report_error("Compat build_roxen_env_vars() used in %s, please consider using build_caudium_env_vars() instead\n",dbt(backtrace()[-2]));
  return build_caudium_env_vars(@args);
}

//! Compat call for Caudium.extension
//! @deprecated
static string extention(string f) {
  WCOMPAT("Caudium","extension");
  return Caudium.extension(f);
}

//! Compat call for http_caudium_id_cookie
//! @deprecated
static string http_roxen_id_cookie() {
  report_error("Compat http_roxen_id_cookie() used in %s, please consider using http_caudium_id_cookie() instead\n",dbt(backtrace()[-2]));
  return Caudium.HTTP.id_cookie();
}

//! Compat call for Caudium.HTTP.config_cookie
//! @deprecated
static string http_roxen_config_cookie(string m) {
   WCOMPAT2("Caudium.HTTP.config_cookie", "http_roxen_config_cookie");
   return Caudium.HTTP.config_cookie(m);
}

//! Compat call from Caudium.HTTP.auth_required
//! @param realm
//!   The realm of this authentication. This is show in variour methods by
//!   authenticating browser.
//! @param m
//!   Unused.
//! @param d
//!   Unused.
//! @deprecated
static mapping http_auth_failed(string realm, string|void m, int|void d) {
  report_error("Compat http_auth_failed() used in %s, please consider using Caudium.HTTP.auth_required() instead\n",dbt(backtrace()[-2]));
#ifdef HTTP_DEBUG
  report_debug("HTTP: Auth failed (%s)\n",realm);
#endif
  return Caudium.HTTP.low_answer(401, "<h1>Authentication failed.</h1>") 
         + ([ "extra_heads": ([ "WWW-Authenticate":"basic realm=\""+realm+"\"",
                               ]),
              ]);
}

//! Compat call from replace
//! @deprecated
static string do_replace(string s, mapping (string:string) m) {
  report_error("Compat do_replace() used in %s, please consider using Pike replace() instead\n",dbt(backtrace()[-2]));
  return replace(s, m);
}


//! Compatibility for Image.Color(X)->rgb()
//! @deprecated
static mixed parse_color(mixed x) {
  report_error("Compat parse_color() used in %s, please consider using Pike Image.Color( X )->rgb() instead\n",dbt(backtrace()[-2]));
  return Image.Color(x)->rgb();
}

//! Compatibility from Image.Color( X, X, X)->name()
//! @deprecated
static mixed color_name(mixed ... args) {
  report_error("Compat color_name() used in %s, please consider using Pike Image.Color( @X )->name() instead\n",dbt(backtrace()[-2]));
  return Image.Color(@args)->name();
}

//! Compatibility for indices(Image.Color)
//! @deprecated
static array list_colors() {
  report_error("Compat list_colors() used in %s, please consider using Pike indices(Image.Color) instead\n",dbt(backtrace()[-2]));
  return indices(Image.Color);
}

//! Compat for Image.Color.rgb( )->hsv();
//! @deprecated
static array rgb_to_hsv(array|int ri, int|void gi, int|void bi) {
  report_error("Compat rgb_to_hsv() used in %s, please consider using Pike Image.Color.rgb( x,x,x )->hsv(); instead\n",dbt(backtrace()[-2]));
  if(arrayp(ri))
    return Image.Color.rgb(@ri)->hsv();
  return Image.Color.rgb(ri,gi,bi)->hsv();
}
  
//! Compat for Image.Color.hsv( )->rgb();
//! @deprecated
static array hsv_to_rgb(array|int hv, int|void sv, int|void vv) {
  report_error("Compat rgb_to_hsv() used in %s, please consider using Pike Image.Color.rgb( x,x,x )->hsv(); instead\n",dbt(backtrace()[-2]));
  if(arrayp(hv))
    return Image.Color.hsv(@hv)->rgv();
  return Image.Color.hsv(hv,sv,vv)->rgb();
}

