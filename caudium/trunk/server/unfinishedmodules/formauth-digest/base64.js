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
 * base64.js - a JavaScript implementation of the base64 algorithm,
 *             (mostly) as defined in RFC 2045.
 *
 * This is a direct JavaScript reimplementation of the original C code
 * as found in the Exim mail transport agent, by Philip Hazel.
 *
 * $Id$
 *
 */


function encode_base64( what )
{
	var base64_encodetable = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	var result = "";
	var len = what.length;
	var x;
	var y;
	var ptr = 0;

	while( len-- > 0 )
	{
		x = what.charCodeAt( ptr++ );
		result += base64_encodetable.charAt( ( x >> 2 ) & 63 );

		if( len-- <= 0 )
		{
			result += base64_encodetable.charAt( ( x << 4 ) & 63 );
			result += "==";
			break;
		}

		y = what.charCodeAt( ptr++ );
		result += base64_encodetable.charAt( ( ( x << 4 ) | ( ( y >> 4 ) & 15 ) ) & 63 );

		if ( len-- <= 0 )
		{
			result += base64_encodetable.charAt( ( y << 2 ) & 63 );
			result += "=";
			break;
		}

		x = what.charCodeAt( ptr++ );
		result += base64_encodetable.charAt( ( ( y << 2 ) | ( ( x >> 6 ) & 3 ) ) & 63 );
		result += base64_encodetable.charAt( x & 63 );

	}

	return result;
}

function decode_base64( what )
{
	var base64_decodetable = new Array (
		255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,		/*   0 -  15 */
		255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,		/*  16 -  31 */
		255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  62, 255, 255, 255,  63,		/*  32 -  47 */
		 52,  53,  54,  55,  56,  57,  58,  59,  60,  61, 255, 255, 255, 255, 255, 255,		/*  48 -  63 */
		255,   0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,		/*  64 -  79 */
		 15,  16,  17,  18,  19,  20,  21,  22,  23,  24,  25, 255, 255, 255, 255, 255,		/*  80 -  95 */
		255,  26,  27,  28,  29,  30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,		/*  96 - 111 */
		 41,  42,  43,  44,  45,  46,  47,  48,  49,  50,  51, 255, 255, 255, 255, 255		/* 112 - 127 */
	);
	var result = "";
	var len = what.length;
	var x;
	var y;
	var ptr = 0;

	while( ( x = what.charCodeAt( ptr++ ) ) != NaN )
	{
		if( ( x > 127 ) || (( x = base64_decodetable[x] ) == 255) )
			return "elso";
		if( ( ( y = what.charCodeAt( ptr++ ) ) == NaN ) || (( y = base64_decodetable[y] ) == 255) )
			return "masodik";

		result += String.fromCharCode( (x << 2) | (y >> 4) );

		if( (x = what.charCodeAt( ptr++ )) == 61 )						/* "=" */
		{
			if( (what.charCodeAt( ptr++ ) != 61) || (what.charCodeAt( ptr ) != NaN) )
				return "harmadik";
		}
		else
		{
			if( ( x > 127 ) || (( x = base64_decodetable[x] ) == 255) )
				return "negyedik";
			result += String.fromCharCode( (y << 4) | (x >> 2) );
			if( (x = what.charCodeAt( ptr++ )) == 61 )					/* "=" */
			{
				if( what.charCodeAt( ptr ) == NaN )
					return "otodik";
			}
			else
			{
				if( (y > 127) || ((y = base64_decodetable[y]) == 255) )
					return "hatodik";
				result += String.fromCharCode( (x << 6) | y );
			}
		}
	}
	return result;
}






























