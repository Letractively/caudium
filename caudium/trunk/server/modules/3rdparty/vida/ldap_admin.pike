#include <module.h>

inherit "module";
inherit "caudiumlib";

// import Array;

constant cvs_version = "$Id$";

constant module_type = MODULE_LOCATION|MODULE_EXPERIMENTAL;
constant module_name = "User LDAP administration";
constant module_doc  = "With this module, your (or 'you' depending on what you want) user will be able to change some of their information. You will also be able to create a basic account and update their gid to if you have year related gid";
constant module_unique = 0;

// what to put ?
constant thread_safe=1;

// some defaults for mails
#define DEFAULT_BADMAILTOUSER \
 "\n  [ Ceci est un message automatique de réponse  ] \n" \
 "  [ à votre adhésion à l'Internet Team  ]\n" \
 "\nUn problème est apparu lors de la création de votre compte\n" \
 "sur l'Internet Team. Un email a été envoyé à $ADMIN\n" \
 "Nous nous efforcerons de régler ce problème dans les plus\n" \
 "bref délais\n" \
 "\n -- L'équipe d'Internet Team\n"
#define DEFAULT_BADMAILTOADMIN \
  "\nError:\n[\n$LAST_ERROR\n]\n" \
  "\nlogin= $LOGIN\n" \
  "uid= $UID\n" \
  "gid= $GID\n" \
  "prénom nom= $GECOS\n" \
  "date= $DATETIME\n"
#define DEFAULT_GOODMAILTOUSER \
  "\n  [ Ceci est un message automatique de réponse  ] \n" \
  "  [ à votre adhésion à l'Internet Team  ]\n" \
  "\nBienvenue sur l'Internet Team $LOGIN\n" \
  "Votre compte à été créé avec succès !\n" \
  "Pour toutes questions vous pouvez vous adressez à $ADMIN \n" \
  "Pour en savoir plus vous pouvez consulter le site http://www.iteam.org\n" \
  "Pour obtenir une aide immédiate vous pouvez aller sur IRC\n" \
  "irc.openprojects.net #iteam\n" \
  "\n -- L'équipe d'Internet Team\n"
#define DEFAULT_GOODMAILTOADMIN \
  "\nlogin= $LOGIN\n" \
  "uid= $UID\n" \
  "gid= $GID\n" \
  "prénom nom= $GECOS\n" \
  "date= $DATETIME\n"

// defaults for user interface
#define DEFAULT_FIRSTSCREEN \
  "<html>"\
  "<head><title>LDAP Administration</title>"\
  "<style=\"text/css\">"\
  "a:hover{"\
  "        color:#D6674F;"\
  "        text-decoration:none;"\
  "}"\
  "a:link{"\
  "        color:#404070;"\
  "        text-decoration:none;"\
  "}"\
  "a:visited{"\
  "        color:#404080;"\
  "        text-decoration:none;"\
  "}"\
  "</style>"\
  "</head>"\
  "<body bgcolor=\"white\">"\
  "<table width=\"100%\" cellspacing=\"20\">"\
  "<tr><th colspan=\"3\">Choose one of the action below</th></tr>"\
  "<tr><td>"\
  "<a href=\"$MOUNTPOINT/modify\">Modify</a></td>"\
  "<td><a href=\"$MOUNTPOINT/add\">Add</a></td>"\
  "<td><a href=\"$MOUNTPOINT/update\">Update</a></td>"\
  "</tr></table></body></html>"
#define DEFAULT_MODIFY_INPUTS \
  "<html>"\
  "<head>"\
  "<title>LDAP Administration - Change information</title>"\
  "<style type=\"text/css\">"\
  "a:hover{"\
  "        color:#D6674F;"\
  "        text-decoration:none;"\
  "}"\
  "a:link{ "\
  "        color:#404070;"\
  "        text-decoration:none;"\
  "}   "\
  "a:visited{"\
  "        color:#404080;"\
  "        text-decoration:none;"\
  "}"\
  "</style>"\
  "</head>  "\
  "<body bgcolor=\"white\">"\
  "<form action=\"$MOUNTPOINT/applymodify\" method=\"POST\">"\
  "<center>"\
  "<p>"\
  "Below you can change some of your information"\
  "</p>"\
  "<table cellspacing=\"10\" border=\"10\" cellpadding=\"10\">"\
  "<tr><td>login</td><td>$LOGIN</td></tr>"\
  "<tr><td>gecos</td><td>$GECOS</td></tr>"\
  "<tr><td>password</td><td>$PASSWORD</td></tr>"\
  "<tr><td>verify password</td><td>$PASSWORD2</td></tr>"\
  "<tr><td>&nbsp;</td><td>"\
  "<input type=\"submit\" value=\"modify\">"\
  "<comment>You can use gbutton if you have loaded the gbutton module"\
  "<input type=\"image\" src=\"<gbutton-url font='lucida sans unicode'>Modify</gbutton-url>\" value=\"modify\">"\
  "</comment>"\
  "</td>"\
  "</tr>"\
  "</table>"\
  "</form>"\
  "<comment>"\
  "<p align=\"center\">maildrop is the mail address that will appear when you"\
  "send.</p>"\
  "<p align=\"center\">"\
  "Mailacceptinggeneralid is the mail(s) address(es) that this account will"\
  "accept. If it contains email addresses to over domains, these will be   "\
  "automatiquelly redirected (like in the old .forward mecanism). You can put"\
  "several mails seperated by commas.</p>"\
  "</comment>"\
  "</body></html>"
#define DEFAULT_MODIFY_ERROR \
  "<html>"\
  "<head>"\
  "<title>LDAP Administration - Error</title>"\
  "</head>"\
  "<body>"\
  "<center>"\
  "<p>"\
  "<font color=\"red\"><pre><strong>$LASTERROR</pre></strong></font>"\
  "</p>"\
  "</center>"\
  "<center>"\
  "<a href=\"$MOUNTPOINT\">return to main menu</a>"\
  "</center>"\
  "</body>"\
  "</html>"
#define DEFAULT_MODIFY \
  "<html><title>LDAP Administration - modification successful</title>"\
  "<style type=\"text/css\">"\
  "a:hover{"\
  "        color:#D6674F;"\
  "        text-decoration:none;"\
  "}"\
  "a:link{"\
  "        color:#404070;"\
  "        text-decoration:none;"\
  "}"\
  "a:visited{"\
  "        color:#404080;"\
  "        text-decoration:none;"\
  "}"\
  "</style>"\
  "</head>"\
  "<body>"\
  "<center>"\
  "<p>Your account has been successfully updated.</p></center>"\
  "<center>"\
  "<a href=\"$MOUNTPOINT\">Return to main menu</a>"\
  "</center>"\
  "</body></html>"
