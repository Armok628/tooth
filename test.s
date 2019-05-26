;;;;;;; Macros ;;;;;;;

%macro NEXT 0
	mov	rax, [rbx]
	add	rbx, 8
	jmp	[rax]
%endmacro

%macro RPUSH 1
	mov	[rbp], %1
	add	rbp, 8
%endmacro

%macro RPOP 1
	sub	rbp, 8
	mov	%1, [rbp]
%endmacro

%define LASTLINK 0

%macro DICTLINK 2-3 0
	section	.rodata
%1_LINK:
	dq	$%[LASTLINK]
	%define LASTLINK %1_LINK
	%strlen l %2
	db	%3+%[l],%2,0
	%undef l
%endmacro

%macro ASMWORD 2-3 0
	DICTLINK %1, %2, %3
$%1:
	dq	%1_ASM
	section	.text
%1_ASM:
%endmacro

%macro FORTHWD 2-3+ 0
	DICTLINK %1, %2, %3
$%1:
%endmacro

%macro CONSTANT 3
ASMWORD %1, %2
	push	%3
	NEXT
%endmacro

%macro VARIABLE 2-3 0
	section .data
%1_VAR: dq	%3
	CONSTANT %1, %2, %1_VAR
%endmacro

%define F_IMM 0x80 ; 1<<7
%define F_HID 0x40 ; 1<<6
%define SYS_READ 0
%define STDIN 0
%define SYS_WRITE 1
%define STDOUT 1
%define SYS_EXIT 60
%define SYS_FCNTL 72
%define SYS_BRK 12

;;;;;;; Return stack setup ;;;;;;;

	section .bss

ret_stack: resq 1024

	section .text

init_ret_stack:
	mov	rbp, ret_stack
	ret

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
	add	rbx, 8
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

ASMWORD FETCH, "!"
	pop	rax
	push	qword [rax]
	NEXT

ASMWORD STORE, "@"
	pop	rax
	pop	qword [rax]
	NEXT

ASMWORD	BYE, "BYE"
	mov	rax, SYS_EXIT
	xor	rdi, rdi
	syscall

	section .bss

charbuf: resb 1

	section .text

ASMWORD	EMIT, "EMIT"
	pop	rax
	mov	rsi, charbuf
	mov	byte [rsi], al
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov	rdx, 1
	syscall
	NEXT

;;;;;;; Parsing ;;;;;;;

%define BUFSIZE 256

	section .data

inputbuf: times BUFSIZE db 0
nextkey: dq	inputbuf
wordbuf: times 64 db 0

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
	mov	rsi, inputbuf
	mov	rdx, BUFSIZE-1
	syscall
	pop	rdi
	test	al, al
	jz	.exit
	mov	byte [inputbuf+rax], 0
	mov	qword [nextkey], inputbuf+1
	movzx	eax, byte [inputbuf]
	ret
.exit:
	mov	eax, SYS_EXIT
	xor	rdi, rdi
	syscall

ASMWORD WORD, "WORD"
	call	_WORD
	push	wordbuf
	push	rdi ; word length
	NEXT
_WORD:
	mov	rdi, wordbuf
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
	sub	rdi, wordbuf
	ret

;;;;;;; Data segment setup ;;;;;;;

VARIABLE HERE,"HERE"

%define DATA_SEG_SIZE 4096
init_data_seg:
	xor	rdi, rdi
	mov	rax, SYS_BRK
	syscall
	mov	qword [HERE_VAR], rax
	lea	rdi, [rax+DATA_SEG_SIZE]
	mov	rax, SYS_BRK
	syscall
	ret

;;;;;;; Other variables/constants ;;;;;;;

CONSTANT R0,"R0",ret_stack
CONSTANT DOCOL_CONST,"DOCOL",DOCOL

;;;;;;; Testing code ;;;;;;;

	section .text

FORTHWD testword, ""
	dq	DOCOL, $WORD, temp_put_str, LIT, ' ', EMIT, \
		$WORD, temp_put_str, LIT, `\n`, EMIT, BYE

ASMWORD	temp_put_str, ""
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	pop	rdx
	pop	rsi
	syscall
	NEXT

	global _start
_start:
	call	init_data_seg
	call	init_ret_stack
	mov	rbx, entry_point
	NEXT

	section .rodata
entry_point:
	dq	testword
