// test the new entity parser.

int main()
{
  object z= scope();
  string s = "entity that exists: &test.ent2; -- should be ENT2\n"
     "entity that exists: &test.blahblah; -- should be BLAHBLAH\n"
     "scope that doesn't exist: &see.wah; -- should be ampsee.wahsemi\n"
     "scope doesnt exit, but no subpart: &ent; -- should be ampentsemi\n\n"
     "scope exists, but no subpart: &blah; -- should be ampblahsemi\n\n";
 
 string snavbar = "\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<td class=\"loopprev\">\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<href action=\"gopage\" countpageloop=\"&navbar_loop_previous.number;\"><img src=\"/mail_camastemplates/Caudium%20WWW/images/page.gif\" alt=\"&navbar_loop_previous.number;\" border=\"0\"><br>&navbar_loop_previous.number;</href>\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

string s1 = "1: &nbsp; &test; &test.test2; &nbsp;"; 
string s2 = "1: &nbsp; &nbsp; &test; &test.test2; &nbsp; 12345 &nbsp; 12345 &test; &test.test2;"; 

string s3, s4, s5;
s3= _Caudium.parse_entities(s1, (["test": z]), 2);

s4= _Caudium.parse_entities(s2, (["test": z]));

mapping v = ([ 
  "number": "27"
]);
write("%s", _Caudium.parse_entities(snavbar, ([ "navbar_loop_previous": EmitScope(v) ])));

write("s3: EN: '" + strlen(s3) + "' " +  s3);

write("\n\n");
write("s4: LEN: '" + strlen(s4) + "' " +  s4);

write("\n\n");
write("s5: " + s5);

write("s6: " + _Caudium.parse_entities(Stdio.File("/dev/zero", "r")->read(147470), ([ "navbar_loop_previous": EmitScope(v) ])));
  return 0;
}

class scope
{

  string z="blah";

  string get(string val, mixed a)
  {
    write("val=%O,a=%O\n", val,a);
    if(val=="test2") 
      return upper_case(val);
    else
      return 0;
  }
}

class EmitScope(mapping v) {
  string name = "emit";
  
  string get(string entity) {
    return v[entity];
  }
}
