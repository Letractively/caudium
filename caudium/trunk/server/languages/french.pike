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

string cvs_version = "$Id$";
Created by:

---------------------+--------------------------------------------------
Patrick KREMER       | U.c. de Louvain (Belgium)  Institute of Geography
kremer@geog.ucl.ac.be| Xin1-Lu3wen4 Da4xue2 (Bi3li4shi2)  Di4li3xue2 Xi4
fax:++32-10/472877   | Pl. Pasteur,3   B-1348 Louvain-la-Neuve   Belgium
---------------------+--------------------------------------------------
http://ftp.geog.ucl.ac.be/~patrick/


*/

/*
 * name = "French language plugin ";
 * doc = "Handles the conversion of numbers and dates to French. You have to restart the server for updates to take effect. Translation by Patrick Kremer.";
 */

import ".";
inherit english;

array(string)    the_words = ({
    "année", "mois", "semaine", "jour"
});

string ordered(int i)
{
    switch(i)
    {
        case 1:
            return "1:ier"; 
        default:
            return (string)i;
    }
}

string date(int timestamp, mapping|void m)
{
    object  target = Calendar.Second("unix", timestamp)->set_language("french");
    object  now = Now;
    string  curtime = target->format_mod();
    string  curday = ordered(target->month_day());
    string  curmonth = month(target->month_no());
    string  curyear = target->year_name();
    
    if(!m) m=([]);

    if(!(m["full"] || m["date"] || m["time"]))
    {
        int dist;

        if (target > now)
            dist = -now->distance(target)->how_many(Calendar.Day);
        else
            dist = target->distance(now)->how_many(Calendar.Day);
        
        if (!dist)
            return "aujourd'hui, " + curtime;
  
        if (dist == -1)
            return "hier, "+ curtime;
  
        if (dist == 1)
            return "demain, "+ curtime;
  
        if(now->year_no() != target->year_no())
            return curmonth + " " + curyear;
        
        return curday + " " + curmonth;
    }
    
    if(m["full"])
        return curtime + ", le "+ curday + " "  + curmonth + " de l'année " + curyear;
    
    if(m["date"])
        return curday + " "  + curmonth + " " + curyear;
    
    if(m["time"])
        return curtime;
}


string number(int num)
{
    if(num<0)
        return "moins "+number(-num);
    switch(num)
    {
        case 0:  return "zéro";
        case 1:  return "une";
        case 2:  return "deux";
        case 3:  return "trois";
        case 4:  return "quatre";
        case 5:  return "cinq";
        case 6:  return "six";
        case 7:  return "sept";
        case 8:  return "huit";
        case 9:  return "neuf";
        case 10: return "dix";
        case 11: return "onze";
        case 12: return "douze";
        case 13: return "treize";
        case 14: return "quatorze";
        case 15: return "quinze";
        case 16: return "seize";
        case 17: return "dix-sept";
        case 18: return "dix-huit";
        case 19: return "dix-neuf";
        case 20: return "vingt";
        case 30: return "trente";
        case 40: return "quarante";
        case 50: return "cinquante";
        case 60: return "soixante";
        case 80: return "quatre-vingt";
        case 21: case 31: case 41:
        case 51: case 61:
            return number((num/10)*10)+"-et-un";
        case 71: case 91:
            return number((num/10)*10-10)+"-et-onze";
        case 22..29: case 32..39: case 42..49:
        case 52..59: case 62..69: case 81..89: 
            return number((num/10)*10)+"-"+number(num%10);
        case 70: case 72..79: case 90: case 92..99:
            return number((num/10)*10-10)+"-"+number((num%10)+10);
        case 200: case 300: case 400: case 500:
        case 600: case 700: case 800: case 900:
            return number(num/100)+" cents";
        case 100..199:
            return "cent "+number(num%100);
        case 201..299: case 301..399:
        case 401..499: case 501..599: case 601..699:
        case 701..799: case 801..899: case 901..999: 
            return number(num/100)+" cent "+number(num%100);
        case 1000..1999: return "mille "+number(num%1000);
        case 2000..999999: return number(num/1000)+" mille "+number(num%1000);
        case 1000000:
            return "un million";
        case 1000001..1999999:
            return number(num/1000000)+" million "+number(num%1000000);
        case 2000000..999999999:
            if(num%1000000 == 0)
                return number(num/1000000)+" millions de ";
            return number(num/1000000)+" millions "+number(num%1000000);
        default:
            return "beaucoup";
    }
}

array aliases()
{
    return ({ "fr", "fra", "français", "french" });
}

void create()
{
    Now = Calendar.now()->set_language("french");
    initialize_months(Now);
    initialize_days(Now);
}