#define DEFAULT_UPDATE_INPUT \
  "<html>"\
  "<head>"\
  "<title>LDAP Administration - Update an account</title>"\
  "<style type=\"text/css\">"\
  "a:hover{"\
  "        color:#D6674F;"\
  "        text-decoration:none;"\
  "}"\
  "a:link{"\
  "        color:#404070;"\
  "        text-decoration:none;"\
  "}"\
  "a:visited{"\
  "        color:#404080;"\
  "        text-decoration:none;"\
  "}"\
  "</style>"\
  "</head>"\
  "<body bgcolor=\"white\">"\
  "<form action=\"$MOUNTPOINT/applyupdate\" method=\"POST\">"\
  "<center>"\
  "<p>"\
  "Here you can change group"\
  "</p>"\
  "<table cellspacing=\"10\" border=\"10\" cellpadding=\"10\">"\
  "<tr><th colspan=\"2\">Datas on this account</th></tr>"\
  "<tr><td>login</td><td>$LOGIN</td></tr>"\
  "<tr><td>gecos</td><td>$GECOS</td></tr>"\
  "<tr><td>uid</td><td>$UIDNUMBER</td></tr>"\
  "</tr><td>gid</td><td>$GIDNUMBER</td></tr>"\
  "<tr><td>&nbsp;</td>"\
  "<td>"\
  "<form action=\"$MOUNTPOINT/applyupdate\" method=\"POST\">"\
  "<input type=\"submit\" value=\"update\">"\
  "<comment>"\
  "<input type=\"image\" src=\"<gbutton-url font='lucida sans unicode'>Update</gbutton-url>\" value=\"modify\">"\
  "</comment>"\
  "</form>"\
  "</td></tr>"\
  "</table>"\
  "</body>"\
  "</html>"
#define DEFAULT_ADD_ERROR \
   "<html>" \
   "<head>" \
   "<title>LDAP Administration - Error</title>" \
   "</head>" \
   "<body bgcolor=\"white\">" \
   "<center>" \
   "<p>" \
   "<font color=\"red\"><pre><strong>$LASTERROR</pre></strong></font>" \
   "</p>" \
   "</center>" \
   "<center>" \
   "<a href=\"$MOUNTPOINT\">return to main menu</a>" \
   "</center>" \
   "</body>" \
   "</html>" 
#define DEFAULT_ADD \
   "<html><title>LDAP Administration - adding successful</title>"\
   "<style type=\"text/css\">"\
   "a:hover{"\
   "        color:#D6674F;"\
   "        text-decoration:none;"\
   "}"\
   "a:link{"\
   "        color:#404070;"\
   "        text-decoration:none;"\
   "}"\
   "a:visited{"\
   "        color:#404080;"\
   "        text-decoration:none;"\
   "}"\
   "</style>"\
   "</head>"\
   "<body bgcolor=\"white\">"\
   "<center>"\
   "<p>Your account has been successfully created.</p></center>"\
   "<center>"\
   "<a href=\"$MOUNTPOINT\">Return to main menu</a>"\
   "</center>"\
   "</body></html>"

#define DEFAULT_ADD_INPUTS \
   "<html>" \
   "<head>" \
   "<title>LDAP Administration - Add a user</title>"\
   "<style type=\"text/css\">"\
   "a:hover{"\
   "     color:#D6674F;"\
   "     text-decoration:none;"\
   "}"\
   "a:link{"\
   "     color:#404070;"\
   "     text-decoration:none;"\
   "}"\
   "a:visited{"\
   "     color:#404080;"\
   "     text-decoration:none;"\
   "}"\
   "</style>"\
   "</head>"\
   "<body bgcolor=\"white\">"\
   "<form action=\"$MOUNTPOINT/applyadd\" method=\"POST\">"\
   "<center>"\
   "<p>"\
   "Below you can add a user"\
   "</p>"\
   "<table cellspacing=\"10\" border=\"10\" cellpadding=\"10\">"\
   "<tr><td>Login</td><td><input type=\"text\" name=\"login\"></td></tr>"\
   "<tr><td>Password</td><td><input name=\"password\" type=\"password\"></td></tr>"\
   "<tr><td>Verify password</td><td><input name=\"password2\" type=\"password\"></td></tr>"\
   "<tr><td>Firstname lastname</td><td><input type=\"text\" name=\"gecos\"></td></tr>"\
   "<tr><td>&nbsp;</td><td><input type=\"submit\"></td>"\
   "</tr>"\
   "</table>"\
   "</form>"\
   "</body>"\
   "</html>"
   
//functions to hide defvar when not used
int hide_mail()
{
  if(QUERY(mail) == 0)
    return 1;
  return 0;
}

int hide_update()
{
  if(QUERY(allowupdate) == 0)
    return 1;
  return 0;
}

