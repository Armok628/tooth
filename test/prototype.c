/*
 * Disclaimer: All of the following source code is horrifyingly arcane.
 * This is not to be considered an official part of the project.
 *
 * I made this as a programming challenge to myself,
 * to see how closely I could emulate the assembly version in C.
 * I do not need (or even want) to use or maintain this seriously,
 * and this is not representative of my usual work.
 *
 * I leveraged a lot of macros to trick the compiler,
 * so it would form link structures the way I need them,
 * and I used a ton of typecasting to get rid of warnings.
 *
 * In some places, I wrote things in an ugly way for optimization.
 * In fact, the code relies on the availability of TCO to function.
 * (Don't expect this to work for long unless the compiler supports TCO!)
 *
 * Also, this code breaks the strict aliasing rule _everywhere_.
 * You have been warned; proceed at your own risk.
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
#define CWORD(last,name,cname) \
void cname##_c(void); \
struct { \
	link_t link; \
	cell xt[1]; \
} cname = { \
	{(link_t *)last,name[0],name}, \
	{(cell)cname##_c} \
}; \
void cname##_c(void)
#define FORTHWORD(last,name,cname,...) \
struct { \
	link_t link; \
	cell xt[COUNT(__VA_ARGS__)]; \
} cname = { \
	{(link_t *)last,name[0],name}, \
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
CWORD(NULL,"\4EXIT",f_exit)
{
	ip=(ffunc_t *)rpop();
	next();
}
CWORD(&f_exit.link,"\3LIT",f_lit)
{
	push((cell)*ip);
	ip=&ip[1];
	next();
}
CWORD(&f_lit.link,"\7EXECUTE",f_execute)
{
	xt=(ffunc_t *)pop();
	(*xt)();
}
/********************************/
CWORD(&f_execute.link,"\006BRANCH",f_branch)
{
	register cell o=(cell)*ip;
	ip=(ffunc_t *)(&((char *)ip)[o]);
	next();
}
CWORD(&f_branch.link,"\0070BRANCH",f_zbranch)
{
	if (!pop()) {
		f_branch_c();
		return;
	}
	ip=&ip[1];
	next();
}
/********************************/
CWORD(&f_zbranch.link,"\003DUP",f_dup)
{
	push(sp[-1]);
	next();
}
CWORD(&f_dup.link,"\004DROP",f_drop)
{
	pop();
	next();
}
CWORD(&f_drop.link,"\004SWAP",f_swap)
{
	register cell b=pop(),a=pop();
	push(b);
	push(a);
	next();
}
CWORD(&f_swap.link,"\003ROT",f_rot)
{
	register cell c=pop(),b=pop(),a=pop();
	push(b);
	push(c);
	push(a);
	next();
}
CWORD(&f_rot.link,"\004-ROT",f_unrot)
{
	register cell c=pop(),b=pop(),a=pop();
	push(c);
	push(a);
	push(b);
	next();
}
CWORD(&f_unrot.link,"\004OVER",f_over)
{
	push(sp[-2]);
	next();
}
CWORD(&f_over.link,"\003NIP",f_nip)
{
	register cell a=pop();
	sp[-1]=a;
	next();
}
CWORD(&f_nip.link,"\004TUCK",f_tuck)
{
	register cell b=pop(),a=pop();
	push(b);
	push(a);
	push(b);
	next();
}
/********************************/
CWORD(&f_tuck.link,"\002>R",f_to_r)
{
	rpush(pop());
	next();
}
CWORD(&f_to_r.link,"\002R>",f_from_r)
{
	push(rpop());
	next();
}
CWORD(&f_from_r.link,"\002R@",f_r_fetch)
{
	push(rp[-1]);
	next();
}
/********************************/
CWORD(&f_r_fetch.link,"\003SP@",f_sp_fetch)
{
	push((cell)sp);
	next();
}
CWORD(&f_sp_fetch.link,"\003SP!",f_sp_store)
{
	sp=(cell *)pop();
	next();
}
CWORD(&f_sp_store.link,"\003RP@",f_rp_fetch)
{
	push((cell)rp);
	next();
}
CWORD(&f_rp_fetch.link,"\003RP!",f_rp_store)
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
CWORD(&f_rp_store.link,"\001+",f_add) OP2(+)
CWORD(&f_add.link,"\001-",f_sub) OP2(-)
CWORD(&f_sub.link,"\001*",f_mul) OP2(*)
CWORD(&f_mul.link,"\003AND",f_and) OP2(&)
CWORD(&f_and.link,"\002OR",f_or) OP2(|)
CWORD(&f_or.link,"\003XOR",f_xor) OP2(^)
CWORD(&f_xor.link,"\006LSHIFT",f_shl) OP2(<<)
CWORD(&f_shl.link,"\006RSHIFT",f_shr) OP2(>>)
CWORD(&f_shr.link,"\004/MOD",f_divmod)
{
	register cell q=sp[-2]/sp[-1];
	register cell m=sp[-2]%sp[-1];
	sp[-2]=m;
	sp[-1]=q;
	next();
}
CWORD(&f_divmod.link,"\0021+",f_incr)
{ sp[-1]++; next(); }
CWORD(&f_incr.link,"\0021-",f_decr)
{ sp[-1]--; next(); }
CWORD(&f_decr.link,"\006NEGATE",f_negate)
{ sp[-1]=-sp[-1]; next(); }
CWORD(&f_negate.link,"\006INVERT",f_invert)
{ sp[-1]=~sp[-1]; next(); }
/********************************/
#define CMPOP(op) \
{ \
	register cell b=pop(); \
	sp[-1]=sp[-1] op b?~0:0; \
	next(); \
}
CWORD(&f_invert.link,"\001=",f_eq) CMPOP(==)
CWORD(&f_eq.link,"\001<",f_lt) CMPOP(<)
CWORD(&f_lt.link,"\001>",f_gt) CMPOP(>)
CWORD(&f_gt.link,"\002<=",f_gte) CMPOP(<=)
CWORD(&f_gte.link,"\002>=",f_lte) CMPOP(>=)
CWORD(&f_lte.link,"\002<>",f_neq) CMPOP(!=)
#define UCMPOP(op) \
{ \
	register ucell b=(ucell)pop(); \
	sp[-1]=(ucell)sp[-1] op b?~0:0; \
	next(); \
}
CWORD(&f_neq.link,"\002U<",f_ult) UCMPOP(<)
CWORD(&f_ult.link,"\002U>",f_ugt) UCMPOP(>)
CWORD(&f_ugt.link,"\003U<=",f_ugte) UCMPOP(<=)
CWORD(&f_ugte.link,"\003U>=",f_ulte) UCMPOP(>=)
/********************************/
#define CONSTANT(x) { push((cell)x); next(); }
CWORD(&f_ulte.link,"\002S0",f_s0) CONSTANT(stack)
CWORD(&f_s0.link,"\002R0",f_r0) CONSTANT(rstack)
CWORD(&f_r0.link,"\005F_IMM",f_imm) CONSTANT(F_IMM)
CWORD(&f_imm.link,"\005F_HID",f_hid) CONSTANT(F_HID)
cell *here=NULL;
CWORD(&f_hid.link,"\004HERE",f_here) CONSTANT(here)
CWORD(&f_here.link,"\004CELL",f_cell) CONSTANT(sizeof(cell))
cell base=10;
CWORD(&f_cell.link,"\004BASE",f_base) CONSTANT(&base)
CWORD(&f_base.link,"\005DOCOL",f_docol_ptr) CONSTANT(f_docol)
cell sourceid=0;
CWORD(&f_docol_ptr.link,"\011SOURCE-ID",f_sourceid) CONSTANT(sourceid)
cell in=0;
CWORD(&f_sourceid.link,"\003>IN",f_in) CONSTANT(in)
link_t *latest;
CWORD(&f_in.link,"\006LATEST",f_latest) CONSTANT(&latest)
/********************************/
CWORD(&f_latest.link,"\005ALLOT",f_allot)
{
	register cell i=pop();
	here=(cell *)(&((char *)here)[i]);
	next();
}
CWORD(&f_allot.link,"\001!",f_store)
{
	register cell *d=(cell *)pop();
	register cell s=pop();
	*d=s;
	next();
}
CWORD(&f_store.link,"\001@",f_fetch)
{
	register cell *s=(cell *)pop();
	push(*s);
	next();
}
FORTHWORD(&f_fetch.link,"\001,",f_comma,
	(cell)f_docol,
	(cell)f_here.xt,
	(cell)f_store.xt,
	(cell)f_cell.xt,
	(cell)f_allot.xt,
	(cell)f_exit.xt
)
CWORD(&f_comma.link,"\002C!",f_cstore)
{
	register char *d=(char *)pop();
	*d=pop();
	next();
}
CWORD(&f_cstore.link,"\002C@",f_cfetch)
{
	register char *s=(char *)pop();
	push(*s);
	next();
}
FORTHWORD(&f_cfetch.link,"\002C,",f_ccomma,
	(cell)f_docol,
	(cell)f_here.xt,
	(cell)f_cstore.xt,
	(cell)f_lit.xt,
	(cell)1,
	(cell)f_allot.xt,
	(cell)f_exit.xt
)
/********************************/
CWORD(&f_ccomma.link,"\004EMIT",f_emit)
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
CWORD(&f_emit.link,"\006REFILL",f_refill)
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
CWORD(&f_refill.link,"\003KEY",f_key)
{
	push((cell)key());
	next();
}
static char wordbuf[255];
char *word(void)
{
	register cell c,i=0;
	while ((c=key())<=' ');
	while (c>' ') {
		i++;
		wordbuf[i]=(char)c;
		c=key();
	}
	wordbuf[0]=i;
	return wordbuf;
}
CWORD(&f_key.link,"\004WORD",f_word)
{
	push((cell)word());
	next();
}
FORTHWORD(&f_word.link,"\005COUNT",f_count,
	(cell)f_docol,
	(cell)f_dup.xt,
	(cell)f_incr.xt,
	(cell)f_swap.xt,
	(cell)f_cfetch.xt,
	(cell)f_exit.xt
)
/********************************/
CWORD(&f_count.link,"\007>NUMBER",f_tonumber)
{
	register cell l=pop();
	register char *s=(char *)pop();
	register cell n=pop();
	register cell b=base;
	push(0);
	if (*s=='-') {
		s++;
		l--;
		sp[-1]=~sp[-1];
	}
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
		char *ln=l->name+1;
		for (int i=0;i<len;i++)
			if (ln[i]!=cs[i])
				goto NEXT;
		break;
NEXT:		continue;
	}
	return l;
}
CWORD(&f_tonumber.link,"\004FIND",f_find)
{
	char *s=(char *)pop();
	link_t *l=find(s);
	if (l) {
		push((cell)(&((ffunc_t *)l)[3]));
		push(l->flags&F_IMM?1:-1);
	} else {
		push((cell)s);
		push(0);
	}
	next();
}
CWORD(&f_find.link,"\001'",f_tick)
{
	link_t *l=find(word());
	push((cell)(&((ffunc_t *)l)[3]));
	next();
}
/********************************/
FORTHWORD(&f_tick.link,"\007ALIGNED",f_aligned,
	(cell)f_docol,
	(cell)f_decr.xt,
	(cell)f_cell.xt,
	(cell)f_decr.xt,
	(cell)f_invert.xt,
	(cell)f_and.xt,
	(cell)f_cell.xt,
	(cell)f_add.xt,
	(cell)f_exit.xt
)
FORTHWORD(&f_aligned.link,"\005ALIGN",f_align,
	(cell)f_docol,
	(cell)f_here.xt,
	(cell)f_dup.xt,
	(cell)f_aligned.xt,
	(cell)f_sub.xt,
	(cell)f_negate.xt,
	(cell)f_allot.xt,
	(cell)f_exit.xt
)
link_t *latest=(link_t *)&f_align.link;
/********************************/
FORTHWORD(NULL,"\00",baseinterp,
	(cell)f_docol,
	(cell)f_word.xt,
	(cell)f_find.xt,
	(cell)f_zbranch.xt,
	(cell)4*sizeof(cell),
	(cell)f_execute.xt,
	(cell)f_branch.xt,
	(cell)-6*sizeof(cell),
	(cell)f_lit.xt,
	(cell)0,
	(cell)f_swap.xt,
	(cell)f_count.xt,
	(cell)f_tonumber.xt,
	(cell)f_zbranch.xt,
	(cell)3*sizeof(cell),
	(cell)f_branch.xt,
	(cell)4*sizeof(cell),
	(cell)f_drop.xt,
	(cell)f_branch.xt,
	(cell)-18*sizeof(cell),
	(cell)f_drop.xt,
	(cell)f_drop.xt,
	(cell)f_lit.xt,
	(cell)'?',
	(cell)f_emit.xt,
	(cell)f_branch.xt,
	(cell)-25*sizeof(cell),
)
ffunc_t entry=(ffunc_t)baseinterp.xt;
int main()//(int argc,char **argv)
{
	here=sbrk(4096*sizeof(cell));
	ip=&entry;
	next();
}
