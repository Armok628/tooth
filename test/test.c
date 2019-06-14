#include <unistd.h>
#include <stdint.h>
#if INTPTR_MAX > 0xFFFFFFFF
typedef int64_t cell;
#elif INTPTR_MAX > 0xFFFF
typedef int32_t cell;
#else
typedef int16_t cell;
#endif
typedef struct link_s {
	struct link_s *prev;
	cell flags;
	char *name;
} link_t;
typedef void (*ffunc_t)(void);
#define COUNT(...) sizeof (cell []){__VA_ARGS__}/sizeof(cell)
#define TOKLEN(x) (sizeof(#x)-1)
#define CWORD(last,name,cname) \
void cname##_func(void); \
struct { \
	link_t link; \
	cell xt[1]; \
} cname = { \
	{(link_t *)last,TOKLEN(name),#name}, \
	{(cell)cname##_func} \
}; \
void cname##_func(void)
#define FORTHWORD(last,name,cname,...) \
struct { \
	link_t link; \
	cell xt[COUNT(__VA_ARGS__)]; \
} cname = { \
	{last,TOKLEN(name),#name}, \
	{__VA_ARGS__} \
};
/********************************/
cell stack[1024];
cell *sp=&stack[0];
cell rstack[1024];
cell *rp=&rstack[0];
void push(cell a)
{
	*sp=a;
	sp=&sp[1];
}
void rpush(cell a)
{
	*rp=a;
	rp=&rp[1];
}
cell pop(void)
{
	sp=&sp[-1];
	return *sp;
}
cell rpop(void)
{
	rp=&rp[-1];
	return *rp;
}
cell top(void)
{
	return *sp;
}
/********************************/
ffunc_t *xt=NULL;
ffunc_t *ip=NULL;
static inline void next(void)
{
	xt=(ffunc_t *)*ip;
	ip=&ip[1];
	(*xt)();
}
void f_docol(void)
{
	rpush((cell)ip);
	ip=&xt[1];
	next();
}
CWORD(NULL,EXIT,f_exit)
{
	ip=(ffunc_t *)rpop();
	next();
}
CWORD(NULL,LITERAL,f_literal)
{
	push((cell)*ip);
	ip=&ip[1];
	next();
}
CWORD(NULL,EMIT,f_emit)
{
	static char c=0;
	c=pop();
	write(STDOUT_FILENO,&c,1);
}
CWORD(NULL,BYE,f_bye)
{
	_exit(0);
}
/********************************/
static char inbuf[255];
static cell len=0;
static cell in=0;
void refill(void)
{ // refill inbuf with keyboard input
	in=0;
	len=read(STDIN_FILENO,inbuf,255);
}
void key(void)
{ // push key value to stack
	if (in>=len)
		refill();
	push(inbuf[in++]);
}
static char wordbuf[255];
void word(void)
{ // push counted address to stack
	register cell c,i=0;
	for (;;) {
		key();
		c=pop();
		if (c<=' ')
			break;
		i++;
		wordbuf[i]=(char)c;
	}
	wordbuf[0]=i;
	push((cell)wordbuf);
}
void count(void)
{ // replace counted addr with addr and count
	register char *s=(char *)pop();
	push((cell)&s[1]);
	push((cell)s[0]);
}
/********************************/
FORTHWORD(NULL,TEST,test,
	(cell)f_docol,
	(cell)f_literal.xt,
	(cell)123,
	(cell)f_emit.xt,
	(cell)f_bye.xt
)
ffunc_t entry=(ffunc_t)&test.xt;
int main()//(int argc,char **argv)
{
	ip=&entry;
	next();
}
