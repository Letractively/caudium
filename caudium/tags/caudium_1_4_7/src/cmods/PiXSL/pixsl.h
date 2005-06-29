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

#define SX_FILE 0
#define SX_DATA 1

#define THIS ((xslt_storage *)Pike_fp->current_storage)

typedef struct
{
  struct pike_string *xml;
  struct pike_string *xsl;
  struct pike_string *base_uri;
  int                 xml_type, xsl_type;
  struct mapping     *variables;  
  struct mapping     *err;
  char               *content_type, *charset;
  SchemeHandler       sab_scheme_handler;
  int                 do_callbacks;
  char               *getAllBuffer;
  struct svalue       cb_getAll;
  struct svalue       cb_freeMemory;
  struct svalue       cb_open;
  struct svalue       cb_get;
  struct svalue       cb_put;
  struct svalue       cb_close;
  struct svalue       cb_extra_args;
} xslt_storage;

static void f_set_xml_data(INT32 args); 
static void f_set_xml_file(INT32 args); 
static void f_set_xsl_data(INT32 args); 
static void f_set_xsl_file(INT32 args); 
static void f_set_variables(INT32 args); 
static void f_set_base_uri(INT32 args); 
static void f_parse(INT32 args);
static void f_create(INT32 args);
static void f_error(INT32 args);
static void f_parse_files(INT32 args);
static void f_content_type(INT32 args);
static void f_charset(INT32 args);
static void f_set_scheme_callbacks(INT32 args);

static void install_callbacks(struct mapping *map);
