inherit "module";
#include <module.h>

string cvs_version = "$Id$";

//! module: Advanced Wizard
//!  This module contains code that implements advanced wizard interface. You can
//!  use this module to create versatile wizard-based user dialogs.
//! type: MODULE_PARSER
//! cvs_version: $Id$
//
//! tag: awizard
//!  Defines a new wizard.
//! attribute: title
//!  Set title of the new wizard.
//
//! container: page
//!  Creates a new wizard page.
//! attribute: name
//!  Optional attribute to set the page name.
//
//! container: verify
//!  Code enclosed within that container will be executed when leaving this
//!  page. use &lt;error&gt; error message &lt;/error&gt; containers inside
//!  verify if you want to prohibit user to leave the page.
//
//! tag: button
//!  Create a button that, when pressed, will transfer the user to either
//!  a wizard page or an URL.
//! attribute: [prev]
//!  Go to the previous page when pressed.
//! attribute: [next]
//!  Go to the next page when pressed.
//! attribute: [page = page_name]
//!  Go to the specified page (defined in this awizard) when pressed.
//! attribute: [href = URL]
//!  Go to the specified URL when pressed.
//! attribute: [title = title_text]
//!  Set the button title.
//! attribute: [image = URL]
//!  Set the image for the button. If not present, created button will be of the
//!  'submit' type.
//
//! container: ebutton
//!  The same as the &lt;[button]&gt; tag, with the exception that the contents of the
//!  tag is considered to be an RXML code and executed when the button is pressed.
//
//! container: come-from
//!  Contents of this container is executed whenever the user arrived from the given
//!  page.
//! attribute: name = page_name
//!  Sets the name of the previous page which will trigger execution of the associated
//!  RXML code in this container.
//!
//! tag: goto
//!  Unconditionally go to the given page defined in this awizard.
//! attribute: page = page_name
//!  Set the page where the user should be transferred.
//! attribute: href = URL
//!  Set the URL where the user should be transferred.
//
//! container: warn
//!  Display the contents of the container as a warning.
//! attribute: quiet
//!  no output, just sets warn_message variable
//! attribute: silent
//!  html commented output of the warning message
//! attribute: solid
//!  displays only the message without info sign.
//
//! container: notice
//!  Display the contents of the container as a notice.
//! attribute: quiet
//!  no output, just sets notice_message variable
//! attribute: silent
//!  html commented output of the notice message
//! attribute: solid
//!  displays only the message without info sign.
//
//! container: error
//!  Display the contents of the container as an error, 
//!  or prohibits leave a page if used inside a
//!  verify container.
//! attribute: quiet
//!  no output, just sets error_message variable
//! attribute: silent
//!  html commented output of the error message
//! attribute: solid
//!  displays only the message without info sign.
//
constant module_type = MODULE_PARSER;
constant module_name = "Advanced Wizards";
constant module_doc  = "<B>Advanced Wizards module</b><p><br>\n"
	    "Tags:<br>"
	    "<b>&lt;awizard title=...&gt;</b><br>"
	    "<b>&lt;page [name=...]&gt;</b><br>"
	    "<b>&lt;verify&gt;</b>...<b>&lt;/verify&gt;</b>"
	    "  --&gt; Will be executed when leaving the page.<br>"
	    "<b>&lt;button [page=...] [title=...] [image=...]&gt;</b><br>"
	    "<b>&lt;ebutton [href=...] [title=...] [image=...]&gt;</b>"
	    "  RXML code to execute when the button is pressed<b>&lt;/ebutton&gt;</b><br>"
	    "<b>&lt;come-from page=...&gt;</b>"
	    "  RXML to be executed when arriving from page<b>&lt;/come-from&gt;</b><br>"
	    "<b>&lt;goto page=...&gt;</b><br>"
	    "<b>&lt;goto href=...&gt;</b><br>"
	    "<b>&lt;warn&gt;</b>string<b>&lt;/warn&gt;</b><br>"
	    "<b>&lt;notice&gt;</b>string<b>&lt;/notice&gt;</b><br>"
	    "<b>&lt;error&gt;</b>string<b>&lt;/error&gt;</b>"
	    "  (can be used to prevent the user from leaving this page)<br>"
	    "<b>&lt;/page&gt;</b>";
constant module_unique = 1;


// Store (advanced wizards with procedures) module...
// tags:
//  <awizard title=...>
//  <page [name=...]>
//   <verify>...</verify> --> Will be executed when leaving the page.
//   <button [page=...] [title=...] [image=...]>
//   <ebutton [href=...] [title=...] [image=...]>RXML code to execute when the button is pressed</ebutton>
//   <come-from page=...>RXML to be executed when arriving from page</come-from>
//   <goto page=...>
//   <goto href=...>
//   <warn>string</warn>
//   <notice>string</notice>
//   <error>string</error> (can be used to prevent the user from leaving this page)
//  </page>

