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

/*
 * name = "Hungarian language plugin ";
 * doc = "Handles the conversion of numbers and dates to Hungarian. You have to restart the server for updates to take effect.";
 *
 */

/*  Hungarian Language module for Roxen Web Server, v1.0
 *  This module copyrighted by Zsolt Varga (redax@agria.hu), but it is 
 *  free to use in the Roxen Web Server, under the terms of GNU GPL.
 *  You can modify this code, as long as my name not removed from the
 *  source.
 *
 *  2001/11/28 corrected some syntactical bug. 
 *		thanks to Attila Toth <cirby@rosvig.hu> 
 */

string cvs_version = "$Id$";

import ".";
inherit english;

array(string)    the_words = ({
    "év", "hónap", "hét", "nap"
});

string ordered(int i)
{
    if(!i)
      return "&eacute;rtelmezhetetlen";
    return i+".";
}


string date(int timestamp, mapping|void m)
{
    object  target = Calendar.Second("unix", timestamp)->set_language("hungarian");
    object  now = Now;
    string  curtime = target->format_mod();
    string  curday = ordered(target->month_day());
    string  curmonth = month(target->month_no());
    string  curyear = target->year_name();
    
    if(!m) m=([]);

    if(!(m["full"] || m["date"] || m["time"]))
    {
        int     dist;
        
        if (target > now)
            dist = -now->distance(target)->how_many(Calendar.Day);
        else
            dist = target->distance(now)->how_many(Calendar.Day);
      
        if (!dist)
            return "ma, " + curtime;
  
        if (dist == -1)
            return "tegnap, " + curtime;
  
        if (dist == 1)
            return "holnap, " + curtime;
  
        if(now->year_no() != target->year_no())
            return curyear + ". " + curmonth;

        return curmonth + ". " + curmonth;
    }
        
    if(m["full"])
        return curyear + ". " + curmonth + " " + curday + ", " + curtime;

    if(m["date"])
        return curyear + ". " + curmonth + " " + curday;

    if(m["time"])
        return curtime;
}

string number(int num)
{
  string jel = "";
  
  if(num<0)
    return "minusz "+number(-num);

  switch(num)
  {
   case 0:  return "";
   case 1:  return "egy";
   case 2:  return "kett&otilde;";
   case 3:  return "h&aacute;rom";
   case 4:  return "n&eacute;gy";
   case 5:  return "&ouml;t";
   case 6:  return "hat";
   case 7:  return "h&eacute;t";
   case 8:  return "nyolc";
   case 9:  return "kilenc";
   case 10: return "t&iacute;z";
   case 11..19: return "tizen"+number(num%10);
   case 20: return "h&uacute;sz";
   case 21..29: return "huszon"+number(num%10);

   case 30: return "harminc";
   case 40: return "negyven";
   case 50: return "&ouml;tven";
   case 60: return "hatvan";
   case 70: return "hetven";
   case 80: return "nyolcvan";
   case 90: return "kilencven";

   case 31..39: case 41..49: case 51..59: 
   case 61..69: case 71..79: case 81..89: 
   case 91..99: 
     return number((num/10)*10) + number(num%10);

   case 100..999:
     return number(num/100) + "sz&aacute;z" + number(num%100);

   case 1000..2000:
     return number(num/1000) + "ezer" + number(num%1000);

   case 2001..999999:
     {
       if (num%1000>0)
         jel = "-";
       return number(num/1000) + "ezer" + jel + number(num%1000);
     }

   case 1000000..999999999:
     {
       if (num%1000000>0)
         jel = "-";
       return number(num/1000000) + "milli&oacute;" + jel + number(num%1000000);
     }

   default:
    return "sok";
  }
}

array aliases()
{
  return ({ "hu", "hun", "magyar", "hungarian" });
}

void create()
{
    Now = Calendar.now()->set_language("hungarian");
    initialize_months(Now);
    initialize_days(Now);
}
