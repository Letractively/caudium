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
 * $Id$
 */

/*
 * made by Pontus Hagland <law@idonex.se> december -96
 */
 
//
//! module: Folder list tag
//!  Adds the tags to make creating folding lists an easy task.
//!  Adds the &lt;fl&gt;, &lt;ft&gt; and &lt;fd&gt; tags. This makes it easy to 
//!  build a folder list or an outline.
//!
//!  The lists can be nested, i.e.:
//!    &lt;ft&gt;...&lt;fd&gt;...&lt;/fd&gt;&lt;/ft&gt; with implicit end tags
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
//! container: fl
//!  This tag is used to build folding lists, that are like {dl}
//!  lists, but where each element can be unfolded. The tags used to build
//!  the list elements are &lt;ft&gt; and &lt;fd&gt;.
//
//! example: rxml
//!  <fl>
//!      <ft>ho
//!          <fd>heyhepp
//!      <ft>alakazot
//!          <fd>no more
//!  </fl>
//
//! tag: ft
//!  Creates a folder list entry
//
//! attribute: [folded]
//!  Will make all elements in the list or that element folded by
//!  default.
//
//! attribute: [unfolded]
//!  Will make all elements in the list or that element unfolded by
//!  default.
//
//! tag: fd
//!  Follows &lt;ft&gt; and marks the entry "definition".
//
//! attribute: [folded]
//!  Will make all elements in the list or that element folded by
//!  default.
//
//! attribute: [unfolded]
//!  Will make all elements in the list or that element unfolded by
//!  default.
//

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PARSER; 
constant module_name = "Folder list tag";
constant module_doc  = "Adds the &lt;fl&gt;, &lt;ft&gt; and &lt;fd&gt; tags."
	       " This makes it easy to build a folder list or an outline. "
	       "Example:<pre>"
	       "&lt;fl unfolded&gt;\n"
	       "  &lt;ft folded&gt;ho\n"
	       "   &lt;fd&gt;heyhepp\n"
	       "  &lt;ft&gt;alakazot\n"
	       "   &lt;fd&gt;no more\n"
	       "&lt;/fl&gt;</pre>";
constant module_unique = 1;

mapping flcache=([]); 
   // not_query:(flno: 1=fodled 2=unfolded )
int flno=1;

#define GC_LOOP_TIME QUERY(gc_time)
void create()
{
   defvar("gc_time", 300, "GC time", TYPE_INT,
	 "Time between gc loop. (It doesn't run when nothing to garb, anyway.)");

}


void gc()
{
   mixed m,n;
   int k=0;
   foreach (indices(flcache),m)
   {
      if (equal(({"gc"}),indices(flcache[m])))
	 m_delete(flcache,m);
      else 
      {
	 foreach (flcache[m]->gc,n)
	    m_delete(flcache[m],n); 
	 k+=sizeof(indices(flcache[m]));
	 flcache[m]->gc=indices(flcache[m])-({"gc"});
      }
   }
   if (k) call_out(gc,GC_LOOP_TIME);
}


string encode_url(object id, 
		  int flno,
		  int dest)
{
  string url = (id->not_query/"/")[-1]+"?fl="+id->variables->fl
    +"&flc"+flno+"="+dest;
  foreach(indices(id->variables), string var)
    if(var != "fl" && var[..2] != "flc" && stringp(id->variables[var]))
      url += sprintf("&%s=%s", http_encode_string(var),
		     http_encode_string(id->variables[var]));
  return url+"#fl_"+flno;
}

string tag_fl_postparse( string tag, mapping m, string cont, object id,
			 object file, mapping defines, object client )
{
   if (!id->variables->fl)
      id->variables->fl=flno++;
   if (!flcache[id->not_query])
   {
      if (-1==find_call_out(gc))
	 call_out(gc,GC_LOOP_TIME);
      flcache[id->not_query]=(["gc":({})]);
   }
   flcache[id->not_query]->gc-=({id->variables->fl});
   if (!flcache[id->not_query][id->variables->fl])
      flcache[id->not_query][id->variables->fl]=([]);

   if (id->variables["flc"+m->id])
   {
      flcache[id->not_query][id->variables->fl][m->id]=
	 (int)id->variables["flc"+m->id];
   }
   else if (!flcache[id->not_query][id->variables->fl][m->id])
   {
      if (m->unfolded)
	 flcache[id->not_query][id->variables->fl][m->id]=2;
      else 
	 flcache[id->not_query][id->variables->fl][m->id]=1;
   }

   if (m->title)
   if (flcache[id->not_query][id->variables->fl][m->id]==1)
   {
      return "<!--"+m->id+"-->"
	     "<a name=fl_"+m->id+" target=_self href='"+
	     encode_url(id,m->id,2)+"'>"
	     "<img width=20 height=20 src=internal-caudium-unfold border=0 "
	     "alt='--'></a>"+cont;
   }
   else
   {
      return "<!--"+m->id+"-->"
	     "<a name=fl_"+m->id+" target=_self href='"+
	     encode_url(id,m->id,1)+"'>"
	     "<img width=20 height=20 src=internal-caudium-fold border=0 "
	     "alt='\/'></a>"+cont;
   }
   else
   if (flcache[id->not_query][id->variables->fl][m->id]==1)
   {
      return "<!--"+m->id+"-->"+"";
   }
   else
   {
      return "<!--"+m->id+"-->"+cont;
   }
}

string recurse_parse_ftfd(string cont,mapping m,string id);

string tag_fl( string tag, mapping arg, string cont, 
	       mapping ma, string id, mapping defines)
{
   mapping m=(["ld":"","t":"","cont":"","count":0]);

   if (defines && defines[" fl "]) m=defines[" fl "];

   if (objectp(id)) id="";
   else id=((id=="")?"":id+":")+ma->count+":";

   if (!arg->folded) m->folded="unfolded";
   else m->folded="folded";

   recurse_parse_ftfd(cont,m,id);

   if (defines) defines[" fl "]=m;

   return "<dl>"+m->cont+"</dl>";
}

string recurse_parse_ftfd(string cont,mapping m,string id)
{
   return parse_html(cont,([]),
		(["ft":
		  lambda(string tag,mapping arg,string cont,mapping m,string id)
		  {
		     string t,fold;
		     int kinc=m->inc;
		     int me;
		     m->cont="";
		     me=++m->count;
		     t=recurse_parse_ftfd(cont,m,id);

		     if (arg->folded) fold="folded";
		     else if (arg->unfolded) fold="unfolded";
		     else fold=m->folded;

		     m->cont=
			"\n<dt><fl_postparse title "+fold
			+" id="
                        +((id=="")?(string)me:(id+me))+">"
                        +t+"</fl_postparse>"
                        +m->ld
                        +m->cont;
		     m->ld="";
		     m->inc=kinc+1;
		     return "";
		  },
		  "fd":
		  lambda(string tag,mapping arg,string cont,mapping m,string id)
		  {
		     m->ld=
                        "\n<fl_postparse contents id="
                        +((id=="")?(string)m->count:(id+m->count))+">"
			+"<dd>"
			+recurse_parse_ftfd(cont,m,id)
			+"</fl_postparse>"
                        +m->ld;

		     return "";
		  },
		  "fl":tag_fl]),m,id);
}
			 

mapping query_container_callers()
{
  return ([ "fl" : tag_fl,
	    "fl_postparse" : tag_fl_postparse]);
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: gc_time
//! Time between gc loop. (It doesn't run when nothing to garb, anyway.)
//!  type: TYPE_INT
//!  name: GC time
//