void create()
{
  defvar("location", "/iteam", "Mount Point", TYPE_LOCATION,
  "The mountpoint of this module");
  defvar("hostname", "ldap://localhost", "LDAP: LDAP server location", 
	 TYPE_STRING, "Specifies the default LDAP directory server hostname."
	              "Format is ldap url style eg ldap://hostname[:port]/.\n");
  defvar("ldapver", 3, "LDAP: LDAP server version", TYPE_INT_LIST,
         "The LDAP protocol version to use with this server.", ({ 2, 3 }));
  defvar("basedn", "", "LDAP: LDAP base DN",
	 TYPE_STRING,
	 "Specifies the distinguished name to use as a base for queries.\n");
  defvar("binddn", "", "LDAP: LDAP bind DN",
	 TYPE_STRING,
	 "Specifies the default binddn to use for access.\n");
  defvar("password", "", "LDAP: password",
 
	 TYPE_STRING,
	 "Specifies the default password to use for access.\n");
  defvar("gidnumber", 100, "Add: gidnumber for new accounts",
  	 TYPE_INT,
	 "Specify the default gidnumber when new account is created\n");
  defvar("default_uid", 100, "Add: uid if no uidNumber found",
  	 TYPE_INT,
	 "uidNumber should only happen if you don't have previously users in LDAP. Never put this to something < 1.\n");
  defvar("addlastslash", 0, "Add: add a slash to the home directory",
  	 TYPE_FLAG,
	 "It can be useful to add a '/' to home directory for example to tell your MTA you have a Maildir box format");
  defvar("defaultdomain", "localdomain", "Add: the domain to use in maildrop and mailacceptinggeneralid attributes",
  	 TYPE_STRING);
  defvar("addrequireauth", ({ "admin" }), "Add: require authentification",
  	 TYPE_STRING_LIST,
	 "Contains the user allowed to add other users. If empty everybody can add users");
  defvar("updaterequireauth", ({ "admin" }), "Update: require authentification",
  	 TYPE_STRING_LIST,
	 "Contains the user allowed to update other users. If empty anybody can update users (provided you allow them in features ->  allow the user to update his account). gid of the user listed in this field don't need to be in Update -> gid numbers allow to update. ");
  defvar("defvaruidnumber", "uidNumber", "LDAP: Attribute - uidnumber attribute",
  	 TYPE_STRING,
	 "Specify the name of the uidnumber attribute in LDAP.");
  defvar("defvargidnumber", "gidNumber", "LDAP: Attribute - gidnumber attribute",
  	 TYPE_STRING,
	 "Specify the name of the gidnumber attribute in LDAP.");
  defvar("defvaruid", "uid", "LDAP: Attribute - uid attribute",
  	 TYPE_STRING,
	 "Name of the uid attribute");
  defvar("defvarhomedirectory", "homeDirectory", "LDAP: Attribute - homedirectory",
  	 TYPE_STRING,
	 "Name of the homedirectory attribute");
  defvar("defvargecos", "gecos", "LDAP: Attribute - gecos",
  	 TYPE_STRING,
	 "Name of the gecos attribute");
  defvar("defvaruserpassword", "userPassword", "LDAP: Attribute - userpassword",
  	 TYPE_STRING,
	 "Name of the userpassword attribute");
  defvar("defvarcn", "cn", "LDAP: Attribute - cn",
  	 TYPE_STRING, "If empty it will not be use");
  defvar("defvarmaildrop", "", "LDAP: Attribute - maildrop",
  	 TYPE_STRING,
	 "This attribute contains the mail address that will appear when you send (for Postfix at least). If empty it will not be use (either in add or modify)");
  defvar("defvarmailacceptinggeneralid", "", "LDAP: Attribute - mailacceptinggeneralid",
  	 TYPE_STRING,
	 "This attribute contains the mail(s) address(es) that will be redirected to your mailbox (for Postfix at least). If empty it will not be use");
  defvar("defvarloginshell", "loginShell", "LDAP: Attribute - loginShell",
  	 TYPE_STRING, "If empty it will not be use");
  defvar("defaultshell", "/bin/bash", "Add: Default shell",
  	 TYPE_STRING,
	 "The default shell for new accounts");
  defvar("defvarobjectclass", "objectClass", "LDAP: Attribute - objectClass",
  	 TYPE_STRING);
  defvar("defaultobjectclass", ({ "top", "shadowAccount", "posixAccount" }), "LDAP: Attribute - default object class",
  	 TYPE_STRING_LIST);
  defvar("homedir", "/home/", "Add: Base homedir used when creating new account",
  	 TYPE_STRING,
	 "The last / is mandatory");
  defvar("mail", 1, "Features: Send mail to the administrator(s)", 
  	 TYPE_FLAG,
	 "There are four case where email will be send:<ol>"
	 "<li>Account has been created successfully: email is sent to the administrator(s) and to the user"
	 "<li>Account has not been created successfully: email is sent to the administrator(s)"
	 "<li>Account has been upgrade successfully: email is sent to the administrator(s) and to the user"
	 "<li>An error occured during the upgrade: an email is sent to the administrator(s) and to the user</ol>\n");
  defvar("allowupdate", 1, "Features: allow the user to update his account",
  	 TYPE_FLAG,
	 "If set to yes, the users will be able to "
	 "change to the last group you define<br>\n"
	 "This feature is useful for example if you have one year accounts"
	 " and you want to update some accounts from one year to another");
  defvar("currentgidnumber", 110, "Update: Current gidnumber",
  	 TYPE_INT,
	 "This is the latest gid you have. If the gid of users is not this "
	 "number, they may update", 0, hide_update);
  defvar("allowedgidupdates", ({ }) , "Update: gid numbers allowed to update",
  	 TYPE_INT_LIST,
	 "This is the list of gid numbers that can update to the current gid number. Leave empty or put 0 to allow every users to update.");
  defvar("allowedmodifyattribute", ({ "userPassword" }), "Modify: Allowed attributes",
  	 TYPE_STRING_LIST,
	 "This is the list of the attribute the user can modify");
  defvar("maildomain","localdomain", "Mail: Domain",
  	 TYPE_STRING,
	 "The domain that will be used for sending mail\n",
	 0, hide_mail);
  defvar("mailadmin", "hostmaster" ,"Mail: email of the administrator(s)",
  	 TYPE_STRING,
	 "Specifing an alias can be useful to contact several people.\n",
	 0, hide_mail);
  defvar("mailserver", "mail", "Mail: Address of your mail server",
  	 TYPE_STRING,
	 "For now this field is mandatory.\n",
	 0, hide_mail);
  defvar("badmailtouser", DEFAULT_BADMAILTOUSER, 
  	"Mail: Body of the message the user will receive if an error occured",
  	 TYPE_TEXT_FIELD,
	 "You can use some replacements:<ul>"
	 "<li>$LOGIN: login if the user</li>"
	 "<li>$UID: uid of the user</li>"
	 "<li>$GID: gid of the user</li>"
	 "<li>$GECOS: gecos (user's name) of the user</li>"
	 "<li>$DATETIME: current date and time</li>"
	 "<li>$ADMIN: email of the administrator</li>"
	 "<li>$LAST_ERROR: backtrace</li></ul>",
	 0, hide_mail);
  defvar("badmailtoadmin", DEFAULT_BADMAILTOADMIN, 
  	"Mail: Body of the message the administrator(s) will receive if an error occured",
  	 TYPE_TEXT_FIELD,
	 "You can use some replacements:<ul>"
	 "<li>$LOGIN: login if the use</li>"
	 "<li>$UID: uid of the user</li>"
	 "<li>$GID: gid of the user</li>"
	 "<li>$GECOS: gecos (user's name) of the user</li>"
	 "<li>$DATETIME: current date and time</li>"
	 "<li>$ADMIN: email of the administrator</li>"
	 "<li>$LAST_ERROR: backtrace</li></ul>",
	 0, hide_mail);
  defvar("goodmailtouser", DEFAULT_GOODMAILTOUSER, 
  	"Mail: Body of the message the user will receive if no errors occured",
  	 TYPE_TEXT_FIELD,
	 "You can use some replacements:<ul>"
	 "<li>$LOGIN: login if the user</li>"
	 "<li>$UID: uid of the user</li>"
	 "<li>$GID: gid of the user</li>"
	 "<li>$GECOS: gecos (user's name) of the user</li>"
	 "<li>$DATETIME: current date and time</li>"
	 "<li>$ADMIN: email of the administrator</li></ul>",
	 0, hide_mail);
  defvar("goodmailtoadmin", DEFAULT_GOODMAILTOADMIN, 
  	"Mail: Body of the message the admin will receive if no errors occured",
  	 TYPE_TEXT_FIELD,
	 "You can use some replacements:<ul>"
	 "<li>$LOGIN: login if the user</li>"
	 "<li>$UID: uid of the user</li>"
	 "<li>$GID: gid of the user</li>"
	 "<li>$GECOS: gecos (user's name) of the user</li>"
	 "<li>$DATETIME: current date and time</li>"
	 "<li>$ADMIN: email of the administrator</li></ul>",
	 0, hide_mail);
  defvar("ui_firstscreen", DEFAULT_FIRSTSCREEN,
  	 "User interface: First screen",
	 TYPE_TEXT,
	 "$MOUNTPOINT will be replaced by the mountpoint of this module");
  defvar("ui_modify", DEFAULT_MODIFY,
	 "User interface: Modify/Update - page that will be display after the user has modified his datas",
	 TYPE_TEXT,
	 "$MOUNTPOINT will be replace by the path of this module");
  defvar("ui_modify_error", DEFAULT_MODIFY_ERROR,
	 "User interface: Modify/Update - page that will be displayed when an error occured",
	 TYPE_TEXT,
	 "$LAST_ERROR will be replace by the backtrace<br>"
	 "$MOUNTPOINT will be replace by the path of this module");
  defvar("ui_modify_inputs", DEFAULT_MODIFY_INPUTS,
	 "User interface: Modify - form input",
	 TYPE_TEXT,
  	 "The following replacements are available:<ul>"
	 "<li><b>$MOUNTPOINT</b>: path to the mountpoint of this module (for use in form action=)</li>"
	 "<li><b>$LOGIN</b>: text for the login</li>"
	 "<li><b>$GECOS</b>: text or input for the gecos</li>"
	 "<li><b>$PASSWORD</b>: first text or input for the password</li>"
	 "<li><b>$PASSWORD2</b>: second text or input for the password (verify)</li>"
	 "<li><b>$MAILDROP</b>: text or input for maildrop</li>"
	 "<li><b>$MAILACCEPTINGGENERALID</b>: text or input for mailacceptinggeneralid</li></ul><br>"
	 "inputs will be available only if you list the corresponding attribute in <i>Modify -> allowed attributes</i><br>"
	 "for maildrop and mailacceptinggeneralid, text or input will appear only if they are in <i>LDAP -> Attribute - name of the attribute</i> ");
  defvar("ui_update_input", DEFAULT_UPDATE_INPUT,
	 "User interface: Update - form input",
	 TYPE_TEXT,
	 "This is the code for the update form. There will be an error message if the user is not in the group you choose in update -> gid allowed to updates.<br>The following replacements are available:<ul>"
	 "<li><b>$LOGIN</b>: login name</li>"
	 "<li><b>$MOUNTPOINT</b>: path to the mountpoint of this module (for use in form action=)</li>"
	 "<li><b>$GECOS</b>: gecos of the account</li>"
	 "<li><b>$UIDNUMBER</b>: uid</li>"
	 "<li><b>$GIDNUMBER</b>: gid</li></ul>", 0, hide_update);
  defvar("ui_add_error", DEFAULT_ADD_ERROR,
  	 "User interface: Add - page that will appear if an error occured after the user/admin add a user",
	 TYPE_TEXT,
	 "$LAST_ERROR will be replace by the backtrace<br>"
	 "$MOUNTPOINT will be replace by the path of this module");
  defvar("ui_add", DEFAULT_ADD,
  	 "User interface: Add - page that will be display after the user has been successfully added into LDAP",
	 TYPE_TEXT,
	 "$MOUNTPOINT will be replace by the path of this module");
  defvar("ui_add_inputs", DEFAULT_ADD_INPUTS, "User interface: Add - form input",
  	 TYPE_TEXT,
	 "<ul><li>$MOUNTPOINT: mountpoint of the current module</li></ul>");
  defvar("regexp_uid", "[0-9a-zA-Z]", "Regexp: Uid",
  	 TYPE_STRING,
	 "If uid don't match this, it will be reject. Leave empty to disable the check (not recommanded)");
  defvar("error_regexp_uid", "Invalid login", "Regexp: Uid - error string",
  	 TYPE_STRING,
	 "The string to display when the uid don't match the regexp");
  defvar("regexp_gecos", "[0-9 a-zA-Z\\-]", "Regexp: Gecos",
  	 TYPE_STRING,
	 "If gecos don't match this, it will be reject. Leave empty to disable the check (not recommanded)");
  defvar("error_regexp_gecos", "Invalid user name", "Regexp: Gecos - error string",
  	 TYPE_STRING,
	  "The string to display when the gecos don't match the regexp");
  defvar("regexp_passwd", "[0-9]|[^a-zA-Z]", "Regexp: Password",
  	 TYPE_STRING,
	 "If user password don't match this, it will be reject. Leave empty to disable the check (not recommanded)");
  defvar("error_regexp_passwd", "Password should be at least 6 characters\nIt should both numeric and alphebitacal characters\n", "Regexp: Password - error string",
  	 TYPE_STRING,
	 "The string to display when the password don't match the regexp"); 
  defvar("regexp_mail", "[a-zA-Z.\-0-9]+@[a-zA-Z.\-0-9]+", "Regexp: Mail",
  	 TYPE_STRING,
	 "If a mail address don't match this, it will be reject. Leave empty to disable the check (not recommanded)");
  defvar("error_regexp_mail", "Invalid email address", "Regexp: Mail - error string",
  	 TYPE_STRING,
	 "The string to display when the mail don't match the regexp");
  defvar("debug", 0, "Enable debugging",
  	 TYPE_FLAG,
	 "If set to yes, mails and LDAP attribute will be write to caudium log file.\nTake care as userPassword will be also write to caudium log file.\n");
  defvar("allowed_domains", ({ "" }), "DNS: Allowed domains", TYPE_STRING_LIST,
  "The domains allowed to access the module. Leave empty to disable this feature.");
}

