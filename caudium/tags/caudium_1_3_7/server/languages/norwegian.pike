/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
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

/*
constant cvs_version = "$Id$";
  norwegian.lpc         morten@nvg.unit.no
  St�tte for norsk p� www-serveren..
  name="Norwegian language plugin";
  doc="St�tte for norsk p� www-serveren.. morten@nvg.unit.no";
*/

string month(int num)
{
  return ({ "januar", "februar", "mars", "april", "mai",
            "juni", "juli", "august", "september", "oktober",
            "november", "december" })[num - 1];
}

string ordered(int i)
{
    return  i+".";
}

string date(int timestamp, mapping m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "i dag, klokken " + ctime(timestamp)[11..15];
  
    if(t1["yday"] == t2["yday"]-1 && t1["year"] == t2["year"])
      return "i g�r, klokken " + ctime(timestamp)[11..15];
  
    if(t1["yday"] == t2["yday"]+1 && t1["year"] == t2["year"])
      return "i morgen, ved "  + ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return month(t1["mon"]+1) + " " + (t1["year"]+1900);
    else
      return "den " + t1["mday"] + " " + month(t1["mon"]+1);
  }
  if(m["full"])
    return sprintf("%s, den %s %s %d",
                   ctime(timestamp)[11..15],
                   ordered(t1["mday"]),
                   month(t1["mon"]+1), t1["year"]+1900);
  if(m["date"])
    return sprintf("den %s %s %d", ordered(t1["mday"]),
                   month(t1["mon"]+1), t1["year"]+1900);

  if(m["time"])
    return ctime(timestamp)[11..15];
}

string number(int num)
{
  if(num<0)
    return "minus "+number(-num);
  switch(num)
  {
   case 0:  return "null";
   case 1:  return "en";
   case 2:  return "to";
   case 3:  return "tre";
   case 4:  return "fire";
   case 5:  return "fem";
   case 6:  return "seks";
   case 7:  return "sju";
   case 8:  return "�tte";
   case 9:  return "ni";
   case 10: return "ti";
   case 11: return "elleve";
   case 12: return "tolv";
   case 13: return "tretten";
   case 14: return "fjorten";
   case 15: return "femten";
   case 16: return "seksten";
   case 17: return "sytten";
   case 18: return "atten";
   case 19: return "nitten";
   case 20: return "tjue";
   case 30: return "tretti";
   case 40: return "forti";
   case 50: return "femti";
   case 60: return "seksti";
   case 70: return "sytti";
   case 80: return "�tti";
   case 90: return "nitti";
   case 21..29: case 31..39: case 41..49:
   case 51..59: case 61..69: case 71..79:
   case 81..89: case 91..99:
     return number((num/10)*10)+number(num%10);
   case 100..999: return number(num/100)+"hundre"+number(num%100);
   case 1000..999999: return number(num/1000)+"tusen"+number(num%1000);
   case 1000000..999999999:
     return number(num/1000000)+"millioner"+number(num%1000000);
   default:
    return "ekstremt mange";
  }
}

string day(int num)
{
  return ({ "s�ndag","mandag","tisdag","onsdag",
            "torsdag","fredag","l�rdag" }) [ num - 1 ];
}

array aliases()
{
  return ({ "no", "nor", "norwegian", "norsk" });
}

