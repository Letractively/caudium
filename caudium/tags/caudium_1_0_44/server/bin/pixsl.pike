#!/usr/bin/env pike

int main(int argc, array argv) {
#if constant(PiXSL.Parser)
  string xsl, xml, ofile;
  object parser;
  mapping|string res;
  if(sizeof(argv) > 2) {
    if(argv[1] == "--pwd") {
      cd(argv[2]);
      argv = argv[2..];
      argc -= 2;
    }
  }
  switch(argc) {    
   case 4:
    ofile = argv[3];
   case 3:
    xml = argv[2];
   case 2:
    xsl = argv[1];
    break;    
   case 1:
   default:
    werror("Syntax: pixsl <stylesheet> [<input1>  [<output>]]\n"
	   "\tApply <stylesheet> to <input>, which defaults to stdin,\n"
	   "\tand write the output to which defaults to stdout.\n\n");
    exit(1);
  }
  if(!xml) xml = "file://stdin";
  parser = PiXSL.Parser();
  parser->set_xml_file(xml);
  parser->set_xsl_file(xsl);
  if(catch(res = parser->run())) {
    res = parser->error();
    if(mappingp(res)) {
      werror("%s: XSLT Parsing failed with %serror code %s on\n"
	     "line %s in %s:\n%s\n",
	     res->level||upper_case(res->msgtype||"ERROR"), 
	     res->module ? res->module + " " : "",
	     res->code || "???",
	     res->line || "???",
	     res->URI || "unknown file",
	     res->msg || "Unknown error");
      exit(1);
    } else if(!res) {
      werror("Unknown error occured.\n");
      exit(1);
    }
  }
  if(ofile) {
    rm(ofile);
    Stdio.write_file(ofile, res);
  } else {
    write(res);
  }
#else
  werror("ERROR: PiXSL.so Pike module not available!\n");
  exit(2);
#endif
}
