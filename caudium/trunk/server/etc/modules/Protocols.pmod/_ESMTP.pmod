/*
 * Caudium - An extensible World Wide Web server
 * Copyright C 2000-2002 The Caudium Group
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
 * The Caudium/Camas ESMTP client module
 *
 * #1 most important TODO: dsn support.
 * other things TODO:
 *	general error handling is very close to nothing (from behind, that is)
 *	destruct
 */

constant cvs_version = "$Id$";

#define CODECLASS(X)	( ((smtp_reply->retcode / 100) * 100 == X) ? 1 : 0 )

class client
{
	constant DSN_SUCCESS = 1;
	constant DSN_DELAY   = 2;
	constant DSN_FAILURE = 4;

	// wish i knew wtf is this here for...
	constant reply_codes = ([
		211:	"System status, or system help reply",
		214:	"Help message",
		220:	"<host> Service ready",
		221:	"<host> Service closing transmission channel",
		235:	"Authentication succeeded",
		250:	"Requested mail action okay, completed",
		251:	"User not local; will forward to <forward-path>",
		334:	"!!this is a reply for authentication request, stuff told by the server here IS NEEDED!!",
		354:	"Start mail input; end with <CRLF>.<CRLF>",
		421:	"<host> Service not available, closing transmission channel "
			"[This may be a reply to any command if the service knows it "
			"must shut down]",
		450:	"Requested mail action not taken: mailbox unavailable "
			"[E.g., mailbox busy]",
		451:	"Requested action aborted: local error in processing",
		452:	"Requested action not taken: insufficient system storage",
		500:	"Syntax error, command unrecognized "
			"[This may include errors such as command line too long]",
		501:	"Syntax error in parameters or arguments",
		502:	"Command not implemented",
		503:	"Bad sequence of commands",
		504:	"Command parameter not implemented",
		535:	"Authentication failure",
		550:	"Requested action not taken: mailbox unavailable "
			"[E.g., mailbox not found, no access]",
		551:	"User not local; please try <forward-path>",
		552:	"Requested mail action aborted: exceeded storage allocation",
		553:	"Requested action not taken: mailbox name not allowed "
			"[E.g., mailbox syntax incorrect]",
		554:	"Transaction failed"
	]);

	private object conn = Stdio.FILE();		// the connection itself
	private mapping smtp_reply = ([
		"lines": 0,
		"retcode": 0,
		"line": ({ })
	]);						// holds server responses
	private mapping supports = ([
		"esmtp":	0,
		"dsn":		0,
		"tls":		0,
		"auth":	([
				"yes":		0,
				"methods":	({ })
		]),
		"size":		0
	]);						// server capability list

	void create(void|string server, void|string|int port, void|string maildomain)
	{
		string fqdn;
		// reasonably-looking defaults
		if(!server)
			server = "127.0.0.1";
		if(!port) {
			port = 25;
#if 0
		// FIXME: sumtin's wrong here.
		} else if (stringp(port)) {
			port = Protocols.Ports.tcp(port);
			if(port == 0)
				port = 25;
#endif
		} else {
			port = 25;
		}

		fqdn = gethostname() + ( maildomain ? "." + maildomain : "" );

		if(!conn->connect(server, port))
			throw( ({ "Connection to " + server + " failed\n", backtrace() }) );
		smtp_read();
		if( !CODECLASS(200) )
			throw( ({ "Connection reset by " + server + "\n", backtrace() }) );
		smtp_tell("EHLO " + fqdn);
		// FIXME: needs cleanup. does not handle cases where...
		// whatever. it just needs to be refined more.
		if( !CODECLASS(200) ) {
			supports->esmtp = 0;
			smtp_tell("HELO " + fqdn);
			if( !CODECLASS(200) ) {
				throw( ({ "Communication setup failed with " + server + ":\n" }) );
			}
		} else {
			supports->esmtp = 1;
			for(int i=1; i<smtp_reply->lines; i++) {
				string s = lower_case(smtp_reply->line[i][4..]);
				switch((s/" ")[0]) {
					case "starttls":
						supports->tls = 1;
					break;
					case "auth":
						supports->auth->yes = 1;
						foreach((s/" ")[1..], string e)
							supports->auth->methods += ({ e });
					break;
#if 0
					// FIXME: broken. need to study the thing a bit more.
					case "size":
						
						supports->size = (int)(s/" ")[1];
					break;
#endif
					default:
					break;
				}
			}
		}
		// now we should be all set up.
	}

	private void smtp_tell(string what) {
		conn->write(what + "\n");
		smtp_read();
	}

