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


/* Language support for numbers and dates. Very simple,
 * really. Look at one of the existing language plugins (not really
 * modules, you see..)
 *
 * $Id$
 * This file is included by roxen.pike. Not very nice to have a
 * cvs_version variable here.
 *
 * WARNING:
 * If the environment variable 'CAUDIUM_LANG' is set, it is used as the default 
 * language.
 */

#include <caudium.h>

mapping languages = ([ ]);

void initiate_languages()
{
  string lang, *langs, p;
  langs = get_dir("languages");
  if(!langs)
  {
    report_fatal("No languages available!\n"+
		 "This is a serious error.\n"
		 "Most RXML tags will not work as expected!\n");
    return 0;
  }
  p = "Adding languages: ";
  foreach(langs, lang)
  {
    if(lang[-1] == 'e')
    {
      array tmp;
      string alias;
      object l;
      mixed err;
      p += String.capitalize(lang[0..search(lang, ".")-1])+" ";
      if (err = catch {
	l = compile_file("languages/"+lang)();
	if(tmp=l->aliases()) {
	  foreach(tmp, alias) {
	    languages[alias] = ([ "month":l->month,
				  "ordered":l->ordered,
				   "date":l->date,
			           "day":l->day,
			           "number":l->number,
			           "\000":l, /* Bug in Pike force this, as of
					      * 96-04-15. Probably fixed. */
			       ]);
	  }
	} 
      }) {
	report_error(sprintf("Initialization of language %s failed:%s\n",
			     lang, describe_backtrace(err)));
      }
    }
  }
  report_notice(p+"\n");
}

private string nil()
{
#ifdef LANGUAGE_DEBUG
  perror(sprintf("Cannot find that one in %O.\n", languages));
#endif
  return "No such function in that language, or no such language.";
}


string default_language = getenv("CAUDIUM_LANG")||"en";

/* Return a pointer to an language-specific conversion function. */
public function language(string what, string func)
{
#ifdef LANGUAGE_DEBUG
  perror("Function: " + func + " in "+ what+"\n");
#endif
  if(!languages[what])
    if(!languages[default_language])
      if(!languages->en)
	return nil;
      else
	return languages->en[func];
    else
      return languages[default_language][func];
  else
    return languages[what][func] || nil;
}


