#define _DEFAULT_SOURCE
#include <unistd.h>
#include <stdint.h>
#include <string.h>

/*
 * 		Type definitions
 * Generally speaking, the goal is sizeof(cell_t)==sizeof(func_t)
 */

typedef void (*func_t)();
#if INTPTR_MAX > 0xFFFFFFFF
typedef int64_t cell_t;
typedef uint64_t ucell_t;
#elif INTPTR_MAX > 0xFFFF
typedef int32_t cell_t;
typedef uint32_t ucell_t;
#else
typedef int16_t cell_t;
typedef uint16_t ucell_t;
#endif
typedef struct link_s {
	struct link_s *prev;
	cell_t len;
	char *name;
} link_t;

/* For C89, need to manually define bool */
typedef enum {false,true} bool;
enum {F_IMM=0x80,F_HID=0x40};

/*
 * 		CWORD macro
 * Used to define words in C visible to the system.
 * Name is a counted string literal, e.g. "\004WORD"
 * Creates two definitions from parameter cname:
 * (1) f_cname: the link structure for the word.
 * 	(execution token at f_cname.xt, decays to (func_t *))
 * (2) f_cname_c: the C function which implements the word.
 * 	(can be aliased to func_t)
 */

#define CWORD(last,len,name,cname) \
void f_##cname##_c(func_t *ip,cell_t *sp,cell_t *rp); \
struct { \
	link_t link; \
	func_t xt[2]; \
} f_##cname = { \
	{last,len,name}, \
	{f_##cname##_c,f_exit_c} \
}; \
void f_##cname##_c(func_t *ip,cell_t *sp,cell_t *rp)

/*
 *		FORTHWORD/ENDWORD macros
 * Used to define assembler-compiled Forth words; same arguments as CWORD.
 * Parameter deflen represents number of given cells, not counting f_exit_c.
 * Defines a struct f_cname whose execution token is f_cname.xt.
 * Usage e.g.: FORTHWORD(...) {f_lit_c,(func_t)1,f_add_c,f_exit_c} ENDWORD
 */

#define FORTHWORD(last,len,name,cname,deflen) \
struct { \
	link_t link; \
	func_t xt[deflen]; \
} f_##cname = { \
	{last,len,name},

#define ENDWORD };

#define L(x) (func_t)(cell_t)x /* L(iteral), 1 cell */
/* ^ Double typecast to ignore warnings from code field pointers */
#define P(n) f_##n##_c /* (Do) P(rimitive), 1 cell */
#define X(n) f_##n.xt
#define NP(n) P(docol),L(X(n)) /* (Do) N(on)P(rimitive), 2 cells */
#define PL(x) P(lit),L(x) /* P(ush) L(iteral), 2 cells */
/* ^^^ Number of characters in macro name = number of cells. */

/******** VM instructions ********/


/*
 * 		push/pop macros
 * Macros push and pop use parameter sp as a reference.
 * Stacks used in this way are to grow downwards by convention.
 * As a result, sp[n] should always be nth item from TOS.
 */

#define push(sp,val) (*(--sp)=(cell_t)(val))
#define pop(sp) (*(sp++))

/*
 *		next
 * The "inner interpreter" uses direct threading for primitives.
 * N.B.: Primitives use continuation passing style.
 * A call to next should be at the end of every primitive.
 * For handling non-primitives, see docol.
 */

void next(func_t *ip,cell_t *sp,cell_t *rp)
{
	(*ip)(ip+1,sp,rp);
}

/*
 *		exit
 * A function pointer to f_exit_c should be at the end of _all_ code fields.
 * A word with exit in cell two of its code field is a "code word".
 * Code words will be compiled differently from non-code words.
 */

CWORD(NULL,4,"\004EXIT",exit)
{
	ip=(func_t *)pop(rp);
	next(ip,sp,rp);
}

/*
 *		docol
 * f_docol_c executes the code field pointer next in the code field.
 * A pointer to f_docol_c must come before any non-primitive XT.
 * It is _not_ necessary at the beginning of any code fields.
 * N.B.: This behavior is different from normal ITC compilers
 */

CWORD(&f_exit.link,5,"\005DOCOL",docol)
{
	push(rp,ip+1);
	ip=*(func_t **)ip;
	next(ip,sp,rp);
}

