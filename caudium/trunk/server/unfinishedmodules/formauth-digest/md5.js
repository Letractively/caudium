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
 * md5.js - a JavaScript implementation of RSA DSI's MD5 algorithm.
 *
 * Copyright C 2001 Róbert Elek <robymus@cprogramming.hu>
 *
 * $Id$
 *
 */

/*
 * API:
 *
 * 1) you can calculate md5 hashes in one step:
 *
 *	string md5( string what ) - returns the md5 hash of "what"
 *		(16 bytes, binary)
 *
 *	string md5_hex( string what ) - returns the hash of "what"
 *		(32 bytes, hexadecimal representation)
 *
 * 2) if you don't have all the data at hand:
 *
 *	1.  md5_ctx md5init( void ) - initializiation of the context object
 *	2.  void md5add( md5_ctx, what ) - push "what" into the context
 *	3.  <repeat step 2 as neccessary>
 *	4.  md5_ctx md5final( md5_ctx ) - calculate the hash, inplace (-ish)
 *	5a.
 *	5b. - these two would be to return the binary and the hex32 hash,
 *		and are yet unwritten. it's no magic, though - see md5() and
 *		md5_hex() if you happen to need it before i do.
 *
 * TODO: write 5a and 5b; clean up the namespace
 *
 */
 
 	
function md5_ff(a, b, c, d, x, s, ac)
{
	a += ((b&c)|((~b)&d)) + x + ac;
	a &= 0xffffffff;
	return (((a<<s)|(a>>>(32-s)))+b) & 0xffffffff;
}

function md5_gg(a, b, c, d, x, s, ac)
{
	a += ((b&d)|(c&(~d))) + x + ac;
	a &= 0xffffffff;
	return (((a<<s)|(a>>>(32-s)))+b) & 0xffffffff;
}

function md5_hh(a, b, c, d, x, s, ac)
{
	a += (b^c^d) + x + ac;
	a &= 0xffffffff;
	return (((a<<s)|(a>>>(32-s)))+b) & 0xffffffff;
}

function md5_ii(a, b, c, d, x, s, ac)
{
	a += (c^(b|(~d))) + x + ac;
	a &= 0xffffffff;
	return (((a<<s)|(a>>>(32-s)))+b) & 0xffffffff;
}


