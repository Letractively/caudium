/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
 * Contributor(s):
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
 */
ENT_RESULT* ent_parser(unsigned char *buf, unsigned long buflen,
                          entcallback cback, void *userdata)
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
    switch (*tmp) {
        case '&':
          if (*(tmp+1) == '&') {
            tmp++;
            goto append_data;
          }
          if (!cback)
            goto append_data;

          memset(entname, 0, sizeof(entname));
          memset(entparts, 0, sizeof(entparts));
          memset(entfullname, 0, sizeof(entfullname));
          entnamelen = entpartslen = 0;
          in_entity = 1;
          tmp++; curpos++;
          continue;

        case ';':
          if (!cback || !in_entity)
            goto append_data;
          tmp++; curpos++;
          in_entity = 0;
          cback(entname, entparts, &cbackres, userdata);
          if (!cbackres.buf)
            cbackres.buflen = entlen;
          
          continue;

        case '.':
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
            entfullname[entlen++] = *tmp;
          }
          tmp++;
          curpos++;
          continue;
          
        default:
          if (!cback || !in_entity)
            goto append_data;
          
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
    tmplen = curlen + cbackres.buflen + 3;
    
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

    if (!cbackres.buf && !cbackres.buflen)
      retval->buf[curlen++] = *tmp++;
    else if (cbackres.buf) {
      memcpy(&retval->buf[curlen], cbackres.buf, cbackres.buflen);
      curlen += cbackres.buflen;
      free(cbackres.buf);
      cbackres.buf = NULL;
      cbackres.buflen = 0;
    } else {
      retval->buf[curlen++] = '&';
      memcpy(&retval->buf[curlen], entfullname, cbackres.buflen);
      curlen += cbackres.buflen;
      retval->buf[curlen++] = ';';
      cbackres.buf = NULL;
      cbackres.buflen = 0;
    }
    
    curpos++;
  }

  if (retval->errcode == ENT_ERR_OK && in_entity)
      retval->errcode = ENT_ERR_OPENENTITY;
  
  retval->buflen = curlen;
  return retval;
}

#ifdef TEST
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

void callback(char *entname, char params[], ENT_CBACK_RESULT *res, void *userdata)
{
  static int dummy = 0;
  char  *tmp = params;
  printf("Got entity: %s ", entname);

  while (tmp && tmp[0]) {
    printf("%s ", tmp);
    tmp += strlen(tmp) + 1;
  }
  printf("\n");

  res->buf = NULL;
  if (dummy != 3) {
    asprintf((char**)&res->buf, "entity%04d", ++dummy);
    res->buflen = strlen(res->buf);
  }
}

int main(int argc, char **argv)
{
  if (argc < 2) {
    fprintf(stderr, "Please pass the path to the file to parse on the command line\n\n");
    return 1;
  }

  FILE *f = fopen(argv[1], "r");
  if (!f) {
    fprintf(stderr, "Cannot open %s for input\n", argv[1]);
    return 1;
  }

  struct stat sbuf;

  if (fstat(fileno(f), &sbuf) < 0) {
    fclose(f);
    fprintf(stderr, "Cannot stat %s\n", argv[1]);
    return 1;
  }

  char  *inbuf = (char*)malloc(sbuf.st_size * sizeof(*inbuf));
  if (!inbuf) {
    fclose(f);
    fprintf(stderr, "Out of memory\n");
    return 1;
  }

  if (fread((void*)inbuf, 1, sbuf.st_size, f) != sbuf.st_size) {
    fclose(f);
    fprintf(stderr, "Error reading from %s\n", argv[1]);
    return 1;
  }
  fclose(f);
  
  ENT_RESULT  *eres = ent_parser(inbuf, sbuf.st_size, callback, NULL);
  if (!eres) {
    fprintf(stderr, "Out of memory in the entity parser\n");
    return 1;
  }

  if (eres->errcode != ENT_ERR_OK)
    switch (eres->errcode) {
        case ENT_ERR_OOM:
          fprintf(stderr, "Out of memory in the entity parser\n");
          break;

        case ENT_ERR_INVPARM:
          fprintf(stderr, "Invalid parameter in the entity parser\n");
          break;

        case ENT_ERR_BUFTOOLONG:
          fprintf(stderr, "Buffer too long in the entity parser\n");
          break;

        case ENT_ERR_INVALIDNAME:
          fprintf(stderr, "Invalid entity name in the entity parser\n");
          break;
          
        default:
          fprintf(stderr, "Unknown error in the entity parser\n");
          break;
    }

  free(inbuf);
  printf("The parsed file:\n\n");

  if (eres->buf) {
    fwrite(eres->buf, 1, eres->buflen, stdout);
    free(eres->buf);
  } else {
    fprintf(stderr, "No data was returned\n");
  }

  free(eres);
  return 0;
}
#endif
