// Log Profile Handling.
// $Id$

import ".";

class File {
  int restore, ispipe, reload;
  int size = 0x7fffffff;
  object fd;
  string fname, filter;
  string format = "%H %R %U [%D/%M/%Y:%h:%m:%s %j] \"%j %f %j\" %c %b";
  //  string format = "%H %R %j [%D/%M/%Y:%h:%m:%s %z] \"%j %f %j\" %c %b";
  void create(string f, int _restore, int|void _reload,
	      string|void _format, string|void _filter)
  {
    restore = _restore;
    reload = _reload;
    fname = f;
    if(_format) format = _format;
    if(_filter) filter = _filter;
  }
  object get_fd()
  {
    array arg;
    if(fd) return fd;
    fd = Stdio.File();  
    werror("get_fd(%s)\n", fname);

    if(filter)
    {
      arg =  Process.split_quoted_string(replace(filter, "$f", fname));
      size = Stdio.file_size(fname);
    } else {
      array parts = fname / ".";
      string sizeinfo;
      switch(parts[-1])
      {
       case "gz":
       case "z":
	catch { sizeinfo = Process.popen("gzip -l "+fname); };
	sscanf(sizeinfo || "", "%*s\n%*d %d ", size);
       case "Z":
	arg = ({ "gunzip", "-c", fname });
	ispipe = 1;
	break;
       case "bz2":
	arg = ({ "bunzip2", "-c", fname });
	ispipe = 1;
	break;
      }
    }
    if(arg)
      Process.create_process(arg, ([ "stdout": fd->pipe() ]));
    else {
      if(!fd->open(fname, "r")) 
	fd = 0;
      size = Stdio.file_size(fname);
    }

    //    size /= 1024.0*1024.0;
    return fd;
  }

  // "seek()" on pipes.
  int seek(int to)
  {
    int rd, orig = to;
    while(to > 65535) {
      rd = strlen(fd->read(65535));
      to -= rd;
      if(rd < 65535) break;
    }
    to -= strlen(fd->read(to));
    if(to) {
       /* read less than required meaning the file is smaller than the previous
	* end location. We reopen the file and parse it from the beginning.
	*/
      fd->close();
      fd = 0;
      get_fd();
      return 1;
    }
  }
}

class profile {
  // Individual profile
  import ".";
  array files;
  multiset extensions;
  string noref;
  string savedir;
  object method;
  string name;
  mapping pos;
  
  void create(string _savedir, string _name, mapping data, string _method)
  {
    name = _name;
    files = ({});
    foreach(sort(indices(data->files||([]))), string f) {
      array globbed = Util.glob_expand(f);
      foreach(globbed, string nf)
	files += ({ File(nf, data->files[f], data->reload[f],
			 data->format[f],
			 data->filter[f]) });
    }    
    extensions = data->extensions;
    noref = data->noref;
    savedir = _savedir;
    method = Storage[_method](savedir);
    catch { pos = decode_value(Stdio.read_file(savedir +"saved_pos")); };
    if(!pos) pos = ([]);
    
  }
  void save() {
    Util.mkdirhier(savedir);
    mv(savedir +"saved_pos", savedir +"saved_pos.old");
    Stdio.write_file(savedir +"saved_pos", encode_value(pos));
    method->sync();
  }
}

class Master {
  import spider;
  // Master Profile
  array profiles = ({});
  string savedir, method;
  int maxsize;
  void create(string|void file)
  {
    if(file)
      catch(load_profile(file));
  }

