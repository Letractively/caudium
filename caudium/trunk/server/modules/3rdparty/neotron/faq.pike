// This is an FAQ module. Defines tags to edit and show questions in a
// Frequently Asked Questions Fashion.

constant cvs_version="$Id$";

inherit "module";
inherit "roxenlib";
#include <module.h>

#define srcencode(x) replace(x, ({ "&", "<", ">", "\"" }),({ "&amp;", "&lt;", "&gt;", "&quot;" }))
#define REDIR "<redirect to=\""+id->not_query+"?r="+time()+"&a=edit&faqname="+http_encode_url(v->faqname)+"\">"

#define DBFIELDS "(\
ordernr INT UNSIGNED NOT NULL, KEY(ordernr),\
id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,\
created INT UNSIGNED NOT NULL,\
modified TIMESTAMP NOT NULL, \
question VARCHAR(128) NOT NULL,\
answer BLOB NOT NULL, \
faqname VARCHAR(16) NOT NULL,  KEY(faqname)\
)"

string version;

string help() {
  return
    "This tag is used to display an FAQ previously created with the "
    "&lt;editfaq&gt; tag. Currently the following arguments are "
    "recognised:<p><dl>"
    "<dt><b>faq[=FAQ name]</b>"
    "<dd>Which FAQ to use. If not present, <i>default</i> will be used."
    "<dt><b>foldtext</b>"
    "<dd>The text displayed as the link which will hide all answers. "
    "The default is \"<i>Hide answers</i>\"."
    "<dt><b>unfoldtext</b>"
    "<dd>The text displayed as the link which will show all answers. "
    "The default is: \"<i>Show all answers</i>\""
    "<dt><b>nofoldtext</b>"
    "<dd>If present the show/hide all links won't be shown at all."
    "<dt><b>help</b>"
    "<dd>Show this help text.</dl>";
}

array register_module()
{
  return ({
    MODULE_PARSER,
    "Frequently Asked Questions module",
    "This is an FAQ module. Defines tags to edit and show questions in a "
    "Frequently Asked Questions fashion. The module stores its questions a "
    "SQL database. MySQL was used for development but using a different "
    "SQL server should be possible. It is used with the &lt;showfaq&gt; and "
    "&lt;editfaq&gt; tags. For more information call the tags with <i>help</i> "
    "as one of the arguments.",0,1
    });
}

void create()
{
  defvar("sqlurl", "mysql://localhost/faq", "SQL Database URL", TYPE_STRING,
	 "The URL specifing what SQL database to use." );
}

mapping query_tag_callers()
{
  return ([
    "showfaq": tag_showfaq,
    "editfaq": tag_editfaq
  ]);
}

object get_sql() {
  object db;
  array err = catch {
    db = Sql.sql(QUERY(sqlurl));
  };
  if(err)
  {
    report_error("FAQ Module: Failed to get SQL object.\n"+
		 describe_backtrace(err));
    return 0;
  }
  err = catch {
    db->query("create table faq "+ DBFIELDS);
  };
  return db;
}

void start()
{
  sscanf(cvs_version, "%*s.pike,v %s %*s", version);
  version = sprintf("<p align=right><font size=1>FAQ Module "
		    "by <a href=\"mailto:david@hedbor.org\">"
		    "david@hedbor.org</a> version %s.</font><p>",
		    version);
}

