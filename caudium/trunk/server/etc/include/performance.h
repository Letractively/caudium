/* -*- Pike -*-
 * $Id$
 *
 * Performance related defines. Also used to enable/disable Roxen
 * compat stuff that's disable for performance reasons.
 */

#ifndef _PERFORMANCE_H_
#define _PERFORMANCE_H_

/* Enable extra Roxen 1.3 compatibility. This is mainly performance issues.
 * See the file README.compatibility for a complete list of changes related
 * to this define.
 */

#define EXTRA_ROXEN_COMPAT


/* Enable support for HTTP/0.9. This is an extremely minor optimization. If
 * you need HTTP/0.9, enable this one. Will not work with http2.pike...
 */

#undef SUPPORT_HTTP_09


/* Enable the request memory cache. This greatly speeds up requests. It's
 * worth it for most sites. Only used by the experimental http2 protocol.
 */
#define ENABLE_RAM_CACHE


/* Do we want module level deny/allow security (IP-numbers and usernames). 
 * This is a minor optimzation. You can uncomment this for stupid servers
 * where module level security isn't needed.
 */

#define MODULE_LEVEL_SECURITY

/* If this is disabled, the server won't parse the supports string. This might
 * make the server somewhat faster. Since supports parsing is cached, the
 * difference should be rather slim. Still, if you don't need the supports,
 * uncomment this define.
 */

#define ENABLE_SUPPORTS


/* Define this if you don't want Caudium to use DNS. Note: This is a
 * minor speed optimization It's mainly used to reload network / dns
 * server load on busy servers. Please note that option turns off ALL
 * ip -> hostname and hostname -> ip conversion. Thus you can't use if
 * if you want to run a proxy or domain/host name based security. See
 * NO_REVERSE_LOOKUP below.
 */

#undef NO_DNS


/* This option turns of all ip->hostname lookups. However the
 * hostname->ip lookups are still functional. This _is_ usable
 * if you run a proxy, but still breaks host based authentication.
 */

#undef NO_REVERSE_LOOKUP


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
#define URL_MODULES

/* Basically, should it be o.k. to return "string" as a member of
 * the result mapping? This is only for compability.
 * Normally: ([ "data":long_string, "type":"text/html" ]), was
 * ([ "string":long_string, "type":"text/html" ]), please ignore..
 * Do not use this, unless you _really_ want to make your
 * modules unportable :-)
 */
#undef API_COMPAT

#endif
