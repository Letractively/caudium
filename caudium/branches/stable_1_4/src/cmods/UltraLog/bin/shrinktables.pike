#!/usr/bin/env pike
import spider;
import UltraLog;
import "../pmod/";
constant cvs_version = "$Id$";
void recurse_repack(string dir)
{
  array files = get_dir(dir);
  write("%s\n", dir);
  foreach(sort(files||({})), string f) {
    string file = combine_path(dir, f);
    array st = file_stat(file);
    if(!st) continue;
    if(st[1]  == -2) {
      recurse_repack(file);
    } else if(st[1] > 0 && Util.compmaps[f]) {
      write("%s-", file);
      string data = Stdio.read_file(file);
      mapping foo;
      catch {
	write("l-");
	data = Gz.inflate()->inflate(data);
	write("uc-");
	foo = decode_value(data);
	data = "";
	if(sizeof(foo) <= 50002)
	{
	  write("sml(%d)-", sizeof(foo));
	  continue;
	}
	write("dec(%d)-", sizeof(foo));
	foo = compress_mapping(foo);
	write("cmpr-", sizeof(foo));
	mv(file, file+"~");
	Stdio.write_file(file, Gz.deflate()->deflate(encode_value(foo)));
      };
      write("ok.\n");
    }
  }
}

int main(int argc, array argv)
{
  foreach(argv[1..], string s)
  {
    recurse_repack(s);
  }
}