// Generic functions (used by add and modify)

array(string) checkuid(array(string) errors, string argv)
{
  if(strlen(argv) == 0 || (sizeof(QUERY(regexp_uid)) > 0 ? !Regexp(QUERY(regexp_uid))->match(argv): 0))
  {
    errors[0] += QUERY(error_regexp_uid);
    errors[1] = 1;
  }
  return errors;
}

array(string) checkgecos(array(string) errors, string argv)
{
  if(strlen(argv) == 0 || (sizeof(QUERY(regexp_gecos)) > 0 ? !Regexp(QUERY(regexp_gecos))->match(argv): 0))
  {
    errors[0] += QUERY(error_regexp_gecos);
    errors[1] = 1;
  }
  return errors;
}

array(string) checkpasswd(array(string) errors, string argv, string argv2)
{
  if(strlen(argv) == 0 || strlen(argv2) == 0)
  {
    errors[0] += "Empy password not allowed here\n";
    errors[1] = 1;
  }
  else
  {
    if(argv != argv2)
    {
      errors[0] += "Passwords differs\n";
      errors[1] =1;
    }
    if(strlen(argv) <= 6 || (sizeof(QUERY(regexp_passwd)) > 0 ? !Regexp(QUERY(regexp_passwd))->match(argv): 0))
    {
      errors[0] += QUERY(error_regexp_passwd);
      errors[1] = 1;
    }
  }
  return errors;
}

array(string) checkmail(array(string) errors, string argv)
{
  if(strlen(argv) == 0 || (sizeof(QUERY(regexp_mail)) > 0 ? !Regexp(QUERY(regexp_mail))->match(argv): 0))
  {
    errors[0] += QUERY(error_regexp_mail);
    errors[1] = 1;
  }
}

int checkinput(mapping(string:string) argv)
{
  array errors = ({ "", 0 });
  checkuid(errors, argv["uid"]);
  checkgecos(errors, argv["gecos"]);
  checkpasswd(errors, argv["passwd"], argv["passwd2"]);
  // Raising an exception
  if(errors[1])
    throw( ({ errors[0] }) );
  return errors[1];
}

