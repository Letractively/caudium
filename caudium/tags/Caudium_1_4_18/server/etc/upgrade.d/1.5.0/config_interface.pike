
// upgrade configuration interface to be a virtual server

inherit Caudium.UpgradeTask;

#define GLOBVAR(X) caudium->retrieve("Variables", 0)[X]

// some support functionality
class dummyConfig(string name)
{}

void setconfigvar(string sect, string var, mixed value)
{
  mapping v;
  object c = dummyConfig("ConfigurationInterface");
  v = caudium->retrieve(sect, c);
  v[var] = value;
  caudium->store(sect, v, 1, c);
}

// the meat of the upgrade task
int upgrade_server()
{
  // if we already have a configuration interface virtual server, we don't 
  // need to continue.
  foreach(caudium->configurations;; object c)
  {
    if(c->name == "ConfigurationInterface") return 1;
  }

   // the configuration interface vs doesn't exist, so we can create it.
   setconfigvar("spider#0", "Ports", GLOBVAR("ConfigPorts"));
   setconfigvar("spider#0", "MyWorldLocation", GLOBVAR("ConfigurationURL"));
   setconfigvar("spider#0", "name", "Configuration Interface");
   setconfigvar("spider#0", "netcraft_done", 1);
   setconfigvar("filesystem#0", "mountpoint", "/config_interface");
   setconfigvar("filesystem#0", "searchpath", "config_interface");
   setconfigvar("configure#0", "mountpoint", "/");
   setconfigvar("auth_master#0", "name", "Master Authentication Handler");
   setconfigvar("auth_configdefault#0", "username", GLOBVAR("ConfigurationUser"));
   setconfigvar("auth_configdefault#0", "password", GLOBVAR("ConfigurationPassword"));
   setconfigvar("EnabledModules", "configure#0", 1);
   setconfigvar("EnabledModules", "auth_master#0", 1);
   setconfigvar("EnabledModules", "auth_configdefault#0", 1);
   setconfigvar("EnabledModules", "filesystem#0", 1);

   // let's clean up the Global Variables config a bit
   mapping v = caudium->retrieve("Variables", 0);

   m_delete(v, "ConfigPorts");
   m_delete(v, "ConfigurationUser");
   m_delete(v, "ConfigurationPassword");

   // and finally, we can save our changes.
   caudium->save_it("ConfigurationInterface");
   caudium->save_it("Global Variables");

  report_notice("Converted old style configuration interface to new configuration interface.\n");
  report_notice("*** NOTE: we will request a restart of the server in 10 seconds. \n"
                "    If running in --once mode, you will have to restart manually.\n\n");


  call_out(caudium->restart, 10);
  return 1;
}
