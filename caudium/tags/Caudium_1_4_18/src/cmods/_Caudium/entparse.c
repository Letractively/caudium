/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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
 * $Id$
 */

/*
 * File licensing and authorship information block.
 *
 * Version: MPL 1.1/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 *
 * Marek Habersack <grendel@caudium.net>
 *
 * Portions created by the Initial Developer are Copyright (C) Marek Habersack
 * & The Caudium Group. All Rights Reserved.
 *
 * Contributor(s): David Gourdelier <vida@caudium.net>, some debugging
 *
 * Alternatively, the contents of this file may be used under the terms of
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the LGPL, and not to allow others to use your version
 * of this file under the terms of the MPL, indicate your decision by
 * deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL or the LGPL.
 *
 * Significant Contributors to this file are:
 *
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "global.h"
RCSID("$Id$");

#ifdef fp
#undef fp
#endif

#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
#include <string.h>

#include "entparse.h"

/* uncomment this to enable debug */
/* #define ENTDEBUG */

/*
 * A simple entity parser. It parses the entities of the form expressed by
 * the regexp below:
 *
 *  &name(.name)*;
 *
 * Examples:
 *
 *  &variable;
 *  &form.varname;
 *  &caudium.info.uptime;
 *
 * The parser does not resolve the entities on its own, instead it calls
 * the callback passed to it as a parameter. If the callback is missing, it
 * will output the entities verbatim without parsing them. If the callback
 * doesn't resolve the entity (returns NULL), the entity will be output
 * verbatim as well (the callback can always return "" if it wants the
 * entity not to be included in the output).
 *
 * The entity replacement returned from the callback must be dynamically
 * allocated, the parser will free(3) the memory when it is done.
 * The parser returns a dynamically allocated buffer which contains the
 * input text with all the resolved entities replaced with their values.
 *
 * The callback synopsis:
 *
 * void (*callback)(char *entname, char parts[], ENT_CBACK_RESULT *res, void *userdata);
 *
 * where:
 *
 *   entname  - the part from & to the first . or ;
 *   parts    - an array of all the names separated by . - note that this
 *              array is allocated on the stack and it will vanish as soon
 *              as the parser function exits. The strings are stored in a
 *              continuous area separated by the \0 bytes. The array is
 *              terminated by a string of length 0 (or, in other words, by
 *              two consecutive \0 bytes)
 *   res      - structure in which the callback is to put the resolved
 *              entity value or NULL
 *   userdata - the pointer passed to the parser function by the calling
 *              code.
 *   extra_args - extra arguments to give to the function
 */
