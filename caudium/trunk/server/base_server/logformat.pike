/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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

/* This code takes a log file format string and returns a program ready to
 * compile. It's used to make logging faster
 */
static constant codes =
([ "ipnumber"     : "id->remoteaddr",
   "binipnumber"  : "host_ip_to_int(id->remoteaddr)",
   "cerndate"     : "cern_http_date(time(1))",
   "bindate"      : "time(1)",
   "method"       : "(string)id->method",
   "resource"     : "http_encode_string((string)id->not_query)",
   "fullresource" : "(string)id->raw_url",
   "protocol"     : "(string)id->prot",
   "response"     : "(file->error||200)",
   "binresponse"  : "(file->error||200)",
   "length"       : "(string)(file->len>=0?file->len:\"-\")",
   "binlength"    : "(file->len)",
   "referer"      : "(id->referrer||\"-\")",
   "useragent"    : "http_encode_string(id->useragent)",
   "agentunquoted": "id->useragent",
   "user"         : "extract_user(id->realauth)",
   "userid"       : "(string)id->cookies->CaudiumUserID",
   "requesttime"  : "(time(1)-id->time)",
]);

mapping specformat = ([
  "binlength": "%4c",
  "bindate"  : "%4c",
  "response" : "%d",
  "binresponse": "%2c",
  "requesttime": "%d"
]);

static constant prg_prefix = "inherit \"caudiumlib\"; inherit \"logformat_support.pike\";";

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
			  "$user_id", "$request-time" }), 
		       ({ "%%", "\\\"", "",
			  "$ipnumber", "$binipnumber", "$cerndate",
			  "$bindate",  "$fullresource", "$binresponse",
			  "$binlength","$useragent", "$agentunquoted",
			  "$userid", "$requesttime" }) );
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

