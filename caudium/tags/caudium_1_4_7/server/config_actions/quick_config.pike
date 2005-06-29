/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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

/*
 * $Id$
 */

inherit "wizard";

string name="Maintenance//Quick Config...";
string doc = "You can here automate the most common configuration and maintenance tasks.";


constant features = ([
  "&lt;GText&gt;":([ "module":"graphic_text", "depend":"htmlparse",
		     "help":"The RXML graphical text tag &lt;gtext&gt;."]),
  "RXML":([ "module":"htmlparse",
	    "help":"If removed, all RXML parsing will be disabled."]),
  "CGI":([
    "module":"cgi",
    "help":"Support for CGI scripts.",
    "settings":([
      
    ]),
  ]),
  "Pike":([ "module":"pikescript","help":"Support for pike scripts.", ]),
  "&lt;Pike&gt;":([ "module":"lpctag","depend":"htmlparse",
		    "help":"Support for the pike tag.",]),
  "IP-VHM":([ "module":"ip-less_hosts",
	      "help":"IP less virtual server master<br>Select this option"
	      "in the configuration that has open ports you want to use "
	      "for ip-less virtual hosting."]),
  "&lt;OBox&gt;":([ "module":"obox", "depend":"htmlparse",]),
  "Imagemaps":([ "module":"ismap", ]),
  "&lt;Tablify&gt;":([ "module":"tablify", "depend":"htmlparse" ]),
  "Userfs":([
    "module":"userfs", "depend":"userdb",
    "help":"Enable user directories."
  ]),
]);

string config_name(object c)
{
  if(strlen(c->query("name"))) return c->query("name");
  return c->name;
}


array not_tags(array q)
{
  return Array.filter(q,lambda(string q){ return q[0]!='&'; });
}

array tags(array q)
{
  return q - not_tags(q);
}

string page_0(object id)
{
  array tbl = ({ });
  string q,pre="<font size=+1>Specific features</font><p>";
  foreach(sort(not_tags(indices(features))), string s)
    if(q=features[s]->help)
      pre += "<help><dl><dt><b>"+s+"</b><dd>"+q+"</dl><p></help>";
  foreach(caudium->configurations, object c)
  {
    array tblr = ({ config_name(c) });
    foreach(sort(not_tags(indices(features))), string f)
      if(c->modules[features[f]->module])
	tblr += ({ "<font size=+2><var type=checkbox name='"+c->name+"/"+f+"' default=1></font>" });
      else
	tblr += ({ "<font size=+2><var type=checkbox name='"+c->name+"/"+f+"' default=0></font>" });
    tbl += ({ tblr });
  }
  return pre+html_table( ({ "Server" })  + sort(not_tags(indices(features))),
  tbl );
}


string page_1(object id)
{
  array tbl = ({ });
  int num;
  string q,pre="<font size=+1>RXML tags</font><p>";
  foreach(sort(tags(indices(features))), string s)
    if(q=features[s]->help)
      pre += "<help><dl><dt><b>"+s+"</b><dd>"+q+"</dl><p></help>";
  foreach(caudium->configurations, object c)
  {
    if((id->variables[c->name+"/RXML"]!="0"))
    {
      num++;
      array tblr = ({ config_name(c) });
      foreach(sort(tags(indices(features))), string f)
	if(c->modules[features[f]->module])
	  tblr += ({ "<font size=+2><var type=checkbox name='"+
		       c->name+"/"+f+"' default=1></font>" });
	else
	  tblr += ({ "<font size=+2><var type=checkbox name='"+
		       c->name+"/"+f+"' default=0></font>" });
      tbl += ({ tblr });
    }
  }
  if(num)
    return pre+html_table( ({ "Server" })+sort(tags(indices(features))),tbl );
}

object find_config(string n)
{
  foreach(caudium->configurations, object c) if (c->name==n) return c;
}

array actions;

void enable_module(object c, string m, string d)
{
  c->enable_module(m);
  if(d && !c->modules[d]) c->enable_module(d);
}

void disable_module(object c, string m)
{
  c->disable_module(m);
}

string page_2(object id)
{
  actions = ({});
  foreach(sort(indices(id->variables)), string i)
  {
    string conf, mod;
    if(sscanf(i, "%s/%s", conf, mod)==2)
    {
//      report_debug("conf: "+conf+" mod: "+mod+"\n");
      mod = _Roxen.html_encode_string(mod);
      int to_enable = (id->variables[i] != "0");
      object config = find_config(conf);
      string m = features[mod]->module;
      string d = features[mod]->depend;
      if(config && (to_enable==!config->modules[m]))
	if(to_enable)
	  actions += ({({"Enable the module "+m+" in the configuration "+
			  config_name(config),
			  enable_module, config, m, d })});
        else
	  actions += ({({"Disable the module "+m+" in the configuration "+
			  config_name(config),
			  disable_module, config, m })});
    }
  }

  if (sizeof(actions)) {
    return ("<font size=+1>Summary</font><p><ul><li>"+
	    column(actions,0)*"\n<li>"+"</ul>");
  } else {
    return ("<font size=+1>Summary</font><p>\n"
	    "<ul>No changes will be made.</ul>");
  }
}


void wizard_done(object id)
{
  foreach(actions, array action) action[1](@action[2..]);
  if (caudium->unload_configuration_interface) {
    /* Fool the type-checker of in old Roxen's */
    mixed foo = caudium->unload_configuration_interface;
    foo();
  } else {
    /* Some backward compatibility */
    caudium->configuration_interface_obj=0;
    caudium->loading_config_interface=0;
    caudium->enabling_configurations=0;
    caudium->build_root=0;
    catch{caudium->root->dest();};
    caudium->root=0;
  }
}


string handle(object id){ return wizard_for( id , 0 ); }
