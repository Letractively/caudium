/*
 * Caudium - An extensible World Wide Web server
 * Copyright C 2002 The Caudium Group
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

/*
 * cram_md5.pike - a Pike implementation of the CRAM-MD5 algorithm,
 *                 as defined in RFC 2195.
 *
 * $Id$
 *
 */

string cram_md5(string secret, string challenge)
{
	if(strlen(secret) > 64)
	{
		secret = Crypto.md5()->update(secret)->digest();
	}

	string ipad = secret;

	for(int i=strlen(ipad); i<64; i++)
	{
	        ipad += "\0";
	}

	string opad = ipad;

	for(int i=0; i<64; i++)
	{
	        ipad[i] ^= 0x36;
	        opad[i] ^= 0x5c;
	}

	return Caudium.Crypto.to_hex(Crypto.md5()->update(opad)->update(Crypto.md5()->update(ipad)->update(challenge)->digest())->digest());
}

string cram_md5_resp(string secret, string challenge, string username)
{
	return MIME.encode_base64(username + " " + cram_md5(secret, challenge));
}

