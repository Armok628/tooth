#define _DEFAULT_SOURCE
#include <unistd.h>
#include <stdint.h>
#if INTPTR_MAX > 0xFFFFFFFF
typedef int64_t cell;
typedef uint64_t ucell;
#elif INTPTR_MAX > 0xFFFF
typedef int32_t cell;
typedef uint32_t ucell;
#else
typedef int16_t cell;
typedef uint16_t ucell;
#endif
typedef struct link_s {
	struct link_s *prev;
	cell flags;
	char *name;
} link_t;
typedef void (*ffunc_t)(void);
#define COUNT(...) sizeof (cell []){__VA_ARGS__}/sizeof(cell)
#define LEN(x) (sizeof(x)/sizeof(x[0]))
#define CWORD(last,name,cname) \
void cname##_c(void); \
struct { \
	link_t link; \
	cell xt[1]; \
} cname = { \
	{(link_t *)last,LEN(name),#name}, \
	{(cell)cname##_c} \
}; \
void cname##_c(void)
#define FORTHWORD(last,name,cname,...) \
struct { \
	link_t link; \
	cell xt[COUNT(__VA_ARGS__)]; \
} cname = { \
	{last,LEN(name)-1,name}, \
	{__VA_ARGS__} \
};
/********************************/
cell stack[1024];
cell *sp=&stack[0];
cell rstack[1024];
cell *rp=&rstack[0];
static inline void push(cell a)
{
	*sp=a;
	sp=&sp[1];
}
static inline void rpush(cell a)
{
	*rp=a;
	rp=&rp[1];
}
static inline cell pop(void)
{
	sp=&sp[-1];
	return *sp;
}
static inline cell rpop(void)
{
	rp=&rp[-1];
	return *rp;
}
/********************************/
ffunc_t *xt=NULL;
ffunc_t *ip=NULL;
//__attribute__((noinline))
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
CWORD(NULL,"EXIT",f_exit)
{
	ip=(ffunc_t *)rpop();
	next();
}
CWORD(NULL,"LITERAL",f_literal)
{
	push((cell)*ip);
	ip=&ip[1];
	next();
}
CWORD(NULL,"BYE",f_bye)
{
	_exit(0);
	next();
}
CWORD(NULL,"EXECUTE",f_execute)
{
	register ffunc_t *f=(ffunc_t *)pop();
	(*f)();
}
/********************************/
CWORD(NULL,"DUP",f_dup)
{
	push(sp[-1]);
	next();
}
CWORD(NULL,"DROP",f_drop)
{
	pop();
	next();
}
CWORD(NULL,"SWAP",f_swap)
{
	register cell b=pop(),a=pop();
	push(b);
	push(a);
	next();
}
CWORD(NULL,"ROT",f_rot)
{
	register cell c=pop(),b=pop(),a=pop();
	push(b);
	push(c);
	push(a);
	next();
}
CWORD(NULL,"-ROT",f_unrot)
{
	register cell c=pop(),b=pop(),a=pop();
	push(c);
	push(a);
	push(b);
	next();
}
CWORD(NULL,"OVER",f_over)
{
	push(sp[-2]);
	next();
}
CWORD(NULL,"NIP",f_nip)
{
	register cell a=pop();
	sp[-1]=a;
	next();
}
CWORD(NULL,"TUCK",f_tuck)
{
	register cell b=pop(),a=pop();
	push(b);
	push(a);
	push(b);
	next();
}
/********************************/
CWORD(NULL,">R",f_to_r)
{
	rpush(pop());
	next();
}
CWORD(NULL,"R>",f_from_r)
{
	push(rpop());
	next();
}
CWORD(NULL,"R@",f_r_fetch)
{
	push(rp[-1]);
	next();
}
/********************************/
CWORD(NULL,"SP@",f_sp_fetch)
{
	push((cell)sp);
	next();
}
CWORD(NULL,"SP!",f_sp_store)
{
	sp=(cell *)pop();
	next();
}
CWORD(NULL,"RP@",f_rp_fetch)
{
	push((cell)rp);
	next();
}
CWORD(NULL,"RP!",f_rp_store)
{
	rp=(cell *)pop();
	next();
}
/********************************/
#define OP2(op) \
{ \
	register cell b=pop(); \
	sp[-1] op##= b; \
	next(); \
}
CWORD(NULL,"+",f_add) OP2(+)
CWORD(NULL,"-",f_sub) OP2(-)
CWORD(NULL,"*",f_mul) OP2(*)
CWORD(NULL,"AND",f_and) OP2(&)
CWORD(NULL,"OR",f_or) OP2(|)
CWORD(NULL,"XOR",f_xor) OP2(^)
CWORD(NULL,"LSHIFT",f_shl) OP2(<<)
CWORD(NULL,"RSHIFT",f_shr) OP2(>>)
CWORD(NULL,"/MOD",f_divmod)
{
	register cell b=sp[-2],a=sp[-1];
	sp[-2]=a%b;
	sp[-1]=a/b;
	next();
}
CWORD(NULL,"1+",f_incr)
{ sp[-1]++; next(); }
CWORD(NULL,"1-",f_decr)
{ sp[-1]--; next(); }
CWORD(NULL,"NEGATE",f_neg)
{ sp[-1]=-sp[-1]; next(); }
CWORD(NULL,"INVERT",f_not)
{ sp[-1]=~sp[-1]; next(); }
/********************************/
#define CMPOP(op) \
{ \
	register cell b=pop(); \
	sp[-1]=sp[-1] op b?~0:0; \
	next(); \
}
CWORD(NULL,"=",f_eq) CMPOP(==)
CWORD(NULL,"<",f_lt) CMPOP(<)
CWORD(NULL,">",f_gt) CMPOP(>)
CWORD(NULL,"<=",f_gte) CMPOP(<=)
CWORD(NULL,">=",f_lte) CMPOP(>=)
CWORD(NULL,"<>",f_neq) CMPOP(!=)
#define UCMPOP(op) \
{ \
	register ucell b=(ucell)pop(); \
	sp[-1]=(ucell)sp[-1] op b?~0:0; \
	next(); \
}
CWORD(NULL,"U<",f_ult) UCMPOP(<)
CWORD(NULL,"U>",f_ugt) UCMPOP(>)
CWORD(NULL,"U<=",f_ugte) UCMPOP(<=)
CWORD(NULL,"U>=",f_ulte) UCMPOP(>=)
/********************************/
cell *here=NULL;
void init_data_seg(void)
{
	here=sbrk(4096*sizeof(cell));
}
CWORD(NULL,"ALLOT",f_allot)
{
	register cell i=pop();
	here=&here[i];
	next();
}
CWORD(NULL,"!",f_store)
{
	register cell *d=(cell *)pop();
	register cell s=pop();
	*d=s;
	next();
}
CWORD(NULL,"@",f_fetch)
{
	register cell *s=(cell *)pop();
	push(*s);
	next();
}
CWORD(NULL,",",f_comma)
{
	*here=pop();
	here=&here[1];
	next();
}
CWORD(NULL,"C,",f_ccomma)
{
	register cell a=pop();
	*(char *)here=a;
	here++;
	next();
}
/********************************/
CWORD(NULL,"EMIT",f_emit)
{
	static char c=0;
	c=pop();
	write(STDOUT_FILENO,&c,1);
	next();
}
/********************************/
static char inbuf[255];
static cell len=0;
static cell in=0;
cell refill(void)
{ // refill inbuf with keyboard input
	register cell l=read(STDIN_FILENO,inbuf,255);
	if (!l)
		_exit(0);
	in=0;
	len=l;
	return l;
}
CWORD(NULL,"REFILL",f_refill)
{
	push(refill()?~0:0);
	next();
}
char key(void)
{ // push key value to stack
	if (in>=len)
		refill();
	return inbuf[in++];
}
CWORD(NULL,"KEY",f_key)
{
	push((cell)key());
	next();
}
static char wordbuf[255];
char *word(void)
{ // push counted address to stack
	register cell c,i=0;
	for (;;) {
		c=key();
		if (c<=' ')
			break;
		i++;
		wordbuf[i]=(char)c;
	}
	wordbuf[0]=i;
	return wordbuf;
}
CWORD(NULL,"WORD",f_word) {
	push((cell)word());
	next();
}
/********************************/
#define CONSTANT(x) { push((cell)x); next(); }
cell base=10;
CWORD(NULL,"BASE",f_base) CONSTANT(&base)
/********************************/
//CWORD(NULL,">NUMBER",f_tonumber)
void tonumber(void)
{
	register cell l=pop();
	register char *s=(char *)pop();
	register cell n=pop();
	register cell b=base;
	if (*s=='-') {
		s++;
		push(-1);
	} else
		push(0);
	while (l>0) {
		char d=*s;
		d-='0';
		if (d<0)
			break;
		else if (d>9) {
			d-='A'-'0'-10;
			if (d<10)
				break;
		}
		if (d>b)
			break;
		n*=b;
		n+=d;
		s++;
		l--;
	}
	if (pop())
		n=-n;
	push(n);
	push((cell)s);
	push(l);
	//next();
}
/********************************/
FORTHWORD(NULL,"TEST",dub,
	(cell)f_docol,
	(cell)f_dup.xt,
	(cell)f_add.xt,
	(cell)f_exit.xt
)
FORTHWORD(NULL,"TEST",test,
	(cell)f_docol,
	(cell)f_literal.xt,
	(cell)35,
	(cell)dub.xt,
	(cell)f_literal.xt,
	(cell)7,
	(cell)f_add.xt,
	(cell)f_emit.xt,
	(cell)f_bye.xt
)
ffunc_t entry=(ffunc_t)test.xt;
int main()//(int argc,char **argv)
{
	ip=&entry;
	next();
}
