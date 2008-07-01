int run()
{

  if(upgrade_server)
  {
    upgrade_server();
  }

  if(upgrade_configuration)
  {
    foreach(caudium->configurations, object config)
    {
      report_notice("Upgrading virtual server configuration " + config->name + "...\n");
       if(!upgrade_configuration())
         report_error("Upgrade " + codefile + "  failed for configuration " + config->name + "\n");
    }
  }

  return 1;
}

//! define this function if you wish to perform a task for each 
//! virtual server configuration present
int upgrade_configuration(object configuration);

//! define this function if you wish to perform a task for the whole 
//! server installation
int upgrade_server();
