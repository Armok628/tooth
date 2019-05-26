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

%macro ASMWORD	2-3 0
	section	.rodata
%1_DICT:
	dq	$%[LASTWORD]
	%define LASTWORD %1
	%strlen l %2
	db	%3+%[l],%2,0
	%undef l
$%1:
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
%define SYS_FCNTL 72

;;;;;;; Reserved space ;;;;;;;

	section .bss

cbuf:	resb	1
stack:	resq	1024


;;;;;;; Forth primitives ;;;;;;;

	section .text

; RSP = Stack (manip. with push/pop)
; RBP = Return stack (manip. with RPUSH/RPOP)
; RBX = Next code word (callee-saved register)
; RAX = This code word (volatile register)

DOCOL:
	RPUSH	rbx
	lea	rbx, [rax+8]
	NEXT

ASMWORD	EXIT, "EXIT"
	RPOP	rbx
	NEXT

ASMWORD	LIT, "LIT"
	push	qword [rbx]
	lea	rbx, [rbx+8]
	NEXT

ASMWORD	DUP, "DUP"
	push	qword [rsp]
	NEXT

ASMWORD	DROP, "DROP"
	pop	rax
	NEXT

ASMWORD SWAP, "SWAP"
	pop	rdi
	pop	rsi
	push	rdi
	push	rsi
NEXT

ASMWORD ROT, "ROT"
	pop	rdi
	pop	rsi
	pop	rdx
	push	rsi
	push	rdi
	push	rdx
NEXT

ASMWORD	ADD, "+"
	pop	rax
	add	[rsp], rax
	NEXT

ASMWORD INVERT, "INVERT"
	not	qword [rsp]
	NEXT

ASMWORD	BYE, "BYE"
	mov	rax, SYS_EXIT
	xor	rdi, rdi
	syscall

ASMWORD	EMIT, "EMIT"
	pop	rax
	mov	rsi, cbuf
	mov	byte [rsi], al
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rdx, 1
	syscall
	NEXT

;;;;;;; Parsing ;;;;;;;

%define BUFSIZE 256

	section .data

buf: times BUFSIZE db 0
nextkey: dq buf
wbuf: times 64 db 0

	section .text

ASMWORD	KEY, "KEY"
	call	_KEY
	push	rax
	NEXT
_KEY:
	mov	rax, [nextkey]
	movzx	eax, byte [rax]
	test	al, al
	jz	.read
	inc	qword [nextkey]
	ret
.read:
	push	rdi ; preserve for stosb
	mov	rax, SYS_READ
	mov	rdi, STDIN
	mov	rsi, buf
	mov	rdx, BUFSIZE-1
	syscall
	pop	rdi
	test	al, al
	jz	BYE_CODE
	mov	byte [buf+rax], 0
	mov	qword [nextkey], buf+1
	movzx	eax, byte [buf]
	ret

ASMWORD WORD, "WORD"
	mov	rdi, wbuf
.start:
	call	_KEY
	cmp	al, byte ' '
	jle	.start
	cmp	al, byte '\'
	je	.skip
.key:
	stosb; mov byte [rdi], al ; inc rdi
	call	_KEY
	cmp	al, byte ' '
	jle	.end
	jmp	.key
.skip:
	call	_KEY
	cmp	al, byte `\n`
	jne	.skip
	jmp	.start
.end:
	push	wbuf
	sub	rdi, wbuf
	push	rdi
	NEXT

;;;;;;; Testing code ;;;;;;;

	section .text

plusone:
	dq	DOCOL, LIT, 1, ADD, EXIT

double:
	dq	DOCOL, DUP, ADD, EXIT

testword:
	dq	DOCOL, $WORD, temp_put_str, LIT, ' ', EMIT, $WORD, temp_put_str, LIT, `\n`, EMIT, BYE

ASMWORD	temp_put_str, ""
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	pop	rdx
	pop	rsi
	syscall
	NEXT

	global _start
_start:
	INIT_STACKS
	mov	rbx, entry_point
	NEXT

	section .data
entry_point:
	dq	testword
