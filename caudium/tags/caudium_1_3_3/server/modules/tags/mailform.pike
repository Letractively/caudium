
/////////////////////////////////////////////////////////////////
//                                                             //
//  MAILFORM tag v 0.1                                         //
//  Form to Mail roxen module. You can dump Forms to Mail      //
//  David Farre polak@polakilandia.org                         //
//  License GPL                                                //
//                                                             //
/////////////////////////////////////////////////////////////////



#include <config.h>
#include <module.h>
inherit "module";
inherit "caudiumlib";

constant cvs_version = "$Id$";

mixed js_error(string pcamp,string error)
{
    string out="";
    error=replace(error,({"%FIELD%"}),({pcamp}));
    out+="<html>\n";
    out+="<script language='JavaScript'>\n";
    out+="function err(){\n";
    out+="\talert(\""+error+"\");\n";
    out+="\thistory.go(-1);\n";
    out+="}\n";
    out+="</script>\n";
    out+="<body bgcolor='white' onload='err();'>\n";
    out+="<h3>"+error+"</h3>\n";
   
    out+="</body>\n";
    out+="</html>\n";
 
    return http_string_answer(out,"text/html");
}



string help(){
    return "Form to Mail module. You can dump Forms to Mail."
           "<h2>Help</h2>"
           "&nbsp;<b>&lt;mailform <br />&nbsp;&nbsp;[help] <br />&nbsp;&nbsp;user='</b><i>destination email</i><b>' <br />&nbsp;&nbsp;[return='</b><i>url</i><b>'] <br />&nbsp;&nbsp;[required='</b><i>field1,field2,...</i><b>'] <br />&nbsp;&nbsp;[sender='</b><i>sender email address</i><b>'] <br />&nbsp;&nbsp;[sender-var='</b><i>name of form-input that will contains the  sender's email address </i><b>'] &gt;</b><br />"
           "&nbsp;<i>all fields and decorations</i><br />"
           "&nbsp;<b>&lt;/mailform&gt;</b>";
}

void start(int level)
{
}

#if __ROXEN_VERSION__ < 2.0
array register_module()
{ return ({ MODULE_LOCATION | MODULE_PARSER,
       "MAILFORM Tag",
       ( "Form to Mail module. You can dump Forms to Mail."),
       0,
       1 });
}
#else


constant module_type = MODULE_LOCATION | MODULE_PARSER;
constant module_name = "MAILFORM Tag";
constant module_doc  = "Form to Mail module. You can dump Forms to Mail.";

#endif

void create()
{
	defvar("mountpoint", "/internal_mailform", "Form ACTION / MOUNTPOINT",
		TYPE_LOCATION, "Destination location for GET/POST." );
	defvar("method", "POST", "Form METHOD", 
		TYPE_STRING_LIST, "HTTP FORM method.",
		( {"POST", "GET"} ) );
	defvar("Vuser", "__user", "Destination Email Address",
		TYPE_STRING, "Variable name for de email address destination." );
	defvar("Sender", "nobody@localhost", "From Email Address.",
		TYPE_STRING, "From mail address. This can be overwritten if tag has var-sender or sender attributes" );
	defvar("Vpage", "page", "Referer URL" , 
		TYPE_STRING, "Variable name for current page URL." );
	defvar("VretURL", "retURL", "Return URL",
		TYPE_STRING, "Variable name for thanx page." );
	defvar("VSender", "__sender", "Sender mail",
		TYPE_STRING, "Variable name for sender mail." );
	defvar("VVar_Sender", "__var_sender", "Sender mail",
		TYPE_STRING, "Variable name for form variable that contains sender mail." );
	defvar("Vorder", "internal_order", "Order of variables",
               TYPE_STRING, "Variable name for variables order." );
	defvar("VSenderProg", "/usr/lib/sendmail -i -t -fnobody@localhost", "MTA command line",
               TYPE_STRING, "The command line for sending mails." );

        defvar("VUserInfo", 1, "Format:Include User Info",
		TYPE_FLAG, "Include in thee mail the user host, address and agent." );
        defvar("Vemptyfield", "The required field %FIELD% is empty.", "Format:Error empty field",
		TYPE_STRING, "The error in javascript alert that shows when a required field is empty. %FIELD% will be the empty field name's." );
        defvar("VBadMail", "The email '%FIELD%' is a invalid email.", "Format:Error bad email",
		TYPE_STRING, "The error in javascript alert that shows when a email field contains a invalid email. %FIELD% will be the invalid email." );
	defvar("VFormatVar", "%VARIABLE% = %VALUE%\n", "Format:Format of mail lines",
		TYPE_STRING, "The format of the lines that produce this module." );
        defvar("VHeaderMail",  "= [User] ==================================", "Format:Format of mail header ",
		TYPE_TEXT_FIELD, "The format of the mail header." );
	defvar("VSepOrd",   "= [Required Vars] =========================", "Format:Format of ordered vars header",
		TYPE_STRING, "The format of the header in the ordered vars section." );
	defvar("VSepOther", "= [Other Vars] ============================", "Format:Format of other vars header",
		TYPE_STRING, "The format of the header in the other vars section." );
        defvar("VEndMail", "= [End] ===================================", "Format:Format of end of mail",
		TYPE_TEXT_FIELD, "The format of end of mail." );
        defvar("VSubject", "FORM from %PAGE%", "Format:Format of subject",
		TYPE_TEXT_FIELD, "The format of subject mail's. %PAGE% will be replaced by referer page." );

}



string query_location() { return query("mountpoint"); }

string mailtime()
{
  int t = time();
  mapping lt = localtime(t);
  string wday, month;
  if (sscanf(ctime(t), "%s %s %*s", wday, month) < 2)
    return "";
  return sprintf("%s, %02d %s %d %02d:%02d:%02d %s%04d",
		 wday, lt->mday, month, lt->year+1900, lt->hour, lt->min,
		 lt->sec, -lt->timezone >=0 ? "+":"", -lt->timezone*100/3600);
}

