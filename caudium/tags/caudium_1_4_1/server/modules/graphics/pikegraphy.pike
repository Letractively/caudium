/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2002 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/* SQL Database description:

CREATE TABLE comments (
  id int(11) NOT NULL auto_increment,
  pic_name varchar(251) DEFAULT '' NOT NULL,
  comment text DEFAULT '' NOT NULL,
  datetime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  user text DEFAULT '' NOT NULL,
  ip varchar(16) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  KEY pic_name (pic_name)
);

CREATE TABLE descr (
  name varchar(255) DEFAULT '' NOT NULL,
  descr text DEFAULT '' NOT NULL,
  seclevel int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (name)
);

CREATE TABLE ratings (
  id int(11) NOT NULL auto_increment,
  datetime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  pic_name varchar(251) DEFAULT '' NOT NULL,
  ip varchar(16) DEFAULT '' NOT NULL,
  rating int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (id),
  KEY pic_name (pic_name)
);

CREATE TABLE users (
  login char(20) DEFAULT '' NOT NULL,
  pass char(32) DEFAULT '' NOT NULL,
  cookieval char(128) DEFAULT '' NOT NULL,
  seclevel int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (login)
);

*/

/*
 * $Id$
 */
inherit "caudiumlib";
inherit "module";

#include <config.h>
#include <module.h>

#define SQLConnect(X) my_configuration()->sql_connect(X)

//
//! module: PikeGraphy
//!  Another photoalbum module.<br />
//!  This is a phpGraphy clone like module for Caudium.
//! type: MODULE_PARSER
//! inherits: caudiumlib
//! inherits: module
//! cvs_version: $Id$ 
//

constant module_type  = MODULE_PARSER;
constant module_name  = "PikeGraphy";
constant module_doc   = "Another photoalbum module.<br>"
                        "This is a phpGraphy clone like module for Caudium."
			"<p>\n"
			"Tag Args: "
			"nocss (optional) do not include configured stylesheet definitions"
			"rootname (optional) change name of gallery root"
			"separator (optional) change directory separator text"
			"next (optional) change next link text"
			"previous (optional) change previous link text";

constant thread_safe=0;	// Not yet...

void create () {
  string css_classes=
          "A {text-decoration: none ; color: #FFFFFF}\n" +
          "A:link {text-decoration: none ; color: #aabbcc}\n" +
          "A:visited{text-decoration:none ; color: #aabbcc}\n" +
          "A:active{text-decoration:none; color: #aabbcc}\n" +
	          "A:hover{text-decoration:underline; color: #aabbcc}\n"
	  "FONT.totalimages{font-family: Helvetica, Arial, sans-serif; font-weight: bold}"
	  "FONT.imagecount{}";
  defvar ("sqlserver", "localhost", "SQL server",
          TYPE_STRING,
          "This is the host running the SQL server with the " 
          "authentication information.<br>\n" 
          "Specify an \"SQL-URL\":<ul>\n"
          "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
          "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
          "Valid values for \"sqlserver\" depend on which "
          "sql-servers your pike has support for, but the following "
          "might exist: msql, mysql, odbc, oracle, postgres.\n",
          ); 
  defvar ("css_classes", css_classes, "CSS Classes", TYPE_TEXT, "" );
  defvar ("image_by_line", 3, "Default number of cols", TYPE_INT, "Default number of columns." );
  defvar ("nb_pic_max", 12, "Default number of pics", TYPE_INT, "Default number of pictures." );
  defvar ("root_dir", "/home/httpd/htdoc/home/pikegraphy/pictures/", "root_dir", TYPE_DIR, "Location of the images in the real filesystem." );
  defvar ("root_images", "pictures/", "root_images", TYPE_STRING, "Location in the Virtual Filesystem of the pictures (root_dir) to bedisplayed." );
}

string replace_string (string what)
{
  return replace(what, ({ "\000", " ", "\t", "\n", "\r", "'", "\"", "/" }) ,({"%00", "%20", "%09", "%0a", "%0d", "%27", "%22", "%2F"}));
}

