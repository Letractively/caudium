/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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
 * The SED tag, a tag that allows you to do sed-like string handling.
 */

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "caudiumlib";

mapping flcache=([]); 
   // not_query:(flno: 1=fodled 2=unfolded )
int flno=1;

#define GC_LOOP_TIME QUERY(gc_time)
void create()
{
}


array (mixed) register_module()
{
  return ({ MODULE_PARSER, "SED tag", 
	    "",
	    ({}),1 });
}

void start()
{
}

array sedreplace(string s,object re,string with,
		 array whatin,int first,int lastmod,
		 multiset flags)
{
   array a;
   string w=0;
   array pr=({});

   if (!(a=re->split(s)))
      return 0;

   if (first)
   {
      array wa;
      wa=sedreplace(a[0],re,with,whatin,first,lastmod,flags);
      if (wa)
	 if (!flags["g"])
	    return ({wa[0],wa[1]+s[strlen(a[0])..]});
	 else
	    pr=wa[0],w=wa[1];
      else
	 w=a[0];
   }
   
   string t=
      replace(with,whatin[..sizeof(a)-first+lastmod-1],
	      a[first..sizeof(a)+lastmod-1]);

   if (flags["p"]) pr+=({t});

   s=(w||"")+t;
   if (flags["g"])
   {
      if (lastmod) 
      {
	 array wa;
	 wa=sedreplace(a[-1],re,with,whatin,first,lastmod,flags);
	 if (wa) 
	 {
	    pr+=wa[0];
	    s+=wa[1];
	 }
	 else
	    s+=a[-1];
      }
   }
   else
      s+=a[-1];

   return ({pr,s});
};

array scan_for_linenumber(string cmd,
			  array(string) in,
			  int n)
{
   int x;
   string what;
   object re;

   while (cmd!="" && (cmd[0]>='0' && cmd[0]<='9') 
	  || cmd[0]=='/' || cmd[0]=='+' || cmd[0]=='-')
   {
      if (cmd[0]>='0' && cmd[0]<='9')
      {
	 sscanf(cmd,"%d%s",n,cmd);
	 n--;
      }
      else if (cmd[0]=='+')
      {
	 sscanf(cmd,"+%d%s",x,cmd);
	 n+=x; 
      }
      else if (cmd[0]=='-')
      {
	 sscanf(cmd,"-%d%s",x,cmd);
	 n-=x; 
      }
      else if (sscanf(cmd,"/%s/%s",what,cmd)==2)
      {
	 re=Regexp(what);
	 while (n<sizeof(in))
	 {
	    if (re->match(in[n])) break;
	    n++;
	 }
      }
      else break;
   }
   if (n<0) n=0; else if (n>=sizeof(in)) n=sizeof(in)-1;
   return ({n,cmd});
}

