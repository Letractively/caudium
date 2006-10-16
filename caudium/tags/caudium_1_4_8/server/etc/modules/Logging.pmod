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
 */
/*
 * $Id$
 */

// Really write an entry to the log.
void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  else
    host = (host/" ")[0]; // In case it's an IP we don't want the port.
  if(fun) fun(replace(rest, "$host", host));
}

// Logging format support functions.
inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";

  return tmp[0];      // username only, no password
}


class Logger {
  // The logging format used.
  mapping (string:string) log_format = ([]);
  
  //! The objects for each logging format. Each of the objects has the function
  //! format_log which takes the file and id object as arguments and returns
  //! a formatted string. the hashost variable is 1 if there is a $host that
  //! needs to be resolved.
  mapping (string:object) log_format_objs = ([]);

  static constant codes =
  ([ "ipnumber"     : "id->remoteaddr",
     "binipnumber"  : "Logging.host_ip_to_int(id->remoteaddr)",
     "cerndate"     : "Caudium.HTTP.cern_date(id->time)",
     "bindate"      : "time(1)",
     "method"       : "(string)id->method",
     "resource"     : "Caudium.http_encode_string((string)id->not_query)",
     "fullresource" : "(string)id->raw_url",
     "protocol"     : "(string)id->prot",
     "response"     : "(file->error||200)",
     "binresponse"  : "(file->error||200)",
     "length"       : "(string)(file->len>=0?file->len:\"-\")",
     "binlength"    : "(file->len)",
     "referer"      : "(id->referrer||\"-\")",
     "useragent"    : "Caudium.http_encode_string(id->useragent)",
     "agentunquoted": "id->useragent",
     "siteid"       : "id->site_id",
     "user"         : "Logging.extract_user(id->realauth)",
     "userid"       : "(string)id->cookies->CaudiumUserID",
     "requesttime"  : "(time(1)-id->time)",
  ]);

  static constant prg_prefix = "inherit \"caudiumlib14\";";

  // Parse the logging format strings.
  inline string fix_logging(string s)
  {
    string pre, post, c;
    sscanf(s, "%*[\t ]", s);
    s = replace(s, ({"\\t", "\\n", "\\r" }), ({"\t", "\n", "\r" }));

    // FIXME: This looks like a bug.
    // Is it supposed to strip all initial whitespace, or do what it does?
    //  /grubba 1997-10-03
    while(s[0] == ' ') s = s[1..];
    while(s[0] == '\t') s = s[1..];
    while(sscanf(s, "%s$char(%d)%s", pre, c, post)==3)
      s=sprintf("%s%c%s", pre, c, post);
    while(sscanf(s, "%s$wchar(%d)%s", pre, c, post)==3)
      s=sprintf("%s%2c%s", pre, c, post);
    while(sscanf(s, "%s$int(%d)%s", pre, c, post)==3)
      s=sprintf("%s%4c%s", pre, c, post);
    if(!sscanf(s, "%s$^%s", pre, post))
      s+="\n";
    else
      s=pre+post;
    return s;
  }

  void parse_log_formats(string query_log_format)
  {
    string b;
    array foo = query_log_format /"\n";
    log_format = ([]);
    log_format_objs = ([]);
    foreach(foo, b)
      if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
	log_format[(b/":")[0]] = fix_logging((b/":")[1..]*":");
    foreach(indices(log_format), string code) {
      string format = parse_log_format(log_format[code]);
      object formatter;
      if(catch(formatter = compile(format)()) || !formatter) {
	report_error(sprintf("Failed to compile log format // %s //.",
			     format));
      }
      log_format_objs[code] = formatter;
    }
  }

  mapping specformat = ([
    "binlength": "%4c",
    "bindate"  : "%4c",
    "response" : "%d",
    "binresponse": "%2c",
    "requesttime": "%d"
  ]);

  //! This code takes a log file format string and returns a program ready to
  //! compile. It's used to make logging faster
  string parse_log_format(string log_format) {
    string pre, kw, post;
    string format="";
    array args = ({});
    string hashost = "int hashhost = 0;";
    log_format = replace(log_format,
			 ({ "%", "\"", "\n",
			    "$ip_number", "$bin-ip_number", "$cern_date",
			    "$bin-date",  "$full_resource", "$bin-response",
			    "$bin-length","$user_agent", "$agent_unquoted",
			    "$site_id", "$user_id", "$request-time" }), 
			 ({ "%%", "\\\"", "",
			    "$ipnumber", "$binipnumber", "$cerndate",
			    "$bindate",  "$fullresource", "$binresponse",
			    "$binlength","$useragent", "$agentunquoted",
			    "$siteid", "$userid", "$requesttime" }) );
    while(strlen(log_format)) {
      switch(sscanf(log_format, "%s$%[a-z]%s", pre, kw, post)) {
       case 3:
	log_format = post;
	format += pre;
	if(kw == "host") hashost = "int hashost = 1; ";
	if(codes[kw]) { format += specformat[kw] || "%s"; args += ({codes[kw] }); }
	else { format += "$"+kw; }
	break;
       case 2:
	log_format = "";
	format += pre;
	if(kw == "host") hashost = "int hashost = 1; ";
	if(codes[kw]) { format += specformat[kw] || "%s"; args += ({codes[kw] }); }
	else { format += "$"+kw; }
	break;
       default:
	format += log_format;
	log_format = "";
      }
    }
    if(sizeof(args))
      return prg_prefix + hashost+"string format_log(mapping file, object id) { return sprintf(\""+format+"\\\n\", "+(args*", ")+"); }";
    else
      return hashost+"string format_log(mapping file, object id) { return \""+format+"\\\n\"; }";
  }
}