string replace_string2 (string what)
{
  return replace(what, ({"%00", "%20", "%09", "%0a", "%0d", "%27", "%22", "%2F"}) , ({ "\000", " ", "\t", "\n", "\r", "'", "\"", "/" }));
}

int get_nb_comment (string filename)
{
  object db = SQLConnect(QUERY(sqlserver));
  array x = db->query("select * from comments where pic_name='"+filename+"'");
  return (int) (sizeof(x));
}

mixed get_comment (string filename)
{
  object db = SQLConnect(QUERY(sqlserver));
  array x = db->query("select * from descr where name='"+filename+"'");
  if ( sizeof(x) == 0 ) {
     return "";
  } else {
     return x[0]->descr;
  }
}

int get_level (string dir)
{
  object db = SQLConnect(QUERY(sqlserver));
  array x = db->query("select * from descr where name='"+dir+"'");
  if ( sizeof(x) == 0 ) {
     return 0;
  } else { 
     return ((int)x[0]->seclevel);
  }
}

//
//! tag: pikegraphy
//!  PikeGraphy tag
//
mixed t_pikegraphy(string tag, mapping args, object id)
{
  //variables necessaire au script
  int tmp_int=0;
  string dir="";
  string cnt="<style type=\"text/css\">" + QUERY(css_classes) + "</style>\n";
  int startpic=0;
  string filename="";
  int logging=0;
  int admin=0;
  string username="";
  int userlevel=0;
  string txt_root_dir="home/";
  string txt_separator="/";
  string txt_next="  -- NeXT -->> ";
  string txt_previous="  <<-- Previous -- ";

  if(args->nocss) cnt="";
  if(args->rootname) txt_root_dir=args->rootname;
  if(args->separator) txt_separator=args->separator;
  if(args->next) txt_next=args->next;
  if(args->previous) txt_previous=args->previous;

//cnt = head_page(cnt) ;

if (id->variables && id->variables->logout) {
   	cnt += "<remove_cookie name=\"LoginValue\">\n<redirect to=\"?dir=\">";
        logging=0;
        admin=0;
}

//
// analyse query

 if (id->variables && id->variables->dir)  
      dir=id->variables->dir;
 if (id->variables && id->variables->startpic)  
      startpic=(int) id->variables->startpic;
 if (id->variables && id->variables->display ) { 
      dir=dirname(id->variables->display);
      filename=basename(id->variables->display);
 }

if (id->variables && id->variables->login) {
  cnt += "</td><td align=left>";
  cnt += "<form method=POST action=\"" + id->not_query + "\">";
  cnt += "Login :    <input name=\"user\" size=20><br>";
  cnt += "Password : <input type=\"password\" name=\"pass\" size=20>";
  cnt += "<input type=\"hidden\" name=\"startlogin\" value=\"1\">";
  cnt += "<input type=\"hidden\" name=\"dir\" value=\""+dir+"\">";
  cnt += "<input type=\"submit\" value=\"Login\">";
  cnt += "</form>";
//  cnt += "\t</td>";
//  cnt += "</tr>\n</table>";
  return cnt;
 }

if (id->variables && id->variables->startlogin) {
   object db = SQLConnect(QUERY(sqlserver));
   array x = (db->query("select * from users where login=\""+id->variables->user+"\" and pass=\""+id->variables->pass+"\""));
   if ( (sizeof(x)) != 0 ) {
   	cnt += "<set_cookie name=LoginValue value=\""+x[0]->cookieval+"\" minutes=15>";
        if ((int)x[0]->seclevel== 999) {
            admin=1;
            userlevel=999;
        } else {
            userlevel=(int)x[0]->seclevel;
        }
        username = x[0]->login;
        logging = 1;
   }
} else {
   if (id->cookies && id->cookies->LoginValue ) {
       object db = SQLConnect(QUERY(sqlserver));
       array x = (db->query("select * from users where cookieval=\""+id->cookies->LoginValue+"\" "));
       if ( sizeof(x) == 1 ) {
          if ((int)x[0]->seclevel==999) {
              admin=1;
              userlevel=999;
          } else {
              userlevel=(int)x[0]->seclevel;
          }
          username = x[0]->login;
          logging = 1;
       }
   }
 }
   
if (id->variables && id->variables->dirlevel && admin == 1) {
   object db = SQLConnect(QUERY(sqlserver));
   db->query("replace into descr values('"+db->quote(id->variables->dir)+"','','"+db->quote(id->variables->dirlevel)+"')");
}

if (id->variables && id->variables->updpic && admin == 1 ) {
   object db = SQLConnect(QUERY(sqlserver));
   db->query("replace into descr values('"+db->quote(id->variables->display)+"','"+db->quote(id->variables->dsc)+"','"+db->quote(id->variables->lev)+"')");
}

if (id->variables && id->variables->delcomment && admin == 1) {
   object db = SQLConnect(QUERY(sqlserver));
   db->query("delete from comments where id=" + id->variables->delcomment);
}

 if (id->data != "" && id->variables && id->variables->comment ){
   object db = SQLConnect(QUERY(sqlserver));
   db->query("insert into comments values(0,'"+db->quote(id->variables->picname)+"','"+db->quote(id->variables->comment)+"',NOW(),'"+id->variables->username+"','"+id->variables->remoteaddr+"')");
   cnt = "<html><script language=\"javascript\">window.opener.location=\"?display="+id->variables->id+"\";window.close();</script></html>";
   return cnt;
 }

 if (id->variables && id->variables->addcomment ) {
      cnt += "\n\t<form name=\"blah\" method=POST>\n";
      cnt += "\tUsername \n\t<font face=\"Courier\" size=1><input type=text name=username size=30>\n\t</font><br><br>\n";
      cnt += "\tComment <br>\n\t<font face=\"Courier\" size=1><textarea name=comment cols=40 rows=3></textarea>\n\t</font><br>";
      cnt += "<br>";
      cnt += "\n\t<input type=submit value=\"Add Comment\">";
      cnt += "\n\t<input type=hidden name=addingcomment value=\"1\">";
      cnt += "\n\t<input type=hidden name=picname value=\""+id->variables->id+"\">";
      cnt += "\n\t</form>";
      cnt += "\n\t<script language=\"javascript\">document.blah.user.focus();</script>\n";
//      cnt += "\t</td>\n";
//      cnt += "</tr>\n</table>\n";
      return cnt;
 }

 cnt += "\n\t<table border=0 cellspacing=0 cellspadding=0 width=\"100%\">\n\t<tr>\n\t\t<td>";

 //
 // Construction du path en haut du tableau
 //
 if (id->variables) {
  if ( (!id->variables->display) && ( (!id->variables->dir) || 
     (id->variables->dir == "dir=") || (id->variables->dir == "")) ) {
   cnt += txt_root_dir+"</td>\n";
   }
   else
   {
     cnt += "<a href=\"" + id->not_query + "?dir=\">"+txt_root_dir+"</a>" + txt_separator;
     array alldir= explode_path(dir);
     string alltmp="";

     for (int i=0;i<(sizeof(alldir));i++) {
       if ( i == (sizeof(alldir) -1) && (id->variables && id->variables->display == "")) {
         cnt += " "+alldir[i]+"\n";
       }  else {
            if ( alltmp == "" ) {
                cnt += "<a href=\"" + id->not_query +"?dir="+alltmp+alldir[i]+"\">"+alldir[i]+"</a>"+ txt_separator;
            } else {
                cnt += "<a href=\"" + id->not_query
			+"?dir="+alltmp+"/"+alldir[i]+"\">"+alldir[i]+"</a>" + txt_separator;
            }
       }
     alltmp += alldir[i];
     }
   }
 }
 if (logging == 1) {
    cnt += "\t\t\n\t\t<td align=right>"+username+" - <a href=\"" +
	id->not_query + "?logout=1\">logout</a></td>\n";
 } else {
    cnt += "\t\t\n\t\t<td align=right><a href=\"" + id->not_query +
	"?dir="+dir+"&login=1\">login</a></td>\n";
 }

 cnt += "\t</tr>\n\t</table>\n";

 cnt += "\n\t<table border=0 cellspacing=0 width=\"100%\">\n\t<tr>\n\t\t<td> \n";

 if ( id->variables && ! id->variables->display ) {
   //
   // Recherche des directory dans le directory
   //
   array dirs=({});
   catch(
     dirs=Array.filter(get_dir(QUERY(root_dir)+dir)||get_dir(QUERY(root_dir)), lambda(string f) { return (file_stat(QUERY(root_dir)+dir+"/"+f)[1] == -2 ); }));


   for (int i=0;i<(sizeof(dirs));i++) {
     if ( dir == "") {
        if (get_level(dirs[i]) <= userlevel) {
//           cnt += dir+" alevel "+userlevel+"    get_level    "+get_level(dirs[i])+"  "+dirs[i];
           cnt += "\t\t&nbsp;&nbsp&nbsp;&nbsp<a href=\"" + id->not_query +
		"?dir="+dirs[i]+"\">"+dirs[i]+"</a><br>\n";
        }
     } else {
//           cnt += " blevel "+userlevel+"    get_level    "+get_level(dir+"/"+dirs[i])+"  "+dir+"/"+dirs[i];
        if (get_level(dir+"/"+dirs[i]) <= userlevel) {
           cnt += "\t\t&nbsp;&nbsp&nbsp;&nbsp<a href=\"" + id->not_query + 
		"?dir="+dir+"/"+dirs[i]+"\">"+dirs[i]+"</a><br>\n"; 
        }
     }
   }

   cnt += "\t\t&nbsp\n\t\t</td>\n";
   // cnt += "\t</tr>\n\t<tr>\n\t\t<td align=center>\n";
   cnt += "\t</tr>\n";

   if ( admin == 1 && !id->variables->display ) {
        cnt += "\t<tr>\n\t\t<td>\n";
        cnt += "\t\t<form method=POST>Directory security level: <input name=\"dirlevel\" value=\""+get_level(dir)+"\" size=4>";
        cnt += "\t\t<input type=hidden name=dirs value=\""+dir+"\">";
        cnt += "\t\t<input type=submit value=\"Change\"></form>";
        cnt += "\t\t</td>\n\t</tr>\n";
   }

   cnt += "\t</table>\n";

   //
   // Recherche des images dans le rep
   //
   int t=1;
   array(string) cnt_dir = sort(Array.filter(get_dir(QUERY(root_dir)+dir)||get_dir(QUERY(root_dir)), lambda(string s) { return glob("*.jpg", s);}));

   if ( (sizeof(cnt_dir)) != 0 ) {
     cnt += "\n\t<table cellspacing=0 cellpadding=3 border=0 width=\"100%\">\n";
     cnt += "\t<tr>\n";
     for(int i = startpic; i<(sizeof(cnt_dir)) && i<QUERY(nb_pic_max)+startpic;i++) {
       cnt += "\t\t<td><a href=\"" + id->not_query 
	+ "?display="+dir+"/"+replace_string(cnt_dir[i])+"\">";
       cnt += "<cimg src=\""+QUERY(root_images)+dir+"/"+replace_string(cnt_dir[i])+"\" format=jpeg quant=\"64\" maxwidth=\"100\" border=0 ></a></td>\n";

       cnt += "\t\t<td align=left><a href=\"" + id->not_query 
	+ "?display="+dir+"/"+replace_string(cnt_dir[i])+"\">";
       string comment = get_comment(dir+"/"+cnt_dir[i]);
       if ( comment == "" ) {
          cnt += cnt_dir[i]+"</a><br>";
	} else {
          cnt += comment+"</a><br>";
       }
 
       tmp_int = (int) get_nb_comment(dir+"/"+(cnt_dir[i]));
       if ( tmp_int != 0 )
         cnt += tmp_int+" comments";
       cnt += "</td>";

       if (t != QUERY(image_by_line) ) {
         cnt += "\n\n";
         t += 1;
       } else {
         t=1;
         cnt += "\n\t</tr>\n\t<tr>\n";
       }
     }
   // display page count and total count for gallery section
     cnt +="<tr>\n<td colspan="+(QUERY(image_by_line)+2)+">"
	"<font class=imagecount>"
	+ (startpic+1) + " - " +
	((startpic+QUERY(nb_pic_max))<=sizeof(cnt_dir)?
        (startpic+QUERY(nb_pic_max)):sizeof(cnt_dir))
	+ " /</font> <font class=totalimages>" + sizeof(cnt_dir) + 
	  "</font></td></tr>\n";

   /// Generation des lignes de navigation du previous/next
   if ( startpic != 0 ) {
     cnt += "\t<tr>\n\t\t<td colspan="+QUERY(image_by_line)*2+"><center>";
     cnt += "<a href=\"" + id->not_query +
	"?dir="+dir+"&startpic="+(startpic-QUERY(nb_pic_max))+"\">" +
          txt_previous + "</a>";
     if ( (startpic+QUERY(nb_pic_max)) < (sizeof(cnt_dir))) {
       cnt += "<a href=\"" +
	id->not_query + "?dir="+dir+"&startpic="+(startpic+QUERY(nb_pic_max))+"\">"
	+ txt_next + "</a></td>\n";
     }
   } else {

      if ((sizeof(cnt_dir)) > QUERY(nb_pic_max)) {
        cnt += "\t<tr>\n\t\t<td colspan="+QUERY(image_by_line)*2+"><center>";
        cnt += "<a href=\"" + id->not_query +
		"?dir="+dir+"&startpic="+(startpic+QUERY(nb_pic_max))+"\">"
		+ txt_next + "</a></td>\n";
      }

//     cnt += (sizeof(cnt_dir))+"  "+QUERY(nb_pic_maxi);
   }
   cnt += "\t</tr>\n\t</table>\n";
// cnt += QUERY(root_dir)+dir+"/"+filename;
  }
 }
 else
 {
   array(string) cnt_dir = sort(Array.filter(get_dir(QUERY(root_dir)+dir), lambda(string s) { return glob("*.jpg", s);}));
   int num_filename = (search(cnt_dir, replace_string2(filename)) );
   if ( num_filename == -1 )
        num_filename = 0;

   cnt += "\t\t<table border=0 align=center width=90%>\n";

   cnt += "\t\t<tr align=center width=\"100%\">\n\t\t\t<td align=center><span class=\"big\">";
//   string comment = get_comment(dir+"/"+cnt_dir[(num_filename)]);
//   if ( comment == "" ) {
//       cnt += cnt_dir[num_filename]+"</span>\n\t\t\t</td>\n\t\t</tr>\n";
//   } else {
//       cnt += comment+"</span>\n\t\t\t</td>\n\t\t</tr>\n";
//   }

   cnt += "\t\t<tr align=\"center\">\n\t\t\t<td > ( "+(num_filename+1)+"/"+(sizeof(cnt_dir)-1)+" )\n\t\t\t</td>\n\t\t</tr>\n\t\t<tr align=\"center\" >\n\t\t\t<td>";
   if ( num_filename > 0 )
        cnt += "<a href=\""  + id->not_query +
		"?display="+dir+"/"+replace_string(cnt_dir[(num_filename-1)])+"\">Previous</a>" ;

//   if ( id->variables && ! id->variables->hi ) {
//      cnt += "<a href=?display="+dir+"/"+replace_string(cnt_dir[(num_filename)])+"&hi=1> HiRes </a>";
//   } else {
//      cnt += "<a href=?display="+dir+"/"+replace_string(cnt_dir[(num_filename)])+"> LowRes </a>";
//   }

   if ( num_filename < (sizeof(cnt_dir)-1)) {
      cnt += "<a href=\"" + id->not_query 
	+ "?display="+dir+"/"+replace_string(cnt_dir[(num_filename+1)])+
	"\">Next</a>\n\t\t\t</td>\n\t\t</tr>\n ";
   } else {
      cnt += "\n\t</td></tr>\n";
   }

   if (  admin == 1 ) {
     cnt += "\t<tr align=center>\n\t\t<td>\n";
     cnt += "\t\t<form> Description:\n";
     cnt += "\t\t<textarea name=\"dsc\" cols=60 rows=3>"+get_comment(dir+"/"+filename)+"</textarea><br><br>";
     cnt += "\t\tSecurity level: <input name=\"lev\" value=\""+get_level(dir+"/"+filename)+"\" size=4>";
     cnt += "\t\t<input type=hidden name=display value=\""+dir+"/"+filename+"\">";
     cnt += "\t\t<input type=hidden name=updpic value=\"1\">";
     cnt += "\t\t<input type=submit value=\"Change\">";
     cnt += "\t\t</form>";

     cnt += "\t\t</td>\n\t</tr>";
   }

   if (id->variables && id->variables->hi ) {
      cnt += "<td ><br><center><img src="+QUERY(root_images)+dir+"/"+filename+" ></center><br><br></td>";
   } else {
      cnt += "\t\t<tr>\n\t\t\t<td><br><center><cimg src="+QUERY(root_images)+dir+"/"+filename+" maxwidth=800 maxheight=600 quant=64 format=\"jpeg\" border=0 ></center><br></td>";
   }
   cnt += "\n\t\t</tr>\n\t\t<tr>\n";
   cnt += "\t\t\t<td align=right> <a href=\"\" onClick='enterWindow=window.open(\"?id="+dir+"/"+filename+"&addcomment=1\",\"commentadd\",\"width=400,height=260,top=250,left=500\"); return false'>Click to add comment</a> <br></td>\n";
   cnt += "\t\t</tr>\n";

   tmp_int = (int) get_nb_comment(dir+"/"+(filename));
   if ( tmp_int != 0 ) {
     cnt += "\t\t<tr>\n\t\t\t<td> Comment : </td>\n\t\t</tr>\n";
     cnt += "\t\t<tr>\n\t\t\t<td>";
     cnt += "<sqloutput host=\""+QUERY(sqlserver)+"\" query=\"select * from comments where pic_name='"+dir+"/"+filename+"'\">";
     cnt += " From #user# on #datetime# <br> #comment# <br><br>";
     if(admin==1)
       cnt +="(<a href=\"" + id->not_query + "?" + id->query +
           "&delcomment=#id#\">delete</a>)";
     cnt += "</sqloutput>";
     cnt += "\n\t\t\t</td>\n\t\t</tr>";
   }

   cnt += "\n\t\t</table>\n";
   cnt += "\n\t\t</td>\n";
   cnt += "\t</tr>\n";
   cnt += "\t</table>\n";
  }
// cnt += "\n\t</td>\n";
// cnt += "\n</tr>\n";
// cnt += "</table>\n";
 return cnt;
}

mapping query_tag_callers() {
    return ([ "pikegraphy" : t_pikegraphy ]);
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: sqlserver
//! This is the host running the SQL server with the authentication information.<br />
//!Specify an "SQL-URL":<ul>
//!<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@][<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br />
//!Valid values for "sqlserver" depend on which sql-servers your pike has support for, but the following might exist: msql, mysql, odbc, oracle, postgres.
//!
//!  type: TYPE_STRING
//!  name: SQL server
//
//! defvar: css_classes
//!  type: TYPE_TEXT
//!  name: CSS Classes
//
//! defvar: image_by_line
//! Default number of columns.
//!  type: TYPE_INT
//!  name: Default number of cols
//
//! defvar: nb_pic_max
//! Default number of pictures.
//!  type: TYPE_INT
//!  name: Default number of pics
//
//! defvar: root_dir
//! Location of the images in the real filesystem.
//!  type: TYPE_DIR
//!  name: root_dir
//
//! defvar: root_images
//! Location in the Virtual Filesystem of the pictures (root_dir) to bedisplayed.
//!  type: TYPE_STRING
//!  name: root_images
//

/*
 * If you visit a file that doesn't contain these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */

