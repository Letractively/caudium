/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
//! module: Language module
//!  Handles documents in different languages.
//!  <p>Is also a directory module that generates no directory
//!  listings. It must be a directory module to work, though it
//!  could of course be fixed to make directory listings.
//!  The module works by using appropriate magic to find out what
//!  language the user wants and then finding a file in that
//!  language. What language a file is in is specified with an
//!  extra extension. index.html.sv would be a file in swedish
//!  while index.html.en would be one in english.</p>
//!  <p>The module also defines three new tags.
//!  <br/><strong>&lt;language&gt;</strong> that tells which language the
//!  current page is in.
//!  <br/><strong>&lt;available_languages&gt;</strong> gives a list of other
//!  languages the current page is in, with links to them.
//!  <br/><strong>&lt;unavailable_language&gt;</strong> shows the language
//!  the user wanted, if the page was not available in that 
//!  language. </p>
//!  <p>All tags take the argument type={txt,img}.</p>
//! inherits: modules/directories/directories
//! type: MODULE_DIRECTORIES | MODULE_URL | MODULE_PARSER
//! cvs_version: $Id$
//

#include <module.h>
inherit "modules/directories/directories";

string cvs_version = "$Id$";
/* Is threadsafe. */

#if DEBUG_LEVEL > 20
# ifndef LANGUAGE_DEBUG
#  define LANGUAGE_DEBUG
# endif
#endif

constant module_type = MODULE_DIRECTORIES | MODULE_URL | MODULE_PARSER;
constant module_name = "Language module";
constant module_doc  = "Handles documents in different languages. "
	      "<p>Is also a directory module that generates no directory "
	      "listings. It must be a directory module to work, though it "
	      "could of course be fixed to make directory listings."
	      "The module works by using appropriate magic to find out what "
	      "language the user wants and then finding a file in that "
	      "language. What language a file is in is specified with an "
	      "extra extension. index.html.sv would be a file in swedish "
	      "while index.html.en would be one in english. "
	      "<p>The module also defines three new tags. "
	      "<br><b>&lt;language&gt;</b> that tells which language the "
	      "current page is in. "
	      "<br><b>&lt;available_languages&gt;</b> gives a list of other "
	      "languages the current page is in, with links to them. "
	      "<br><b>&lt;unavailable_language&gt;</b> shows the language "
	      "the user wanted, if the page was not available in that "
	      "language. "
	      "<p>All tags take the argument type={txt,img}. ";
constant module_unique = 1;

