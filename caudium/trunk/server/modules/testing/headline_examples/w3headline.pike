#!/usr/bin/env pike

/* w3headline.pike - Roxen pike script to output headlines on WWW.
 * 
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */


import ".";

mapping sites = ([]);

int no_reload() { return 1; }

void update_me(object me)
{
  werror("Updated %s\n", me->site);
  sites[me->site] = me;
  fetching--;
}

void fetch_failed(object me)
{
  werror("%s failed\n", me->site);
  sites[me->site] = me;
  fetching--;
  
}

int fetching=0;

string parse(object|void id)
{
  int to_fetch;
  add_constant("log_event", lambda(mixed ... args) { } );
  add_constant("hversion", "1.0");
  add_constant("trim",Headlines.Tools()->trim);
   
  if(!sizeof(sites) )
    foreach(indices(Headlines.Sites), string site)
    {
      object me = Headlines.Sites[ site ]();
      //      trace(3);
      fetching++;
      write("Fetching %s.\n", site);
      me->refetch(update_me, fetch_failed);
      //      trace(0);
    }
//  while(fetching)
    sleep(30);
	
  //  else if(id->pragma["no_cache"]) {
  //    values(sites)->refetch(update_me);
  //  }
  //  if(to_fetch) while(sizeof(sites) != to_fetch)
  //    sleep(0.1);
  string out = "";
  foreach(indices(sites), string name)
  {
    out += sprintf("<h3>%s</h3><pre>\n%s</pre>",
		   name, (string)sites[name]);
  }
  return out;
}
	   
void main()
{
  write(parse());
}
