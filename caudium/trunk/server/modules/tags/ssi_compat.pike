/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
 */
/*
 * $Id$
 */

//! module: SSI Compat Tags
//!   This module provide SSI compatibility tags from Apache (tags
//!   starting with &lt;!--#).
//!   Apache to Caudium.
//! type: MODULE_PARSER
//! cvs_version: $Id$"
//! inherits: module
//! inherits: caudiumlib

#define RXMLTAGS id->conf->get_provider("rxml:tags")

#include <config.h>
#include <module.h>
inherit "module";
inherit "caudiumlib";

// TODO: Is this needed.. ?
constant language = caudium->language;

constant cvs_version   = "$Id$";
constant thread_safe   = 1;
constant module_type   = MODULE_PARSER;
constant module_name   = "SSI Compat Tags";
constant module_doc    = "This module provide SSI compatibility tags from"
                         " Apache (tags starting with &lt;!--#).";
constant module_unique = 1;

void create() {

  defvar("virtonly", 1, "Support only virtual acccess", TYPE_FLAG,
         "If set, Caudium will accept only \"virtual\" method to #include "
         "SSI extensions. Warning allow this can "
         "have some big security problems for public websites.");

  defvar("exec", 0, "SSI execute command", 
	 TYPE_FLAG, "If set, Caudium "
	 "will accept NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt;. "
	 "Note that this will allow your users to execute arbitrary "
	 "commands.");

#if constant(getpwnam)
  array nobody = getpwnam("nobody") || ({ "nobody", "x", 65534, 65534 });
#else /* !constant(getpwnam) */
  array nobody = ({ "nobody", "x", 65534, 65534 });
#endif /* constant(getpwnam) */

  defvar("execuid", nobody[2] || 65534, "SSI execute command uid",
	 TYPE_INT,
	 "UID to run NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands with." );

  defvar("execgid", nobody[3] || 65534, "SSI execute command gid",
	 TYPE_INT,
	 "GID to run NCSA / Apache &lt;!--#exec cmd=\"XXX\" --&gt; "
	 "commands with.");
}


//! tag: !--#exec
//!  Compat &lt;!--#exec tag 
//! attribute: cache
//!  Explicitly cache the results.
//! attribute: cmd
//!  Execute a command (like "/bin/echo foo" for example) 
//! attribute: help
//!  Give some help
string tag_compat_exec(string tag,mapping m,object id,object file,
		       mapping defines) {
  if(m->help) 
    return ("See the Apache documentation. This tag is more or less equivalent"
	    " to &lt;insert file=...&gt;, but you can run any command. Please "
	    "note that this can present a severe security hole.");

  if(m->cgi) {
    if(!m->cache)
      m->nocache = "yes";
    m->file = _Roxen.http_decode_string(m->cgi);
    m_delete(m, "cgi");
    object rxmltags_module = RXMLTAGS;
    if(objectp(rxmltags_module)) 
      return rxmltags_module->tag_insert(tag, m, id, file, defines);
    else
      return "<!-- No RXML Tags Module ??? -->";
  }

  if(m->cmd) {
    if(QUERY(exec)) {
      string tmp;
      tmp=id->conf->query("MyWorldLocation");
      sscanf(tmp, "%*s//%s", tmp);
      sscanf(tmp, "%s:", tmp);
      sscanf(tmp, "%s/", tmp);
      string user;
      user="Unknown";
      if(id->user)
	user=id->user->username;
      string addr=id->remoteaddr || "Internal";
      NOCACHE();
      return popen(_Roxen.http_decode_string(m->cmd),
		   getenv()
		   | build_caudium_env_vars(id)
		   | build_env_vars(id->not_query, id, 0),
		   QUERY(execuid) || -2, QUERY(execgid) || -2);
    } else {
      return "<b>Execute command support disabled."
	"<!-- Check \"Main RXML Parser\"/\"SSI support\". --></b>";
    }
  }
  return "<!-- exec what? -->";
}

//! tag: !--#config
//!   Compat @lt;!--#config tag
//! attribute: help
//!   Give some help
string tag_compat_config(string tag,mapping m,object id,object file,
			 mapping defines)
{
  if(m->help || m["help--"]) 
    return ("The SSI #config tag is used to set configuration parameters "
       "for other SSI tags. The tag takes one or more of the following "
       "attributes: <tt>sizefmt</tt>=<i>size_format</i>, "
       "<tt>timefmt</tt>=<i>time_format</i>, <tt>errmsg</tt>=<i>error</i>. "
       "The size format is either 'bytes' (plain byte count) or 'abbrev' "
       "(use size suffixes), the time format is a <tt>strftime</tt> format "
       "string, and the error message is the message to return if a parse "
       "error is encountered.");

  if (m->sizefmt) {
    if ((< "abbrev", "bytes" >)[lower_case(m->sizefmt||"")]) {
      defines->sizefmt = lower_case(m->sizefmt);
    } else {
      return(sprintf("Unknown SSI sizefmt:%O", m->sizefmt));
    }
  }
  if (m->errmsg) {
    // FIXME: Not used yet.
    defines->errmsg = m->errmsg;
  }
  if (m->timefmt) {
    // FIXME: Not used yet.
    defines->timefmt = m->timefmt;
  }
  return "";
}

