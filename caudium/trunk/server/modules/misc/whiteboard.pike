/*
 * Whiteboard module v.0.2
 *
 * (c) Karl Stevens <karl@maxim.ca>
 * This code is released under the GNU Public License (GPL)
 *
 * This is a web-based whiteboard.
 *
 *
 * TODO:
 *       make thread-safe
 *	 make the storage into a SQL database
 *
 */
constant cvs_version = "$Id$";
#include <module.h>
#include <process.h>
inherit "module";
inherit "caudiumlib";

string tail="<br><hr></body>";
string back="\n<br><a href=../>Back</a>";
array priority=({"HIGHEST","HIGH","Normal","low","lowest"});
array statuses=({"Open", "Suspended", "Waiting"});

array masterfile=({});

array register_module()
{
  return ({ MODULE_LOCATION,
            "Web-based whiteboard",
            "Makes a whiteboard. ",
            ({}),
            1 });
}

void create() {
 defvar("mountpoint", "/whiteboard", "Location of module in virtual file system.",
 	TYPE_LOCATION,
 	"Location of module in virtual filesystem.");
 defvar("masterfile", "NONE", "Location of master data file",
         TYPE_FILE,
         "This is the file that holds the whiteboard info.  It must be "
         "readable and writable by Roxen.");
 defvar("allowedusers", ({""}), "Users allowed to access this whiteboard",
 	TYPE_STRING_LIST,
 	"Users listed here will have access to this whiteboard, they will "
 	"be able to add, delete, and modify data.  Leaving this blank will "
 	"make this whiteboard accessible to anyone (although users will still "
 	"be required to login.");
 defvar("expiretime", 48, "Time before closed projects get deleted.",
        TYPE_INT,
        "This is the amount of time (in hours) before closed projects "
        "get expunged from the database.");
}

array readfile(string file) {
  object o=Stdio.File();
  if (!o->open(file,"r"))
    return 0;
  array result=(o->read()/"\n");
  o->close;

  return result;
}

void start() {
  // Load config file
  array tempdb=readfile(QUERY(masterfile));
  if(tempdb==0)
    return;

  sort(tempdb);
  //parse config file
  masterfile=({});
  foreach(tempdb, string line) {
    if((line!=0)&&(line!="")) {
      array c=({});
      string comments="";
      if(sscanf(line,"%d\t%s\t%s\t%d\t%s\t%s\t%s\t%*s\t%*s\t%*s\t%s",
                      int pri, string project, string creator,
                      int timestamp, string users, string status,
                      string description, comments)>6) {
        if(comments!=0)
          foreach(comments/"\t",string ln)
            if(sscanf(ln,"%d:%s:%s", int ts, string u, string cmm)==3)
              c+=({ (["time":(int)ts, "user":u, "text":cmm]) });
          if(users==0)
            users="";
          if(pri>4)
            pri=4;
          masterfile+=({ (["priority":(int) pri,
                           "project":project,
                           "creator":creator,
                           "timestamp":(int) timestamp,
                           "users":users/" ",
                           "status":status,
                           "description":description,
                           "comments":c ]) });
      }
    }
  }
}

void stop() {
  string t=savedb();
  return;
}

string savedb() {
  string dbname=QUERY(masterfile);
  object o=Stdio.File();
  int expungetime=time()-QUERY(expiretime)*3600;

  if (!o->open(dbname,"wct"))
    return "ERROR: Cannot save database";
  foreach(masterfile,mapping line) {
    if(line->status=="Closed" && (line->timestamp<expungetime))
      masterfile-=({line});
    else {
      if(line->users==0)
        line->users=({});
      o->write(line->priority+"\t"+
               line->project+"\t"+
               line->creator+"\t"+
               line->timestamp+"\t"+
              (line->users*" ")+"\t"+
               line->status+"\t"+
               line->description+"\t\t\t");
      array c=line->comments;
      if(c!=0)
        foreach(c,mapping ln)
          o->write("\t"+
                   ln->time+":"+
                   ln->user+":"+
                   ln->text);
        o->write("\n");
    }
  }
  o->close;
  return "";
}

