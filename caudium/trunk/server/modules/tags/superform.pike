/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Based on Superform © NSL Internet / shez@nsl.net.
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
/*
 * $Id$
 */
//
//! module: Superform
//!  This tag extends html forms to add new widget type, provide
//!  verification functions, and generally make dealing with
//!  complex input easiers. Eventually it will provide widgets for
//!  all common database type.
//! inherits: module
//! inherits: caudiumlib
//! type: MODULE_PARSER|MODULE_FIRST
//! cvs_version: $Id$
//! todo: finish doc/examples
//
constant cvs_version="$Id$";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "caudiumlib";


static private int loaded;

string demo_widget(string widget,string descr) ;
mixed tag_input(string tag_name, mapping args,
		 object request_id, object f,
		 mapping defines, object fd) ;
int|string luhn_check(string number) ;

static private string doc()
{
  string doc="This tag extends html forms to add new widget types, "+
    "provide verification functions, and generally make dealing with <br>"+
    "complex input easier.  Eventually it will provide widgets for all "+
    "common database types.<br><p>"+
    "<b>Usage:</b> Below shows an example demonstrating most features<br>"+
    "Number of hits: {accessed}{br}<br>"+
    "This should go up by 1000 if the input is good.{br}<br>"+
    "{if variable=sformerror}{h1}There is an error in your form input: "+
    "{insert variable=sformerror}{/h1}{/if}<br>"+
    "{formoutput}<br>"+
    "{sform action=/here.html erroraction=here.html}<br>"+
    "{input type=text name=number error='Not an Email'<br>"+
    "match='::email::'<br>"+
    "value='#number:quote=none#' mandatory=True}<br>"+
    "{input name=name1 type=bool value=f}{br}<br>"+
    "{input type=submit}<br>"+
    "{rxml}<br>"+
    "{comment}This is only executed if the verification stage succeeded{/comment}<br>"+
    "{accessed add=1000 file='here.html'}<br>"+
    "{/rxml}<br>"+
    "{/sform}<br>"+
    "{/formoutput}<br><p><h1>New widgets</h1><form><table>"+
    demo_widget("<input type=text name=text value='text' mandatory=t|f "
		"match=\".*\" error=\"Text doesn't match _anything_\">",

		"Returns you to the erroraction URL if the variable "
		"doesn't match the regular expression specified by attribute "
		"`match.'  The variable sformerror will be set to the "
		"attribute `error' in this case Returns a credit card style "
		"expiry date.  Lets you ")+
    
    demo_widget("<input type=expirydate name=date value='03/02'>",
		"Returns a credit card style expiry date.  Lets you "
		"select from any year in the next seven years.  "
		"The number of years be overridden with the `years' "
		"attribute")+
    demo_widget("<input type=cardnumber name=number>",
		"Performs a LUHN checksum on the returned number to ensure "
		"it is a valid credit card number")+
    demo_widget("<input type=bool name=boolean value=t>",
		"Returns `t' or `f'")+
    demo_widget("<input type=select name=selectlist list=\"1,2,3,4,5\" value=1>",
		"Allows simple drop down boxes to be created in a more "
		"straightforward way then standard.  The separator for list can be overidden with the `sep' attribute")+
    "</table></form>";
  return replace(doc,({"{","}"}),({"&lt;","&gt;"}));
}

string demo_widget(string widget,string descr) {
  string p;
  p="<tr align=left><th>"+replace(widget,({"<",">"}),({"{","}"}))+"</th><td>";
  p+=parse_html(widget, ([ "input" : tag_input ]),([]));
  p+="</td><td>"+descr+"</td></tr>";
  // strip out new lines cos they break things??
  return replace(p,({"\n"}),({""}));
}

// store the success rxml here rather than pass it as form 
// variable cos we don't want people to be able to exucute
// arbitary rxml just be asking for the correct URL...
mapping (int:string) rxmlsession=([]);

void create() {
 defvar("regexps", 
	"::int::\t[0-9]+\n"
	"::float::\t[0-9]+[.][0-9]+\n"
	"::email::\t[a-zA-Z.\\-0-9]+@[a-zA-Z.\\-0-9]+\n"
	"::money::\t[0-9]+[.][0-9][0-9]\n",
	"Predefined Regular expressions", TYPE_TEXT_FIELD,
	"In the match strings each of the fixed strings on the left will "
	"be replaced with the regular expression on the right before "
	"carrying out any pattern matching.  A single tab should be used as "
	"a separator.  N.B. Pike regexps are slightly different to those in "
	"some other languages (e.g. perl)");
}