string tag_showfaq(string t, mapping args, object id)
{
  mapping v = id->variables;
  array res;
  string list="<ol>", out = "";
  object db;
  int i;
  if(args->help) 
    return help();

  
  db = get_sql();
  if(!db)
    return "<b>Error: Couldn't connect to database server. See error log for "
      "details.</b>";
  if(!args->unfoldtext) args->unfoldtext = "Show all answers";
  if(!args->foldtext)   args->foldtext   = "Hide answers";
  if(!args->faq)	args->faq        = "default";
  
  array err = catch {
    res = db->query("select * from faq where faqname = '"+db->quote(args->faq)+
		    "' order by ordernr");
  };
  if(!res || !sizeof(res) || err)
  {
    report_error("FAQ Module: Failed to fetch FAQ entries from database.\n"+
		 "SQL Server Error: "+(db->error()||"None"));
		 
    return "<b>Error: Couldn't fetch entries from database.</b>";
  }
  
  
  foreach(res, mapping faq) {
    ++i;
    if(v->all || v->num == faq->id)
      out += sprintf("<dt><a name=\"%s\"><h3>%d. %s</h3></a>\n<dd>%s\n",
		     faq->id, i, faq->question, faq->answer);
    if(v->all)
      list += sprintf("<li><a href=\"%s#%s?all=1\">%s</a>\n",
		      id->not_query, faq->id, faq->question);
    else
      list += sprintf("<li><a href=\"%s?num=%s\">%s</a>\n",
		      id->not_query, faq->id, faq->question);
  }
  if(strlen(out))
    out = "<dl><hr>"+out+"</dl>";
  list += "</ol>";
  if(!args->nofoldtext) {
    if(v->all)
      list += "<p><a href=\""+srcencode(id->not_query)+"\">"+
	args->foldtext+"</A>";
    else
      list += "<p><a href=\""+srcencode(id->not_query)+"?all=1\">"+
	args->unfoldtext+"</a>";
  }
  return list + out + version;
}

string edit_form(object id, object db)
{
  mapping v = id->variables;
  int ok;
  string out =
    sprintf("<h3>Edit FAQ Message</h3><form action=\"%s\" method=\"GET\">"
	    "<input type=\"hidden\" name=\"a\" value=\"e2\">"
	    "<input type=\"hidden\" name=\"faqname\" value=\"%s\">",
	    srcencode(id->not_query), srcencode(v->faqname));
  
  if(v->id) {
    array res, err;
    err = catch {
      res = db->query("select * from faq where id="+v->id);
    };
    if(!err && res && sizeof(res)) {
      ok = 1;
      out += sprintf("<input type=\"hidden\" name=\"id\" value=\"%s\">"
		     "<b>Question:</b> "
		     "<input size=66 name=question value=\"%s\">"
		     "<p><b>Answer:</b><br>"
		     "<textarea name=answer cols=65 rows=10 wrap=soft>%s"
		     "</textarea>",
		     srcencode(v->id),
		     srcencode(res[0]->question),
		     srcencode(res[0]->answer));
    }
  }
  if(!ok)
    out += ("<b>Question:</b> <input size=55 name=question>"
	    "<p><b>Answer:</b><br>"
	    "<textarea name=answer cols=65 rows=10 wrap=soft></textarea>");
  return out +"<p><input type=submit> <input type=reset></form>";
}


