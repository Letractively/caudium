string get_hash( string data ) {
  string retval;
#if constant(_Lobotomized_Crypto)
  retval = _Lobotomized_Crypto.md5()->update( data )->digest();
#elseif constant(Crypto)
  retval = Crypto.md5()->update( data )->digest();
#else
  retval = MIME.encode_base64( data );
#endif
  return sprintf("%@02x",(array(int)) retval);
}
