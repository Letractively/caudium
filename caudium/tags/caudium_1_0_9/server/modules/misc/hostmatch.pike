/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
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
//! module: Virtual Host Matcher
//!  hostmatch.pike - host header regexp -> host header/virt site remap
//!  This module is used for virtual hosting. It's like the IP Less
//!  virtual hosting module but better. Instead of relying on flaky
//!  fuzzy matching, this module uses regexps to rewrite the host header
//!  and then does an exact match on the result. No rules or no matched
//!  rules uses exact matching on the host header.
//!  <p><strong>Please note that  ip less hosting
//!  doesn't work well together with proxies. The reason is that the
//!  host header sent isn't the one of the proxy server, but the
//!  one of the requested host. We strongly  recommend having the
//!  proxies in their own virtual server with a dedicated
//!  IP and / or port.</strong></p>
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PRECACHE
//! cvs_version: $Id$
//

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>
#include <pcre.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_PRECACHE;
constant module_name = "Virtual Host Matcher";
constant module_doc  = "This module adds support for ip-less virtual hosts. Add this "
	    "module to a server with an open listen port. All requests will "
	    "be matched exactly against all your virtual servers. You can also "
	    "optionally write regexp rules to rewrite the host before doing "
	    "the exact matching. This module replaces the old IP-less virtual "
	    "hosting module, which used fuzzy matching which often gave a bad "
	    "result"
	    "<p><b>Please note that  ip less hosting "
	    "doesn't work well together with proxies. The reason is that the "
	    "host header sent isn't the one of the proxy server, but the "
	    "one of the requested host. We strongly  recommend having the "
	    "proxies in their own virtual server with a dedicated "
	    "IP and / or port.</b>";
constant module_unique = 1;

#define IP_LESS_DEBUG

#if defined(DEBUG) || defined(IP_LESS_DEBUG)
# define DWERR(x) werror("HOSTMATCH: %s\n", x)
#else
# define DWERR(x)
#endif

mapping config_cache = ([ ]);
mapping rewrite_info = ([]);
int is_ip(string s)
{
  return(replace(s,
		 ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "." }),
		 ({ "","","","","","","","","","","" })) == "");
}

void create() {
  defvar("matches", "",  "Regular expression rewrite rules",
	 TYPE_TEXT_FIELD, 
	 "Rules used to rewrite the URL to match an existing virtual server. "
	 "Use this if you have hosts with multiple names or for example want "
	 "to do wildcard DNS urls, like www.user.host.com. Examples: <p>"
	 "<pre>"
	 "	^www\\.[^\\.]*\\.domain\\.com	users.domain.com<br>"
	 "	sales\\.theweb\\.com		www.theweb.com<br>"
	 "	.*\\.whatever\\.com		www.whatever.com<br>"
	 "	.*				www.default.com<br>"
	 "</pre></p>"
	 "The latter will match every host not previously matched and can "
	 "be used for setting a default site. <b>This includes all requests "
	 "that lack a host header!</b> If a request is done to an ip-address "
	 "and the Host header is sent, matching will be done as usual. "
	 "Also note that all matching is done on the lower case host header "
	 "without the :port part.");
}

array regexp_pairs;

void precache_rewrite(object id)
{
  object old_conf = id->conf;
  string host = id->host || "COWFISHSTEW";
  sscanf(host, "%s:", host);

  if(config_cache[host]) {
    id->conf = config_cache[host];
  } else {
    foreach(regexp_pairs, array pair) {
      if(pair[0]->match(host)) {
	rewrite_info[id->host||"No Host header"] = pair[1..];
	host = pair[1];
	break;
      }
    }
    foreach(caudium->configurations, object s) {
      string h = lower_case(s->query("MyWorldLocation"));
      if(!sscanf(h, "http://%s/", h)) {
	// Not a http url -> no virtual hosting possible
	continue;
      }
      sscanf(h, "%s:", h);
      if(h == host) {
	id->conf = s;
	break;
      }
    }
    config_cache[host] = id->conf;
  }
  if (id->conf != old_conf && id->rawauth) {
    /* Need to re-authenticate with the new server */    
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

  // remove the request from the 'host' server
  old_conf->requests--;
  // add the request to the 'destination' server
  id->conf->requests++;

  return;
}

void start()
{
  array lines;
  config_cache = ([]);
  rewrite_info = ([]);  
  regexp_pairs = ({});
  lines = QUERY(matches) / "\n" - ({});
  foreach(lines, string l)
  {
    array pair = replace(l, "\t", " ") / " " - ({""});
    object(Regexp) reg;
    if(sizeof(pair) != 2)
    {
      DWERR(sprintf("Invalid line: %s", l));
      continue;
    }
    pair[0] = lower_case(pair[0]);
    pair[1] = lower_case(pair[1]);
    if(catch(reg = Regexp(pair[0])) || !reg) {
      DWERR(sprintf("Failed to parse regexp: %s", pair[0]));
      continue;
    }
    regexp_pairs += ({ ({ reg, pair[1], pair[0] }) });
  }
}

string status()
{
  //  return "Blaha";
  string res="<table><tr bgcolor=lightblue><td>Original</td><td>Rewritten to</td><td>Matching Rule</td></tr>";
  foreach(sort(indices(rewrite_info)), string s ) {
    res += "<tr><td>"+html_encode_string(s)+
      "</td><td>"+html_encode_string(rewrite_info[s][0])+"</td><td>"+
      html_encode_string(rewrite_info[s][1])+"</td></tr>";
  }
  return res+"</table>";
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: matches
//! Rules used to rewrite the URL to match an existing virtual server. Use this if you have hosts with multiple names or for example want to do wildcard DNS urls, like www.user.host.com. Examples: <p><pre>	^www\.[^\.]*\.domain\.com	users.domain.com<br />	sales\.theweb\.com		www.theweb.com<br />	.*\.whatever\.com		www.whatever.com<br />	.*				www.default.com<br /></pre></p>The latter will match every host not previously matched and can be used for setting a default site. <b>This includes all requests that lack a host header!</b> If a request is done to an ip-address and the Host header is sent, matching will be done as usual. Also note that all matching is done on the lower case host header without the :port part.
//!  type: TYPE_TEXT_FIELD
//!  name: Regular expression rewrite rules
//
