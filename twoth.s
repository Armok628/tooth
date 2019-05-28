;;;;;;; Macros ;;;;;;;

%macro NEXT 0
	mov	rax, [rbx]
	add	rbx, 8
	jmp	[rax]
%endmacro

%macro RPUSH 1
	add	rbp, 8
	mov	qword [rbp], %1
%endmacro

%macro RPOP 1
	mov	%1, qword [rbp]
	sub	rbp, 8
%endmacro

%define LASTLINK 0

%macro DICTLINK 2-3 0
	section	.rodata
%1_LINK:
	dq	$%[LASTLINK]
	%define LASTLINK %1_LINK
	%strlen l %2
	db	%3|%[l],%2,0
	%undef l
%endmacro

%macro ASMWORD 2-3 0
	DICTLINK %1, %2, %3
$%1:
	dq	%1_ASM
	section	.text
%1_ASM:
%endmacro

%macro FORTHWORD 2-3+ 0
	DICTLINK %1, %2, %3
$%1:
%endmacro

%macro FORTHCONST 3
ASMWORD %1, %2, F_IMM
	push	qword %3
	NEXT
%endmacro

%macro FORTHVAR 2-3 0
	section .data
%1_VAR: dq	%3
	FORTHCONST %1, %2, %1_VAR
%endmacro

;;;;;;; Assembler constants ;;;;;;;

F_IMM equ 0x80
F_HID equ 0x40

STDIN equ 0
STDOUT equ 1
STDERR equ 2
SYS_READ equ 0
SYS_WRITE equ 1
SYS_BRK equ 12
SYS_EXIT equ 60
SYS_FCNTL equ 72

;;;;;;; Return stack setup ;;;;;;;

	section .bss

ret_stack: resq 1024

	section .text

init_ret_stack:
	mov	rbp, ret_stack
	ret

;;;;;;; Basic FORTH primitives ;;;;;;;

	section .text

; RSP = Stack (manip. with push/pop)
; RBP = Return stack (manip. with RPUSH/RPOP)
; RBX = Next execution token (callee-saved register)
; RAX = This execution token (volatile register)

DOCOL: ; Not a "real" FORTH word, per se
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

ASMWORD	BYE, "BYE"
	mov	rax, SYS_EXIT
	xor	rdi, rdi
	syscall

ASMWORD EXECUTE, "EXECUTE"
	pop	rax
	jmp	[rax]

;;;;;;; Stack manipulation ;;;;;;;

ASMWORD	DUP, "DUP" ; ( a -- a a )
	push	qword [rsp]
	NEXT

ASMWORD	DROP, "DROP" ; ( a -- )
	sub	rsp, 8
	NEXT

ASMWORD SWAP, "SWAP" ; ( a b -- b a )
	pop	rdi
	pop	rsi
	push	rdi
	push	rsi
	NEXT

ASMWORD ROT, "ROT" ; ( a b c -- b c a )
	pop	rdi
	pop	rsi
	pop	rdx
	push	rsi
	push	rdi
	push	rdx
	NEXT

ASMWORD OVER, "OVER" ; ( a b -- a b a )
	push	qword [rsp-8]
	NEXT

;;;;;;; Return stack manipulation ;;;;;;;

ASMWORD TO_R, ">R"
	pop	rax
	RPUSH	rax
	NEXT

ASMWORD FROM_R, "R>"
	RPOP	rax
	push	rax
	NEXT

ASMWORD R_FETCH, "R@"
	push	qword [rbp]
	NEXT

;;;;;;; Math operations ;;;;;;;

ASMWORD	ADD, "+" ; ( a b -- a+b)
	pop	rax
	add	[rsp], rax
	NEXT

ASMWORD	SUB, "-" ; ( a b -- a-b )
	pop	rax
	sub	[rsp], rax
	NEXT

ASMWORD MUL, "*" ; ( a b -- a*b )
	pop	rax
	imul	qword [rsp]
	mov	qword [rsp], rax
	NEXT

ASMWORD DIVMOD, "/MOD" ; ( a b -- a%b a/b )
	mov	rax, [rsp-8]
	div	qword [rsp]
	mov	qword [rsp-8], rdx
	mov	qword [rsp], rax
	NEXT