array execute_sed(array(string) e,array(string) in,int suppress)
{
   int start,stop;
   string div,what,with,inflags;
   multiset flags;
   array whatin=({"\\1","\\2","\\3","\\4","\\5","\\6","\\7","\\8","\\9"});
   array print=({});
   array hold=({});
   object re;
   array a1,a2;

   start=0; 
   stop=sizeof(in)-1;

   foreach (e, string cmd)
   {
      a1=scan_for_linenumber(cmd,in,start);
      start=a1[0]; 
      cmd=a1[1];

      if (cmd[0..1]==",$") { cmd=cmd[2..]; stop=sizeof(in)-1; }
      else if (sscanf(cmd,",%s",cmd))
      {
	 a1=scan_for_linenumber(cmd,in,start);
	 stop=a1[0]; 
	 cmd=a1[1];
      }

      if (stop>sizeof(in)-1) stop=sizeof(in)-1;
      if (start<0) start=0;
      
      if (cmd=="") continue;
      switch (cmd[0])
      {
	 case 's':
	    div=cmd[1..1]; 
	    if (div=="%") div="%%";
	    inflags="";
	    if (sscanf(cmd,"%*c"+div+"%s"+div+"%s"+div+"%s",
		       what,with,inflags)<3) continue;
	    flags=aggregate_multiset(@(inflags/""));
	    
	    int first=0,lastmod=0;
	    if (what!="") // fix the regexp for working split
	    {
	       if (what[0]!='^') what="^(.*)"+what,first=1;
	       if (what[-1]!='$') what=what+"(.*)$",lastmod=-1;
	    }
	    re=Regexp(what);

	    while (start<=stop)
	    {
	       array sa=sedreplace(in[start],re,with,whatin,
				   first,lastmod,flags);

	       if (sa)
	       {
		  in[start]=sa[1];
		  print+=sa[0];
		  if (!flags["g"]) break;
	       }
	       start++;
	    }
	    
	    break;

	 case 'y':
	    div=cmd[1..1]; 
	    if (div=="%") div="%%";
	    inflags="";
	    if (sscanf(cmd,"%*c"+div+"%s"+div+"%s"+div+"%s",
		       what,with,inflags)<3) continue;
	    if (strlen(what)!=strlen(with))
	    {
	       what=what[0..strlen(with)-1];
	       with=with[0..strlen(what)-1];
	    }
	    
	    a1=what/"",a2=with/"";

	    while (start<=stop)
	    {
	       in[start]=replace(in[start],a1,a2);
	       start++;
	    }
	    break;

	 case 'G': // insert hold space
	    in=in[..start-1]+hold+in[start..];
	    if (stop>=start) stop+=sizeof(hold);
	    break;

	 case 'a': // insert line
	    in=in[..start-1]+({cmd[1..]})+in[start..];
	    if (stop>=start) stop++;
	    break;

	 case 'c': // change 
	    in=in[..start-1]+({cmd[1..]})+in[stop+1..];
	    stop=start;
	    break;

	 case 'd': // delete 
	    in=in[..start-1]+in[stop+1..];
	    stop=start;
	    break;

	 case 'D': // delete first line
	    in=in[..start-1]+in[start+1..];
	    stop=start;
	    break;

	 case 'h': // copy
	    hold=in[start..stop];
	    break;

	 case 'H': // appending copy
	    hold+=in[start..stop];
	    break;
	    
	 case 'i': // print text
	    print+=({cmd[1..]});
	    break;

	 case 'l': // print space
	    print+=in[start..stop];
	    break;

	 case 'P': // print all
	    print+=in;
	    break;

	 case 'p': // print first
	    print+=in[..0];
	    break;

	 case 'q': // quit
	    if (!suppress) return print+in;
	    return print;
   
	 default:
	    // error? just ignore for now
      }
   }
   if (!suppress) return print+in;
   return print;
}

string tag_sed(string tag,mapping m,string cont,object id)
{
   mapping c=(["e":({})]);
   string|array d;
   
   parse_html(cont,
	      (["source":lambda(string tag,mapping m,mapping c,object id)
			 { 
			    if (m->variable)
			       c->data=id->variables[m->variable]||"";
			    else if (m->cookie)
			       c->data=id->cookie[m->cookie]||"";
			    else
			       c->data="";
			    if (m->rxml) c->data=parse_rxml(c->data,id);
			 },
		"destination":lambda(string tag,mapping m,mapping c,object id)
			 { 
			    if (m->variable) c->destvar=m->variable;
			    else if (m->cookie) c->destcookie=m->cookie;
			    else c->nodest=1;
			 },
	      ]),
	      (["e":lambda(string tag,mapping m,string cont,mapping c,
			   object id)
		    { if (m->rxml) c->e+=({parse_rxml(cont,id)});
		       else c->e+=({cont}); },
		"raw":lambda(string tag,mapping m,string cont,mapping c)
		       { c->data=cont; },
		"rxml":lambda(string tag,mapping m,string cont,mapping c,
			      object id)
		       { c->data=parse_rxml(cont,id); },
	      ]),c,id);

   if (!c->data) return "<!-- sed command missing data -->";
   
   d=c->data;

   if (m->split) d/=m->split;
   else if (m->lines) d/="\n"; 
   else if (m->chars) d/=""; 
   else d=({c->data});

   d=execute_sed(c->e,d,!!(m->suppress||m["-n"]));

   if (m->split) d*=m->split;
   else if (m->lines) d*="\n"; 
   else if (m->chars) d*=""; 
   else d=d*"";

   if (c->destvar)
   {
      if (m->prepend) d+=id->variables[c->destvar]||"";
      if (m->apppend) d=(id->variables[c->destvar]||"")+d;
      id->variables[c->destvar]=d;
   }
   else if (c->destcookie)
   {
      if (m->prepend) d+=id->variables[c->destvar]||"";
      if (m->apppend) d=(id->variables[c->destvar]||"")+d;
      id->cookie[c->destcookie]=d;
   }
   else if (!c->nodest)
      return d;
   
   return "";
}

mapping query_container_callers()
{
  return ([ "sed" : tag_sed ]);
}

