;//
// This is a Roxen module.
//
// Written by Bill Welliver, <hww3@riverweb.com>
//
//
string cvs_version = "$Id$";
#include <module.h>
#include <process.h>
inherit "module";
inherit "roxenlib";

string mimewarning="This message is in MIME format.  The first part should be readable text,"
 "\n"
 "while the remaining parts are likely unreadable without MIME-aware tools.\n";
array register_module()
{
  return ({ MODULE_PARSER,
            "MailIt! 1.0  Module",
            "Adds the container 'mailit' for sending emails within Roxen.", ({}), 1
            });
}

int use_sendmail()
{
	return QUERY(usesmtp);
}

int use_smtp()
{
	return !QUERY(usesmtp);
}

void create()
{
  defvar("sendmail", "/usr/lib/sendmail", "Sendmail Binary", 
         TYPE_STRING,
         "This is the location of the sendmail binary.\n",0,use_sendmail);
 defvar("checkowner", 1, "Send mail from owner of template file",
	TYPE_FLAG,
         "If set, and Roxen is running as a sendmail trusted user,"
	 " MailIt! will send the mail as the owner of the template file.",0,use_sendmail);
 defvar("enableattach", 0, "Enable sending of attachments?",
	TYPE_FLAG,
	 "Enable sending of attachments? Enabling this feature has serious "
         "security implications. Do not enable this feature unless you "
         "are running the server as a non-priveledged user.");
 defvar("mailitdebug", 0, "Enable debugging",
	TYPE_FLAG,
         "If set, MailIt! will write debugging information to the error log."
	 );
#if constant(Protocols.SMTP)
 defvar("usesmtp",0,"Use SMTP", TYPE_FLAG,
        "Use SMTP with the Pike SMTP client library instead of the local sendmail");
 defvar("mailserver","mail","SMTP server",TYPE_STRING,
        "The SMTP server to use to send the mail",0,use_smtp);

 defvar("mailport",25,"SMTP port",TYPE_INT,
        "The SMTP port to use when using SMTP protocol",0,use_smtp);

 defvar("defaultrecepient","nobody@nobody.com","Default Recipient", TYPE_STRING,
        "The default recepient email address, if the user doesn't specify a recipient.",0,use_smtp);
 
 defvar("defaultsender","nobody@nobody.com","Default Sender", TYPE_STRING,
        "The default sender email address, if the user doesn't specify a sender"
        " address",0,use_smtp);

#endif	// constant(Protocols.SMTP)
}

string|void check_variable(string variable, mixed set_to)
{
        if (variable=="sendmail")
                {
		if(!file_stat(set_to))
		return "File doesn't exist!";
                }
}

string tag_header(string tag_name, mapping arguments,
		object request_id, object file, mapping defines)
  {

  string headtype;
  string headvalue;

  if (arguments->subject)
    {
    headtype="Subject";
    headvalue=arguments->subject;
    }
  else if (arguments->to)
    {
    headtype="to";
    headvalue=arguments->to;
    }
  else if (arguments->from)
    {
    headtype="from";
    headvalue=arguments->from;
    }
  else if(arguments->name && arguments->name!="")
    {
    headtype=arguments->name;
    headvalue=arguments->value||"";
    }
  else return "<!-- Skipping header tag because of incorrect usage. -->";
// perror("parsing header: "+headtype+" "+headvalue+"\n");

  if (headtype == "to" && stringp(request_id->misc->mailithdrs[headtype])) {
     array(string) tmp = ({ request_id->misc->mailithdrs[headtype], headvalue });
     request_id->misc->mailithdrs[headtype] = tmp;
  } else if (headtype == "to" && arrayp(request_id->misc->mailithdrs[headtype])) {
     request_id->misc->mailithdrs[headtype] += ({ headvalue });
  } else
     request_id->misc->mailithdrs+=([headtype:headvalue]);
  return "";

  }

string tag_mfield(string tag_name, mapping arguments,
		object request_id, object file, mapping defines)
	{
	string retval="";
	if(query("mailitdebug"))
		perror("MailIt!: Parsing mfield "+ arguments->name + "...\n");
	if(arguments->name)
		{
		if(request_id->variables[arguments->name] && (string)request_id->variables[arguments->name]!="")
			retval=request_id->variables[arguments->name];
		else if (arguments->empty)
			retval=arguments->empty;
		}
	if(arguments->add && (string)request_id->variables[arguments->name]!="")
		retval+=arguments->add;
	return html_encode_string(retval);
	}

string tag_attach(string tag_name, mapping arguments,
		object request_id, object file, mapping defines)
{
  if(query("enableattach")!=1) return "<!-- attachments are disabled by your server administrator -->";
  if(!arguments->file)
   return "";

