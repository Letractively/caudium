/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000-2002 The Caudium Group
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

//! $Id$
//! 
//! This file implements SNMP agent for Caudium
//!

constant cvs_version = "$Id$";

//! SNMP Agent
object agent;

//! Caudium Configuration Object Hook
object caudium;

#include <module.h>

//! Create the SNMP agent
//! @param c
//!    The Caudium Configuration Object.
void create(object c)
{
  caudium=c;
  report_error("snmp agent starting on port " + GLOBVAR(snmp_port) + "\n");

  mixed err=catch(agent=Protocols.SNMP.agent((int)(GLOBVAR(snmp_port))));

  if(err)
  {
    report_error("Unable to start SNMP agent: " + err[0] + "\n");
    agent=0;
    return;
  }
  agent->set_get_communities(({GLOBVAR(snmp_get_community)}));
  agent->set_managers_only(0);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.1", snmp_get_server_version);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.2", snmp_get_server_boottime);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.3", snmp_get_server_bootlen);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.4", snmp_get_server_uptime);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.5", snmp_get_server_total_requests);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.6", snmp_get_server_total_received);
  agent->set_get_oid_callback("1.3.6.1.4.1.14245.100.7", snmp_get_server_total_sent);
}

//! Return the server version for SNMP for oid 100.1 (under Caudium OID)
array snmp_get_server_version(string oid, mapping rv)
{
  return ({1, "str", caudium->real_version});
}

//! Return the bootime for SNMP for oid 100.2 (under Caudium OID)
array snmp_get_server_boottime(string oid, mapping rv)
{
  int boottimeticks;
  boottimeticks=(caudium->boot_time);

  return ({1, "str", ctime(boottimeticks)});
}

//! Return the boot length for SNMP for oid 100.3 (under Caudium OID)
array snmp_get_server_bootlen(string oid, mapping rv)
{
  int bootlenticks;
  bootlenticks=(caudium->start_time-caudium->boot_time)*100;

  return ({1, "tick", bootlenticks});
}

//! Return the uptime for SNMP for oid 100.4 (under Caudium OID)
array snmp_get_server_uptime(string oid, mapping rv)
{
  int uptimeticks;
  uptimeticks=(time()-caudium->start_time)*100;

  return ({1, "tick", uptimeticks});
}


//! Return the total number of requests for SNMP for oid 100.5 (under Caudium OID)
array snmp_get_server_total_requests(string oid, mapping rv)
{
  int requests;
  foreach(caudium->configurations, object conf) {
#ifdef __AUTO_BIGNUM__
    requests += (conf->requests?conf->requests:0);
#else
    requests += conf->requests?conf->requests:0;
#endif
  }  
  return ({1, "count64", requests});
}

//! Return the total bytes of data received for SNMP for oid 100.6 (under Caudium OID)
array snmp_get_server_total_received(string oid, mapping rv)
{
  int received;
  foreach(caudium->configurations, object conf) {
#ifdef __AUTO_BIGNUM__
    received += (conf->received?conf->received:0);
#else
    received += conf->received?conf->received:0;
#endif
  }  
  return ({1, "count64", received});
}

//! Return the total bytes of data sent for SNMP for oid 100.7 (under Caudium OID)
array snmp_get_server_total_sent(string oid, mapping rv)
{
  int sent;
  foreach(caudium->configurations, object conf) {
#ifdef __AUTO_BIGNUM__
    sent += (conf->sent?conf->sent:0);
#else
    sent += conf->sent?conf->sent:0;
#endif
  }  
  return ({1, "count64", sent});
}

void destroy()
{
   report_error("Agent shutting down.");
}