//! tag: !--#include
//!  Compat &lt;#--#include tag
//! attribute: help
//!  Give some help
//! attribute: virtual
//!  Insert a virtual file (like RXML tag &lt;insert file= ... &gt;)
//! attribute: file
//!  Insert a real file on real FS...
string tag_compat_include(string tag,mapping m,object id,object file,
			  mapping defines) {
  if(m->help || m["help--"]) 
    return ("The SSI #include tag is more or less equivalent to the RXML "
            "&lt;INSERT&gt; tag. ");

  if(m->virtual) {
    m->file = m->virtual;
    object rxmltags_module = RXMLTAGS;
    if(objectp(rxmltags_module)) 
      return rxmltags_module->tag_insert("insert", m, id, file, defines);
    else
      return "<!-- No RXML Tags Module ??? -->";
  }

  if(m->file && !QUERY(virtonly)) {
    mixed tmp;
    string fname1 = m->file;
    string fname2;
    if(m->file[0] != '/') {
      if(id->not_query[-1] == '/')
	m->file = id->not_query + m->file;
      else
	m->file = ((tmp = id->not_query / "/")[0..sizeof(tmp)-2] +
		   ({ m->file }))*"/";
      fname1 = id->conf->real_file(m->file, id);
      if ((sizeof(m->file) > 2) && (m->file[sizeof(m->file)-2..] == "--")) {
	fname2 = id->conf->real_file(m->file[..sizeof(m->file)-3], id);
      }
    } else if ((sizeof(fname1) > 2) && (fname1[sizeof(fname1)-2..] == "--")) {
      fname2 = fname1[..sizeof(fname1)-3];
    }
    return((fname1 && Stdio.read_bytes(fname1)) ||
	   (fname2 && Stdio.read_bytes(fname2)) ||
	   ("<!-- No such file: " +
	    (fname1 || fname2 || m->file) +
	    "! -->"));
  }
  return "<!-- What? -->";
}

//! tag: !--#echo
//!   Compat &lt;!--#echo tag
string tag_compat_echo(string tag,mapping m,object id,object file,
			  mapping defines) {
  object rxmltags_module = RXMLTAGS;
  if(objectp(rxmltags_module))
    return rxmltags_module->tag_echo(tag, m, id, file, defines);
  else
    return "<!-- No RXML Tags module ??? -->";
}

//! tag: !--#set
//!   Compat &lt;!--#set tag
//! attribute: var
//!   The var name to set
//! attribute: value
//!   The value to set into the variable
string tag_compat_set(string tag,mapping m,object id,object file,
			  mapping defines) {
  if(m->var && m->value) {
    if(!id->misc->ssi_variables)
      id->misc->ssi_variables = ([]);
    id->misc->ssi_variables[m->var] = m->value;
  }
  return "";
}


//! tag: !--#fsize
//!   Compat &lt;!--#fsize tag

//! tag: !--#flastmod
//!   Compat &lt;!--#flastmod tag
string tag_compat_fsize(string tag,mapping m,object id,object file,
			mapping defines) {
  if(m->help || m["help--"]) 
    if (tag == "!--#fsize")
      return ("Returns the size of the file specified (as virtual=... or file=...)");
    else
      return ("Returns the last modification date of the file specified (as virtual=... or file=...)");
  
  if(m->virtual && sizeof(m->virtual)) {
    m->virtual = _Roxen.http_decode_string(m->virtual);
    if (m->virtual[0] != '/') {
      // Fix relative path.
      m->virtual = combine_path(id->not_query, "../" + m->virtual);
    }
    m->file = id->conf->real_file(m->virtual, id);
    m_delete(m, "virtual");
  } else if (m->file && sizeof(m->file) && (m->file[0] != '/')) {
    // Fix relative path
    m->file = combine_path(id->conf->real_file(id->not_query, id) || "/", "../" + m->file);
  }
  if(m->file) {
    array s;
    s = file_stat(m->file);
    CACHE(5);
    if(s) {
      if(tag == "!--#fsize") {
	if(defines->sizefmt=="bytes")
	  return (string)s[1];
	else
	  return sizetostring(s[1]);
      } else {
	return strftime(defines->timefmt || "%c", s[3]);
      }
    }
    return "Error: Cannot stat file";
  }
  return "<!-- No file? -->";
}

// Tags provided
mapping query_tag_callers () {
  return ([ "!--#echo":     tag_compat_echo,
            "!--#exec":     tag_compat_exec,
            "!--#flastmod": tag_compat_fsize,
            "!--#set":      tag_compat_set,
            "!--#fsize":    tag_compat_fsize,
            "!--#include":  tag_compat_include,
            "!--#config":   tag_compat_config, 
          ]);
}


/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: virtonly
//! If set, Caudium will accept only "virtual" method to #include SSI extensions. Warning allow this can have some big security problems for public websites.
//!  type: TYPE_FLAG
//!  name: Support only virtual acccess
//
//! defvar: exec
//! If set, Caudium will accept NCSA / Apache &lt;!--#exec cmd="XXX" --&gt;. Note that this will allow your users to execute arbitrary commands.
//!  type: TYPE_FLAG
//!  name: SSI execute command
//
//! defvar: execuid
//! UID to run NCSA / Apache &lt;!--#exec cmd="XXX" --&gt; commands with.
//!  type: TYPE_INT
//!  name: SSI execute command uid
//
//! defvar: execgid
//! GID to run NCSA / Apache &lt;!--#exec cmd="XXX" --&gt; commands with.
//!  type: TYPE_INT
//!  name: SSI execute command gid
//
