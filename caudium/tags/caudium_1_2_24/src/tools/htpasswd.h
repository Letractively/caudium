#ifndef HTPASSWD_H
#define HTPASSWD_H
char *strd(char *s);
void getword(char *word, char *line, char stop);
int getline(char *s, int n, FILE *f);
void putline(FILE *f,char *l);
void to64(register char *s, register long v, register int n);
void add_password(char *user, FILE *f);
void usage(void);
void interrupted(void);
#endif
