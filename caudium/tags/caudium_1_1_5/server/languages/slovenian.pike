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

/* name="Slovenian language support for Roxen ";
   doc="Author: Iztok Umek 7. 8. 1997<br>"
   "Help by: Henrik Grubbstr�m <grubba@idonex.se> tnx!<br>"
   "E-mail: iztok.umek@snet.fri.uni-lj.si<br>";
   You can do anything you want with this code.
   Please consult me before modifying slovenian.pike.
*/

string cvs_version = "$Id$";
string month(int num)
{
  return ({ "Januar", "Februar", "Marec", "April", "Maj",
	    "Junij", "Julij", "Avgust", "September", "Oktober",
	    "November", "December" })[ num - 1 ];
}

string number(int num)
{
  if(num<0)
    return "minus "+number(-num);
  switch(num)
  {
   case 0:  return "";
   case 1:  return "ena";
   case 2:  return "dva";
   case 3:  return "tri";
   case 4:  return "�tiri";
   case 5:  return "pet";
   case 6:  return "�est";
   case 7:  return "sedem";
   case 8:  return "osem";
   case 9:  return "devet";
   case 10: return "deset";
   case 11..19: return number(num%10)+"najst";
   case 20: return "dvajset";
   case 30: case 40: case 50: case 60: case 70: case 80: case 90:
     return number(num/10)+"deset";
   case 21..29: case 31..39: case 41..49: case 51..59: case 61..69:
   case 71..79: case 81..89: case 91..99:
     return number(num%10)+"in"+number((num/10)*10);
   case 100: return "sto";
   case 101..199: return "sto "+number(num%100);
   case 200..299: return "dvesto "+number(num%100);
   case 300..999: return number(num/100)+"sto "+number(num%100);
   case 1000: return "tiso�";
   case 1001..1999: return "tiso� "+number(num%1000);
   case 2000..999999: return number(num/1000)+" tiso� "+number(num%1000);
   case 1000000..1999999:
     return "milijon "+number(num%1000000);
   case 2000000..2999999: 
     return number(num/1000000)+" milijona"+number(num%1000000);
   case 3000000..4999999:
     return number(num/1000000)+" milijone"+number(num%1000000);
   case 5000000..999999999:
     return number(num/1000000)+" milijonov"+number(num%1000000);
     if ( ((num%10000000)/1000000)==1 ) return number(num/1000000)+" milijon "+number(num%1000000);
   return "veliko";
  }
}

mapping(int:string) small_orders = ([ 1: "prvi", 2: "drugi", 3: "tretji",
                                     4: "�etrti", 7: "sedmi", 8: "osmi" ]);

string ordered(int i)
{
  int rest2 = i%1000000;
  int rest1 = i%1000;
  int rest = i%100;
  int base = i-rest;
  if (!i) {
    return("napacen");
  }
  if (!rest2) {
    return replace(number(i)+"ti"," ","");
  }
  if (!rest1) {
    return replace(number(i)+"i"," ","");
  }
  if (!rest) {
    return replace(number(i)+"ti"," ","");
  }
  if (small_orders[rest])
    return replace((base ? (number(base)+" ") : "")+small_orders[rest]," ","");
  else
    return replace(number(i)+"i"," ","");
}


string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "danes, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "v�eraj, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "danes, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (t1["mday"]+1 + ". " + month(t1["mon"]+1));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           (t1["mday"]) + ". "
           + month(t1["mon"]+1) + " " +(t1["year"]+1900);
  if(m["date"])
    return (t1["mday"]) + ". " + month(t1["mon"]+1)
      + " " + (t1["year"]+1900);
  if(m["time"])
    return ctime(timestamp)[11..15];
}



string day(int num)
{
  return ({ "Nedelja","Ponedeljek","Torek","Sreda",
	    "�etrtek","Petek","Sobota" })[ num - 1 ];
}

array aliases()
{
  return ({ "si", "svn", "slovenian" });
}