// How can I change this with Caudium constant thing to support
// varibles ? - Xavier
mixed *register_module()
{
  return ({ 
    MODULE_PARSER|MODULE_FIRST,
      "Superform", 
      doc(),
      ({}), 1, });
}

void start(int num, object configuration)
{
  loaded = 1;
}

//! tag: input
//!  The forms &lt;input&gt; tag used inside of &lt;sform&gt; container
//! arg: type
//!  The type used, standart forms type can be used, but extended ones
//!  are bool, expirydate, cardnumder which can support extended actions
//! arg: error
//!  Text to send when there is an error
//! arg: match
//!  The regexp used to verify (see configuration interface).
//! arg: mail
//!  Check this is a really a email and there is really a MX on this
//!  mail. Warning a match="::email::" is need to enable the check.
//! arg: mailerror
//!  The message to send if the mail check fails.
//! todo: Add a email type that verify, domain, mx etc... :)
mixed tag_input(string tag_name, mapping args,
		 object request_id, object f,
		 mapping defines, object fd)
{
  string result,hidden,type;
  
  if (args->type && args->type=="bool") {
    result="<default name=\""+args->name+"\" value=\""+args->value+"\">"+
      "<select name=\""+args->name+"\" >"+
      "<option value=t>True<option value=f>False</select></default>";
    return result;
  }
  
  if (args->type && args->type=="select") {
    result="<default name=\""+args->name+"\" value=\""+args->value+"\">"+
      "<select name=\""+args->name+"\" >";
    if (args->list && args->list/(args->sep||",")) {
      foreach(args->list/(args->sep||","),string item) 
	result+=sprintf("<option>%s</option>",item); }
    result+="</select></default>";
    return result;
  }
  
  // two select boxes, one for month one for years....
  // can use the attribute years=nyears to sepcify how far in the future to
  // look and value=mm/yy to preset it.
  if (args->type && args->type=="expirydate") {
    string t="<default name='sform_expire_month_#name#' value='#month#'>"
      "<select name='sform_expire_month_#name#'>"
      "<option>01<option>02<option>03<option>04<option>05<option>06"
      "<option>07<option>08<option>09<option>10<option>11<option>12"
      "</select></default>/"
      "<default name='sform_expire_year_#name#' value='#year#'>"
      "<select name='sform_expire_year_#name#' value='#year#'>";
    // get this year 
    int thisyear=((localtime(time(1))->year)+1900);
    // get the biggest year
    int biggestyear=abs((int)args->years||7);
    if (biggestyear > 40) biggestyear=40;
    for (int i=thisyear; i<(thisyear+biggestyear); i++) 
      t+="<option>"+sprintf("%02d",(i%100))+"</option>";
    t+="</select></default>";
    
    string month,year; 
    if (args->value && sizeof(args->value/"/")==2) {
      month=(args->value/"/")[0]; 
      year=(args->value/"/")[1];
    } else { month="1"; year=sprintf("%02d",(thisyear+2)% 100); }
    return replace(t,
		   ({"#name#","#month#","#year#"}),
		   ({(string)args->name,(string)month,(string)year}));
  }

  if (args->type && args->type=="cardnumber") {
    type="cardnumber"; args->type="text";
  }
  
  result="<input"; 
  // build up the <input tag, removing the new attributes
  foreach(indices(args) - ({ "match", "error","mandatory"}),
	  string attr) {
    string val = args[attr];
    if (val != attr) {
      result += " "+attr+"=\""+val+"\"";
    } else {
      result += " "+attr;
    }
  }               
  result+=">";
  if (args->match) {
    result+="<input type=hidden name=sform_match_"+
      args->name+" value=\""+args->match+"\">\n";
    if (args->match == "::email::") {
      if (args->mail)
        result +="<input type=hidden name=sform_mail_"+
          args->name+" value=\""+args->mail+"\">\n";
      if (args->mailerror)
        result +="<input type=hidden name=sform_mailerror_"+
	  args->name+" value=\""+args->mailerror+"\">\n";
    }
  }
  if (args->error) 
    result+="<input type=hidden name=sform_error_"+
      args->name+" value=\""+args->error+"\">\n";
  if (args->mandatory)
    result+="<input type=hidden name=sform_mandatory_"+
      args->name+" value=\""+args->mandatory+"\">\n";
  if (type=="cardnumber") 
    result+="<input type=hidden name=sform_type_"+
      (args->name||"")+" value=\"cardnumber\" >\n";

  // as a mapping so it dosn't get re-parsed
  return ({result});
}

// simply stuff the contents somewhere where we can get it later...

