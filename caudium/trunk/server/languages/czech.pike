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

/* name="Czech language support for Roxen";
   doc="Author: Jan Petrous 16.10.1997<br>"
   "Based on Slovenian language module by Iztok Umek<br>"
   "E-mail: hop@unibase.cz<br>";

   You can do enything you want this code.
   Please consult me before modifying czech.pike.

   13.05.1998	hop	corrected one a little bug
			All texts are now in ISO 8859-2
   16.11.1998	hop	corrected name of months and days
             		(First letter must be lower case)

*/
constant cvs_version = "$Id$";
string month(int num)
{
  return ({ "ledna", "�nora", "b�ezna", "dubna", "kv�tna",
	    "�ervna", "�ervence", "srpna", "z���", "��jna",
	    "listopadu", "prosince" })[ num - 1 ];
}

string ordered(int i)
{
  if(i==0)
    return "buggy";
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
      return ("dnes, "+ ctime(timestamp)[11..15]);
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return ("v�era, "+ ctime(timestamp)[11..15]);
  
    if((t1["yday"]-1) == t2["yday"] && t1["year"] == t2["year"])
      return ("z�tra, "+ ctime(timestamp)[11..15]);
  
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
   case 1:  return ("jedna");
   case 2:  return ("dv�");
   case 3:  return ("t�i");
   case 4:  return ("�ty�i");
   case 5:  return ("p�t");
   case 6:  return ("�est");
   case 7:  return ("sedm");
   case 8:  return ("osm");
   case 9:  return ("dev�t");
   case 10: return ("deset");
   case 11: return ("jeden�ct");
   case 12: return ("dvan�ct");
   case 13: case 16..18: return (number(num-10)+"n�ct");
   case 14: return ("�trn�ct");
   case 15: return ("patn�st");
   case 19: return ("devaten�ct");
   case 20: return ("dvacet");
   case 30: return ("t�icet");
   case 40: return ("�ty�icet");
   case 50: return ("pades�t");
   case 60: return ("�edes�t");
   case 70: return ("sedmdes�t");
   case 80: return ("osmdes�t");
   case 90: return ("devades�t");
   case 21..29: case 31..39: 
   case 51..59: case 61..69: case 71..79: 
   case 81..89: case 91..99: case 41..49: 
     return (number((num/10)*10)+number(num%10));
   case 100..199: return ("sto"+number(num%100));
   case 200..299: return ("dv�st� "+number(num%100));
   case 300..499: return (number(num/100)+"sta "+number(num%100));
   case 500..999: return (number(num/100)+"set "+number(num%100));
   case 1000..1999: return ("tis�c "+number(num%1000));
   case 2000..2999: return ("dva tis�ce "+number(num%1000));
   case 3000..999999: return (number(num/1000)+" tis�c "+number(num%1000));
   case 1000000..999999999: 
     return (number(num/1000000)+" milion "+number(num%1000000));
   default:
    perror("foo\n"+ num +"\n");
    return ("hodn�");
  }
}

string day(int num)
{
  return ({ "ned�le","pond�l�","�ter�","st�eda",
	    "�tvrtek","p�tek","sobota" })[ num - 1 ];
}

array aliases()
{
  return ({ "cs", "cz", "cze", "czech" });
}



