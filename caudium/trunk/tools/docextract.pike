/* $Id$ */

/* Documentation extract program. Based on mkwmml.pike from Pike by Mirar.
 * Extracts inline documentation comments into an XML format (to be defined).
 */

import Stdio;
import Array;

mapping parse=([]);
int illustration_counter;

mapping manpage_suffix=
([
   "Image":"i",
   "Image.image":"i",
]);


function verbose=werror;

#define error(X) throw( ({ (X), backtrace()[0..sizeof(backtrace())-2] }) )

/*

module : mapping <- moduleM
	"desc" : text
	"cvs_version": text
	"see also" : array of references 
	"note" : mapping of "desc": text
	"modules" : same as classes (below)
	"classes" : mapping 
		class : mapping <- classM
	        	"see also" : array of references
			"scope": text
			"desc" : text
			"note" : mapping of "desc": text
			"methods" : array of mappings <- methodM
				"decl" : array of textlines of declarations
				"desc" : text
				"scope": text
				"returns" : textline
				"see also" : array of references 
				"note" : mapping of "desc": text
				"known bugs" : mapping of "desc": text
				"args" : array of mappings <- argM
					"args" : array of args names and types
					"desc" : description
				"names" : multiset of method name(s) 
file : mapping <- moduleM
	"desc" : text
	"cvs_version": text
	"note" : mapping of "desc": text
	"type": text (module type)
	"tags" : mapping 
		tag : mapping <- tagM
	        	"see also" : array of references
			"desc" : text
			"note" : mapping of "desc": text
			"syntax" : text (syntax)
			"returns" : textline
			"known bugs" : mapping of "desc": text
			"attributes" : array of attributes <- argM
				"args" : array of args names and types
				"desc" : description

Quoting: Only '<' must be quoted as '&lt;'.

*/

mapping moduleM, classM, methodM, argM, nowM, descM, tagM;
mapping focM(mapping dest,string name,string line)
{
   if (!dest->_order) dest->_order=({});
   if (-1==search(dest->_order,name)) dest->_order+=({name});
   return dest[name] || (dest[name]=(["_line":line]));
}

string stripws(string s)
{
   return desc_stripws(s);
}

string desc_stripws(string s)
{
   if (s=="") return s;
   array lines = s / "\n";
   int m=10000;
   foreach (lines,string s)
      if (s!="")
      {
	 sscanf(s,"%[ ]%s",string a,string b);
	 if (b!="") m=min(strlen(a),m);
      }
   return map(lines,lambda(string s) { return s[m..]; })*"\n";
}

mapping lower_nowM()
{
   if (nowM && 
       (nowM==parse
	|| nowM==classM
	|| nowM==methodM
	|| nowM==moduleM
	|| nowM==tagM)) return nowM;
   else return nowM=methodM;
}

void report(string s)
{
   verbose("extract:   "+s+"\n");
}

#define complain(X) (X)

