#ifndef SABLOT_CONFIG_H
#define SABLOT_CONFIG_H
@TOP@

@BOTTOM@

#if defined(HAVE_SABLOT_H) && defined(HAVE_LIBSABLOT)
# define HAVE_SABLOT
#endif

static void f_parse( INT32 args );
static void f_parse_files( INT32 args );
void pike_module_init( void );
void pike_module_exit( void );

#endif