void create()
{
  defvar( "default_language", "en", "Default language", TYPE_STRING,
	  "The default language for this server. Is used when trying to "
	  "decide which language to send when the user hasn't selected any. "
	  "Also the language for the files with no language-extension." );

  defvar( "languages", "en	English\nde	Deutch		en\n"
	  "sv	Svenska		en", "Languages", TYPE_TEXT_FIELD,
	  "The languages supported by this site. One language on each row. "
	  "Syntax: "
	  "<br />language-code language-name optional-next-language-codes"
	  "<br />For example:\n"
	  "<pre>sv	Svenska		en de<br />"
	  "en	English		de<br />"
	  "de	Deutch		en\n"
	  "</pre><p>"
	  "The next-language-code is used to determine what language should "
	  "be used in case the chosen language is unavailable. To find a "
	  "page with a suitable language the languages is tried as follows. "
	  "<ol><li>The selected language, stored as a prestate</li>"
	  "<li>The user agent's accept-headers</li>"
	  "<li>The selected languages next-languages-codes if any</li>"
	  "<li>The default language</li>"
	  "<li>If there were no selected language, the default language's "
	  "next-language-codes</li>"
	  "<li>All languages, in the order they appear in this text-field</li>"
	  "</ol></p>"
	  "<p>Empty lines, lines beginning with # or // will be ignored."
	  " Lines with errors may be ignored, or execute a HCF instruction."
	  "</p>");

  defvar( "flag_dir", "/icons", "Flag directory", TYPE_STRING,
	  "A directory with small pictures of flags, or other symbols, "
	  "representing the various languages. Each flag should exist in the "
	  "following versions:"
	  "<dl><dt>language-code.selected.gif</dt>"
	  "<dd>Shown to indicate that the page is in that selected language, "
	  "usually by the header-module.</dd>"
	  "<dt>language-code.available.gif</dt>"
	  "<dd>Shown as a link to the page in that language. Will of course "
	  "only be used if the page exists in that language.</dd>"
	  "<dt>language-code.unavailable.gif</dt>"
	  "<dd>Shown to indicate that the user has selected an language that "
	  "this page hasn't been translated to.</dd>"
	  "</dl>"
	  "<p>It is of course not necessary to have all this pictures if "
	  "their use is not enabled in this module nor the header module.</p>" );
/*	 "<dt>language-code.dir.selected.gif</dt>"
	 "<dd>Shown to indicate that the dir-entry will be shown in that "
	 "language.</dd>"
	 "<dt>language-code.dir.available.gif</dt>"
	 "<dd>Shown as a link to the dir-entry translated to that language.</dd>"
	 */

/*
  defvar( "flags_or_text", 1, "Flags in directory lists", TYPE_FLAG,
	  "If set, the directory lists will include cute flags to indicate "
	  "which language the entries exists in. Otherwise it will be shown "
	  "with not-so-cure text. " );
  defvar( "directories", 1, "Directory parsing", TYPE_FLAG, 
	  "If you set this flag to on, a directories will be "+
	  "parsed to a file-list, if no index file is present. "+
	  "If not, a 'No such file or directory' response will be generated.");
*/  
  defvar( "configp", 1, "Use config (uses prestate otherwise).",
          TYPE_FLAG,
          "If set the users chooen language will be stored using Roxens "
          "which in turn will use a Cookie stored in the browser, if "
          "possible. Unfortunatly Netscape may not reload the page when the "
          "language is changed using Cookies, which means the end-users "
          "may have to manually reload to see the page in the new language. "
          "Prestate does not have this problem, but on the other hand "
          "they will not be remembered over sessions." );

  defvar( "textonly", 0, "Text only", TYPE_FLAG,
	  "If set the tags type argument will default to txt instead of img" );
  
/* Who came up with this idea?
  defvar( "borderwidth", 0, "Border width", TYPE_INT,
	  "The width of the border around selectable flags." );
*/

  ::create();
}

mapping parse_directory( object id )
{
  return ::parse_directory( id );
}


// language part

mapping (string:mixed) language_data = ([ ]);
array (string) language_order = ({ });
#define LANGUAGE_DATA_NAME 0
#define LANGUAGE_DATA_NEXT_LANGUAGE 1
multiset (string) language_list;
string default_language, flag_dir;
int textonly;
int borderwidth;

mixed fnord(mixed what) { return what; }


void start()
{
  string tmp;
  array (string) tmpl;

  foreach (query( "languages" ) / "\n", tmp)
    if (strlen( tmp ) > 2 && tmp[0] != '#' && tmp[0..1] != "//")
    {
      tmp = replace( tmp, "\t", " " );
      tmpl = tmp / " " - ({ "" });
      if (sizeof( tmpl ) >= 2)
      {
	language_data[ tmpl[0] ] = ({ tmpl[1], tmpl[2..] });
	language_order += ({ tmpl[0] });
      }
    }
  language_list = aggregate_multiset( @indices( language_data ) );
  foreach (indices( language_data ), tmp)
    language_data[ tmp ][ LANGUAGE_DATA_NEXT_LANGUAGE ] &= indices( language_list );
  default_language = query( "default_language" );
  textonly = query( "textonly" );
  /* Really...   /Peter
    borderwidth = query( "borderwidth" );
  */

  ::start();
}

multiset (string) find_files( string url, object id )
{
  string filename, basename, extension;
  multiset (string) files = (< >);
  multiset result = (< >);
  array tmp;

  filename = reverse( (reverse( url ) / "/")[0] );
  basename = reverse( (reverse( url ) / "/")[1..] * "/" ) + "/";
  tmp = caudium->find_dir( basename, id );
  if (tmp)
    files = aggregate_multiset( @tmp );
  foreach (indices( language_list ), extension)
    if (files[ filename + "." + extension ])
      result[ extension ] = 1;
  if (files[ filename ])
    result[ "" ] = 1;
  return result;
}

