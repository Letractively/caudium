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

/*
 * Caudium master, replacing the default Pike master.
 */

string cvs_version = "$Id$";

/*
 * name = "Caudium Master";
 * doc = "Caudium's customized master object.";
 */

mapping names=([]);
int unique_id=time();

object mm = (object)"/master";

inherit "/master": old_master;



string program_name(program p)
{
//werror(sprintf("Program name %O = %O\n", p, search(programs,p)));
  return search(programs, p);
}

mapping saved_names = ([]);
 
void name_program(program foo, string name)
{
  programs[name] = foo;
  saved_names[foo] = name;
  saved_names[(program)foo] = name;
}

private static int mid = 0;

mapping _vars = ([]);
array persistent_variables(program p, object o)
{
  if(_vars[p]) return _vars[p];

  mixed b;
  array res = ({});
  foreach(indices(o), string a)
  {
    b=o[a];
    if(!catch { o[a]=b; } ) // It can be assigned. Its a variable!
      res += ({ a });
  }
  return _vars[p]=res;
}

array|string low_nameof(object|program|function fo)
{
  //fo might be of several types, so DON'T return if one search failes.
  if(objectp(fo))
    if(mixed x=search(objects,fo)) return x;

  if(programp(fo))
    if(mixed x=search(programs,fo)) return x;
  string p,post="";
  object foo ;

  if(functionp(fo))
  {
    mixed a;
    post = sprintf("%O", function_object( fo ));
    //    werror("%O\n", objects);
    if(a = search(objects, function_object( fo ))) 
      return ({ a[0], a[1], post });
  } else
    foo = fo;
  
  if(p=search(programs, object_program(foo)))
    return ({ p, (functionp(foo->name)?foo->name():
		  (stringp(foo->name)?foo->name:time(1)+":"+mid++)),post})-({"",0});
#ifdef DEBUG		  
  throw(({"nameof: unknown thingie.\n",backtrace()}));
#else
  return 0;
#endif
}

array|string nameof(mixed foo)
{
  // werror(sprintf("Nameof %O...\m", foo));
  return saved_names[foo] ||  (saved_names[foo] = low_nameof( foo ));
}

program programof(string foo)
{
  return saved_names[foo] || programs[foo] || (program) foo ;
}

object objectof(array foo)
{
  object o;
  program p;

  array err;
  
  if(!arrayp(foo)) return 0;
  
  if(saved_names[foo[0..1]*"\0"]) return saved_names[foo[0..1]*"\0"];

  if(!(p = programof(foo[0]))) {
    werror("objectof(): Failed to restore object (programof("+foo[0]+
	   ") failed).\n");
    return 0;
  }
  err = catch {
    o = p();
    
    saved_names[ foo[0..1]*"\0" ] = o;

    saved_names[ o ] = foo;
    o->persist && o->persist( foo );
    return o;
  };
  werror("objectof(): Failed to restore object"
	 " from existing program "+foo*"/"+"\n"+
	 describe_backtrace( err ));
  return 0;
}

function functionof(array f)
{
  object o;
//  werror(sprintf("Functionof %O\n", f));
  if(!arrayp(f) || sizeof(f) != 3)
  return 0;
  o = objectof( f[..1] );
  if(!o)
  {
    werror("functionof(): objectof() failed.\n");
    return 0;
  }
  if(!functionp(o[f[-1]]))
  {
    werror("functionof(): "+f*"."+" is not a function.\n");
    destruct(o);
    return 0;
  }
  return o[f[-1]];
}

void create()
{
  object o = this_object();
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(o[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }
  programs["/master"] = object_program(o);
  objects[object_program(o)] = o;
  /* make ourselves known */
  add_constant("_master",o);

  /* Move the old efuns to the new object. */
  if (o->master_efuns) {
    foreach(o->master_efuns, string e) {
      if (o[e]) {
	add_constant(e, o[e]);
      } else {
	throw(({ sprintf("Function %O is missing from roxen_master.pike.\n",
			 e), backtrace() }));
      }
    }
  } else {
    ::create();
  }

  add_constant("persistent_variables", persistent_variables);
  add_constant("name_program", name_program);
  add_constant("objectof", objectof);
  add_constant("nameof", nameof);
}


string errors = "";
void set_inhibit_compile_errors(mixed f)
{
  ::set_inhibit_compile_errors(f);
  errors="";
}


void clear_compilation_failures()
{
  foreach (indices (programs), string fname)
    if (!programs[fname]) m_delete (programs, fname);
}

#if !defined(__MAJOR__) || __MAJOR__ < 7
/*
 * This function is called whenever a compiling error occurs,
 * It is only required for Pike 0.6 since Pike 7.0 and higher
 * performs the correct task by default.
 */

void compile_error(string file,int line,string err)
{
  mixed inhibit;
  inhibit = inhibit_compile_errors;
  if(objectp(inhibit)) {
    if(functionp(inhibit->compile_error)) {
      inhibit->compile_error(file, line, err);
    }
  } else if(stringp(inhibit))
    errors += sprintf("%s:%d:%s\n",trim_file_name(file),line,err);
  else
    ::compile_error(file,line,err);
}
#endif
