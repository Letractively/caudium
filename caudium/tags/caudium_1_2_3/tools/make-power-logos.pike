#!/usr/bin/env pike

#pike 7.2

mapping sizes = ([
  "large": ({ 264, 93 }), 
  "medium": ({ 176, 62 }), 
  "small": ({ 99, 35 }), 
]);


mapping colors = ([
  "antiquewhite": (["c-antiquewhite": 1, "white-filter":0 ]),
  "blue": ([ "c-blue": 1, "white-filter": 1 ]),
  "darkblue": ([ "c-blue": 1, "white-filter": 0 ]),
  "darkgreen": (["c-green":1, "white-filter":0 ]),
  "darkpurple": ([ "c-purple": 1, "white-filter": 0 ]),
  "gold": (["c-red":1, "c-yellow":1, "white-filter":0 ]),
  "lightgold": (["c-red":1, "c-yellow":1, "white-filter":1 ]),
  "lightgray": ([ "white-filter":1 ]),
  "gray": ([ "white-filter":0 ]),
  "green": (["c-green":1, "white-filter":1 ]),
  "greenblue": ([ "c-greenblue": 1, "white-filter": 0]),
  "lightblue": ([ "c-blue": 1, "c-white": 1, "white-filter": 0 ]),
  "lightgreen": (["c-green":1, "white-filter":1 ]),
  "orange": ([ "c-orange": 1, "white-filter":0]),
  "purple": ([ "c-purple": 1, "white-filter": 1 ]),
  "red": ([ "c-red": 1, "white-filter":0]),
  "white": ([ "c-white":1 ]),
  "yellow": ([ "c-yellow":1, "white-filter":0]),
]);

void main(int argc, array argv) {
  Image.XCF.GimpImage xcf;
  string version = "1.1";
  array files = ({});
  if(argc != 2) {
    werror("Syntax: %s <power.xcf>\n", argv[0]);
    exit(1);
  }
  mkdir("out"); cd("out"); map(get_dir("."), rm); cd("../");
  string sourcedata;
  if(search(argv[1], ".bz2") != -1) {
#if constant(bzip2.inflate)
    sourcedata = bzip2.inflate()->inflate(Stdio.read_file(argv[1]));
#else
    sourcedata = Process.popen("bzip2 -d -c "+argv[1]);
#endif
  }
  xcf =  Image.XCF.__decode(sourcedata);
  string name = "out/power-%s-%s.gif";
  foreach(sort(indices(colors)), string col) {
    if(sizeof(colors[col])) {
      write(col+": ");
      foreach(xcf->layers, object layer) {
	if(!zero_type(colors[col][layer->name])) {
	  layer->flags->visible = colors[col][layer->name];
	} else if(layer->name[..1] == "c-") {
	  layer->flags->visible = 0;
	} else if(layer->name[..1] == "v-") {
	  if(layer->name[2..] == version) {
	    layer->flags->visible = 1;
	  } else {
	    layer->flags->visible = 0;
	  }
	}
      }
      Image.Image source = Image.XCF._decode(xcf)->image;
      foreach(sort(indices(sizes)), string size) {
	write(size +"...");
	Image.Image out = source->scale(@sizes[size]);
	string fn = sprintf(name, size, col);
	files += ({ fn });
	Stdio.write_file(fn, Image.GIF.encode(out));
      }
      write("done.\n");
    }
  }
  write("Running gifsicle...\n");
  object gifs = Process.create_process( ({ "gifsicle", "-O4", "-b", "-k64",
					   "-f" }) + files);
  gifs->wait();
}
  