mixed remap_url( object id, string url )
{
  string chosen_language, prestate_language, extension;
  string found_language;
  multiset (string) lang_tmp, found_languages, found_languages_orig;
  array (string) accept_language;

  if(id->misc->language || id->misc->in_language)
    return 0;

  id->misc->in_language=1;
  
  extension = reverse( (reverse( url ) / ".")[0] );
  if (language_list[ extension ])
  {
    string redirect_url;

    redirect_url = reverse( (reverse( url ) / ".")[1..] * "." );
    if (id->query)
      redirect_url += "?" + id->query;
    redirect_url = add_pre_state( redirect_url, (id->prestate - language_list)+
				  (< extension >) );
    redirect_url = id->conf->query( "MyWorldLocation" ) +
      redirect_url[1..];
    
    id->misc->in_language=0;
    return http_redirect( redirect_url );
  }		    
  found_languages_orig = find_files( url, id );
  found_languages = copy_value( found_languages_orig );
  if (sizeof( found_languages_orig ) == 0)
  {
    id->misc->in_language=0;
    return 0;
  }
  if (found_languages_orig[ "" ])
  {
    found_languages[ "" ] = 0;
    found_languages[ default_language ] = 1;
  }
  // The file with no language extension is supposed to be in the default
  // language

  // fill the accept_language list
  if ( accept_language = id->misc["accept-language"] )
    ;
    else
      accept_language = ({ });

#ifdef LANGUAGE_DEBUG  
  perror("Wish:%O", accept_language);
#endif
  // This looks funny, but it's nessesary to keep the order of the languages.
  accept_language = accept_language -
    ( accept_language - indices(language_list) );
#ifdef LANGUAGE_DEBUG  
  perror("Negotiated:%O\n", accept_language);
#endif

  if (query( "configp" ))
    lang_tmp = language_list & id->config;
  else
    lang_tmp = language_list & id->prestate;

#ifdef LANGUAGE_DEBUG
  if( sizeof(accept_language) )
    perror("Header-choosen language: %O\n", accept_language[0]);
#endif
  
  if (sizeof( lang_tmp ))
    chosen_language = prestate_language = indices( lang_tmp )[0];
  else if (sizeof( accept_language ))
    chosen_language = accept_language[0];
  else
    chosen_language = default_language;

#ifdef LANGUAGE_DEBUG
  perror("Presented language: %O\n", chosen_language);
#endif
  
  if (found_languages[ chosen_language ])
    found_language = chosen_language;
  else if (sizeof( accept_language & indices( found_languages ) ))
    found_language = chosen_language
      = (accept_language & indices( found_languages ))[0];
  else if (prestate_language 
	   && sizeof( fnord(language_data[ prestate_language ]
		     [ LANGUAGE_DATA_NEXT_LANGUAGE ]
		      & indices( fnord(found_languages) ) )))
    found_language
      = (language_data[ prestate_language ][ LANGUAGE_DATA_NEXT_LANGUAGE ]
	 & indices( found_languages ))[0];
  else if (found_languages[ default_language ])
    found_language = default_language;
  else if (!prestate_language 
    	   && sizeof( language_data[ default_language ]
		     [ LANGUAGE_DATA_NEXT_LANGUAGE ]
		     & indices( found_languages ) ))
    found_language
      = ((language_data[ default_language ][ LANGUAGE_DATA_NEXT_LANGUAGE ]
	 & indices( found_languages )))[0];
  else
    found_language = (language_order & indices( found_languages ))[0];

  id->misc[ "available_languages" ] = copy_value( found_languages );
  id->misc[ "available_languages" ][ found_language ] = 0;
  id->misc[ "chosen_language" ] = chosen_language;
  id->misc[ "language" ] = found_language;
  id->misc[ "flag_dir" ] = flag_dir;
  id->misc[ "language_data" ] = copy_value( language_data );
  id->misc[ "language_list" ] = copy_value( language_list );
//  id->prestate -= language_list;
//  id->prestate[ found_language ] = 1; // Is this smart?

  if (found_languages_orig[ found_language ])
    id->extra_extension += "." + found_language;
  // We don't change not_query incase it was a file without
  // extension that were found.

  id->misc->in_language=0;
  return id;
}

string tag_unavailable_language( string tag, mapping m, object id )
{
  if (!id->misc[ "chosen_language" ] || !id->misc[ "language" ]
      || !id->misc[ "language_data" ])
    return "";
  if (id->misc[ "chosen_language" ] == id->misc[ "language" ])
    return "";
  if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
    return id->misc[ "language_data" ][ id->misc[ "chosen_language" ] ];
  else
    return "<img src=" + query( "flag_dir" ) + id->misc[ "chosen_language" ]
            + ".unavailable.gif alt=\""
            + id->misc[ "language_data" ][ id->misc[ "chosen_language" ] ][0]
            + "\">";
}