void|string getlastuid(object con, string gidnumber)
{
  object res;
  mapping oneres;
  array uids = ({});
  string uidNumber;
  // search for the last uidNumber in given gidnumber
  res = con->search("(" + QUERY(defvargidnumber) + "=" + gidnumber + ")");
  // retrieve only the attribute uidNumber
  if(!objectp(res) || !res->num_entries())
    return (string) QUERY(default_uid);
  do
  {
    oneres = res->fetch();
    uids += ({ oneres[QUERY(defvaruidnumber)] });
  }
  while (res->next());
  // sort by uidNumber
  uids = sort(uids);
  // finally retrieve the last one + 1 and put it in a int
  foreach(uids[sizeof(uids) - 1], uidNumber)
    uidNumber = (string) ((int) uidNumber + 1);
  if((int)uidNumber <= 0)
    throw( ({ "Error getting last uidNumber", backtrace() }) );
  return uidNumber;
}

int isloginexist(object con, string uid)
{
  object res;
  res = con->search("(" + QUERY(defvaruid) + "=" + uid + ")");
  if(objectp(res) && res->num_entries())
    return 1;
  return 0;
}

void simple_mail(string to, string subject, string from, string msg)
{
if(QUERY(mail))
{
  if(QUERY(debug))
    write(sprintf("mail=%s\n", msg));
}
else
{
#if constant(Protocols.ESMP)
  Protocols.ESMP.client(QUERY(mailserver), 25, QUERY(maildomain))->send_message(from, ({ to }),
              (string)MIME.Message(msg, (["mime-version":"1.0",
                                          "subject":subject,
                                          "from":from,
                                          "to":to,
                                          "content-type": "text/plain;charset=iso-8859-1",
                                          "content-transfer-encoding":
                                          "8bit"])));
#else
//Protocols.SMTP.client(QUERY(mailserver), 25, QUERY(maildomain))->send_message(from, ({ to })
  Protocols.SMTP.client(QUERY(mailserver), 25)->send_message(from, ({ to }),
                (string)MIME.Message(msg, (["mime-version":"1.0",
		                            "subject":subject,
					    "from":from,
					    "to":to,
					    "content-type": "text/plain;charset=iso-8859-1",
					    "content-transfer-encoding":
					    "8bit"])));
#endif
  }
}

void sendmails(mapping (string:string) defines)
{
  mapping localtime = localtime(time());
  string localmailadmin = QUERY(mailadmin);
  string date = localtime["hour"] + ":" + localtime["min"] + ":" + localtime["sec"] + " " + localtime["mday"] + "/" + localtime["mon"] + "/" + (localtime["year"] + 1900);
  // first mail the admin
  array mail_from = ({ "$LOGIN", "$UID", "$GID", "$GECOS", "$DATETIME", "$ADMIN" }); 
  array mail_to = ({ defines["uid"][0], defines["uidNumber"][0], defines["gidNumber"][0], defines["gecos"][0], date, localmailadmin });
  string msg = replace(QUERY(goodmailtoadmin), mail_from, mail_to);
  simple_mail(localmailadmin, "Nouveau membre", localmailadmin, msg);
  // next mail the user (this will also create his mail account)
  msg = replace(QUERY(goodmailtouser), mail_from, mail_to);
  simple_mail(defines["uid"][0] + "@" + QUERY(maildomain) , "[ ITEAM ] Welcome on board", localmailadmin, msg);
}

void sendbadmails(mapping defines, string last_error)
{
  mapping localtime = localtime(time());
  string localmailadmin = QUERY(mailadmin);
  string date = localtime["hour"] + ":" + localtime["min"] + ":" + localtime["sec"] + " " + localtime["mday"] + "/" + localtime["mon"] + "/" + (localtime["year"] + 1900);
  // first mail the admin
  array mail_from = ({ "$LOGIN", "$UID", "$GID", "$GECOS", "$DATETIME", "$ADMIN", "$LAST_ERROR" }); 
  array mail_to;
  // Avoid errors over error
  if(mappingp(defines) && arrayp(defines["uid"]) && stringp(defines["uid"][0]))
    mail_to = ({ defines["uid"][0] });
  else 
    mail_to = ({ "don't know" });
  if(mappingp(defines) && arrayp(defines["uidNumber"]) && stringp(defines["uidNumber"][0]))
    mail_to += ({ defines["uidNumber"][0] });
  else
    mail_to += ({ "don't know" }); 
  if(mappingp(defines) && arrayp(defines["gidNumber"]) && stringp(defines["gidNumber"][0]))
    mail_to += ({ defines["gidNumber"][0] });
  else
    mail_to += ({ "don't know" }); 
  if(mappingp(defines) && arrayp(defines["gecos"]) && stringp(defines["gecos"][0]))
    mail_to += ({ defines["gecos"][0] });
  else
    mail_to += ({ "don't know" }); 
  mail_to += ({ date, localmailadmin, last_error });
  string msg = replace(QUERY(badmailtouser), mail_from, mail_to);
  if(mappingp(defines) && arrayp(defines["uid"]) && stringp(defines["uid"][0]))
    simple_mail(defines["uid"][0] + "@" + QUERY(maildomain), "[ ITEAM] Erreur dans votre inscription", localmailadmin, msg);
  msg = replace(QUERY(badmailtoadmin), mail_from, mail_to);
  simple_mail(QUERY(mailadmin), "Problème(s) lors de la création d'un compte", localmailadmin, msg);
}

int checkdns(string remoteaddr)
{
  if(sizeof((QUERY(allowed_domains) - ({ "" }))) > 0)
  {
    array clientdns = Protocols.DNS.client()->gethostbyaddr(remoteaddr);
    string domain;
    foreach(((QUERY(allowed_domains) - ({ "" }))), domain)
    {
      if(stringp(clientdns[0]))
      {
        string clientdns1, clientdns2;
        sscanf(clientdns[0], "%s.%s", clientdns1, clientdns2);
        if(lower_case(clientdns2) == lower_case(domain))
          return 1;
      }
      else  
        return 0;
    }
    return 0;
  }
  return 1;
}

mapping first_screen(object id)
{
  array from = ({ "$MOUNTPOINT" });
  array to = ({ QUERY(location) });
  return http_rxml_answer(replace(QUERY(ui_firstscreen), from, to), id);
}

// check the more things we can check
void checkresult(object con, mapping from, string uid)
{
  mapping to = getfullinformation(con, uid);
  array indic = indices(from);
  string indice;
  for(int i = 0; i < sizeof(from); i++)
  {
    indice = indic[i];
    from[indice] = sort(from[indice]);
  }
  for(int i = 0; i < sizeof(to); i++)
  {
    indice = indic[i];
    to[indice] = sort(to[indice]);
  }
  if(!equal(from, to))
    throw ( ({ "Due to an unknown error, you were not added to our account database. Check /var/log/auth.log(error code in decimal value) and $OPENLDAP_SRC_DIR/include/ldap.h(meaning of the error and error code in hexa) [ provided you use openldap and configured /etc/syslog.conf ] for more information", backtrace() }) );
}

int user_auth(object id)
{
  if(id->auth && id->auth[0])
    return 1;
  else 
    return 0;
}

