/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2004 The Caudium Group
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
 */

inherit "wizard";
constant name= "Status//Process status";

constant doc = ("Shows various information about the pike process.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

string describe_global_status()
{
  return "Server uptime             : "+
    Caudium.msectos((time(1) - caudium->start_time)*1000) +"\n";
}

#define MB (1024*1024)

mixed page_0(object id, object conf)
{
  string res;
  mapping ru;
  int tmp, use_ru;
  array err;
  string out = "";
#if constant(System.getrusage)
  if(err = catch(ru=System.getrusage()))
#else
  if(err = catch(ru=mkmapping(({"utime","stime","maxrss","ixrss","idrss","isrss","minflt","majflt","nswap","inblock","oublock","msgsnd","msgrcv","nsignals","nvcsw","nivcsw","sysc","ioch","rtime","ttime","tftime","dftime","kftime","ltime","slptime","wtime","stoptime","brksize","stksize"}),predef::rusage())))
#endif
    return sprintf("<h1>Failed to get rusage information: </h1><pre>%s</pre>",
                   describe_backtrace(err));


  if(ru->utime)
    tmp=ru->utime/(time(1) - caudium->start_time+1);

  out += "<font size=\"+1\"><a href=\""+ caudium->config_url(id)+
         "Actions/?action=processstatus.pike&foo="+ time(1)+
         "\">Process status</a></font>"+ 
         "<pre>"+
	 describe_global_status()+
	 "CPU-Time used             : "+Caudium.msectos(ru[0]+ru[1])+
	 " ("+tmp/10+"."+tmp%10+"%)\n";
  if(ru->brksize)
	 out += sprintf("Resident set size (RSS)   : %.3f Mb\n",
			    (float)ru->brksize/(float)MB);
  if(ru->stksize)
	 out += sprintf("Stack size                : %.3f Mb\n",
			    (float)ru->stksize/(float)MB);
  if(ru->minflt)
	 out += "Page faults (non I/O)     : " + ru->minflt + "\n";
  if(ru->majflt)
	 out += "Page faults (I/O)         : " + ru->majflt+ "\n";
  if(ru->nswap)
	 out += "Full swaps (should be 0)  : " + ru->nswap + "\n";
  if(ru->inblock)
	 out += "Block input operations    : " + ru->inblock + "\n";
  if(ru->oublock)
	 out += "Block output operations   : " + ru->oublock + "\n";
  if(ru->msgsnd)
	 out += "IPC Messages sent         : " + ru->msgsnd + "\n";
  if(ru->msgrcv)
	 out += "IPC Messages received     : " + ru->msgrcv + "\n";
  if(ru->nsignals)
	 out += "Number of signals received: " + ru->nsignals + "\n";
  if(ru->sysc)
         out += "Number of system calls    : " + ru->sysc + "\n";
  if(ru->ioch)
         out += "Nb. of characters rd and w: " + ru->ioch + "\n";
  if(ru->nsignals)
         out += "Number of signals received: " + ru->nsignals + "\n";
  if(ru->nvcsw)
         out += "Number of voluntary CS    : " + ru->nvcsw + "\n";
  if(ru->nivcsw)
         out += "Nb of preemptions          : " + ru->nivcsw + "\n";

  out += "</pre>";
  return out;
}

int verify_0()
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }
