/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
 */

//
//! module: Automatic sending of compressed files
//!  This module implements a suggestion by Francesco Chemolli:<br/>
//!  The modified filesystem should do about this:<br/>
//!  -check if the browser supports on-the-fly decompression<br/>
//!  -check if a precompressed file already exists.<br/>
//!  -if so, send a redirection to the precompressed file<p>
//!  So, no cost for compression, all URLs, content-types and such would
//!  remain vaild, no compression overhead and should be really simple
//!  to implement. Also, it would allow a site mantainer to
//!  choose WHAT to precompress and what not to.</p><p>
//!  This module acts as a filter, and it _will_ use one extra stat
//!  per access from browsers that support automatic decompression.</p>
//! inherits: module
//! type: MODULE_FIRST
//! cvs_version: $Id$
//

inherit "module";
inherit "caudiumlib";
inherit "cachelib";

#include <module.h>
#include <pcre.h>

//#define GZIP_DEBUG 1

constant cvs_version="$Id$";
constant thread_safe=1;

constant module_type = MODULE_FIRST|MODULE_FILTER;
constant module_name = "Compression module";
constant module_doc  = "This module will allow you to send compressed "
		"data to the client with the use of the Accept-Encoding "
		"header. Currently two modes of operation are supported:"
		"<ol><li>Sending pre-compressed version of static file from "
		"the real filesystem. This is ideal for your static content "
		"as it won't take much CPU time and remains simple.</li>"
		"<li>Creating and sending a compressed version of the content."
		" This is for dynamic content and useful if you want to use "
		"the features of this mode.</li></ol>"
		"Additionnaly for mode 2, it will use the Caudium cache. "
		"The module will cache compressed version of documents. "
		"It will make a hash on the data to decide if it should "
		"cache it or not so it can even cache dynamic content. "
		"Finally some people may find useful informations in the "
		"status and debug info screen.";
constant module_unique = 1;

#if constant(thread_create)
object global_lock  = Thread.Mutex();
#endif

// for status screen
mapping(string:int|float) stats;

// Regexp to decide wherether to compress or not
mapping regexps;

// Get ourselves a cache to store stuff in.
object gzipcache = caudium->cache_manager->get_cache( this_object() );

string status()
{
  string status = "";
#if constant (Gz.deflate)
  status += "Gz.deflate Pike module support is OK.";
  status += "<table><tr><td>CPU time used for compression:</td>";
  status += "<td>" + stats["cputime"] + " second</td></tr>";
  status += "<tr><td>Data Before Compression:</td>";
  status += "<td>" + stats["totaldata"] + " bytes</td></tr>";
  status += "<tr><td>Compressed Data:</td>";
  status += "<td>" + stats["compresseddata"] + " bytes</td></tr>";
  if(stats["totaldata"])
  {
    status += "<tr><td>Compress ratio:</td>";
    status += "<td>" + (int)((float)(stats["totaldata"] - stats["compresseddata"]) / stats["totaldata"] * 100) + "%</td></tr>";
  }
  status += "<tr><td>Not Matching data (for example excluded from regexp):</td>";
  status += "<td>" + stats["notmatchingdata"] + " bytes</td></tr>";
  if(stats["totaldata"] && stats["notmatchingdata"])
  {
    status += "<tr><td>Bandwith saving:</td>";
    status += "<td>" + (int)((float)(stats["totaldata"] 
    	           - stats["compresseddata"]) / (stats["totaldata"] + 
		   stats["notmatchingdata"]) * 100) + "%</td></tr>";
  }
  status += "<tr><td>Requests to compress:</td>";
  status += "<td>" + stats["requests2compress"] + "</td></tr>";
  status += "<tr><td>Cache hits:</td>";
  status += "<td>" + (stats["requests2compress"] - stats["cache_miss"]) + "</td></tr>";
  status += "<tr><td>Cache miss:</td>";
  status += "<td>" + stats["cache_miss"] + "</td></tr>";
  status += "</table>";
#else
  status += "<font color=\"red\">You don't have the Gz.deflate Pike module, without it you won't be "
  "able to do on the fly Gzip compression.</font>";
#endif
  return status;
}

mapping first_try(object id)
{
  NOCACHE();
  if(QUERY(gzipprecompress) && 
     id->supports->autogunzip &&
     id->conf->real_file(id->not_query + ".gz", id))
    {
      array|int gz_statfile = id->conf->stat_file(id->not_query + ".gz", id);
      array|int statfile = id->conf->stat_file(id->not_query, id);
      if(gz_statfile && statfile)
      { 
        // don't send the compressed version if it is older than 
        // the original one
        if(statfile[3] >= gz_statfile[3])
#ifdef GZIP_DEBUG
	  werror(sprintf("auto_gzip: gz file is older than original one '%s', I will not give it\n", id->not_query));
#else
	  ;
#endif
        else
        {
#ifdef GZIP_DEBUG
	  werror(sprintf("auto_gzip: sending pre compressed version of '%s'\n", id->not_query));
#endif
          // Actually, Content-Encoding is added automatically. Just had to fix
          // the extensions file to use gzip instead of x-gzip...
          id->not_query += ".gz";
        }
      }
  }
}

