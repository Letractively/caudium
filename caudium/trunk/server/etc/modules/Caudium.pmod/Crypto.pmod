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
 * Marek Habersack <grendel@caudium.net>.
 *
 * Portions created by the Initial Developer are Copyright (C) Marek
 * Habersack & The Caudium Group. All Rights Reserved.
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
 * Significant Contributors to this file are:
 *
 */

//! @decl string hash_sha(string|array(string) key, void|int hexify)
//!  Return a SHA1 hash of the passed string.
//!
//! @param key
//!  The string(s) you want to create the hash for. If it is an array of
//!  strings, then the strings will be concatenated before generating the
//!  digest.
//!
//! @param hexify
//!   If present and != 0, the returned hash will be presented in the ASCII
//!   hex mode, otherwise it will be a binary string.
//!
//! @returns
//!  The SHA1 digest string either in ASCII hex or in the binary form. An
//!  empty string will be returned if an error returns.

//! @decl string hash_md5(string|array(string) key, void|int hexify)
//!  Return an MD5 hash of the passed string.
//!
//! @param key
//!  The string you want to create the hash for. If it is an array of
//!  strings, then the strings will be concatenated before generating the
//!  digest.
//!
//! @param hexify
//!   If present and != 0, the returned hash will be presented in the ASCII
//!   hex mode, otherwise it will be a binary string.
//!
//! @returns
//!  The MD5 digest string either in ASCII hex or in the binary form. An
//!  empty string will be returned when an error occurs.

//! @decl string string_to_hex(string data)
//!  Return an ASCII hex representation of the passed string.
//!
//! @param data
//!  The string to hexify.
//!
//! @returns
//!  The ASCII hex representation of the string.

#if constant(Mhash.hash_md5)
string md5_hash_type = "Mhash";

string hash_md5(string|array(string) key, void|int hexify)
{
  string ret = "";
  mixed  error;

  error = catch {
    if (key && arrayp(key))
      ret = Mhash.hash_md5(key * "");
    else
      ret = Mhash.hash_md5(key);
  };

  if (error)
    return "";
  
  return (hexify ? string_to_hex(ret) : ret);
}
#else
string md5_hash_type = "Pike.Crypto";

string hash_md5(string|array key, void|int hexify)
{
  string ret = "";
  mixed  error;

  error = catch {
    if (key && arrayp(key))
      ret = Crypto.md5()->update(key * "")->digest();
    else
      ret = Crypto.md5()->update(key)->digest();
  };

  if (error)
    return "";
  
  return (hexify ? string_to_hex(ret) : ret);
}
#endif

#if constant(Mhash.hash_sha1)
string sha1_hash_type = "Mhash";

string hash_sha(string|array key, void|int hexify)
{
  string ret = "";
  mixed  error;

  error = catch {
    if (key && arrayp(key))
      ret = Mhash.hash_sha1(key * "");
    else
      ret = Mhash.hash_sha1(key);
  };

  if (error)
    return "";
  
  return (hexify ? string_to_hex(ret) : ret);
}
#else
string sha1_hash_type = "Pike.Crypto";

string hash_sha(string|array key, void|int hexify)
{
  string ret = "";
  mixed  error;

  error = catch {
    if (key && arrayp(key))
      ret = Crypto.sha()->update(key * "")->digest();
    else
      ret = Crypto.sha()->update(key)->digest();
  };

  if (error)
    return "";
  
  return (hexify ? string_to_hex(ret) : ret);
}
#endif

#if constant(Mhash.to_hex)
string string_to_hex(string data)
{
  return Mhash.to_hex(data);
}
#else
string string_to_hex(string data)
{
  return Crypto.string_to_hex(data);
}
#endif
