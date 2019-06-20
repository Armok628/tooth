#include <unistd.h>
#include <stdint.h>

/*
 * 		Type definitions
 * Generally speaking, the goal is sizeof(cell_t)==sizeof(func_t)
 */

typedef void (*func_t)();
#if INTPTR_MAX > 0xFFFFFFFF
typedef int64_t cell_t;
#elif INTPTR_MAX > 0xFFFF
typedef int32_t cell_t;
#else
typedef int16_t cell_t;
#endif
typedef struct link_s {
	struct link_s *prev;
	cell_t len;
	char *name;
} link_t;

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


/*________ VM instructions ________*/


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

/*________ Branching ________*/

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

/*________ Arithmetic ________*/

#define F_2OP(op) \
{ \
	register cell_t b=pop(sp),a=pop(sp); \
	push(sp,a op b); \
	next(ip,sp,rp); \
}
CWORD(&f_zbranch.link,1,"\001+",add)
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

/*________ Comparisons  ________*/

#define F_CMP(op) \
{ \
	register cell_t b=pop(sp),a=pop(sp); \
	push(sp,a op b?~0:0); \
	next(ip,sp,rp); \
}

CWORD(&f_divmod.link,1,"\001=",eq)
	F_CMP(==)

/*________ Entry ________*/

#define F(x) (func_t)(cell_t)x
/* ^ Double typecast to ignore warnings from code field pointers */
#define P(n) f_##n##_c /* P(rimitive) */
#define NP(n) P(docol),F(f_##n.xt) /* N(on)P(rimitive) */
#define LT(x) P(lit),F(x) /* L(i)T(eral) */
FORTHWORD(NULL,2,"\0021+",oneplus,4) {
	LT(1),P(add),P(exit)
} ENDWORD
FORTHWORD(NULL,0,"\000",prog,5) {
	LT(2),NP(oneplus),P(bye)
} ENDWORD
cell_t stack[1024];
cell_t rstack[1024];
int main()/*(int argc,char *argv[])*/
{
	next(f_prog.xt,&stack[1024],&rstack[1024]);
	return 0;
}
