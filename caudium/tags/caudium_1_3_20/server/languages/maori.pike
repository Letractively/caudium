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

/* Maaori (New Zealand) */
/* any bugs in this file were inserted by Jason Rumney <jasonr@pec.co.nz> */
/*
 * name = "Maaori (New Zealand) language plugin ";
 * doc = "Handles the conversion of numbers and dates to Maaori. You have "
"to restart the server for updates to take effect. Translation by Jason "
"Rumney (jasonr@pec.co.nz)";
 */


constant cvs_version = "$Id$";

string month( int num )
     {
	return ( {
	   "Haanuere", "Pepuere", "Maehe", "Aaperira", "Mei",
	   "Hune", "Huurae", "Aakuhata", "Hepetema", "Oketopa",
	   "Nowema", "Tiihema" 
	})[num-1];
     }

string number( int i ) ;

string ordered(int i)
     {
	return "tua" + number(i) ;
     }

string date(int timestamp, mapping|void m)
     {
	mapping t1=localtime(timestamp) ;
	mapping t2=localtime(time(0));

	if (!m) m=([]);

	if (!(m["full"] || m["date"] || m["time"]))
	  {
	     if(t1["year"] != t2["year"])
	       return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
	     return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
	  }
	if(m["full"])
	  return ctime(timestamp)[11..15]+", "+
	month(t1["mon"]+1) + " te "
	+ ordered(t1["mday"]) + ", " +(t1["year"]+1900);
	if(m["date"])
	  return month(t1["mon"]+1) + " te "  + ordered(t1["mday"])
	+ " o te tau " +(t1["year"]+1900);
	if(m["time"])
	  return ctime(timestamp)[11..15];
     }


string number(int num)
{
  if(num<0)
    return number(-num)+" tango";
  switch(num)
  {
   case 0:  return "kore";
   case 1:  return "tahi";
   case 2:  return "rua";
   case 3:  return "toru";
   case 4:  return "whaa";
   case 5:  return "rima";
   case 6:  return "ono";
   case 7:  return "whitu";
   case 8:  return "waru";
   case 9:  return "iwa";
   case 10: return "tekau";
   case 11..19: return "tekau ma "+number(num-10) ; 
   case 20..99: return number(num/10)+" "+number(10+num%10) ;
   case 100: return "rau" ;
   case 101..199: return "rau ma "+number(num-100);
   case 200..999: return number(num/100)+" "+number(100+num%100) ;
   case 1000: return "mano" ;
   case 1001..1999: return "mano ma "+ number(num-1000);
   case 2000..999999: return number(num/1000)+" "+number(1000+num%1000); 
   default:
    return "tini ("+num+")";
  }
}

string day(int num)
{
  return ({ "Raatapu","Mane","Tuurei","Wenerei",
	    "Taaite","Paraire","Haatarei" })[ num - 1 ];
}

array aliases()
{
  return ({ "mi", "maori", "maaori" });
}
