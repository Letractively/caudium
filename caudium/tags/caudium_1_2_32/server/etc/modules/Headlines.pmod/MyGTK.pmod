/* MyGTK.pmod - Extensions and Widgets for the headlines project.
 * $Id$
 *
 * Written by David Hedbor <david@hedbor.org>.
 *
 */

class Headline
{
  GTK.SClist list;
  private array names;
  object col1 = GDK.Color(240,240,255);
  object col2 = GDK.Color(255,255,255);
  object fg = GDK.Color(0,0,0);
  int color_counter; // which color to use...
  int selected_row = -1; // Currently selected row

  void f_select_row(mixed q, object w, int row) {
    selected_row = row;
  }
  void f_unselect_row() {  selected_row = -1; }
  void f_mouse_button(function cb, object w, mapping event)
  {
    cb(event, w, selected_row);
  }    
  
  void create(array titles, array _names, function|void mouse_cb)
  {
    names = _names;
    list = GTK.SClist(sizeof(titles));
    list -> set_policy(GTK.PolicyAutomatic, GTK.PolicyAutomatic)
      -> column_title_active(1)
      -> column_titles_show()
      -> set_shadow_type(GTK.ShadowIn);
      //      -> set_sort_column(0);
    //      -> columns_autosize();
    if(mouse_cb) {
      list -> signal_connect("button_press_event", f_mouse_button, mouse_cb);
      list -> signal_connect("button_release_event", f_mouse_button, mouse_cb);
      list -> signal_connect("select_row", f_select_row);
      list -> signal_connect("unselect_row", f_unselect_row);
    }
    for(int c = 0; c < sizeof(titles); c ++) {
      list -> set_column_title(c, titles[c]);
      list->set_column_auto_resize(c, 1);
    }
  }
  
  void set_data(array headlines)
  {
    list->freeze()->clear();
    array maxlen = allocate(sizeof(names));
    int i;
    for(i = 0; i < sizeof(headlines); i ++)
    {
      array cols = Array.map(names,
			     lambda(string n) {
			       return (string)headlines[i][n];
			     });
      for(int c = 0; c < sizeof(names); c ++)
	if(strlen(cols[c]) > maxlen[c])
	  maxlen[c] = strlen(cols[c]);

      list -> append(cols);
      list -> set_foreground(i, fg);
      if(i % 2)
	list->set_background(i, col1);
      else
	list->set_background(i, col2);
    }
    color_counter = i;
    //    for(int c = 0; c < sizeof(names) - 1;  c ++)
    //      list->set_column_width(c, maxlen[c] * 6);
    list->thaw();
  }
}

class EventLog
{
  inherit Headline;

  void create()
  {
    ::create( ({ "Date", "Site", "Event" }), ({ 0, 1, 2 }) );
  }
  void set_data(array event_log) {
    ::set_data( Array.map (event_log,
			   lambda(array entry) {
			     return mkmapping(indices(entry),
					      entry);
			   }));
  }
  void add_log_entry(array event)
  {
    list -> freeze();
    list -> append(event);
    list -> set_foreground(color_counter, fg);
    if(color_counter % 2)
      list->set_background(color_counter, col1);
    else
      list->set_background(color_counter, col2);
    color_counter++;
    list->thaw();
  }
  
}

class ContextMenu {
  inherit GTK.Menu;

  array callback;

  void f_run_callback(mixed ... args)
  {
    if(callback)
      callback[0](@callback[1..]);
    ::popdown();
  }
  
  void create(array layout)
  {
    ::create();
    foreach(layout, array menu_item)
    {
      object item = GTK.MenuItem(menu_item[0]);
      item -> signal_connect("select",
			     lambda(array a) {
			       callback = a;
			     }, menu_item[1..]);
      item -> signal_connect("deselect", lambda() {
					 callback = 0;
				       });
    ::append( item );
    }
    ::show_all();
    ::signal_connect("button_release_event", f_run_callback, 0);
  }
}
