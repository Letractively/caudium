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
    caudium->msectos((time(1) - caudium->start_time)*1000) +"\n";
}

#define MB (1024*1024)

mixed page_0(object id, object mc)
{
  string res;
  array(int) ru;
  int tmp, use_ru;
  array err;
  if(err = catch(ru=rusage()))
    return sprintf("<h1>Failed to get rusage information: </h1><pre>%s</pre>",
		   describe_backtrace(err));

  if(ru[0])
    tmp=ru[0]/(time(1) - caudium->start_time+1);

  return (/* "<font size=\"+1\"><a href=\""+ caudium->config_url(id)+
	     "Actions/?action=processstatus.pike&foo="+ time(1)+
	     "\">Process status</a></font>"+ */
	  "<pre>"+
	  describe_global_status()+
	  "CPU-Time used             : "+caudium->msectos(ru[0]+ru[1])+
	  " ("+tmp/10+"."+tmp%10+"%)\n"
	  +(ru[-2]?(sprintf("Resident set size (RSS)   : %.3f Mb\n",
			    (float)ru[-2]/(float)MB)):"")
	  +(ru[-1]?(sprintf("Stack size                : %.3f Mb\n",
			    (float)ru[-1]/(float)MB)):"")
	  +(ru[6]?"Page faults (non I/O)     : " + ru[6] + "\n":"")
	  +(ru[7]?"Page faults (I/O)         : " + ru[7] + "\n":"")
	  +(ru[8]?"Full swaps (should be 0)  : " + ru[8] + "\n":"")
	  +(ru[9]?"Block input operations    : " + ru[9] + "\n":"")
	  +(ru[10]?"Block output operations   : " + ru[10] + "\n":"")
	  +(ru[11]?"Messages sent             : " + ru[11] + "\n":"")
	  +(ru[12]?"Messages received         : " + ru[12] + "\n":"")
	  +(ru[13]?"Number of signals received: " + ru[13] + "\n":"")
	  +"</pre>");
}

int verify_0()
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }
