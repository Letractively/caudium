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
 */

inherit "wizard";

constant name= "Maintenance//Check your Caudium configuration for problems...";
constant doc = "Perform several sanity-checks of your configuration.";
constant wizard_name = "Check configuration";


string page_0(object id)
{
  return ("<b>Welcome to the problem finder wizard.</b>"
	  "<p>This action tries to find the most "
	  "common errors in your Caudium configuration.");
}

mapping mod_recursed = ([]), mod_problems = ([]), mod_identifiers = ([]);

#define DIR_DONT_EXIST 1
#define MOD_DOUBLE 2

void module_recurse_dir(string dir)
{
  if(mod_recursed[dir]) return;
  mod_recursed[dir]=1;
  array d = get_dir(dir);
  string res="";
  array to_recurse = ({});
  string current_check;
  if(d && (search(d, ".no_modules")!=-1)) return;
  if(!d)
  {
    mod_problems[dir] = DIR_DONT_EXIST;
    return;
  }
  foreach(d, string f)
  {
    string rf = f;
    if(f[-1]=='~' || f[0]=='.' || sscanf(f, "%*s.pmod") || f=="CVS")
      continue;
    if(Stdio.file_size(dir+f) < 0)
      to_recurse += ({ dir+f+"/" });
    else if(sscanf(f, "%s.pike", f) ||
	    sscanf(f, "%s.lpc", f) ||
	    sscanf(f, "%s.so", f))
      if(mod_identifiers[f])
	mod_problems[dir+rf] = ({ MOD_DOUBLE, mod_identifiers[f] });
      else
	mod_identifiers[f] = dir+rf;
  }
  foreach(to_recurse, string f)
    module_recurse_dir(f);
}

// Check modules in module path.
string page_1(object id)
{
  mod_recursed = ([]); mod_identifiers = ([]); mod_problems = ([]);
  foreach(caudium->query("ModuleDirs"), string dir) module_recurse_dir(dir);

  if(mod_problems)
  {
    string res = html_notice("<b>Checking module directories</b>",id);
    foreach(indices(mod_problems), string n)
    {
      if(mod_problems[n]==DIR_DONT_EXIST)
      {
#if constant(readlink)
	int in_main_path;
	string symlink;
	if(search(caudium->query("ModuleDirs"), n)+1)
	  in_main_path = 1;
	if(array a=file_stat(n, 1))
	  if(a[1]<-1) {
	    symlink = readlink(n);
	  }

	if(symlink)
	  res+=html_error("The module directory <b>"+n+"</b> "
			  "(symbolic link to <b>"+symlink+"</b>) does not"
			  " exist. <br><var name=\"delete_mpath_"+n+
			  "\" type=checkbox> Delete the symbolic link<br>"+
			  (in_main_path?"<var name=\"remove_mpath_"+n+
			   "\" type=checkbox> Remove the directory from the "
			   "Module Path variable<br>":"")
			  ,id);
	else
#endif /* constant(readlink) */
	  res+=html_error("The module directory <b>"+n+
			  "</b>, mentioned in the "
			  "'Module Path' variable, does not exist.<br>"
			  "<var name=\"remove_mpath_"+n+
			  "\" type=checkbox> Remove the directory from the "
			  "Module Path variable<br>",id);
      } else {
	res+=html_warning("The module <b>"+n+
			  "</b>, is also available as "+mod_problems[n][1]+
			  "<br>"
			  "<var name=\"remove_module_"+n+"\" "
			  "type=checkbox> Move <b>"+n+
			  "</b> to disabled_modules<br>"
			  "<var name=\"remove_module_"+mod_problems[n][1]
			  +"\" type=checkbox> Move <b>"+mod_problems[n][1]
			  +"</b> to disabled_modules<br>",id);
      }
    }
    res += html_notice("Scanned "+sizeof(mod_recursed)+
		     " directories, found "+sizeof(mod_identifiers)+
		       " modules.<br>",id);
    return res;
  }
  return html_notice("Scanned "+sizeof(mod_recursed)+
		     " directories, found "+sizeof(mod_identifiers)+
		     " modules.<br>"
		     "No problems.\n",id);
}

string page_2(object id)
{
  int errs;
  string res="<font size=+1>Checking enabled virtual servers</font><p>";
  foreach(caudium->configurations, object c)
  {
    res+=html_notice("<b>Checking "+(strlen(c->query("name"))?
				     c->query("name"):c->name)+"</b>",id);
    if(c->query("Log") && strlen(c->query("LogFile")) && !c->log_function)
    {
      errs++;
      res +=
	html_warning("The logfile "+c->query("LogFile")+
		     " cannot be opened<br>You might want to select "
		     "another log filename<br>"
		     "<var name=\"mod_cvar_"+c->name+
		     "/LogFile\" default=\""+c->query("LogFile")+"\">", id);
    }
    if(sizeof(c->query("NoLog")) && (search(c->query("NoLog"), "*")!=-1))
    {
      errs++;
      res +=
	html_warning("The 'no log for' pattern includes '*'. "
		     "This means that no logging "
		     "will be done, and the &lt;accessed&gt; tag will not "
		     "work. You might want to modify the no-log for variable."
		     "<br>"
		     "<var name=\"mod_cvar_"+c->name+
		     "/NoLog\" type=list size=20,1 default=\'"+
		     (c->query("NoLog")*"\0")+"\'>", id);
    }

    foreach(sort(indices(caudium->retrieve("EnabledModules",c))), string m)
    {
      sscanf(m,"%s#",m);
      if(!c->modules[m])
      {
	errs++;
	res += html_warning("The module "+m+" could not be loaded<br>"
			    "<var name=\"mod_remove_module_"+c->name+"/"+m+
			    "\" "
			    "type=checkbox> Don't try again",id);
      } else {
	// Check the module?
      }
    }
  }
  if(!errs) res+="<p><font size=+1>No errors found</font>";
  return res;
}


