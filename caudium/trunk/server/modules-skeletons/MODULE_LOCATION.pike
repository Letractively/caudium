/*
 * This module is a MODULE_LOCATION skeleton
 */


/* Standard includes and inherits */

#include <module.h>

inherit "module";
inherit "caudiumlib";



/* Module registration */

// Module type
constant module_type = MODULE_LOCATION;
// Module name
constant module_name = "Skeleton: MODULE_LOCATION";
// Module documentation
constant module_doc  = "Please document me";
// Do we want multiple copies
constant module_unique = 1;
// Is this code thread safe? Beware of global variables...
constant thread_safe = 1;
constant cvs_version = "$Id$";



/*****************************************************************************
 *  Caudium module API 
 *
 *  See http://docs.roxen.com/roxen/1.3/programmer/modules/index.html
 *****************************************************************************/

// Construtor for the module
void create()
{
	// MODULE_LOCATION require a "location"
  defvar(
    "location",
    "/mymountpoint",
    "Mount point",
    TYPE_LOCATION,
    "Location");
}



/*****************************************************************************
 *  Caudium MODULE_LOCATION API 
 *
 *  See http://docs.roxen.com/roxen/1.3/programmer/location-modules/index.html
 *****************************************************************************/

// Method called when a request is made for an URL within this module
// mount point
mixed find_file(string path, object id)
{
	// See http://docs.roxen.com/roxen/1.3/programmer/responses/index.html	
	return Caudium.HTTP.string_answer(sprintf("Hit %s\n", module_name));
}