string tag_editfaq(string t, mapping args, object id)
{
  mapping v = id->variables;
  array res,err;
  string list="<ol>", out = "";
  object db;
  int i;
  if(args->help)
    return
      "This tag doesn't take any arguments. It might be a good idea to use "
      "this tag only on a password protected page (Roxen's builtin auth db, "
      "htaccess or any other method) to avoid unauthorized people from editing "
      "the FAQs.";
  if(!(db = get_sql()))
    return "<b>Error: Couldn't connect to database server. See error log for "
      "details.</b>";
  switch(v->a) {
   case "edit":
     if(!strlen(v->faqname))
       return "<b>Sorry, the specified FAQ name isn't valid. It has to be "
	 "one character or longer!</b>"+version;
     err = catch {
      res = db->query("select * from faq where faqname='"+
		      db->quote(v->faqname)+"' order by ordernr");
    };
    if(err)
    {
      report_error("FAQ Module: Failed to fetch FAQ entries from database.\n"+
		   "SQL Server Error: "+(db->error()||"None") +"\n");
		 
      return "<b>Error: Couldn't fetch entries from database.</b>";
    }
    out = sprintf("<h3>Edit Questions for %s</h3><dl>", 
		  srcencode(v->faqname));
    
    foreach(res||({}), mapping faq) {
      i++;
      out += sprintf("<dt><b>%d: %s (unique ID: %s)</b><dd>%s<p>"
		     "<a href=\"%s?a=up&id=%s&faqname=%s&on=%s\">Move Up</a> - "
		     "<a href=\"%s?a=dn&id=%s&faqname=%s&on=%s\">Move Down</a> - "
		     "<a href=\"%s?a=e1&id=%s&faqname=%s\">Edit</a> - "
		     "<a href=\"%s?a=d&id=%s&faqname=%s\">Delete</a>"
		     "<dt><hr noshade size=1>",
		     i, faq->question, faq->id, faq->answer, 
		     srcencode(id->not_query),
		     faq->id, srcencode(v->faqname), faq->ordernr,
		     srcencode(id->not_query),
		     faq->id, srcencode(v->faqname), faq->ordernr,
		     srcencode(id->not_query),
		     faq->id, srcencode(v->faqname),
		     srcencode(id->not_query),
		     faq->id, srcencode(v->faqname)
		     );
    }
    return sprintf("%s</dl><h3>"
		   "<a href=\"%s?faqname=%s&a=e1\">Enter new Question</a>%s",
		   out, srcencode(id->not_query), srcencode(v->faqname),
		   version);
    
   case "dn":
    catch {
      res = db->query("select id,ordernr from faq where faqname='"+
		      db->quote(v->faqname)+"' and ordernr > "+
		      v->on +" order by ordernr limit 1");
      if(res && sizeof(res)) {
	db->query(sprintf("update faq set ordernr=%s where id=%s",
			  res[0]->ordernr, v->id));
	db->query(sprintf("update faq set ordernr=%s where id=%s",
			  v->on, res[0]->id));
      }
    };
    return REDIR;

   case "d":
    catch {
      db->query("delete from faq where faqname='"+db->quote(v->faqname)+"' "
		"and id="+v->id);
    };
    return REDIR;
    
   case "up":
    catch {
      res = db->query("select id,ordernr from faq where faqname='"+
		      db->quote(v->faqname)+"' and ordernr < "+
		      v->on +" order by ordernr DESC limit 1");
      if(res && sizeof(res)) {
	db->query(sprintf("update faq set ordernr=%s where id=%s",
			  res[0]->ordernr, v->id));
	db->query(sprintf("update faq set ordernr=%s where id=%s",
			  v->on, res[0]->id));
      }
    };
    return REDIR;
   case "e1":
    return edit_form(id, db) + version;
   case "e2":
    catch { 
      if(v->id) 
	db->query(sprintf("update faq set question='%s',answer='%s' "
			  "where id=%s",
			  db->quote(v->question),
			  db->quote(v->answer),
			  v->id));
      else {
	res = db->query("select max(ordernr) as max from faq where "
			"faqname='"+db->quote(v->faqname)+"'");
	db->query(sprintf("insert into faq set question='%s',answer='%s',"
			  "faqname='%s',ordernr=%d", 
			  db->quote(v->question),
			  db->quote(v->answer),
			  db->quote(v->faqname), (int)(res[0]->max) +1));
      }
    };
    return REDIR;
    
   default:
    err = catch {
      res = db->query("select distinct faqname from faq order by faqname");
    };
    if(!res || !sizeof(res))
    {
      report_error("FAQ Module: Failed to fetch FAQ list from database.\n"+
		   "SQL Server Error: "+(db->error()||"None") +"\n");
      return "<b>Failed to fetch FAQ list from database "
	"(no entries or error).<br>SQL Server Error: "+
	(db->error()||"None") +"<p>";
    }
    out = sprintf("<h3>Please select FAQ to edit:</h3><form action=\"%s\" "
		  "method=GET><input type=\"hidden\" name=\"r\" "
		  "value=\"%d\"><input type=\"hidden\" name=\"a\" "
		  "value=\"edit\"><select name=\"faqname\">",
		  srcencode(id->not_query), time());
    foreach(res->faqname, string faq) {
      out += "  <option>"+srcencode(faq)+"</option>\n";
    }
    out += sprintf("</select> <input type=\"submit\" "
		   "value=\"Edit QAs for selected FAQ\"></form><form action=\"%s\" "
		   "method=\"GET\"><input type=\"hidden\" name=\"a\" value=\""
		   "edit\"> <input type=text size=30 name=faqname>"
		   "<input type=submit value=\"Create new FAQ\"></form>",
		   id->not_query);
  }
  if(strlen(out))
    return out + version;
  return "";
}
