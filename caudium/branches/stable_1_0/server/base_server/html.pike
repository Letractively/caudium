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

//string cvs_version = "$Id$";
#define __replace(X) (X)

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


string pre(string f)
{
  return "<pre>\n"+f+"</pre>\n";
}


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

string tr(string data, int|void rows)
{
  if(rows) 
    return "<tr rowspan="+rows+">\n" + __replace(data) + "</tr><p>";
  else
    return "<tr>\n" + __replace(data) + "</tr><p>\n";
}


string td(string t, string|void align, int|void rows, int|void cols)
{
  string q="";
  if(align) q+=" align="+align; 
  if(rows)  q+=" rowspan="+rows;
  if(cols)  q+=" colspan="+cols;
  return "<td"+q+">\n" + __replace(t) +"</td>\n";
}

string bf(string|void s, int|void i)
{
  return "<font size=+"+(i+1)+"><b>"+s+"</b></font>";
}

string th(string t, string|void align, int|void rows, 
	  int|void cols)
{
  string q="";
  if(align) q+=" align="+align; 
  if(rows)  q+=" rowspan="+rows;
  if(cols)  q+=" colspan="+cols;
  return "<th"+q+">\n" + __replace(t) +"</th>\n";
}

string h1(string h)
{
  return "<h1>"+h+"</h1>\n\n";
}

string h2(string h)
{
  return "<h2>"+h+"</h2>\n\n";
}

string h3(string h)
{
  return "<h3>"+h+"</h3>\n\n";
}

#if 0
inline string button(string text, string url)
{
  return sprintf("<form method=get action=\"%s\"><input type=submit value"+
		 "=\"%s\"></form>", replace(url, " ", "%20"), text);
}

inline string link(string text, string url)
{ 
  return sprintf("<a href=\"%s\">%s</a>", replace(url, " ", "%20"), text);
}
#endif
 

