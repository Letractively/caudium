/* -*-Pike-*-
 *
 * Caudium - An extensible World Wide Web server
 * Copyright © 2003 The Caudium Group
 * Copyright © 2003 Stephen R. van den Berg, The Netherlands.
 *                  <srb@cuci.nl>
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
 * $Id$
 */

/*
 * File licensing and authorship information block.
 *
 * Version: MPL 1.1/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developer of the Original Code is
 *
 *  Stephen R. van den Berg, The Netherlands. <srb@cuci.nl>
 *
 * Portions created by the Initial Developer are Copyright (C)
 *  Stephen R. van den Berg, The Netherlands. <srb@cuci.nl>
 *  Xavier Beaudouin & The Caudium Group. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the LGPL, and not to allow others to use your version
 * of this file under the terms of the MPL, indicate your decision by
 * deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL or the LGPL.
 *
 * Significant Contributors to this file are:
 *
 */


//! This is a roxen module which provides SNMP get/set facilities.
//! @note
//!   You can define a SNMP_DEBUG to get debug messages into Caudium
//!   log file.

#define _(X,Y)  _DEF_LOCALE("mod_snmp",X,Y)
#define _ok id->misc->defines[" _ok"]

//! 
constant cvs_version= "$Id$";


//#define SNMP_DEBUG 1
#ifdef SNMP_DEBUG
# define SNMP_WERR(X) report_debug("SNMP module: %O\n",(X))
#else
# define SNMP_WERR(X)
#endif

//! Get a snmp variable
array snmpget(mapping args)
{ Protocols.SNMP.protocol handler=Protocols.SNMP.protocol((int)args->port||161,
   args->server);
  if(args->community)
     handler->snmp_community=args->community;
  handler->snmp_version=(int)args->version||1;
  multiset reqs;
  args->oid=args->oid/(args->split||",")-({""});
  reqs=(<handler->get_request(args->oid)>);
  mapping nexts=([]);
  array res=({});
  array rnexts=({}),qnexts=({});
  while(sizeof(reqs)&&handler->wait(args->timeout?(float)args->timeout:4))
   { mapping msg=handler->decode_asn1_msg(handler->readmsg());
     int reqid
     ;{ string s;
        reqid=(int)(s=indices(msg)[0]);
        msg=msg[s];
      }
     if(reqs[reqid])
      { array attribute=msg->attribute;
        mapping m;
        reqs[reqid]=0;
	SNMP_WERR(msg);
        switch((int)msg["error-status"])
         { case 0:
            { array tnexts=nexts[reqid];
              m_delete(nexts,reqid);
	      array rvals,ridx;
	      rvals=ridx=({});
              foreach(attribute,m)
               { if(tnexts)
                  { string noid=tnexts[0];
                    tnexts=tnexts[1..];
                    string retoid=indices(m)[0];
                    if(noid+"."==retoid[..sizeof(noid)])
                       rnexts+=({noid}),qnexts+=({retoid});
                    else
                       continue;
                  }
#if 0
                 array values=values(m);
                 int i=0;
                 foreach(indices(m),string oid)
                    res+=({(["oid":oid,"value":values[i++]])});
#else
		 SNMP_WERR(m);
                 ridx+=indices(m);rvals+=values(m);
#endif
               }
              res+=({(["oid":sizeof(ridx)==1?ridx[0]:ridx,
                       "value":sizeof(rvals)==1?rvals[0]:rvals])});
              if(sizeof(qnexts))
               { int neqid;
                 reqs+=(<neqid=handler->get_nextrequest(qnexts)>);
                 nexts+=([neqid:rnexts]);
                 rnexts=qnexts=({});
               }
              break;
            }
           case 2:
            { int badindex=(int)msg["error-index"]-1;
              int i=0;
              array dir=({});
              foreach(attribute,m)
                 if(i++!=badindex)
                    dir+=indices(m);
              foreach(indices(attribute[badindex]),string oid)
                 rnexts+=({oid}),qnexts+=({oid});
              if(sizeof(dir))
                 reqs+=(<handler->get_request(dir)>);
              else if(sizeof(qnexts))
               { int neqid;
                 reqs+=(<neqid=handler->get_nextrequest(qnexts)>);
                 nexts+=([neqid:rnexts]);
                 rnexts=qnexts=({});
               }
              break;
            }
         }
      }
   }
  SNMP_WERR(res);
  return res;
}

//! Sets a SNMP oid
array snmpset(mapping args)
{ Protocols.SNMP.protocol handler=Protocols.SNMP.protocol((int)args->port||161,
   args->server);
  if(args->community)
     handler->snmp_community=args->community;
  handler->snmp_version=(int)args->version||1;
  handler->set_read_callback(handler->to_pool);
  mapping req=([]);
  args->oid=args->oid/(args->split||",");
  args->value=args->value/(args->split||",");
  args->type=args->type/(args->split||",");
  int i=0;
  foreach(args->oid,string oid)
   { req+=([oid:({args->type[i],args->value[i]})]);
     i++;
   }
  int reqid=handler->set_request(req);
  return ({});
}

/*
 * If you visit a file that doesn't containt these lines at its end, please
 * cut and paste everything from here to that file.
 */

/*
 * Local Variables:
 * c-basic-offset: 2
 * End:
 *
 * vim: softtabstop=2 tabstop=2 expandtab autoindent formatoptions=croqlt smartindent cindent shiftwidth=2
 */
