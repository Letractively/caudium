/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

// $Id$
import "..";
import UltraLog;

int modified;
array data = ({
  "pages", 
  "dirs", 
  "codes",
  "redirs",
  "hits", "agents",
  "refs",
  "sites",
  "errorpages", 
  "pages_per_day", 
  "hits_per_day", 
  "kb_per_day", 
  "sess_day_hits", 
  "sess_day_pages", 
  "sessions_per_day", 
  "sess_len", "refsites", "refto", "errefs",
  "domains", "topdomains", "hosts_per_day"
});

constant mapvars =
({ "dirs", "redirs", "pages", "hits", "refs", "errorpages",
   "refto", "refsites", "sites", "errefs",
   "domains", "topdomains" });
float avg_bandwidth;

mapping pages = ([ ]);
mapping agents = ([ ]);
mapping dirs  = ([ ]);
mapping codes = ([ ]);
mapping hits =  ([ ]);
mapping refs =  ([ ]);
mapping errorpages = ([]);
mapping redirs =  ([ ]);
mapping refsites =  ([ ]);
mapping refto =  ([ ]);
mapping errefs = ([]);
mapping sites = ([]);
mapping domains = ([]);
mapping topdomains = ([]);

array   pages_per_day = allocate(32);
array   hits_per_day  = allocate(32);
array   hosts_per_day  = allocate(32);
array   kb_per_day   = allocate(32);
array   sessions_per_day = allocate(32);
array(float)   sess_day_hits = allocate(32);
array(float)   sess_day_pages= allocate(32);
array(float)   sess_len = allocate(32);
int loaded;
mapping extra;
void create(int year, int month, object method, string|void table,
	    int|void maxsize, mapping|void saveinme, mixed ... args) {
  int multiload;

  if(saveinme) {
    extra = saveinme;
    if(table) data += ({ table });
  }
  method->set_period( ({ Util.PERIOD_MONTH, year, month }) );
  if(method->multiload) table = 0;
  if(!table || (table && search(table, "kb_per"))) {
    Util.load(method, saveinme||this_object(), data, table);
  }
    //  werror("Preload took %d (%d) ms\n", preload, loaded);
  if(loaded || (extra&&extra->loaded)) 
    return;
  array dates = method->get_days();
  int count, g, load;
  object d;
  foreach(sort((array(int))(dates||({})) - ({0})), int day)
  {
    if(d) destruct(d);
    werror("   Date %d-%02d-%02d\n", year, month, day);
    if(saveinme)  saveinme = ([]);
    method->set_period( ({ Util.PERIOD_DAY, year, month, day }) );
    d = Period.Day(year,month,day,method ,table &&
		   replace(table, "day", "hour"),
		   saveinme, @args);
    if(saveinme) {
      addmappings(extra,saveinme);
      continue;
    }
    if(!table  || table == "hits_per_day" || table == "pages_per_day") {
      hits_per_day[day] += `+(@d->hits_per_hour);
      pages_per_day[day] += `+(@d->pages_per_hour);
    }
    if(!table  || table == "hosts_per_day") {
      hosts_per_day[day] += `+(@d->hosts_per_hour);
    }
    if(!table  || table == "kb_per_day") {
      kb_per_day[day] += `+(@d->kb_per_hour);
      if(d->avg_bandwidth > 0.0)
      {
	count++;
	avg_bandwidth += d->avg_bandwidth;
      }
    }
    if(!table  || table == "sessions_per_day") {
      sessions_per_day[day] += `+(@d->sessions_per_hour);
    }
    if(!table || table == "sess_day_hits")
    {
      int sessnum = sizeof(d->sess_hour_hits - ({0})) || 1;
      sess_day_hits[day]  += (`+(@d->sess_hour_hits) / sessnum);
      sess_day_pages[day] += (`+(@d->sess_hour_pages) / sessnum);
      
    }
    if(!table || table == "sess_day_len")
    {
      int sessnum = sizeof(d->sess_len - ({0})) || 1;
      sess_len[day]  += `+(@d->sess_len) / sessnum;
    }
    if(!table || !search(table, "agent") || table == "common_os")
      addmappings(agents, d->agents);
    if(!table)  foreach( mapvars, string t)
      addmappings(this_object()[t], d[t]);
    else if(search(mapvars, table) != -1)
      addmappings(this_object()[table], d[table]);
    if(!table  || table == "codes" || table == "error_code") 
      addmappings(codes, d->codes);
    Util.compress_mappings(this_object(), table, maxsize);
  }
  if(count)
    avg_bandwidth /= count;
  method->set_period( ({ Util.PERIOD_MONTH, year, month }) );
  Util.save(method, data, this_object());
  method->destroy();
}

