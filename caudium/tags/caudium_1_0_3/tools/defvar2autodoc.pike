#!/usr/bin/env pike
// Generate inline auto-doc from the defvar statements in Caudium modules.
#define THIS split[i][e+1]

int get_next_string(array arr, int pos, mapping res) {
  string s = "";
  int i;
  for(i = pos; i < sizeof(arr); i++) {
    if(arrayp(arr[i])) {
      res->res = "";
      return i+1;
    }
    if(((string)arr[i])[0..0] == "\"") {
      s += arr[i];
      break;
    }
  }
  for(i = i+1; i < sizeof(arr); i++) {
    if(arrayp(arr[i])) {
      break;      
    }
    if(((string)arr[i])[0..0] != "\"") {
      break;
    } else
      s += arr[i];
  }
  if(strlen(s)) {
    s = "string res = "+ s + ";";
    res->res = compile_string(s)()->res;
  } else
    res->res = 0;
  return i+1;
}

int get_token(array arr, int pos, mapping res) {
  string s = "";
  int i;
  for(i = pos; i < sizeof(arr); i++) {
    if(((string)arr[i])[0..0] == "," ||
       ((string)arr[i])[0..0] == ")")
      break;
    s += arr[i];
  }
  res->token = s;
  return i+1;
}
#define SEP "\n/* START AUTOGENERATED DEFVAR DOCS */\n\n"

int main(int argc, array(string) argv)
{
  
  foreach(argv[1..], string file) {
    string doc = SEP;
    string origdata;
    if((file / ".")[-1] != "pike")
      continue;
    string data = Stdio.read_file(file);
    origdata = data;
    if(!data) continue;
    array split;
    sscanf(data, "%s\n/* START AUTOGENERATED DEFVAR", data);
      
    array err = catch { 
      split = Parser.Pike->group(Parser.Pike->hide_whitespaces(Parser.Pike->tokenize(Parser.Pike->split(data))));
      if(!arrayp(split))
	continue;
      for(int i = 0; i < sizeof(split); i++) {
	if(arrayp(split[i]))
	  for(int e = 0; e < sizeof(split[i]) - 1; e++) {
	    int pos;
	    mapping res = ([]);
	    if(split[i][e] == "defvar" ||
	       split[i][e] == "globvar") {
	      pos = get_next_string(THIS, 0, res);
	      res->name = res->res;
	      while(!arrayp(THIS[pos]) && ((string)(THIS[pos])) != ",")
		pos++;
	      pos = get_next_string(THIS, pos+1, res);
	      if(res->name && strlen(res->name) &&
		 res->res && strlen(res->res)) {
		res->longname = res->res;
		doc += ("//! defvar: "+res->name +"\n");
		pos = get_token(THIS, pos, res);
		pos = get_next_string(THIS, pos, res);
		if(res->res) {
		  res->res =
		    replace(res->res, ({ "<br>",  "&nbsp;", "\n" }),
			    ({ "<br />", "&#xa0;", "\n//!"}));
		  if(strlen(res->res - " "))
		    doc += ("//! "+ res->res +"\n");
		}
		doc += ("//!  type: "+res->token +"\n");
		doc += ("//!  name: "+res->longname+"\n//\n");
	      }
	    }
	  }
      }
      if(doc != SEP) {
	data += doc;
	if(data != origdata) {
	  if(!mv(file, file+"~")) {
	    werror("Failed to write backup-file "+file+"~ - aborting.\n");
	    exit(1);
	  }
	  Stdio.write_file(file, data);
	  write("+++ "+ file+" updated\n");
	} else
	  write("    "+file+" unmodified\n");
      } else {
	write("    "+file+": no defvars\n");
      }
    };
    if(err) {
      werror("*** "+file+" failed.\n");
      werror(describe_backtrace(err));
    }
  }
}