mapping keywords=
([
  "module":lambda(string arg,string line) 
	   { classM=descM=nowM=moduleM=focM(parse,stripws(arg),line); 
	   methodM=0; 
	   if (!nowM->classes) nowM->classes=(["_order":({})]); 
	   if (!nowM->modules) nowM->modules=(["_order":({})]);
	   if (!nowM->tags) nowM->tags=(["_order":({})]); 
	   moduleM->_type = "module";
	   report("module "+arg); },
  "file":lambda(string arg,string line) 
	 { classM=descM=nowM=moduleM=focM(parse,stripws(arg),line); 
	 methodM=0; 
	 if (!nowM->classes) nowM->classes=(["_order":({})]); 
	 if (!nowM->modules) nowM->modules=(["_order":({})]); 
	 moduleM->_type = "file";
	 report("file "+arg); },
  "class":lambda(string arg,string line) 
	  { if (!moduleM) return complain("class w/o module");
	  descM=nowM=classM=focM(moduleM->classes,stripws(arg),line); 
	  methodM=0; report("class "+arg); },
  "tag":lambda(string arg,string line) 
	{ if (!moduleM || !moduleM->tags)
	  return complain("tag w/o module");
	descM = nowM = tagM = focM(moduleM->tags,"<"+stripws(arg)+">",line); 
	methodM=0; report("container "+arg); },
  "container":lambda(string arg,string line) 
	      { if (!moduleM || !moduleM->tags) 
		return complain("container w/o module");
	      arg = stripws(arg);
	      descM = nowM = tagM = focM(moduleM->tags,"<"+arg+">"+"</"+arg+">",line); 
	      methodM=0; report("tag "+arg); },
  "submodule":lambda(string arg,string line) 
	      { if (!moduleM) return complain("submodule w/o module");
	      classM=descM=nowM=moduleM=focM(moduleM->modules,stripws(arg),line);
	      methodM=0;
	      if (!nowM->classes) nowM->classes=(["_order":({})]); 
	      if (!nowM->modules) nowM->modules=(["_order":({})]); 
	      report("submodule "+arg); },
  "method":lambda(string arg,string line)
	   { if (!classM) return complain("method w/o class");
	   if (!nowM || methodM!=nowM || methodM->desc || methodM->args || descM==methodM) 
	   { if (!classM->methods) classM->methods=({});
	   classM->methods+=({methodM=nowM=(["decl":({}),"_line":line])}); }
	   methodM->decl+=({stripws(arg)}); descM=0; },
  "inherits":lambda(string arg,string line)
	     { if (!nowM) return complain("inherits w/o class or module");
	     if (nowM != classM) return complain("inherits outside class or module");
	     if (!classM->inherits) classM->inherits=({});
	     classM->inherits+=({stripws(arg)}); },

  "variable":lambda(string arg,string line)
	     {
	       if (!classM) return complain("variable w/o class");
	       if (!classM->variables) classM->variables=({});
	       classM->variables+=({descM=nowM=(["_line":line])}); 
	       nowM->decl=stripws(arg); 
	     },
  "constant":lambda(string arg,string line)
	     {
	       if (!classM) return complain("constant w/o class");
	       if (!classM->constants) classM->constants=({});
	       classM->constants+=({descM=nowM=(["_line":line])}); 
	       nowM->decl=stripws(arg); 
	     },

  "arg":lambda(string arg,string line)
	{
	  if (!methodM) return complain("arg w/o method");
	  if (!methodM->args) methodM->args=({});
	  methodM->args+=({argM=nowM=(["args":({}),"_line":line])}); 
	  argM->args+=({arg}); descM=argM;
	},
  "attribute":lambda(string arg,string line)
	{
	  if (!tagM) return complain("attribute w/o tag or container");
	  if (!tagM->attributes) tagM->attributes=({});
	  tagM->attributes+=({argM=(["args":({}),"_line":line])}); 
	  argM->args+=({arg}); descM=argM;
	},
  "default":lambda(string arg,string line)
	{
	  if (!argM) return complain("default w/o attribute");
	  argM->default = stripws(arg);
	},
  "name":lambda(string arg,string line)
	 {
	   if (!methodM) return complain("name w/o method");
	   nowM = methodM->shortdesc = methodM->shortdesc||(methodM->shortdesk=(["_line":line]));
	   nowM->shortdesc  = arg;
	 },
  "note":lambda(string arg,string line)
	 {
	   if (!lower_nowM()) 
	     return complain("note w/o method, class or module");
	   descM=nowM->note||(nowM->note=(["_line":line]));
	 },
  "cvs_version":lambda(string arg,string line)
		{
		  if (!moduleM) 
		    return complain("cvs_version w/o file or module");
		  moduleM->cvs_version = arg;
		},
  "type":lambda(string arg,string line)
	 {
	   if (!moduleM) 
	     return complain("type w/o module");
	   moduleM -> type = ((arg  - " ")/ "|" - ({""}))*"&nbsp;|&nbsp;";
	   descM=0; nowM=0;	   
	 },
  "added":lambda(string arg,string line)
	  {
	    if (!lower_nowM()) 
	      return complain("added in: w/o method, class or module");
	    descM=nowM->added||(nowM->added=(["_line":line]));
	  },
  "bugs":lambda(string arg,string line)
	 {
	   if (!lower_nowM()) 
	     return complain("bugs w/o method, class or module");
	   descM=nowM->bugs||(nowM->bugs=(["_line":line]));
	   descM->desc = arg;
	 },
  "fixme":lambda(string arg,string line)
	  {
	    if (!lower_nowM()) 
	      return complain("fixme w/o method, class or module");
	    descM=nowM->bugs||(nowM->bugs=(["_line":line]));
	  },
  "see":lambda(string arg,string line)
	{
	  if (arg[0..3]!="also")
	    return complain("see w/o 'also:'\n");
	  if (!lower_nowM()) 
	    return complain("see also w/o method, class or module");
	  sscanf(arg,"also%*[:]%s",arg);
	  nowM["see also"]=map(arg/",",stripws)-({""});
	  if (!nowM["see also"])
	    return complain("empty see also\n");
	},
  "returns":lambda(string arg, string line)
	    {
	      if (!methodM) 
	        return complain("returns w/o method");
	      nowM = descM=methodM->returns||(methodM->returns=(["_line":line]));
	    },
  "scope":lambda(string arg)
	  {
	    if (!(nowM = methodM || classM)) 
	      return complain("returns w/o method");
	    nowM->scope=stripws(arg);
	    descM=0; nowM=0;
	  }

]);

