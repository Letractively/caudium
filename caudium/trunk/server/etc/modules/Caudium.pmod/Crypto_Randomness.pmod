// $Id$

//! Assorted stronger or weaker randomnumber generators.
//! These devices try to collect entropy from the environment.
//! They differ in behaviour when they run low on entropy, /dev/random
//! will block if it can't provide enough random bits, while /dev/urandom
//! will degenerate into a reasonably strong pseudo random generator
//! @deprecated Crypto.Random

// #pragma strict_types

#if constant(Crypto.SHA1.name)

static constant RANDOM_DEVICE = "/dev/random";
static constant PRANDOM_DEVICE = "/dev/urandom";

/* Collect somewhat random data from the environment. Unfortunately,
 * this is quite system dependent
 */
static constant PATH = "/usr/sbin:/usr/etc:/usr/bin/:/sbin/:/etc:/bin";

static constant SYSTEM_COMMANDS = ({
  "last -256", "arp -a",
  "netstat -anv","netstat -mv","netstat -sv",
  "uptime","ps -fel","ps aux",
  "vmstat -s","vmstat -M",
  "iostat","iostat -cdDItx"
});

static RandomSource global_arcfour;
static int(0..1) goodseed;

//! Executes several programs (last -256, arp -a, netstat -anv, netstat -mv,
//! netstat -sv, uptime, ps -fel, ps aux, vmstat -s, vmstat -M, iostat,
//! iostat -cdDItx) to generate some entropy from their output. On Microsoft
//! Windows the Windows cryptographic routines are called to generate random
//! data.
string some_entropy()
{
  mapping env = [mapping(string:string)]getenv();
  env->PATH = PATH;

  Stdio.File parent_pipe = Stdio.File();
  Stdio.File child_pipe = parent_pipe->pipe();
  if (!child_pipe)
    error( "Couldn't create pipe.\n" );

  Stdio.File null = Stdio.File("/dev/null","rw");

  foreach(SYSTEM_COMMANDS, string cmd)
    {
      catch {
	Process.create_process(Process.split_quoted_string(cmd),
				       (["stdin":null,
					"stdout":child_pipe,
					"stderr":null,
					"env":env]));
      };
    }

  destruct(child_pipe);

  return parent_pipe->read();
}

//! Virtual class for randomness source object.
class RandomSource {

  //! Returns a string of length len with (pseudo) random values.
  string read(int(0..) len) { return random_string(len); }
}

// Compatibility
constant pike_random = RandomSource;

//! A pseudo random generator based on the arcfour crypto.
class arcfour_random {

  inherit Nettle.ARCFOUR_State;

  //! Initialize and seed the arcfour random generator.
  void create(string secret)
  {
    set_encrypt_key(Crypto.SHA1->hash(secret));
  }

  //! Return a string of the next len random characters from the
  //! arcfour random generator.
  string read(int len)
  {
    if (len > 16384) return read(len/2)+read(len-len/2);
    return crypt("\47" * len);
  }
}

//! Returns a reasonably random random-source.
RandomSource reasonably_random()
{
  if (file_stat(PRANDOM_DEVICE))
  {
    Stdio.File res = Stdio.File();
    if (res->open(PRANDOM_DEVICE, "r"))
      return res;
  }

  if (global_arcfour)
    return global_arcfour;

  string seed = some_entropy();
  if (sizeof(seed) < 2001)
    seed = random_string(2001); // Well, we're only at reasonably random...
  return (global_arcfour = arcfour_random(sprintf("%4c%O%s", time(),
						  _memory_usage(), seed)));
}

//! Returns a really random random-source.
RandomSource really_random(int|void may_block)
{
  Stdio.File res = Stdio.File();
  if (may_block && file_stat(RANDOM_DEVICE))
  {
    if (res->open(RANDOM_DEVICE, "r"))
      return res;
  }

  if (file_stat(PRANDOM_DEVICE))
  {
    if (res->open(PRANDOM_DEVICE, "r"))
      return res;
  }

  error( "No source found.\n" );
}

#endif // constant(Crypto.SHA1)
