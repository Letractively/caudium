/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000 The Caudium Group
 * Copyright � 1994-2000 Roxen Internet Software
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
 *
 * Incremental Pike evaluator, modified to work within Roxen
 */

#include <simulate.h>
#include <stdio.h>
import Array;
#include <string.h>
#include <getopt.h>

/* todo:
 *  return (void)1; will give me problems.
 *  strstr(string,string *) -> return first occurance of first string...
 *  inherit doesn't work
 *  preprocessor stuff
 */

#!define catch(X) ((X),0)

#pragma all_inline

/* #define HILFE_DEBUG */

object p;

mapping variables=([]);
string *functions=({});
string *function_names=({});
mapping query_variables() { return variables; }
/* do nothing */

void my_write(mixed x)
{
  write(sprintf("%O",x));
}


object eval(string f)
{
  string prog,file;
  object o;
  mixed err;
  prog=("#pragma unpragma_strict_types\n#pragma all_inline\n"+
	"static mapping ___variables=___hilfe->query_variables();\n"+
	map(indices(variables),lambda(string f)
	    { return sprintf("mixed %s=___variables[\"%s\"];",f,f); })*"\n"+
	"\nmapping query_variables() { return ([\n"+
        map(indices(variables),lambda(string f)
            { return sprintf("    \"%s\":%s,",f,f); })*"\n"+
	    "\n  ]);\n}\n"+
        functions*"\n"+"\n"+ f+"\n");

#ifdef HILFE_DEBUG
  write("program:"+prog);
#endif
  program p;
  if(err=catch(p=compile_string(prog)))
  {
#ifdef HILFE_DEBUG
    write(describe_backtrace(err));
    write("Couldn't compile expression.\n");
#endif
    return 0;
  }
  if(err=catch(o=clone(p)))
  {
    write(describe_backtrace(err));
    return 0;
  }
  return o;
}

mixed do_evaluate(string a, int show_result)
{
  mixed foo, c;
  if(foo=eval(a))
  {
    if(c=catch(a=sprintf("%O",foo->___Foo4711())))
    {
      if(arrayp(c) && sizeof(c)==2 && arrayp(c[1]))
      {
	c[1]=c[1][sizeof(backtrace())..];
	write(describe_backtrace(c));
      }else{
	write(sprintf("Error in evalutation: %O\n",c));
      }
    }else{
      if(show_result)
	write("Result: "+a+"\n");
      else
	write("Ok.\n");
      variables=foo->query_variables();
    }
  }
}

string input="";

string skipwhite(string f)
{
  while(sscanf(f,"%*[ \r\n\t]%s",f) && sscanf(f,"/*%*s*/%s",f));
  return f;
}

int find_next_comma(string s)
{
  int e, p, q;

  for(e=0;e<strlen(s);e++)
  {
    switch(s[e])
    {
    case '"':
      for(e++;s[e]!='"';e++)
      {
        switch(s[e])
        {
	case 0: return 0;
	case '\\': e++; break;
        }
      }
      break;

    case '{':
    case '(':
    case '[':
      p++;
      break;

    case ',':
      if(!p) return e;
      break;

    case '/':
      if(s[e+1]=='*')
	while(s[e-1..e]!="*/" && e<strlen(s)) e++;
      break;

    case '}':
    case ')':
    case ']':
      p--;
      if(p<0)
      {
	write("Syntax errror.\n");
	input="";
	return 0;
      }
      break;

    }
  }
  return 0;
}

string *get_name(string f)
{
  int e,d;
  string rest;
  
  f=skipwhite(f);
  if(sscanf(f,"*%s",f)) f=skipwhite(f);
  sscanf(f,"%[a-zA-Z0-9_]%s",f,rest);
  rest=skipwhite(rest);
  return ({f,rest});
}

string first_word=0;
int pos=0;
int parenthese_level=0;
int in_comment=0;
int in_string=0;
int in_quote=0;
int eq_pos=-1;
int do_parse();
mixed parse_function(string s);
mixed parse_statement(string s);

int set_buffer(string s,int parsing)
{
  input=s;
  first_word=0;
  pos=-1;
  parenthese_level=0;
  in_comment=0;
  in_quote=0;
  in_string=0;
  eq_pos=-1;
  if(!parsing) return do_parse()==1;
}

