/* $Id$
 *
 */

inherit "cipher" : cipher;


string identity; /* Identifies the session to the server */
int compression_algorithm;
int cipher_suite;
object cipher_spec;
int ke_method;
string master_secret; /* 48 byte secret shared between client and server */

constant Struct = ADT.struct;
constant State = CaudiumSSL.state;
array(int) version;
array(string) client_certificate_chain;
array(string) server_certificate_chain;

void set_cipher_suite(int suite,int version)
{
  array res = cipher::lookup(suite,version);
  cipher_suite = suite;
  ke_method = res[0];
  cipher_spec = res[1];
#ifdef SSL3_DEBUG
  werror(sprintf("CaudiumSSL.session: cipher_spec %O\n",
		 mkmapping(indices(cipher_spec), values(cipher_spec))));
#endif
}

void set_compression_method(int compr)
{
  if (compr != COMPRESSION_null)
    throw( ({ "CaudiumSSL.session->set_compression_method: Method not supported\n",
		backtrace() }) );
  compression_algorithm = compr;
}

string generate_key_block(string client_random, string server_random,array(int) version)
{
  int required = 2 * (
#ifndef WEAK_CRYPTO_40BIT
    cipher_spec->is_exportable ?
#endif /* !WEAK_CRYPTO_40BIT (magic comment) */
    (5 + cipher_spec->hash_size)
#ifndef WEAK_CRYPTO_40BIT
    : ( cipher_spec->key_material +
	cipher_spec->hash_size +
	cipher_spec->iv_size)
#endif /* !WEAK_CRYPTO_40BIT (magic comment) */
  );
  object sha = mac_sha();
  object md5 = mac_md5();
  int i = 0;
  string key = "";

  if(version[1]==0) {
    while (strlen(key) < required)
      {
	i++;
	string cookie = replace(allocate(i), 0, sprintf("%c", 64+i)) * "";
#ifdef SSL3_DEBUG
	werror(sprintf("cookie %O\n", cookie));
#endif
	key += md5->hash_raw(master_secret +
			     sha->hash_raw(cookie + master_secret +
					   server_random + client_random));
      }
  } else if(version[1]==1) {
    key=prf(master_secret,"key expansion",server_random+client_random,required);

  }
#ifdef SSL3_DEBUG
  werror(sprintf("key_block: %O\n", key));
#endif
  return key;
}

#ifdef SSL3_DEBUG
void printKey(string name , string key) {

  string res="";
  res+=sprintf("%s:  len:%d type:%d \t\t",name,strlen(key),0); 
  /* return; */
  for(int i=0;i<strlen(key);i++) {
    int d=key[i];
    res+=sprintf("%02x ",d&0xff);
  }
  res+=sprintf("\n");
  werror(res);
}

#endif

