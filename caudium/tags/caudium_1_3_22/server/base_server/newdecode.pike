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
 */
/*
 * $Id$
 */

// The magic below is for the 'install' program

#ifndef roxenp
#if !constant(roxenp)
#define roxenp this_object()
#endif
#endif
#ifndef IN_INSTALL
// constant cvs_version = "$Id$";
#endif

#include <caudium.h>


void parse(string s, mapping mr);
void new_parse(string s, mapping mr);

private string decode_int(string foo, mapping m, string s, mapping res)
{
  if(arrayp(res->res)) res->res += ({ (int)s });  else  res->res = (int)s;
  return "";
}

private string decode_module(string foo, mapping m, string s, mapping res)
{
  if(arrayp(res->res)) 
    res->res += ({ s }); 
  else 
    res->res = s;
  return "";
}


private string decode_float(string foo, mapping m, string s, mapping res)
{
  if(arrayp(res->res)) res->res += ({ (float)s }); else  res->res = (float)s;
  return "";
}

private string decode_string(string foo, mapping m, string s, mapping res)
{
  s = replace(s, ({ "%3e", "%3c" }), ({ ">", "<" }) );
  if(arrayp(res->res)) res->res += ({ s  });  else   res->res = s;
  return "";
}

private string decode_list(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_multiset(@myres->res) }); 
  else
    res->res = aggregate_multiset(@myres->res);
  return "";
}


private string new_decode_list(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  new_parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_multiset(@myres->res) }); 
  else
    res->res = aggregate_multiset(@myres->res);
  return "";
}


private string decode_array(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  parse(s, myres); 

  if(arrayp(res->res)) 
    res->res += ({ myres->res }); 
  else
    res->res = myres->res;
  return "";
}

private string new_decode_array(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({}) ]);

  new_parse(s, myres); 

  if(arrayp(res->res)) 
    res->res += ({ myres->res }); 
  else
    res->res = myres->res;
  return "";
}


private string new_decode_mapping(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({ }) ]);
  
  new_parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_mapping(@myres->res) }); 
  else
    res->res = aggregate_mapping(@myres->res);

  return "";
}

private string decode_mapping(string foo, mapping m, string s, mapping res)
{
  mapping myres = ([ "res":({ }) ]);

  parse(s, myres);

  if(arrayp(res->res)) 
    res->res += ({ aggregate_mapping(@myres->res) }); 
  else
    res->res = aggregate_mapping(@myres->res);

  return "";
}

private string decode_variable(string foo, mapping m, string s, mapping res)
{
  mapping mr;

  mr = ([ "res":0 ]);
  
  parse(s, mr);
  res[m->name] = mr->res;

  return "";
}

private string new_decode_variable(string foo, mapping m, string s,
				   mapping res)
{
  mapping mr;

  mr = ([ "res":0 ]);
  
  new_parse(s, mr);
  res[m->name] = mr->res;

  return "";
}


string name_of_module( object m )
{
#ifndef IN_INSTALL
  string name;
  mapping mod;
  foreach(values(caudiump()->current_configuration->modules), mod)
  {
    if(mod->copies)
    {
      int i;
      if(!zero_type(i=search(mod->copies, m)))
	return mod->sname+"#"+i;
    } else 
      if(mod->enabled==m)
	return mod->sname+"#0"; 
  }
  return name;
#endif
}



void parse(string s, mapping mr)
{
  Caudium.parse_html(s, ([ ]),  
	     (["array":decode_array, 
	      "mapping":decode_mapping,
	      "list":decode_list,
	      "module":decode_module,
	      "int":decode_int, 
	      "string":decode_string, 
	      "float":decode_float ]), mr);
}


void new_parse(string s, mapping mr)
{
  Caudium.parse_html(s, ([ ]),  
	     (["a":new_decode_array, 
	      "map":new_decode_mapping,
	      "lst":new_decode_list,
	      "mod":decode_module,
	      "int":decode_int, 
	      "str":decode_string, 
	      "flt":decode_float ]), mr);
}

string decode_config_region(string foo, mapping mr, string s, mapping res2)
{
  mapping res = ([ ]);
  Caudium.parse_html(s, ([]), ([ "variable":decode_variable ]), res);
  res2[mr->name] = res;
  return "";
}

