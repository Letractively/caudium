/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2001 The Caudium Group
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
  "domains", "topdomains",
  "sess_day_hits", 
  "sess_day_pages", 
  "pages",
  "sites",
  "dirs", 
  "codes", 
  "hits", 
  "refs", 
  "errorpages", 
  "pages_per_day", 
  "hits_per_day", 
  "kb_per_day", 
  "sessions_per_day", 
  "sess_len", "agents",
  "redirs", "refsites", "refto", "errefs",
  "hosts_per_day", 
});

float avg_bandwidth;

mapping agents = ([]);
mapping pages = ([ ]);
mapping dirs  = ([ ]);
mapping codes = ([ ]);
mapping hits =  ([ ]);
mapping refs =  ([ ]);
mapping redirs =  ([ ]);
mapping refsites =  ([ ]);
mapping refto =  ([ ]);
mapping errefs = ([]);
mapping errorpages = ([]);
mapping pages_per_day = ([]);
mapping hits_per_day  = ([]);
mapping hosts_per_day  = ([]);
mapping kb_per_day    = ([]);
mapping sessions_per_day = ([]);
mapping sess_day_hits       = ([]);
mapping sess_day_pages      = ([]);
mapping sess_len      = ([]);
mapping sites = ([]);
mapping domains = ([]);
mapping topdomains = ([]);
mapping extra;
int loaded;
void create(int year, int week, object method, string|void table,
	    int|void maxsize, mapping|void saveinme, mixed ... args) {
  if(saveinme) extra = saveinme;
  if(saveinme && table)
    data += ({ table });
  method->set_period( ({ Util.PERIOD_WEEK, year, week }) );
  if(method->multiload) table = 0;
  if(!table || (table && search(table, "kb_per"))) {
    Util.load(method, saveinme||this_object(), data, table);
  }
  //  werror("Preload took %d (%d) ms\n", preload, loaded);
  if(loaded || (saveinme&&saveinme->loaded)){
    return;
  }  
  int count, g, load;
  object d, wobj = Calendar.ISO.Week(year, week);
  werror("Week %d %d (%s)\n", year, week, table||"none");
  for(int i = 1; i < 8; i ++) {
    int day = wobj->day(i)->month_day();
    int month;
#if constant(Calendar.Islamic)
    month = wobj->month_no();
    year = wobj->year_no();
#else
    month = wobj->day(i)->month()->number();
    year = wobj->day(i)->year()->number();
#endif
    if(d) destruct(d);
      
    werror("   Date %d-%02d-%02d\n", year, month, day);
    if(saveinme)
      saveinme = ([]);
    method->set_period( ({ Util.PERIOD_DAY, year, month, day }) );
    d = Period.Day(year,month,day,method,table &&
		   replace(table, "day", "hour"), saveinme, 
		   @args);
    if(saveinme) {
      addmappings(extra,saveinme);
      continue;
    }
    if(!table  || table == "hits_per_day") {
      hits_per_day[day] += `+(@d->hits_per_hour);
      pages_per_day[day] += `+(@d->pages_per_hour);
    } else if(table == "pages_per_day") {
      pages_per_day[day] += `+(@d->pages_per_hour);
    }
    if(!table  || table == "kb_per_day") {
      kb_per_day[day] += `+(@d->kb_per_hour);
      if(d->avg_bandwidth > 0)
      {
	count++;
	avg_bandwidth += d->avg_bandwidth;
      }
    }

    if(!table  || table == "hosts_per_day") {
      hosts_per_day[day] += `+(@d->hosts_per_hour);
    }
    
    if(!table  || table == "sessions_per_day") {
      sessions_per_day[day] += `+(@d->sessions_per_hour);
     }
    if(!table || table == "sess_day_hits")
    {
      int sessnum = sizeof(d->sess_hour_hits - ({0})) || 1;
      sess_day_hits[day]  += `+(@d->sess_hour_hits) / sessnum;
      sess_day_pages[day] += `+(@d->sess_hour_pages) / sessnum;      
    }
    if(!table || table == "sess_day_len") {
      int sessnum = sizeof(d->sess_len - ({0})) || 1;
      sess_len[day]  += `+(@d->sess_len) / sessnum;
    }
    
    if(!table || !search(table, "agent") || table == "common_os")
      addmappings(agents, d->agents);
    foreach( ({ "dirs", "redirs", "pages", "hits", "refs", "errorpages",
		 "refto", "refsites", "sites", "errefs",
		"domains", "topdomains" }), string t) 
      if(!table || table == t)
	addmappings(this_object()[t], d[t]);
    if(!table  || table == "codes" || table == "error_code") 
      addmappings(codes, d->codes);
    Util.compress_mappings(this_object(), table, maxsize);
  } 
  //compress_mappings(t);
  if(count)
    avg_bandwidth /= count;
  //  werror("Add: %d ms, Load: %d ms\n", g, load);
  method->set_period( ({ Util.PERIOD_WEEK, year, week }) );
  Util.save(method, data, this_object());
  method->destroy();
}
