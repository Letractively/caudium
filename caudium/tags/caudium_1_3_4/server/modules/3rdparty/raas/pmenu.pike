
/*
 * pmenu.pike
 *
 * Copyright András Horváth <raas@dawn.elte.hu>
 *
 */

#include <module.h>
inherit "module";

string cvs_version = "$Id$";

array register_module()
{
  return ({ MODULE_PARSER,
            "Prestate Menu Module",
            "Add the 'pmenu' tag.", ({}), 1
            });
}

string pmenu(string tag, mapping m, string contents, object id)
{
	string rval="";	 // return value
	string pres,val; // current item's prestate and value
	int pos;	 // tmp, position of the first ":"
	array(array) items=({ }); // all the menu items with prestates
	string tmp; // whatever

	foreach(contents/"\n",string s) if(sizeof(s)) // empty lines don't count
	{
		pos=search(s,":");
		pres=s[0..pos-1];  // left of the first ":" is the prestate
		val=s[pos+1..]; // the rest is the value (can have ":"'s)
		items+=({ ({ pres,val }) }); 	
	}
	foreach(items, array curr_item) {
		rval+="<apre ";	
		foreach(column(items,0), string s)
			if(s==curr_item[0])
				rval+=" "+s;
			else
				rval+=" -"+s;
		rval+=">"+curr_item[1]+"</apre> \n"; 
	}
	return rval;
}

string info() { return 
		"The <b>pmenu</b> tag is used to create menus that represent the "
		"selected menu item in a prestate. Thus, it can be handled "
		"using &lt;if prestate=..&gt;.<br>"
		"Prestates and display values are separated by a ':'."
		"Of course, values may have colons in them.<br><p>"
		"&lt;pmenu&gt;<br>"
		"first:This will be the first menuitem.<br>"
		"second:This is the second<br>"
		"3rd:iwueriqoweuriqwe<br>"
		"&lt;/pmenu&gt;<p>"
		"See <a href=\"http://dawn.elte.hu/~raas/szakma/pmenu/index.html\">"
		"http://dawn.elte.hu/~raas/szakma/pmenu/index.html</a> for an example.";
}

mapping query_container_callers() { return (["pmenu":pmenu]); }