// Return the index# of the project, or -1 (not found)
int findproject(string s) {
  if(search(column(masterfile,"project"), s)<0)
    return -1;
  return search(column(masterfile,"project"), s);
}

//Strip characters from a string
string strip( string a, string b) {
  if((b!="") && (b!=0))
    foreach(b/"", string n)
      a-=n;
  return a;
}

//Return a string with X parts
string words( string a, int w) {
  array n=a/" ";
  return (n[0..w-1])*" ";
}

//Return date as string
string nctime( int t) {
  string a=words((string) ctime(t),4);
  return a[..sizeof(a)-4];
}

//Print our head...
string head(string title) {
  return "<HTML><HEAD><TITLE>WWWhiteboard - "+title+"</TITLE></HEAD>\n"
         "<BODY bgcolor=white>\n<table width=100%><tr valign=top><td><h2>WWWhiteboard</h2></td>"
         "<td align=right><a href="+QUERY(mountpoint)+">Home</a></td></tr></table><hr>";
}

//List all comments.
string listcomments( array a ) {
  string result;
  if((a==0) ||(sizeof(a)==0))
    result="<BR><B>No Comments Posted</b>";
  else {
    result="<table border=1 width=100%><tr><th>Comments:</th></tr>\n";
    foreach(reverse(a), mapping comment) {
      result+="<tr><td><b><u>Posted by "+String.capitalize(comment->user)+
              " on "+nctime(comment->time)+"</u></b><br>\n"+comment->text+"</td></tr>\n";
    }
    result+="</table>";
  }
  return result;

}

// Create the screen for editing a record.
string editscreen( mapping m, int mod, string user) {
  string extra1="";
  string extra2="";
  string pri="";
  string stt="";
  string result="<table border=1><tr><th colspan=2>"+m->project+"</th></tr>\n";

  switch(mod) {
    case 0:                              //project is closed
      pri=priority[m->priority];
      stt=m->status;
      extra2=listcomments(m->comments);
      break;
    case -1:                             //new/edit record
      for(int i=0;i<sizeof(priority);i++) {
        if(i==m->priority)
          pri+="<option selected>"+priority[i];
        else
          pri+="<option>"+priority[i];
      }
      extra1="<form action=saveproject.html method=post><input type=hidden name=new value=new>";
      pri="<select name=priority>"+pri+"</select>";
      extra2="Users:<input type=text value=\"\" size=80 name=users><br>\n"
        "<sub>(This is a comma separated list of users who will have access to this project.  If left empty, then everybody has access.</sub>"
        "<br>\n<br><input type=submit value=Save></form>";
      stt=m->status;
      break;
    case -2:
      foreach(statuses, string st1) {
        if(st1==m->status)
          stt+="<option selected>"+st1;
        else
          stt+="<option>"+st1;
      }
      for(int i=0;i<sizeof(priority);i++) {
        if(i==m->priority)
          pri+="<option selected>"+priority[i];
        else
          pri+="<option>"+priority[i];
      }
      extra1="<form action=save.html method=post>";
      pri="<select name=priority>"+pri+"</select>";
      stt="<select name=status>"+stt+"</select>";

      extra2="<input type=submit value=\"Modify Data\"></form>\n";
      if(user==m->creator)
        extra2="<table><tr><td align=left>"+extra2+"</td><td align=right>"+
               "<form action=save.html method=post><input type=hidden name=status value=\"Closed\">"+
               "<input type=submit value=\"Close Project\"></form></td></tr></table>";
      extra2+=listcomments(m->comments)+
             "<form action=addcomment.html method=post><input type=hidden name=project value=\""+
              m->project+"\">\n"+"<textarea name=comment cols=70 rows=4></textarea>"+
             "<br>\n<input type=submit value=\"Add Comment\"</form>";
    break;
  }
  result=(sprintf("\n%s<table border=1><tr><th colspan=2>%s</th></tr>\n"
                  "<tr valign=top><td>Priority: %s</td><td rowspan=3>Created by: "
                    "<u>%s</u><br>%s</td></tr>\n"
                  "<tr><td>Status: %s</td></tr>\n"
                  "<tr><td>Last Modified: %s</td></tr></table>%s",
                  extra1, m->project, pri, m->creator, m->description,
                  stt, nctime(m->timestamp),extra2) );
  return result;
}

