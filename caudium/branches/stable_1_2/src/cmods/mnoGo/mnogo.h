/*
 * Pike Extension Modules - A collection of modules for the Pike Language
 * Copyright © 2000, 2001, 2002 The Caudium Group
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
 * Glue for the mnoGo search engine
 *
 * $Id$
 */

#ifndef MNOGO_H
#define MNOGO_H

#include "udm_config.h"
#include "udmsearch.h"

#define MNOGO_API(NAME) static void PIKE_CONCAT(f_mnogo_,NAME)(INT32 args)

/* udm_set_agent_param constants */
#define UDM_PARAM_PAGE_SIZE		1
#define UDM_PARAM_PAGE_NUM		2
#define UDM_PARAM_SEARCH_MODE		3
#define UDM_PARAM_CACHE_MODE		4
#define UDM_PARAM_TRACK_MODE		5
#define UDM_PARAM_CHARSET		6
#define UDM_PARAM_STOPTABLE		7
#define UDM_PARAM_STOPFILE		8
#define UDM_PARAM_WEIGHT_FACTOR		9
#define UDM_PARAM_WORD_MATCH		10
#define UDM_PARAM_PHRASE_MODE		11
#define UDM_PARAM_MIN_WORD_LEN		12
#define UDM_PARAM_MAX_WORD_LEN		13
#define UDM_PARAM_ISPELL_PREFIXES	14
#define UDM_PARAM_CROSS_WORDS		15

/* udm_add_search_limit constants */
#define UDM_LIMIT_URL		1
#define UDM_LIMIT_TAG		2
#define UDM_LIMIT_LANG		3
#define UDM_LIMIT_CAT		4
#define UDM_LIMIT_DATE		5

/* phrase modes */
#define UDM_PHRASE_ENABLED	1
#define UDM_PHRASE_DISABLED	0

/* crosswords modes */
#define UDM_CROSS_WORDS_ENABLED	 1
#define UDM_CROSS_WORDS_DISABLED 0

/* udm_get_res_param constants */
#define UDM_PARAM_NUM_ROWS	256
#define UDM_PARAM_FOUND		257
#define UDM_PARAM_WORDINFO	258
#define UDM_PARAM_SEARCHTIME	259
#define UDM_PARAM_FIRST_DOC	260
#define UDM_PARAM_LAST_DOC	261

/* udm_load_ispell_data constants */
#define UDM_ISPELL_TYPE_AFFIX	1
#define UDM_ISPELL_TYPE_SPELL	2
#define UDM_ISPELL_TYPE_DB	3
#define UDM_ISPELL_TYPE_SERVER	4

#define THIS ((mnogo_storage *)Pike_fp->current_storage)
#define RES ((mnogo_result_storage *)Pike_fp->current_storage)
#define AGENT THIS->mnogo_agent
#define RESOBJ RES->mnogo_result

#define RETURN_TRUE pop_n_elems(args); push_int(1);
#define RETURN_FALSE pop_n_elems(args); push_int(0);
#define RETURN_INT(x) pop_n_elems(args); push_int(x);
#define RETURN_STRING(x) pop_n_elems(args); push_text(x);
#define RETURN_FLOAT(x) pop_n_elems(args); push_float(x);

typedef struct {
  UDM_AGENT *mnogo_agent;
} mnogo_storage;

typedef struct {
  UDM_RESULT *mnogo_result;
  unsigned int current_row;
} mnogo_result_storage;

#endif
