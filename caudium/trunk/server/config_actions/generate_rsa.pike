/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2004 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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
 * $Id$
 */

inherit "wizard";

#if SSL_DEBUG
#define WERROR report_debug
#else
#define WERROR(x)
#endif

constant name = "Security//Generate a new RSA key pair...";

constant doc = ("In order to use the SSL on your server, "
		"you first have to create a random RSA key pair."
		"One part of the key is kept secret. The "
		"other part should be submitted to a certificate "
		"authority, such as Thawte or VeriSign. The "
		"certificate authority will return the signed "
		"certificate that need to run a secure server." 
		"Note that it is possible to have more than one "
		"certificate for the same key.");

#if !constant(_Crypto) || !constant(Crypto.rsa)

constant action_disabled = 1;

#else /* constant(_Crypto) && constant(Crypto.rsa) */

mixed page_0(object id, object conf)
{
  string msg;
  
  if (id->variables->_error)
  {
    msg = "<font color=red>" + id->variables->_error
      + "</font><p>";
    id->variables->_error = 0;
  }
  
  return (msg || "" )
    + ("<font size=+1>How large key do you want to generate?</font><p>"
       "<var name=key_size type=int default=1024> Key size <br>\n"
       "<help><blockquote>"
       "The desired key size. This is a security parameter; larger "
       "keys gives better security, but it also makes connecting to "
       "the server a little slower.<p>"
       "The largest RSA key that is publicly known to have been broken "
       "was 130 decimal digits, or about 430 bits large. This "
       "effort required 500 MIPS-years.<p>"
       "A key 1000 bits large should be secure enough for most "
       "applications, but of course you can you use an even larger key "
       "if you so wish."
       "</blockquote></help>"
       "<var name=key_file type=string><br>\n"
       "Where to store the secret key, relative to " + getcwd() + "<br>\n"
       "<help><blockquote>"
       "A filename in the real filesystem, where the secret key should "
       "be stored. This is the filename you enter in the 'Key file'-field "
       "when you configure an SSL listen port."
       "</blockquote></help>");
}

mixed verify_0(object id, object conf)
{
  int key_size = (int) id->variables->key_size;
  if (key_size < 300)
  {
    id->variables->_error =
      "Keys smaller than 300 bits are ridiculous.";
    return 1;
  }
  if (key_size > 5000)
  {
    id->variables->_error =
      "Keys larger than 5000 bits would take too long to generate.";
    return 1;
  }

  object file = Stdio.File();
  object privs = Privs("Storing private RSA key.");
  if (!file->open(id->variables->key_file, "wxc", 0600))
  {
    id->variables->_error =
      "Could not open file: "
      + (strerror(file->errno()) || (string) file->errno())
      + ".";
    privs = 0;
    return 1;
  }

  privs = 0;

  object rsa = Crypto.rsa();
  rsa->generate_key(key_size, Crypto.randomness.reasonably_random()->read);

#if constant(Tools)
  string key = Tools.PEM.simple_build_pem
    ("RSA PRIVATE KEY",
     Standards.PKCS.RSA.rsa_private_key(rsa));
#else /* !constant(Tools) */
  /* Backward compatibility */
  string key = SSL.pem.build_pem("RSA PRIVATE KEY",
				 Standards.PKCS.RSA.rsa_private_key(rsa));
#endif /* constant(Tools) */
  WERROR(key);
  
  if (strlen(key) != file->write(key))
  {
    id->variables->_error =
      "Write failed: "
      + (strerror(file->errno()) || (string) file->errno())
      + ".";
    return 1;
  }

  return 0;
}

mixed wizard_done(object id, object conf)
{
  return 0;
}

mixed handle(object id) { return wizard_for(id,0); }

#endif /* constant(_Crypto) && constant(Crypto.rsa) */
