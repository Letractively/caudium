/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
 * Support for user Pike-scripts, like CGI, but handled internally in
 * the server, and thus much faster, but blocking, and somewhat less
 * secure.
 *
 * This is an extension module.
 */
constant cvs_version = "$Id$";

#include <module.h>
#include <config.h>
inherit "pikescript.pike";

Web.PikeServerPages.PSPCompiler compiler;


constant module_name = "PikeServerPages support";
constant module_doc  = "Support for user PikeServerPages.\n"
    "<br><img src=/image/err_2.gif align=left alt=\"\">"
    "NOTE: This module should not be enabled if you allow anonymous PUT!<br>\n"
    "NOTE: Enabling this module is the same thing as letting your users run"
    " programs with the same right as the server!";


string parse_psp(string code, string realfile)
{
   if(!compiler)
     compiler = Web.PikeServerPages.PSPCompiler();


  return compiler->parse_psp(code, realfile);
}

void create()
{
  defvar("exts", ({ "psp" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse");

  defvar("reload_on_update", 0, "Reload on update?", TYPE_FLAG,
         "should the psp file be recompiled when it is updated?\n"
         "Note that this will slow operations down, and is recommended "
         "only for development purposes.");
  defvar("fork_exec", 0, "Fork execution: Enabled", TYPE_FLAG,
	 "If set, pike will fork to execute the script. "
	 "This is a more secure way if you want to let "
	 "your users execute pike scripts. "
	 "NOTE: This doesn't work in threaded servers.\n"
	 "Note, that fork_exec must be set for Run scripts as, "
	 "Run user scripts as owner and Change directory variables.\n"
	 "Note, all features of pike-scripts are not available when "
	 "this is enabled.");

  defvar("runuser", "", "Fork execution: Run scripts as", TYPE_STRING,
	"If you start Caudium as root, and this variable is set, root uLPC "
	"scripts will be run as this user. You can use either the user "
	"name or the UID. Note however, that if you don't have a working "
	"user database enabled, only UID's will work correctly. If unset, "
	"scripts owned by root will be run as nobody. ", 0, fork_exec_p);

  defvar("scriptdir", 1, "Fork execution: Change directory", TYPE_FLAG,
	"If set, the current directory will be changed to the directory "
	"where the script to be executed resides. ", 0, fork_exec_p);
  
  defvar("user", 1, "Fork execution: Run user scripts as owner", TYPE_FLAG,
	 "If set, scripts in the home-dirs of users will be run as the "
	 "user. This overrides the Run scripts as variable.", 0, fork_exec_p);

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG|VAR_MORE,
	 "If set, the raw, unparsed, user info will be sent to the script. "
	 "Please note that this will give the scripts access to the password "
	 "used. This is not recommended !", 0, fork_exec_p);

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG|VAR_MORE,
	 "If set, the decoded password value will be sent to the script. "
	 "This is not recommended !", 0, fork_exec_p);

  defvar("exec-mask", "0777", 
	 "Exec mask: Needed", 
	 TYPE_STRING|VAR_MORE,
	 "Only run scripts matching this permission mask");

  defvar("noexec-mask", "0000", 
	 "Exec mask: Forbidden", 
	 TYPE_STRING|VAR_MORE,
	 "Never run scripts matching this permission mask");

#if constant(set_max_eval_time)
  defvar("evaltime", 4, "Maximum evaluation time", TYPE_INT,
	 "The maximum time (in seconds) that a script is allowed to run for. "
	 "This might be changed in the script, but it will stop most mistakes "
	 "like i=0; while(i&lt;=0) i--;.. Setting this to 0 is not a good idea.");
#endif
}


mapping handle_file_extension(object f, string e, object id)
{
  int mode = f->stat()[0];
  if(!(mode & (int)query("exec-mask")) ||
     (mode & (int)query("noexec-mask")))
    return 0;  // permissions does not match.


  string file="";
  string s;
  mixed err;
  program p;
  object o;

  if(scripts[id->not_query])
  {
    if(id->pragma["no-cache"] || (QUERY(reload_on_update) && 
        f->stat()->mtime > scripts[id->not_query][0]))
    {
      o = function_object(scripts[id->not_query][1]);
      // Reload the script from disk, if the script allows it.
      if(!o->no_reload || (functionp(o->no_reload) && o->no_reload(id)))
      {
        m_delete( master()->programs, object_program(o));
        destruct(o);
        scripts[id->not_query] = 0;
      }
    }
  }

  function fun;

  
  if(!(scripts[id->not_query] && (functionp( fun=(scripts[id->not_query][1]))))) {
    file=f->read(0x7ffffff);   // fix this?

    file = parse_psp(file, id->realfile);

    if(id->realfile)
      file = cpp(file, id->realfile);
    else
      file = cpp(file);
    array (function) ban = allocate(6);
#if constant(setegid)
    ban[0] = setegid;
    ban[2] = seteuid;
#endif
    ban[1] = setgid;
    ban[3] = setuid;
    //ban[4] = spawne;

    add_constant("setegid", 0);
    add_constant("seteuid", 0);
    add_constant("setgid", 0);
    add_constant("setuid", 0);
    //add_constant("spawne", 0);
    ban[5] = cd;
    add_constant("cd", 0);
    object e = ErrorContainer();
    master()->set_inhibit_compile_errors(e);
    mixed re = catch
    {
werror("recompiling %s\n", id->realfile);
      p = compile_string(file, id->realfile);
    };
    master()->set_inhibit_compile_errors(0);
    if(!p)
    {
      // force reload on next access. Really.
      master()->clear_compilation_failures();

      if(strlen(e->get()))
      {
        report_error("Error compiling PSP page: \n" + e->get());
        return
          Caudium.HTTP.string_answer("<h1>Error compiling PSP page</h1><p><pre>"+
                             _Roxen.html_encode_string(e->get())+"</pre>");
      }
      throw( err );
    }
    e->print_warnings("Error compiling PSP page "+id->not_query+":");

#if constant(setegid)
    add_constant("setegid", ban[0]);
    add_constant("seteuid", ban[2]);
#endif
    add_constant("setgid", ban[1]);
    add_constant("setuid", ban[3]);
    //add_constant("spawne", ban[4]);
    add_constant("cd", ban[5]);

    if(err) {
      destruct(f);
      my_error(err, id->not_query+":\n"+(s?s+"\n\n":"\n"),
               "Error while compiling PSP page:<br>\n\n");
    }
    if(!p) {
      destruct(f);
      return Caudium.HTTP.string_answer("<h1>While compiling PSP page</h1>\n"+s);
    }

    o=p();
    fun = o->parse;
    scripts[id->not_query] = ({time(), fun});
    if (!functionp(fun)) {
      /* Should not happen */
      destruct(f);
      return Caudium.HTTP.string_answer("<h1>Internal error in PSP page</h1>\n");
    }

  }
  id->misc->cacheable=0;
  err=call_script(fun, id, f);
  destruct(f);
  if(arrayp(err)) {
    destruct(function_object(fun));
    scripts[id->not_query] = 0;
    my_error(err[1]); // Will interrupt here.
  }
  return err;
}