/*
 * 		lit
 * f_lit_c will place the cell after it in the code field onto the stack.
 */

CWORD(&f_docol.link,3,"\004LIT",lit)
{
	push(sp,*ip);
	next(ip+1,sp,rp);
}

/*
 *		bye
 * For testing purposes, bye does not currently exhibit typical behavior.
 */
CWORD(&f_lit.link,3,"\004BYE",bye)
{
	_exit(pop(sp)); /*_exit(0);*/
	next(ip,sp,rp);
}

/*
 *		execute
 * f_execute_c executes the code field pointer on top of the stack.
 * Because all code fields end with f_exit_c, execute can cope with any XT.
 */
CWORD(&f_bye.link,7,"\007EXECUTE",execute)
{
	push(rp,ip);
	ip=(func_t *)pop(sp);
	next(ip,sp,rp);
}

/******** Branching ********/

CWORD(&f_execute.link,6,"\006BRANCH",branch)
{
	ip+=(cell_t)*ip;
	next(ip,sp,rp);
}

CWORD(&f_branch.link,7,"\0070BRANCH",zbranch)
{
	ip+=pop(sp)?(cell_t)*ip:1;
	next(ip,sp,rp);
}

/******** Parameter Stack Manipulation ********/

CWORD(&f_zbranch.link,3,"\003DUP",dup)
{
	sp--;
	sp[0]=sp[1];
	next(ip,sp,rp);
}
CWORD(&f_dup.link,4,"\004DROP",drop)
{
	next(ip,sp+1,rp);
}
CWORD(&f_drop.link,4,"\004SWAP",swap)
{
	register cell_t a=sp[1],b=sp[0];
	sp[1]=b;
	sp[0]=a;
	next(ip,sp,rp);
}
CWORD(&f_swap.link,3,"\003ROT",rot)
{
	register cell_t a=sp[2],b=sp[1],c=sp[0];
	sp[2]=b;
	sp[1]=c;
	sp[0]=a;
	next(ip,sp,rp);
}

CWORD(&f_rot.link,3,"\003NIP",nip)
{
	sp[1]=sp[0];
	next(ip,sp+1,rp);
}
CWORD(&f_nip.link,4,"\004TUCK",tuck)
{
	register cell_t a=sp[1],b=sp[0];
	sp--;
	sp[2]=b;
	sp[1]=a;
	sp[0]=b;
	next(ip,sp,rp);
}
CWORD(&f_tuck.link,4,"\004OVER",over)
{
	sp--;
	sp[0]=sp[2];
	next(ip,sp,rp);
}
CWORD(&f_over.link,4,"\004-ROT",unrot)
{
	register cell_t a=sp[2],b=sp[1],c=sp[0];
	sp[2]=c;
	sp[1]=a;
	sp[0]=b;
	next(ip,sp,rp);
}

/******** Return Stack Manipulation ********/


CWORD(&f_unrot.link,2,"\002R@",rfetch)
{
	push(sp,rp[0]);
	next(ip,sp,rp);
}
CWORD(&f_rfetch.link,2,"\002>R",to_r)
{
	push(rp,pop(sp));
	next(ip,sp,rp);
}
CWORD(&f_to_r.link,2,"\002R>",r_from)
{
	push(sp,pop(rp));
	next(ip,sp,rp);
}

/******** Memory Access ********/

CWORD(&f_r_from.link,1,"\001@",fetch)
{
	sp[0]=*(cell_t *)sp[0];
	next(ip,sp,rp);
}
CWORD(&f_fetch.link,1,"\001!",store)
{
	*(cell_t *)sp[0]=sp[1];
	next(ip,sp+2,rp);
}

CWORD(&f_store.link,2,"\002C@",cfetch)
{
	sp[0]=*(char *)sp[0];
	next(ip,sp,rp);
}
CWORD(&f_cfetch.link,2,"\002C!",cstore)
{
	*(char *)sp[0]=(char)sp[1];
	next(ip,sp+2,rp);
}

/******** Arithmetic ********/

#define F_2OP(op) { \
	register cell_t b=pop(sp),a=pop(sp); \
	push(sp,a op b); \
	next(ip,sp,rp); \
}
CWORD(&f_cfetch.link,1,"\001+",add)
	F_2OP(+)