// Make main menu.
string makeindex(string project, string user) {
  string result="";
  int open;
  string title;
  string test="";

  if(project=="") {
    result="Total Projects: "+sizeof(masterfile)+"<BR>";
    if(sizeof(masterfile)>0) {
      result+="<table border=1><tr><th>Name</th><th>Priority</th><th>Status</th>"
              "<th>Description</th><th>Created By</th><th>Updated</th><th>Comments</th></tr>\n";
      foreach(masterfile, mapping x) {
        string t="<tr>";
        if(x->status=="Closed") {
          t="<tr bgcolor=#BBBBBB>";
        }
        if(x->users==0)
          t+="<td bgcolor=green>";
        else {
          if(sizeof(x->users-({""}))==0)
            t+="<td bgcolor=green>";
          else {
            array a=x->users-({""})+({x->creator});
            if(search(a,user)<0)
              t+="<td bgcolor=red>";
            else
              t+="<td bgcolor=yellow>";
          }
        }
        if(x->comments==0)
          x->comments=({});
        result+=t+"<a href="+http_encode_string(x->project)+"/>"+x->project+"</a></td>"
                "<td>"+priority[x->priority]+"</td><td>"+x->status+"</td>"
                "<td>"+x->description+"</td><td>"+x->creator+"</td><td>"+
                nctime((int) x->timestamp)+"</td><td align=center>"+sizeof(x->comments)+"</td></tr>\n";
      }
      result+="</table><br>\n";
    }
    result+="<br><p><a href=createnewproject.html>Create New Project</a></p>\n";
    title="Project Index";
  }
  else {
    mapping x=masterfile[findproject(project)];
    if(x->status=="Closed")
      open=0;
    else
      open=-2;
    result=editscreen(x, open, user);
    title=project+test;
  }
  return head(title)+result+tail;
}

string editproject( string user, int prj, object id) {
  mapping m;

  if(prj==-1)
    m=(["priority":2,"project":"Name: <input name=project type=text value=\"\" size=50>",
        "creator":user,"timestamp":time(),
        "users":({}),"status":"Creating",
        "description":"<textarea name=description cols=50 rows=5>Description</textarea>",
        "comments":({([ ])}) ]);
  else
    m=masterfile[prj];

  return head(m->prj)+editscreen(m, prj, user)+tail;
}

string saveinput(string project, string user, object id) {
  string result="";
  int x;

  if(id->variables->new) {
    if( (x=findproject(project))>=0)
      result="ERROR: Project &quot;"+project+"&quot; already exists.";
    else {
      if(project=="")
        return "";
      array users;
      if(id->variables->users) {
        if((id->variables->users-" ")!="")
          users=((id->variables->users+","+user)-" ")/",";
      }
      id->variables->status="Open";
      masterfile+=({ (["project":project,
                       "creator":user,
                       "description":replace(id->variables->description,"\t"," "),
                       "users":users ]) });
    }
  }

  if(result=="") {
    if((x=findproject(project))<0)
      result="ERROR: Project &quot;"+project+"&quot; not found";
    else {
      mapping m=masterfile[x];

      m->timestamp=time();
      m->priority=search(priority,id->variables->priority);
      m->status=id->variables->status;
      masterfile[x]=m;

      if(!(id->variables->new))
        result=addcomment(project, user,"SYSTEM: Status Changed.");
      else {
        sort(column(masterfile,"priority"),masterfile);
        result=savedb();
      }
    }
  }

  return result;
}

string addcomment(string project, string user, string comment) {
  string result="";
  int x;

  if(comment=="")
    result="No Comment!";
  else {
    if((x=findproject(project))<0)
      result="Project &quot;"+project+"&quot; not found";
    else {
      array d=({ ([ "time":time(), "user":user, "text":comment-"\r" ]) });
      mapping m=masterfile[x];
      if(m->comments==0)
        m->comments=d;
      else
        m->comments+=d;

      masterfile[x]=m;

      result=savedb();
    }
  }
  return result;
}
/*
 * Server hooks follow
 */

