// PCRE is compatible, but faster, than original Pike regexps.
// Including this file will replace the global Regexp module
// with PCRE.Regexp.
#ifndef PCRE_H
#if constant(PCRE.Regexp) && constant(PCRE.version)
private constant Regexp = PCRE.Regexp;
#endif
#define PCRE_H
#endif

