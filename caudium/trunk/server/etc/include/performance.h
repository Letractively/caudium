/* -*- Pike -*-
 * $Id$
 *
 * Performance related defines. Also used to enable/disable Roxen
 * compat stuff that's disable for performance reasons.
 */

#ifndef _PERFORMANCE_H_
#define _PERFORMANCE_H_

/* Define this for maximum performance. Handy for benchmarking. */

/* #define MAX_PERFORMANCE */

/* Enable extra Roxen 1.3 compatibility. This is mainly performance issues.
 * See the file README.compatibility for a complete list of changes related
 * to this define.
 */

#ifndef MAX_PERFORMANCE
# define EXTRA_ROXEN_COMPAT
#endif

/* Enable support for HTTP/0.9. This is an extremely minor optimization. If
 * you need HTTP/0.9, enable this one. Will not work with http2.pike...
 */

#undef SUPPORT_HTTP_09


/* Enable the request memory cache. This greatly speeds up requests. It's
 * worth it for most sites. Only used by the experimental http2 protocol.
 */

#ifndef NO_RAM_CACHE
# define ENABLE_RAM_CACHE
#endif

/* Do we want module level deny/allow security (IP-numbers and usernames). 
 * This is a minor optimzation. You can uncomment this for stupid servers
 * where module level security isn't needed.
 */

#ifndef MAX_PERFORMANCE
# define MODULE_LEVEL_SECURITY
#endif

/* If this is disabled, the server won't parse the supports string. This might
 * make the server somewhat faster. Since supports parsing is cached, the
 * difference should be rather slim. Still, if you don't need the supports,
 * uncomment this define.
 */

#ifndef MAX_PERFORMANCE
# define ENABLE_SUPPORTS
#endif


/* Define this if you don't want Caudium to use DNS. Note: This is a
 * minor speed optimization It's mainly used to reload network / dns
 * server load on busy servers. Please note that option turns off ALL
 * ip -> hostname and hostname -> ip conversion. Thus you can't use if
 * if you want to run a proxy or domain/host name based security. See
 * NO_REVERSE_LOOKUP below.
 */


#undef NO_DNS

#ifdef MAX_PERFORMANCE
# ifndef NO_DNS
#  define NO_DNS
# endif
#endif


/* This option turns of all ip->hostname lookups. However the
 * hostname->ip lookups are still functional. This _is_ usable
 * if you run a proxy, but still breaks host based authentication.
 */

#undef NO_REVERSE_LOOKUP


/* Should we allow the config interface to lookup the hostnames of
 * all ip-addresses on the machine? This is the default, but if your
 * machine has a large number of virtual interfaces, we recommend that you
 * disable this feature. The reason being that it takes a long time to do the
 * ip -> hostname lookups. It's done for cosmetical reasons only.
 */

#define CONFIG_IF_IP_LOOKUPS


/* Should we use sete?id instead of set?id?.
 * There _might_ be security problems with the sete?id functions.
 */

#define SET_EFFECTIVE 

/* Compatibility with some Really Old Server. Quite possibly not even
 * used at all anymore.
 */
#undef COMPAT

/*
 * Should support for URL modules be included? This includes the
 * htaccess module for example.  
 */
#ifndef MAX_PERFORMANCE
# define URL_MODULES
#endif

/* Basically, should it be o.k. to return "string" as a member of
 * the result mapping? This is only for compability.
 * Normally: ([ "data":long_string, "type":"text/html" ]), was
 * ([ "string":long_string, "type":"text/html" ]), please ignore..
 * Do not use this, unless you _really_ want to make your
 * modules unportable :-)
 */
#undef API_COMPAT

/*
 * The maximum body size the server should read upon a post
 * request. -1 means unlimited and 0 means the body is completely
 * ignored. The default value should be a reasonable value.
 */
#ifndef POST_MAX_BODY_SIZE
#define POST_MAX_BODY_SIZE 1024*16
#endif

/*
 * Load all configurations (virtual servers and their modules) at
 * Caudium startup.
 * This is not enabled for performance reasons (eg Caudium with lots of
 * virtuals servers that are mostly unused.).
 */
#undef LOAD_CONFIGS_STARTUP


/*
 * Use spider.parse_html() and spider.parse_html_lines() instead
 * of using Parse.HTML. Se this if you have some issues with this
 * new routine. And don't forget to open a bug at our bug
 * database : http://caudium.net/community/bugtraq.rxml
 */
#undef OLD_SPIDER

/*
 * Compare results between old spider and Parse.HTML return.
 * Used only if OLD_SPIDER is not set.
 */
#define COMPARE_SPIDER

/*
 * Setting this will stop warnings in Caudium logfile about
 * API compatibility issues.
 *
 * This not set because this can help developpers to make
 * more up to date modules and code, but it can slow down
 * a bit Caudium because of heavy usage of backtrace() pike
 * function to help find in which file and which line the 
 * compat API was called.
 */
#undef SILENT_COMPAT

#endif
