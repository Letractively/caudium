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

#ifdef fp
#undef fp
#endif

#ifndef __ENTPARSE_H
#define __ENTPARSE_H

typedef struct
{
  unsigned char    *buf;
  unsigned long     buflen;
  int               errcode;
} ENT_RESULT;

typedef struct
{
  unsigned char    *buf;
  unsigned long     buflen;
} ENT_CBACK_RESULT;

typedef void (*entcallback)(char *entname, char params[], ENT_CBACK_RESULT *res, void *userdata, void *extra_args);

/* The high bit is set for critical errors */
#define ENT_ERR_OK             0x00000000
#define ENT_ERR_OOM            0x80000001
#define ENT_ERR_BUFTOOLONG     0x80000002
#define ENT_ERR_INVPARM        0x00000003
#define ENT_ERR_OPENENTITY     0x00000004
#define ENT_ERR_ENTNAMELONG    0x00000005
#define ENT_ERR_INVALIDNAME    0x00000006
#define ENT_ERR_RETBUFTOOLONG  0x80000007

/* the maximum size of the entity name (excluding the & and the ; chars) */
#define ENT_MAX_ENTSIZE         255
#define ENT_MAX_RETBUFSIZE      (128*1024)

ENT_RESULT* ent_parser(unsigned char *buf, unsigned long buflen,
                       entcallback cback, void *userdata, void *extra_args);
#endif
