/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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
/* <tablify> tag - convert text to HTML tables
 *
 * Converts tab and newline separated lists to tables.
 * 
 * made by Per Hedbor
 */

constant cvs_version = "$Id$";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

constant module_type = MODULE_PARSER;
constant module_name = "Tablify";
constant module_doc  = "This tag generates tables.<p>"
"<tt>&lt;tablify help&gt;&lt;/tablify&gt;</tt> gives help.\n\n<p>"; //+doc();
constant module_unique = 1;

static private int loaded;

static private constant old_doc =
  ("Generates tables from, as an example, tab separated fields in newline"
   " separated records (this is the default)."
   "<p>This module defines a tag, {tablify}<p>Arguments:<br>"
   "help: This help<br>\n"
   "nice: Generate \"nice\" tables. The first row is the title row<br>\n"
   "nicer: Generate \"even nicer\" tables. The first row is the title row<br>\n"
   "cellseparator=str: Use str as the column-separator<br>\n"
   "rowseparator=str: Use str as the row-separator<br>\n"
   "cellalign=left|right|center: Align the contents of the cells<br>\n"
   "rowalign=left|right|center: Align the contents of the rows<br>\n");

static private string doc()
{
  return !loaded?"":replace(Stdio.read_bytes("modules/tags/doc/tablify")||
			    old_doc,
			    ({ "{", "}" }), ({ "&lt;", "&gt;" }));
}


void start(int num, object configuration)
{
  loaded = 1;
}

string html_nicer_table(array(string) subtitles, array(array(string)) table,
			mapping|void opt)
{
  /* Options:
   *   bgcolor, titlebgcolor, titlecolor, fgcolor0, fgcolor1, modulo,
   *   font, scale, face, size
   * Containers:
   *   <fields>[num|text, ...]</fields>
   */

  string r = "";

  if(!opt) opt = ([]);
  int m = (int)(opt->modulo?opt->modulo:1);
  r += ("<table bgcolor="+(opt->bgcolor||"#27215b")+" border=0 "
	"cellspacing=0 cellpadding=1>\n"
	"<tr><td>\n");
  r += "<table border=0 cellspacing=0 cellpadding=2>\n";
  r += "<tr bgcolor="+(opt->titlebgcolor||"#27215b")+">\n";
  int cols;
  foreach(subtitles, mixed s)
    r+=
      "<td align=left><gtext nfont="+(opt->font||"lucida")+" scale="+
      (opt->scale||"0.36")+" fg="+(opt->titlecolor||"white")+" bg="+
      (opt->titlebgcolor||"#27215b")+">"+s+"</gtext></td>";
  r += "</tr>";
  
  for(int i = 0; i < sizeof(table); i++) {
    string tr;
    r += tr = "<tr bgcolor="+((i/m)%2?opt->fgcolor1||"#ddeeff":
			      opt->fgcolor0||"#ffffff")+">";
    for(int j = 0; j < sizeof(table[i]); j++) {
      mixed s = table[i][j];
      if(arrayp(s))
	r += "</tr>"+tr+"<td colspan="+cols+">"+s[0]+" &nbsp;</td>";
      else {
	string type = "text";
	if(arrayp(opt->fields) && j < sizeof(opt->fields))
	  type = opt->fields[j];
	switch(type) {
	case "num":
	  array a = s/".";
	  r += "<td align=right><font color="+(opt->fgcolor||"black")+" size="+(opt->size||"2")+" face=\""+
	    (opt->face||"helvetica,arial")+"\">";
	  if(sizeof(a) > 1) {
	    r += (format_numeric(a[0])+"."+
		  reverse(format_numeric(reverse(a[1]), ";psbn&")));
	  } else
	    r += format_numeric(s, "&nbsp;");
	  break;
	case "text":
	default:
	  r += "<td><font color="+(opt->fgcolor||"black")+" size="+(opt->size||"2")+" face=\""+
	    (opt->face||"helvetica,arial")+"\">"+s;
	}
	r += "&nbsp;&nbsp;</font></td>";
      }
    }
    r += "</tr>\n";
  }
  r += "</table></td></tr>\n";
  r += "</table><br>\n";
  return r;
}


/* The meat of the module. Convert the contents of the tag (in 'q') to
 * a table. */

string container_fields(string name, mapping arg, string q,
			mapping m, mapping arg_list)
{
  arg_list->fields = q/(m->cellseparator||"\t");
  return "";
}

string tag_tablify( string tag, mapping m, string q, object request_id,
		    object file, mapping defines)
{
  array rows, res;
  string sep, td, color, table;
  int i;

#if 0
  sscanf(q, "%*[\n]%s", q);
  sscanf(reverse(q), "%*[\n]%s", q);
  q = reverse(q);
#endif

  if(tag == "htable") m->nice="nice";
  
  if(m->help) return module_doc;

  if (m->preprocess || m->parse) {
    q = parse_rxml(q, request_id, file, defines);
  }

  mapping arg_list = ([]);
  q = parse_html(q, ([]), (["fields":container_fields]), m, arg_list);

  if(sep = m->rowseparator)
    m->rowseparator = 0;
  else
    sep = "\n";

  rows = (q / sep) - ({""});
  
  if(sep = m->cellseparator)
    m->cellseparator = 0;
  else
    sep = "\t";

  if(m->cellalign)
  {
    td = "<td align="+m->cellalign+">";
    m->cellalign = 0;
  } else
    td="<td>";

  array title;
  if(m->nice||m->nicer) {
    title = rows[0]/sep;
    rows = rows[1..];
  }

  if(m->min)
    rows = rows[((int)m->min)..];
  if(m->max)
    rows = rows[..((int)m->max-1)];
  
  if(m->nice)
  {
    rows = Array.map(rows,lambda(string r, string s){return r/s;}, sep);
    string res = html_table(title, rows, m + arg_list);
    if(m->wrap)
      return replace(res, ({ "<td nowrap", "<th nowrap" }),
		     ({ "<td", "<th"}));
    return res;
  }

  if(m->nicer)
  {
    rows = Array.map(rows,lambda(string r, string s){return r/s;}, sep);
    return html_nicer_table(title, rows, m + arg_list);
  }
  
  for(i=0; i<sizeof(rows); i++)
    rows[i] = td + (rows[i]/sep) * ("</td>"+td) + "</td>";

  table = "<table";
  foreach(indices(m), td)
    if(m[td]) table += " "+td+"=\""+m[td]+"\"";

  table += ">";
  if(m->rowalign)
  {
    td = "<tr align="+m->rowalign+">";
    m->rowalign=0;
  } else
    td="<tr>";

  return table + td + rows*("</tr>\n"+td) + "</tr>\n</table>";
}

mapping query_container_callers()
{
  return ([ "tablify" : tag_tablify, "htable" : tag_tablify ]);
}

