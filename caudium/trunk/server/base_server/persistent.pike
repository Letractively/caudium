/*
 * Caudium - An extensible World Wide Web server
 * Copyright © 2000 The Caudium Group
 * Copyright © 1994-2000 Roxen Internet Software
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

/* $Id$ */

/*************************************************************,
* PERSIST. An implementation of persistant objects for Pike.  *
* Variables are saved between restarts.                       *
'*************************************************************/

//Define this to only save the database in bursts instead of every time
//something is changed.
#undef SAVE_IO

static void _nosave(){}
static function nosave = _nosave;
private static array __id;

void really_save()
{
  //Note: We'll get a backtrace here if the object is destructed before save.
  if(nosave()) return;

  array res = ({ });
  mixed b;

  if(!__id)
  {
    mixed i = nameof(this_object());
    if(!arrayp(i)) __id=({i});
    else __id = i;
  }

  //  perror("really save (%s)\n", __id*":");
  
  string a;
  foreach(persistent_variables(object_program(this_object()),this_object()),a)
    res += ({ ({ a, this_object()[a] }) });
  open_db(__id[0])[__id[1]]=res;
}


/* Public methods! */
static int ___destructed = 0;

public void begone()
{
  remove_call_out(really_save);   //Remove SAVE_IO call_out
  ___destructed=1;
  if(__id) open_db(__id[0])->delete(__id[1]);
  __id=0;
// A nicer destruct. Won't error() if no object.
  call_out(do_destruct,8,this_object());
}

void destroy()
{
  remove_call_out(really_save);   //Remove SAVE_IO call_out
}

static void compat_persist()
{
  string _id;
  _id=(__id[0]+".class/"+__id[1]);


#define COMPAT_DIR "dbm_dir.perdbm/"
  array var;
  mixed tmp;
  catch
  {
    object file;
    if(!(file=open(COMPAT_DIR+_id, "r"))) return 0;
    perror("compat restore ("+ _id +")\n");
    var=decode_value(tmp=file->read(0x7ffffff));
  };

  if(var)
  {
    foreach(var, var) catch {
      this_object()[var[0]] = var[1];
    };
    if(!__id)
    {
      mixed i = nameof(this_object());
      if(!arrayp(i)) __id=({i});
      else __id = i;
    }
    
    open_db(__id[0])[__id[1]]=tmp;
    rm(COMPAT_DIR+_id);
  }
}

nomask public void persist(mixed id)
{
  array err;
  /* No known id. This should not really happend. */
  if(!id)  error("No known id in persist.\n");
  __id = id;

// Restore
  array var;
  var=open_db(__id[0])[__id[1]];
  if(var && sizeof(var))
  {
    foreach(var, var) if(err=catch {
      this_object()[var[0]] = var[1];
    })
      report_error(" When setting "+(var[0])+" in "+(__id*":")+": "+
		   describe_backtrace(err));
  } else
    compat_persist();

  if(functionp(this_object()->persisted))
    this_object()->persisted();
}
  

public void save()
{
  if(nosave()) return;
  if(!___destructed)
  {
#ifdef SAVE_IO
    if(zero_type(find_call_out(really_save)))
      call_out(really_save,10);
#else
    really_save();
#endif
  }
}
