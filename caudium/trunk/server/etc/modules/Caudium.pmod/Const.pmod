/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
 */
/*
 * $Id$
 */

//! Constants used for all Caudium works.

//! 
mapping(string:string) doctypes = ([
    "transitional" : "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n\"http://www.w3.org/TR/html4/loose.dtd\">",
    "strict" : "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"\n\"http://www.w3.org/TR/html4/strict.dtd\">",
    "frameset" : "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\"\n\"http://www.w3.org/TR/html4/frameset.dtd\">"
]);

//!
string docstart = "%s\n<html><head><title>%s</title>%s%s</head><body>%s</body></html>";

//! Month names (in english).
constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
 		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

//! Day names (in english).
constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

//! Month names and numbers.
constant MONTHS=(["Jan":0, "Feb":1, "Mar":2, "Apr":3, "May":4, "Jun":5,
                  "Jul":6, "Aug":7, "Sep":8, "Oct":9, "Nov":10, "Dec":11,
                  "jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
                  "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

//!
constant iso88591 = ([
  "&nbsp;":   " ",
  "&iexcl;":  "¡",
  "&cent;":   "¢",
  "&pound;":  "£",
  "&curren;": "¤",
  "&yen;":    "¥",
  "&brvbar;": "¦",
  "&sect;":   "§",
  "&uml;":    "¨",
  "&copy;":   "©",
  "&ordf;":   "ª",
  "&laquo;":  "«",
  "&not;":    "¬",
  "&shy;":    "­",
  "&reg;":    "®",
  "&macr;":   "¯",
  "&deg;":    "°",
  "&plusmn;": "±",
  "&sup2;":   "²",
  "&sup3;":   "³",
  "&acute;":  "´",
  "&micro;":  "µ",
  "&para;":   "¶",
  "&middot;": "·",
  "&cedil;":  "¸",
  "&sup1;":   "¹",
  "&ordm;":   "º",
  "&raquo;":  "»",
  "&frac14;": "¼",
  "&frac12;": "½",
  "&frac34;": "¾",
  "&iquest;": "¿",
  "&Agrave;": "À",
  "&Aacute;": "Á",
  "&Acirc;":  "Â",
  "&Atilde;": "Ã",
  "&Auml;":   "Ä",
  "&Aring;":  "Å",
  "&AElig;":  "Æ",
  "&Ccedil;": "Ç",
  "&Egrave;": "È",
  "&Eacute;": "É",
  "&Ecirc;":  "Ê",
  "&Euml;":   "Ë",
  "&Igrave;": "Ì",
  "&Iacute;": "Í",
  "&Icirc;":  "Î",
  "&Iuml;":   "Ï",
  "&ETH;":    "Ð",
  "&Ntilde;": "Ñ",
  "&Ograve;": "Ò",
  "&Oacute;": "Ó",
  "&Ocirc;":  "Ô",
  "&Otilde;": "Õ",
  "&Ouml;":   "Ö",
  "&times;":  "×",
  "&Oslash;": "Ø",
  "&Ugrave;": "Ù",
  "&Uacute;": "Ú",
  "&Ucirc;":  "Û",
  "&Uuml;":   "Ü",
  "&Yacute;": "Ý",
  "&THORN;":  "Þ",
  "&szlig;":  "ß",
  "&agrave;": "à",
  "&aacute;": "á",
  "&acirc;":  "â",
  "&atilde;": "ã",
  "&auml;":   "ä",
  "&aring;":  "å",
  "&aelig;":  "æ",
  "&ccedil;": "ç",
  "&egrave;": "è",
  "&eacute;": "é",
  "&ecirc;":  "ê",
  "&euml;":   "ë",
  "&igrave;": "ì",
  "&iacute;": "í",
  "&icirc;":  "î",
  "&iuml;":   "ï",
  "&eth;":    "ð",
  "&ntilde;": "ñ",
  "&ograve;": "ò",
  "&oacute;": "ó",
  "&ocirc;":  "ô",
  "&otilde;": "õ",
  "&ouml;":   "ö",
  "&divide;": "÷",
  "&oslash;": "ø",
  "&ugrave;": "ù",
  "&uacute;": "ú",
  "&ucirc;":  "û",
  "&uuml;":   "ü",
  "&yacute;": "ý",
  "&thorn;":  "þ",
  "&yuml;":   "ÿ",
]);

//!
constant international = ([
  "&OElig;":  "\x0152",
  "&oelig;":  "\x0153",
  "&Scaron;": "\x0160",
  "&scaron;": "\x0161",
  "&Yuml;":   "\x0178",
  "&circ;":   "\x02C6",
  "&tilde;":  "\x02DC",
  "&ensp;":   "\x2002",
  "&emsp;":   "\x2003",
  "&thinsp;": "\x2009",
  "&zwnj;":   "\x200C",
  "&zwj;":    "\x200D",
  "&lrm;":    "\x200E",
  "&rlm;":    "\x200F",
  "&ndash;":  "\x2013",
  "&mdash;":  "\x2014",
  "&lsquo;":  "\x2018",
  "&rsquo;":  "\x2019",
  "&sbquo;":  "\x201A",
  "&ldquo;":  "\x201C",
  "&rdquo;":  "\x201D",
  "&bdquo;":  "\x201E",
  "&dagger;": "\x2020",
  "&Dagger;": "\x2021",
  "&permil;": "\x2030",
  "&lsaquo;": "\x2039",
  "&rsaquo;": "\x203A",
  "&euro;":   "\x20AC",
  "&odbacute;": "\x0151",
  "&Odbacute;": "\x0150",
  "&udbacute;": "\x0171",
  "&Udbacute;": "\x0170",
  "&odblac;": "\x0151",
  "&Odblac;": "\x0150",
  "&udblac;": "\x0171",
  "&Udblac;": "\x0170",
]);

//!
constant symbols = ([
  "&fnof;":     "\x0192",
  "&thetasym;": "\x03D1",
  "&upsih;":    "\x03D2",
  "&piv;":      "\x03D6",
  "&bull;":     "\x2022",
  "&hellip;":   "\x2026",
  "&prime;":    "\x2032",
  "&Prime;":    "\x2033",
  "&oline;":    "\x203E",
  "&frasl;":    "\x2044",
  "&weierp;":   "\x2118",
  "&image;":    "\x2111",
  "&real;":     "\x211C",
  "&trade;":    "\x2122",
  "&alefsym;":  "\x2135",
  "&larr;":     "\x2190",
  "&uarr;":     "\x2191",
  "&rarr;":     "\x2192",
  "&darr;":     "\x2193",
  "&harr;":     "\x2194",
  "&crarr;":    "\x21B5",
  "&lArr;":     "\x21D0",
  "&uArr;":     "\x21D1",
  "&rArr;":     "\x21D2",
  "&dArr;":     "\x21D3",
  "&hArr;":     "\x21D4",
  "&forall;":   "\x2200",
  "&part;":     "\x2202",
  "&exist;":    "\x2203",
  "&empty;":    "\x2205",
  "&nabla;":    "\x2207",
  "&isin;":     "\x2208",
  "&notin;":    "\x2209",
  "&ni;":       "\x220B",
  "&prod;":     "\x220F",
  "&sum;":      "\x2211",
  "&minus;":    "\x2212",
  "&lowast;":   "\x2217",
  "&radic;":    "\x221A",
  "&prop;":     "\x221D",
  "&infin;":    "\x221E",
  "&ang;":      "\x2220",
  "&and;":      "\x2227",
  "&or;":       "\x2228",
  "&cap;":      "\x2229",
  "&cup;":      "\x222A",
  "&int;":      "\x222B",
  "&there4;":   "\x2234",
  "&sim;":      "\x223C",
  "&cong;":     "\x2245",
  "&asymp;":    "\x2248",
  "&ne;":       "\x2260",
  "&equiv;":    "\x2261",
  "&le;":       "\x2264",
  "&ge;":       "\x2265",
  "&sub;":      "\x2282",
  "&sup;":      "\x2283",
  "&nsub;":     "\x2284",
  "&sube;":     "\x2286",
  "&supe;":     "\x2287",
  "&oplus;":    "\x2295",
  "&otimes;":   "\x2297",
  "&perp;":     "\x22A5",
  "&sdot;":     "\x22C5",
  "&lceil;":    "\x2308",
  "&rceil;":    "\x2309",
  "&lfloor;":   "\x230A",
  "&rfloor;":   "\x230B",
  "&lang;":     "\x2329",
  "&rang;":     "\x232A",
  "&loz;":      "\x25CA",
  "&spades;":   "\x2660",
  "&clubs;":    "\x2663",
  "&hearts;":   "\x2665",
  "&diams;":    "\x2666",
]);

//!
constant greek = ([
  "&Alpha;":   "\x391",
  "&Beta;":    "\x392",
  "&Gamma;":   "\x393",
  "&Delta;":   "\x394",
  "&Epsilon;": "\x395",
  "&Zeta;":    "\x396",
  "&Eta;":     "\x397",
  "&Theta;":   "\x398",
  "&Iota;":    "\x399",
  "&Kappa;":   "\x39A",
  "&Lambda;":  "\x39B",
  "&Mu;":      "\x39C",
  "&Nu;":      "\x39D",
  "&Xi;":      "\x39E",
  "&Omicron;": "\x39F",
  "&Pi;":      "\x3A0",
  "&Rho;":     "\x3A1",
  "&Sigma;":   "\x3A3",
  "&Tau;":     "\x3A4",
  "&Upsilon;": "\x3A5",
  "&Phi;":     "\x3A6",
  "&Chi;":     "\x3A7",
  "&Psi;":     "\x3A8",
  "&Omega;":   "\x3A9",
  "&alpha;":   "\x3B1",
  "&beta;":    "\x3B2",
  "&gamma;":   "\x3B3",
  "&delta;":   "\x3B4",
  "&epsilon;": "\x3B5",
  "&zeta;":    "\x3B6",
  "&eta;":     "\x3B7",
  "&theta;":   "\x3B8",
  "&iota;":    "\x3B9",
  "&kappa;":   "\x3BA",
  "&lambda;":  "\x3BB",
  "&mu;":      "\x3BC",
  "&nu;":      "\x3BD",
  "&xi;":      "\x3BE",
  "&omicron;": "\x3BF",
  "&pi;":      "\x3C0",
  "&rho;":     "\x3C1",
  "&sigmaf;":  "\x3C2",
  "&sigma;":   "\x3C3",
  "&tau;":     "\x3C4",
  "&upsilon;": "\x3C5",
  "&phi;":     "\x3C6",
  "&chi;":     "\x3C7",
  "&psi;":     "\x3C8",
  "&omega;":   "\x3C9",
]);

//!
constant replace_entities = indices( iso88591 ) +
         indices( international ) +
         indices( symbols ) +
         indices( greek ) +
         ({"&lt;","&gt;","&amp;","&quot;","&apos;","&#x22;","&#34;","&#39;","&#0;"});

//!
constant replace_values = values( iso88591 ) +
         values( international ) +
         values( symbols ) +
         values( greek ) +
         ({"<",">","&","\"","\'","\"","\"","\'","\000"});

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
