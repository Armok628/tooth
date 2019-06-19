#include <unistd.h>
#include <stdint.h>
#if INTPTR_MAX > 0xFFFFFFFF
typedef int64_t cell;
#elif INTPTR_MAX > 0xFFFF
typedef int32_t cell;
#else
typedef int16_t cell;
#endif
/******** VM instructions ********/
typedef void (*func)();
#define push(sp,val) (*(--sp)=(cell)(val))
#define pop(sp) (*(sp++))
void next(func *ip,cell *sp,cell *rp)
{
	(*ip)(ip+1,sp,rp);
}
void f_docol(func *ip,cell *sp,cell *rp)
{
	push(rp,ip+1);
	ip=(func *)*ip;
	next(ip,sp,rp);
}
void f_exit(func *ip,cell *sp,cell *rp)
{
	ip=(func *)pop(rp);
	next(ip,sp,rp);
}
void f_lit(func *ip,cell *sp,cell *rp)
{
	push(sp,*ip);
	next(ip+1,sp,rp);
}
void f_bye(func *ip,cell *sp,cell *rp)
{
	_exit(pop(sp));
	next(ip,sp,rp);
}
void f_execute(func *ip,cell *sp,cell *rp)
{
	push(rp,ip);
	ip=(func *)pop(sp);
	next(ip,sp,rp);
}
/******** Arithmetic ********/
#define F_2OP(name,op) \
void name(func *ip,cell *sp,cell *rp) \
{ \
	register cell b=pop(sp),a=pop(sp); \
	push(sp,a op b); \
	next(ip,sp,rp); \
}
F_2OP(f_add,+)
F_2OP(f_sub,-)
F_2OP(f_mul,*)
void f_divmod(func *ip,cell *sp,cell *rp)
{
	register cell b=pop(sp),a=pop(sp);
	push(sp,a%b);
	push(sp,a/b);
	next(ip,sp,rp);
}
/******** Entry ********/
#define LIT(n) f_lit,(func)n
func f_oneplus[]={LIT(1),f_add,f_exit};
func prog[]={LIT(2),LIT(f_oneplus),f_execute,f_bye};
cell stack[1024];
cell rstack[1024];
int main()/*(int argc,char *argv[])*/
{
	next(prog,&stack[1024],&rstack[1024]);
	return 0;
}