CWORD(&f_add.link,1,"\001-",sub)
	F_2OP(-)
CWORD(&f_sub.link,1,"\001*",mul)
	F_2OP(*)
CWORD(&f_sub.link,3,"\001AND",and)
	F_2OP(&)
CWORD(&f_sub.link,2,"\001OR",or)
	F_2OP(|)
CWORD(&f_sub.link,3,"\001XOR",xor)
	F_2OP(^)
CWORD(&f_mul.link,6,"\006LSHIFT",lshift)
	F_2OP(<<)
CWORD(&f_lshift.link,6,"\006RSHIFT",rshift)
	F_2OP(>>)
CWORD(&f_rshift.link,4,"\004/MOD",divmod)
{
	register cell_t b=pop(sp),a=pop(sp);
	push(sp,a%b);
	push(sp,a/b);
	next(ip,sp,rp);
}

#define F_1OP(op) { \
	sp[0]=op sp[0]; \
	next(ip,sp,rp); \
}
CWORD(&f_divmod.link,6,"\006NEGATE",negate)
	F_1OP(-)
CWORD(&f_negate.link,6,"\006INVERT",invert)
	F_1OP(~)
CWORD(&f_invert.link,2,"\0061+",incr)
	F_1OP(1+)
CWORD(&f_incr.link,2,"\006INVERT",decr)
	F_1OP(1-)

/******** Comparisons  ********/

#define F_CMP(op,t) { \
	register t b=pop(sp),a=pop(sp); \
	push(sp,a op b?~0:0); \
	next(ip,sp,rp); \
}

CWORD(&f_decr.link,1,"\001=",eq)
	F_CMP(==,cell_t)
CWORD(&f_eq.link,1,"\001<",lt)
	F_CMP(<,cell_t)
CWORD(&f_lt.link,1,"\001>",gt)
	F_CMP(>,cell_t)
CWORD(&f_gt.link,2,"\002<=",lte)
	F_CMP(<=,cell_t)
CWORD(&f_lte.link,2,"\002>=",gte)
	F_CMP(>=,cell_t)
CWORD(&f_gte.link,2,"\002<>",neq)
	F_CMP(!=,cell_t)

CWORD(&f_neq.link,2,"\002U<",ult)
	F_CMP(<,ucell_t)
CWORD(&f_ult.link,2,"\002U>",ugt)
	F_CMP(>,ucell_t)
CWORD(&f_ugt.link,3,"\003U<=",ulte)
	F_CMP(<=,ucell_t)
CWORD(&f_ulte.link,3,"\003U>=",ugte)
	F_CMP(>=,ucell_t)

/******** I/O ********/

CWORD(&f_ugte.link,4,"\004EMIT",emit)
{
	static char b;
	b=pop(sp);
	write(STDOUT_FILENO,&b,1);
	next(ip,sp,rp);
}

#define TIB_SIZE (1<<8)
char tib[TIB_SIZE];
char *source=tib;
cell_t source_id=0;
size_t nextkey;
size_t keycount;

CWORD(&f_ugte.link,8,"\010EVALUATE",evaluate)
{
	keycount=(size_t)pop(sp);
	source=(char *)pop(sp);
	nextkey=0;
	source_id=~0;
	next(ip,sp,rp);
}
CWORD(&f_evaluate.link,6,"\006SOURCE",source)
{
	push(sp,source);
	push(sp,keycount);
	next(ip,sp,rp);
}

size_t refill(void)
{
	nextkey=0;
	source=tib;
	source_id=0;
	keycount=read(STDIN_FILENO,tib,TIB_SIZE);
	return keycount;
}
CWORD(&f_source.link,6,"\006REFILL",refill)
{
	push(sp,refill());
	next(ip,sp,rp);
}
char key(void)
{
	if (nextkey>=keycount)
		if (!refill())
			_exit(0);
	return source[nextkey++];
}
CWORD(&f_refill.link,3,"\003KEY",key)
{
	push(sp,key());
	next(ip,sp,rp);
}
#define WORDBUF_SIZE (1<<6)
char *word(void)
{
	static char wordbuf[WORDBUF_SIZE];
	int i=0;
	char c=key();
	while (c<=' ')
		c=key();
	while (c>' ') {
		wordbuf[++i]=c;
		c=key();
	}
	wordbuf[0]=i;
	return wordbuf;
}
CWORD(&f_key.link,4,"\004WORD",word)
{
	push(sp,word());
	next(ip,sp,rp);
}

