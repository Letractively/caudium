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
#include <module.h>
#include <pcre.h>

#define GZIP_DEBUG 1

constant cvs_version="$Id$";
constant thread_safe=1;

constant module_type = MODULE_FIRST|MODULE_FILTER;
constant module_name = "Automatic sending of compressed files";
constant module_doc  = "This module implements a suggestion by Francesco Chemolli:<br>\n"
      "The modified filesystem should do\n"
      "about this:<br>\n"
      "-check if the browser supports on-the-fly decompression<br>\n"
      "-check if a precompressed file already exists.<BR>\n"
      "-if so, send a redirection to the precompressed file<p>\n"
      "\n"
      "So, no cost for compression, all URLs, content-types and such would "
      "remain vaild, no compression overhead and should be really simple "
      "to implement. Also, it would allow a site mantainer to "
      "choose WHAT to precompress and what not to.<p>"
      "This module acts as a filter, and it _will_ use one extra stat "
      "per access from browsers that support automatic decompression.";
constant module_unique = 1;

// for status screen
mapping(string:int|float) stats = ([ 
				     "totaldata": 0,
			             "compresseddata": 0,
			             "cputime": 0 ]);
// Regexp to decide wherether to compress or not
mapping regexps = ([ ]);

string status()
{
  string status = "";
#if constant (Gz.deflate)
  status += "Gz.deflate Pike module support is Ok.";
  status += "<table><tr><td>CPU time used for compression:</td>";
  status += "<td>" + stats["cputime"] + " second</td></tr>";
  status += "<tr><td>Total data:</td>";
  status += "<td>" + stats["totaldata"] + " bytes</td></tr>";
  status += "<tr><td>Compressed data:</td>";
  status += "<td>" + stats["compresseddata"] + " bytes</td></tr>";
  if(stats["totaldata"])
  {
    status += "<tr><td>Compress ratio:</td>";
    status += "<td>" + (int)((float)(stats["totaldata"] - stats["compresseddata"]) / stats["totaldata"] * 100) + "%</td></tr>";
  }
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
  if(id->supports->autogunzip &&
     (caudium->real_file(id->not_query + ".gz", id)
      && caudium->stat_file(id->not_query + ".gz", id)))
  {
    // Actually, Content-Encoding is added automatically. Just had to fix
    // the extensions file to use gzip instead of x-gzip...
    id->not_query += ".gz";
  }
}

#if constant(Gz.deflate)

int hide_gzipfly()
{
  return !QUERY(gzipfly);
}

void create()
{
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
  defvar("maxfilesize", 65535, "Maximum file size", TYPE_INT,
  	 "The maximum file size this module will compress.<br>"
	 "<i>Note: this module works only in memory</i>.",
	 0, hide_gzipfly);
  defvar("includemime", ".*", "Include: Compress these MIME types",
  	 TYPE_TEXT_FIELD,
  	 "Always compress these MIME types (Regular expression separated "
	 "by line).<br><i>Note: you will have to reload the module once you "
	 "changed the expression</i>.",
	 0, hide_gzipfly);
  defvar("includefileext", ".*", "Include: Compress these file extentions",
  	 TYPE_TEXT_FIELD, "Always compress the files ending with these "
	 "extentions (Regular expression separated by line).",
	 0, hide_gzipfly);
  defvar("excludefileext", "", "Exclude: Don't compress these file extentions",
  	 TYPE_TEXT_FIELD, "Don't compresse the files ending with these "
	 "extentions (Regular expression separated by line).",
	 0, hide_gzipfly);
  defvar("excludemime", "^image/\n^audio/\n^video/\n^application/pdf",
  	 "Exclude: Don't compress these MIME types",
  	 TYPE_TEXT_FIELD, "Don't compress these MIME types "
	 "(Regular expression separated by line).", 0, hide_gzipfly);
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
  regexps = ([ "includemime":    0,
  	       "includefileext": 0,
	       "excludemime":    0,
	       "excludefileext": 0 ]);
  regexps->includemime    = compile_regexp(QUERY(includemime));
  regexps->includefileext = compile_regexp(QUERY(includefileext));
  regexps->excludemime    = compile_regexp(QUERY(excludemime));
  regexps->excludefileext = compile_regexp(QUERY(excludefileext));
}

string deflate(string data)
{
  int level = QUERY(compressionlevel);
  level = abs(level);
  if(level > 9)
   level = 9;
  stats["cputime"] += gauge {
    data = Gz.deflate(level)->deflate(data); 
  };
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

string gzip(string data)
{
  string deflated= deflate(data);
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
  if(!mappingp(response) || !stringp(response->data))
    return 0;
  
#ifdef GZIP_DEBUG
  werror(sprintf("auto_gzip: supports->autogunzip=%d, supports->autoinflate=%d\n", id->supports->autogunzip, id->supports->autoinflate));
#endif
  if(  QUERY(gzipfly)
    && (id->supports->autoinflate || id->supports->autogunzip)
    && !response->encoding && response->extra_heads != "Content-Encoding"
    && checkfilesize(response->data) 
    && !is_in_excludelist(response->type, id->realfile)
    && is_in_includelist(response->type, id->realfile) )
  {
      // FIXME: will see cache issues later
      NOCACHE();
      stats["totaldata"] += sizeof(response->data);
      if(id->supports->autoinflate)
      {
        response["extra_heads"] += ([ "Content-Encoding" : "deflate" ]);
	response->data = deflate(response->data);
      }
      else if(id->supports->autogunzip)
      {
        // transform deflate data into gzip one
	// see RFC1952 for the format
        response->data = gzip(response->data);
	response["extra_heads"] += ([ "Content-Encoding" : "gzip" ]);
      }
      stats["compresseddata"] += sizeof(response->data);
      m_delete(response,"file");
#ifdef GZIP_DEBUG
      werror(sprintf("auto_gzip: response[\"extra_heads\"]=%O\n", response["extra_heads"]));
#endif
      return response;
  }
  return 0;
}

#endif

