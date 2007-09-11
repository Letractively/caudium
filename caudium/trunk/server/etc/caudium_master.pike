/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2005 The Caudium Group
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
 * $Id$
 */

//! Caudium master, replacing the default Pike master.
//! $Id$

constant cvs_version = "$Id$";

mapping names=([]);
int unique_id=time();

mapping(program:string) program_names = set_weak_flag (([]), 1);

object mm = (object)"/master";

inherit "/master": old_master;

function current_thread = Thread.this_thread;
int findprog_mappings = 0;

class findprog_handler
{
  inherit "/master": old_master;

  mixed resolv(mixed ... args)
  {
//    werror("surrogate resolv(%O)\n", args);
    return ::resolv(@args);
  }

  program low_findprog(mixed ... args)
  {
//    werror("surrogate low_findprog(%O)\n", args);
    return ::low_findprog(@args);
  }

  program low_cast_to_program(mixed ... args)
  {
//    werror("surrogate low_cast_to_program(%O)\n", args);
    return ::low_cast_to_program(@args);
  }

  //!   
  void create()
  {
    object o = this_object();
    /* Copy variables from the original master */  
    foreach(indices(mm), string varname) {
      catch(o[varname] = mm[varname]);
      /* Ignore errors when copying functions */
    }
    programs["/master"] = object_program(o);
    program_names[object_program(o)] = "/master";
    objects[object_program(o)] = o;
 
    /* Move the old efuns to the new object. */
  }

}

mapping findprog_handlers = ([]);
mapping findprog_thread_keys = ([]);

void add_handler_for_key(mixed key, object handler)
{
  findprog_mappings++;
  findprog_handlers[key] = handler;
}

void add_thread_for_key(mixed key, object thread)
{
  findprog_thread_keys[thread] = key;
}

array get_program_path()
{
  object handler = get_findprog_handler_for_thread();
   return handler->pike_program_path;
}

array get_module_path()
{
  object handler = get_findprog_handler_for_thread();
   return handler->pike_module_path;
}

array get_include_path()
{
  object handler = get_findprog_handler_for_thread();
   return handler->pike_include_path;
}

void add_module_path(string tmp)
{
  object handler = get_findprog_handler_for_thread();
  if(handler != this)
    handler->add_module_path(tmp);
  else ::add_module_path(tmp);
}

void add_program_path(string tmp)
{
  object handler = get_findprog_handler_for_thread();

  if(handler != this)
    handler->add_program_path(tmp);
  else ::add_program_path(tmp);
//  werror("program_path: %O\n",  handler->pike_program_path - master()->pike_program_path);
}


void add_include_path(string tmp)
{
  object handler = get_findprog_handler_for_thread();

  if(handler != this)
    handler->add_include_path(tmp);
  else 
    ::add_include_path(tmp);
}

object get_findprog_handler_for_thread()
{
  object key;
  object thandler;

//   werror("get_findprog_handler_for_thread(%O)\n", current_thread());
//   werror("%O\n", findprog_thread_keys);

  if(findprog_mappings)
    key = findprog_thread_keys[current_thread()];
  else
    return this;

  if(key)
  {
//   werror("got a handler!: %O\n", findprog_handlers);
    return findprog_handlers[key];
  }
  else return this;  
}

//!
string program_name(program p)
{
//werror(sprintf("Program name %O = %O\n", p, search(programs,p)));
  //return search(programs, p);

  return program_names[p];
}

//!
mapping saved_names = ([]);
 
//!
void name_program(program foo, string name)
{
//  programs[name] = foo;
//  saved_names[foo] = name;
//  saved_names[(program)foo] = name;
  if(programs[name]) {
    if (programs[name] == foo) return;
    if (rev_programs && (rev_programs[programs[name]] == name)) {
      m_delete(rev_programs, programs[name]);
    }
    m_delete(programs, name);
  }
  string t = programs_reverse_lookup(foo);
  load_time[name] = t?load_time[t]:time(1);
  programs[name] = foo;
}

private static int mid = 0;

mapping _vars = ([]);

//!
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

//!
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

//!
array|string nameof(mixed foo)
{
  // werror(sprintf("Nameof %O...\m", foo));
  return saved_names[foo] ||  (saved_names[foo] = low_nameof( foo ));
}

//!
program programof(string foo)
{
  return saved_names[foo] || programs[foo] || (program) foo ;
}

//!
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

//!
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

  program low_cast_to_program(mixed ... args)
  {
    mixed key;
    object thandler;
    if(findprog_mappings)
      key = findprog_thread_keys[current_thread()];
    else
      return ::low_cast_to_program(@args);

    if(key)
    {
      //werror("low_cast_to_program(%O)\n", args);
      return findprog_handlers[key]->low_cast_to_program(@args);
    }
    else
      return ::low_cast_to_program(@args);

  }



mixed resolv(mixed ... args)
{
  mixed key;
  object thandler;
  if(findprog_mappings)
    key = findprog_thread_keys[current_thread()];
  else
    return ::resolv(@args);

  if(key)
  {
    return findprog_handlers[key]->resolv(@args);
  }
  else
    return ::resolv(@args);
}


// This will avoid messages about cannot set a mutex when
// threads are disabled. Since threads are automatically
// disabled when compiling a program.
// This is more simple since we have only to catch such
// messages.

// For low_findprog();
#if constant(_static_modules.Builtin.mutex)
#define THREADED
#endif

program findprog(mixed ... args)
{
  //werror("findprog(%O)\n", args);
  return ::findprog(@args);

}

//! Caudium low_findprog() 
program low_findprog(string pname, string ext,
		     object|void handler, void|int mkobj)
{
  object key;
  object thandler;
  if(findprog_mappings)
    key = findprog_thread_keys[current_thread()];
  else
    return old_master::low_findprog(pname, ext, handler, mkobj);

  if(key)
  {
    return findprog_handlers[key]->low_findprog(pname, ext, handler, mkobj);
  }
  else
    return old_master::low_findprog(pname, ext, handler, mkobj);
}

//!
void handle_error(array(mixed)|object trace)
{
  catch {
    if (arrayp (trace) && sizeof (trace) == 2 &&
        arrayp (trace[1]) && !sizeof (trace[1]))
      // Don't report the special compilation errors thrown above. Pike
      // calls this if resolv() or similar throws.
      return;
  };
  ::handle_error (trace);
}

//! Our own Describer class
class Describer
{
  inherit old_master::Describer;

  //!
  string describe_string (string m, int maxlen)
  {
    canclip++;
    if(sizeof(m) < 40)
      return  sprintf("%O", m);;
    clipped++;
    return sprintf("%O+[%d]+%O",m[..15],sizeof(m)-(32),m[sizeof(m)-16..]);
  }

  //!
  string describe_array (array m, int maxlen)
  {
    if(!sizeof(m)) return "({})";
    return "({" + describe_comma_list(m,maxlen-2) +"})";
  }
}

// Our describe_bactrace system :)
constant bt_max_string_len = 99999999;
int long_file_names;

string describe_backtrace(mixed trace, void|int linewidth)
{
  return predef::describe_backtrace(trace, 999999);
}

//!
void create()
{
  object o = this_object();
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(o[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }
  programs["/master"] = object_program(o);
  program_names[object_program(o)] = "/master";
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
  add_constant("findprog", findprog);
}

//!
void clear_compilation_failures()
{
  foreach (indices (programs), string fname)
    if (!programs[fname]) m_delete (programs, fname);
}

