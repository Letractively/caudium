/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
 * Things to know:
 *
 *  - this script has to run with any pike (back to 0.6, i can try 0.5
 *    if anyone can give me one...)
 *  - a specific Caudium version number can be passed as an argument; then it
 *    will do the checks appropriate for that version only. if no version
 *    number is supplied, it will do all the checks (as it was doing before
 *    this change).
 *    NOTE: the version number format has to be "%d.%d"!
 *
 */

void pp(string f, mixed ... a)
{
  write(sprintf(f, @a));
  return;
}

float ver; // version
int rel; // release
int warnings; // Number of warnings
int major, minor; // Caudium version number

string warning(string msg, mixed ... args)
{
  if(!warnings)
    write("\n");
  write("\n");
  msg += "\n";
  if(sizeof(args))
    pp(msg, @args);
  else
    write(msg);
  warnings++;
}

void endreport()
{
  if(!warnings)
    write(" none found.\n");
  else
    pp("\n*** Found %d potential problem%s.\n", warnings, (warnings>1 ? "s" : "") );
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
  if(argc > 1)
  // there is a caudium version specified
  {
    if( sscanf(argv[1], "%d.%d", major, minor) != 2 )
    // but it seems to be badly formatted...
    {
      Stdio.stderr.write("wrong Caudium version number given (wrong format)\n");
      exit(1);
    }
  }

  array missing, existing;
  sscanf(version(), "Pike v%f release %d", ver, rel);
  write("Checking for potential compatibility problems with your Pike installation...");
  master()->set_inhibit_compile_errors("");

  if(ver < 7.4 ||
     (ver == 7.4 && rel < 1))
    warning("Caudium 1.3 requires Pike 7.4.1 or newer.");

  if(ver == 7.5) {
    warning("We strongly recommend the use of Pike 7.4 for Caudium. "
            "Pike 7.5 is less\n"
	    "tested and still a development version.");
  }
  
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
	    (sizeof(missing) == 1 ? "" : "s"), 
	    String.implode_nicely(missing));
  }

  missing = ({ "Msql", "Mysql", "Odbc", "Oracle", "Postgres", "sybase" });

  existing = has_features(missing);
  missing -= existing;

  if(sizeof(missing)) {
    warning("Pike is missing support for the following database backend%s:\n"
	    "\t%s\nSupported backend%s:\n"
	    "\t%s",
	    (sizeof(missing) == 1 ? "" : "s"), 
	    String.implode_nicely(missing),
	    (sizeof(existing) == 1 ? "" : "s"), 
	    ( sizeof(existing) ? String.implode_nicely(existing) : "none" ));
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

#if !constant(SSL)
  warning("Your Pike is lacking of SSL module. So you won't be able to use\n"
          "SSL3 with Caudium. We recommand you to use a Pike toolkit with\n"
          "SSL module.");
#endif 

#if !constant(Image.TTF)
  warning("Your Pike is lacking truetype font support. If you want to use <gtext> with\n"
	  "truetype fonts, you need to install the freetype library available from\n"
	  "http://www.freetype.org/ and recompile Pike.");
#endif

#if !constant(Gdbm.gdbm)
  warning("No gdbm support available. UltraLog will not be able to use the gdbm backend\n"
	  "for storing log summaries. You can still use UltraLog with the File and\n"
	  " Filetree backends however.");
#endif

  endreport();
}