ASMWORD AND, "AND" ; ( a b -- a&b )
	pop	rax
	and	qword [rsp], rax
	NEXT

ASMWORD OR, "OR" ; ( a b -- a|b )
	pop	rax
	or	qword [rsp], rax
	NEXT

ASMWORD XOR, "XOR" ; ( a b -- a^b )
	pop	rax
	xor	qword [rsp], rax
	NEXT

ASMWORD LSHIFT, "LSHIFT"
	pop	rcx
	shl	qword [rsp], cl
	NEXT

ASMWORD RSHIFT, "RSHIFT"
	pop	rcx
	shr	qword [rsp], cl
	NEXT

ASMWORD INCR, "1+"
	inc	qword [rsp]
	NEXT

ASMWORD DECR, "1-"
	dec	qword [rsp]
	NEXT

ASMWORD NEGATE, "NEGATE" ; ( x -- -x )
	neg	qword [rsp]
	NEXT

ASMWORD INVERT, "INVERT" ; ( x -- ~x )
	not	qword [rsp]
	NEXT

;;;;;;; Comparisons ;;;;;;;

SET_TOS_TRUE:
	mov	qword [rsp], ~0
	NEXT
SET_TOS_FALSE:
	mov	qword [rsp], 0
	NEXT

%macro CMPWORD 3
ASMWORD %1, %2
	pop	rax
	cmp	qword [rsp], rax
	%3	SET_TOS_TRUE
	jmp	SET_TOS_FALSE
%endmacro

CMPWORD EQ, "=", je
CMPWORD NEQ, "<>", jne
CMPWORD GT, "<", jl
CMPWORD LT, ">", jg
CMPWORD ULT, "U>", ja
CMPWORD UGT, "U<", jb

;;;;;;; Store/Fetch ;;;;;;;

ASMWORD FETCH, "!" ; ( addr -- qword )
	pop	rsi
	push	qword [rsi]
	NEXT

ASMWORD BYTEFETCH, "C!" ; ( addr -- byte )
	pop	rsi
	movzx	eax, byte [rsi]
	push	rax
	NEXT

ASMWORD STORE, "@" ; ( qword addr -- )
	pop	rdi
	pop	qword [rdi]
	NEXT

ASMWORD BYTESTORE, "C@" ; ( byte addr -- )
	pop	rdi
	pop	rax
	mov	byte [rdi], al
	NEXT

ASMWORD COMMA, ","
	mov	rdi, [HERE_VAR]
	pop	qword [rdi]
	add	qword [HERE_VAR], 8
	NEXT

ASMWORD BYTECOMMA, "C,"
	pop	rax
	mov	rdi, [HERE_VAR]
	mov	byte [rdi], al
	inc	qword [HERE_VAR]
	NEXT

ASMWORD ALLOT, "ALLOT"
	pop	rax
	add	qword [HERE_VAR], rax
	NEXT

;;;;;;; Branching ;;;;;;;

ASMWORD BRANCH, "BRANCH"
	add	rbx, qword [rbx]
	NEXT

ASMWORD ZBRANCH, "0BRANCH"
	pop	rax
	test	rax, rax
	jz	BRANCH_ASM
	add	rbx, 8
	NEXT

;;;;;;; Output ;;;;;;;

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

;;;;;;; Parser ;;;;;;;

BUFSIZE equ 256

	section .data

inputbuf: times BUFSIZE db 0
keycount: dq 0
nextkey: dq 0
wordbuf: times 64 db 0

	section .text

ASMWORD	KEY, "KEY"
	call	_KEY
	push	rax
	NEXT
_KEY:
	mov	rdx, [nextkey]			; get nextkey
	mov	rcx, [keycount]			; get keycount
	cmp	rdx, rcx			; compare
	jnl	.read 				; if nextkey!<keycount, read
	movzx	eax, byte [inputbuf+rdx]	; else load next key
	inc	qword [nextkey]	 		; increment nextkey
	ret 					; return with key in al
