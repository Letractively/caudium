#ifndef SABLOT_CONFIG_H
#define SABLOT_CONFIG_H
@TOP@

@BOTTOM@
#undef HAVE_LIBSABLOT
#if defined(HAVE_SABLOT_H) && defined(HAVE_LIBSABLOT)
# define HAVE_SABLOT
#endif

void pike_module_init( void );
void pike_module_exit( void );

#endif
