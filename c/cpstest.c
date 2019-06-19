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
 * Creates two definitions from parameter cname:
 * (1) f_cname: the link structure for the word.
 * 	(execution token is available as f_cname.xt)
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

CWORD(NULL,5,"\005DOCOL",docol)
{
	push(rp,ip+1);
	ip=(func_t *)*ip;
	next(ip,sp,rp);
}

/*
 * 		lit
 * f_lit_c will place the cell after it in the code field onto the stack.
 */

CWORD(NULL,3,"\004LIT",lit)
{
	push(sp,*ip);
	next(ip+1,sp,rp);
}

/*
 *		bye
 * For testing purposes, bye does not currently exhibit typical behavior.
 */
CWORD(NULL,3,"\004BYE",bye)
{
	_exit(pop(sp)); /*_exit(0);*/
	next(ip,sp,rp);
}

/*
 *		execute
 * f_execute_c executes the code field pointer on top of the stack.
 * Because all code fields end with f_exit_c, execute can cope with any XT.
 */
CWORD(NULL,7,"\007EXECUTE",execute)
{
	push(rp,ip);
	ip=(func_t *)pop(sp);
	next(ip,sp,rp);
}

/*________ Branching ________*/

CWORD(NULL,6,"\006BRANCH",branch)
{
	ip+=(cell_t)*ip;
	next(ip,sp,rp);
}

CWORD(NULL,7,"\0070BRANCH",zbranch)
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
CWORD(NULL,1,"\001+",add)
	F_2OP(+)
CWORD(NULL,1,"\001-",sub)
	F_2OP(-)
CWORD(NULL,1,"\001*",mul)
	F_2OP(*)
CWORD(NULL,4,"\004/MOD",divmod)
{
	register cell_t b=pop(sp),a=pop(sp);
	push(sp,a%b);
	push(sp,a/b);
	next(ip,sp,rp);
}

/*________ Entry ________*/

#define LIT(n) f_lit_c,(func_t)n
func_t f_oneplus[]={LIT(1),f_add_c,f_exit_c};
func_t prog[]={LIT(1),LIT(2),LIT(f_add.xt),f_execute_c,f_bye_c};
cell_t stack[1024];
cell_t rstack[1024];
int main()/*(int argc,char *argv[])*/
{
	next(prog,&stack[1024],&rstack[1024]);
	return 0;
}