.read:
	push	rdi 				; preserve rdi (for stosb in WORD)
	mov	rax, SYS_READ 			; need to read more data
	mov	rdi, STDIN 			; from stdin
	mov	rsi, inputbuf 			; into inputbuf
	mov	rdx, BUFSIZE-1 			; for at most BUFSIZE-1 bytes
	syscall 				; get the data
	pop	rdi 				; restore rdi
	test	al, al				; check number of bytes read
	jz	.exit 				; if no bytes were read, quit
	mov	qword [keycount], rax		; update keycount
	mov	qword [nextkey], 1		; update nextkey
	movzx	eax, byte [inputbuf] 		; get key from buffer
	ret 					; return with key in al
.exit:
	mov	rax, SYS_EXIT
	xor	rdi, rdi
	syscall

ASMWORD SOURCE, "SOURCE"
	push	qword inputbuf
	push	qword [keycount]
	NEXT

ASMWORD WORD, "WORD"
	call	_WORD
	push	qword wordbuf
	push	rdi 				; word length
	NEXT
_WORD:
	mov	rdi, wordbuf
.start:
	call	_KEY 				; get a key in al
	cmp	al, byte ' '
	jle	.start 				; if key is whitespace, try again
	cmp	al, byte '('
	je	.skip 				; if key is '(', skip comment
.key:
	stosb 					; store key
	call	_KEY 				; get a key in al
	cmp	al, byte ' '
	jle	.end 				; if key is whitespace, finish
	jmp	.key 				; continue
.skip:
	call	_KEY 				; get a key in al
	cmp	al, byte `)`
	jne	.skip 				; if key is not newline, continue
	jmp	.start 				; try again for word
.end:
	sub	rdi, wordbuf			; put length in rdi
	ret

;;;;;;; Execution Token Finder ;;;;;;;

ASMWORD FIND, "'"
	pop	rdx ; length
	pop	rsi ; string
	call	_FIND
	push	rax
	NEXT
_FIND: ; rdx=len, rsi=str
	mov	rax, last_link
.next:
	mov	rax, [rax] 			; go to next word
	test	rax, rax
	jz	.undef 				; if NULL, none left
	movzx	ecx, byte [rax+8] 		; get entry string length|flags
	test	cl, F_HID 			; if word is hidden...
	jnz	.next 				; move on.
	and	cl, ~F_IMM 			; remove immediate flag
	cmp	cl, dl 				; compare lengths
	jne	.next 				; if not equal, move on
	lea	rdi, [rax+9] 			; else load entry string
.cmpstr:
	push	rsi
	repe	cmpsb 				; compare strings
	pop	rsi
	jne	.next 				; if not equal, move on
	lea	rax, [rax+8+1+rdx+1]		; else load xt into rax
	ret					; return the xt
.undef:						; if not found:
	xor	rax, rax			; return 0
	ret

;;;;;;; Variables/Constants ;;;;;;;

	section .data
S0:	dq 0 ; To be initialized later
last_link: dq LATEST_LINK

FORTHVAR HERE, "HERE" ; To be initialized later
FORTHCONST BUF_INDEX, ">IN", nextkey
FORTHCONST R0, "R0", ret_stack
FORTHCONST DOCOL_CONST, "DOCOL", DOCOL

FORTHCONST LATEST, "LATEST", last_link

;;;;;;; Data segment setup ;;;;;;;

DATA_SEG_SIZE equ 4096

init_data_seg:
	xor	rdi, rdi
	mov	rax, SYS_BRK
	syscall
	mov	qword [HERE_VAR], rax
	lea	rdi, [rax+DATA_SEG_SIZE]
	mov	rax, SYS_BRK
	syscall
	ret

;;;;;;; Testing code ;;;;;;;

FORTHWORD baseinterp, ""
	dq	DOCOL, $WORD, FIND, EXECUTE, BRANCH, -32

ASMWORD	temp_put_str, ""
	mov	qword [S0], rsp
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	pop	rdx
	pop	rsi
	syscall
	NEXT

	global _start
_start:
	cld
	call	init_data_seg
	call	init_ret_stack
	mov	rbx, entry_point
	NEXT

	section .rodata

entry_point:
	dq	baseinterp
