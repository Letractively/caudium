/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
 * Copyright © David Hedbor
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
  "&nbsp;": " ", "&iexcl;": "¡", "&cent;": "¢", "&pound;": "£",
  "&curren;": "¤", "&yen;": "¥", "&brvbar;": "¦", "&sect;": "§",
  "&uml;": "¨", "&copy;": "©", "&ordf;": "ª", "&laquo;": "«",
  "&not;": "¬",  "&quot;": "\"", "&shy;": "­", "&reg;": "®", "&macr;": "¯",
  "&deg;": "°",  "&plusmn;": "±", "&sup2;": "²", "&sup3;": "³",
  "&acute;": "´",  "&micro;": "µ", "&para;": "¶", "&middot;": "·",
  "&cedil;": "¸",  "&sup1;": "¹", "&ordm;": "º", "&raquo;": "»",
  "&frac14;": "¼",  "&frac12;": "½", "&frac34;": "¾", "&iquest;": "¿",
  "&Agrave;": "À",  "&Aacute;": "Á", "&Acirc;": "Â", "&Atilde;": "Ã",
  "&Auml;": "Ä",  "&Aring;": "Å", "&AElig;": "Æ", "&Ccedil;": "Ç",
  "&Egrave;": "È",  "&Eacute;": "É", "&Ecirc;": "Ê", "&Euml;": "Ë",
  "&Igrave;": "Ì",  "&Iacute;": "Í", "&Icirc;": "Î", "&Iuml;": "Ï",
  "&ETH;": "Ð",  "&Ntilde;": "Ñ", "&Ograve;": "Ò", "&Oacute;": "Ó",
  "&Ocirc;": "Ô",  "&Otilde;": "Õ", "&Ouml;": "Ö", "&times;": "×",
  "&Oslash;": "Ø",  "&Ugrave;": "Ù", "&Uacute;": "Ú", "&Ucirc;": "Û",
  "&Uuml;": "Ü",  "&Yacute;": "Ý", "&THORN;": "Þ", "&szlig;": "ß",
  "&agrave;": "à",  "&aacute;": "á", "&acirc;": "â", "&atilde;": "ã",
  "&auml;": "ä",  "&aring;": "å", "&aelig;": "æ", "&ccedil;": "ç",
  "&egrave;": "è",  "&eacute;": "é", "&ecirc;": "ê", "&euml;": "ë",
  "&igrave;": "ì",  "&iacute;": "í", "&icirc;": "î", "&iuml;": "ï",
  "&eth;": "ð",  "&ntilde;": "ñ", "&ograve;": "ò", "&oacute;": "ó",
  "&ocirc;": "ô",  "&otilde;": "õ",   "&ouml;": "ö", "&divide;": "÷",
  "&oslash;": "ø", "&ugrave;": "ù",  "&uacute;": "ú", "&ucirc;": "û",
  "&uuml;": "ü", "&yacute;": "ý",  "&thorn;": "þ", "&yuml;": "ÿ",
  "&apos;": "'"
]); 

//!
string trim(string s)
{
  return replace(String.trim_whites(s), indices(h2c), values(h2c));
}
