/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

string cvs_version = "$Id$";
string month(int num)
{
  return ({ "styczeñ", "luty", "marzec", "kwiecieñ", "maj",
	    "czerwiec", "lipiec", "sierpieñ", "wrzesieñ", "pa¼dziernik",
	    "listopad", "grudzieñ" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
   case 0:
    return ("buggy");
   default:
      return (i+".");
  }
}

string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return ("dzisiaj, "+ ctime(timestamp)[11..15]);
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return ("wczoraj, "+ ctime(timestamp)[11..15]);
  
    if((t1["yday"]-1) == t2["yday"] && t1["year"] == t2["year"])
      return ("jutro, "+ ctime(timestamp)[11..15]);
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (ordered(t1["mday"]) + " " + month(t1["mon"]+1));
  }
  if(m["full"])
    return (ctime(timestamp)[11..15]+", "+
	   ordered(t1["mday"]) + " " + 
           month(t1["mon"]+1) + " " +
           (t1["year"]+1900));
  if(m["date"])
    return (ordered(t1["mday"]) + " " + month(t1["mon"]+1) + " " +
       (t1["year"]+1900));
  if(m["time"])
    return (ctime(timestamp)[11..15]);
}


string number(int num)
{
  if(num<0)
    return ("minus "+number(-num));
  switch(num)
  {
   case 0:  return ("");
   case 1:  return ("jeden");
   case 2:  return ("dwa");
   case 3:  return ("trzy");
   case 4:  return ("cztery");
   case 5:  return ("piêæ");
   case 6:  return ("sze¶æ");
   case 7:  return ("siedem");
   case 8:  return ("osiem");
   case 9:  return ("dziewiêæ");
   case 10: return ("dziesiêæ");
   case 11: return ("jeden¶cie");
   case 12: return ("dwana¶cie");
   case 13: case 17..18: return (number(num-10)+"na¶cie");
   case 14: return ("czterna¶cie");
   case 15: return ("piêtna¶cie");
   case 16: return ("szesna¶cie");
   case 19: return ("dziewiêtna¶cie");
   case 20: return ("dwadzie¶cia");
   case 30: return ("trzydzie¶ci");
   case 40: return ("czterdziesci");
   case 50: return ("piêædziesi±t");
   case 60: return ("sze¶ædziesi±t");
   case 70: return ("siedemdziesi±t");
   case 80: return ("osiemdziesi±t");
   case 90: return ("dziewiêædziesi±t");
   case 21..29: case 31..39: 
   case 51..59: case 61..69: case 71..79: 
   case 81..89: case 91..99: case 41..49: 
     return (number((num/10)*10)+number(num%10));
   case 100..199: return ("sto"+number(num%100));
   case 200..299: return ("dwie¶cie"+number(num%100));
   case 300..499: return (number(num/100)+"sta "+number(num%100));
   case 500..999: return (number(num/100)+"set "+number(num%100));
   case 1000..1999: return ("tysi±c "+number(num%1000));
   case 2000..4999: return (number(num/1000)+" tysi±ce "+number(num%1000));
   case 5000..999999: return (number(num/1000)+" tysiêcy "+number(num%1000));
   case 1000000..1999999: 
     return (number(num/1000000)+" milion "+number(num%1000000));
   case 2000000..4999999: 
     return (number(num/1000000)+" miliony "+number(num%1000000));
   case 5000000..99999999: 
     return (number(num/1000000)+" milionów "+number(num%1000000));
   default:
    perror("foo\n"+ num +"\n");
    return ("duuuuu¿o ;)");
  }
}

string day(int num)
{
  return ({ "niedziela","poniedzia³ek","wtorek","¶roda",
	    "czwartek","pi±tek","sobota" })[ num - 1 ];
}

string day_short(int num)
{
  return ({ "N", "P", "W", "S", "C", "P", "S" })[ num - 1 ];
}

string words(int num)
{
  return ({ "rok", "miesi±c", "tydzieñ", "dzieñ" });
}

array aliases()
{
  return ({ "pl", "PL", "pol", "polski", "polish", "pl_PL" });
}