string getridoftabs(string s)
{
   string res="";
   while (sscanf(s,"%s\t%s",string a,s)==2)
   {
      res+=a;
      res+="         "[(strlen(res)%8)..7];
   }
   return res+s;
}


object(File) make_file(string filename)
{
   stderr->write("creating "+filename+"...\n");
   if (file_size(filename)>0)
   {
      rm(filename+"~");
      mv(filename,filename+"~");
   }
   object f=File();
   if (!f->open(filename,"wtc"))
   {
      stderr->write("failed.");
      exit(1);
   }
   return f;
}

string synopsis_to_html(string s,mapping huh)
{
   string type,name,arg;
   s=replace(s,({"<",">"}),({"&lt;","&gt;"}));
   if (sscanf(s,"%s%*[ \t]%s(%s",type,name,arg)!=4)
   {
      sscanf(s,"%s(%s",name,arg),type="";
      werror(sprintf(huh->_line+": suspicios method %O\n",(s/"(")[0]));
   }
   if (arg[..1]==")(") name+="()",arg=arg[2..];

   if (!arg) arg="";

   return 
      type+" <b>"+name+"</b>("+
      replace(arg,({","," "}),({", ","\240"}));
}

string htmlify(string s) 
{
#define HTMLIFY(S) \
   (replace((S),({"&lt;","&gt;",">","&","\240"}),({"&lt;","&gt;","&gt;","&amp;","&nbsp;"})))

   string t="",u,v;
   while (sscanf(s,"%s<%s>%s",u,v,s)==3)
      t+=HTMLIFY(u)+"<"+v+">";
   return t+HTMLIFY(s);
}

#define linkify(S) \
   ("\""+replace((S),({"->","()","&lt;","&gt;"}),({".","","<",">"}))+"\"")

string make_nice_reference(string what,string prefix,string stuff)
{
   string q;
   if (what==prefix[strlen(prefix)-strlen(what)-2..strlen(prefix)-3])
   {
      q=prefix[0..strlen(prefix)-3];
   }
   else if (what==prefix[strlen(prefix)-strlen(what)-1..strlen(prefix)-2])
   {
      q=prefix[0..strlen(prefix)-2];
   }
   else if (search(what,".")==-1 &&
	    search(what,"->")==-1 &&
	    !parse[what])
   {
      q=prefix+what;
   }
   else 
      q=what;

   return "<link to="+linkify(q)+">"+htmlify(stuff)+"</link>";
}