int clean_buffer() { return set_buffer("",0);  }

int add_buffer(string s)
{
  input+=s;
  if(do_parse()==1)
    return 1;
  input=skipwhite(input);
  return 0;
}

void cut_buffer(int where)
{
  int old,new;
  old=strlen(input);
  input=skipwhite(input[where..old-1]);
  new=strlen(input);
  if(where>1) first_word=0;
  pos-=old-new; if(pos<0) pos=0;
  eq_pos-=old-new; if(eq_pos<0) eq_pos=-1;
#ifdef HILFE_DEBUG
  write("CUT input = "+my_write(input)+"  pos="+pos+"\n");
#endif
}

void print_version()
{
  write(version()+
	" running Hilfe v1.6 (Incremental Pike Frontend)\n");
}


int do_parse()
{
  string tmp;
  if(pos<0) pos=0;
  for(;pos<strlen(input);pos++)
  {
    if(in_quote) { in_quote=0; continue; }
//    trace(99);
    if(!first_word)
    {
      int d;
      if(!strlen(input) && pos)
      {
	werror("Error in optimizer.\n");
	exit(1);
      }

      d=input[pos];
      if(d==' ' && !pos)
      {
	cut_buffer(1);
	continue;
      }
      if((d<'a' || d>'z') && (d<'A' || d>'Z') && (d<'0' || d>'9') && d!='_')
      {
	first_word=input[0..pos-1];
#ifdef HILFE_DEBUG
	write("First = "+my_write(first_word)+"  pos="+pos+"\n");
	write("input = "+my_write(input)+"\n");
#endif
	switch(first_word)
	{
	case "quit":
	  write("Exiting.\n");
	  return 1;
	case ".":
	  if(clean_buffer())
	    return 1;
	  
	  write("Input buffer flushed.\n");
	  continue;

	case "new":
	  this_object()->__INIT();
	  continue;

	case "dump":
	  sum_arrays(lambda(string var,mixed foo)
		   {
		     write(sprintf("%-15s:%s\n",var,sprintf("%O",foo)));
		   },
		     indices(variables),
		     values(variables));
	  cut_buffer(4);
	  continue;

	case "help":
	  print_version();
	  write("Hilfe is a tool to evaluate Pike interactively and incrementally.\n"
		"Any Pike function, expression or variable declaration can be entered\n"
		"at the command line. There are also a few extra commands:\n"
		" help       - show this text\n"
		" quit       - exit this program\n"
		" .          - abort current input batch\n"
		" dump       - dump variables\n"
		" new        - clear all function and variables\n"
		"See the Pike reference manual for more information.\n"
		);
	  cut_buffer(4);
	  continue;
	  
	}
      }
    }

    switch(input[pos])
    {
    case '\\':
      in_quote=1;
      break;
	
    case '=':
      if(in_string || in_comment  || parenthese_level || eq_pos!=-1) break;
      eq_pos=pos;
      break;
      
    case '"':
      if(in_comment) break;
      in_string=!in_string;
      break;

    case '{':
    case '(':
    case '[':
      if(in_string || in_comment) break;
      parenthese_level++;
      break;

    case '}':
    case ')':
    case ']':
      if(in_string || in_comment) break;
      if(--parenthese_level<0)
      {
	write("Syntax error.\n");
	if(clean_buffer())
	  return 1;
	return 0;
      }
      if(!parenthese_level && input[pos]=='}')
      {
	if(tmp=parse_function(input[0..pos]))
	{
	  cut_buffer(pos+1);
	  if(stringp(tmp))
	    if(set_buffer(tmp+input,1))
	      return 1;
	}
      }
      break;

    case ';':
      if(in_string || in_comment || parenthese_level) break;
      if(tmp=parse_statement(input[0..pos]))
      {
	cut_buffer(pos+1);
	if(stringp(tmp))
	  if(set_buffer(tmp+input,1))
	    return 1;
      }
      break;
      
    case '*':
      if(in_string || in_comment) break;
      if(input[pos-1]=='/') in_comment=1;
      break;

    case '/':
      if(in_string) break;
      if(input[pos-1]=='*') in_comment=0;
      break;
    }
  }
  if(pos>strlen(input)) pos=strlen(input);
  return -1;
}


