/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2001 The Caudium Group
 * Copyright © 2001 Davies, Inc
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
 * See http://www.daviesinc.com/modules/ for more informations.
 */

#include <module.h>
inherit "module";
inherit "caudiumlib";

//! module: JavaMenu Module
//!  This module wraps around a JavaScript that does the pull-down menus.
//!  The idea was to make something so that a webmaster could easily alter 
//!  these menus without having to have the webmaster deal with cryptic
//!  JavaScripting.  Not all features in the original Java Script have been
//!  enabled in this version of the wrapper. <p />
//!  Original:  Angus Turnbull<br />
//!  Web Site:  http://gusnz.cjb.net<p />
//!  This script and many more are available free online at<br />
//!  The JavaScript Source!! http://javascript.internet.com<p />
//!  Javascript Caudium Wrapper written by Chris Davies<br />
//!  Web Site: <a href="http://daviesinc.com/javamenu/">
//!  http://daviesinc.com/javamenu/</a><p />
//!  This is what a demo page would look like:<p/>
//!  <tt>&lt;HEAD&gt;<br />
//!  &lt;menu defback="#3333ff" defover = "#000000" textcolor="yellow"&gt;<br />
//!  &lt;header name="test" url="urlcangohere"&gt;<br />
//!  &lt;item name="asdf" url="asdf" /&gt;<br />
//!  &lt;item name="asdf" url="asdf" /&gt;<br />
//!  &lt;item name="line2" url="url2" /&gt;<br />
//!  &lt;/header&gt;<br />
//!  &lt;header name="test2"&gt;<br />
//!  &lt;item name="asdf" url="asdf" /&gt;<br />
//!  &lt;item name="line2" url="url2" /&gt;<br />
//!  &lt;/header&gt;<br />
//!  &lt;/menu&gt;<br />
//!  &lt;/HEAD&gt;<p />
//!  &lt;BODY marginwidth="0" marginheight="0" style="margin: 0" onLoad="writeMenus()" onResize="if (isNS4) nsResizeHandler()"&gt;<br />
//!  &lt;table bgcolor="#006666" width="100%" border="0" cellpadding="0" cellspacing="0"&gt;<br />
//!  &lt;tr&gt;&lt;td height="17"&gt;&lt;font size="1"&gt;&nbsp;&lt;/font&gt;&lt;/tdi&gt;&lt;/tr&gt;&lt;/table&gt;<br />
//!  &lt;p&gt;<br />
//!  &lt;/BODY&gt;
//! type: MODULE_PARSER
//! inherits: module
//! inherits: caudiumlib
//! cvs_version: $Id$

constant module_type = MODULE_PARSER;
constant module_name = "JavaMenu Module";
constant module_version = "javamenu.pike v0.1 5/10/2001";
constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_doc  = #"
This module wraps around a JavaScript that does the pull-down menus.  The idea was to make something
so that a webmaster could easily alter these menus without having to have the webmaster deal with 
cryptic JavaScripting.  Not all features in the original Java Script have been enabled in this version of
the wrapper.
<p>
Original:  Angus Turnbull<br>
Web Site:  http://gusnz.cjb.net<p>

This script and many more are available free online at<br>
The JavaScript Source!! http://javascript.internet.com<p>

Javascript Caudium Wrapper written by Chris Davies<br>
Web Site: <a href=\"http://daviesinc.com/javamenu/\">http://daviesinc.com/javamenu/</a><p>

This is what a demo page would look like:<p>
&lt;HEAD><br>
&lt;menu defback=\"#3333ff\" defover = \"#000000\" textcolor=\"yellow\"><br>
&lt;header name=\"test\" url=\"urlcangohere\"><br>
&lt;item name=\"asdf\" url=\"asdf\" /><br>
&lt;item name=\"asdf\" url=\"asdf\" /><br>
&lt;item name=\"line2\" url=\"url2\" /><br>
&lt;/header><br>
&lt;header name=\"test2\"><br>
&lt;item name=\"asdf\" url=\"asdf\" /><br>
&lt;item name=\"line2\" url=\"url2\" /><br>
&lt;/header><br>
&lt;/menu><br>
&lt;/HEAD><p>

&lt;BODY marginwidth=\"0\" marginheight=\"0\" style=\"margin: 0\" onLoad=\"writeMenus()\" onResize=\"if (isNS4) nsResizeHandler()\"><br>
&lt;table bgcolor=\"#006666\" width=\"100%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><br>
&lt;tr>&lt;td height=\"17\">&lt;font size=\"1\">&nbsp;&lt;/font>&lt;/td>&lt;/tr>&lt;/table><br>
&lt;p><br>
&lt;/BODY><br>
";
constant module_unique = 1;