mapping getfullinformation(object con, string uid)
{
  object res;
  mapping defines;
  res = con->search("(" + QUERY(defvaruid) + "=" + uid + ")");
  if(!objectp(res) || !res->num_entries())
    throw ( ({ "Unable to search in LDAP or problems in uid", backtrace() }) );
  defines = res->fetch();
  return m_delete(defines, "dn");
}

// End generic functions

// functions used only by add
void insertinldap(object con, mapping(string:array(string)) defines, string basedn)
{
  mapping(string:array(string)) attrval;
  if((int) defines["uidNumber"][0] < 1)
    throw( ({ "Invalid uidnumber(" + defines["uidnumber"][0] + ")", backtrace() }) );
  defines["passwd"] = ({ "{crypt}" + crypt(defines["passwd"][0]) });
  // paye = ({ "0" })
  attrval = ([ QUERY(defvaruidnumber): defines["uidNumber"] , QUERY(defvargidnumber): defines["gidNumber"] , QUERY(defvaruid): defines["uid"] , QUERY(defvargecos): defines["gecos"], QUERY(defvaruserpassword): ({ "" + defines["passwd"][0] + "" }), QUERY(defvarhomedirectory): defines["homedirectory"], QUERY(defvarobjectclass): QUERY(defaultobjectclass) ]);
 if(sizeof(QUERY(defvarcn)) > 0)
   attrval += ([ QUERY(defvarcn): defines["gecos"] ]);
 if(sizeof(QUERY(defvarloginshell)) > 0)
   attrval += ([ QUERY(defvarloginshell): ({ QUERY(defaultshell) }) ]);
 if(sizeof(QUERY(defvarmaildrop)) > 0)
   attrval += ([ QUERY(defvarmaildrop): ({ defines["uid"][0] + "@" + QUERY(defaultdomain) }) ]);
 if(sizeof(QUERY(defvarmailacceptinggeneralid)) > 0)
   attrval += ([ QUERY(defvarmailacceptinggeneralid): ({ defines["uid"][0] + "@" + QUERY(defaultdomain) }) ]);

 // now add the entry
 if(QUERY(debug))
   write(sprintf("attrs=%O\n", attrval));
 con->add(QUERY(defvaruid) + "=" + defines["uid"][0] + ", " + basedn, attrval);
 checkresult(con, attrval, attrval["uid"][0]);

}

void updatesystem(mapping defines)
{
  if(!mkdir(defines["homedirectory"][0]))
  // Raising an exception and giving a backtrace for debugging
    throw(({ "Can't create homedirectory: " + defines["homedirectory"][0] , backtrace() }));
  chown(defines["homedirectory"][0], (int) defines["uidNumber"][0], (int) defines["gidNumber"][0]);
}

string showaddinputs(object id, mapping defines)
{
  string inputs;
  array inputs_from = ({ "$MOUNTPOINT" });
  array inputs_to = ({ QUERY(location) });
  inputs = replace(QUERY(ui_add_inputs), inputs_from, inputs_to);
  return inputs;
}

mapping add(object id, int applyadd)
{
  string host = QUERY(hostname);
  string password = QUERY(password);
  string basedn = QUERY(basedn);
  string binddn = QUERY(binddn);
  string gidnumber = (string) QUERY(gidnumber);
  int proto = QUERY(ldapver);
  mapping defines;
  // for error handling
  string last_error;
  mixed error = 1;
  // fill in default values in defines for sendbadmails in case of error
  defines = ([ "uid": ({ "none" }), "uidNumber": ({ "-1" }), "gidNumber": ({ "-1" }), "gecos": ({ "none" }) ]);
  // object for LDAP connection
  object con = 0;
  
    error = catch {
    if(strlen(QUERY(addrequireauth)[0]) > 0)
    {
      if(!id->conf->auth_module)
        throw ( ({ "This module require the caudium LDAP authentification module"  }) );
      if( !user_auth(id) )
        return http_auth_required("add member user", "Wrong login/password ");
      if(search(QUERY(addrequireauth), id->auth[1]) == -1)
        return http_auth_required("add member user", "Wrong login/password");
    }
    if(!applyadd)
    {
      // only show form inputs
      return http_rxml_answer(showaddinputs(id, defines), id);
    }
    string homedirectory = QUERY(homedir) + id->variables->login;
    if(QUERY(addlastslash))
      homedirectory += "/";
    string uid = id->variables->login;
    string gecos = id->variables->gecos;
    defines = ([ "homedirectory": ({ homedirectory }), "uid": ({ uid }), "gecos": ({ gecos }) ]);
    string passwd = id->variables->password, passwd2 = id->variables->password2;
    
    // for verifing user input
    mapping input_vrfy = ([ "uid":uid, "gecos":gecos, "passwd":passwd, "passwd2": passwd2 ]);
    // sanity checks for malicious user
    checkinput( input_vrfy );
    con = Protocols.LDAP.client(host);
    con->bind(binddn, password, proto);
    con->set_basedn(basedn);
    con->set_scope(2);
    defines += ([ "uidNumber": ({ getlastuid(con, gidnumber) }), "passwd": ({ passwd }), "gidNumber": ({ gidnumber }) ]);
    if( isloginexist(con, defines["uid"][0]) )
      throw ( ({ "Login " + defines["uid"][0] + " already exist" }) );
    insertinldap(con, defines, basedn);
    if ( !isloginexist(con, defines["uid"][0]) )
      throw ( ({ "Due to an unknown error, you were not added to our account database", backtrace() }) );
    // create homedir and fix FS permissions
    updatesystem(defines);
    sendmails(defines);
    if(con)
      con->unbind();
  };
  if( error != 0 )
  {
    if(con)
      con->unbind();
    if(sizeof(error) < 2)
      // no backtrace produced => error with user input
      last_error = sprintf("An error occured\n%s\n", error[0]);
    else
    {
      last_error = sprintf("An error occured\n%s\nBacktrace is\n%s\n", error[0], master()->describe_backtrace(error[1]));
      sendbadmails(defines, last_error);
    }
    return http_rxml_answer(replace(QUERY(ui_add_error), ({ "$LASTERROR", "$MOUNTPOINT" }) , ({ last_error, QUERY(location) }) ) ,id);
  }
  return http_rxml_answer(replace(QUERY(ui_add), "$MOUNTPOINT", QUERY(location)), id);
}

// functions used by modify and update

void nodouble_attr(string attr_user, string attr_prog, mapping defines)
{
  if(attr_user != attr_prog)
  {
    defines[attr_user] = defines[attr_prog];
    defines -= defines[attr_prog];
  }
}