function md5_transform(m)
{
	var S11= 7;	var S12=12;	var S13=17;
	var S14=22;	var S21= 5;	var S22= 9;
	var S23=14;	var S24=20;	var S31= 4;
	var S32=11;	var S33=16;	var S34=23;
	var S41= 6;	var S42=10;	var S43=15;
	var S44=21;	var a=m.a;	var b=m.b;
	var c=m.c;	var d=m.d;
	var x=new Array();

	for (i=0, j=0; j<64; i++,j+=4)
	{
		x[i] = m.buffer[j]       |
		(m.buffer[j+1]<< 8)|
		(m.buffer[j+2]<<16)|
		(m.buffer[j+3]<<24);
	}

	a = md5_ff(a, b, c, d, x[ 0], S11, 0xd76aa478);
	d = md5_ff(d, a, b, c, x[ 1], S12, 0xe8c7b756);
	c = md5_ff(c, d, a, b, x[ 2], S13, 0x242070db);
	b = md5_ff(b, c, d, a, x[ 3], S14, 0xc1bdceee);
	a = md5_ff(a, b, c, d, x[ 4], S11, 0xf57c0faf);
	d = md5_ff(d, a, b, c, x[ 5], S12, 0x4787c62a);
	c = md5_ff(c, d, a, b, x[ 6], S13, 0xa8304613);
	b = md5_ff(b, c, d, a, x[ 7], S14, 0xfd469501);
	a = md5_ff(a, b, c, d, x[ 8], S11, 0x698098d8);
	d = md5_ff(d, a, b, c, x[ 9], S12, 0x8b44f7af);
	c = md5_ff(c, d, a, b, x[10], S13, 0xffff5bb1);
	b = md5_ff(b, c, d, a, x[11], S14, 0x895cd7be);
	a = md5_ff(a, b, c, d, x[12], S11, 0x6b901122);
	d = md5_ff(d, a, b, c, x[13], S12, 0xfd987193);
	c = md5_ff(c, d, a, b, x[14], S13, 0xa679438e);
	b = md5_ff(b, c, d, a, x[15], S14, 0x49b40821);
	a = md5_gg(a, b, c, d, x[ 1], S21, 0xf61e2562);
	d = md5_gg(d, a, b, c, x[ 6], S22, 0xc040b340);
	c = md5_gg(c, d, a, b, x[11], S23, 0x265e5a51);
	b = md5_gg(b, c, d, a, x[ 0], S24, 0xe9b6c7aa);
	a = md5_gg(a, b, c, d, x[ 5], S21, 0xd62f105d);
	d = md5_gg(d, a, b, c, x[10], S22,  0x2441453);
	c = md5_gg(c, d, a, b, x[15], S23, 0xd8a1e681);
	b = md5_gg(b, c, d, a, x[ 4], S24, 0xe7d3fbc8);
	a = md5_gg(a, b, c, d, x[ 9], S21, 0x21e1cde6);
	d = md5_gg(d, a, b, c, x[14], S22, 0xc33707d6);
	c = md5_gg(c, d, a, b, x[ 3], S23, 0xf4d50d87);
	b = md5_gg(b, c, d, a, x[ 8], S24, 0x455a14ed);
	a = md5_gg(a, b, c, d, x[13], S21, 0xa9e3e905);
	d = md5_gg(d, a, b, c, x[ 2], S22, 0xfcefa3f8);
	c = md5_gg(c, d, a, b, x[ 7], S23, 0x676f02d9);
	b = md5_gg(b, c, d, a, x[12], S24, 0x8d2a4c8a);
	a = md5_hh(a, b, c, d, x[ 5], S31, 0xfffa3942);
	d = md5_hh(d, a, b, c, x[ 8], S32, 0x8771f681);
	c = md5_hh(c, d, a, b, x[11], S33, 0x6d9d6122);
	b = md5_hh(b, c, d, a, x[14], S34, 0xfde5380c);
	a = md5_hh(a, b, c, d, x[ 1], S31, 0xa4beea44);
	d = md5_hh(d, a, b, c, x[ 4], S32, 0x4bdecfa9);
	c = md5_hh(c, d, a, b, x[ 7], S33, 0xf6bb4b60);
	b = md5_hh(b, c, d, a, x[10], S34, 0xbebfbc70);
	a = md5_hh(a, b, c, d, x[13], S31, 0x289b7ec6);
	d = md5_hh(d, a, b, c, x[ 0], S32, 0xeaa127fa);
	c = md5_hh(c, d, a, b, x[ 3], S33, 0xd4ef3085);
	b = md5_hh(b, c, d, a, x[ 6], S34,  0x4881d05);
	a = md5_hh(a, b, c, d, x[ 9], S31, 0xd9d4d039);
	d = md5_hh(d, a, b, c, x[12], S32, 0xe6db99e5);
	c = md5_hh(c, d, a, b, x[15], S33, 0x1fa27cf8);
	b = md5_hh(b, c, d, a, x[ 2], S34, 0xc4ac5665);
	a = md5_ii(a, b, c, d, x[ 0], S41, 0xf4292244);
	d = md5_ii(d, a, b, c, x[ 7], S42, 0x432aff97);
	c = md5_ii(c, d, a, b, x[14], S43, 0xab9423a7);
	b = md5_ii(b, c, d, a, x[ 5], S44, 0xfc93a039);
	a = md5_ii(a, b, c, d, x[12], S41, 0x655b59c3);
	d = md5_ii(d, a, b, c, x[ 3], S42, 0x8f0ccc92);
	c = md5_ii(c, d, a, b, x[10], S43, 0xffeff47d);
	b = md5_ii(b, c, d, a, x[ 1], S44, 0x85845dd1);
	a = md5_ii(a, b, c, d, x[ 8], S41, 0x6fa87e4f);
	d = md5_ii(d, a, b, c, x[15], S42, 0xfe2ce6e0);
	c = md5_ii(c, d, a, b, x[ 6], S43, 0xa3014314);
	b = md5_ii(b, c, d, a, x[13], S44, 0x4e0811a1);
	a = md5_ii(a, b, c, d, x[ 4], S41, 0xf7537e82);
	d = md5_ii(d, a, b, c, x[11], S42, 0xbd3af235);
	c = md5_ii(c, d, a, b, x[ 2], S43, 0x2ad7d2bb);
	b = md5_ii(b, c, d, a, x[ 9], S44, 0xeb86d391);

	m.a = (m.a+a) & 0xffffffff;
	m.b = (m.b+b) & 0xffffffff;
	m.c = (m.c+c) & 0xffffffff;
	m.d = (m.d+d) & 0xffffffff;
}

