;;;;;;; Macros ;;;;;;;

%macro INIT_STACKS 0
	;mov	rsp, stack_end
	mov	rbp, stack
%endmacro

%macro NEXT 0
	lodsq ; mov rax,[rsi] ; lea rsi,[rsi+8]
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
	section	.rodata
%1_DICT:
	dq	%[LASTWORD]
	%define LASTWORD %1
	%strlen l %2
	db	%3+%[l],%2,0
	%undef l
%1:
	dq	%1_CODE
	section	.text
%1_CODE:
%endmacro

%define IMM_F 0x80 ; 1<<7
%define HID_F 0x40 ; 1<<6
%define SYS_READ 0
%define STDIN 0
%define SYS_WRITE 1
%define STDOUT 1
%define SYS_EXIT 60

;;;;;;; Stack space ;;;;;;;

	section .bss

stack:
	resq	1024
stack_end:


;;;;;;; Forth structure ;;;;;;;
	section .text

; RSP = Stack (push/pop)
; RBP = Return stack (RPUSH/RPOP)
; RSI = Next code word
; RAX = This code word (can be discarded)

DOCOL:
	RPUSH	rsi
	lea	rsi, [rax+8]
NEXT

ASMWORD EXIT,"EXIT"
	RPOP	rsi
NEXT

ASMWORD LIT,"LIT"
	push	qword [rsi]
	lea	rsi, [rsi+8]
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
	section .text

plusone:
	dq	DOCOL, LIT, 1, ADD, EXIT

double:
	dq	DOCOL, DUP, ADD, EXIT

testword:
	dq	DOCOL, LIT, 2, double, double, plusone, temp_exit

ASMWORD temp_exit,""
	mov	rax, SYS_EXIT
	pop	rdi
	syscall

	global _start
_start:
	INIT_STACKS
	mov	rsi, entry_point
	NEXT

	section .data
entry_point:
	dq	testword
