/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
 * Copyright � David Hedbor
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
/*
 * $Id$
 */

//! Some tools for Headline module
//! $Id$

//!
constant h2c =
([
  "&lt;":"<", "&gt;":">", "&amp;":"&",
  "&nbsp;": "�", "&iexcl;": "�", "&cent;": "�", "&pound;": "�",
  "&curren;": "�", "&yen;": "�", "&brvbar;": "�", "&sect;": "�",
  "&uml;": "�", "&copy;": "�", "&ordf;": "�", "&laquo;": "�",
  "&not;": "�",  "&quot;": "\"", "&shy;": "�", "&reg;": "�", "&macr;": "�",
  "&deg;": "�",  "&plusmn;": "�", "&sup2;": "�", "&sup3;": "�",
  "&acute;": "�",  "&micro;": "�", "&para;": "�", "&middot;": "�",
  "&cedil;": "�",  "&sup1;": "�", "&ordm;": "�", "&raquo;": "�",
  "&frac14;": "�",  "&frac12;": "�", "&frac34;": "�", "&iquest;": "�",
  "&Agrave;": "�",  "&Aacute;": "�", "&Acirc;": "�", "&Atilde;": "�",
  "&Auml;": "�",  "&Aring;": "�", "&AElig;": "�", "&Ccedil;": "�",
  "&Egrave;": "�",  "&Eacute;": "�", "&Ecirc;": "�", "&Euml;": "�",
  "&Igrave;": "�",  "&Iacute;": "�", "&Icirc;": "�", "&Iuml;": "�",
  "&ETH;": "�",  "&Ntilde;": "�", "&Ograve;": "�", "&Oacute;": "�",
  "&Ocirc;": "�",  "&Otilde;": "�", "&Ouml;": "�", "&times;": "�",
  "&Oslash;": "�",  "&Ugrave;": "�", "&Uacute;": "�", "&Ucirc;": "�",
  "&Uuml;": "�",  "&Yacute;": "�", "&THORN;": "�", "&szlig;": "�",
  "&agrave;": "�",  "&aacute;": "�", "&acirc;": "�", "&atilde;": "�",
  "&auml;": "�",  "&aring;": "�", "&aelig;": "�", "&ccedil;": "�",
  "&egrave;": "�",  "&eacute;": "�", "&ecirc;": "�", "&euml;": "�",
  "&igrave;": "�",  "&iacute;": "�", "&icirc;": "�", "&iuml;": "�",
  "&eth;": "�",  "&ntilde;": "�", "&ograve;": "�", "&oacute;": "�",
  "&ocirc;": "�",  "&otilde;": "�",   "&ouml;": "�", "&divide;": "�",
  "&oslash;": "�", "&ugrave;": "�",  "&uacute;": "�", "&ucirc;": "�",
  "&uuml;": "�", "&yacute;": "�",  "&thorn;": "�", "&yuml;": "�",
  "&apos;": "'"
]); 

//!
string trim(string s)
{
  return replace(String.trim_whites(s), indices(h2c), values(h2c));
}