string fixdesc(string s,string prefix,string where)
{
  if(!s) {
    report("null desc: "+where);
    return "";
  }
  s=desc_stripws(s);
  
   string t,u,v,q;

   t=s; s="";
   while (sscanf(t,"%s<ref%s>%s</ref>%s",t,q,u,v)==4)
   {
      if (search(u,"<ref")!=-1)
      {
	 werror("warning: unclosed <ref>\n%O\n",s);
	 u=replace(u,"<ref","&lt;ref");
      }
      
      if (sscanf(q," to=%s",q))
	 s+=htmlify(t)+make_nice_reference(q,prefix,u);
      else
	 s+=htmlify(t)+make_nice_reference(u,prefix,u);
      t=v;
   }
   if (search(s,"<ref")!=-1)
   {
      werror("%O\n",s);
      error("buu\n");
   }

   s+=htmlify(t);

   t=s; s="";
   for (;;)
   {
      string a,b,c;
      if (sscanf(t,"%s<%s>%s",a,b,c)<3) break;
      
      if (b[..2]=="pre" &&
	  sscanf(t,"%s<pre%s>%s</pre>%s",t,q,u,v)==4)
      {
	 s+=replace(t,"\n\n","\n\n<p>")+
	   "<pre"+q+">\n"+u+"</pre>";
	 t=v;
      }
      else
      {
	s+=replace(a,"\n\n","\n\n<p>")+"<"+b+">";
	 t=c;
      }
   }
   s+=replace(t,"\n\n","\n\n<p>");

   return s;
}


multiset(string) get_method_names(string *decls)
{
   string decl,name;
   multiset(string) names=(<>);
   foreach (decls,decl)
   {
      sscanf(decl,"%*s%*[\t ]%s%*[\t (]%*s",name);
      names[name]=1;
   }
   return names;
}

string *nice_order(string *arr)
{
   sort(map(arr,replace,({"_","`"}),({"ÿ","þ"})),
	arr);
   return arr;
}

string addprefix(string suffix,string prefix)
{
   return prefix+suffix;
}

array fix_dotstuff(array(string) in)
{
   if (!sizeof(in)) return ({});
   array(string) last;
   in=Array.map(in,replace,({"->",">","<"}),({".","&lt;","&gt;"}));
   last=in[0]/"."; 
   last=last[..sizeof(last)-2];
   int i;
   array res=in[..0];
   for (i=1; i<sizeof(in); i++)
   {
      array(string) z=in[i]/".";
      if (equal(z[..sizeof(z)-2],last))
	 res+=({"."+z[-1]});
      else
      {
	 last=z[..sizeof(z)-2];
	 res+=in[i..i];
      }
   }
   return res;
}

void document(string enttype,
	      mapping huh,string name,string prefix,
	      object f)
{
   string *names;
   if (huh->names)
      names=map(indices(huh->names),addprefix,name);
   else
      names=({name});

   verbose("extract: "+name+" : "+names*","+"\n");

   f->write("\n"  "<!-- " + huh->_line + " -->\n");
   f->write( "<"+enttype+" name=\""+
	     fix_dotstuff(names)*",");

   if (manpage_suffix[replace(name,"->",".")])
      f->write(" mansuffix="+manpage_suffix[replace(name,"->",".")]);

   f->write("\">\n");

// [SHORTDESC]

   if (huh->shortdesc)
   {
      f->write( "<short>\n");
      f->write(huh->shortdesc->shortdesc);
      f->write("\n"  "</short>\n\n");
   }

// [SYNTAX]

   if (huh->decl)
   {
      f->write( "<syntax>\n");

      if (enttype=="function" ||
	  enttype=="method")
	 f->write(replace(htmlify(map(huh->decl,synopsis_to_html,huh)*
				  "<br>\n"),"\n","\n\t")+"\n");
      else
	 f->write(huh->decl);

      f->write( "</syntax>\n\n");
   }


// [DESCRIPTION]

   if (huh->desc)
   {
      f->write( "<description>\n");

      if (huh->inherits)
      {
	 string s="";
	 foreach (huh->inherits,string what)
	    f->write("inherits "+make_nice_reference(what,prefix,what)+
		     "<br>\n");
	 f->write("<br>\n");
      }

      f->write(fixdesc(huh->desc,prefix,huh->_line)+"\n");
      f->write( "</description>\n\n");
   }

// [ARGUMENTS | ATTRIBUTES] 

