/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2003 The Caudium Group
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

/* name="Croatian language support for Roxen";
   doc="Author: Klara Makovac 1997/07/02<br>"
   "E-mail: makovac@istria.nexus.com.hr<br>"
   "SDC-CIP Co. Ernesta Milosa 25, 52470 Umag, Croatia<br>";
   "tel. +385 52 741 967<br>";
   You can do anything you want with this code.
   Don't change the name of the author !!!
   Please consult me before upgrading croatian.pike.
*/



string cvs_version = "$Id$";
string month(int num)
{
  return ({ "Sijecanj", "Veljaca", "Ozujak", "Travanj", "Svibanj",
	    "Lipanj", "Srpanj", "Kolovoz", "Rujan", "Listopad",
	    "Studeni", "Prosinac" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
   case 0:
    return "pogresan";
   default:
    return i+".";
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
      return "danas, "+ ctime(timestamp)[11..15];

    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "jucer, "+ ctime(timestamp)[11..15];

    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "danas, "+ ctime(timestamp)[11..15];

    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           ordered(t1["mday"]) + " "
           + month(t1["mon"]+1) + " " +(t1["year"]+1900) + ".";
  if(m["date"])
    return ordered(t1["mday"]) + " " + month(t1["mon"]+1)
      + " " + (t1["year"]+1900) + ".";
  if(m["time"])
    return ctime(timestamp)[11..15];
}


string number(int num)
{
  if(num<0)
    return "minus "+number(-num);
  switch(num)
  {
   case 0:  return "";
   case 1:  return "jedan";
   case 2:  return "dva";
   case 3:  return "tri";
   case 4:  return "cetiri";
   case 5:  return "pet";
   case 6:  return "sest";
   case 7:  return "sedam";
   case 8:  return "osam";
   case 9:  return "devet";
   case 10: return "deset";
   case 11: return "jedanaest";
   case 12: return "dvanaest";
   case 13: return "trinaest";
   case 14: return "cetrnaest";
   case 15: return "petnaest";
   case 16: return "sesnaest";
   case 17: return "sedamnaest";
   case 18: return "osamnaest";
   case 19: return "devetnaest";
   case 40: return "cetrdeset";
   case 50: return "pedeset";
   case 60: return "sesdeset";
   case 90: return "devedeset";
   case 20: case 30: case 70: case 80:
     return number(num/10)+"deset";
   case 21..29: case 31..39:
   case 51..59: case 61..69: case 71..79:
   case 81..89: case 91..99: case 41..49:
     return number((num/10)*10)+" "+number(num%10);
   case 100: return "sto";
   case 200..299: return "dvije stotine "+number(num%100);
   case 300..399: return "tri stotine "+number(num%100);
   case 600..699: return "sest stotina "+number(num%100);
   case 101..199: return "sto "+number(num%100);
   case 400..599: case 700..999: return number(num/100)+"sto "+number(num%100);
   case 1000..1999: return "tisucu "+number(num%1000);
   case 2000..2999: return "dvije tisuce "+number(num%1000);
   case 3000..4999: return number(num/1000)+" tisuce "+number(num%1000);
   case 1000000..999999999:
     if ( ((num%10000000)/1000000)==1 ) return number(num/1000000)+" milijun "+number(num%1000000);
     return number(num/1000000)+" milijuna "+number(num%1000000);
   default:
    if ( (((num%100000)/1000)<11) || (((num%100000)/1000)>19) ) {
     if ( (((num%10000)/1000)==3) || (((num%10000)/1000)==4) ) return
number((num-(num%1000))/1000)+" tisuce "+number(num%1000);
     if (((num%10000)/1000)==2) return number((num-(num%10000))/1000)+" dvije tisuce "+number(num%1000);
     if (((num%10000)/1000)==1) return number((num-(num%10000))/1000)+" tisucu "+number(num%1000); };
    if ((num>4999) && (num<1000000)) return number(num/1000)+" tisuca "+number(num%1000);
    perror("uf\n"+ num +"\n");
    return "mnogo";
  }
}

string day(int num)
{
  return ({ "Nedjelja","Ponedjeljak","Utorak","Srijeda",
	    "Cetvrtak","Petak","Subota" })[ num - 1 ];
}

array aliases()
{
  return ({ "hr", "cro", "croatian" });
}


