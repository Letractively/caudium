// test the new entity parser.

int main()
{
  object z= scope();
  string s = "entity that exists: &test.ent2; -- should be ENT2\n"
     "entity that exists: &test.blahblah; -- should be BLAHBLAH\n"
     "scope that doesn't exist: &see.wah; -- should be ampsee.wahsemi\n"
     "scope exists, but no subpart: &ent; -- should be ampsentsemi\n\n";

write(  _Caudium.parse_entities(s, 
(["test": z])));

  return 0;
}

class scope
{

  string z="blah";

  string get(string val)
  {
    werror("%O\n", val);
    if(val!="") 
      return upper_case(val);
    else
      return 0;
  }


}