void create()
{
  defvar("gzipprecompress", 1, "Send compressed version of static files",
  	 TYPE_FLAG, "This option implements a suggestion by Francesco Chemolli:<br>\n"
      "The module will:\n"
      "<ul><li>check if the browser supports on-the-fly decompression</li>\n"
      "<li>check if a precompressed file already exists.</li>\n"
      "<li>if so, send a redirection to the precompressed file</li></ul>\n"
      "<p>So, no cost for compression, all URLs, content-types and such would "
      "remain vaild, no compression overhead."
      "Also, it would allow a site mantainer to "
      "choose WHAT to precompress and what not to.</p>"
      "<p>With this option, the module will acts as a filter, and it _will_ use "
      "one extra stat per access from browsers that support automatic "
      "decompression. Of course you won't be able to compress dynamic "
      "content with this option.</p>"
      "<i>Note: this option will not work if your gzip file is older than "
      "the original one.</i>",
      );
#if constant(Gz.deflate)
  defvar("gzipfly", 1, "On the fly gzip compression", TYPE_FLAG,
         "If set the module will compress data on the fly even on "
         "dynamic content. Useful if for you CPU is cheaper than "
	 "bandwith.");
  defvar("compressionlevel", 6, "Compression Level", TYPE_INT,
  	 "The compression level for the gzip dynamic compression.",
	 0, hide_gzipfly);
  defvar("minfilesize", 500, "Minimum file size", TYPE_INT,
  	 "The minimum object size this module will compress.",
	 0, hide_gzipfly);
  defvar("maxfilesize", 60000, "Maximum file size", TYPE_INT,
  	 "The maximum file size this module will compress.<br>"
	 "<i>Note: this module works only in memory</i>.",
	 0, hide_gzipfly);
  defvar("includemime", ".*", "Include: Compress these MIME types",
  	 TYPE_TEXT_FIELD,
  	 "Always compress these MIME types (Regular expression separated "
	 "by line).<br><i>Note: you will have to reload the module once you "
	 "changed the expression.</i>",
	 0, hide_gzipfly);
  defvar("includefileext", ".*", "Include: Compress these file extentions",
  	 TYPE_TEXT_FIELD, "Always compress the files ending with these "
	 "extentions (Regular expression separated by line)."
	 "<br><i>Note: you will have to reload the module once you "
	 "changed the expression.</i>", 0, hide_gzipfly);
  defvar("excludefileext", "", "Exclude: Don't compress these file extentions",
  	 TYPE_TEXT_FIELD, "Don't compresse the files ending with these "
	 "extentions (Regular expression separated by line)."
	 "<br><i>Note: you will have to reload the module once you "
	 "changed the expression.</i>",
	 0, hide_gzipfly);
  defvar("excludemime", "^image/\n^audio/\n^video/\n^application/pdf",
  	 "Exclude: Don't compress these MIME types",
  	 TYPE_TEXT_FIELD, "Don't compress these MIME types "
	 "(Regular expression separated by line)."
	 "<br><i>Note: you will have to reload the module once you "
	 "changed the expression.</i>", 0, hide_gzipfly);
}

int hide_gzipfly()
{
  return !QUERY(gzipfly);
}

// helper function for start()
array(object) compile_regexp(string text) 
{
  array _regexps = (text - "\r")/"\n";
  // the array of regexp object for a given include or
  // exclude list
  array(object) res_regexps = ({ });
  foreach(_regexps, string regexp)
    if(sizeof(regexp) > 0)
      if(catch ( res_regexps += ({ Regexp(regexp) }) ))
        report_error(sprintf("auto_gzip: Failed to compile regexp %O\n", regexp));
  return res_regexps; 
}

void start()
{
  stats = ([ 
             "totaldata": 0,
	     "compresseddata": 0,
	     "notmatchingdata": 0,
	     "cputime": 0,
	     "cache_miss": 0,
	     "requests2compress": 0 ]);
  regexps = ([ "includemime":    0,
  	       "includefileext": 0,
	       "excludemime":    0,
	       "excludefileext": 0 ]);
  regexps->includemime    = compile_regexp(QUERY(includemime));
  regexps->includefileext = compile_regexp(QUERY(includefileext));
  regexps->excludemime    = compile_regexp(QUERY(excludemime));
  regexps->excludefileext = compile_regexp(QUERY(excludefileext));
}

// taken from Cache code
static string get_hash( string data ) {
string retval;
#if constant(_Lobotomized_Crypto)
  retval = _Lobotomized_Crypto.md5()->update( data )->digest();
#elseif constant(Crypto)
  retval = Crypto.md5()->update( data )->digest();
#else
  retval = MIME.encode_base64( data );
#endif
  return sprintf("%@02x",(array(int)) retval);
}
	  
