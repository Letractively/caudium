/* Emacs, this is -*-pike-*-
 *
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
 * $Id$
 */

//! This is a simple thread farm. Used by the PHP4 module to
//! create a set of shuffle threads.

//! The class that implements the thread farm.
class Farm {
    private array threads;
    private object queue = Thread.Queue();

    private void farmer() {
        array data;
        mixed err;
        while(this_object()) {
            err = catch {
                while(this_object() && (data = queue->read())) {
                    data[0](@data[1]);
                }
                // got zero in queue or object dested.
                catch { threads -= ({ this_thread() }); };
                return;
            };
            if(err) {
                report_error("Uncaught error in ThreadFarm handler: " +
                             describe_backtrace(err));
            }
        }
        catch { threads -= ({ this_thread() }); };
    }

    //! Create the object and allocate the indicated number of threads.
    //!
    //! @param numthreads
    //!  The number of threads to create.
    void create(int numthreads) {
        threads = allocate(numthreads, thread_create)(farmer);
    }

    //! Resize the thread farm.
    //!
    //! @param newsize
    //!  New farm size.
    //!
    //! @param shrink
    //!  Shrink the farm if so requested and this parameter is larger than
    //!  zero.
    void resize(int newsize, int|void shrink) {
        if(newsize == sizeof(threads)) return;
        if(newsize < sizeof(threads)) {
            if(shrink)
                allocate(sizeof(threads) - newsize, queue->write)(0);
            return;
        } else {
            threads += allocate(newsize - sizeof(threads), thread_create)(farmer);
        }
    }

    //! Destroy the object and the farm.
    void destroy() {
        int w;
        allocate(sizeof(threads), queue->write)(0);
        while(w < 10 && sizeof(threads)) {
            sleep(0.1);
            w++;
        }
    }

    //! Enqueue a new function waiting for a thread.
    //!
    //! @param fun
    //!  Function to enqueue.
    //!
    //! @param args
    //!  Variable number of arguments to pass to the function.
    void enqueue(function fun, mixed ... args) {
        queue->write( ({ fun, args }) );
    }
}
