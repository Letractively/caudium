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
 * cram_md5.js - a JavaScript implementation of the CRAM-MD5 algorithm,
 *               as defined in RFC 2195.
 *
 * $Id$
 *
 */

function cram_md5(secret, challenge)
{
	var my_secret = secret;
	var len = my_secret.length;
	var ipad = opad = "";
	var ipad_x = opad_x = "";
	var i;

	if( len > 64 )
	{
		my_secret = md5( my_secret );
		len = 16;
	}

	ipad = my_secret;
	opad = my_secret;

	for(i=len; i<64; i++)
	{
		ipad += String.fromCharCode(0);
		opad += String.fromCharCode(0);
	}

	for(i=0; i<64; i++)
	{
		ipad_x += String.fromCharCode( ipad.charCodeAt(i) ^ 0x36);
		opad_x += String.fromCharCode( opad.charCodeAt(i) ^ 0x5c);
	}

	return md5_hex( opad_x + md5( ipad_x + challenge ) );

}


function cram_md5_resp(secret, challenge, username)
{
	return encode_base64( username + " " + cram_md5(secret, challenge) );
}

