/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2014 The Caudium Group
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

int main(int argc, array argv)
{
  if(argc > 1)
  // there is a caudium version specified
  {
    if( sscanf(argv[1], "%d.%d", major, minor) != 2 )
    // but it seems to be badly formatted...
    {
      Stdio.stderr.write("Wrong Caudium version number given (wrong format)\n");
      exit(1);
    }
  }

  sscanf(version(), "Pike v%f release %d", ver, rel);
  write("Checking for potential compatibility problems with your Pike installation...");
  master()->set_inhibit_compile_errors("");

  if(ver < 7.8 ||
     (ver == 7.8 && rel < 1))
    warning("Caudium 1.5 requires Pike 7.8 or newer, current version is\n%s",
      version());

  if(ver == 7.9) {
    warning("We strongly recommend the use of Pike 7.8 for Caudium. "
            "Pike %f is less\n"
	    "tested and still a development version.", ver);
  }

// if the pike doesn't have Tools.Install.features it's not a pike 7.6 anyway
#if constant(Tools.Install.features)
  array missing, existing = Tools.Install.features();
  
  missing = ({ "Image.GIF", "Image.JPEG", "Image.PNG" }) - existing;
  if(search(missing, "Image.PNG") != -1)
    warning("Caudium requires the Image.PNG module. \n"
            "You must resolve this problem before attempting to start Caudium.\n");
  missing -= ({ "Image.PNG" });

  if(sizeof(missing)) {
    warning("Pike is missing support for the image format%s %s.\n"
	    "This might limit the functionality of the dynamic image generation in Caudium.",
	    (sizeof(missing) == 1 ? "" : "s"), 
	    String.implode_nicely(missing));
  }

  array databases = ({ "Msql", "Mysql", "Odbc", "Oracle", "Postgres", "sybase", "SQLite" });
  missing = databases - existing;
  array supported_backend = databases & existing;
  

  if(sizeof(missing)) {
    warning("Pike is missing support for the following database backend%s:\n"
	    "\t%s\nSupported backend%s:\n"
	    "\t%s",
	    (sizeof(missing) == 1 ? "" : "s"), 
	    String.implode_nicely(missing),
	    (sizeof(supported_backend) == 1 ? "" : "s"), 
	    ( sizeof(supported_backend) ? String.implode_nicely(supported_backend) : "none" ));
  }
  
if(!has_value(existing, "Gmp"))
  warning("Your Pike is lacking Gmp support. This will, among other things, disable the\n"
	  "SSL3 support. You can fetch the  GMP library from any GNU mirror.");

#if !constant(SSL)
  warning("Your Pike is lacking of SSL module. So you won't be able to use\n"
          "SSL3 with Caudium. We recommand you to use a Pike toolkit with\n"
          "SSL module.");
#endif 

if(!has_value(existing, "Image.TTF"))
  warning("Your Pike is lacking truetype font support. If you want to use <gtext> with\n"
	  "truetype fonts, you need to install the freetype library available from\n"
	  "http://www.freetype.org/ and recompile Pike.");

#endif
  endreport();
}

