#!/usr/local/bin/pike

/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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
 *
 */

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

string cvs_version = "$Id$";

//
// usage: searcher.pike --profile=/path/to/profile "search query"
//

#if constant(Java)

static constant jvm = Java.machine;

string profile_path;
int verbose;
object index;
mapping profile=([]);

void display_help()
{
   werror("usage: searcher.pike [-v] --profile=/path/to/profile \"search query\"\n");
   exit(0);
}

void read_profile(string filename)
{
  if(!file_stat(filename))
  {
    werror("profile " + filename + " does not exist.\n");
    exit(1);
  }

  string f=Stdio.read_file(filename);
  if(!f) 
  {
    werror("profile " + filename + " is empty.\n");
    exit(1);
  }

  array lines=f/"\n";

  profile->dbdir=lines[0];

  return;
}

int main(int argc, array argv)
{
  array options=({ ({"profile", Getopt.HAS_ARG, ({"--profile"}) }),
	({"verbose", Getopt.NO_ARG, ({"-v", "--verbose"}) }),
	({"help", Getopt.NO_ARG, ({"-h", "--help"}) }) });
  array args=Getopt.find_all_options(argv, options);

  foreach(args, array a)
  {
    if(a[0]=="profile")
      profile_path=a[1];
    if(a[0]=="verbose")
      verbose=1;
    if(a[0]=="help")
      display_help();
  }

  if(!profile_path)
  {
    werror("no profile specified.\n");
    exit(1);
  }



  read_profile(profile_path);
  index=Lucene.Index(profile->dbdir);
  index->search(argv[-1]);
}

#endif