void modifyinldap(object con, mapping defines, string basedn)
{
  mapping attropval = ([ ]);
  array define;
  array indic;
  indic = indices(defines);
  string indice;
  nodouble_attr(QUERY(defvaruid), "uid", defines);
  nodouble_attr(QUERY(defvargecos), "gecos", defines);
  nodouble_attr(QUERY(defvaruidnumber), "uidNumber", defines);
  nodouble_attr(QUERY(defvargidnumber), "gidNumber", defines);
  nodouble_attr(QUERY(defvarhomedirectory), "homeDirectory", defines);
  nodouble_attr(QUERY(defvaruserpassword), "userPassword", defines);
  if(sizeof(QUERY(defvarmaildrop)) > 0)
  {
    nodouble_attr(QUERY(defvarmaildrop), "maildrop", defines);
    defines[QUERY(defvarmaildrop)] = String.trim_all_whites(defines[QUERY(defvarmaildrop)]);
  }
  if(sizeof(QUERY(defvarmailacceptinggeneralid)) > 0)
  {
    nodouble_attr(QUERY(defvarmailacceptinggeneralid), "mailacceptinggeneralid", defines); 
    for(int i = 0; i < sizeof(defines[QUERY(defvarmailacceptinggeneralid)]); i++)
      defines[QUERY(defvarmailacceptinggeneralid)][i] = String.trim_all_whites(defines[QUERY(defvarmailacceptinggeneralid)][i]);
  }
  for(int i = 0; i < sizeof(defines); i++)
  {
    indice = indic[i];
    attropval[indice] += ({ 2 }) + defines[indice];
  }
  if(QUERY(debug))
    write(sprintf("defines2=%O\n", attropval));
  con->modify(QUERY(defvaruid) + "=" + attropval[QUERY(defvaruid)][1] + ", " + basedn, attropval);
  checkresult(con, defines, defines[QUERY(defvaruid)][0]);
}

// functions used by update

// recursive chown
void rchown(string dir, int uid, int gid)
{
  string filename;
  array type;
  array filenames = get_dir(dir);
  if(filenames == 0)
    throw (({ "Your directory" + dir + " doesn't exist" }));
  chown(dir, uid, gid);
  foreach(filenames, filename)
  {
    type = file_stat(dir + filename);
    if((type != 0) && (type[1] == -2))
      rchown(dir + filename, uid, gid);
    chown(dir + filename, uid, gid);
  }
}

void updatevar(object con, mapping defines, string basedn)
{
  // defines is a mapping of array
  array(int) dirstat;
  string newgid = (string) QUERY(currentgidnumber);
  array oldgid = defines["gidNumber"];
  //In the case there are both upper and lower case, pay attention to use the good one or this will cause a _lot_ of trouble
  if(oldgid[0] == newgid)
    throw ( ({ "You don't need to update, you are already in the correct group" }) );
  array olduidnumber = defines["uidNumber"];
  array oldgidnumber = defines["gidNumber"];  
  defines["gidNumber"] = ({ newgid });
  array gidnumber = defines["gidNumber"];
  defines["uidNumber"] = ({ getlastuid(con, gidnumber[0]) });
  array uidnumber = defines["uidNumber"];
  array uid = defines["uid"];
  array homedirectory = defines["homeDirectory"];
  //defines["paye"] = ({ "0" });
  modifyinldap(con, defines, basedn);
  // sanity checks
  dirstat = file_stat(homedirectory[0]);
  if(dirstat == 0)
    throw ( ({ "No such file or directory: " + homedirectory[0], backtrace() }) );
  if(dirstat[1] != -2)
    throw ( ({ homedirectory[0] + " is not a directory!", backtrace() }) );
  if(dirstat[5] != ((int) olduidnumber[0]) || dirstat[6] != ((int) oldgidnumber[0]))
    throw ( ({ "You don't own your directory", backtrace() }) );
  // end of sanity checks
  rchown(homedirectory[0], (int) uidnumber[0], (int) gidnumber[0]); 
}

int gidok(mapping defines)
{
  int gidok = 1;
  if(intp(QUERY(allowedgidupdates)[0]) && sizeof(QUERY(allowedgidupdates)) > 0 && (QUERY(allowedgidupdates) != 0))
  {
    gidok = 0;
    foreach(QUERY(allowedgidupdates), int gid)
    {
      if(defines["gidNumber"][0] == (string) gid)
      {
        gidok = 1;
        break;
      }
    }
  }
  return gidok;
}

string showmodifyinputs(object id, mapping defines)
{
  string inputs;
  
  array inputs_from = ({ "$LOGIN", "$MOUNTPOINT", "$GECOS", "$PASSWORD", "$PASSWORD2", "$MAILDROP", "$MAILACCEPTINGGENERALID" });
  array inputs_to = ({ defines["uid"][0], QUERY(location) });
  /* can the user change his gecos ? */
  if(search(QUERY(allowedmodifyattribute), QUERY(defvargecos)) != -1)
    inputs_to += ({ "<input type=\"text\" value=\"" + defines["gecos"][0] + "\" name=\"gecos\">" });
  else
    inputs_to += ({ defines["gecos"][0] });
  if(search(QUERY(allowedmodifyattribute), QUERY(defvaruserpassword)) != -1)
    inputs_to += ({ "<input type=\"password\" name=\"passwd\">", "<input type=\"password\" name=\"passwd2\">" });
  else
    inputs_to += ({ "********", "********" });
  /* do we know maildrop ? */
  if(sizeof(QUERY(defvarmaildrop)) > 0)
  {
    /* can the user change maildrop ? */
    if(search(QUERY(allowedmodifyattribute), QUERY(defvarmaildrop)) != -1)
      inputs_to += ({ "<input type=\"text\" size=\"30\" value=\"" + defines["maildrop"][0] + "\" name=\"maildrop\">" });
    else
      inputs_to += ({ defines["maildrop"][0] });
  }
  else
    inputs_to += ({ "&nbsp;" });
  if(sizeof(QUERY(defvarmailacceptinggeneralid)) > 0)
  {
    string input_mailaccept = "<input type=\"text\" size=\"60\" name=\"mailacceptinggeneralid\" value=\"";
    string mailaccept = "";
    int n = sizeof(defines["mailacceptinggeneralid"]);
    for(int i = 0; i < n; i++)
    {
      mailaccept += defines["mailacceptinggeneralid"][i];
      if(i + 1 < n)
        mailaccept += ", ";
    }
    input_mailaccept = input_mailaccept + mailaccept + "\">";
    if(search(QUERY(allowedmodifyattribute), QUERY(defvarmailacceptinggeneralid)) != -1)
      inputs_to += ({ input_mailaccept });
    else
      inputs_to += ({ mailaccept });
  }
  else
    inputs_to += ({ "&nbsp;" });
  inputs = replace(QUERY(ui_modify_inputs), inputs_from, inputs_to);
  return inputs;
}

string showupdateinputs(object id, mapping defines)
{
  string inputs;
  array inputs_from = ({ "$LOGIN", "$MOUNTPOINT", "$GECOS", "$UIDNUMBER", "$GIDNUMBER" });
  array inputs_to = ({ defines["uid"][0], QUERY(location), defines["gecos"][0], defines["uidNumber"][0], defines["gidNumber"][0] });
  if(strlen(QUERY(updaterequireauth)[0]) > 0)
  {
    //TODO: use a select box to list logins in currentgidnumber
    inputs_to = ({ "<input type=\"text\" value=\"fill in user login\" name=\"uid\"", QUERY(location), "will find it", "will find it", "will find it" });
    inputs = replace(QUERY(ui_update_input), inputs_from, inputs_to);
    return inputs;
  }
  // sanity check
  if(QUERY(allowupdate) && gidok(defines))
    inputs = replace(QUERY(ui_update_input), inputs_from, inputs_to);
  else
    throw ( ({ "You are not allowed to update" }) );
  return inputs;
}