mapping query_tag_callers()
{
  return ([ "item":tag_item, ]);
}
mapping query_container_callers() 
{ 
  return (["menu":container_menu,"header":container_header, ]); 
}

string tag_item(string t, mapping m, object id)
{
  return("menu["+(id->misc->javamenumain)+"]["+(id->misc->javamenusub++)+"] = new Item('"+(m->name?m->name:"")+"', '"+(m->url?m->url:"#")+"', '', defLength, 0, 0);");
}

string container_header(string t, mapping m, string contents, object id, mapping defines)
{
  id->misc->javamenusub = 1;
  return("menu[0]["+(++id->misc->javamenumain)+"] = new Item('  " + m->name + "', '"+(m->url?m->url:"#")+"', '', "+id->misc->titlewidth+", 10, "+(id->misc->javamenumain)+");\nmenu["+id->misc->javamenumain+"] = new Array();\nmenu["+id->misc->javamenumain+"][0] = new Menu(true, '>', 0, "+(m->startpos?m->startpos:22)+", "+(m->width?m->width:id->misc->titlewidth)+", defOver, defBack, 'itemBorder', 'itemText');"+contents);
}

string container_menu(string t, mapping m, string contents, object id, mapping defines)
{
  string javaout = javacode;
  id->misc->javamenumain = 0;
  id->misc->titlewidth = (m->width>40?m->width:60);
  string builtjava = "menu[0] = new Array();\nmenu[0][0] = new Menu(false, '', 5, 0, 17, defOver, defBack, '', 'itemText');\n";
  builtjava += parse_rxml(contents,id);

  javaout = replace(javaout,"%_TEXTCOLOR_%",(m->textcolor?m->textcolor:"#ffffff"));
  javaout = replace(javaout,"%_DEFOVER_%",(m->defover?m->defover:"#336699"));
  javaout = replace(javaout,"%_DEFBACK_%",(m->defback?m->defback:"#003366"));
  javaout = replace(javaout,"%_BUILTJAVA_%",builtjava);

  return(javaout);
}

string javacode = #"

<SCRIPT LANGUAGE=\"JavaScript\">
<!-- Original:  Angus Turnbull -->
<!-- Web Site:  http://gusnz.cjb.net -->

<!-- This script and many more are available free online at -->
<!-- The JavaScript Source!! http://javascript.internet.com -->

<!-- Javascript Caudium Wrapper written by Chris Davies -->
<!-- Web Site: http://daviesinc.com/javamenu/ -->

<!-- Begin
var isDOM = (document.getElementById ? true : false); 
var isIE4 = ((document.all && !isDOM) ? true : false);
var isNS4 = (document.layers ? true : false);
function getRef(id) {
if (isDOM) return document.getElementById(id);
if (isIE4) return document.all[id];
if (isNS4) return document.layers[id];
}
function getSty(id) {
return (isNS4 ? getRef(id) : getRef(id).style);
} 
var popTimer = 0;
var litNow = new Array();
function popOver(menuNum, itemNum) {
clearTimeout(popTimer);
hideAllBut(menuNum);
litNow = getTree(menuNum, itemNum);
changeCol(litNow, true);
targetNum = menu[menuNum][itemNum].target;
if (targetNum > 0) {
thisX = parseInt(menu[menuNum][0].ref.left) + parseInt(menu[menuNum][itemNum].ref.left);
thisY = parseInt(menu[menuNum][0].ref.top) + parseInt(menu[menuNum][itemNum].ref.top);
with (menu[targetNum][0].ref) {
left = parseInt(thisX + menu[targetNum][0].x);
top = parseInt(thisY + menu[targetNum][0].y);
visibility = 'visible';
      }
   }
}
function popOut(menuNum, itemNum) {
if ((menuNum == 0) && !menu[menuNum][itemNum].target)
hideAllBut(0)
else
popTimer = setTimeout('hideAllBut(0)', 500);
}
function getTree(menuNum, itemNum) {

itemArray = new Array(menu.length);

while(1) {
itemArray[menuNum] = itemNum;
if (menuNum == 0) return itemArray;
itemNum = menu[menuNum][0].parentItem;
menuNum = menu[menuNum][0].parentMenu;
   }
}

function changeCol(changeArray, isOver) {
for (menuCount = 0; menuCount < changeArray.length; menuCount++) {
if (changeArray[menuCount]) {
newCol = isOver ? menu[menuCount][0].overCol : menu[menuCount][0].backCol;
with (menu[menuCount][changeArray[menuCount]].ref) {
if (isNS4) bgColor = newCol;
else backgroundColor = newCol;
         }
      }
   }
}
function hideAllBut(menuNum) {
var keepMenus = getTree(menuNum, 1);
for (count = 0; count < menu.length; count++)
if (!keepMenus[count])
menu[count][0].ref.visibility = 'hidden';
changeCol(litNow, false);
}

