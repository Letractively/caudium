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
 */

//
//! module: IP-Less virtual hosting (DEPRECATED)
//!  This module adds support for IP-less virtual hosts,
//!  simply add this module to a server with a real listen port
//!  (Server Variables -&gt; Listen ports)
//!  configured, then add no ports to all the servers you want to
//!  use ip-less virtual hosting for, but configure their
//!  server-URLs. This module will then automagically
//!  select the server the request should be sent to.
//!  <p><strong>Please note that the ip less hosting module
//!  doesn't work together with proxies. The reason is that the
//!  host header sent isn't the one of the proxy server, but the
//!  one of the requested host. We recommend having the proxies in
//!  their own virtual server, with a unique IP and / or port.</strong></p>
//! inherits: module
//! type: MODULE_PRECACHE
//! cvs_version: $Id$
// 

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";

//#define IP_LESS_DEBUG
constant module_type = MODULE_PRECACHE;
constant module_name = "IP-Less virtual hosting (DEPRECATED)";
constant module_doc  = "<b><font color=red>THIS MODULE IS DEPRECATED.</font> Please "
	    "use the Virtual Host Matcher module instead. It gives you the "
	    "ability to control how the host matching is done, using "
	    "regular expressions.</b><p>"
	    "This module adds support for IP-less virtual hosts, "
	    "simply add this module to a server with a real listen port "
	    "(Server Variables -&gt; Listen ports) "
	    "configured, then add no ports to all the servers you want to "
	    "use ip-less virtual hosting for, but configure their "
	    "server-URLs. This module will then automagically "
	    "select the server the request should be sent to."
	    "<p><b>Please note that the ip less hosting module "
	    "doesn't work together with proxies. The reason is that the "
	    "host header sent isn't the one of the proxy server, but the "
	    "one of the requested host. We recommend having the proxies in "
	    "their own virtual server, with a unique IP and / or port.</b>";
constant module_unique = 1;
constant module_deprecated = 1;


mapping config_cache = ([ ]);
mapping host_accuracy_cache = ([]);
int is_ip(string s)
{
  return(replace(s,
		 ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "." }),
		 ({ "","","","","","","","","","","" })) == "");
}

void create() {
  defvar("minmatch", 30, "Minimum Acceptable Match",
	 TYPE_INT, 
	 "If the best match results in a lower match percentage than this variable "
	 "the access will be made to the default server (the one with this module).");

}

object find_server_for(object id, string host)
{
  object old_conf = id->conf;