  string content_type, file_name, descr="";
  mapping headers=([]);

  if(arguments->content_type) 
    content_type=arguments->content_type;
  else
    content_type=request_id->conf->type_from_filename(arguments->file);
  file_name=arguments->file;
  headers["content-type"]=content_type;
  headers["x-file-description"]=descr;   

  mixed file_contents=Stdio.read_file(file_name);

  if(!file_contents) return "";
  file_name=reverse(explode_path(file_name))[0];
  object a=MIME.Message(file_contents, headers);
  if (arguments->encoding)
    a->setencoding(arguments->encoding);
  else
    a->setencoding("base64");
  a->setdisp_param("filename", file_name);
  request_id->misc->mailitattachments+=({a});
  return "";
}

mixed container_message(string tag_name, mapping arguments,
			string contents, object request_id,
			mapping defines)
{

if (arguments->encoding)
request_id->misc->mailitencode=arguments->encoding;
else
request_id->misc->mailitencode="7bit";


request_id->misc->mailitbody=contents;
return "";

}

mixed container_mailit(string tag_name, mapping arguments,
			string contents, object request_id,
			mapping defines)
	{
	string retval="";
	mapping hdrs=([]);
	hdrs=  	  ([ "MIME-Version" : "1.0",
             "Content-Type" : "text/plain; charset="+(arguments->charset||"iso-8859-1"),
	     "X-Originating-IP" : request_id->remoteaddr,
             "X-HTTP-Referer" : (sizeof(request_id->referer||({}))?request_id->referer[0]:"None / Unknown"),
	     "X-Navigator-Client":(sizeof(request_id->client||({}))?request_id->client*" ":"None / Unknown"),
	     "X-Mailer" : "MailIt! for Roxen/Caudium" ]);

        request_id->misc->mailitattachments=({});
	request_id->misc->mailitencode="7bit";
	request_id->misc->mailithdrs=hdrs;
	request_id->misc->mailitbody="";

	contents=parse_rxml(contents, request_id);
	contents = parse_html(contents,([ "mailheader":tag_header,
			"mailattach":tag_attach ]),
                    (["mailmessage":container_message]), request_id ); 
	object mpmsg;

        if(sizeof(request_id->misc->mailitattachments)>0)
	{
	  
request_id->misc->mailitattachments=({MIME.Message(request_id->misc->mailitbody, (["Content-Type":request_id->misc->mailithdrs["Content-Type"]]))}) + 
request_id->misc->mailitattachments;
	  request_id->misc->mailithdrs["Content-Type"]="multipart/mixed";
		mpmsg=MIME.Message(mimewarning, 
		 request_id->misc->mailithdrs,request_id->misc->mailitattachments);
	  mpmsg->setencoding(request_id->misc->mailitencode);
	}
	else
	{
	  mpmsg=MIME.Message(request_id->misc->mailitbody,
		request_id->misc->mailithdrs);

	}
#if constant(Protocols.SMTP)
	if(query("usesmtp"))
        {
           array(string)  toa;
	   
	   if (arrayp(request_id->misc->mailithdrs->to))
	      toa = request_id->misc->mailithdrs->to;
	   else 
	      toa = ({ request_id->misc->mailithdrs->to || query("defaultrecipient") });
	   
Protocols.SMTP.client(query("mailserver"),query("mailport"))->send_message(request_id->misc->mailithdrs->from
|| query("defaultsender"), ({"grendel@vip.net.pl"}), (string)mpmsg);
        }
        else
        {
#endif
	array(mixed) f_user;
	if(query("checkowner")){
		array(int) file_uid=file_stat(request_id->realfile);
#if constant(getpwuid)
		f_user=getpwuid(file_uid[5]);
#else
		f_user="roxen";
#endif
		}

    object in=clone(Stdio.File, "stdout");
        object  out=in->pipe();
 
	if(query("mailitdebug")){
		if(query("checkowner"))
		perror("MailIt!: Sending mail from "+f_user[0]+"...\n");
		}
	if(query("checkowner")){
	  spawn(query("sendmail")+" -t -f "+f_user[0]+"",out,0,out);
	  }
	else {
	  spawn(query("sendmail")+" -t",out,0,out);
	  }
	retval=(string)mpmsg;
	in->write((string)mpmsg);
	in->close();
	m_delete(request_id->misc,"mailithdrs");		
	m_delete(request_id->misc,"mailitattachments");		
	m_delete(request_id->misc,"mailitbody");		
	#if constant(Protocols.SMTP)
        }
	#endif
	return contents;
	}


mapping query_tag_callers() { return (["mfield":tag_mfield,]); }

mapping query_container_callers() { return (["mailit":container_mailit, ]); }







