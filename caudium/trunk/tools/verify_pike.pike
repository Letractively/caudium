/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
 * $Id$
 *
 */

/*
 * This is a small utility to verify and find potential problems with
 * the pike version the user wants to run with Caudium. It's run automatically
 * at the end of the configure script.
 *
 */


float ver; // version
int rel; // release
int warnings; // Number of warnings
string warning(string msg, mixed ... args)
{
  if(!warnings)
    write("\n");
  write("\n");
  msg += "\n";
  if(sizeof(args))
    write(sprintf(msg, @args));
  else
    write(msg);
  warnings++;
}
void endreport()
{
  switch(warnings) {
   case 0: write(" none found.\n"); break;
   case 1: write("\n*** Found one potential problem.\n"); break;
   default: write("\n*** Found "+warnings+" potential problems.\n"); break;
  }
}
array(string) has_features(array features)
{
  array a = ({});
  
  foreach(features, string modname)
  {
    catch
    {
      if(([ "Java":2 ])[modname] <
	 sizeof(indices(master()->resolv(modname) || ({}))))
      {
	if(modname[0] == '_')
	  modname = replace(modname[1..], "_", ".");
	a += ({ modname });
      }
    };
  }

  return a;
}

int main(int argc, array argv)
{
  array missing, existing;
  sscanf(version(), "Pike v%f release %d", ver, rel);
  write("Checking for potential compatibility reasons with your Pike...");
  master()->set_inhibit_compile_errors("");

  if(ver < 7.0 ||
     (ver == 7.0 && rel < 268))
    warning("Caudium 1.1 requires Pike 7.0.268 or newer.");

  if(ver == 7.1) {
    warning("We strongly recommend the use of Pike 7.0 for Caudium. Pike 7.1 is less\n"
	    "tested and still a development version.");
    
    if(rel == 11)
      /* Pike 7.1.11 _might_ have several problems... */
      warning("You are using Pike 7.1.11. The errors reported below might or might not be a\n"
	      "problem. The problems were fixed in Pike 7.1.11, but if you have an older\n"
	      "version of if, the problems might very well still be there. We recommend an\n"
	      "upgrade to the latest Pike 7.1 version to avoid any potential problems.");
    if(rel > 11 && rel < 28)
      /* Serious string bug in these versions */
      warning("In Pike 7.1 build 13 to build 27 there is a serious bug string bug which\n"
	      "breaks Caudium query string parsing. If you want to use Pike 7.1, you have\n"
	      "to upgrade it to a later version.");
    if(rel < 12) {
      /* PHP 4 */
      warning("Pike 7.0 w/ build >= 268 or 7.1 build >= 12 is required for embedded PHP4\n"
	      "scripting support. Please note that you also need to get a late version\n"
	      "of PHP4 to enable it.");
      /* Pipe.pipe leak */
      warning("In Pike 7.1 builds <= 11, there is a severe leak in Pipe.pipe, which is\n"
	      "used for sending data in Caudium. You will need a newer version of Pike 7.1\n"
	      "to fix this problem.");
    }
  }
  
  /* Pike 7.11 might have several problems... */
  if(ver == 7.1 && rel == 11)
    warning("You are using Pike 7.1.11. The errors reported below might or might not be a\n"
	    "problem. The problems were fixed in Pike 7.1.11, but if you have an older\n"
	    "version of if, the problems might very well still be there. We recommend an\n"
	    "upgrade to the latest Pike 7.1 version to avoid any potential problems.");



#if constant(Parser.HTML) 
  /* Parser.HTML recursion stuff */
  if(!(Parser.HTML()->max_stack_depth))
    warning("Your Parser.HTML is missing the max_stack_depth() function. This might cause\n"
	    "'too deep recursion' errors when using the new XML compliant RXML parser.\n"
	    "CAMAS is known to show this problem. Upgrade your Pike 7.0 to build >= 286\n"
	    "or Pike 7.1 to build >= 12 to fix this problem.");
#endif

  missing = ({});
#if !constant(Image.GIF.decode)
  missing += ({ "GIF"});
#endif
#if !constant(Image.JPEG.decode)
  missing += ({ "JPEG"});
#endif
#if !constant(Image.PNG.decode)
  missing += ({ "PNG"});
#endif
  if(sizeof(missing)) {
    warning("Pike is missing support for the image format%s %s.\n"
	    "This might limit the functionality of the dynamic image generation in Caudium.",
	    sizeof(missing) == 1 ? "" : "s", 
	    String.implode_nicely(missing));
  }

  missing = ({ "Msql","Mysql", "Odbc", "Oracle","Postgres", "sybase" });

  existing = has_features(missing);
  missing -= existing;

  if(sizeof(missing)) {
    warning("Pike is missing support for the following database backend%s:\n"
	    "\t%s\nSupported backend%s:\n"
	    "\t%s",
	    sizeof(missing) == 1 ? "" : "s", 
	    String.implode_nicely(missing),
	    sizeof(existing) == 1 ? "" : "s", 
	    sizeof(existing) ? String.implode_nicely(existing):
	    "none");
  }
  
#if !constant(Gmp.mpz)
  warning("Your Pike is lacking Gmp support. This will, among other things, disable the\n"
	  "SSL3 support. You can fetch the  GMP library from any GNU mirror.");
#endif

#if !defined(__MAJOR__) || __MAJOR__ < 7
  warning("Caudium doesn't support SSL3 with Pike 0.6. Upgrade to Pike 7.0 if\n"
	  "you need https support.");
#elif !constant(_Crypto)
  warning("Your Pike is lacking the _Crypto module so you won't be able to use SSL3.");
#endif
  
  if(
#if !constant(Image.TTF)
     1
#else
     !sizeof(Image.TTF)
#endif
     )
  warning("Your Pike is lacking true type font support. If you want to use <gtext> with\n"
	  ".ttf fonts, you need to install the freetype library available from\n"
	  "http://www.freetype.org/ and recompile Pike.");
#endif
#if !constant(Gdbm.gdbm)
  warning("No gdbm support available. UltraLog will not be able to use the gdbm backend\n"
	  "for storing log summaries. You can still use UltraLog with the File and\n"
	  " Filetree backends however.");
#endif
  endreport();
}