array generate_keys(string client_random, string server_random,array(int) version)
{
  object key_data = Struct(generate_key_block(client_random, server_random,version));
  array keys = allocate(6);

#ifdef SSL3_DEBUG
  werror(sprintf("client_random: %O\nserver_random: %O\n",
		client_random, server_random));
#endif
  /* client_write_MAC_secret */
  keys[0] = key_data->get_fix_string(cipher_spec->hash_size);
  /* server_write_MAC_secret */
  keys[1] = key_data->get_fix_string(cipher_spec->hash_size);

#ifndef WEAK_CRYPTO_40BIT
  if (cipher_spec->is_exportable)
#endif /* !WEAK_CRYPTO_40BIT (magic comment) */
  {
    if(version[1]==0) {
      //SSL3.0
      object md5 = mac_md5()->hash_raw;
      
      keys[2] = md5(key_data->get_fix_string(5) +
		    client_random + server_random)
	[..cipher_spec->key_material-1];
      keys[3] = md5(key_data->get_fix_string(5) +
		    server_random + client_random)
	[..cipher_spec->key_material-1];
      if (cipher_spec->iv_size)
	{
	  keys[4] = md5(client_random + server_random)[..cipher_spec->iv_size-1];
	  keys[5] = md5(server_random + client_random)[..cipher_spec->iv_size-1];
	}

    } if(version[1]==1) {
      //TLS1.0
      string client_wkey= key_data->get_fix_string(5);
      string server_wkey= key_data->get_fix_string(5);
      keys[2] = prf(client_wkey,"client write key",client_random+server_random,cipher_spec->key_material);
      keys[3] = prf(server_wkey,"server write key",client_random+server_random,cipher_spec->key_material);
      if(cipher_spec->iv_size) {
	string iv_block=prf("","IV block",client_random+server_random,2*cipher_spec->iv_size);
	keys[4]=iv_block[..cipher_spec->iv_size-1];
	keys[5]=iv_block[cipher_spec->iv_size..];
	werror("strlen(keys[4]):"+strlen(keys[4])+"   strlen(keys[5]):"+strlen(keys[4])+"\n");
      }
      
    }
    
  }
  
#ifndef WEAK_CRYPTO_40BIT
  else {
    keys[2] = key_data->get_fix_string(cipher_spec->key_material);
    keys[3] = key_data->get_fix_string(cipher_spec->key_material);
    if (cipher_spec->iv_size)
      {
	keys[4] = key_data->get_fix_string(cipher_spec->iv_size);
	keys[5] = key_data->get_fix_string(cipher_spec->iv_size);
      }
  }
#endif /* !WEAK_CRYPTO_40BIT (magic comment) */

#ifdef SSL3_DEBUG
  printKey( "client_write_MAC_secret",keys[0]);
  printKey( "server_write_MAC_secret",keys[1]);
  printKey( "keys[2]",keys[2]);
  printKey( "keys[3]",keys[3]);
  
  if(cipher_spec->iv_size) {
    printKey( "keys[4]",keys[4]);
    printKey( "keys[5]",keys[5]);
    
  } else {
    werror("No IVs!!\n");
  }
#endif
  
  return keys;
}

array new_server_states(string client_random, string server_random,array(int) version)
{
  object write_state = State(this_object());
  object read_state = State(this_object());
  array keys = generate_keys(client_random, server_random,version);

  if (cipher_spec->mac_algorithm)
  {
    read_state->mac = cipher_spec->mac_algorithm(keys[0]);
    write_state->mac = cipher_spec->mac_algorithm(keys[1]);
  }
  if (cipher_spec->bulk_cipher_algorithm)
  {
    read_state->crypt = cipher_spec->bulk_cipher_algorithm();
    read_state->crypt->set_decrypt_key(keys[2]);
    write_state->crypt = cipher_spec->bulk_cipher_algorithm();
    write_state->crypt->set_encrypt_key(keys[3]);
    if (cipher_spec->iv_size)
    {
      read_state->crypt->set_iv(keys[4]);
      write_state->crypt->set_iv(keys[5]);
    }
    if (cipher_spec->cipher_type == CIPHER_block)
    { /* Crypto.crypto takes care of splitting input into blocks */
      read_state->crypt = Crypto.crypto(read_state->crypt);
      write_state->crypt = Crypto.crypto(write_state->crypt);
    }
  }
  return ({ read_state, write_state });
}

array new_client_states(string client_random, string server_random,array(int) version)
{
  object write_state = State(this_object());
  object read_state = State(this_object());
  array keys = generate_keys(client_random, server_random,version);
  
  if (cipher_spec->mac_algorithm)
  {
    read_state->mac = cipher_spec->mac_algorithm(keys[1]);
    write_state->mac = cipher_spec->mac_algorithm(keys[0]);
  }
  if (cipher_spec->bulk_cipher_algorithm)
  {
    read_state->crypt = cipher_spec->bulk_cipher_algorithm();
    read_state->crypt->set_decrypt_key(keys[3]);
    write_state->crypt = cipher_spec->bulk_cipher_algorithm();
    write_state->crypt->set_encrypt_key(keys[2]);
    if (cipher_spec->iv_size)
    {
      read_state->crypt->set_iv(keys[5]);
      write_state->crypt->set_iv(keys[4]);
    }
    if (cipher_spec->cipher_type == CIPHER_block)
    { /* Crypto.crypto takes care of splitting input into blocks */
      read_state->crypt = Crypto.crypto(read_state->crypt);
      write_state->crypt = Crypto.crypto(write_state->crypt);
    }
  }
  return ({ read_state, write_state });
}
    

