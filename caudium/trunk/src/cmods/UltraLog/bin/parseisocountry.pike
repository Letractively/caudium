#!/usr/local/bin/pike

constant cvs_version = "$Id$";
/* ftp://ftp.ripe.net/iso3166-countrycodes */

void main()
{
  string s = Stdio.File("stdin")->read();
  mapping codes = ([]);
  int state;
  foreach( s / "\n" - ({""}), string line)
  {
    array fields = line / " ";
    
    if(!sizeof(fields) || !strlen(fields[0])||
       sizeof(fields - ({""})) < 4 || 
       fields[0] != upper_case(fields[0]))
      continue;
    array country = ({});
    state = 0;
    foreach(fields, string f)
    {
      if(!strlen(f)) {
	if(!state) state++;
	continue;
      }
      f = lower_case(f);
      if(!state) {
	if(f != "and")
	  f = String.capitalize(f);
	country += ({ f });
      } else {
	if(country[0][-1] == ',')
	  country = country[1..] + ({ country[0][0..strlen(country[0])-2] });
	//	werror("%s == %s\n", f, country*" ");
	codes[f] = country * " ";
	break;
      }
    }
  }
  werror("%O\n", codes);
}
