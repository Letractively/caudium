// This is a roxen module. by Aw.
// orginal 123stophotlinking.pike by  Kai Voigt <k@123.org> http://k.123.org


#include <module.h>
inherit "module";
inherit "roxenlib";

mixed register_module() {
	return ({ MODULE_FILTER,
		"ColdLink",
		"Coldlink, stops HOTlinks.",
		({}), 1, });
}

void create() {



defvar("hosts", "", "referer hosts", TYPE_TEXT_FIELD,
	"allow referer hostlist<br>"
	"Syntax:<pre>"
	"	myfirstdomain.com:allow\n"
	"	www.myfirstdomain.com:allow\n"
	"	myotherdomain.com:allow\n"
	"	www.myotherdomain.com:allow\n"
	"	ex-girlfriends.com:deny:/block.html\n"
	"	bad.links.com:deny:/block.html");


defvar("extentions", "", "extention rules ", TYPE_TEXT_FIELD,
	"extentions rules (<i>NOTE:</i> the hostlist overrides extentions) <br />"
	"Syntax:<pre>"
	"	jpg:/error.jpg\n"
	"	gif:/error.gif\n"
	"	mpg:/error.html\n"
	);



}

mixed filter(mapping res, object id)
	{
	if (!id->request_headers->referer)
		{ return 0; } //if no referer....


	sscanf(id->request_headers->referer, "%*s://%[^/:]", string referer_host);
	string my_host = (id->request_headers->host/":")[0];

// test hosts...
	if (referer_host == my_host)  // Locallink?
	{ return 0; }

	foreach(query("hosts")/"\n",string tmp)
	{
	array tmp1= tmp/":";

	if(tmp1[0] == referer_host && tmp1[1] == "allow") // ALLOW host
		{ return 0; }

	if(tmp1[0] == referer_host && tmp1[1] == "deny")  // DENY host
		{
		if(id->not_query ==tmp1[2]) return 0;
		return (http_redirect(tmp1[2],id));
		}
	}

	// test extentions based
	array  tmp_ext = basename(id->not_query)/".";
	string file_ext =tmp_ext[sizeof(tmp_ext)-1];

	foreach(query("extentions")/"\n",string tmp)
	{
	array tmp1= tmp/":";
	if(tmp1[0] ==file_ext) return (http_redirect(tmp1[1],id));
	}

return 0;
}