  string parse_profile(string tag, mapping m, mapping tmp) {
    switch(tag) {
     case "file":
      if(!tmp->files)	tmp->files = ([]);
      if(!tmp->format)	tmp->format = ([]);
      if(!tmp->filter)	tmp->filter = ([]);
      if(!tmp->reload)	tmp->reload = ([]);
      tmp->files[m->path] = m->restore ? 1 : -1;
      tmp->reload[m->path] = m->reload ? 1 : 0;
      tmp->format[m->path] = m->format;
      tmp->filter[m->path] = m->filter;
      break;
     case "noref":
      tmp->noref = m["for"] || m->host || m->path;
      break;
     case "extensions":
      tmp->extensions = mkmultiset(replace(m->list||m->exts||"",
					   ({ ",", "\r", "\t", "\n" }),
					   ({ " ", " ", " ", " "})) / " " -
				   ({""}));
      break;
    }
  }

  string parse_profdata(string tag, mapping m, string|void contents)
  {
    mapping tmp;
    array users, include, exclude, inds;
    string parsed ="";
    switch(tag)
    {
     case "savedir":
      savedir = m->path || "";
      method  = String.capitalize(lower_case(m->method||"Filetree"));
      if(!strlen(savedir) || savedir[-1] != '/')
	savedir += '/';
      
      master()->set_inhibit_compile_errors("");
      if(!strlen(method) ||
	 search(indices(Storage),method) == -1 ||
	 catch(Storage[method])) {
	werror("'%s' is not a valid method!\n", method);
	exit(1);
      }
      master()->set_inhibit_compile_errors(0);
      break;

     case "table":
      maxsize = (int)m->maxsize;
      break;

     case "ispprofile":
      /* Return a <profile> for each of the acceptable users */
      users = get_all_users();
      inds = Array.map(users, lambda(array u) { return u[0]; });
      tmp = mkmapping(inds, users);
      if(!m->name) m->name = "#user#";
      if(m->include) 
	include = replace(m->include, ({",", "\t", "\n"}),
			  ({" ", " ", " "})) / " " - ({""});
      if(m->exclude) 
	exclude = replace(m->exclude, ({",", "\t", "\n"}),
			  ({" ", " ", " "}))/" "- ({""});
      if(include && sizeof(include))
	inds = include;
      if(exclude) inds -= exclude;
      string mm = "";
      if(m->method) 
	mm = " method='"+mm+"' ";
      foreach(inds, string u)
      {
	if(tmp[u])
	  parsed += replace("<profile "+mm+"name='"+m->name+"'>"+contents
			    +"</profile>\n",
			    ({ "#user#", "#homedir#" }),
			    ({ tmp[u][0], tmp[u][5] }));
      }
      return parsed;
      
      
     case "profile":
      tmp = ([]);
      if(!m->name)
      {
	werror("Profile is missing a name.\n");
	break;
      }
      contents = parse_html(contents||"", 
		 ([ "file": parse_profile, 
		    "noref": parse_profile, 
		    "extensions": parse_profile,
		 ]), ([]), tmp);
      if(!m->method) m->method = method;
      else {
	master()->set_inhibit_compile_errors("");
	if(!strlen(m->method = String.capitalize(lower_case(m->method))) ||
	   search(indices(Storage),m->method) == -1 ||
	   catch(Storage[m->method])) {
	  werror("Profile %s: '%s' is not a valid method!\n", m->name,
		 m->method);
	  master()->set_inhibit_compile_errors(0);
	  break;
	} else {
	  master()->set_inhibit_compile_errors(0);
	}
      }
      profiles += ({  ({ m->name +"/", m->name, tmp, m->method||method }) });
    }
    return "";
  }
  
  void load_profile(string file)
  {
    string profdata = Stdio.read_file(file);
    if(!profdata) return;
   
    profdata = parse_html(profdata, ([ "savedir": parse_profdata,
				       "table": parse_profdata ]),
			  (["profile": parse_profdata,
			    "ispprofile": parse_profdata]));
    if(!savedir) {
      werror("*** ERROR: No save directory specified => no valid profiles!\n");
      profiles = ({});
    } else {
      profiles = Array.map(profiles,
			   lambda(array arr) {
			     return profile(savedir + arr[0], @arr[1..]);
			   });
    }
    
    if(!maxsize) maxsize = 10000; /* nice and fast with only 10k */
  }
}



