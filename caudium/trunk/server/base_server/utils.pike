#!NOMODULE

// utils.pike 
// some module utils 

//  This code is (c) 1999 Martin Baehr, and can be used, modified and
//  redistributed freely under the terms of the GNU General Public License,
//  version 2.
//  This code comes on a AS-IS basis, with NO WARRANTY OF ANY KIND, either
//  implicit or explicit. Use at your own risk.
//  You can modify this code as you wish, but in this case please
//  - state that you changed the code in the modified version
//  - do not remove my name from it
//  - send me a copy of the modified version or a patch, so that
//    I can include it in the 'official' release.
//  If you find this code useful, please e-mail me. It would definitely
//  boost my ego :)
//  
//  For risks and side-effects please read the code or ask your local 
//  unix or roxen-guru.

constant cvs_version = "$Id$";

void unload_program(string p)
{
  m_delete(master()->programs,search(master()->programs,(program)p));
}

