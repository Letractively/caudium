/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2001 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

#include <config.h>

inherit "caudiumlib";

#define TIMESTAMP 0
#define DATA 1
#define TIMEOUT 2

#define ENTRY_SIZE 3

#define CACHE_TIME_OUT 300

#if DEBUG_LEVEL > 8
#ifndef CACHE_DEBUG
#define CACHE_DEBUG
#endif
#endif


mapping cache;
mapping hits=([]), all=([]);

#ifdef THREADS
object cleaning_lock = Thread.Mutex();
#endif /* THREADS */

void cache_expire(string in)
{
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
  m_delete(cache, in);
}

mixed cache_lookup(string in, string what)
{
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
#ifdef CACHE_DEBUG
  perror(sprintf("CACHE: cache_lookup(\"%s\",\"%s\")  ->  ", in, what));
#endif
  all[in]++;
  if(cache[in] && cache[in][what])
  {
#ifdef CACHE_DEBUG
    perror("Hit\n");
#endif
    hits[in]++;
    cache[in][what][TIMESTAMP]=time(1);
    return cache[in][what][DATA];
  }
#ifdef CACHE_DEBUG
  perror("Miss\n");
#endif
  return 0;
}

string status()
{
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
  string res, a;
  res = "<table border=0 cellspacing=0 cellpadding=2><tr bgcolor=lightblue>"
    "<th align=left>Class</th><th align=left>Entries</th><th align=left>(KB)</th><th align=left>Hits</td><th align=left>Misses</th><th align=left>Hitrate</th></tr>";
  array c, b;
  mapping ca = ([]), cb=([]), ch=([]), ct=([]);
  b=indices(cache);
  c=Array.map(values(cache), get_size);

  int i;

  for(i=0; i<sizeof(b); i++)
  {
    int s = sizeof(cache[b[i]]);
    int h = hits[b[i]];
    int t = all[b[i]];
    sscanf(b[i], "%s:", b[i]);
    ca[b[i]]+=c[i]; cb[b[i]]+=s; ch[b[i]]+=h; ct[b[i]]+=t;
  }
  b=indices(ca);
  c=values(ca);
  sort(c,b);
  int n, totale, totalm, totalh, mem, totalr;
  i=0;
  c=reverse(c);
  foreach(reverse(b), a)
  {
    if(ct[a])
    {
      res += ("<tr align=right bgcolor="+(n/3%2?"#f0f0ff":"white")+
	      "><td align=left>"+a+"</td><td>"+cb[a]+"</td><td>" +
	      sprintf("%.1f", ((mem=c[i])/1024.0)) + "</td>");
      res += "<td>"+ch[a]+"</td><td>"+(ct[a]-ch[a])+"</td>";
      if(ct[a])
	res += "<td>"+(ch[a]*100)/ct[a]+"%</td>";
      else
	res += "<td>0%</td>";
      res += "</tr>";
      totale += cb[a];
      totalm += mem;
      totalh += ch[a];
      totalr += ct[a];
    }
    i++;
  }
  res += "<tr align=right bgcolor=lightblue><td align=left>Total</td><td>"+totale+"</td><td>" + sprintf("%.1f", (totalm/1024.0)) + "</td>";
    res += "<td>"+totalh+"</td><td>"+(totalr-totalh)+"</td>";
    if(totalr)
      res += "<td>"+(totalh*100)/totalr+"%</td>";
    else
      res += "<td>0%</td>";
    res += "</tr>";
  return res + "</table>";
}

void cache_remove(string in, string what)
{
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
#ifdef CACHE_DEBUG
  perror(sprintf("CACHE: cache_remove(\"%s\",\"%O\")\n", in, what));
#endif
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in]) 
      m_delete(cache[in], what);
}

mixed cache_set(string in, string what, mixed to, int|void tm)
{
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
#ifdef CACHE_DEBUG
  perror(sprintf("CACHE: cache_set(\"%s\", \"%s\", %O)\n",
		 in, what, to));
#endif
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  cache[in][what][TIMEOUT] = tm||CACHE_TIME_OUT;
  cache[in][what][TIMESTAMP] = time(1);
  return to;
}

void cache_clear(string in)
{
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
#ifdef CACHE_DEBUG
  perror("CACHE: cache_clear(\"%s\")\n", in);
#endif
  if(cache[in])
    m_delete(cache,in);
}

void cache_clean()
{
  remove_call_out(cache_clean);
  call_out(cache_clean, CACHE_TIME_OUT);
// #ifdef THREADS
//   mixed key;
//   catch { key = cleaning_lock->lock(); };
// #endif /* THREADS */
  string a, b;
  int cache_time_out=CACHE_TIME_OUT;
#ifdef CACHE_DEBUG
  perror("CACHE: cache_clean()\n");
#endif
  foreach(indices(cache), a)
  {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
    perror("CACHE:   Class  " + a + "\n");
#endif
#endif
    foreach(indices(cache[a]), b)
    {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
      perror("CACHE:      " + b + " ");
#endif
#endif
#ifdef DEBUG
      if(!intp(cache[a][b][TIMESTAMP]))
	error("Illegal timestamp in cache ("+a+":"+b+")\n");
#endif
      if(cache[a][b][TIMESTAMP]+cache[a][b][TIMEOUT] <
	 (time(1) - (cache_time_out - get_size(cache[a][b][DATA])/100)))
      {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	perror("DELETED\n");
#endif
#endif	
	m_delete(cache[a], b);
      }
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
      else
	perror("Ok\n");
#endif
#endif	
      if(!sizeof(cache[a]))
      {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	perror("CACHE:    Class DELETED.\n");
#endif
#endif
	m_delete(cache, a);
      }
    }
  }
}

void create()
{
#ifdef CACHE_DEBUG
  perror("CACHE: Now online.\n");
#endif
  cache=([  ]);
  call_out(cache_clean, CACHE_TIME_OUT);
}