class Page
{
inherit "wizard"; // For 'html_warn' with friends.
mapping TAGS, CONTAINERS;

void init_tags()
{
  TAGS = ([]);
  CONTAINERS = ([]);
  foreach(glob("tag_*", indices(this_object())), string i)
    TAGS[ replace(i-"tag_", "_", "-") ] = this_object()[ i ];
  foreach(glob("container_*", indices(this_object())), string i)
    CONTAINERS[ replace(i-"container_","_","-") ] = this_object()[ i ];
}


string ce = "";
string container_awizard_pike(string t, mapping m, string c, int l, object id,
			    object awiz)
{

  if( !query("allow_awizard_pike") ) {
	report_warning("Awizard: &lt;awizard-pike&gt; called, '<b>%s</b>' on virtual server: <b>%s:%s</b> while awizard-pike is disabled for this virtualserver",
		id->not_query, 
		id->conf->this->name, id->conf->this->variables->name[0] );
	return "<!-- awizard-pike is disabled -->";
  }
  array err;
  string res;
  object e = ErrorContainer();
  string code = 
    ("#define error(x) return \"<error>\"+x+\"</error>\";\n"
     "string parse(object id, mapping args) { "+c+"; }");
  master()->set_inhibit_compile_errors(e);
  err = catch {
    res=compile_string(code)()->parse(id, m);
  };
  if(strlen(e->get())) 
  {
    string res="";
    int line = 1;
    foreach(code/"\n", string s)
      res += sprintf("%3d: %s\n", line++, s);
    code = res;
    return "<preparse tag=error><b><font color=darkred><doc magic pre>"+
      e->get()+"</doc><doc magic pre>"+code+"</doc></font></b><p></preparse>";
  }
  master()->set_inhibit_compile_errors(0);
  master()->clear_compilation_failures();
  if(err) throw(err);
  return res||"";
}

string tag_goto(string t, mapping m, int l, object id, object awiz)
{
  if(m->page)
    id->misc->return_me = ([ "page":m->page ]);
  else
    id->misc->return_me = ([ "href":m->href ]);
  return "";
}

string tag_wizardbuttons(string t, mapping m, int l, object id, object awiz)
{
  return ("<p><table width=100%><tr width=100% >\n"
	  "<td  width=50% align=left>"
	  "<button prev title=\""+(m->previous||" &lt;- Previous ")+"\">"
	  "</td><td width=50% align=left>"
	  "<button next title=\""+(m->next||" Next -&gt; ")+"\"></td></tr>\n"
	  "</table>");
}

string tag_button(string t, mapping m, int l, object id, object awiz)
{
  mapping args = ([]);
  if(m->page)
    args->name  = "goto_page_"+m->page+"/"+m->id;
  else if(m->href)
    args->name  = "goto_href_"+m->href+"/"+m->id;
  else if(m->next)
  {
    if(!id->misc->next_possible)
      return "";
    args->name  = "goto_next_page/"+m->id;
  }
  else if(m->prev)
  {
    if(!id->misc->prev_possible)
      return "";
    args->name  = "goto_prev_page/"+m->id;
  } else 
    args->name = "goto_current_page/"+m->id;
  if(m->image) {
    args->type = "image";
    args->alt  = m->title||m->alt||m->page||"[ "+m->image+" ]";
    args->title = args->alt;
    args->border="0";
    args->src = replace(m->image, ({" ","?"}), ({"%20", "%3f"}));
  } else {
    args->type  = "submit";
    args->value  = m->title||m->page;
  }
  return make_tag("input", args);
}

string container_dbutton(string t, mapping m, string c, int l, object id, object awiz)
{
  mapping args = ([]);
  if(m->page)
    args->name  = "goto_page_"+m->page+"/"+m->id;
  else if(m->href)
    args->name  = "goto_href_"+m->href+"/"+m->id;
  else if(m->next)
  {
    if(!id->misc->next_possible)
      return "";
    args->name  = "goto_next_page/"+m->id;
  }
  else if(m->prev)
  {
    if(!id->misc->prev_possible)
      return "";
    args->name  = "goto_prev_page/"+m->id;
  } else 
    args->name = "goto_current_page/"+m->id;
  if(m->image) {
    args->type = "image";
    args->alt  = m->title||m->alt||m->page||"[ "+m->image+" ]";
    args->title = args->alt;
    args->border="0";
    args->src = replace(m->image, ({" ","?"}), ({"%20", "%3f"}));
  } else {
    args->type  = "submit";
    args->value  = m->title||m->page;
  }
  args->name += "/eval/"+MIME.encode_base64( c, 1 );
  return make_tag("input", args);
}

string container_warn(string t, mapping m, string c, int l, object id, object awiz )
{
  id->variables->warn_message=c;

  if( m->quiet ) return "";
  if( m->silent) return "<!-- error: '"+c+"' -->";
  if( m->solid ) return c;

  return html_warning( c, id );
}

string container_notice(string t, mapping m, string c, int q, object id, object awiz )
{
  id->variables->notice_message=c;

  if( m->quiet ) return "";
  if( m->silent) return "<!-- notice: '"+c+"' -->";
  if( m->solid ) return c;

  return html_notice( c, id );
}

string container_error(string t, mapping m, string c, int q, object id, object awiz) 
{
  id->variables->error_message = c;

  if( m->quiet ) return "";
  if( m->silent) return "<!-- error: '"+c+"' -->";
  if( m->solid ) return c;

  return html_error( c,id );
}

