/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
#include <pcre.h>

inherit "module";
inherit "caudiumlib";

constant module_type = MODULE_FIRST;
constant module_name = "VHS - Redirect";
constant module_doc  = "Redirect VHF requests if need";

constant module_unique = 1;

private int redirs = 0;

void create()
{
}

void start()
{
}

string status()
{
  return "<h3>Module enabled</h3>";
}

mixed first_try(object id)
{
  if (!id->misc->vhs || !id->misc->vhs->redirect || id->misc->vhs->is_redirected)
     return 0;

  id->misc->vhs->is_redirected = 1;

  return http_redirect("http://" + id->misc->vhs->redirect + "/", id);
}

