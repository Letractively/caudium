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
constant cvs_version = "$Id$";

//! Some code to render HTML

#define __replace(X) (X) 		// What is this for ? - XB

//! Creates a <input type > html code
//! @param name
//!   The name used for input type.
//! @param val
//!   The default value
//! @param t
//!   If this <input> should be hidden
//! @returns
//!   An Form input string.
string input(string name, string|void val, int|void t)
{
  name = replace (name, ({"&", "\""}), ({"&amp;", "&quot;"}));
  if(!stringp(val))
    val = sprintf ("%O", val);
  val = replace (val, ({"&", "\""}), ({"&amp;", "&quot;"}));
  if(!t)
    return "<input type=hidden name=\"" + name + "\" value=\"" + val + "\">";
  return "<input size=" + t + ",1 name=\"" + name + "\" value=\"" + val + "\">";
}

//! Adds <pre></pre>
//! @param f
//!   String
//! @returns
//!   The contents of string f with <pre> </pre> between it.
string pre(string f)
{
  return "<pre>\n"+f+"</pre>\n";
}

//! Create a HTML table
//! @param t
//!   The contents of the table
//! @param cellspacing
//!   The cellspacing value
//! @param callpadding
//!   The cellpadding value
//! @param border
//!   The size of border
//! @param width
//!   The size of the table
//! @returns
//!   HTML table.
//! @seealso
//!   @[tr]
//!   @[td]
//!   @[th]
//! @fixme
//!   Add support for CSS ?  
string table(string|void t, int|void cellspacing, int|void cellpadding,
	     int|void border, int|void width)
{
  string d="";
  int ds, dp;
  if(border)
  {
    d += " border="+border;
    ds=2;
    dp=3;
  }

  if(cellspacing)
    ds=cellspacing;
  d += " cellspacing="+ds;
  if(cellpadding)
    dp=cellpadding;
  d += " cellpadding="+dp;
  if(width)
    d += " width="+width+"%";
  return "<table"+d+">\n"+__replace(t)+"</table>\n\n";
}

//! Create a Table line
//! @param data
//!   The data to put inside the line
//! @param row
//!   The rowspan parameter.
//! @returns
//!   HTML code for Line in a table
//! @seealso
//!   @[table]
//!   @[td]
//!   @[th]
//! @fixme
//!   Add code for CSS ?
string tr(string data, int|void rows)
{
  if(rows) 
    return "<tr rowspan="+rows+">\n" + __replace(data) + "</tr><p>";
  else
    return "<tr>\n" + __replace(data) + "</tr><p>\n";
}

//! Create a data cell for a Table
//! @param t
//!   The data
//! @param align
//!   The align value
//! @param rows
//!   The rowspan value
//! @param cols
//!   The colspan value
//! @returns
//!   HTML code for a cell in a table
//! @seealso
//!   @[table]
//!   @[tr] 
//!   @[th]
//! @fixme
//!   Add code for CSS ?
string td(string t, string|void align, int|void rows, int|void cols)
{
  string q="";
  if(align) q+=" align="+align; 
  if(rows)  q+=" rowspan="+rows;
  if(cols)  q+=" colspan="+cols;
  return "<td"+q+">\n" + __replace(t) +"</td>\n";
}

//! Bigger font for a string
//! @param s
//!   The string
//! @param i
//!   How mutch bigger must be it.
//! @returns
//!   A <font size=+i><b>s</b></font>
//! @fixme
//!   Handle for CCS ?
string bf(string|void s, int|void i)
{
  return "<font size=+"+(i+1)+"><b>"+s+"</b></font>";
}

//! Table header for HTML tables
//! @param t
//!   The data to put on header
//! @param align
//!   The align value
//! @param rows
//!   The rowspan value
//! @param cols
//!   The colspan value
//! @returns
//!   HTML code for table headers
//! @seealso
//!   @[table]
//!   @[td]
//!   @[tr]
//! @fixme
//!   Add code for CSS ?
string th(string t, string|void align, int|void rows, 
	  int|void cols)
{
  string q="";
  if(align) q+=" align="+align; 
  if(rows)  q+=" rowspan="+rows;
  if(cols)  q+=" colspan="+cols;
  return "<th"+q+">\n" + __replace(t) +"</th>\n";
}

//! Add <H1></H1>
//! @param h
//!   The string
//! @returns
//!   Html results
string h1(string h)
{
  return "<h1>"+h+"</h1>\n\n";
}

//! Add <H2></H2>
//! @param h
//!   The string
//! @returns
//!   Html results
string h2(string h)
{
  return "<h2>"+h+"</h2>\n\n";
}

//! Add <H3></H3>
//! @param h
//!   The string
//! @returns
//!   Html results
string h3(string h)
{
  return "<h3>"+h+"</h3>\n\n";
}

#if 0

//!
//! @note
//!   Not used
inline string button(string text, string url)
{
  return sprintf("<form method=get action=\"%s\"><input type=submit value"+
		 "=\"%s\"></form>", replace(url, " ", "%20"), text);
}

//!
//! @note
//!   Not used
inline string link(string text, string url)
{ 
  return sprintf("<a href=\"%s\">%s</a>", replace(url, " ", "%20"), text);
}
#endif
 

