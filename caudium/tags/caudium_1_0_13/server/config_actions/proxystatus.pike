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

/*
 * $Id$
 *
 * proxystatus was contributed by Wilhelm Köhler (wk@cs.tu-berlin.de)
 *
 * based on code from requeststatus.pike
 *
 */

inherit "wizard";
constant name= "Status//Proxy connections";

constant doc = ("Shows current proxy connections.");

constant more=0;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

string status(object mc)
{
  array rows = ({});
  array times = ({});
  foreach(indices(mc->requests), object foo){
    string res = "";
    if(!objectp(foo))
      continue;
    foreach(foo->ids, object id){
      if(!objectp(id))
	continue;
      if(!id->time)
	continue;
      object ret;
      res = (time()-id->time)+"s\t"+(foo->new?"new\t":"cached\t");
      if(catch(ret=foo->from->query_address())||!ret)
	res += "\tno server connection";
      else if(catch(ret=id->my_fd->query_address())||!ret)
	res += "\tno browser connection";
      else if(!foo->pipe)
	res += "\t";
      else {
        int sent;
        object stat;
        if(!catch(stat=foo->cache->file->stat())&&stat[1]>0){
          catch(stat[1]-=foo->cache->headers->head_size);
          if(foo->bytes_sent != stat[1]){
            foo->bytes_sent = stat[1];
	    foo->bytes_sent_time = stat[4];
          }
        } else if(!catch(sent=foo->pipe->bytes_sent())&&sent>0){
	  if(foo->bytes_sent != sent){
	    foo->bytes_sent = sent;
	    foo->bytes_sent_time = time();
	  }
        }
        int idle = time()-(foo->bytes_sent_time||time());
        res += (foo->bytes_sent||"")+"\t"+(idle?idle+"s idle":"");
      }
      res += "\t"+caudium->quick_ip_to_host(id->remoteaddr)+
             "\t\<a href=\"http://"+foo->name+"\">"+foo->name+"</a>";
    times += ({ id->time });
    rows += ({ res/"\t" });
    }
  } 
  if(sizeof(mc->requests)&&sizeof(rows)){
    times = sort(times, rows);
    return html_table( ({ "since", "cache", "bytes", "state",
      "browser connection", "server connection" }), rows);
  } else
    return "<b>No current proxy connections.</b>";
}

mixed page_0(object id, object mc)
{
  string res="";
  foreach(Array.sort_array(caudium->configurations,
			   lambda(object a, object b) {
			     return a->requests < b->requests;
			   }), object o) {
    if(!o->requests || !o->modules || !o->modules->proxy ||
       !o->modules->proxy->copies)
      continue;
    res += sprintf("<h3><a href=%s>%s</a><br>%s</h3>\n",
		   o->query("MyWorldLocation"),
		   o->name,
		   replace(o->status(), "<table>", "<table cellpadding=4>"));
    foreach(indices(o->modules->proxy->copies), int i){
      object out = o->modules->proxy->copies[i];
      gc();
      res+=status(out);
    }
  }
  if(!strlen(res))
    return "<b>There are no active virtual servers.</b>";
  return
    "<b>These are all virtual servers with proxy modules. They are sorted by the "
    "number of requests they have received - the most active being first. "
    "Servers which haven't recevied any requests are not listed.</b>" +
    res;
}

int verify_0(object id)
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }

