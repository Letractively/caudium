/*
**  openssl.c
*/

#include "config.h"
#include "global.h"

#include "array.h"
#include "backend.h"
#include "interpret.h"
#include "object.h"
#include "pike_macros.h"
#include "program.h"
#include "stralloc.h"
#include "svalue.h"
#include "threads.h"

#ifdef HAVE_OPENSSL

#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>

struct SSL_CTX_t { SSL_CTX *ctx; };
struct SSL_t { SSL *ssl; };

#define SSL_CTX_OBJ	(((struct SSL_CTX_t *)(Pike_fp->current_storage))->ctx)
#define SSL_OBJ		(((struct SSL_t *)(Pike_fp->current_storage))->ssl)

static struct program *openssl_SSL_CTX_program;
static struct program *openssl_SSL_program;

/*****************************************************************************
**  openssl_SSL_CTX_create()                                                **
**  openssl_SSL_CTX_werror()                                                **
**  openssl_SSL_CTX_new()                                                   **
**  openssl_SSL_CTX_use_PrivateKey_file()                                   **
**  openssl_SSL_CTX_use_certificate_file()                                  **
**  openssl_SSL_CTX_check_private_key()                                     **
**  openssl_SSL_CTX_load_verify_locations()                                 **
**  openssl_SSL_CTX_set_verify()                                            **
**  openssl_SSL_CTX_set_verify_depth()                                      **
*****************************************************************************/

static void openssl_SSL_CTX_create(INT32 args) {
	pop_n_elems(args);
	return;
}

static void openssl_SSL_CTX_werror(INT32 args) {
	ERR_print_errors_fp(stderr);
	pop_n_elems(args);
	return;
}

static void openssl_SSL_CTX_new(INT32 args) {
	INT32 ret;

	ret = ((SSL_CTX_OBJ = SSL_CTX_new(SSLv3_method())) ? 1 : 0);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_CTX_use_PrivateKey_file(INT32 args) {
	INT32 ret;

	if (sp[-args].type != T_STRING)
		error("SSL_CTX->use_PrivateKey_file():  bad argument type\n");
	ret = SSL_CTX_use_PrivateKey_file(SSL_CTX_OBJ, sp[-args].u.string->str, SSL_FILETYPE_PEM);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_CTX_use_certificate_file(INT32 args) {
	INT32 ret;

	if (sp[-args].type != T_STRING)
		error("SSL_CTX->use_certificate_file():  bad argument type\n");
	ret = SSL_CTX_use_certificate_file(SSL_CTX_OBJ, sp[-args].u.string->str, SSL_FILETYPE_PEM);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_CTX_check_private_key(INT32 args) {
	INT32 ret;

	ret = SSL_CTX_check_private_key(SSL_CTX_OBJ);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_CTX_load_verify_locations(INT32 args) {
	INT32 ret;

	if (sp[-args].type != T_STRING)
		error("SSL_CTX->load_verify_locations():  bad argument type\n");
	ret = SSL_CTX_load_verify_locations(SSL_CTX_OBJ, NULL, sp[-args].u.string->str);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_CTX_set_verify(INT32 args) {
	if (sp[-args].type != T_INT)
		error("SSL_CTX->set_verify():  bad argument type\n");
	SSL_CTX_set_verify(SSL_CTX_OBJ, sp[-args].u.integer, NULL);
	pop_n_elems(args);
	return;
}

static void openssl_SSL_CTX_set_verify_depth(INT32 args) {
	if (sp[-args].type != T_INT)
		error("SSL_CTX->set_verify_depth():  bad argument type\n");
	SSL_CTX_set_verify_depth(SSL_CTX_OBJ, sp[-args].u.integer);
	pop_n_elems(args);
	return;
}

/*****************************************************************************
**  openssl_SSL_create()                                                    **
**  openssl_SSL_new()                                                       **
**  openssl_SSL_clear()                                                     **
**  openssl_SSL_set_fd()                                                    **
**  openssl_SSL_accept()                                                    **
**  openssl_SSL_connect()                                                   **
**  openssl_SSL_get_verify_result()                                         **
**  openssl_SSL_read()                                                      **
**  openssl_SSL_write()                                                     **
**  openssl_SSL_shutdown()                                                  **
*****************************************************************************/

static void openssl_SSL_create(INT32 args) {
	pop_n_elems(args);
	return;
}

static void openssl_SSL_new(INT32 args) {
	INT32 ret;

	if ((sp[-args].type != T_OBJECT) || (sp[-args].u.object->prog != openssl_SSL_CTX_program))
		error("SSL->new():  bad argument type\n");
	ret = ((SSL_OBJ = SSL_new(((struct SSL_CTX_t *)(sp[-args].u.object->storage))->ctx)) ? 1 : 0);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_clear(INT32 args) {
	INT32 ret;

	ret = SSL_clear(SSL_OBJ);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_set_fd(INT32 args) {
	INT32 ret;

	if (sp[-args].type != T_INT)
		error("SSL->set_fd():  bad argument type\n");
	ret = SSL_set_fd(SSL_OBJ, sp[-args].u.integer);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_accept(INT32 args) {
	INT32 ret;
	SSL *ssl = SSL_OBJ;

	THREADS_ALLOW();
	ret = SSL_accept(ssl);
	THREADS_DISALLOW();
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_connect(INT32 args) {
	INT32 ret;
	SSL *ssl = SSL_OBJ;

	THREADS_ALLOW();
	ret = SSL_connect(ssl);
	THREADS_DISALLOW();
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_get_verify_result(INT32 args) {
	INT32 ret;

	ret = SSL_get_verify_result(SSL_OBJ);
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_read(INT32 args) {
	INT32 ret;
	SSL *ssl = SSL_OBJ;
	struct pike_string *s;

	if (sp[-args].type != T_INT)
		error("SSL->read():  bad argument type\n");
	if ((ret = sp[-args].u.integer) <= 0) {
		pop_n_elems(args);
		push_int(ret);
		return;
	}
	s = begin_shared_string(ret);
	THREADS_ALLOW();
	ret = SSL_read(ssl, s->str, ret);
	THREADS_DISALLOW();
	if (ret < 0) {
		free_string(end_shared_string(s));
		pop_n_elems(args);
		push_int(ret);
		return;
	}
	s->len = ret;
	pop_n_elems(args);
	push_string(end_shared_string(s));
	return;
}

static void openssl_SSL_write(INT32 args) {
	INT32 ret;
	SSL *ssl = SSL_OBJ;
	char *str;
	int len;

	if (sp[-args].type != T_STRING)
		error("SSL->write():  bad argument type\n");
	str = sp[-args].u.string->str;
	len = sp[-args].u.string->len;
	THREADS_ALLOW();
	ret = SSL_write(ssl, str, len);
	THREADS_DISALLOW();
	pop_n_elems(args);
	push_int(ret);
	return;
}

static void openssl_SSL_shutdown(INT32 args) {
	INT32 ret;
	SSL *ssl = SSL_OBJ;

	THREADS_ALLOW();
	ret = SSL_shutdown(ssl);
	THREADS_DISALLOW();
	pop_n_elems(args);
	push_int(ret);
	return;
}

#ifdef _REENTRANT

/*****************************************************************************
**  openssl_thread_id()                                                     **
**  openssl_locking_callback()                                              **
**  openssl_init_threads()                                                  **
*****************************************************************************/

static MUTEX_T openssl_locks[CRYPTO_NUM_LOCKS];

static unsigned long openssl_thread_id() {
	return (unsigned long)th_self();
}

static void openssl_locking_callback(int m, int t, const char *f, int l) {
	if (m & CRYPTO_LOCK) mt_lock(openssl_locks + t);
	else mt_unlock(openssl_locks + t);
	return;
}

static void openssl_init_threads() {
	int i;

	for (i = 0; i < CRYPTO_NUM_LOCKS; i++) mt_init(openssl_locks + i);
	CRYPTO_set_id_callback(openssl_thread_id);
	CRYPTO_set_locking_callback(openssl_locking_callback);
	return;
}

#endif /* _REENTRANT */

/*****************************************************************************
**  openssl_SSL_CTX_program_init()                                          **
**  openssl_SSL_CTX_program_exit()                                          **
**  openssl_SSL_program_init()                                              **
**  openssl_SSL_program_exit()                                              **
*****************************************************************************/

static void openssl_SSL_CTX_program_init(struct object *o) {
	SSL_CTX_OBJ = NULL;
	return;
}

static void openssl_SSL_CTX_program_exit(struct object *o) {
	if (SSL_CTX_OBJ != NULL) SSL_CTX_free(SSL_CTX_OBJ);
	return;
}

static void openssl_SSL_program_init(struct object *o) {
	SSL_OBJ = NULL;
	return;
}

static void openssl_SSL_program_exit(struct object *o) {
	if (SSL_OBJ != NULL) SSL_free(SSL_OBJ);
	return;
}

#endif /* HAVE_OPENSSL */

/*****************************************************************************
**  pike_module_init()                                                      **
**  pike_module_exit()                                                      **
*****************************************************************************/

void pike_module_init() {
#ifdef HAVE_OPENSSL
	SSL_load_error_strings();
	SSL_library_init();

#ifdef _REENTRANT
	openssl_init_threads();
#endif /* _REENTRANT */

	start_new_program();
	ADD_STORAGE(struct SSL_CTX_t);
	ADD_FUNCTION("create", openssl_SSL_CTX_create, tFunc(tVoid, tVoid), 0);
	ADD_FUNCTION("werror", openssl_SSL_CTX_werror, tFunc(tVoid, tVoid), 0);
	ADD_FUNCTION("new", openssl_SSL_CTX_new, tFunc(tVoid, tInt), 0);
	ADD_FUNCTION("use_PrivateKey_file", openssl_SSL_CTX_use_PrivateKey_file, tFunc(tStr, tInt), 0);
	ADD_FUNCTION("use_certificate_file", openssl_SSL_CTX_use_certificate_file, tFunc(tStr, tInt), 0);
	ADD_FUNCTION("check_private_key", openssl_SSL_CTX_check_private_key, tFunc(tVoid, tInt), 0);
	ADD_FUNCTION("load_verify_locations", openssl_SSL_CTX_load_verify_locations, tFunc(tStr, tInt), 0);
	ADD_FUNCTION("set_verify", openssl_SSL_CTX_set_verify, tFunc(tInt, tVoid), 0);
	ADD_FUNCTION("set_verify_depth", openssl_SSL_CTX_set_verify_depth, tFunc(tInt, tVoid), 0);
	add_integer_constant("VERIFY_NONE", SSL_VERIFY_NONE, 0);
	add_integer_constant("VERIFY_PEER", SSL_VERIFY_PEER, 0);
	add_integer_constant("VERIFY_FAIL_IF_NO_PEER_CERT", SSL_VERIFY_FAIL_IF_NO_PEER_CERT, 0);
	add_integer_constant("VERIFY_CLIENT_ONCE", SSL_VERIFY_CLIENT_ONCE, 0);
	set_init_callback(openssl_SSL_CTX_program_init);
	set_exit_callback(openssl_SSL_CTX_program_exit);
	openssl_SSL_CTX_program = end_program();
	add_program_constant("SSL_CTX", openssl_SSL_CTX_program, 0);

	start_new_program();
	ADD_STORAGE(struct SSL_t);
	ADD_FUNCTION("create", openssl_SSL_create, tFunc(tVoid, tVoid), 0);
	ADD_FUNCTION("new", openssl_SSL_new, tFunc(tObj, tInt), 0);
	ADD_FUNCTION("clear", openssl_SSL_clear, tFunc(tVoid, tInt), 0);
	ADD_FUNCTION("set_fd", openssl_SSL_set_fd, tFunc(tInt, tInt), 0);
	ADD_FUNCTION("accept", openssl_SSL_accept, tFunc(tVoid, tInt), 0);
	ADD_FUNCTION("connect", openssl_SSL_connect, tFunc(tVoid, tInt), 0);
	ADD_FUNCTION("get_verify_result", openssl_SSL_get_verify_result, tFunc(tVoid, tInt), 0);
	ADD_FUNCTION("read", openssl_SSL_read, tFunc(tInt, tOr(tInt, tStr)), 0);
	ADD_FUNCTION("write", openssl_SSL_write, tFunc(tStr, tInt), 0);
	ADD_FUNCTION("shutdown", openssl_SSL_shutdown, tFunc(tVoid, tInt), 0);
	set_init_callback(openssl_SSL_program_init);
	set_exit_callback(openssl_SSL_program_exit);
	openssl_SSL_program = end_program();
	add_program_constant("SSL", openssl_SSL_program, 0);
#endif /* HAVE_OPENSSL */
	return;
}

void pike_module_exit() {
#ifdef HAVE_OPENSSL
	free_program(openssl_SSL_program);
	openssl_SSL_program = NULL;
	free_program(openssl_SSL_CTX_program);
	openssl_SSL_CTX_program = NULL;
#endif /* HAVE_OPENSSL */
	return;
}