  host = lower_case(host);
  if(config_cache[host]) {
    id->conf=config_cache[host];
  } else {

    if (is_ip(host)) {
      // Not likely to be anything else than the current virtual server.
      config_cache[host] = id->conf;
      return(id->conf);
    }


#if constant(String.fuzzymatch)
    int best;
    object c;
    string hn;
#ifdef IP_LESS_DEBUG
    roxen_perror("IPLESS: find_server_for(object, \""+host+"\")...\n");
#endif /* IP_LESS_DEBUG */
    foreach(caudium->configurations, object s) {
      string h = lower_case(s->query("MyWorldLocation"));

      // Remove http:// and trailing slash...
      // Would get interresting correlation problems with the "http" otherwise.
      sscanf(h, "%*s://%s/", h);

      int corr = String.fuzzymatch(host, h);
#ifdef IP_LESS_DEBUG
      roxen_perror(sprintf("IPLESS: host: \"%s\"\n"
			   "IPLESS: server: \"%s\"\n"
			   "IPLESS: corr: %d\n",
			   host, h, corr));
#endif /* IP_LESS_DEBUG */
      if ((corr > best) ||
	  ((corr == best) && hn && (sizeof(hn) > sizeof(h)))) {
	/* Either better correlation,
	 * or the same, but a shorter hostname.
	 */
#ifdef IP_LESS_DEBUG
	roxen_perror(sprintf("IPLESS: \"%s\" is a better match for \"%s\" than \"%s\"\n",
			     h, host, hn||""));
#endif /* IP_LESS_DEBUG */
	best = corr;
	c = s;
	hn = h;
      }
    }
    if(best >= QUERY(minmatch)) {
      id->conf = config_cache[host] = (c || id->conf);
    } else 
      config_cache[host] = id->conf;
    host_accuracy_cache[host] = best;
#elif constant(Array.diff_longest_sequence)

    /* The idea of the algorithm is to find the server-url with the longest
     * common sequence of characters with the host-string, and among those with
     * the same correlation take the one which is shortest (ie least amount to
     * throw away).
     */

    int best;
    array a = host/"";
    string hn;
    object c;
#ifdef IP_LESS_DEBUG
    roxen_perror("IPLESS: find_server_for(object, \""+host+"\")...\n");
#endif /* IP_LESS_DEBUG */
    foreach(caudium->configurations, object s) {
      string h = lower_case(s->query("MyWorldLocation"));

      // Remove http:// et al here...
      // Would get interresting correlation problems with the "http" otherwise.
      int i = search(h, "://");
      if (i != -1) {
	h = h[i+3..];
      }

      array common = Array.diff_longest_sequence(a, h/"");
      int corr = sizeof(common);
#ifdef IP_LESS_DEBUG
      string common_s = rows(h/"", common)*"";
      roxen_perror(sprintf("IPLESS: h: \"%s\"\n"
			   "IPLESS: common: %O (\"%s\")\n"
			   "IPLESS: corr: %d\n",
			   h, common, common_s, corr));
#endif /* IP_LESS_DEBUG */
      if ((corr > best) ||
	  ((corr == best) && hn && (sizeof(hn) > sizeof(h)))) {
	/* Either better correlation,
	 * or the same, but a shorter hostname.
	 */
#ifdef IP_LESS_DEBUG
	roxen_perror(sprintf("IPLESS: \"%s\" is a better match for \"%s\" than \"%s\"\n",
			     h, host, hn||""));
#endif /* IP_LESS_DEBUG */
	best = corr;
	c = s;
	hn = h;
      }
    }
    // Minmatch should be counted in percent
    best=best*100/strlen(host);
    if(best >= QUERY(minmatch))
      id->conf = config_cache[host] = (c || id->conf);
    else
      config_cache[host] = id->conf;
    host_accuracy_cache[host] = best;
  
#else /* !constant(Array.diff_longest_sequence) */
    array possible = ({});
    foreach(caudium->configurations, object s)
      if(search(lower_case(s->query("MyWorldLocation")), host)+1)
	possible += ({ s });
    id->conf=config_cache[host]=
      (sizeof(possible)?
       Array.sort_array(possible,lambda(object s, string q) {
	 return (strlen(s->query("MyWorldLocation"))-strlen(q));},host)[0]:
	   ((sscanf(host, "%*[^.].%s", host)==2)?find_server_for(id,host):id->conf));
#endif /* constant(Array.diff_longest_sequence) */
  }

  if (id->conf != old_conf) {
    /* Need to re-authenticate with the new server */

    if (id->rawauth) {
      array(string) y = id->rawauth / " ";

      id->realauth = 0;
      id->auth = 0;

      if (sizeof(y) >= 2) {
	y[1] = MIME.decode_base64(y[1]);
	id->realauth = y[1];
	if (id->conf && id->conf->auth_module) {
	  y = id->conf->auth_module->auth(y, id);
	}
	id->auth = y;
      }
    }
  }

  // remove the request from the 'host' server
  old_conf->requests--;
  // add the request to the 'destination' server
  id->conf->requests++;

  return id->conf;
}

void precache_rewrite(object id)
{
  if(id->misc->host) find_server_for(id,lower_case((id->misc->host/":")[0]));
}

void clear_memory_cache()
{
  config_cache = ([]);
  host_accuracy_cache = ([]);  
}

void start()
{
  clear_memory_cache();
}
inherit "http";
string status()
{
  //  return "Blaha";
  string res="<table><tr bgcolor=lightblue><td>Host</td><td>Server</td><td>Match %</td></tr>";
  foreach(sort(indices(config_cache)), string s) {
    string match;
    if(zero_type(host_accuracy_cache[s]))
      match = "100";
    else if(host_accuracy_cache[s] < QUERY(minmatch)) {
      match = "less than minimum acceptable";
    } else 
      match = host_accuracy_cache[s];
    res+="<tr><td>"+s+"</td><td><a href=/Configurations/"+
      http_encode_string(config_cache[s]->name)+">"+
      (config_cache[s]->name)+"</a></td><td>"+match+"</td></tr>";
  }
  return res+"</table>";
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: minmatch
//! If the best match results in a lower match percentage than this variable the access will be made to the default server (the one with this module).
//!  type: TYPE_INT
//!  name: Minimum Acceptable Match
//
