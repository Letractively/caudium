/* PIKE */

#include <module.h>

#define NOBLOCK_TTL 300
#define BLOCK_TTL 900

inherit "module";
inherit "caudiumlib";

constant cvs_version = "$ Id $";
constant module_type = MODULE_FILE_EXTENSION;
constant module_name = "Deep image blocker";
constant module_doc  =
  "This module attempts to detect when someone from another site is "
  "referencing an image from this server on another site. This is done on a "
  "directory by directory basis.<br />"
  "<br />"
  "Every time an image is accessed this module checks for the existance of a "
  "file called <pre>.image_block</pre> in the same directory.  If said file "
  "doesn't exist then the image is served as normal.  If the file does exist "
  "then it's contents are examined for a list of regexps specifying the "
  "allowed refferrers and the path to an image to serve in it's place. <br />"
  "Like so:<br />"
  "<pre>"
  "ReferrerAllow\t^http\\:\\/\\/www\\.caudium\\.(net|info|org)\/.*\n"
  "DenyImage\t/var/www/image/dontlink.gif\n"
  "</pre>"
  "<br />"
  "There can be as many <pre>ReferrerAllow</pre> lines as you want. This "
  "module only works on static images, and not server generated ones.";
  
constant module_unique = 1;
constant thread_safe = 1;

static mapping blocked;

object module_cache;

void create() {
  defvar("Extensions", ({ "jpg", "jpeg", "gif", "png" }), "File Extensions", TYPE_STRING_LIST, "The file extensions to assume are images.");
}

void start() {
  blocked = ([]);
  module_cache=GET_CACHE();
}

string status() {
  string retval = "Blocked referrers:<br />";
  foreach(indices(blocked), string key) {
    retval += sprintf("%s %d time(s)<br />", key, blocked[key]);
  }
  if (sizeof(blocked))
    return retval;
  else
    return "No referrers blocked.";
}

array query_file_extensions() {
  return QUERY(Extensions);
}

mixed handle_file_extension(object file, string extension, object id) {
  if (!id->referrer)
    return 0;
  string blockfile = Stdio.append_path(dirname(id->realfile), ".image_block");
  if (id->pragma["no-cache"]) 
    module_cache->refresh(blockfile);
  int|mapping block = module_cache->retrieve(blockfile, parse_blockfile, ({ blockfile }));
  if (!block)
    // We aren't doing anything about files in this directory.
    return 0; 
  else if (mappingp(block)) {
    foreach(block->ReferrerAllow, string reg) {
      object regex = module_cache->retrieve(sprintf("regex:%O", reg), get_regex, ({ reg }));
      if (regex->match(id->referrer))
        return 0;
      else {
        blocked[id->referrer]++;
        return get_blockimage(blockfile, block);
      }
    }
  }
}

object get_regex(string reg) {
  object regex = Regexp(reg);
  module_cache->store(cache_pike(regex, sprintf("regex:%O", reg), -1));
  return regex;
}

int|mapping parse_blockfile(string blockfile) {
  if (!Stdio.exist(blockfile)) {
    module_cache->store(cache_pike(0, blockfile, NOBLOCK_TTL));
    return 0;
  }
  object f;
  if (catch(f = Stdio.File(blockfile, "r"))) {
    module_cache->store(cache_pike(0, blockfile, NOBLOCK_TTL));
    return 0;
  }
  string data = f->read();
  f->close();
  array lines = (data / "\r")*"" / "\n" - ({ "" });
  // Split the lines on either \r or \n.
  mapping block = ([]);
  foreach(lines, string line) {
    string key, value;
    sscanf(line, "%s%*[\t ]%s", key, value);
    switch (key) {
    case "ReferrerAllow":
      if (block->ReferrerAllow && arrayp(block->ReferrerAllow))
        block->ReferrerAllow += ({ value });
      else
        block->ReferrerAllow = ({ value });
      break;
    case "DenyImage":
      block[key] = value;
      break;
    }
  }
  module_cache->store(cache_pike(block, blockfile, BLOCK_TTL));
  // Store the contents of the blockfile in the cache.

  // Let's pre-cache the deny image so that it's in the cache in advance:
  _get_blockimage(blockfile, block);
  return block;
}

mapping get_blockimage(string blockfile, mapping block) {
  object img = module_cache->retrieve(sprintf("image:%O", blockfile), _get_blockimage, blockfile, ({ block }));
  return Caudium.HTTP.string_answer(Image.PNG.encode(img), "image/png");
}

object _get_blockimage(string blockfile, mapping block) {
  if (!block->DenyImage)
    return 0;
  if (!Stdio.exist(block->DenyImage)) {
    perror("Trying to block with image %O, but it doesn't exist.");
    return 0;
  }
  object f;
  if (catch(f = Stdio.File(block->DenyImage, "r"))) {
    perror("Trying to block with image %O, but I can't open it.");
    return 0;
  }
  string data = f->read();
  f->close();
  object img = Image.ANY.decode(data);
  module_cache->store(cache_image(img, sprintf("image:%O", blockfile), BLOCK_TTL));
  return img;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: Extensions
//! The file extensions to assume are images.
//!  type: TYPE_STRING_LIST
//!  name: File Extensions
//