  int num, id, button_id, line_offset;
  string name;

  string page;   // RXML code for normal page.
  string verify; // RXML code for verification.

  mapping come_from = ([ ]);
  mapping procedures = ([ ]);
  mapping button_code;

  mapping my_tags, my_containers;


  string internal_tag_verify(string t, mapping args, string c)
  {
    verify += c;
    return "";
  }

  string internal_tag_ebutton(string t, mapping m, string c)
  {
    m->id=(string)++button_id;
    button_code[(int)m->id] = c;
    return make_tag("button", m);
  }

  string internal_tag_come_from(string t, mapping args, string c)
  {
    if(!come_from[args->name])
      come_from[args->name] = c;
    else
      come_from[args->name] += c;
    return "";
  }

  mapping up_args = ([]);

  string call_procedure(string which, mapping args,  object id)
  {
    array replace_from = ({"#args#"})+
      Array.map(indices(args)+indices(up_args),lambda(string q){return "&"+q+";";});
    array replace_to = (({make_tag_attributes( args + up_args ) })+
			values(args)+values(up_args));
    foreach(indices(args), string a)
    {
      up_args["::"+a]=args[a];
      up_args[which+"::"+a]=args[a];
    }
    return replace(procedures[ which ], replace_from , replace_to);
  }

  void create(mapping m, string from, mapping p, int bi, mapping bc)
  {
    button_code = bc;
    button_id = bi;
    init_tags();
    procedures = p;
    my_tags = TAGS;
    my_containers = CONTAINERS;

    foreach(indices(procedures), string proc) 
      my_tags[ proc ] = call_procedure;

    num =  m->num;
    name = m->name;
    page = parse_html(from, ([ ]), ([
      "verify":internal_tag_verify,
      "ebutton":internal_tag_ebutton,
      "come-from":internal_tag_come_from,
    ]));
  }

  string eval(string what, object id)
  {
    up_args = ([]);
    if(!what) return "";

    id->misc->offset = line_offset;
    // Huergl. It's time to fiddle with id->misc->_tags with friends. :-)
    // This is not the recommended way to do things, but what the heck...
    // It might even work. :-)

    
    // WARNING: Needs new htmlparse.pike (at least version 1.103)
    foreach(indices(my_tags), string s) {
	id->misc->_tags[ s ] = call_tag_wrapper;
    }
    foreach(indices(my_containers), string s) {
      	id->misc->_containers[ s ] = call_container_wrapper;
    }

    return parse_rxml(parse_html(what,(["var":wizard_tag_var,]),
				 (["cvar":wizard_tag_var]),id),id);
  }  

  /* We need this dirty hack, 
   * id->misc->_tags, id->misc->_containers called differently if we
   * use Main RXML parser (compatibility) or if the XML compliant */
  mixed call_tag_wrapper( mixed ... args ) {
	object parser, id, awiz;
	string tag;
	mapping m, d;
	int l;

	// XML compliat parser
	if( objectp( args[0] )) {
		parser=args[0]; m=args[1]; id=args[2]; awiz=args[3];
		d=args[4]; tag = parser->tag_name();
		id->misc->line = (string)parser->at_line();
		l=(int) id->misc->line;
	} else {
		tag=args[0]; m=args[1]; l=args[2]; id=args[3]; awiz=args[4];
	}

	if( my_tags[ tag ] )
		return my_tags[ tag ]( tag, m, l, id, awiz );

	return "";
  }

