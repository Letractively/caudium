/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

/*
 * $Id$
 *
 * Standard server template.
 */

constant selected = 1;
constant name = "VHS / SQL - Basic server";
constant desc = "A virtual server with the most basic modules that can be used with the Virtual Hosting System SQL";
constant modules = ({
  "contenttypes#0",
  "ismap#0",
  "htmlparse#0",
  "pathinfo#0",
  "rxmltags#0",
  "corescopes#0",
  "vhs_dirparser#0",
  "vhs_logger#0",
  "vhs_redirect#0",
  "vhs_fs#0",
  "vhs_system_sql#0"
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
