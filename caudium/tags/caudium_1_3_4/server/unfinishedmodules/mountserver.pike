/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

string cvs_version = "$Id$";
// Mounts a virtual server on a location in the virtual filesystem of
// another one (or, infact, the same one, but that is probably quite
// useless).
#include <module.h>

#define TYPE_SERVER TYPE_STRING
#define DEBUG 

inherit "module";

mixed *register_module()
{
  return ({ 
    MODULE_LOCATION,
    "Server as a filesystem", 
    ("This module enables you to mount a virtual server as a filesystem. "
     "")
      });
}



void create()
{
  defvar("server", "NONE", "Server", TYPE_SERVER, 
	 "The virtual server to mount.");

  defvar("mountpoint", "NONE", "Mount point", TYPE_LOCATION,
	 "The mountpoint in the namespace of this virtual server.");
}

string fmts;
object config;

string query_location() { return QUERY(mountpoint); }

object find_configuration( string what )
{
  object c;
  foreach(caudium->configurations, c)
    if(objectp(c))
      if(lower_case(c->name) == lower_case(what))
	return c;
}

array find_dir( string f, object id )
{
  mixed res;
  object oc;
  string oq;

  if(!config)  config = find_configuration( query("server") );
  oq = id->not_query;
  oc = id->conf;
  id->not_query = f;
  id->conf = config;
  res = caudium->find_dir( f, id );
  id->not_query = oq;
  id->conf = oc;
#ifdef DEBUG
  if(res)
    perror(sprintf("find_dir:: %s == %{%s, %}\n",f,res));
  else
    perror(sprintf("find_dir:: %s No such dir.\n",f));
    
#endif
  return res;
}

array stat_file( string f, object id )
{
  mixed res;
  object oc;
  string oq;
  if(!config) 
    config = find_configuration( query("server") );
  oq = id->not_query;
  oc = id->conf;
  id->not_query = f;
  id->conf = config;
  res = caudium->stat_file( f, id );
  id->not_query = oq;
  id->conf = oc;
#ifdef DEBUG
  if(arrayp(res))
    perror(sprintf("stat_file:: %s; res = %{%O, %}\n",f,res));
  else
    perror("stat_file:: "+f+", no such file\n");
#endif
  return res;
}

array real_file( string f, object id )
{
  mixed res;
  object oc;
  string oq;
  if(!config) 
    config = find_configuration( query("server") );
  oq = id->not_query;
  oc = id->conf;
  id->not_query = f;
  id->conf = config;
  res = caudium->real_file( f, id );
  id->not_query = oq;
  id->conf = oc;
#ifdef DEBUG
  perror(sprintf("real_file:: Location = %s; LocalLocation = %s; res = %O\n",oq,f,res));
#endif
  return res;
}

string mp;

void start()
{
  if(strlen(mp=query("mountpoint")))
  {
    if(query("mountpoint")[-1] == '/')
    {
      mp = mp[..strlen(mp)-2];
      set("mountpoint", mp);
    }
  }
  config = find_configuration( query("server") );
}

inline nomask private static string tags(mapping from)
{
  string t, res="";
  foreach(indices(from), t)
    res += " " + t+"=\""+from[t]+"\"";
  return res;
}

inline nomask private static string fix_it(string from)
{
  string pre;
  if(strlen(from) && from[0]=='/' && search(from, mp))
  {
    if(sscanf(from, "/<%s>%s", pre, from)==2)
    {
      if(search(from, mp))
      {
	if(pre)
	  return "/<"+pre+">" + mp + from;
      } else
	from = "/<"+pre+">/" + from;
    }
    if(sscanf(from, "/(%s)%s", pre, from)==2)
    {
      if(search(from, mp))
      {
	if(pre)
	  return "/("+pre+")" + mp + from;
      } else
	from = "/("+pre+")/" + from;
    }
    return QUERY(mountpoint) + from;
  }
  return from;
}

string do_href(string t, mapping m) 
{
  if(m->__parsed) return 0;
  if(!m->href) return 0;
  m->__parsed="yes";
  m->href = fix_it(m->href);
  return "<"+t+tags(m)+">";
}

string do_src(string t, mapping m)
{
  if(m->__parsed)    return 0;
  if(!m->src) return 0;
  m->__parsed="yes";
  m->src = fix_it(m->src);
  return "<"+t+tags(m)+">";
}

string do_action(string t, mapping m)
{
  if(m->__parsed)    return 0;
  if(!m->action) return 0;
  m->__parsed="yes";
  m->action = fix_it(m->action);
  return "<"+t+tags(m)+">";
}

string do_background(string t, mapping m)
{
  if(m->__parsed)    return 0;
  if(!m->background) return 0;
  m->__parsed="yes";
  m->background = fix_it(m->background);
  return "<"+t+tags(m)+">";
}

string fix_absolute(string from)
{
  string data;
  if ((data = parse_html(from, ([ "base":do_href ]), ([]))) == from) {
    return parse_html(from, ([ "a":do_href, "img":do_src, "form":do_action, 
			       "input":do_src, "body":do_background  ]), ([]));
  } else {
    return data;
  }
}

mapping find_file(string f, object id)
{
  mapping res;
  object oc;
  string oq;
  if(!config) 
    config = find_configuration( query("server") );

  if(!config) return 0;

  oq = id->not_query;
  oc = id->conf;
  id->not_query = f;
  id->conf = config;
  res = caudium->get_file( id, 1 );
  id->not_query = oq;
  id->conf = oc;
#ifdef DEBUG
  perror(sprintf("find_file:: Location = %s; LocalLocation = %s; res = %O\n",oq,f,res));
#endif
  if(intp(res)) return res;
  if(mappingp(res) && res->data)
    res->data = fix_absolute( res->data );
  caudium->current_configuration = oc;
  return res;
}

string comment()
{
  return "The server "+QUERY(server)+" mounted on "+QUERY(mountpoint);
}