  mixed call_container_wrapper( mixed ... args ) {
	object parser, id,awiz;
	string tag,c;
	mapping m,d;
	int l;

	// XML compliat parser
	if( objectp( args[0] )) {
		parser=args[0]; m=args[1]; c=args[2]; id=args[3]; awiz=args[4];
		d=args[5]; tag = parser->tag_name();
		id->misc->line = (string)parser->at_line();
		l=(int) id->misc->line;
	} else {
		tag=args[0]; m=args[1]; c=args[2]; l=args[3];
		id=args[4]; awiz=args[5];
	}

	if( my_containers[ tag ] )
		return my_containers[ tag ]( tag, m, c, l, id, awiz );

	return "";  
  }

  mapping|int can_leave(object id, string eeval)
  {
    m_delete(id->variables,"error_message");
    eval(eeval+button_code[id->misc->button_id]+verify, id);
    if(id->misc->return_me) return id->misc->return_me;
    return !id->variables->error_message;
  }

  string generate( object id, string header, string footer )
  {
    string contents = eval((come_from[id->last_page]||"")
			   + header + (id->variables->error_message||"") + page + footer, id);
//     if(id->variables->error_message)
//       contents = contents + error_message;
    id->variables->error_message=0;
    return contents;
  }
}

class Store
{
  inherit "wizard";

  string footer="";
  string header="";
  array pages = ({});
  mapping pages_by_name = ([]);
  mapping procedures = ([]);
  int last_page, button_id;

  string internal_tag_header(string t, mapping args, string c)
  {
    header = c;
  }

  string internal_tag_footer(string t, mapping args, string c)
  {
    footer = c;
  }

  string internal_tag_include(string t, mapping args, int l, object id)
  {
    if(args->define) return id->misc->defines[args->define]||"";
    string q = roxen->try_get_file(fix_relative(args->file, id), id);
    return q;
  }

  string internal_tag_proc(string t, mapping args, string c)
  {
    if(args->type == "pike") c = "<awizard-pike #args#>"+c+"</awizard-pike>";
    procedures[args->name] = c;
  }

  mapping button_code;
  string internal_tag_page(string t, mapping args, string c, int l, object id)
  {
    args->num = last_page;
    if(!args->name) args->name = (string)last_page;
    pages += ({ Page( args, c, procedures, button_id, button_code ) });
    button_id = pages[ -1 ]->button_id;
    pages[ -1 ]->line_offset = id->misc->offset + l;
    pages_by_name[ args->name ] = pages[ -1 ];
    last_page++;
  }

  string lc = "";
  void update(string contents, object id)
  {
    if((contents != lc) || id->pragma["no-cache"])
    {
      lc = contents;
      contents=(Stdio.read_bytes(query("proc"))||"No proc db\n")
	+contents;
      button_code = ([]);
      button_id = 0;
      last_page = 0;
      pages = ({});
      procedures = ([]);
      pages_by_name = ([]);
      footer=header="";

      parse_html_lines( parse_html_lines(contents, 
			 ([
 			    "awizard_include":internal_tag_include,
			  ]),
			  ([
			     "comment":lambda(){ return ""; },
			   ]),id), 
		  ([]),
		  ([ "page":internal_tag_page,
		     "header":internal_tag_header,
		     "proc":internal_tag_proc,
		     "footer":internal_tag_footer, ]),id );


      int off = sizeof(header/"\n")-1;
      foreach(pages, object p) 
	p->line_offset -= off;

    }
  }

  object parent;
  void create(mapping args, string contents, object id, object p)
  {
    update(contents,id);
    parent = p;
  }



