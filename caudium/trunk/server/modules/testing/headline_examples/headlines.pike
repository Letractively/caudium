#!/usr/local/bin/pike

#if constant(GTK) && constant(thread_create)
#define USE_GTK
#define DEBUG
import ".";
import GTK.MenuFactory;
inherit Headlines.Version;


array   log =({});   // Event (debug) log.
array   site_names = ({}); // Array with the names of the sites..

mapping sites;

object  event_log; // Event log list
object  log_window; // Event log window.
object  selected_site;         // Current site

void add_log_entry(string site, string event, mixed ... args)
{
  if(sizeof(args))
    event = sprintf(event, @args);
  log += ({ ({ ctime(time())[4..18], site, event }) });
  if(sizeof(log) > 100)
  {
    log = log[15..];
    if(event_log)
      event_log->set_data(log);
  } else if(event_log)
    event_log->add_log_entry(log[-1]);
}


void f_show_site(object new_site, void|object tree)
{
  selected_site = new_site;
  foreach(values(sites), object s)
    s->frame->hide();
  selected_site->frame->show();
  selected_site->first_fetch();
  if(tree && new_site) {
    object row, parent;
    parent = row = tree->find_by_row_data(selected_site);
    if(!objectp(row)) return;
    tree->select(row);
    while(parent = parent->parent())
      tree->expand(parent);
    tree->node_moveto(row, 1, 0.5, 0.0);
  }
}

void f_update()
{
  if(selected_site)
    thread_create(selected_site -> refetch);
}

void f_update_all(object site)
{
  foreach(values(sites), object s)
    thread_create(s -> refetch);
}

void f_toggle_log()
{
  if(log_window)
    destruct(log_window);
  else {
    log_window = GTK.Window( GTK.WINDOW_TOPLEVEL )->realize();
    log_window -> set_title("Pike Headlines Event Log");
    event_log = Headlines.MyGTK.EventLog();
    if(log)
      event_log->set_data(log);
    event_log->list->set_usize(500, 400);
    log_window->add(event_log->list);
    log_window->show_all();
  }
}

void f_ctree_selected(mixed q, object w, object node)
{
  object site = w->node_get_row_data(node);
  if(site && site != selected_site) f_show_site(site);
}

void f_change_site(int change, object tree) {
  if(!selected_site)
    return;
  mapping tmpmap = mkmapping(values(sites), indices(sites));
  int pos = search(site_names, tmpmap[selected_site]);
  if(pos == -1)   return; // Not found for some reason.
  pos += change;
  if(pos >= sizeof(site_names)) // Jump to first.
    pos = 0;
  f_show_site( sites[ site_names[pos] ], tree);
}

// Rather ugly function to sort sites in correct "menu order"
int site_sort(object a, object b)
{
  if(a->sub == b->sub) {
    return lower_case(a->site)
      > lower_case(b->site);
  }
  array aa = a->sub / "/";
  array bb = b->sub / "/";
  while(sizeof(aa) && sizeof(bb)) {
    if(aa[0] == bb[0]) {
      if(sizeof(aa) == 1)
	return 1;
      else if(sizeof(bb) == 1)
	return 0;
    }
    aa = aa[1..];
    bb = bb[1..];
  }
  return lower_case(a->sub)
    > lower_case(b->sub);
}

void loader(array tmp, object stat, object label)
{
  float left = (float)sizeof(tmp);
  foreach(tmp, string site) {
    label->set_text(site);
    array err = catch(Headlines.Sites[site]);
#ifdef DEBUG
    if(err)
      werror("Error loading %s: %s\n", site, describe_backtrace(err));
#endif
    left--;
    stat->update(1 - left/sizeof(tmp));
  }
}

void f_fold_tree(object tree) { tree->collapse_recursive(0); }
void f_unfold_tree(object tree) { tree->expand_recursive(0); }

int main(int argc, array argv)
{
  thread_create(setitup, argv);
  return -1;
}