function Menu(isVert, popInd, x, y, width, overCol, backCol, borderClass, textClass) {
this.isVert = isVert;
this.popInd = popInd
this.x = x;
this.y = y;
this.width = width;
this.overCol = overCol;
this.backCol = backCol;
this.borderClass = borderClass;
this.textClass = textClass;
this.parentMenu = null;
this.parentItem = null;
this.ref = null;
}

function Item(text, href, frame, length, spacing, target) {
this.text = text;
this.href = href;
this.frame = frame;
this.length = length;
this.spacing = spacing;
this.target = target;
this.ref = null;
}

function writeMenus() {
if (!isDOM && !isIE4 && !isNS4) return;

for (currMenu = 0; currMenu < menu.length; currMenu++) with (menu[currMenu][0]) {
var str = '', itemX = 0, itemY = 0;

for (currItem = 1; currItem < menu[currMenu].length; currItem++) with (menu[currMenu][currItem]) {
var itemID = 'menu' + currMenu + 'item' + currItem;

var w = (isVert ? width : length);
var h = (isVert ? length : width);

if (isDOM || isIE4) {
str += '<div id=\"' + itemID + '\" style=\"position: absolute; left: ' + itemX + '; top: ' + itemY + '; width: ' + w + '; height: ' + h + '; visibility: inherit; ';
if (backCol) str += 'background: ' + backCol + '; ';
str += '\" ';
}
if (isNS4) {
str += '<layer id=\"' + itemID + '\" left=\"' + itemX + '\" top=\"' + itemY + '\" width=\"' +  w + '\" height=\"' + h + '\" visibility=\"inherit\" ';
if (backCol) str += 'bgcolor=\"' + backCol + '\" ';
}
if (borderClass) str += 'class=\"' + borderClass + '\" ';

str += 'onMouseOver=\"popOver(' + currMenu + ',' + currItem + ')\" onMouseOut=\"popOut(' + currMenu + ',' + currItem + ')\">';

str += '<table width=\"' + (w - 8) + '\" border=\"0\" cellspacing=\"0\" cellpadding=\"' + (!isNS4 && borderClass ? 3 : 0) + '\"><tr><td align=\"left\" height=\"' + (h - 7) + '\">' + '<a class=\"' + textClass + '\" href=\"' + href + '\"' + (frame ? ' target=\"' + frame + '\">' : '>') + text + '</a></td>';
if (target > 0) {

menu[target][0].parentMenu = currMenu;
menu[target][0].parentItem = currItem;

if (popInd) str += '<td class=\"' + textClass + '\" align=\"right\">' + popInd + '</td>';
}
str += '</tr></table>' + (isNS4 ? '</layer>' : '</div>');
if (isVert) itemY += length + spacing;
else itemX += length + spacing;
}
if (isDOM) {
var newDiv = document.createElement('div');
document.getElementsByTagName('body').item(0).appendChild(newDiv);
newDiv.innerHTML = str;
ref = newDiv.style;
ref.position = 'absolute';
ref.visibility = 'hidden';
}

if (isIE4) {
document.body.insertAdjacentHTML('beforeEnd', '<div id=\"menu' + currMenu + 'div\" ' + 'style=\"position: absolute; visibility: hidden\">' + str + '</div>');
ref = getSty('menu' + currMenu + 'div');
}

if (isNS4) {
ref = new Layer(0);
ref.document.write(str);
ref.document.close();
}

for (currItem = 1; currItem < menu[currMenu].length; currItem++) {
itemName = 'menu' + currMenu + 'item' + currItem;
if (isDOM || isIE4) menu[currMenu][currItem].ref = getSty(itemName);
if (isNS4) menu[currMenu][currItem].ref = ref.document[itemName];
   }
}
with(menu[0][0]) {
ref.left = x;
ref.top = y;
ref.visibility = 'visible';
   }
}

var menu = new Array();

var defOver = '%_DEFOVER_%', defBack = '%_DEFBACK_%';

var defLength = 22;

%_BUILTJAVA_%

var popOldWidth = window.innerWidth;
nsResizeHandler = new Function('if (popOldWidth != window.innerWidth) location.reload()');

if (isNS4) document.captureEvents(Event.CLICK);
document.onclick = clickHandle;

function clickHandle(evt)
{
 if (isNS4) document.routeEvent(evt);
 hideAllBut(0);
}

function moveRoot()
{
 with(menu[0][0].ref) left = ((parseInt(left) < 100) ? 100 : 5);
}
//  End -->
</script>

<style>
<!--

.itemBorder { border: 1px solid black }
.itemText { text-decoration: none; color: %_TEXTCOLOR_%; font: 12px Arial, Helvetica }

-->
</style>
";
