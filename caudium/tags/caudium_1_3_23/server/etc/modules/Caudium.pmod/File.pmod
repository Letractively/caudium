/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2003 The Caudium Group
 * Copyright © 1994-2001 Roxen Internet Software
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
 */
/*
 * $Id$
 */

//! Used for files functions and utilities

//! 
constant cvs_version = "$Id$";

#include <stat.h>


//!  Return a textual description of the file mode.
//! @param m
//!  The file mode to decode.
//! @returns
//!  The mode described as a string.
//!  Example result: File, &lt;tt&gt;rwxr-xr--&lt;tt&gt;
//! @fixme
//!  This should be done in C. RIS-Code.
string decode_mode(int m)
{
  string s;
  s="";
  
  if (S_ISLNK(m))
    s += "Symbolic link";
  else if(S_ISREG(m))
    s += "File";
  else if(S_ISDIR(m))
    s += "Dir";
  else if(S_ISSOCK(m))
    s += "Socket";
  else if(S_ISCHR(m))
    s += "Special";
  else if(S_ISBLK(m))
    s += "Device";
  else if(S_ISFIFO(m))
    s += "FIFO";
  else if((m&0xf000)==0xd000)
    s+="Door";
  else
    s+= "Unknown";
  
  s+=", ";
  
  if (S_ISREG(m) || S_ISDIR(m)) {
    s+="<tt>";
    if (m&S_IRUSR)
      s+="r";
    else
      s+="-";
    
    if (m&S_IWUSR)
      s+="w";
    else
      s+="-";
    
    if (m&S_IXUSR)
      s+="x";
    else
      s+="-";
    
    if (m&S_IRGRP)
      s+="r";
    else
      s+="-";
    
    if (m&S_IWGRP)
      s+="w";
    else
      s+="-";
    
    if (m&S_IXGRP)
      s+="x";
    else
      s+="-";
    
    if (m&S_IROTH)
      s+="r";
    else
      s+="-";
    
    if (m&S_IWOTH)
      s+="w";
    else
      s+="-";
    
    if (m&S_IXOTH)
      s+="x";
    else
      s+="-";
    
    s+="</tt>";
  } else {
    s+="--";
  }
  return s;
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
