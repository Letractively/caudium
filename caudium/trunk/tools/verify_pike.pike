/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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
int main(int argc, array argv)
{
  sscanf(version(), "Pike v%f release %d", ver, rel);
  write("Checking for potential compatibility reasons with your Pike...");
  master()->set_inhibit_compile_errors("");
  /* Pike 7.11 might have several problems... */
  if(ver == 7.1 && rel == 11)
    warning("You are using Pike 7.1.11. You might encounter the following problems if it\n"
	    "a too old version: embedded PHP4 failures, Pipe.pipe memory leak and potential\n"
	    "problems with Parser.HTML (too deep recursion errors). We also strongly\n"
	    "recommend the use of Pike 7.0 for Caudium for stability reasons.");

  /* PHP 4 check */
  if(ver < 7.0
     || (ver == 7.0 && rel < 268)
     || (ver == 7.1 && rel < 11))
    warning("Pike 7.0.268 or Pike 7.1.11 is required for embedded PHP4 support.");

  /* Pipe.pipe leak */
  if((ver == 7.0 && rel < 146)
     || (ver == 7.1 && rel < 11))
    warning("In Pike 7.0 builds earlier than 146 and in Pike 7.1 prior to build 11,\n"
	    "there is a severe leak in Pipe.pipe, which is used for sending data in Caudium."
	    "You will need a newer version of Pike to fix this problem.");

#if constant(Parser.HTML) 
  /* Parser.HTML recursion stuff */
  if(!(Parser.HTML()->max_stack_depth))
    warning("Your Parser.HTML is missing the max_stack_depth() function. This might cause\n"
	    "'too deep recursion' errors when using the new XML compliant RXML parser.\n"
	    "CAMAS is known to show this problem. Upgrade your Pike 7.0 build 286 or newer,\n"
	    "or a late Pike 7.1.11 from CVS to fix this problem.");
#endif

  array missing = ({});
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

#if !constant(Gmp.mpz)
  warning("Your Pike is lacking Gmp support. This will, among other things, disable the\n"
	  "SSL3 support. You can fetch the  GMP library from any GNU mirror.");
#endif

#if !constant(Image.TTF)
  warning("Your Pike is lacking true type font support. If you want to use <gtext> with\n"
	  ".ttf fonts, you need to install the freetype library available from\n"
	  "http://www.freetype.org/ and recompile Pike.");
#endif
  endreport();
}

