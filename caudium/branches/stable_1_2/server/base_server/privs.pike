/*
 * Caudium - An extensible World Wide Web server
 * Copyright � 2000-2005 The Caudium Group
 * Copyright � 1994-2001 Roxen Internet Software
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

#include <module.h>
#include <caudium.h>
// string cvs_version = "$Id$";

int saved_uid;
int saved_gid;

int new_uid;
int new_gid;

#if !constant(report_notice)
#define report_notice werror
#define report_debug werror
#define report_warning werror
#endif

#define LOGP (roxen && caudium->variables && caudium->variables->audit && GLOBVAR(audit))

#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

#if constant(geteuid) && constant(getegid) && constant(seteuid) && constant(setegid)
#define HAVE_EFFECTIVE_USER
#endif

static private string _getcwd()
{
  if (catch{return(getcwd());}) {
    return("Unknown directory (no x-bit on current directory?)");
  }
}

static private string dbt(array t)
{
  if(!arrayp(t) || (sizeof(t)<2)) return "";
  return (((t[0]||"Unknown program")-(_getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
}

#ifdef THREADS
static mixed mutex_key;	// Only one thread may modify the euid/egid at a time.
static object threads_disabled;
#endif /* THREADS */

int p_level;

void create(string reason, int|string|void uid, int|string|void gid)
{
#ifdef THREADS
#if constant(roxen_pid) && !constant(_disable_threads)
  if(getpid() == roxen_pid)
    werror("Using Privs ("+reason+") in threaded environment, source is\n  "+
	   replace(describe_backtrace(backtrace()), "\n", "\n  ")+"\n");
#endif
#endif
#ifdef HAVE_EFFECTIVE_USER
  array u;

#ifdef THREADS
  if (caudium->euid_egid_lock) {
    catch { mutex_key = caudium->euid_egid_lock->lock(); };
  }
#if constant(_disable_threads)
  threads_disabled = _disable_threads();
#endif
#endif /* THREADS */

  p_level = caudium->privs_level++;

  if (getuid()) return;

  /* Needs to be here since root-priviliges may be needed to
   * use getpw{uid,nam}.
   */
  saved_uid = geteuid();
  saved_gid = getegid();
  seteuid(0);

  /* A string of digits? */
  if (stringp(uid) && ((int)uid) &&
      (replace(uid, ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }),
	       ({ "", "", "", "", "", "", "", "", "", "" })) == "")) {
    uid = (int)uid;
  }
  if (stringp(gid) && ((int)gid) &&
      (replace(gid, ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }),
	       ({ "", "", "", "", "", "", "", "", "", "" })) == "")) {
    gid = (int)gid;
  }

  if(!stringp(uid)) {
    u = getpwuid(uid);
  } else {
    u = getpwnam(uid);
    if(u) 
      uid = u[2];
  }

  if(u && !gid) gid = u[3];
  
  if(!u) {
    if (uid && (uid != "root")) {
      if (intp(uid) && (uid >= 60000)) {
	report_warning(sprintf("privs.pike: User %d is not in the password database.\n"
			       "Assuming nobody.\n", uid));
	// Nobody.
	gid = gid || uid;	// Fake a gid also.
	u = ({ "fake-nobody", "x", uid, gid, "A real nobody", "/", "/sbin/sh" });
      } else {
	error("Unknown user: "+uid+"\n");
      }
    } else {
      u = ({ "root", "x", 0, gid, "The super-user", "/", "/sbin/sh" });
    }
  }

  if(LOGP)
    report_notice(sprintf("Change to %s(%d):%d privs wanted (%s), from %s",
			  (string)u[0], (int)uid, (int)gid,
			  (string)reason,
			  (string)dbt(backtrace()[-2])));

#if constant(cleargroups)
  catch { cleargroups(); };
#endif /* cleargroups */
#if constant(initgroups)
  catch { initgroups(u[0], u[3]); };
