// upgrade configurations containing ypuserdb to auth_master + auth_ypuserdb.

object config;

void create(object c)
{
  config=c;
}

int run()
{
  array varstoget=({"update"});
  mapping vars=([]);
  mapping reg;
  string mod_reg;

  if(mod_reg=is_module_enabled("ypuserdb"))
  {
    reg=caudium->retrieve(mod_reg, config);
    if(reg && sizeof(reg)>0)
    {
      // non-default settings here.
      foreach(varstoget, string v)
      {
         vars[v]=reg[v];
      }
    }
   
    mapping enabled_modules=caudium->retrieve("EnabledModules", config);
     
    m_delete(enabled_modules, mod_reg);
    caudium->remove(mod_reg, config);

    // now that we have the existing settings, and have removed ypuserdb, we can add auth_master and auth_ypuserdb.

    // do we need to add auth_master? (presumably yes, but let's not take any chances...
    if(!(mod_reg=is_module_enabled("auth_master")))
    {
      enabled_modules["auth_master#0"] = 1;
    }

    enabled_modules["auth_ypuserdb#0"] = 1;
   
    if(sizeof(vars)>0)
      caudium->store("auth_ypuserdb#0", vars, 1, config);

    caudium->store("EnabledModules",enabled_modules, 1, config);
    caudium->save_it(config->name);

    report_notice("YP User database module upgraded to use the new Authentication Provider system. "
      "Your settings have been retained.\n");

  }
  return 1;
}

string|int is_module_enabled(string module)
{
  mapping reg;
  if(reg=caudium->retrieve("EnabledModules", config))
  {
    foreach(indices(reg), string m)
    {
       string mn, i;
       if(sscanf(m, "%s#%s", mn, i)==2)
       {
         if(mn==module) return m;
       }
    }
  }
  else return 0;
}
