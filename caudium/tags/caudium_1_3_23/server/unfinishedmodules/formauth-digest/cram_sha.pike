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
 * cram_sha.pike - a Pike implementation of the CRAM-SHA1 algorithm,
 *                 as defined in RFC 2195.
 *
 * $Id$
 *
 */

string cram_sha(string secret, string challenge)
{
	if(strlen(secret) > 64)
	{
		secret = Caudium.Crypto.hash_sha(secret);
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

	return Caudium.Crypto.string_to_hex(Crypto.sha()->update(opad)->update(Crypto.sha()->update(ipad)->update(challenge)->digest())->digest());
}

string cram_sha_resp(string secret, string challenge, string username)
{
	return MIME.encode_base64(username + " " + cram_sha(secret, challenge));
}

