;;;;;;; Macros ;;;;;;;

%macro INIT_STACKS 0
	;mov	rsp, stack_end
	mov	rbp, stack
%endmacro

%macro NEXT 0
	mov	rax, [rbx]
	lea	rbx, [rbx+8]
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

; RSP = Stack (manip. with push/pop)
; RBP = Return stack (manip. with RPUSH/RPOP)
; RBX = Next code word (callee-saved register)
; RAX = This code word (volatile register)

COL:
	RPUSH	rbx
	lea	rbx, [rax+8]
	NEXT

ASMWORD EXIT,"EXIT"
	RPOP	rbx
	NEXT

ASMWORD LIT,"LIT"
	push	qword [rbx]
	lea	rbx, [rbx+8]
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

ASMWORD BYE,"BYE"
	mov	rax, SYS_EXIT
	xor	rdi, rdi
	syscall

;;;;;;; I/O ;;;;;;;
%define WBUFSIZE 64

	section .data

wbuf: times WBUFSIZE db 0
wbuftop: dq wbuf
ebuf: db 0

	section .text

ASMWORD KEY,"KEY"
	mov	rax, [wbuftop]
	movzx	eax, byte [rax]
	test	al, al
	jz	.key_read
	inc	qword [wbuftop]
	push	rax
	NEXT
.key_read:
	mov	rax, SYS_READ
	mov	rdi, STDIN
	mov	rsi, wbuf
	mov	rdx, WBUFSIZE-1
	syscall
	test	al, al
	jz	BYE_CODE
	mov	byte [rax+wbuf], 0
	mov	qword [wbuftop], wbuf+1
	movzx	eax, byte [wbuf]
	push	rax
	NEXT

ASMWORD EMIT,"EMIT"
	pop	rax
	mov	rsi, ebuf
	mov	byte [rsi], al
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rdx, 1
	syscall
	NEXT

;;;;;;; Testing code ;;;;;;;
	section .text

plusone:
	dq	COL, LIT, 1, ADD, EXIT

double:
	dq	COL, DUP, ADD, EXIT

testword:
	;dq	COL, LIT, 2, double, double, plusone, temp_exit
	;dq	COL, LIT, 0x4D, EMIT, LIT, 10, EMIT, LIT, 13, temp_exit
	dq	COL, KEY, KEY, KEY, EMIT, ADD, temp_exit

ASMWORD temp_exit,""
	mov	rax, SYS_EXIT
	pop	rdi
	syscall

	global _start
_start:
	INIT_STACKS
	mov	rbx, entry_point
	NEXT

	section .data
entry_point:
	dq	testword
