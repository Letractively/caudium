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
  "sess_month_hits", 
  "sess_month_pages", 
  "pages", 
  "dirs", 
  "codes", 
  "hits", 
  "refs",
  "sites",
  "errorpages", 
  "pages_per_month", 
  "hits_per_month", 
  "whits_per_month",
  "wsessions_per_month",
  "wpages_per_month",
  "kb_per_month", 
  "hosts_per_month", 
  "wkb_per_month", 
  "sessions_per_month", 
  "sess_len", "agents",
  "redirs", "refsites", "refto", "errefs"
});

float avg_bandwidth;

mapping pages = ([ ]);
mapping dirs  = ([ ]);
mapping codes = ([ ]);
mapping hits =  ([ ]);
mapping refs =  ([ ]);
mapping errorpages = ([]);
mapping redirs =  ([ ]);
mapping refsites =  ([ ]);
mapping refto =  ([ ]);
mapping errefs = ([]);
mapping agents = ([]);
mapping sites = ([]);
mapping domains = ([]);
mapping topdomains = ([]);

mapping hosts_per_month = ([ ]);
mapping pages_per_month = ([ ]);
mapping hits_per_month = ([]);
mapping wpages_per_month = ([ ]);
mapping whits_per_month = ([]);
//array   pages_per_month = allocate(13);
//array   hits_per_month  = allocate(13);
array   kb_per_month    = allocate(13);
array   wkb_per_month    = allocate(13);
array   sessions_per_month    = allocate(13);
array   wsessions_per_month    = allocate(13);
array(float)   sess_month_hits = allocate(13);
array(float)   sess_month_pages= allocate(13);
array(float)   sess_len = allocate(13);
int loaded;
mapping extra;
void create(int year, object method, string|void table, int|void maxsize,
	    mapping|void saveinme, mixed ... args) {
  if(saveinme && table) 
    data += ({ table });
  if(saveinme)
    extra = saveinme;
  method->set_period( ({ Util.PERIOD_YEAR, year }) );
  if(method->multiload) table = 0;
  if(!table || (table && search(table, "kb_per"))) {
    Util.load(method, saveinme||this_object(), data, table);
  }
  //  werror("%s: %O\n", table, avg_bandwidth);
  if(loaded || (extra && extra->loaded))
    return;

  array months = method->get_months();
  int count, load, g;
  object d;
  foreach(sort((array(int))(months||({})) - ({0})), int month) {
    werror("Month %d-%02d\n", year, month);
    if(d) destruct(d);
    if(saveinme) saveinme = ([]);
    method->set_period( ({ Util.PERIOD_MONTH, year, month }) );
    d = Period.Month(year,month,method, table &&
		     replace(table, "month", "day"), maxsize,
		     saveinme, @args);
    if(saveinme) {
      addmappings(extra,saveinme);
      continue;
    }
    if(!table  || table == "hits_per_month" || table == "pages_per_month") {
      int c1, c2;
      for(int i = 0; i < sizeof(d->hits_per_day); i++) {
	if(d->hits_per_day[i] > 0) c1++;
	if(d->pages_per_day[i] > 0) c2++;
	hits_per_month[month] += (float)d->hits_per_day[i];
	pages_per_month[month] += (float)d->pages_per_day[i];
      }
      if(c1) whits_per_month[month] = (hits_per_month[month] / (float)c1)*30;
      if(c2)wpages_per_month[month] = (pages_per_month[month] / (float)c2)*30;
    }
    if(!table  || table == "kb_per_month") {
      kb_per_month[month] += `+(@d->kb_per_day);
      wkb_per_month[month] = d->avg_bandwidth;
      if(d->avg_bandwidth > 0.0)
      {
	count++;
	avg_bandwidth += d->avg_bandwidth;
      }
    }
    if(!table  || table == "hosts_per_month") {
      for(int i = 0; i < sizeof(d->hosts_per_day); i++) 
	hosts_per_month[month] += d->hosts_per_day[i];
    }
    if(!table  || table == "sessions_per_month") {
      int c1;
      for(int i = 0; i < sizeof(d->sessions_per_day); i++) {
	if(d->sessions_per_day[i] > 0) c1++;
	sessions_per_month[month] += d->sessions_per_day[i];
      }
      if(c1) wsessions_per_month[month] =
	       (int)(sessions_per_month[month] / (float)c1)*30;
    }
    if(!table || table == "sess_month_hits")
    {
      int sessnum = sizeof(d->sess_day_hits - ({0})) || 1;
      sess_month_hits[month]  += (`+(@d->sess_day_hits) / sessnum);
      sess_month_pages[month] += (`+(@d->sess_day_pages) / sessnum);
    }
    if(!table || table == "sess_month_len") {
      int sessnum = sizeof(d->sess_len - ({0})) || 1;
      sess_len[month]  += `+(@d->sess_len) / sessnum;
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
  if(count)
    avg_bandwidth /= count;
  //  write("Avg Bandwidth: %O %O\n", kb_per_month, wkb_per_month);
  method->set_period( ({ Util.PERIOD_YEAR, year }) );
  Util.save(method, data, this_object());
  method->destroy();
}
