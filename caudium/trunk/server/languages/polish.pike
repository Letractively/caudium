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

import ".";
inherit english;

array(string)    the_words = ({
    "rok", "miesi±c", "tydzieñ", "dzieñ"
});

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
    object  target = Calendar.Second("unix", timestamp)->set_language("polish");
    object  now = Now;

    if(!m) m=([]);

    if(!(m["full"] || m["date"] || m["time"]))
    {
        int dist;

        if (target > now)
            dist = -now->distance(target)->how_many(Calendar.Day);
        else
            dist = target->distance(now)->how_many(Calendar.Day);
      
        if (!dist)
            return "dzisiaj, " + target->format_mod();

        if (dist == -1)
            return "wczoraj, " + target->format_mod();

        if (dist == 1)
            return "jutro, " + target->format_mod(); 

        if (now->year_no() != target->year_no())
            return month(target->month_no()) +  " " + target->year_name());

    return month(target->month_no()) + " " + ordered(target->month_day());
}
  
if(m["full"])
    return target->format_mod() + ", " +
ordered(target->month_day()) + " " + 
month(target->month_no()) + " " +
target->year_name();
  
if(m["date"])
    return ordered(target->month_day()) + " " + month(target->month_no()) + " " +
target->year_name();
  
if(m["time"])
    return target->format_mod();
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

array aliases()
{
    return ({ "pl", "PL", "pol", "polski", "polish", "pl_PL" });
}

void create()
{
    Now = Calendar.now()->set_language("polish");
    initialize_months(Now);
    initialize_days(Now);
}