mixed find_file(string path, object id) {

  // check to see if the user is authenticated!
  if(!(id->auth && id->auth[0]))
    return http_auth_required("Whiteboard for "+QUERY(mountpoint));
  string user = id->auth[1];

  array a=QUERY(allowedusers)-({""});
  if(sizeof(a)>0)
    if(search(a,user)<0)
      return http_auth_required("Whiteboard for "+QUERY(mountpoint));

  string result="";
  string file="";
  mixed returncode;
  string project="";
  int tt;
  int ts=time();
  int prj;

  path = simplify_path(path);
  // Remove leading "/" from path, if it exists
  if(path[0..0]=="/")
    path=path[1..sizeof(path)-1];
  if(path=="")
      return -1;

  // Split the request into path & file.
  array x=(path)/"/";
  file=x[sizeof(x)-1];

  //Handle the various methods now...
  switch(id->method) {
    case "GET":
    case "HEAD":
    case "POST":
      if(sizeof(x)<2) {             //are we in the root directory?
        switch(file) {
          case "index.html":        //Print list of things user can do.
            result=makeindex("", user);
            break;
          case "createnewproject.html":
            result=editproject(user, -1, id);
            break;
          case "saveproject.html":
            id->variables->new="new";
            result=saveinput(id->variables->project, user, id);
            if(result=="")
              return http_redirect(QUERY(mountpoint)+"/"+project,id);
            break;
          }
        if(findproject(file)>=0)
          return -1;
      }
      else {
        project=x[0];               //first part of path is the project to work on.

        if((prj=findproject(project))<0)
          return 0;
        if(file=="")
          return -1;

        mapping p=masterfile[prj];
        if(p->users!=0) {
          if(sizeof(p->users-({""}))!=0) {
            a=p->users-({""})+({p->creator});
            if(search(a,user)<0)
              return http_auth_required("Whiteboard for "+QUERY(mountpoint));
          }
        }

        switch(file) {
          case "index.html":        //Display page for editing.
            result=makeindex(project, user);
            break;
          case "editproject.html":
              result=editproject(user, prj, id);
            break;
          case "addcomment.html":
            if(id->variables->comment) {
              result=addcomment(project, user, id->variables->comment);
              if(result=="")
                return http_redirect(QUERY(mountpoint)+"/"+project,id);
            }
            else result=makeindex(project, user);
            break;
          case "save.html":        //generic save routine. Save whatever user sent
            result=saveinput(project, user, id);
            if(result=="")
              return http_redirect(QUERY(mountpoint)+"/"+project,id);
            break;
          break;
          default:                          //check to see if it's second level.
            return 0;
            break;
        }
      }
      break;
    case "PUT":
      return http_low_answer(405, "Method not allowed");
      break;
    default:
      return http_low_answer(400, "Bad Request");
      break;
  }

  if(result=="")
    return 0;
  else
    return http_string_answer(result);
}

void|array(string) find_dir(string path, object id) {
  return 0;
}

void|array(int) stat_file(string path, object id) {
  return ({0,-2, 0, 0, 0, -1, -1});
}

string query_location()
{
  return query("mountpoint");
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: mountpoint
//! Location of module in virtual filesystem.
//!  type: TYPE_LOCATION
//!  name: Location of module in virtual file system.
//
//! defvar: masterfile
//! This is the file that holds the whiteboard info.  It must be readable and writable by Roxen.
//!  type: TYPE_FILE
//!  name: Location of master data file
//
//! defvar: allowedusers
//! Users listed here will have access to this whiteboard, they will be able to add, delete, and modify data.  Leaving this blank will make this whiteboard accessible to anyone (although users will still be required to login.
//!  type: TYPE_STRING_LIST
//!  name: Users allowed to access this whiteboard
//
//! defvar: expiretime
//! This is the amount of time (in hours) before closed projects get expunged from the database.
//!  type: TYPE_INT
//!  name: Time before closed projects get deleted.
//
