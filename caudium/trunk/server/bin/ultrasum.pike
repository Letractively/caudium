#!/usr/local/bin/pike
/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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

string savedir;
object method;
import UltraLog;
import spider;
import UltraSupport;
import Util;

constant cvs_version = "$Id$";

//#define TIME time
#define TIME gethrtime

int start, persec=20000, oldt, saved_lines, maxsize;
int|float length;
mapping year = ([]);


void status(int lines, void|int pos, void|int long)
{
  saved_lines = lines;
  float div = 1.0;
  if(time != TIME)
    div = 1000000.0;
  float secs = (((TIME() - start) / (div||1.0)))||1;
  persec = (int)(lines / secs) || 1;
  float done = (int)length ? (float)pos/length : 0.0;
  float mb = (float)pos;
  float mbs = mb / secs;
  if(!long)
  {
    if(done <= 0)
      done = 0.99;
    int secleft = (int)((secs / (done) - secs));
    int minleft = secleft/60;
    secleft = secleft % 60;
    write("\r%6dk (%4d MB) in %d s at %6d l/s / %4.1f MB/s (%3.1f%% %02dm%02ds)",
	  lines/1000, (int)(mb), (int)secs,
	  persec,mbs, done * 100, minleft, secleft);
  } else
    write("\n %10d lines (%d MB) in %.3f min\n"
	   " %10d lines, %7.1f MB / sec      =>\n"
	   " %10d lines, %7.1f MB / min      =>\n"
	   " %10d lines, %7.1f MB / hour.\n",
	  lines, (int)(mb), secs/60.0,
	  persec, mbs,
	  persec *= 60, mbs *= 60,
	  persec * 60, mbs *= 60);
}

function _ispage = Regexp("(\\.(html|htm|rxml|txt)$)|/$")->match;

#define ISPAGE(x) (x[0] == '/' && (x[-1] == '/' ||_ispage(x)))

void daily(int y, int m, int d, mapping pages, mapping hits, mapping redirs,
	   mapping hiterr, mapping errurl, mapping erefs,
	   mapping refto, mapping refsites, mapping ref, mapping dirs,
	   mapping agents, mapping sites, mapping domains, mapping topdomains,
	   array sess_hour, array hour_hits, array pages_hour, array hour_kb,
	   array sess_len, array hosts_per_hour)
{
  string ns;
  object dd;
  int num;
  int t1, t2, t3, t4;
  if(!year[y])  year[y] = ([]);
  if(!year[y][m])  year[y][m] = (<>);
  year[y][m][d] = 1; // Remember dirs that are modified;
#ifdef GAUGE
  t1 = gauge {
#endif
    dd = Period.Day(y,m,d, method);
#ifdef GAUGE
  };
#endif
  //werror("Daily for %4d-%02d-%02d\n", y,m,d);
  //  exit(0);
#ifdef GAUGE
  t2 = gauge {
#endif
    if(dd->loaded) {
      for(int i = 0; i < 24; i ++ )
      {
	dd->hosts_per_hour[i]  = hosts_per_hour[i];
	dd->hits_per_hour[i]  += hour_hits[i];
	dd->kb_per_hour[i]    += hour_kb[i];
	dd->pages_per_hour[i] += pages_hour[i];
	dd->sessions_per_hour[i] += sess_hour[i];
	num = dd->sess_len[i] && sess_len[i];
	dd->sess_len[i] += sess_len[i];
	if(num)   dd->sess_len[i] /= 2;
      }
      addmappings(dd->dirs, dirs);  
      addmappings(dd->pages, pages);  
      addmappings(dd->hits, hits);  
      addmappings(dd->refs, ref);  
      addmappings(dd->refsites, refsites);  
      addmappings(dd->refto, refto);  
      addmappings(dd->sites, sites);  
      addmappings(dd->errefs, erefs);  
      addmappings(dd->codes, hiterr);
      addmappings(dd->errorpages, errurl);
      addmappings(dd->redirs, redirs);
      addmappings(dd->agents, agents);
      addmappings(dd->topdomains, topdomains);
      addmappings(dd->domains, domains);
    } else {
      for(int i = 0; i < 24; i ++ )
      {
	dd->hits_per_hour[i]  = hour_hits[i];
	dd->hosts_per_hour[i]  = hosts_per_hour[i];
	dd->kb_per_hour[i]    = hour_kb[i];
	dd->pages_per_hour[i] = pages_hour[i];
	dd->sessions_per_hour[i] = sess_hour[i];
	num = dd->sess_len[i] && sess_len[i];
	dd->sess_len[i] = sess_len[i];
	if(num)   dd->sess_len[i] /= 2;
      }
      dd->sites = sites;
      dd->dirs = dirs;  
      dd->pages = pages;  
      dd->hits = hits;  
      dd->refs = ref;  
      dd->refsites = refsites;  
      dd->refto = refto;  
      dd->errefs = erefs;  
      dd->codes = hiterr;
      dd->errorpages = errurl;
      dd->redirs = redirs;
      dd->agents = agents;
      dd->topdomains = topdomains;
      dd->domains = domains;
    }
#ifdef GAUGE
  };
  t3 = gauge {
#endif
    foreach(indices(Util.compmaps), string map) {
      dd[map] = compress_mapping(dd[map], maxsize);
    }
#ifdef GAUGE
  };
  t4 = gauge {
#endif
    dd->modified = 1;
    destruct(dd);
#ifdef GAUGE
  };
#define FL(X) intp(X) ? X/1000.0: X
  werror("\n%4d-%02d-%02d: Restore: %f, add: %f, compr: %f, dest: %f.\n", y,m,d,
	 FL(t1), FL(t2), FL(t3), FL(t4));
#endif
}

int exit_now;

void set_exit_now()
{
  exit_now = 1;
}

void main(int argc, array argv)
{
  string noref;
  oldt = start = TIME();
  object fd;
  if(argc == 1)
  {
    werror("Syntax: %s <configfile>\n", argv[0]);
    exit(1);
  }
   object profs = Profile.Master(argv[1]);
  maxsize = profs->maxsize;
  foreach(profs->profiles, object profile) {
    write("Processing %s\n", profile->name);
    savedir = profile->savedir;
    method = profile->method;
    year = ([]); // mapping with time periods that needs to be cleared.
    foreach(profile->files, object f) {
      object fd;
      int oldpos, pos = profile->pos[f->fname];
      if(pos < 0) {
	if(f->reload)
	  pos = 0;
	else
	  continue;
      }
      if(!(fd = f->get_fd())) continue;
      saved_lines = 0;
      if(f->size > 0)
	length = f->size;
      start = oldt = TIME();
      write("    %s (%d)\n", f->fname, pos);
      if(pos > 0)
      {
	if(f->ispipe) {
	  if(!f->seek(pos)) oldpos = pos;
	  pos = 0;
	} else if(pos > length)
	  pos = 0; /* file shorter than last saved position */
      }
      length /= 1024.0 * 1024.0; // filesize => MB
      pos = UltraLog.ultraparse(f->format, status, daily, fd,
				profile->extensions, profile->noref, pos);
      
      if(f->restore == 1)
	profile->pos[f->fname] = pos+oldpos;
      else
	profile->pos[f->fname] = -1; // Ignore file in the future.
      //      status(saved_lines,0,1);
      profile->save(); 
      destruct(fd);
    }
    profile->method->invalidate(year);
  }
  //werror("Parsed %d kbytes\n", pos/1024);
  exit(0);
}

