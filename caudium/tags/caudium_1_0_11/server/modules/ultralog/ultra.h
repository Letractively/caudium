/* This is very much -*- pike -*- code
   "$Id$";
*/
#define V1 ({ "line_chart", "bar_chart", "table", "export" })
#define V2 ({ "table", "export" })
#define V3 ({ "table", "export" }), S_DATERANGE
#define V4 ({ "line_chart", "bar_chart",  "table", "export" }), S_DATERANGE 

#define S_NONE      0
#define S_MATCHBOX  1
#define S_DATERANGE 2
#define S_NOTYEAR   4

#define MAXENTRY 100
constant views =
([
  "hits_per_hour" : ({"Hits and page loads per hour", V4 }),
  "pages_per_hour" : ({"Page loads per hour", V4 }),
  "sessions_per_hour" : ({"Visitor sessions per hour", V4 }),
  "kb_per_hour" : ({"Bandwidth usage per hour", V4 }),
  "hosts_per_hour" : ({"Unique hosts per hour", V4 }),
  
  "hits_per_day" : ({"Hits and page loads per day", V4}),
  "pages_per_day" : ({"Page loads per day", V4}),
  "sessions_per_day" : ({"Visitor sessions per day", V4}),
  "kb_per_day" : ({"Bandwidth usage per day", V4}),
  "hosts_per_day" : ({"Unique hosts per day", V4 }),

  "hits_per_month" : ({"Hits and page loads per month", V4}),
  "pages_per_month" : ({"Page loads per month", V4}),
  "sessions_per_month" : ({"Visitor sessions per month", V4}),
  "kb_per_month" : ({"Bandwidth usage per month", V4}),
  "hosts_per_month" : ({"Unique hosts per month", V4 }),

  "pages" : ({"Most popular pages", V2 , S_MATCHBOX|S_NOTYEAR }),
  "dirs" : ({"Most popular directories", V2, S_MATCHBOX }),
  "hits": ({"Most common non-pages", V2, S_MATCHBOX|S_NOTYEAR }),
  "redirs": ({"Most common redirect paths", V2, S_MATCHBOX|S_NOTYEAR }),

  "codes" : ({"Return code summary", V3, S_DATERANGE }),
  "errorpages" : ({"Error pages", V2,
		     S_NOTYEAR|S_MATCHBOX}),
 
  "sites" : ({"Host statistics", V2, S_NOTYEAR}),
  "domains" : ({"2nd level domain statistics", V2, S_NOTYEAR|S_MATCHBOX}),
  "topdomains" : ({"Country statistics", V2, S_MATCHBOX}),

  "refs" : ({"Referrers", V2, S_NOTYEAR|S_MATCHBOX }),
  "refsites" : ({"Referring sites", V2, S_NOTYEAR|S_MATCHBOX }),
  "errefs" : ({"Error Page Referrers", V2, S_NOTYEAR }),
  "refto" : ({"Referred Pages", V2, S_NOTYEAR }),

  "auth_users": ({"Authenticated Users", V2, S_NONE}), 

  "agent": ({"Most Common Browsers", V2, S_NOTYEAR }), 
  "agent_os": ({"Most Common Browsers / OS", V2, S_NOTYEAR }), 
  "agent_os_ver": ({"Most Common Browsers / Versions / OS ", V2, S_NOTYEAR }), 
  "agent_ver": ({"Most Common Browsers / Versions", V2, S_NOTYEAR }), 
  "common_os": ({"Most Common OS", V2, S_NOTYEAR }), 
  "agents": ({"Unparsed Raw User Agents", V2, S_NOTYEAR|S_MATCHBOX }), 

  "sess_hour_hits"  : ({"Average hits and pages per session", V1, S_DATERANGE}),
  "sess_day_hits"   : ({"Average hits and pages per session", V1, S_DATERANGE}),
  "sess_month_hits" : ({"Average hits and pages per session", V1, S_DATERANGE}),

  "sess_hour_len" : ({"Average time per session", V1, S_DATERANGE}),
  "sess_month_len" : ({"Average time per session", V1, S_DATERANGE}),
  "sess_day_len" : ({"Average time per session", V1, S_DATERANGE}),
]);

constant view_names = ({
  "pages_per_hour",
  "hits_per_hour",
  "kb_per_hour", 
  
  "pages_per_day",
  "hits_per_day",
  "kb_per_day", 
    
  "pages_per_month",
  "hits_per_month",
  "kb_per_month", 
    
  "pages",
  "dirs",
  "hits",
  "redirs",
    
  "codes",
  "errorpages",

  "sites",
  "domains",
  "topdomains",
  "hosts_per_hour",
  "hosts_per_day",
  "hosts_per_month",

  "refs",
  "refsites",
  "errefs",
  "refto",
#if 0
  "auth_users",
  "screen_depth",
  "screen_res",
#endif
  
  "common_os", 
  "agent", 
  "agent_os", 
  "agent_ver", 
  "agent_os_ver", 
  "agents",
    
  "sessions_per_hour",
  "sessions_per_day",
  "sessions_per_month",

  "sess_day_hits",
  "sess_month_hits",
  "sess_hour_hits",

  "sess_hour_len",
  "sess_day_len",

  "sess_month_len",

#ifdef USE_SESSIONS
  "start_pages",
  "exit_pages",
  "one_pages",
#endif
});
#undef V1
#undef V2
#undef V3

constant err_msgs =
([
  // Informational
  100:"100 Continue",
  101:"101 Switching Protocols",

  // Successful
  200:"200 OK",
  201:"201 Created",
  202:"202 Accepted",
  203:"203 Non-Authoritative Information",
  204:"204 No Content",
  205:"205 Reset Content",
  206:"206 Partial Content",

  // Redirection
  300:"300 Multiple Choices",
  301:"301 Permanent relocation",
  302:"302 Temporary relocation",
  303:"303 See Other",
  304:"304 Not modified",
  305:"305 Use Proxy",

  // Client Error
  400:"400 Bad request",
  401:"401 Access denied",
  402:"402 Payment required",
  403:"403 Forbidden",
  404:"404 Not Found",
  405:"405 Method not allowed",
  406:"406 Not Acceptable",
  407:"407 Proxy Authentication Needed",
  408:"408 Request Timeout",
  409:"409 Conflict",
  410:"410 This document is no more",
  411:"411 Length Required",
  412:"412 Precondition Failed",
  413:"413 Request Entity Too Large",
  414:"414 Request-URI Too Large",
  415:"415 Unsupported Media Type",
  416:"416 Requested Range Not Satisfiable",

  // Internal Server Errors
  500:"500 Internal Server Error", 
  501:"501 Not Implemented",
  502:"502 Bad Gateway",
  503:"503 Service Unavailable",
  504:"504 Gateway Timeout",
  505:"505 HTTP Version Not Supported",
]);