string tag_language( string tag, mapping m, object id )
{
  if (!id->misc[ "language" ] || !id->misc[ "language_data" ]
      || !id->misc[ "language_list" ])
    return "";
  if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
    return id->misc[ "language_data" ][ id->misc[ "language" ] ][0];
  else
    return "<img src=" + query( "flag_dir" ) + id->misc[ "language" ]
            + ".selected.gif alt=\""
            + id->misc[ "language_data" ][ id->misc[ "language" ] ][0]
            + "\">";
}

string tag_available_languages( string tag, mapping m, object id )
{
  string result, lang;
  int c;
  array available_languages;

  if (!id->misc[ "available_languages" ] || !id->misc[ "language_data" ]
      || !id->misc[ "language_list" ])
    return "";
  result = "";
  available_languages = indices( id->misc["available_languages"] );
  for (c=0; c < sizeof( available_languages ); c++)
  {
    if (query( "configp" ))
      result += "<aconf ";
    else
      result += "<apre ";
    foreach (indices( id->misc[ "language_list" ]
		      - (< available_languages[c] >) ), lang)
      result += "-" + lang + " ";
    if (query( "configp" ))
      result += "+" + available_languages[c]
	 + (id->misc[ "index_file" ] ? " href=\"\" >" : ">");
    else
      result += available_languages[c]
	 + (id->misc[ "index_file" ] ? " href=\"\" >" : ">");
    if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
      result += ""+id->misc[ "language_data" ][ available_languages[c] ][0];
    else
      result += "<img src=" + query( "flag_dir" ) + available_languages[c] +
	".available.gif alt=\"" +
	id->misc[ "language_data" ][ available_languages[c] ][0] +
	"\" " + sprintf("border=%d", borderwidth) + ">";
	
    if (query( "configp" ))
      result += "</aconf>\n";
    else
      result += "</apre>\n";
    }
  return result;
}

mapping query_tag_callers()
{
  return ([ "unavailable_language" : tag_unavailable_language,
            "language" : tag_language,
            "available_language" : tag_available_languages,  // compat lio
            "available_languages" : tag_available_languages ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: default_language
//! The default language for this server. Is used when trying to decide which language to send when the user hasn't selected any. Also the language for the files with no language-extension.
//!  type: TYPE_STRING
//!  name: Default language
//
//! defvar: languages
//! The languages supported by this site. One language on each row. Syntax: <br />language-code language-name optional-next-language-codes<br />For example:
//!<pre>sv	Svenska		en de<br />en	English		de<br />de	Deutch		en
//!</pre><p>The next-language-code is used to determine what language should be used in case the chosen language is unavailable. To find a page with a suitable language the languages is tried as follows. <ol><li>The selected language, stored as a prestate</li><li>The user agent's accept-headers</li><li>The selected languages next-languages-codes if any</li><li>The default language</li><li>If there were no selected language, the default language's next-language-codes</li><li>All languages, in the order they appear in this text-field</li></ol></p><p>Empty lines, lines beginning with # or // will be ignored. Lines with errors may be ignored, or execute a HCF instruction.</p>
//!  type: TYPE_TEXT_FIELD
//!  name: Languages
//
//! defvar: flag_dir
//! A directory with small pictures of flags, or other symbols, representing the various languages. Each flag should exist in the following versions:<dl><dt>language-code.selected.gif</dt><dd>Shown to indicate that the page is in that selected language, usually by the header-module.</dd><dt>language-code.available.gif</dt><dd>Shown as a link to the page in that language. Will of course only be used if the page exists in that language.</dd><dt>language-code.unavailable.gif</dt><dd>Shown to indicate that the user has selected an language that this page hasn't been translated to.</dd></dl><p>It is of course not necessary to have all this pictures if their use is not enabled in this module nor the header module.</p>
//!  type: TYPE_STRING
//!  name: Flag directory
//
//! defvar: configp
//! If set the users chooen language will be stored using Roxens which in turn will use a Cookie stored in the browser, if possible. Unfortunatly Netscape may not reload the page when the language is changed using Cookies, which means the end-users may have to manually reload to see the page in the new language. Prestate does not have this problem, but on the other hand they will not be remembered over sessions.
//!  type: TYPE_FLAG
//!  name: Use config (uses prestate otherwise).
//
//! defvar: textonly
//! If set the tags type argument will default to txt instead of img
//!  type: TYPE_FLAG
//!  name: Text only
//