   if (huh->args || huh->attributes)
   {
      string rarg="";
      string nam, nam2;
      if(huh->args) {
	nam  = "argument";
	nam2 = "syntax";
      } else {
	nam = "attribute";
	nam2 = "name";
      }
      f->write("<"+nam+"s>\n");
      mapping arg;
      foreach (huh->args || huh->attributes, arg)
      {
	 if (arg->desc)
	 {
	    f->write("\t<"+nam+">\n"
		     +fixdesc(rarg+"\t\t<"+nam2+">"
			      +arg->args*("</"+nam2+">\n\t\t<"+nam2+">")
			      +"</"+nam2+">",prefix,arg->_line)
		     +"\n\t\t<description>"
		     +stripws(fixdesc(arg->desc,prefix,arg->_line))
		     +"</description>\n");
	    if(arg->default)
	      f->write("\t\t<default>"+arg->default+"</default>\n");
	    f->write("\t</"+nam+">\n\n");
	    rarg="";
	 }
	 else
	 {
	    rarg+="\t\t<"+nam2+">"
	       +arg->args*("</"+nam2+">\n\t\t<"+nam2+">")+
	       "</aarg>\n";
	    if(arg->default)
	      f->write("\t\t<default>"+arg->default+"</default>\n");
	 }
      }
      if (rarg!="") error("trailing args w/o desc on "+arg->_line+"\n");

      f->write("</"+nam+"s>\n");
   }


// [RETURN VALUE]

   if (huh->returns)
   {
     f->write("<returns>\n");
     f->write(fixdesc(huh->returns->desc,prefix,huh->returns->_line)+"\n");
     f->write("</returns>\n\n");
   }

// [SCOPE]

   if (huh->scope)
   {
     f->write("<scope>"+huh->scope+"</scope>\n");
   }


// [NOTE]

   if (huh->note && huh->note->desc)
   {
      f->write("<note>\n");
      f->write(fixdesc(huh->note->desc,prefix,huh->_line)+"\n");
      f->write("</note>\n\n");
   }

// [CVS_VERSION]

   if (huh->cvs_version)
   {
      f->write("<version>\n");
      f->write(fixdesc(huh->cvs_version,prefix,huh->_line)+"\n");
      f->write("</version>\n\n");
   }

// [TYPE]

   if (huh->type)
   {
      f->write("<type>");
      f->write(fixdesc(huh->type,prefix,huh->_line));
      f->write("</type>\n\n");
   }
   
// [BUGS]

   if (huh->bugs && huh->bugs->desc)
   {
      f->write("<bugs>\n");
      f->write(fixdesc(huh->bugs->desc,prefix,huh->_line)+"\n");
      f->write("</bugs>\n\n");
   }

// [ADDED]

   if (huh->added && huh->added->desc)
   {
      /* noop */
   }

// [SEE ALSO]

   if (huh["see also"])
   {
      f->write("<see>\n");
      f->write(htmlify(huh["see also"]*", "));
      f->write("</see>\n\n");
   }

// ---childs----

   if (huh->constants)
   {
      foreach(huh->constants,mapping m)
      {
	 sscanf(m->decl,"%s %s",string type,string name);
	 sscanf(name,"%s=%s",name,string value);
	 document("constant",m,prefix+name,prefix+name+".",f);
      }
   }

   if (huh->variables)
   {
      foreach(huh->variables,mapping m)
      {
	 sscanf(m->decl,"%s %s",string type,string name);
	 if (!name) name=m->decl,type="mixed";
	 sscanf(name,"%s=%s",name,string value);
	 document("variable",m,prefix+name,prefix+name+".",f);
      }
   }

   if (huh->methods)
   {
      // postprocess methods to get names

      multiset(string) method_names=(<>);
      string *method_names_arr,method_name;
      mapping method;

      if (huh->methods) 
	 foreach (huh->methods,method)
	    method_names|=(method->names=get_method_names(method->decl));

       method_names_arr=nice_order(indices(method_names));

      // alphabetically

      foreach (method_names_arr,method_name)
	 if (method_names[method_name])
	 {
	    // find it
	    foreach (huh->methods,method)
	       if ( method->names[method_name] )
	       {
		  document("method",method,prefix,prefix,f);
		  method_names-=method->names;
	       }
	    if (method_names[method_name])
	       stderr->write("failed to find "+method_name+" again, wierd...\n");
	 }
   }

