// Code to handle daily stats
// $Id$

import "..";
import Util;

int modified;
array data = ({
  "pages",  "codes",  "hits",   "refs",   "errorpages", "hits_per_hour",
  "kb_per_hour", "dirs", "pages_per_hour", "sessions_per_hour", "sess_len",
  "redirs", "refsites", "refto", "errefs", "agents", "sites", "topdomains",
  "domains", "hosts_per_hour"
});
float avg_bandwidth;
mapping pages = ([ ]);
mapping dirs  = ([ ]);
mapping codes = ([ ]);
mapping hits =  ([ ]);
mapping refs =  ([ ]);
mapping refsites =  ([ ]);
mapping refto =  ([ ]);
mapping errorpages = ([]);
mapping errefs = ([]);
mapping redirs = ([]);
mapping agents = ([]);
mapping sites = ([]);
mapping domains = ([]);
mapping topdomains = ([]);
array   pages_per_hour 	     = allocate(24);
array   hosts_per_hour 	     = allocate(24);
array   hits_per_hour        = allocate(24);
array   kb_per_hour    	     = allocate(24);
array   sessions_per_hour    = allocate(24);
array(float)   sess_hour_hits       = allocate(24);
array(float)   sess_hour_pages      = allocate(24);
array(float)   sess_len             = allocate(24);
int loaded;
mapping extra;
object db;
void create(int year, int month, int date, object method,
	    string|void table, mapping|void savemap,
	    void|function create_callback, mixed ... args) {
  if(savemap && table)
    data += ({ table });
  method->set_period(({ PERIOD_DAY, year, month, date }));
  db = method ;
  load(db, savemap || this_object(), data, table);
  if(savemap) {
    extra = savemap;
    if(!savemap->loaded && create_callback) {
      create_callback(this_object(), ({ year,month,date }), "day", 
		      savemap, @args);      
      if(savemap[table]) {
	modified = 1;
	loaded = 1;
      }
    }
  }
  method->destroy();
}

void destroy()
{
  if(modified) save(db, data, this_object());
}

