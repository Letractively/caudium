#!/usr/bin/env pike

/* dumphl.pike - Program to simply dump the headlines from supported sites to
 * stdout. Mainly a debug program but can perhaps be useful for some.
 * 
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */


import ".";

void printme(object me)
{
  array testit;

  testit = (array)me;
  write((string)me);
//  write(sprintf("me : %O\n",mkmapping(indices(testit),values(testit))));
  foreach(testit, mapping hl)
  {
   /*
    if (hl->title)
      write(sprintf("Title : %s\n",hl->title||"None"));
    else if (hl->module)
      write(sprintf("Module: %s\n",hl->module||"None"));
    write(sprintf("URL   : %s\n",hl->url||""));
    if (!(hl->module))
      if (hl->date)
        write(sprintf("Date  : %s\n",hl->date||""));
      else if (hl->time)
        write(sprintf("Date  : %s\n",hl->time||""));
	*/
    //foreach(hl, mixed what)
     write(sprintf("new1: %O\n", (indices(hl))[1]));
     write(sprintf("new : %O\n",mkmapping(indices(hl),values(hl))));
  }
  exit(0);
}


int main(int argc, array (string) argv)
{
  add_constant("log_event", lambda(mixed ... args) { } );
  add_constant("hversion", "1.0");
  add_constant("trim", Headlines.Tools()->trim);

  mapping list = mkmapping(Array.map(indices(Headlines.Sites), lower_case),
			   indices(Headlines.Sites));
  if(argc != 2 || !list[ lower_case(argv[1]) ]) {
    werror("Syntax: %s <site>\n"
	   "    Dump the headlines for the selected site to stdout.\n"
	   "    Available sites are: \n"
	   "        %s\n\n", argv[0],
	   replace(sprintf("%-=60s",
			   String.implode_nicely(sort(values(list)))),
		   "\n", "\n        "));
    exit(1);
  }

  object me = Headlines.Sites[ list[ lower_case(argv[1]) ] ]();
   
  //write(sprintf("me : %O\n",mkmapping(indices(me),values(me))));
  me->refetch(printme);
  return -1;
}
	   