ENT_RESULT* ent_parser(unsigned char *buf, unsigned long buflen,
                          entcallback cback, void *userdata, void *extra_args)
{
  ENT_RESULT        *retval;
  ENT_CBACK_RESULT   cbackres;
  unsigned char     *tmp = buf;
  unsigned long      curpos = 0, curlen = 0;
  unsigned char      in_entity = 0;
  unsigned long      entnamelen, entpartslen, entlen, tmplen;
  unsigned char      entfullname[ENT_MAX_ENTSIZE + 1];
  unsigned char      entname[ENT_MAX_ENTSIZE + 1];
  unsigned char      entparts[ENT_MAX_ENTSIZE + 1];
  
  retval = (ENT_RESULT*)malloc(sizeof(*retval));
  if (!retval)
    return NULL;

#ifdef ENTDEBUG
  printf(">>%s<<\n", buf);
  printf("parsing %d bytes\n", buflen);
#endif
  retval->errcode = ENT_ERR_OK;
  retval->buflen = 0;
  retval->buf = NULL;
  
  if (!buf) {
    retval->errcode = ENT_ERR_INVPARM;
    return retval;
  }
  
  if (buflen >= ULONG_MAX || (buflen + buflen/3) > ULONG_MAX) {
    retval->errcode = ENT_ERR_BUFTOOLONG;
    return retval;
  }
  
  retval->buflen = buflen + buflen/3;
  retval->buf = (unsigned char*)malloc(retval->buflen * sizeof(*retval->buf));
  if (!retval->buf) {
    retval->buflen = 0;
    retval->errcode = ENT_ERR_OOM;
    return retval;
  }

  memset(retval->buf, 0, retval->buflen);
  entnamelen = entpartslen = entlen = 0;
  cbackres.buf = NULL;
  cbackres.buflen = 0;
  
  while(tmp && curpos < buflen) {

#ifdef ENTDEBUG
printf("considering %d of %d\n", curpos, buflen);
#endif
    switch (*tmp) {
        case '&':
#ifdef ENTDEBUG
printf("got an ampersand.\n");
#endif
          if (*(tmp+1) == '&') {
            tmp++; curpos++;
            goto append_data;
          }
          if (!cback)
            goto append_data;

          memset(entname, 0, sizeof(entname));
          memset(entparts, 0, sizeof(entparts));
          memset(entfullname, 0, sizeof(entfullname));
          entlen = entnamelen = entpartslen = 0;
          in_entity = 1;
          tmp++; curpos++;
          continue;

        case ';':

#ifdef ENTDEBUG
printf("got a semicolon.\n");
#endif
          if (!cback || !in_entity)
          {
            goto append_data;
          }
          tmp++;
          in_entity = 0;
          cback(entname, entparts, &cbackres, userdata, extra_args);
          if (!cbackres.buf)
            cbackres.buflen = entlen;
          goto append_data;
          
          continue;

        case '.':

#ifdef ENTDEBUG
printf("got a dot.\n");
#endif
          if (!cback || !in_entity)
            goto append_data;
          if (!entnamelen) {
            tmp = 0;
            retval->errcode = ENT_ERR_INVALIDNAME;
            continue;
          }

          entfullname[entlen++] = *tmp;
          if (entpartslen) {
            entparts[entpartslen++] = 0;
          } else {
            entparts[entpartslen++] = *++tmp;
	    curpos++;
            entfullname[entlen++] = *tmp;
          }
          tmp++;
          curpos++;
          continue;
          
        default:
          if (!cback || !in_entity)
          {

#ifdef ENTDEBUG
printf("got a character not in entity: %c\n", *tmp);
#endif
            goto append_data;
          }          
#ifdef ENTDEBUG
printf("got a character in an entity: %c\n", *tmp);
#endif
          if (entlen >= ENT_MAX_ENTSIZE) {
            retval->errcode = ENT_ERR_ENTNAMELONG;
            tmp = 0;
            continue;
          }

          entfullname[entlen++] = *tmp;
          if (!entpartslen)
            entname[entnamelen++] = *tmp++;
          else
            entparts[entpartslen++] = *tmp++;
          
          curpos++;
          continue;
    }

    append_data:
    /* the 3 is to account for one char in "normal" case and 2 chars when
     * we are to append the entity name verbatim. That way it's faster.
     */
    tmplen = curlen + cbackres.buflen+2;
    
    if (curlen + tmplen >= retval->buflen) {
      retval->buflen += tmplen << 1;
      if (retval->buflen >= ENT_MAX_RETBUFSIZE) {
        retval->errcode = ENT_ERR_RETBUFTOOLONG;
        return retval;
      }
      
      retval->buf = (unsigned char*)realloc(retval->buf, sizeof(*retval->buf) * retval->buflen);
      if (!retval->buf) {
        retval->errcode = ENT_ERR_OOM;
        retval->buf = NULL;
        return retval;
      }
    }

#ifdef ENTDEBUG
printf("current length: %d\n", curlen);
#endif
    /* we have no result from the callback */
    if (!cbackres.buf && !cbackres.buflen)
    {
      retval->buf[curlen++] = *tmp++;
#ifdef ENTDEBUG
printf("copied 1, current length: %d\n", curlen);
#endif
     }
    /* we do have results from the callback */
    else if (cbackres.buf) {
      memcpy(&retval->buf[curlen], cbackres.buf, cbackres.buflen);
      curlen += cbackres.buflen;

#ifdef ENTDEBUG
printf("copied d%d, current length: %d\n", cbackres.buflen, curlen);
#endif
      free(cbackres.buf);
      cbackres.buf = NULL;
      cbackres.buflen = 0;
    } else {
      retval->buf[curlen++] = '&';

      memcpy(&retval->buf[curlen], entfullname, cbackres.buflen);
      curlen += cbackres.buflen;
      retval->buf[curlen++] = ';';

#ifdef ENTDEBUG
printf("copied %d (%s), current length: %d\n", cbackres.buflen + 2, entfullname, curlen);
#endif
      cbackres.buf = NULL;
      cbackres.buflen = 0;
    }
    
    curpos++; 
#ifdef ENTDEBUG
    printf("curpos == %d\n", curpos); 
#endif
  }

  if (retval->errcode == ENT_ERR_OK && in_entity)
      retval->errcode = ENT_ERR_OPENENTITY;

  
  retval->buflen = curlen;

#ifdef ENTDEBUG
printf("- %d ->%s<--\n", retval->buflen, retval->buf);
#endif
  return retval;
}
