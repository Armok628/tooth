;;;;;;; Macros ;;;;;;;

%macro INIT_STACKS 0
	;mov	rsp, stack_end
	mov	rbp, stack
%endmacro

%macro NEXT 0
	mov	rax, rsi
	lea	rsi, [rsi+8]
	jmp	[rax]
%endmacro

%macro RPUSH 1
	mov	[rbp], %1
	lea	rbp, [rbp+8]
%endmacro

%macro RPOP 1
	lea	rbp, [rbp-8]
	mov	%1, [rbp]
%endmacro

%define LASTWORD 0

%macro ASMWORD 2-3 0
	%strlen l %2
	section	.rodata
	%{1}_DICT:
	dq	%[LASTWORD]
	%define LASTWORD %1
	db	%3+%[l],%2,0
	%undef l
	dq	%1
	section	.text
	%{1}:
%endmacro

%define IMMEDIATE 0x80 ;1<<7

;;;;;;; Stack space ;;;;;;;

	section .bss

stack:
	resq	1024
stack_end:


;;;;;;; Forth primitives ;;;;;;;

	section	.text

; RSP = Stack (push/pop)
; RBP = Return stack (RPUSH/RPOP)
; RSI = "Instruction pointer"
; RAX = Accumulator

ASMWORD DOCOL,"DOCOL"
	RPUSH	rsi
	lea	rsi,[rax+8]
NEXT

ASMWORD EXIT,"EXIT"
	RPOP	rsi
NEXT

ASMWORD DUP,"DUP"
	push	qword [rsp]
NEXT

ASMWORD DROP,"DROP"
	pop	rax
NEXT

ASMWORD ADD,"+"
	pop	rax
	add	[rsp], rax
NEXT

;;;;;;; Testing code ;;;;;;;

TESTING:
	dq	DOCOL, DUP, ADD, exit

exit:
	mov	eax, 1
	pop	rbx
	int	0x80

	global _start
_start:
	INIT_STACKS
	push	qword 2
	mov	rsi, TESTING
	NEXT
