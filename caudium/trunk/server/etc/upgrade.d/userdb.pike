// upgrade configurations containing userdb to auth_master + auth_userdb.

object config;

void create(object c)
{
  config=c;
}

int run()
{
  array varstoget=({"update", "Swashii", "method", "file", "args", "shadowfile", "Strip"});
  mapping vars=([]);
  mapping reg;
  string mod_reg;

  if(mod_reg=is_module_enabled("userdb"))
  {
    reg=caudium->retrieve(mod_reg, config);
    if(reg && sizeof(reg)>0)
    {
      // non-default settings here.
      foreach(varstoget, string v)
      {
         if(v=="file")
           vars[v]=reg["userfile"];
         else vars[v]=reg[v];
      }
    }
   
    mapping enabled_modules=caudium->retrieve("EnabledModules", config);
     
    m_delete(enabled_modules, mod_reg);
    caudium->remove(mod_reg, config);

    // now that we have the existing settings, and have removed userdb, we can add auth_master and auth_userdb.

    // do we need to add auth_master? (presumably yes, but let's not take any chances...
    if(!(mod_reg=is_module_enabled("auth_master")))
    {
      enabled_modules["auth_master#0"] = 1;
    }

    enabled_modules["auth_userdb#0"] = 1;
   
    if(sizeof(vars)>0)
      caudium->store("auth_userdb#1", vars, 1, config);

    caudium->store("EnabledModules",enabled_modules, 1, config);
    caudium->save_it(config->name);

    report_notice("User database module upgraded to use the new Authentication Provider system. "
      "Your settings have been retained, "though you will need to add your group file "
      "settings if using password database request method 'file'.\n");

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
