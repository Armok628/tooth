#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#if INTPTR_MAX > SIZE_MAX
#error "Incompatible type sizes"
#endif
typedef size_t cell;
/******** VM instructions ********/
typedef void (*func_t)();
#define push(sp,val) (*(++sp)=(cell)(val))
#define pop(sp) (*(sp--))
inline void next(func_t *ip,cell *sp,cell *rp)
{
	(*ip)(ip+1,sp,rp);
}
void f_exit(func_t *ip,cell *sp,cell *rp)
{
	ip=(func_t *)pop(rp);
	next(ip,sp,rp);
}
void f_lit(func_t *ip,cell *sp,cell *rp)
{
	push(sp,*(ip++));
	next(ip,sp,rp);
}
void f_bye(func_t *ip,cell *sp,cell *rp)
{
	register cell a=pop(sp);
	_exit(a);
	next(ip,sp,rp);
}
void f_add(func_t *ip,cell *sp,cell *rp)
{
	register cell a=pop(sp),b=pop(sp);
	push(sp,a+b);
	next(ip,sp,rp);
}
/******** Entry ********/
#define LIT(n) f_lit,(func_t)n
func_t prog[]={LIT(1),LIT(2),f_add,f_bye};
cell stack[1024];
cell rstack[1024];
int main()//(int argc,char *argv[])
{
	next(prog,stack,rstack);
	return 0;
}
