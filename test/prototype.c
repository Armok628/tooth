/*
 * Disclaimer: All of the following source code is horrifyingly arcane.
 *
 * I leveraged a lot of macros to trick the compiler,
 * so it would form structures the way I need them,
 * and I used a ton of typecasting to get rid of warnings.
 *
 * In some places, I wrote things in an ugly way for optimization.
 * In fact, the code relies on the availability of TCO to function.
 * (Don't expect this to work for long unless the compiler supports TCO!)
 *
 * I made this as a programming challenge to myself,
 * to see how closely/portably I could emulate the assembly version.
 * I do not need (or even want) to use or maintain this seriously,
 * and this is not representative of my usual work.
 */

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
enum { F_IMM=0x80, F_HID=0x40 };
typedef void (*ffunc_t)(void);
#define COUNT(...) sizeof (cell []){__VA_ARGS__}/sizeof(cell)
#define LEN(x) (sizeof(x)/sizeof(x[0]))
#define CWORD(last,name,cname) \
void cname##_c(void); \
struct { \
	link_t link; \
	cell xt[1]; \
} cname = { \
	{(link_t *)last,LEN(name)-1,name}, \
	{(cell)cname##_c} \
}; \
void cname##_c(void)
#define FORTHWORD(last,name,cname,...) \
struct { \
	link_t link; \
	cell xt[COUNT(__VA_ARGS__)]; \
} cname = { \
	{(link_t *)last,LEN(name)-1,name}, \
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
CWORD(&f_exit.link,"LIT",f_lit)
{
	push((cell)*ip);
	ip=&ip[1];
	next();
}
CWORD(&f_lit.link,"BYE",f_bye)
{
	_exit(0);
	next();
}
CWORD(&f_bye.link,"EXECUTE",f_execute)
{
	register ffunc_t *f=(ffunc_t *)pop();
	(*f)();
}
/********************************/
CWORD(&f_execute.link,"BRANCH",f_branch)
{
	register cell o=(cell)*ip;
	ip=(ffunc_t *)(&((char *)ip)[o]);
	next();
}
CWORD(&f_branch.link,"0BRANCH",f_zbranch)
{
	register cell c=pop();
	register cell o=(cell)*ip;
	if (c)
		ip=(ffunc_t *)(&((char *)ip)[o]);
	else
		ip=&ip[1];
	next();
}
/********************************/
CWORD(&f_zbranch.link,"DUP",f_dup)
{
	push(sp[-1]);
	next();
}
CWORD(&f_dup.link,"DROP",f_drop)
{
	pop();
	next();
}
CWORD(&f_drop.link,"SWAP",f_swap)
{
	register cell b=pop(),a=pop();
	push(b);
	push(a);
	next();
}
CWORD(&f_swap.link,"ROT",f_rot)
{
	register cell c=pop(),b=pop(),a=pop();
	push(b);
	push(c);
	push(a);
	next();
}
CWORD(&f_rot.link,"-ROT",f_unrot)
{
	register cell c=pop(),b=pop(),a=pop();
	push(c);
	push(a);
	push(b);
	next();
}
CWORD(&f_unrot.link,"OVER",f_over)
{
	push(sp[-2]);
	next();
}
CWORD(&f_over.link,"NIP",f_nip)
{
	register cell a=pop();
	sp[-1]=a;
	next();
}
CWORD(&f_nip.link,"TUCK",f_tuck)
{
	register cell b=pop(),a=pop();
	push(b);
	push(a);
	push(b);
	next();
}
/********************************/
CWORD(&f_tuck.link,">R",f_to_r)
{
	rpush(pop());
	next();
}
CWORD(&f_to_r.link,"R>",f_from_r)
{
	push(rpop());
	next();
}
CWORD(&f_from_r.link,"R@",f_r_fetch)
{
	push(rp[-1]);
	next();
}
/********************************/
CWORD(&f_r_fetch.link,"SP@",f_sp_fetch)
{
	push((cell)sp);
	next();
}
CWORD(&f_sp_fetch.link,"SP!",f_sp_store)
{
	sp=(cell *)pop();
	next();
}
CWORD(&f_sp_store.link,"RP@",f_rp_fetch)
{
	push((cell)rp);
	next();
}
CWORD(&f_rp_fetch.link,"RP!",f_rp_store)
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
CWORD(&f_rp_store.link,"+",f_add) OP2(+)
CWORD(&f_add.link,"-",f_sub) OP2(-)
CWORD(&f_sub.link,"*",f_mul) OP2(*)
CWORD(&f_mul.link,"AND",f_and) OP2(&)
CWORD(&f_and.link,"OR",f_or) OP2(|)
CWORD(&f_or.link,"XOR",f_xor) OP2(^)
CWORD(&f_xor.link,"LSHIFT",f_shl) OP2(<<)
CWORD(&f_shl.link,"RSHIFT",f_shr) OP2(>>)
CWORD(&f_shr.link,"/MOD",f_divmod)
{
	register cell b=sp[-2],a=sp[-1];
	sp[-2]=a%b;
	sp[-1]=a/b;
	next();
}
CWORD(&f_divmod.link,"1+",f_incr)
{ sp[-1]++; next(); }
CWORD(&f_incr.link,"1-",f_decr)
{ sp[-1]--; next(); }
CWORD(&f_decr.link,"NEGATE",f_neg)
{ sp[-1]=-sp[-1]; next(); }
CWORD(&f_neg.link,"INVERT",f_not)
{ sp[-1]=~sp[-1]; next(); }
/********************************/
#define CMPOP(op) \
{ \
	register cell b=pop(); \
	sp[-1]=sp[-1] op b?~0:0; \
	next(); \
}
CWORD(&f_not.link,"=",f_eq) CMPOP(==)
CWORD(&f_eq.link,"<",f_lt) CMPOP(<)
CWORD(&f_lt.link,">",f_gt) CMPOP(>)
CWORD(&f_gt.link,"<=",f_gte) CMPOP(<=)
CWORD(&f_gte.link,">=",f_lte) CMPOP(>=)
CWORD(&f_lte.link,"<>",f_neq) CMPOP(!=)
#define UCMPOP(op) \
{ \
	register ucell b=(ucell)pop(); \
	sp[-1]=(ucell)sp[-1] op b?~0:0; \
	next(); \
}
CWORD(&f_neq.link,"U<",f_ult) UCMPOP(<)
CWORD(&f_ult.link,"U>",f_ugt) UCMPOP(>)
CWORD(&f_ugt.link,"U<=",f_ugte) UCMPOP(<=)
CWORD(&f_ugte.link,"U>=",f_ulte) UCMPOP(>=)
/********************************/
#define CONSTANT(x) { push((cell)x); next(); }
CWORD(&f_ulte.link,"S0",f_s0) CONSTANT(stack)
CWORD(&f_s0.link,"R0",f_r0) CONSTANT(rstack)
CWORD(&f_r0.link,"F_IMM",f_imm) CONSTANT(F_IMM)
CWORD(&f_imm.link,"F_HID",f_hid) CONSTANT(F_HID)
cell *here=NULL;
CWORD(&f_hid.link,"HERE",f_here) CONSTANT(here)
CWORD(&f_here.link,"CELL",f_cell) CONSTANT(sizeof(cell))
cell base=10;
CWORD(&f_cell.link,"BASE",f_base) CONSTANT(&base)
CWORD(&f_base.link,"DOCOL",f_docol_ptr) CONSTANT(f_docol)
cell sourceid=0;
CWORD(&f_docol_ptr.link,"SOURCE-ID",f_sourceid) CONSTANT(sourceid)
cell in=0;
CWORD(&f_sourceid.link,">IN",f_in) CONSTANT(in)
link_t *latest;
CWORD(&f_in.link,"LATEST",f_latest) CONSTANT(&latest)
/********************************/
void init_data_seg(void)
{
	here=sbrk(4096*sizeof(cell));
}
CWORD(&f_latest.link,"ALLOT",f_allot)
{
	register cell i=pop();
	here=(cell *)(&((char *)here)[i]);
	next();
}
CWORD(&f_allot.link,"!",f_store)
{
	register cell *d=(cell *)pop();
	register cell s=pop();
	*d=s;
	next();
}
CWORD(&f_store.link,"@",f_fetch)
{
	register cell *s=(cell *)pop();
	push(*s);
	next();
}
FORTHWORD(&f_fetch.link,",",f_comma,
	(cell)f_docol,
	(cell)f_here.xt,
	(cell)f_store.xt,
	(cell)f_cell.xt,
	(cell)f_allot.xt,
	(cell)f_exit.xt
)
CWORD(&f_comma.link,"C!",f_cstore)
{
	register char *d=(char *)pop();
	*d=pop();
	next();
}
CWORD(&f_cstore.link,"C@",f_cfetch)
{
	register char *s=(char *)pop();
	push(*s);
	next();
}
FORTHWORD(&f_cfetch.link,"C,",f_ccomma,
	(cell)f_docol,
	(cell)f_here.xt,
	(cell)f_cstore.xt,
	(cell)f_lit.xt,
	(cell)1,
	(cell)f_allot.xt,
	(cell)f_exit.xt
)
/********************************/
CWORD(&f_ccomma.link,"EMIT",f_emit)
{
	static char c=0;
	c=pop();
	write(STDOUT_FILENO,&c,1);
	next();
}
/********************************/
static char inbuf[255];
static cell len=0;
//static cell in=0; // (declared previously)
//static cell sourceid=0; // (declared previously)
cell refill(void)
{
	register cell l=read(STDIN_FILENO,inbuf,255);
	if (!l)
		_exit(0);
	in=0;
	len=l;
	sourceid=0;
	return l;
}
CWORD(&f_emit.link,"REFILL",f_refill)
{
	push(refill()?~0:0);
	next();
}
char key(void)
{
	if (in>=len)
		if (!refill())
			_exit(0);
	return inbuf[in++];
}
CWORD(&f_refill.link,"KEY",f_key)
{
	push((cell)key());
	next();
}
static char wordbuf[255];
char *word(void)
{
	register cell c,i=0;
	while ((c=key())<=' ');
	for (;c>' ';c=key()) {
		i++;
		wordbuf[i]=(char)c;
	}
	wordbuf[0]=i;
	return wordbuf;
}
CWORD(&f_key.link,"WORD",f_word) {
	push((cell)word());
	next();
}
FORTHWORD(&f_word.link,"COUNT",f_count,
	(cell)f_docol,
	(cell)f_dup.xt,
	(cell)f_incr.xt,
	(cell)f_swap.xt,
	(cell)f_cfetch.xt,
	(cell)f_exit.xt
)
/********************************/
CWORD(&f_count.link,">NUMBER",f_tonumber)
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
		n=n*b+d;
		s++;
		l--;
	}
	if (pop())
		n=-n;
	push(n);
	push((cell)s);
	push(l);
	next();
}
/********************************/
link_t *find(char *cs)
{
	int len=cs[0];
	cs++;
	link_t *l=latest;
	for (;l;l=l->prev) {
		if (l->flags&F_HID)
			continue;
		if ((l->flags&~F_IMM)!=len)
			continue;
		for (int i=0;i<len;i++)
			if (l->name[i]!=cs[i])
				goto NEXT;
		break;
NEXT:		continue;
	}
	return l;
}
CWORD(&f_tonumber.link,"FIND",f_find)
{
	link_t *l=find((char *)pop());
	push((cell)(&((ffunc_t *)l)[3]));
	push(l->flags&F_IMM?1:-1);
	next();
}
CWORD(&f_find.link,"'",f_tick)
{
	link_t *l=find(word());
	push((cell)(&((ffunc_t *)l)[3]));
	next();
}
link_t *latest=(link_t *)&f_tick.link;
/********************************/
FORTHWORD(NULL,"TEST",test,
	(cell)f_docol,
	(cell)f_tick.xt,
	(cell)f_execute.xt,
	(cell)f_branch.xt,
	(cell)-3*sizeof(cell)
)
ffunc_t entry=(ffunc_t)test.xt;
int main()//(int argc,char **argv)
{
	ip=&entry;
	next();
	return 0;
}
