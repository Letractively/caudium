/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
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

/* From: Tvns B|ker <bueker@bidnix.bid.fh-hannover.de> 
string cvs_version = "$Id$";
   Subject: New 'german.lpc' ...
 
   Hi,
 
   I got a new 'german.lpc' for the distribution. It replaces
   the 'ter' in ordered() with a '.' and puts the date issued
   by e. g. <modified since lang=de> to e. g. 'am 22. Septemper'
   which is more frequently used than 'Septemper 22ter' in
   Germany.
 */

/*
 * name = "German language plugin ";
 * doc = "Handles the conversion of numbers and dates to German. You have to restart the server for updates to take effect. Translation by Tvns B�ker (bueker@bidnix.bid.fh-hannover.de)";
 */

string month(int num)
{
  return ({ "Januar", "Februar", "M�rz", "April", "Mai",
	    "Juni", "Juli", "August", "September", "Oktober",
	    "November", "Dezember" })[ num - 1 ];
}

string ordered(int i)
{
  return i+".";
}

string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));
 
  if(!m) m=([]);
 
  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "heute, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "gestern, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "morgen, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return ordered(t1["mday"]) + " " + (month(t1["mon"]+1));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           ordered(t1["mday"]) +" "+
           month(t1["mon"]+1) +" "+ (t1["year"]+1900);
  if(m["date"])
    return ordered(t1["mday"])+" "+month(t1["mon"]+1)
      + " im Jahre des Herrn " +(t1["year"]+1900);
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
   case 1:  return "eins";
   case 2:  return "zwei";
   case 3:  return "drei";
   case 4:  return "vier";
   case 5:  return "f�nf";
   case 6:  return "sechs";
   case 7:  return "sieben";
   case 8:  return "acht";
   case 9:  return "neun";
   case 10: return "zehn";
   case 11: return "elf";
   case 12: return "zw�lf";
   case 13..15:
   case 18..19: return number(num%10)+"zehn";
   case 16: return "sechzehn";
   case 17: return "siebzehn";
   case 20: return "zwanzig";
   case 30: return "drei�ig";
   case 70: return "siebzig";
   case 40: case 50: case 60: case 80: case 90:
     return number(num/10)+"zig";

   case 21: case 31: case 41: case 51: case 61: case 71: case 81: case 91:
     return "einund"+number((num/10)*10);
   case 22..29: case 32..39: case 42..49:
   case 52..59: case 62..69: case 72..79: 
   case 82..89: case 92..99:
     return number(num%10)+"und"+number((num/10)*10);
   case 100..199: return "einhundert"+number(num%100);
   case 200..999: return number(num/100)+"hundert"+number(num%100);
   case 1000..1999: return "eintausend"+number(num%1000);
   case 2000..999999: return number(num/1000)+"tausend"+number(num%1000);
   case 1000000..1999999:
     return "eine Million "+number(num%1000000);
   case 2000000..999999999: 
     return number(num/1000000)+" Millionen "+number(num%1000000);
   default:
    return "verdammt viele";
  }
}

string day(int num)
{
  return ({ "Sonntag","Montag","Dienstag","Mittwoch",
	    "Donnerstag","Freitag","Samstag" })[ num - 1 ];
}

array aliases()
{
  return ({ "de", "deu", "deutsch", "german" });
}