//! container: rxml
//!  Execute the rxml stuff in &lt;rxml&gt; .. &lt;/rxml&gt; when
//!  all verification stage have succeeded.
//! attribute: debug
//!  Debug the code
//! note: this tag is only avaible in &lt;sform&gt; container
string tag_rxml(string tag_name, mapping args, string contents,
		object rid, object f, mapping defines, object fd) {
  rid->misc->successrxml=contents;
  if (args->debug) { 
	return "<input type=hidden name=sform_rxml_debug value=t>";
  }
}

//! container: sform
//!  Extended form tag.
//! arg: action
//!  Where to go (URL) when the form is executed (and when all
//!  verification stage are successfull). 
//! arg: erroraction
//!  Where to go (URL) when the form has an error. The variable
//!  sformerror, is then setup with the error that fails the
//!  the correct execution of the form.
//! arg: multi_separator
//!  To be documented
//! arg: method
//!  The HTTP method used for this form
string tag_sform(string tag_name, mapping args, string contents,
		 object request_id, object f,
		 mapping defines, object fd) {
  
  string multi_separator = args->multi_separator || "\000";
  int rand=random(100000);

  contents=parse_html(contents, ([ "input" : tag_input ]),(["rxml":tag_rxml]),request_id);
  
  // a really messy bit of code to get the current URL
  string here=request_id->not_query;
  
  //  put the rxml in a mapping for later use...
  if (request_id->misc->successrxml) 
    rxmlsession[rand]=request_id->misc->successrxml;

  return "<form method="+(args->method||"post")+" action=\""+
    (args->action||here)+"\">"+contents+
    "<input type=hidden name=sform_errorpage value=\""+
    (args->erroraction||here)+"\">\n"+
    "<input type=hidden name=sform_rand value=\""+rand+"\"></form>";
}                                
  
// we do this routine if everything verified OK
mapping success(object rid) {
  // if theres any rxml to do then do it and then
  // delete its entry
  int rand=(int)rid->variables["sform_rand"];
  if (rxmlsession[rand]) {
    if (rid->variables["sform_rxml_debug"]) 
	perror("RXML code %s\nRXML result: %s\n",
		rxmlsession[rand],
		parse_rxml(rxmlsession[rand],rid));
    else parse_rxml(rxmlsession[rand],rid);
    m_delete(rxmlsession,rand);
  }
  // delete all the sform variables 
  foreach (indices(rid->variables),string v)
    if (sscanf(v,"sform_%*s"))m_delete(rid->variables,v);
}

mapping failed(object rid) {

  // delete the rxml
  int rand=(int)rid->variables["sform_rand"];
  if (rxmlsession[rand]) m_delete(rxmlsession,rand);
  
  // this is the location we want to go to
  string to=rid->variables["sform_errorpage"];
  // delete all the sform variables 
  foreach (indices(rid->variables),string v)
    if (sscanf(v,"sform_%*s"))m_delete(rid->variables,v);

  // there are two possibilities, either it is a full URL
  // whereupon we have to do a clunky http redirect,
  // or it is just a path whereupon we can do a clunky internal
  // redirect :)
  if((strlen(to) > 6 &&       
      (to[3]==':' || to[4]==':' ||
       to[5]==':' || to[6]==':'))) {
    // external redirect
    to=replace(to, ({ "\000", " " }), ({"%00", "%20" }));
    string q="";
    foreach (indices(rid->variables),string v) {
      q+="&"+v+"="+http_encode_string(rid->variables[v]);
    }
    to+="?"+q;
    // return a redirect.  We can't use http_redirect because that does
    // a http_encode_string on the whole url including any query
    return http_low_answer( 302, "")
      + ([ "extra_heads":([ "Location":to ]) ]); 
  } else {
    rid->raw_url = http_encode_string(to);
    rid->not_query = rid->scan_for_query(to);
  }
}

mapping query_container_callers()
{
  return( ([ "sform":tag_sform]));
}                        

string replace_predefined(string match) {
  array regexps=QUERY(regexps)/"\n";
  foreach(regexps,string p) {
    if (sizeof(p/"\t")!=2) continue;
    match=replace(match, (p/"\t")[0], (p/"\t")[1]);
  }
  return match;
}

// this cycles thru all the sform_variables 
// looking ones that are used by predifined widgets.
int process_widgets(object rid) {
  string var;
  foreach(indices(rid->variables),string v) {
    if (sscanf(v,"sform_expire_year_%s",var)) {
      rid->variables[var]=
	rid->variables["sform_expire_month_"+var]+"/"+
	rid->variables["sform_expire_year_"+var];
      continue;
    }
    if (rid->variables["sform_type_"+v] &&
	rid->variables["sform_type_"+v]=="cardnumber") {
      int|string result=luhn_check(rid->variables[v]);
      if (result !=1) {
	rid->variables["sformerror"]=result; return 1;
      }
    }
  }
  return 0;
}