string new_decode_config_region(string foo, mapping mr, string s, mapping res2)
{
  mapping res = ([ ]);
  Caudium.parse_html(s, ([]), ([ "var":new_decode_variable ]), res);
  res2[mr->name] = res;
  return "";
}

mixed compat_decode_value( string val )
{
  if(!val || !strlen(val))  return 0;

  switch(val[0])
  {
  case '"':
    return replace(val[1 .. strlen(val)-2], "%0A", "\n");
      
  case '{':
   return Array.map(val[1 .. strlen(val)-2]/"},{", compat_decode_value);
      
  case '<':
   return aggregate_multiset(Array.map(val[1 .. strlen(val)-2]/"},{", compat_decode_value));

  default:
    if(search(val,".") != -1)
      return (float)val;
    return (int)val;
  }
}


private mapping compat_parse(string s)
{
  mapping res = ([ ]);
  string current;
  foreach(s/"\n", s) 
  {
    if(strlen(s))
    {
      switch(s[0])
      {
      case ';':
	continue;
      case '[':
	sscanf(s, "[%s]", current);
	res[ current ] = ([ ]);
	break;
      default:
	string a, b;
	sscanf(s, "%s=%s", a, b);
	res[current][ a ] = compat_decode_value(b);
      }
    }
  }
  return res;
}


mapping decode_config_file(string s)
{
//  report_debug("Decoding \n%s\n",s);
  mapping res = ([ ]);
  if(!s || !sizeof(s)) return res; // Empty file..
  switch(s[0])
  {
  case ';':
    // Old (and stupid...) configuration file format 
    perror("Reading very old (pre b11) configuration file format.\n");
    return compat_parse(s);
    break;
   case '4': // Pre b15 configuration format. Could encode most stuff, but not
	     // everything.
    perror("Reading old (pre b15) configuration file format.\n");
    Caudium.parse_html(s, ([]), ([ "region":decode_config_region ]), res);
    return res;
   case '5': // New (binary) format. Fast and lean, but not very readable
	     // for a human.. :-)
    return decode_value(s[1..]); // C-function.
   case '6': // Newer ((somewhat)readable) format. Can encode everything, _and_
             // a mere human can edit it.
    
//    trace(1);
    Caudium.parse_html(s, ([]), ([ "region":new_decode_config_region ]), res);
//    trace(0);
//    report_debug("Decoded value is: %O\n", res);
    return res;
   }
}


#if 1
private string encode_mixed(mixed from)
{
  if(stringp(from))
    return "<str>"+replace(from, ({ ">", "<" }), ({ "%3e", "%3c" })  )
           + "</str>";
  else if(intp(from))
    return "<int>"+from+"</int>";
  else if(floatp(from))
    return "<flt>"+from+"</flt>";
  else if(arrayp(from))
    return "\n  <a>\n    "+Array.map(from, encode_mixed)*"\n    "
          +"\n  </a>\n";
  else if(multisetp(from))
    return "\n  <lst>\n    "
      +Array.map(indices(from),encode_mixed)*"\n    "+"\n  </lst>\n";
  else if(objectp(from)) // Only modules.
    return "<mod>"+name_of_module(from)+"</mod>";
  else if(mappingp(from))
  {
    string res="<map>";
    mixed i;
    foreach(indices(from), i)
      res += "    " + encode_mixed(i) + " : " + encode_mixed(from[i])+"\n";
    return res + "  </map>\n";
  }
}

string encode_config_region(mapping m)
{
  string res = "";
  string v;
  foreach(indices(m), v)
    res += " <var name="+sprintf("%-22s", "'"+v+"'>")+encode_mixed(m[v])
        +" </var>\n";
  return res;
}

string encode_regions(mapping r)
{
  string v;
  string res = "6 <- Do not remove this number!   "
    "Caudium save file format>\n\n";
  foreach(indices(r), v)
    res += "<region name='"+v+"'>\n" + encode_config_region(r[v]) 
           + "</region>\n\n";
  return res;
}
#else
string encode_regions(mapping r)
{
  mapping mr = copy_value(r);
  string i, j;
  foreach(indices(mr), i)
    foreach(indices(mr[i]), j)
      if(objectp(mr[i][j]))
	mr[i][j] = name_of_module( mr[i][j] );
  return "5"+encode_value(mr);
}
#endif

