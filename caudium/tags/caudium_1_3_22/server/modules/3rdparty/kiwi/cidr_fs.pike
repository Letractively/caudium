/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
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
 * $Id$
 */

/*
 * File licensing and authorship information block.
 *
 * Version: MPL 1.1/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 *
 * Xavier Beaudouin <kiwi AT caudium DOT net>
 *
 * Portions created by the Initial Developer are Copyright (C) 
 * Xavier Beaudouin & The Caudium Group. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the LGPL, and not to allow others to use your version
 * of this file under the terms of the MPL, indicate your decision by
 * deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL or the LGPL.
 *
 */
#include <module.h>

inherit "modules/filesystems/filesystem.pike" : filesystem;

#define CIDR_DEBUG

#ifdef CIDR_DEBUG
# define WERR(X) if(QUERY(debug)) write("CIDR-FS: "+X+"\n")
#else
# define WERR(X)
#endif

constant module_type    = MODULE_FIRST|MODULE_LOCATION;
constant module_name    = "CIDR Filesystem and redirector";
constant module_doc     = "CIDR Filesystem and redirector. Does redirecting "
                          "or access to local FS as a virtual hosting system."; 
constant module_version = "$Id$";
constant module_unique  = 1;
constant thread_safe    = 0;

// Global variables for autoloading file.
object  filewatch;    // Filewatcher object
mapping cidrlist;     // CIDR list with actions in an array    

//! method: void start()
//!  When the module is started, start filesystem
void start(int count, object conf)
{
  filesystem::start();
  WERR(" CIDR File is " + QUERY(cidrf));
  catch {
  load_cidrfile(QUERY(cidrf));
  filewatch = FileWatch.Callout(QUERY(cidrf), 5, load_cidrfile);
  };
}

//! method: void create()
//!  At the creation, call filesystem module constructor and add virtual
//!  hosting specific variables
void create()
{
  filesystem::create();

#ifdef CIDR_DEBUG
  defvar("debug", 0, "Debug", TYPE_FLAG,
         "If set to yes, some debug information will be put in the debug logs.");
#endif

  defvar("cidrf", "NONE", "CIDR Definition file", TYPE_FILE,
         "The file that contains definition of CIDR and Actions to be done.");

}

//! Check for a IP in a subnet
class IP_check {
  private string  _mask,
                  _ip;
  private int   _badmask = 0;

  //! Create the class. The string ipstr is the subnet given in CIDR type
  void create(string ipstr) {
    int a1, a2, a3, a4, mlen;

    if (sscanf(ipstr, "%d.%d.%d.%d/%d", a1, a2, a3, a4, mlen) == 5) { 
      _mask = sprintf("%4c", (0xFFFFFFFF >> mlen) ^ 0xFFFFFFFF);
      _ip = sprintf("%1c%1c%1c%1c", a1, a2, a3, a4) & _mask;
      _badmask = 0;
    }
    else _badmask = 1;
    if ((mlen >34) || (mlen <0)) 
      _badmask = 1;
  }
                
  //! Check if the given ip is inside the CIDR given in the create()
  //! routine.
  //! @returns
  //!   1, if it is inside, 0 if it is outside, 255 if the IP is 
  //!   not a IPv4 IP, 254 if the CIDR is not a CIDR.
  int check(string ipstr) {
    int   a1, a2, a3, a4, mlen;
                                
    if (_badmask == 1)
      return 254;
                                    
    if (sscanf(ipstr, "%d.%d.%d.%d", a1, a2, a3, a4) == 4 )
      return (sprintf("%1c%1c%1c%1c", a1, a2, a3, a4) & _mask) == _ip;

    return 255;
  }
}

// Create the mapping of CIDR things
class CIDRFile {
  
 private string datafile;    // file to be used

#define LINE_COMMENT  0x00
#define LINE_DIRECTIVE 0x01

 private int qualify_line(string line)
 {
   if (!line || line == "")
     return LINE_COMMENT;
   if (sizeof(line) >=1 && line [0..0] == "#")
     return LINE_COMMENT;
   if (sizeof(line) >=1 && line [0..0] == " ")
     return LINE_COMMENT;
   if (sizeof(line/"\t") == 3)
     return LINE_DIRECTIVE;
   return -1;
  }

  void create(string path)
  {
    datafile = Stdio.read_bytes(path);
    if (datafile == 0) throw("Unable to read "+path+"file !");
  }

  mapping doindex()
  {
    mapping out = ([ ]);
    foreach((datafile-"\r")/"\n",string foo)
      if(qualify_line(foo) == LINE_DIRECTIVE)
      {
         array l= foo / "\t";
         out += ([ l[0] : ({ l[1], l[2] }) ]);
      }
    return out;
  }
}

//! method: int load_cidrfile (string file)
//!  Load the cidr file, parse it and update the cidrlist mapping
int load_cidrfile(string file)
{
  WERR("(re)loading the CIDR action file");
  if(file == "NONE")
  {
    WERR("File is not set, we don't reload anything");
    return 0;
  }
  cidrlist = CIDRFile(file)->doindex();
  WERR("File loaded, with "+(string)sizeof(cidrlist)+" CIDR definitions in it");
  return 0;
}

//! mapping first_try(object id)
//!  At first try, modify path to the data in the filesystem given the settings
//!  in the CIF and id->request_headers->host (kind of root pivot)
//!  Return 0, then let the filesystem module do its job.
mapping first_try(object id)
{
  // path is a filesystem global variable which contain the path to data
  path = QUERY(searchpath);

  // Get the remote ip address from id object
  WERR("Ip source address : "+id->remoteaddr);
  string source = id->remoteaddr;

  foreach(indices(cidrlist), string subnet) 
  {
    int isinlist = IP_check(subnet)->check(source);

    if (isinlist) {
      WERR(source + " is in the list ... Checking actions ...");
      WERR(source + " Action is : "+cidrlist[subnet][0]);
      WERR(source + " Args is : "+cidrlist[subnet][1]);
      switch(upper_case(cidrlist[subnet][0])) {
        case "REDIRECT":  return Caudium.HTTP.redirect(cidrlist[subnet][1],id);
                          break;
        case "DIR"     :  path += combine_path("/./",cidrlist[subnet][1]);
                          break;
        }
      }
  }

  path = Caudium.simplify_path(path);

  return 0; 
}

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