mapping modify(object id, string action)
{
  string host = QUERY(hostname);
  string password = QUERY(password);
  string basedn = QUERY(basedn);
  string binddn = QUERY(binddn);
  string gidnumber = (string) QUERY(gidnumber);
  int proto = QUERY(ldapver);
  mapping defines;
  object con = 0;
  string last_error;
  mixed error = 1;
  // fill in default values in defines for sendbadmails in case of error
  defines = ([ "uid": ({ "none" }), "uidNumber": ({ "-1" }), "gidNumber": ({ "-1" }), "gecos": ({ "none" }) ]);

  error = catch 
  {
    if(!id->conf->auth_module)
      throw ( ({ "This module require the caudium LDAP authentification module"  }) );
    if( !user_auth(id) )
      return http_auth_required("member user", "Wrong login/password ");
    con = Protocols.LDAP.client(host);
    con->bind(binddn, password, proto);
    con->set_basedn(basedn);
    con->set_scope(2);
    // first a sanity check :)
    if(isloginexist(con, id->auth[1]) == 0)
      throw ( ({ "You '" + id->auth[1] + "' don't exist, go away!" }) );
    defines[QUERY(defvaruid)] = id->auth[1];
    defines = getfullinformation(con, defines[QUERY(defvaruid)]);
    defines["uid"] = defines[QUERY(defvaruid)];
    defines["gecos"] = defines[QUERY(defvargecos)];
    defines["uidNumber"] = defines[QUERY(defvaruidnumber)];
    defines["gidNumber"] = defines[QUERY(defvargidnumber)];
    defines["homeDirectory"] = defines[QUERY(defvarhomedirectory)];
    defines["userPassword"] = defines[QUERY(defvaruserpassword)];
    if(sizeof(QUERY(defvarmaildrop)) > 0)
      defines["maildrop"] = defines[QUERY(defvarmaildrop)];
    if(sizeof(QUERY(defvarmailacceptinggeneralid)) > 0)
      defines["mailacceptinggeneralid"] = defines[QUERY(defvarmailacceptinggeneralid)];
    if(action == "modify")
    {
      // only show form inputs
      return http_rxml_answer(showmodifyinputs(id, defines), id);
    }
    if(action == "update")
    {
      if(strlen(QUERY(updaterequireauth)[0]) > 0)
        if(search(QUERY(updaterequireauth), id->auth[1]) == -1)
	  return http_auth_required("add member user", "Only some users may update");
      return http_rxml_answer(showupdateinputs(id, defines), id);
    }
    if(QUERY(debug))
      write(sprintf("defines1=%O\n", defines));
    if(action == "applyupdate")
    {
      /* the admin is updating another account */
      if(strlen(QUERY(updaterequireauth)[0]) > 0)
      {
        if(search(QUERY(updaterequireauth), id->auth[1]) == -1)
	  return http_auth_required("update member user", "Only some users may update");  
        if(isloginexist(con, id->variables->uid) == 0)
          throw ( ({ "You '" + id->variables->uid + "' don't exist, go away!" }) );
        defines[QUERY(defvaruid)] = id->variables->uid;
        defines = getfullinformation(con, defines[QUERY(defvaruid)]);
        defines["uid"] = defines[QUERY(defvaruid)];
        defines["uidNumber"] = defines[QUERY(defvaruidnumber)];
        defines["gidNumber"] = defines[QUERY(defvargidnumber)];
        defines["homeDirectory"] = defines[QUERY(defvarhomedirectory)];
      }
      if(QUERY(allowupdate) && gidok(defines))
      {
        //update
        updatevar(con, defines, basedn);
        sendmails(defines);
        return http_rxml_answer(replace(QUERY(ui_modify), "$MOUNTPOINT", QUERY(location)), id);
      }
      else throw ( ({ "You are not allowed to update" }) );
    }
    else if (action == "applymodify")
    {
      // modify
      array errors = ({ "" , 0 });
      if(search(QUERY(allowedmodifyattribute), QUERY(defvargecos)) != -1)
      {
        checkgecos(errors, id->variables->gecos);
        defines["gecos"] = ({ id->variables->gecos });
      }
      if(search(QUERY(allowedmodifyattribute), QUERY(defvaruserpassword)) != -1)
      {
	checkpasswd(errors, id->variables->passwd, id->variables->passwd2);
	defines["userPassword"] = ({  "{crypt}" + crypt(id->variables->passwd)  });
      }
      /* do we know maildrop ? */
      if(sizeof(QUERY(defvarmaildrop)) > 0)
      {
        /* can the user change maildrop ? */
        if(search(QUERY(allowedmodifyattribute), QUERY(defvarmaildrop)) != -1)
        {
	  checkmail(errors, id->variables->maildrop);
	  defines["maildrop"] = ({ id->variables->maildrop });
	}
      }
      if(sizeof(QUERY(defvarmailacceptinggeneralid)) > 0)
      {
        array mailaccept = id->variables->mailacceptinggeneralid / ",";
        for(int i = 0; i < sizeof(mailaccept); i++)
          checkmail(errors, mailaccept[i]);
        if(search(QUERY(allowedmodifyattribute), QUERY(defvarmailacceptinggeneralid)) != -1)
          defines["mailacceptinggeneralid"] = mailaccept;
      }
      if(errors[1])
        throw ( ({ errors[0] }) );
      else
      {
        modifyinldap(con, defines, basedn);
        return http_rxml_answer(replace(QUERY(ui_modify), "$MOUNTPOINT", QUERY(location)), id);
      }
    }
    else
      throw ( ({ "Wrong usage" }) );
    if(con)
      con->unbind();
  };
  if( error != 0 )
  {
    if(con)
      con->unbind();
    if(sizeof(error) < 2)
      // no backtrace produced => error with user input
      last_error = sprintf("An error occured\n%s\n", error[0]);
    else
    {
      last_error = sprintf("An error occured\n%s\nBacktrace is\n%s\n", error[0],
 master()->describe_backtrace(error[1]));
      sendbadmails(defines, last_error);
    }
    return http_rxml_answer(replace(QUERY(ui_modify_error), ({ "$LASTERROR", "$MOUNTPOINT" }) , ({ last_error, QUERY(location) }) ) ,id);
  }
}

mixed find_file(string path, object id)
{
  mapping result;
  if(!checkdns(id->remoteaddr))
    return http_low_answer(403, "<html><body><h2>Access forbidden</h2></body></html>");
  id->misc->cacheable = 0;
  id->misc->is_dynamic = 1;
  switch(path)
  {
    case "/add":result = add(id, 0); break;
    case "/applyadd": result = add(id, 1); break;
    case "/modify": result = modify(id, "modify"); break;
    case "/applymodify": result = modify(id, "applymodify"); break;
    // update is just a sub case of modify
    case "/update": result = modify(id, "update"); break;
    case "/applyupdate": result = modify(id, "applyupdate"); break;
    default: result = first_screen(id);
  }
  return result;
}