cell_t base=10;
CWORD(&f_word.link,7,"\007>NUMBER",to_number)
{
	size_t len=pop(sp);
	char *str=(char *)pop(sp);
	cell_t tot=pop(sp);
	cell_t b=base;
	/* Better standards conformance will need switch (str[0]) */
	/* This is good enough for now. */
	bool neg=str[0]=='-';
	str+=neg;
	len-=neg;
	while (len>0) {
		char d=str[0];
		d-='0';
		if (d>9)
			d-='A'-'0'-10;
		if (d<0||d>b)
			break;
		tot=tot*b+d;
		++str;
		--len;
	}
	if (neg)
		tot=-tot;
	push(sp,tot);
	push(sp,str);
	push(sp,len);
	next(ip,sp,rp);
}

FORTHWORD(&f_to_number.link,5,"\005COUNT",count,5) {
	P(dup),P(incr),P(swap),P(cfetch),P(exit)
} ENDWORD

/******** Data Segment Setup ********/

#define DATA_SEG_INC (1<<16)
char *here=NULL;
void init_data_seg(void)
{
	here=sbrk(0);
	sbrk(DATA_SEG_INC);
}

CWORD(&f_count.link,5,"\005ALLOT",allot)
{
	here+=pop(sp);
	next(ip,sp,rp);
}

void f_here_c(func_t *,cell_t *,cell_t *);
/* ^ Forward declaration needed by , and C, */
FORTHWORD(&f_allot.link,1,"\001,",comma,6) {
	P(here),P(store),PL(sizeof(cell_t)),P(allot),P(exit)
} ENDWORD
FORTHWORD(&f_comma.link,2,"\002C,",ccomma,6) {
	P(here),P(cstore),PL(1),P(allot),P(exit)
} ENDWORD

/******** Dictionary Search ********/

link_t *latest;
void find(char *cs,cell_t *sp)
{
	char *n;
	cell_t l,len=cs[0];
	link_t *link=latest;
	for (;link;link=link->prev) {
		int i;
		l=link->len;
		if (l&F_HID)
			continue;
		if ((l&~F_IMM)!=len)
			continue;
		n=link->name;
		for (i=1;i<=len;i++)
			if (n[i]!=cs[i])
				goto CONT;
		push(sp,&((func_t *)link)[3]);
		push(sp,l&F_IMM?1:-1);
		return;
CONT:		continue;
	}
	push(sp,cs);
	push(sp,0);
}
CWORD(&f_ccomma.link,4,"\004FIND",find)
{
	char *cs=(char *)pop(sp);
	find(cs,sp);
	next(ip,sp-2,rp);
}
CWORD(&f_find.link,1,"\001'",tick)
{
	char *cs=word();
	find(cs,sp);
	next(ip,sp-1,rp);
}

/******** Constants ********/

#define F_CONST(val) { \
	push(sp,val); \
	next(ip,sp,rp); \
}

CWORD(&f_tick.link,4,"\004CELL",cell)
	F_CONST(sizeof(cell_t))
CWORD(&f_cell.link,3,"\003>IN",in)
	F_CONST(&nextkey)
CWORD(&f_in.link,9,"\011SOURCE-ID",source_id)
	F_CONST(source_id)
CWORD(&f_source_id.link,4,"\004BASE",base)
	F_CONST(base)
CWORD(&f_base.link,4,"\004HERE",here)
	F_CONST(here)

CWORD(&f_here.link,6,"\006LATEST",latest)
	F_CONST(&latest)
link_t *latest=&f_latest.link;

/******** Entry ********/

FORTHWORD(NULL,0,"\000",prog,4) {
	P(tick),P(execute),P(branch),L(-3)
} ENDWORD

#define ENDOF(s) &s[sizeof(s)/sizeof(s[0])]
cell_t stack[1024];
cell_t rstack[1024];
int main()/*(int argc,char *argv[])*/
{
	init_data_seg();
	next(X(prog),ENDOF(stack),ENDOF(rstack));
	return 0;
}