function md5_hexnibble(x)
{
	switch (x&15)
	{
		case  0: return '0';
		case  1: return '1';
		case  2: return '2';
		case  3: return '3';
		case  4: return '4';
		case  5: return '5';
		case  6: return '6';
		case  7: return '7';
		case  8: return '8';
		case  9: return '9';
		case 10: return 'a';
		case 11: return 'b';
		case 12: return 'c';
		case 13: return 'd';
		case 14: return 'e';
		case 15: return 'f';
	}
}

function md5_binbyte( what )
{
	return String.fromCharCode( what & 0xff );
}

function md5_bin32( what )
{
	return (
		md5_binbyte( what       ) +
		md5_binbyte( what >>  8 ) +
		md5_binbyte( what >> 16 ) +
		md5_binbyte( what >> 24 )
	);
}

function md5_hex32(x)
{
	return (md5_hexnibble(x>> 4) + md5_hexnibble(x    )+
		md5_hexnibble(x>>12) + md5_hexnibble(x>> 8)+
		md5_hexnibble(x>>20) + md5_hexnibble(x>>16)+
		md5_hexnibble(x>>28) + md5_hexnibble(x>>24) );
}

function md5init()
{
	var md5obj = {
		a:	0x67452301,
		b:	0xefcdab89,
		c:	0x98badcfe,
		d:	0x10325476,
		len_lo:	0,
		len_hi:	0,
		bpos:	0,
		buffer:	new Array()
	};
	return md5obj;
}

function md5add(md5obj,from)
{
	var i;
	for (i = 0; i < from.length; i++)
	{
		md5obj.buffer[md5obj.bpos++] = from.charCodeAt(i);
		md5obj.len_lo+=8;
		if (md5obj.len_lo == 0) { md5obj.len_hi++; }
		if (md5obj.bpos == 64)
		{
			md5_transform(md5obj);
			md5obj.bpos = 0;
		}
	}
}

function md5final(md5obj)
{
	if (md5obj.bpos < 56)
	{
		md5obj.buffer[md5obj.bpos++] = 0x80;
		while (md5obj.bpos < 56)
		{
			md5obj.buffer[md5obj.bpos++] = 0x0;
		}
	} else {
		md5obj.buffer[md5obj.bpos++]=0x80;
		while (md5obj.bpos < 64)
		{
			md5obj.buffer[md5obj.bpos++] = 0x0;
		}
		md5_transform(md5obj);
		md5obj.bpos = 0;
		while (md5obj.bpos < 56)
		{
			md5obj.buffer[md5obj.bpos++] = 0x0;
		}
	}

	md5obj.buffer[56] = ( md5obj.len_lo      &0xff);
	md5obj.buffer[57] = ((md5obj.len_lo>>> 8)&0xff);
	md5obj.buffer[58] = ((md5obj.len_lo>>>16)&0xff);
	md5obj.buffer[59] = ((md5obj.len_lo>>>24)&0xff);
	md5obj.buffer[60] = ( md5obj.len_hi      &0xff);
	md5obj.buffer[61] = ((md5obj.len_hi>>> 8)&0xff);
	md5obj.buffer[62] = ((md5obj.len_hi>>>16)&0xff);
	md5obj.buffer[63] = ((md5obj.len_hi>>>24)&0xff);
	md5_transform(md5obj);
	return md5obj;
}

function md5( what )
{
	var md5obj = md5init();
	md5add(md5obj, what);
	md5final( md5obj );
	return (
		md5_bin32( md5obj.a ) +
		md5_bin32( md5obj.b ) +
		md5_bin32( md5obj.c ) +
		md5_bin32( md5obj.d )
	);
}

function md5_hex( what )
{
	var md5obj = md5init();
	md5add(md5obj, what);
	md5final( md5obj );
	return (
		md5_hex32( md5obj.a ) +
		md5_hex32( md5obj.b ) +
		md5_hex32( md5obj.c ) +
		md5_hex32( md5obj.d )
	);
}