	private void smtp_read() {
		array reply = ({ });
		string tmp0, tmp1 = "";
		// multiline reply parser
		do {
			tmp0 = conn->gets();
			tmp1 += tmp0;
		} while (tmp0[3] == '-');
		// i want to keep each lines of the reply
		reply = tmp1 / "\r";
		// but not the last ""
		reply = reply[0..sizeof(reply)-2];
		smtp_reply->lines = 0; smtp_reply->line = ({ });
		foreach(reply, string s) {
			smtp_reply->line += ({ s });
		}
		smtp_reply->lines = sizeof(reply);
		smtp_reply->retcode = (int)reply[0][0..2];
	}

	int sender(string address) {
		if(address[0] != '<')
			address = "<" + address;
		if(address[strlen(address)-1] != '>')
			address += ">";
		smtp_tell("MAIL FROM: " + address);
		if( !CODECLASS(200) )
			return 0;
		return 1;
	}
	
	int recipient(string|array address) {
		if(stringp(address)) {
			if(address[0] != '<')
				address = "<" + address;
			if(address[strlen(address)-1] != '>')
				address += ">";
		} else {
			// FIXME: something's fishy here too
			for(int i=0; i<sizeof(address); i++) {
				string s = address[i];
				if(s[0] != '<') address[i] = "<" + s;
				if(s[strlen(s)-1] != '>') address[i] += ">";
			}
		}
		if(stringp(address)) {
			smtp_tell("RCPT TO:" + address);
			if( !CODECLASS(200) ) {
				return 0;
			} else {
				return 1;
			}
		}
		foreach(address, string s) {
			smtp_tell("RCPT TO: " + s);
			if( !CODECLASS(200) )
				return 0;
		}
		return 1;
	}

	int body(string body) {
		array b = body / "\n";
		for(int i=0; i<sizeof(b)-1; i++) {
			if( strlen(b[i]) == 1 && b[i][0] == '.')
				b[i] = "." + b[i];
		}
		// TODO: add a received header here.
		smtp_tell("DATA");
		if( !CODECLASS(300) )
			return 0;
		foreach(b, string e)
			conn->write(e + "\n");
		smtp_tell(".");
		return ( CODECLASS(200) ? 1 : 0 );
	}

	void quit() {
		smtp_tell("QUIT");
		conn->close();
		destruct( this_object() );
	}

	int auth(string user, string pass) {
		int able = 0;
		string method = "";
		multiset known_methods = (< >);
		if(!supports->auth->yes)
			return 0;
		// the order of this also indicates the preference when multiple
		// methods are available
#if constant(Crypto.md5)
		known_methods += (< "cram-md5" >);
#endif
		known_methods += (< "plain", "login" >);
		foreach(supports->auth->methods, string s) {
			if(known_methods[s])
				method = s;
			break;
		}
		if(method == "")
			return 0;
		return do_auth(user, pass, method);
	}

	private int do_auth(string user, string pass, string method) {
#if constant(Crypto.md5)
		string ipad, opad, inner, outer, challenge;
		int i;
#endif
		switch(method) {
			case "plain":
				smtp_tell("AUTH PLAIN " + MIME.encode_base64(sprintf("\0%s\0%s\0",
					user, pass )));
				if(!CODECLASS(200)) {
					return 0;
				} else {
					return 1;
				}
			break;
			case "login":
				smtp_tell("AUTH LOGIN");
				if(!CODECLASS(300))
					return 0;
				smtp_tell(MIME.encode_base64(user));
				if(!CODECLASS(300))
					return 0;
				smtp_tell(MIME.encode_base64(pass));
				if(!CODECLASS(200)) {
					return 0;
				} else {
					return 1;
				}
			break;
#if constant(Crypto.md5)
			case "cram-md5":
				smtp_tell("AUTH CRAM-MD5");
				if(!CODECLASS(300))
					return 0;
				challenge = MIME.decode_base64(smtp_reply->line[0][4..]);
				ipad = pass;
				for(i=strlen(ipad); i<64; i++)
					ipad += "\0";
				opad = ipad;
				for(i=0; i<64; i++) {
					ipad[i] ^= 0x36;
					opad[i] ^= 0x5c;
				}
				inner = Crypto.md5()->update(ipad)->update(challenge)->digest();
				outer = Crypto.string_to_hex( Crypto.md5()->update(opad)->update(inner)->digest() );
				smtp_tell(MIME.encode_base64( user + " " + outer ));
				if(!CODECLASS(200)) {
					return 0;
				} else {
					return 1;
				}
			break;
#endif
			default:
				return 0;
			break;
		}
		// just to make sure...
		return 0;
	}

	private string prettyprint(array what) {
		string retval = "";
		foreach(what, string s)
			retval += s + "\n";
		return retval;
	}


}