#endif
  gid = gid || getgid();
  int err = (int)setegid(new_gid = gid);
  if (err < 0) {
    report_debug(sprintf("privs.pike: WARNING: Failed to set the effective group id to %d!\n"
			 "Check that your password database is correct for user %s(%d),\n"
			 "and that your group database is correct.\n",
			 gid, (string)u[0], (int)uid));
    int gid2 = gid;
#ifdef HPUX_KLUDGE
    if (gid >= 60000) {
      /* HPUX has doesn't like groups higher than 60000,
       * but has assigned nobody to group 60001 (which isn't even
       * in /etc/group!).
       *
       * HPUX's libc also insists on filling numeric fields it doesn't like
       * with the value 60001!
       */
      perror("privs.pike: WARNING: Assuming nobody-group.\n"
	     "Trying some alternatives...\n");
      // Assume we want the nobody group, and try a couple of alternatives
      foreach(({ 60001, 65534, -2 }), gid2) {
	perror("%d... ", gid2);
	if (initgroups(u[0], gid2) >= 0) {
	  if ((err = setegid(new_gid = gid2)) >= 0) {
	    perror("Success!\n");
	    break;
	  }
	}
      }
    }
#endif /* HPUX_KLUDGE */
    if (err < 0) {
      perror("privs.pike: Failed\n");
      throw(({ sprintf("Failed to set EGID to %d\n", gid), backtrace() }));
    }
    perror("privs.pike: WARNING: Set egid to %d instead of %d.\n",
	   gid2, gid);
    gid = gid2;
  }
  if(getgid()!=gid) setgid(gid||getgid());
  seteuid(new_uid = uid);
#endif /* HAVE_EFFECTIVE_USER */
}

void destroy()
{
#ifdef HAVE_EFFECTIVE_USER
  /* Check that we don't increase the privs level */
  if (p_level >= caudium->privs_level) {
    report_error(sprintf("Change back to uid#%d gid#%d from uid#%d gid#%d\n"
			 "in wrong order! Saved level:%d Current level:%d\n"
			 "Occurs in:\n%s\n",
			 saved_uid, saved_gid, new_uid, new_gid,
			 p_level, caudium->privs_level,
			 describe_backtrace(backtrace())));
    return(0);
  }
  if (p_level != caudium->privs_level-1) {
    report_error(sprintf("Change back to uid#%d gid#%d from uid#%d gid#%d\n"
			 "Skips privs level. Saved level:%d Current level:%d\n"
			 "Occurs in:\n%s\n",
			 saved_uid, saved_gid, new_uid, new_gid,
			 p_level, caudium->privs_level,
			 describe_backtrace(backtrace())));
  }
  caudium->privs_level = p_level;

  if(LOGP) {
    catch {
      array bt = backtrace();
      if (sizeof(bt) >= 2) {
	report_notice(sprintf("Change back to uid#%d gid#%d, from %s\n",
			      saved_uid, saved_gid, dbt(bt[-2])));
      } else {
	report_notice(sprintf("Change back to uid#%d gid#%d, from backend\n",
			      saved_uid, saved_gid));
      }
    };
  }

  if(getuid()) return;

#ifdef DEBUG
  int uid = geteuid();
  if (uid != new_uid) {
    report_warning(sprintf("Privs.pike: UID #%d differs from expected #%d\n"
			   "%s\n",
			   uid, new_uid, describe_backtrace(backtrace())));
  }
  int gid = getegid();
  if (gid != new_gid) {
    report_warning(sprintf("Privs.pike: GID #%d differs from expected #%d\n"
			   "%s\n",
			   gid, new_gid, describe_backtrace(backtrace())));
  }
#endif /* DEBUG */

  seteuid(0);
  array u = getpwuid(saved_uid);
#if constant(cleargroups)
  catch { cleargroups(); };
#endif /* cleargroups */
  if(u && (sizeof(u) > 3)) {
    catch { initgroups(u[0], u[3]); };
  }
  setegid(saved_gid);
  seteuid(saved_uid);

#ifdef THREADS
  if (threads_disabled) destruct (threads_disabled);
  if (mutex_key) destruct (mutex_key);
#endif

#endif /* HAVE_EFFECTIVE_USER */
}
