// test the new entity parser.

int main()
{
  object z= scope();
  string s = "entity that exists: &test.ent2; -- should be ENT2\n"
     "entity that exists: &test.blahblah; -- should be BLAHBLAH\n"
     "scope that doesn't exist: &see.wah; -- should be ampsee.wahsemi\n"
     "scope doesnt exit, but no subpart: &ent; -- should be ampentsemi\n\n"
     "scope exists, but no subpart: &blah; -- should be ampblahsemi\n\n";

string s1 = "1: &nbsp; &test; &test.test2; &nbsp;"; 
string s2 = "1: &nbsp; &nbsp; &test; &test.test2; &nbsp; 12345 &nbsp; 12345 &test; &test.test2;"; 

string s3, s4;
s3= _Caudium.parse_entities(s1, (["test": z]), 2, 4);

s4= _Caudium.parse_entities(s2, (["test": z]));

write("s3: EN: '" + strlen(s3) + "' " +  s3);

write("\n\n");
write("s4: LEN: '" + strlen(s4) + "' " +  s4);

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