// this time we really have to compress
// because the cache miss it
string real_deflate(string _name, string _data)
{
  int level = QUERY(compressionlevel);
  level = abs(level);
  if(level > 9)
   level = 9;
#ifdef GZIP_DEBUG
  write(sprintf("auto_gzip: Cache miss, compressing '%s'\n", _name));
#endif
  int cputime = gauge {
    _data = Gz.deflate(level)->deflate(_data);
  };
#if constant(thread_create)
  object lock = global_lock->lock();
#endif
  stats["cputime"] += cputime; 
  stats["cache_miss"]++;
#if constant(thread_create)
  destruct(lock);
#endif
  gzipcache->store(cache_string(_data, _name));
  return _data;
}

string deflate(string data, object id)
{
#ifdef GZIP_DEBUG
  write(sprintf("auto_gzip: need compressed version of '%s'\n", id->not_query));
#endif
#if constant(thread_create)
  object lock = global_lock->lock();
#endif  
  stats["requests2compress"]++;
#if constant(thread_create)
  destruct(lock); 
#endif   
  // we made a hash on the data and decide to cache or not
  string hash = get_hash(data); 
  if(id->pragma->nocache)
    gzipcache->refresh(hash);
  data = gzipcache->retrieve(hash, real_deflate, ({ hash, data }));  
  return data[2..sizeof(data)-5];
}

string gzip_PrintFourChars(int val)
{
  string result = "";
  for (int i = 0; i < 4; i ++)
  {
    result += sprintf("%c", val % 256);
    val /= 256;
  }
  return result;
}

string gzip(string data, object id)
{
  string deflated= deflate(data, id);
  // transform deflate data into gzip one
  // see RFC1952 for the format
  data = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03" + deflated 
   + gzip_PrintFourChars(Gz.crc32(data))
   + gzip_PrintFourChars(strlen(data));
  return data;
}

// helper function
// return true is the file size is acceptable and can be compressed
int checkfilesize(string data)
{
  int res = strlen(data) > QUERY(minfilesize) && strlen(data) < QUERY(maxfilesize);
#ifdef GZIP_DEBUG
  if(res)
    werror(sprintf("File size allow compression(size=%d)\n", strlen(data)));
  else
    werror(sprintf("File size doesn't allow compression(size=%d)\n", strlen(data)));
#endif
  return res;
}

int is_in_excludelist(string mime, string file)
{
#ifdef GZIP_DEBUG
  string debug = "auto_gzip: is_in_excludelist, ";
  debug += "mime=" + mime + " file=" + file + "\n";
  werror(debug);
#endif
  foreach(regexps["excludemime"], object rex)
  {
    if(rex->match(mime))
      return 1;
  }
  foreach(regexps["excludefileext"], object rex)
  {
    if(rex->match(file))
      return 1;
  }
#ifdef GZIP_DEBUG
  debug = "...doesn't match the exclude list\n";
  werror(debug);
#endif
  return 0;
}

int is_in_includelist(string mime, string file)
{
#ifdef GZIP_DEBUG
  string debug = "auto_gzip: is_in_includelist, ";
  debug += "mime=" + mime + " file=" + file + "\n";
  werror(debug);
#endif
  foreach(regexps["includemime"], object rex)
  {
    if(rex->match(mime))
      return 1;
  }
  foreach(regexps["includefileext"], object rex)
  {
    if(rex->match(file))
      return 1;
  }
#ifdef GZIP_DEBUG
  debug = "...doesn't match the include list\n";
  werror(debug);
#endif
  return 0;
}

mapping filter(mapping response, object id)
{ 
  object lock;
  if(!mappingp(response) || !stringp(response->data))
    return 0;
  
#ifdef GZIP_DEBUG
  werror(sprintf("auto_gzip: supports->autogunzip=%d, supports->autoinflate=%d\n", id->supports->autogunzip, id->supports->autoinflate));
#endif
  if(  QUERY(gzipfly)
    && (id->supports->autoinflate || id->supports->autogunzip)
    && !response->encoding && response->extra_heads != "Content-Encoding"
    && checkfilesize(response->data) 
    && !is_in_excludelist(response->type, id->not_query)
    && is_in_includelist(response->type, id->not_query) )
  {
#if constant(thread_create)
      lock = global_lock->lock();
#endif
      stats["totaldata"] += sizeof(response->data);
#if constant(thread_create)
      destruct(lock);
#endif	    
      if(id->supports->autoinflate)
      {
        response["extra_heads"] += ([ "Content-Encoding" : "deflate" ]);
	response->data = deflate(response->data, id);
      }
      else if(id->supports->autogunzip)
      {
        // transform deflate data into gzip one
	// see RFC1952 for the format
        response->data = gzip(response->data, id);
	response["extra_heads"] += ([ "Content-Encoding" : "gzip" ]);
      }
#if constant(thread_create)
      lock = global_lock->lock();
#endif      
      stats["compresseddata"] += sizeof(response->data);
#if constant(thread_create)
      destruct(lock);
#endif            
      m_delete(response,"file");
#ifdef GZIP_DEBUG
      werror(sprintf("auto_gzip: response[\"extra_heads\"]=%O\n", response["extra_heads"]));
#endif
      return response;
  }
#if constant(thread_create)
  lock = global_lock->lock();
#endif            
  stats["notmatchingdata"] += sizeof(response->data);
#if constant(thread_create)
   destruct(lock);
#endif      
  return 0;
}

#endif