void setitup(array argv) {
  object menu, table, w;
  int stime = time(); // Start boot time.
  argv = GTK.setup_gtk(argv);
  add_constant("log_event", add_log_entry);
  add_constant("hversion", version);
  add_constant("trim", Headlines.Tools()->trim);
  array tmp;
  string basedir = "/"+ (tmp = __FILE__ / "/" -
			 ({""}))[..sizeof(tmp)-2]*"/" +"/";
  mapping logo = GTK.Util.low_load_image(basedir+"splash.jpg");
  object pix = GDK.Image(0)->set(logo->img || Image.image(1,1));
  
  tmp =
    sort(Array.map(glob("*.pike",
			get_dir(basedir+"Headlines.pmod/Sites.pmod/")||({})),
		   lambda (string s) { return s - ".pike"; }));
  w = GTK.Window(GTK.WINDOW_POPUP);
  object label,stat = GTK.ProgressBar();
  stat -> set_show_text(1);
  w->add(GTK.Vbox(0,0)
	 -> add(GTK.Image(pix))
	 -> add(label=GTK.Label("Loading Plugins..."))
	 -> add(stat))->set_position(GTK.WinPosCenter)->show_all();
  thread_create(loader, tmp, stat, label)->wait();
  destruct(w);
  destruct(pix); 
  logo = stat = 0;
  sites = mkmapping(indices(Headlines.Sites), 
		    Array.map(indices(Headlines.Sites),
			      lambda(string s) {
				return Headlines.Sites[s]();
			      }));
  mapping tmpmap = mkmapping(values(sites), indices(sites));
  w = GTK.Window( GTK.WINDOW_TOPLEVEL )
    -> set_policy(1, 1, 0);
  object vbox = GTK.Vbox(0,0);
  vbox -> set_usize(600,400);
  object site_tree = GTK.Ctree(2,1)
    //    -> set_expander_style(GTK.CtreeExpanderSquare)
    //    -> set_line_style(GTK.CtreeLinesSolid)
    -> set_indent(8);
  array menudefs = ({
    MenuDef("Commands/<check>View Event Log", f_toggle_log, 0, "a-l"),
    MenuDef("Commands/Reload Current Site", f_update, 0, "a-r"),
    MenuDef("Commands/Update All Sites", f_update_all, 0, "a-u"),
    MenuDef("Commands/<separator>", 0),
    MenuDef("Commands/Previous Site", f_change_site, ({-1, site_tree}), "c-p"),
    MenuDef("Commands/Next Site", f_change_site, ({1, site_tree}), "c-n"),
    MenuDef("Commands/Expand Site Tree ", f_unfold_tree, site_tree, "a-e"),
    MenuDef("Commands/Collapse Site Tree", f_fold_tree, site_tree, "a-c"),
    MenuDef("Commands/<separator>", 0),
    MenuDef("Commands/Quit", exit, 0, "a-q"),
  });
  mapping temp = ([]);
  foreach(Array.sort_array(values(sites), site_sort), object site)
  {
    if(site->disabled)
      continue;
    if(!selected_site)
      selected_site = site;
    site_names += ({ tmpmap[site] });
    vbox->pack_end(site->frame, 1,1,2);
    site->frame->hide();
    menudefs += ({ MenuDef(site->sub+"/"+site->site, f_show_site, ({ site,site_tree })) });
    string tmppath,path="/";
    foreach(site->sub / "/", string s)
    {
      tmppath += s+"/";
      if(!temp[tmppath]) {
	temp[tmppath] = site_tree->insert_node(temp[path], 0, 0, 0, 0);
	site_tree->node_set_text(temp[tmppath], 1, s);
      }
      path = tmppath;
    }
    object node = site_tree->insert_node(temp[path], 0, 0, 0, 0);
    site_tree->node_set_text(node, 1, site->site)
      -> node_set_row_data(node, site);
    
  }
  site_tree -> signal_connect(GTK.s_tree_select_row, f_ctree_selected, 0);
  site_tree -> set_column_auto_resize(1, 1);
  [menu, table] = MenuFactory(@menudefs);
  object hbox = GTK.Hpaned()
    -> add1(GTK.ScrolledWindow(GTK.Adjustment(),GTK.Adjustment())
	    -> set_policy(GTK.POLICY_AUTOMATIC,GTK.POLICY_AUTOMATIC)
	    -> add(site_tree) -> set_usize(180, 0)->show_all())
    -> add2(vbox->show())
    -> show();
  object vbox2 = GTK.Vbox(0,0)
    -> pack_start(menu->show(), 0, 0, 0)->add(hbox);
  w -> add(vbox2->show())->show()
    -> add_accel_group(table)
    -> set_title("Pike Headlines "+version);
  
  add_log_entry("Master Program",
		sprintf("Headlines started in %d seconds.", time() - stime));
  //  f_show_site(selected_site, site_tree );
}
	   
#else
void main()
{
  werror("Sorry! PiGTK and threads is required to run this program.\n"
	 "You can get PiGTK from http://pike-community.org/sites/pigtk/\n");
}
#endif
