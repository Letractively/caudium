/* Code used by the site classes. Commonly usable. It's included in those file
 * using #include.
 * 
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

object frame, framebox;
static private object hlist;
static private int stime; // Start time.
static private object status; // Status bar (current action, last updated)
static private object context_menu;
static array context_menu_callback;

void create(function|void done)
{
  //thread_create(refetch, done);
  if(this_object()->custom_setup)
    this_object()->custom_setup();
}

void set_status(string s)
{
}

void prefailed(mixed ... args)
{
  log_event(site, "Failed to get headlines.");
  set_status("Failed to update headlines at "+
	     ctime(time())[4..18]+".");
  stime = 0;
  //fetch_failed(@args);
}

void first_fetch()
{
  if(!headlines)
    refetch();
}

void refetch(function|void done, function|void failed)
{
  if(stime)
    // fetching already in progress
    return; 
  stime = time();
  object http =   HTTPFetcher();
  http->timeout = 40;
  http->async_fetch(url+path, got_reply,
		    failed||prefailed, done);
}

void fetch()
{
  if(stime)
    // fetching already in progress
    return; 
  stime = time();
  string data = HTTPFetcher()->fetch(url+path);
  headlines = ({});
  parse_reply((data||"") - "\r");
}


mixed cast(string to)
{
  mixed tmp;
  switch(to)
  {
   case "array":
    return headlines;

   case "string":
    tmp = "";
    foreach(headlines, mapping hl)
      tmp += entry2txt(hl);
    return tmp;

   default:
    throw("Can't cast to "+to);
  }
}

private static void got_reply(object http, void|function done)
{
  headlines = ({});
  if((http->status / 100 ) == 2 ||
     (site == "Central Europe" && http->status == 302) // Stupid buggy site!
     ) {
    parse_reply((http->data()||"") - "\r");
  }
  else {
    log_event(site, "Failed to get headlines (return code "+http->status+").");
    set_status("Failed to get headlines at "+ctime(time())[4..18]+"."); 
  }
  stime = 0;
  if(done) done(this_object());
}


inline string indent(string text, int space)
{
  string ind = " " * space;
  return ind + replace(sprintf("%-=70s", text), "\n", "\n"+ind);
}