   if (huh->classes)
   {
      foreach(huh->classes->_order,string n)
      {
	 f->write("\n\n\n<section title=\""+prefix+n+"\">\n");
	 document("class",huh->classes[n],
		  prefix+n,prefix+n+"->",f);
	 f->write("</section title=\""+prefix+n+"\">\n");
      }
   }
   if (huh->tags)
   {
     foreach(huh->tags->_order,string n)
     {
       document("tag",huh->tags[n],
		n,prefix+n+"->",f);
     }
   }

   if (huh->modules)
   {
      foreach(huh->modules->_order,string n)
      {
	 f->write("\n\n\n<section title=\""+prefix+n+"\">\n");
	 document("module",huh->modules[n],
		  prefix+n,prefix+n+".",f);
	 f->write("</section title=\""+prefix+n+"\">\n");
      }
   }
// end ANCHOR

   f->write("</"+enttype+"> <!-- end of "+ (fix_dotstuff(names)*",") +" -->\n");
}

void make_doc_files()
{
   stderr->write("modules: "+sort(indices(parse) - ({ "_order"}))*", "+"\n");
   
   foreach (sort(indices(parse)-({"_order"})),string module) {
     stdout->write("<documentation>\n\n");
     document(parse[module]->_type,parse[module],module,module+".",stdout);
     stdout->write("\n</documentation>\n\n");
   }
}

int main(int ac,string *files)
{
   string s,t;
   int line;
   string *ss=({""});
   object f;

   string currentfile;

   nowM=parse;

   stderr->write("reading and parsing data...\n");

   files=files[1..];

   if (sizeof(files) && files[0]=="--nonverbose") 
      files=files[1..],verbose=lambda(){};

   stderr->write("extract: reading files...\n");

   for (;;)
   {
      int i;
      int inpre=0;

      if (!f) 
      {
	 if (!sizeof(files)) break;
	 verbose("extract: reading "+files[0]+"...\n");
	 f=File();
	 currentfile=files[0];
	 files=files[1..];
	 if (!f->open(currentfile,"r")) { f=0; continue; }
	 t=0;
	 ss=({""});
	 line=0;
      }

      if (sizeof(ss)<2)
      {
	 if (t=="") { f=0; continue; }
	 t=f->read(8192);
	 if (!t) 
	 {
	    werror("extract: failed to read %O\n",currentfile);
	    f=0;
	    continue;
	 }
	 s=ss[0];
	 ss=t/"\n";
	 ss[0]=s+ss[0];
      }
      s=ss[0]; ss=ss[1..];

      s=getridoftabs(s);

      line++;
      if ((i=search(s,"**!"))!=-1 || (i=search(s,"//!"))!=-1)
      {
	 string kw,arg;

	 sscanf(s[i+3..],"%*[ \t]%[^: \t\n\r]%*[: \t]%s",kw,arg);
	 if (keywords[kw])
	 {
	    string err;
	    if ( (err=keywords[kw](arg,currentfile+" line "+line)) )
	    {
	       stderr->write("extract: "+
			     currentfile+" line "+line+": "+err+"\n");
	       return 1;
	    }
	    inpre=0;
	 }
	 else if (s[i+3..]!="")
	 {
	    string d=s[i+3..];
//  	    sscanf(d,"%*[ \t]!%s",d);
//	    if (search(s,"$Id")!=-1) report("Id: "+d);
	    if (!descM) descM=methodM;
	    if (!descM)
	    {
	       stderr->write("extract: "+
			     currentfile+" line "+line+
			     ": illegal description position\n");
	       stderr->write("extract: "+
			     currentfile+" line "+line+
			     ": Missing module or file statement?\n");
	       f = 0;
	       moduleM = classM = methodM = argM = nowM = descM = tagM = 0;
	       continue;
	    }
	    if (!descM->desc) descM->desc="";
	    else descM->desc+="\n";
	    d=getridoftabs(d);
	    descM->desc+=d;
	 }
      }
   }

//   stderr->write(sprintf("%O",parse));

   stderr->write("extract: making docs...\n\n");

   make_doc_files();

   return 0;
}