#include <roxen.h>
#include <config.h>
string page_3(object id)
{
  filter_checkbox_variables(id->variables);
  int errs;
  string res="<font size=+1>Checking Global Variables</font><p>";

  if(caudium->query("NumAccept")>16 && sizeof(caudium->configurations)>3)
  {
    errs++;
    res += html_warning("It is not advisable to have the 'Number of "
			"accepts to attempt' variable set to a high "
			"value with more than four virtual servers, "
			"since this will dramatically impair the "
			"load-balancing between virtual servers<br>"
			"Set to: <var type=select name=\""
			"mod_cvar_G/NumAccept\" choices=1,2,4,8,16,"+
			caudium->query("NumAccept")+" "
			"default="+caudium->query("NumAccept")+"><br>",id);
  }
  
  string user;
  if(strlen(user=caudium->query("User")))
  {
    string u,g;
    if(getuid())      
    {
      res += html_warning("The server was not started as root, so the "
			  "variable 'Change uid and gid to' will not have "
			  "any effect, but it is set to "+user,id);
    }
    if(!sscanf(user, "%s:%s", u, g))
      u = user;

#if constant(getpwnam)
    array pw;
    if(!(pw = getpwnam(u)) && (int)u)
      pw = getpwuid((int)u);

    if(!pw)
      res += html_warning("'Change uid and gid to' is set to "+user+
			  ". This does not seem to be a valid user on this "
			  "computer. Caudium is currently running as UID#"+
			  geteuid()+". You might want to change this "
			  "variable.<br>"
			  "<var name=mod_cvar_G/User size=20,1 default='"+user+
			  "'>",id);
#endif
  }


#ifdef THREADS
  
#endif

  
  if(!errs) res+="<font size=+1>No errors found</font>";
  return res;
}

void remove_module_dir(string dir)
{
  caudium->set("ModuleDirs", caudium->query("ModuleDirs")-({dir}));
}

array fix_array(array in)
{
  array res = ({});
  foreach(in, string q)
    if(strlen(((replace(q,"\t", " ")-" ")-"\r")-"\n"))
      res += ({ q });
  return res;
}

void modify_variable(string v, string to)
{
  string c;
  sscanf(v, "%s/%s", c, v);
  if(c=="G")
  {
    if(arrayp(caudium->query(v))) caudium->set(v,fix_array(to/"\0"-({""})));
    else if(intp(caudium->query(v))) caudium->set(v,(int)to);
    else if(floatp(caudium->query(v))) caudium->set(v,(float)to);
    else  caudium->set(v,to);
    caudium->store("Variables", caudium->variables, 0, 0);
    return;
  } else {
    foreach(caudium->configurations, object co)
      if(co->name == c)
      {
	if(arrayp(co->query(v))) co->set(v,fix_array(to/"\0"-({""})));
	else if(intp(co->query(v))) co->set(v,(int)to);
	else if(floatp(co->query(v))) co->set(v,(float)to);
	else  co->set(v,to);
	co->save(1);
      }
  }
}

void remove_module(string m)
{
  string c;
  sscanf(m, "%s/%s", c, m);
  foreach(caudium->configurations, object co)
    if(co->name == c)
    {
      mapping en = caudium->retrieve("EnabledModules",co);
      foreach(indices(en), string q)
      {
	if(!search(q,m))
	{
	  caudium->remove(q,co);
	  m_delete(en,q);
	}
      }	
      caudium->store("EnabledModules", en, 1, co);
    }
}

array actions = ({ });
string page_4(object id)
{
  string res = "<font size=+1>Summary</font><ul>";
  actions=({});
  string tmp="";
  filter_checkbox_variables(id->variables);
  foreach(indices(id->variables), string v)
  {
    if(sscanf(v,"remove_module_%s", tmp))
      actions += ({ ({ "Move the module <b>"+tmp+"</b> to disabled_modules/",
			 mv, tmp, "disabled_modules/"+(tmp-dirname(tmp)) }) });
    else if(sscanf(v,"remove_mpath_%s", tmp))
      actions +=({({"Remove the directory <b>"+tmp+"</b> from the module path",
		      remove_module_dir, tmp }) });
    else if(sscanf(v,"mod_cvar_%s", tmp))
      actions +=({({"Modify the variable <b>"+tmp+"</b>",
		      modify_variable, tmp, id->variables[v] }) });
    else if(sscanf(v,"mod_remove_module_%s", tmp))
      actions +=({({"Remove the module <b>"+tmp+"</b>",
		      remove_module, tmp }) });
    else if(sscanf(v,"delete_mpath_%s", tmp))
      actions +=({({"Delete the symbolic link <b>"+tmp+"</b>.", rm, tmp }) });
  }
  if(!sizeof(actions)) return res+"No actions will be done</ul>";
  res += "In order to fix the problems the following actions "
    "will be performed.<p>";
  foreach(actions, array act) res += "<li>"+act[0];
  return res+"</ul>";
}

string wizard_done(object id)
{
  if(actions)
  {
    object o = ((program)"privs")("Fixing config");
    mkdir("disabled_modules");
    foreach(actions, array action) action[1](@action[2..]);
  }
}

string handle(object id)
{
  return wizard_for(id,0);
}