// this gets called before anything else is done
// it allows us to check for requests using the magic
// sform url
mixed first_try(object rid)
{
  mixed match;
  string error,value,mail,mailerror,mandatory;
  int err=0;
  mixed tmp;
  if (!rid->variables["sform_rand"]) {
    return 0;
  }
  
  // process any predifined widgets we may have
  err=process_widgets(rid);
  if (err) { return failed(rid); } 

  // foreach form variable
  foreach (indices(rid->variables),string v) {
//    werror(sprintf("%O\n",rid->variables));
    // skip if it matches sform_*
    if (sscanf(v,"sform_%*s")) continue;
    match="sform_match_"+v;  // get the regexp
    error="sform_error_"+v;  // get the error
    mail="sform_mail_"+v;    // get the mail error if needed
    mailerror="sform_mailerror_"+v; // get the mail error message if needed
    mandatory="sform_mandatory_"+v;
    
    // is the value empty?
    if (rid->variables[v]&& 
	strlen(rid->variables[v])==0) { // empty value 
      if (rid->variables[mandatory] &&
	  lower_case(rid->variables[mandatory])[0]=='t') { // yes
	rid->variables["sformerror"]=
	  rid->variables[error]||"You must fill in the "+v+ " field."; 
	err=1; break; 
      } else { // not mandatory so just ignore.
	continue;
      }
    }

    // if there is a match to check...
    if (rid->variables[match]) {
      string pattern=rid->variables[match];
      string pattern2=rid->variables[match];
      function split;
      // replace any predifined expressions
      pattern=replace_predefined(pattern);
      // we want to make sure the regexp is of the form:
      // blah(stuff we want)blah
      if ((search(pattern,"(") && search(pattern,")"))) {
	pattern="("+pattern+")";
      }
      // strip leading and trailing spaces..
      pattern="^ *"+pattern+" *$";
      if (catch(match=Regexp(pattern)->split(rid->variables[v]))) {
	  err=1; rid->variables["sformerror"]="Bad regular expression "+
		   pattern; break; }
      if (match) {
//        werror(" ==> GOT IT <== " + match[0] + "\n");
//	werror("mail " + rid->variables[mail] + "\n");
//	werror("mailerror " + rid->variables[mailerror] + "\n");
//	werror("match " + pattern2 + "\n");
	if ((pattern2 == "::email::")&&(rid->variables[mail])) {
	  if(stringp(Protocols.DNS.client()->get_primary_mx((match[0]/"@")[1])))
            rid->variables[v]=match[0];
	  else {
	    err=1;
	    rid->variables["sformerror"]=
	      rid->variables[mailerror]||"There is no MX for this email ("+v+")";
	    break;
	  }
	}
	else  rid->variables[v]=match[0];
      }
      else { 
	err=1;
	rid->variables["sformerror"]=
	  rid->variables[error]||"There was an error in the field "+v;
	break; // error so break
      }
    }
  }
  if (err) { return failed(rid); } 
  else { return success(rid); }
}
 

// does a luhn check on the number.  From Henrik Grubbström's
// code posted on 15/9/97

int|string luhn_check(string number) {

  // remove spaces and dashes
  number = replace(number, ({ " ", "-" }), ({ "", "" }));

  if (replace(number, ({ "0","1","2","3","4","5","6","7","8","9" }),
	      ({ "","","","","","","","","","" })) != "") 
    return "Only digits, hyphens and spaces allowed in card numbers.";

  
  array digits = Array.map(reverse(number/""), 
		     lambda(string n) { return (int)n; });

  int* hash_function = ({ 0, 2, 4, 6, 8, 1, 3, 5, 7, 9 });

  for(int i=1; i<sizeof(digits); i+=2) {
    digits[i] = hash_function[digits[i]];
  }

  int sum = 0;
  foreach(digits, int d) {
    sum += d;
  }
  
  sum %= 10;
  
  if (sum) return ("Invalid card number (LUHN check failed)");
  return 1;
}

/* START AUTOGENERATED DEFVAR DOCS */

//! defvar: regexps
//! In the match strings each of the fixed strings on the left will be replaced with the regular expression on the right before carrying out any pattern matching.  A single tab should be used as a separator.  N.B. Pike regexps are slightly different to those in some other languages (e.g. perl)
//!  type: TYPE_TEXT_FIELD
//!  name: Predefined Regular expressions
//