  mapping|string handle( object id )
  {
    mapping v = id->variables;
    mapping s = decompress_state(v->_shop_state), error;
    object page, last_page;
    int new_page;
    string contents, goto;

    foreach(indices(s), string q)
      v[ q ] = v[ q ]||s[ q ];

    m_delete(v, "_shop_state");
    id->misc->next_possible = ((int)v->_page_num) < (sizeof(pages)-1);
    id->misc->prev_possible = ((int)v->_page_num) > 0;

    foreach(glob("goto_*", indices(v)), string q)  
    {
      goto = q;
      m_delete(v, q);
    }
    
    if(goto)
    {
      array w = goto/".";
      goto = w[0];
      mapping er;

      string extra_eval;
      if(sscanf(goto, "%*s/eval/%s", extra_eval) == 2)
	extra_eval = MIME.decode_base64( extra_eval );

      last_page = pages[ (int)v->_page_num ];
      if(last_page) v->last_page = last_page->name;
      if(mappingp(er) && !er->page)
	error = er;
      else if(mappingp(er) && er->page)
	new_page = (pages_by_name[ error->page ] && 
		    pages_by_name[ error->page ]->num)+1;
      else if(sscanf(goto, "goto_next_page/%d",id->misc->button_id))
	new_page = ((int)v->_page_num)+2;
      else if(sscanf(goto, "goto_prev_page/%d", id->misc->button_id))
	new_page = ((int)v->_page_num); 
      else if(sscanf(goto, "goto_page_%s/%d", goto, id->misc->button_id))
	new_page = pages_by_name[ goto ] && pages_by_name[ goto ]->num+1;
      else if(sscanf(goto, "goto_href_%s/%d", goto, id->misc->button_id))
	return http_redirect( goto, id );
      
      if( last_page && last_page->can_leave( id, extra_eval ))
      {
	if(new_page)
	{
	  if(new_page < 1) new_page = 1;
	  if(new_page > sizeof(pages)) new_page = sizeof(pages);
	  v->_page_num = (string)(new_page-1);
	}
      }
    }


    id->misc->next_possible = ((int)v->_page_num) < (sizeof(pages)-1);
    id->misc->prev_possible = ((int)v->_page_num) > 0;
    
    if (!pages || !sizeof(pages))
	return http_string_answer("<strong>There are no pages to show!</strong><br />");

    page = pages[ (int)v->_page_num ];

    if(!error) 
    {
      contents = page->generate( id, header, footer );
      error = id->misc->return_me;
    }

    if(error)
    {
      if(error->page && error->page != page->name)
      {
	v["goto_page_"+error->page+"/0"]=1;
	return handle( id );
      } else if(error->href) {
	return http_redirect(error->href, id);
      } else if(!error->page)
	return error;
    }

    foreach(glob("goto_*", indices(v)), string nope)  m_delete(v, nope);
    m_delete(v, "_page_num");
    m_delete(v, "_shop_state");
    return
      ("<form method="+(parent->query("debug")?"get":"post")+
       " action=\""+id->not_query+"\">\n"
       " <input type=hidden name=_page_num value=\""+page->num+"\">\n"
       " <input type=hidden name=_shop_state value=\""+
       compress_state(v)+"\">\n" + contents + " </form>\n");
  }
}

void create()
{
  defvar("debug", 0, "Debug mode", TYPE_FLAG|VAR_EXPERT, "");
  defvar("proc", "", "Procedure library", TYPE_FILE, 
	 "If set, this variable points to a file with procedures that "
	 "can be used by all stores. Use the real (physical) filename.");
  defvar("allow_awizard_pike",0,"Awizard-Pike tag", TYPE_FLAG,
         "If set, you can use, and additonal tag for scripting in AWizards: "
	 "<b>&lt;awizard-pike&gt</b>...pike code...<b>&lt;/awizard-pike&gt;</b>"
	 "in your pages, or procedures.<br>"
	 "this is doing somewhat same like pike tag support.<br>"
	 "<font color=red>NOTE: Enabling awizard-pike is the same thing as letting your users"
	 "run programs with the same right as the server!</font>" );
}


mapping stores = ([]);

constant help = "Da help";

mixed tag_store(string tagname, mapping arguments, string contents, object id)
{
  mixed res;

  if(arguments->help)
    return help;

  if(!stores[id->not_query])
    stores[id->not_query] = Store( arguments, contents, id, this_object() );
  else
    stores[id->not_query]->update( contents, id );
  res = stores[id->not_query]->handle( id );
  if(mappingp(res)) 
  {
    string v = "";
    if (res->extra_heads) {
      foreach(indices(res->extra_heads), string i)
        v += "<header name="+i+" value='"+res->extra_heads[i]+"'>";
    }
    
    return v+"<return code="+res->error+">";
  }
  return ({res});
}


mapping query_container_callers()
{
  return ([ "awizard" : tag_store, ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: debug
//!  type: TYPE_FLAG|VAR_EXPERT
//!  name: Debug mode
//
//! defvar: proc
//! If set, this variable points to a file with procedures that can be used by all stores. Use the real (physical) filename.
//!  type: TYPE_FILE
//!  name: Procedure library
//
//! defvar: allow_awizard_pike
//! If set, you can use, and additonal tag for scripting in AWizards: <b>&lt;awizard-pike&gt</b>...pike code...<b>&lt;/awizard-pike&gt;</b>in your pages, or procedures.<br />this is doing somewhat same like pike tag support.<br /><font color=red>NOTE: Enabling awizard-pike is the same thing as letting your usersrun programs with the same right as the server!</font>
//!  type: TYPE_FLAG
//!  name: Awizard-Pike tag
//
