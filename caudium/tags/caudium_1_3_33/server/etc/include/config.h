/* -*- Pike -*-
 * $Id$
 *
 * User configurable things not accessible from the normal
 * configuration interface. Not much, but there are some things..
 * Also see performance.h for more configurable options.
 */

#include <extra_config.h>
#include <performance.h>
#ifndef _ROXEN_CONFIG_H_
#define _ROXEN_CONFIG_H_


#if efun(thread_create)
// Some OS's (eg Linux) can get severe problems (PANIC)
// if threads are enabled.
//
// If it works, good for you. If it doesn't, too bad.
#ifndef DISABLE_THREADS
#ifdef ENABLE_THREADS
# define THREADS
#endif /* ENABLE_THREADS */
#endif /* !DISABLE_THREADS */
#endif /* efun(thread_create) */

/* Lev  What                          Same as defining
 *----------------------------------------------------
 *   1  Module                        MODULE_DEBUG
 *   2  HTTP                          HTTP_DEBUG
 *   8  Hostname                      HOST_NAME_DEBUG
 *   9  Cache                         CACHE_DEBUG
 *  10  Configuration file handling   CONFIG_DEBUG
 *  20  Socket opening/closing        SOCKET_DEBUG
 *  21  Module: Filesystem            FILESYSTEM_DEBUG
 *  22  Module: Proxy                 PROXY_DEBUG
 *  23  Module: Gopher proxy          GOPHER_DEBUG
 *  40  _More_ cache debug            -
 * >40  Probably even more debug
 * 
 * Each higher level also include the debug of the lower levels.
 * Use the defines in the rightmost column if you want to enable
 * specific debug features.  
 * 
 * You can also start roxen with any debug enabled like this:
 * bin/pike -DMODULE_DEBUG -m etc/master.pike roxenloader
 * 
 * Some other debug thingies:
 *  HTACCESS_DEBUG
 *  SSL_DEBUG
 *  NEIGH_DEBUG
 */

// #define MIRRORSERVER_DEBUG
// #define HTACCESS_DEBUG

/* #undef DEBUG_LEVEL */
#ifndef DEBUG_LEVEL
#define DEBUG_LEVEL DEBUG
#endif

#if DEBUG_LEVEL > 19
#ifndef SOCKET_DEBUG
#define SOCKET_DEBUG
#endif
#endif

#ifdef DEBUG
// Make it easier to track what FD's are doing, to be able to find FD leaks.
#define FD_DEBUG
#endif

/* Should we use sete?id instead of set?id?.
 * There _might_ be security problems with the sete?id functions.
 */

#define SET_EFFECTIVE 

#endif /* if _ROXEN_CONFIG_H_ */