mapping find_file( string f, object id ){
    string out="";
    string texte="";
    string sender="";
    array vars=indices(id->variables);
    vars-=({query("Vuser"),query("Vorder"), query("VretURL"), query("Vpage"),query("VSender"),query("VVar_Sender")});
    if(id->variables[query("Vorder")] && sizeof(id->variables[query("Vorder")])){
        foreach((id->variables[query("Vorder")]/","),string s){
            s-=" ";
            vars-=({s});
            if(id->variables[s])
            {
                if(!sizeof(id->variables[s]))
                    return js_error(s,query("Vemptyfield"));
                out+=replace(query("VFormatVar"),({"%VARIABLE%","%VALUE%"}),({s,id->variables[s]}))+"\n";
            }
        }
    }
    out+="\n"+query("VSepOther")+"\n";
    foreach(sort(vars),string s)
        out+=replace(query("VFormatVar"),({"%VARIABLE%","%VALUE%"}),({s,id->variables[s]}))+"\n";
    texte+="\n"+query("VHeaderMail")+"\n";
    if(query("VUserInfo"))
    {
        texte+="ADDR={"+id->remoteaddr+"}\n";
        texte+="HOST={"+id->request_headers["host"]+"}\n";
        texte+="USER-AGENT={"+id->request_headers["user-agent"]+"}\n";
    }
    texte+="\n"+query("VSepOrd")+"\n";
    texte+=out;
    texte+="\n"+query("VEndMail")+"\n";


    object mail = MIME.Message("",
                               (["MIME-Version" : "1.0",
                                 "Content-Type" : "text/plain; charset=iso-8859-1",
                                 "X-Mailer" : "Form2Mail" ]) );

    mail->headers["to"]  = id->variables[query("Vuser")];


    if(sizeof(query("Sender")))
        sender=query("Sender");
    if(sizeof(query("VSender")) && id->variables[query("VSender")] && sizeof(id->variables[query("VSender")]))
        sender=id->variables[query("VSender")];
    if(sizeof(query("VVar_Sender")) && id->variables[query("VVar_Sender")] && sizeof(id->variables[query("VVar_Sender")]) && id->variables[id->variables[query("VVar_Sender")]] && sizeof(id->variables[id->variables[query("VVar_Sender")]]))
    {
        sender=id->variables[id->variables[query("VVar_Sender")]];
        if((sender-"@"==sender) || (sender-"."==sender))
            return js_error(sender,query("VBadMail"));
    }
    mail->headers["from"] =sender;
    mail->headers["Reply-to"] =sender;
    mail->headers["subject"] = replace(query("VSubject"),({"%PAGE%"}),({id->variables[query("Vpage")]}));
    mail->headers["date"] = mailtime();
    mail->setencoding("8bit");


    mail->setdata(texte);
    object(Stdio.File) in=Stdio.File("stdout");
    object outo=in->pipe();
    Process.spawn(query("VSenderProg"),outo,0,outo);
    in->write((string)mail);
    in->close();

     return http_redirect( id->variables[query("VretURL")],id );
}

string simpletag_mailform( string tag, mapping m,string cont, object got)
{
	string username="";
	string pagename="";
        string retURL="";
        string order="";
        string sender="";
        string var_sender="";
	string tmp, out;

	foreach( indices(m), tmp )
	{
		switch(tmp)
		{
		case "user":
			username=m[tmp];
			break;
		case "return":
			retURL=m[tmp];
			break;
		case "required":
			order=m[tmp];
			break;
		case "sender":
			sender=m[tmp];
			break;
		case "sender-var":
			var_sender=m[tmp];
			break;
		}
	}


        pagename=got->conf->query("MyWorldLocation");
        sscanf(pagename,"http://%s/",pagename);
        pagename="http://"+pagename+got->not_query;
        if(m->help )
        {
            return help();
        }
	if(!sizeof(username) )
	{
            return "<h1>Error:</h1><h3>The field user is required.</h3><br><br>"+help();
	}

	if(!strlen(retURL))
	{
		retURL = got->not_query;
	}

	
	out =	"<FORM ACTION=" + query("mountpoint") +
		" METHOD=" + query("method") +">\n" +
		"<INPUT TYPE=HIDDEN NAME="+ query("Vuser") +
		" VALUE='" + username + "'>\n" ;
	
	if( sizeof(query("Vpage")) )
		out +=  "<INPUT TYPE=HIDDEN NAME="+ query("Vpage") +
			" VALUE='" + pagename + "'>\n";

	if( sizeof(query("VSender")) && sizeof(sender) )
		out +=  "<INPUT TYPE=HIDDEN NAME="+ query("VSender") +
			" VALUE='" + sender + "'>\n";

	if( sizeof(query("VVar_Sender")) && sizeof(var_sender) )
		out +=  "<INPUT TYPE=HIDDEN NAME="+ query("VVar_Sender") +
			" VALUE='" + var_sender + "'>\n";

	if( sizeof(query("Vorder")) )
		out +=  "<INPUT TYPE=HIDDEN NAME="+ query("Vorder") +
			" VALUE='" + order + "'>\n";

        if( sizeof(query("VretURL")) )
            out +=  "<INPUT TYPE=HIDDEN NAME="+ query("VretURL") +
			" VALUE='" + retURL + "'>\n";
	
	return(out+cont+"\n</FORM>\n");
}

string query_name()
{
	return(	"MAILFORM Tag" );
}
string info()
{
	return  help();
}

mapping query_container_callers()
{
  return ([ "mailform" : simpletag_mailform ]);
}