mixed parse_function(string fun)
{
  string name,a,b;
  object foo;
  mixed c;
#ifdef HILFE_DEBUG
  write("Parsing block ("+first_word+")\n");
#endif

  switch(first_word)
  {
  case "if":
  case "for":
  case "do":
  case "while":
  case "foreach":
    /* parse loop */
    do_evaluate("mixed ___Foo4711() { "+fun+" ; }\n",0);
    return 1;

  case "int":
  case "void":
  case "object":
  case "array":
  case "mapping":
  case "string":
  case "multiset":
  case "float":
  case "mixed":
  case "program":
  case "function":
  case "class":
    /* parse function */
    if(eq_pos!=-1) break;  /* it's a variable */
    sscanf(fun,first_word+"%s",name);

    c=get_name(name);
    name=c[0];
    c=c[1];

    int i;
    if((i=member_array(name,function_names))!=-1)
    {
      b=functions[i];
      functions[i]=fun;
      if(!eval(""))  functions[i]=b;
    }else{
      if(eval(fun))
      {
	functions+=({fun});
	function_names+=({name});
      }
    }
    return 1;
  }
}

mixed parse_statement(string ex)
{
  string a,b,name;
  mixed c;
  object foo;
  int e;
#ifdef HILFE_DEBUG
  write("Parsing statement ("+first_word+")\n");
#endif
  switch(first_word)
  {
  case "if":
  case "for":
  case "do":
  case "while":
  case "foreach":
    /* parse loop */
    do_evaluate("mixed ___Foo4711() { "+ex+" ; }\n",0);
    return 1;

  case "int":
  case "void":
  case "object":
  case "array":
  case "mapping":
  case "string":
  case "multiset":
  case "float":
  case "mixed":
  case "program":
  case "function":
    /* parse variable def. */
    sscanf(ex,first_word+"%s",b);
    b=skipwhite(b);
    c=get_name(b);
    name=c[0];
    c=c[1];

#ifdef HILFE_DEBUG
    write("Variable def.\n");
#endif
    if(name=="") 
    {
      return 1;
    }else{
      string f;
      variables[name]=0;

      if(sscanf(c,"=%s",c))
      {
#ifdef HILFE_DEBUG
	write("Variable def. with assign. ("+name+")\n");
#endif
	if(e=find_next_comma(c))
	{
	  return name+"="+c[0..e-1]+";\n"+
	    first_word+" "+c[e+1..strlen(c)-1];
	}else{
	  return name+"="+c;
	}
#ifdef HILFE_DEBUG
	write("Input buffer = '"+input+"'\n");
#endif

      }else{
	sscanf(c,",%s",c);
	return first_word+" "+c;
      }
    }
    
    return 1;

  default:
    if(ex==";") return 1;
    /* parse expressions */
    do_evaluate("mixed ___Foo4711() { return (mixed)("+ex[0..strlen(ex)-2]+"); }\n",1);
    return 1;
  }
}

int stdin(string s)
{
  string *tmp,a,b,c,f,name;
  int e,d;
  object foo;

#ifdef HILFE_DEBUG
  write("input: '"+my_write(s)+"'\n");
#endif
  s=skipwhite(s);

  if(s[0..1]==".\n")
  {
    if(clean_buffer())
      return 1;
    write("Input buffer flushed.\n");
    s=s[2..strlen(s)-1];
  }
  if(add_buffer(s))
    return 1;
  else return 0;
//  if(!strlen(input))  write("> ");
}

void signal_trap(int s)
{

  clean_buffer();
  throw("**Break\n");
}

void main(object _p, object id)
{
  p=_p;
  string s;
  print_version();
  add_efun("write",my_write);
  add_efun("p",p);
  add_efun("id",id);
  add_efun("___hilfe",this_object());

  while(s=readline(strlen(input) ? ">> " : "> "))
  {
//     signal(signum("SIGINT"),signal_trap);
    if(stdin(s+"\n"))
      return;
//     signal(signum("SIGINT"));
  }
  write("Terminal closed.\n");
  return;
}

