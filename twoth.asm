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

%define PREVLINK 0

%macro DICTLINK 2-3 0
	section	.rodata
%1_LINK:
	dq	$%[PREVLINK]
	%define PREVLINK %1_LINK
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

ASMWORD	LITERAL, "LITERAL"
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
	add	rsp, 8
	NEXT

ASMWORD SWAP, "SWAP" ; ( a b -- b a )
	pop	rdi ; b
	pop	rsi ; a
	push	rdi ; b
	push	rsi ; a
	NEXT

ASMWORD ROT, "ROT" ; ( a b c -- b c a )
	pop	rdi ; c
	pop	rsi ; b
	pop	rdx ; a
	push	rsi ; b
	push	rdi ; c
	push	rdx ; a
	NEXT

ASMWORD UNROT, "-ROT" ; ( a b c -- c a b )
	pop	rdi ; c
	pop	rsi ; b
	pop	rdx ; a
	push	rdi ; c
	push	rdx ; a
	push	rsi ; b
	NEXT

ASMWORD OVER, "OVER" ; ( a b -- a b a )
	push	qword [rsp+8]
	NEXT

ASMWORD NIP, "NIP" ; ( a b -- b )
	pop	qword [rsp]
	NEXT

ASMWORD TUCK, "TUCK" ; (a b -- b a b)
	pop	rdi ; b
	pop	rsi ; a
	push	rdi ; b
	push	rsi ; a
	push	rdi ; b
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

ASMWORD RFETCH, "R@"
	push	qword [rbp]
	NEXT

;;;;;;; Direct stack manipulation ;;;;;;;

ASMWORD RSPFETCH, "RSP@"
	push	rsp
	NEXT

ASMWORD RSPSTORE, "RSP!"
	pop	rsp
	NEXT

ASMWORD RBPFETCH, "RBP@"
	push	rbp
	NEXT

ASMWORD RBPSTORE, "RBP!"
	pop	rbp
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
	mov	rax, [rsp+8]
	xor	rdx, rdx
	div	qword [rsp]
	mov	qword [rsp+8], rdx
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
CMPWORD GTE, "<=", jle
CMPWORD LT, ">", jg
CMPWORD LTE, ">=", jge
CMPWORD UGT, "U<", jb
CMPWORD UGTE, "U<=", jbe
CMPWORD ULT, "U>", ja
CMPWORD ULTE, "U>=", jae

;;;;;;; Store/Fetch ;;;;;;;

ASMWORD STORE, "!" ; ( qword addr -- )
	pop	rdi
	pop	qword [rdi]
	NEXT

ASMWORD FETCH, "@" ; ( addr -- qword )
	pop	rsi
	push	qword [rsi]
	NEXT

ASMWORD CSTORE, "C!" ; ( byte addr -- )
	pop	rdi
	pop	rax
	mov	byte [rdi], al
	NEXT

ASMWORD CFETCH, "C@" ; ( addr -- byte )
	pop	rsi
	movzx	eax, byte [rsi]
	push	rax
	NEXT

ASMWORD ALLOT, "ALLOT"
	pop	rax
	add	qword [here], rax
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

termbuf: times BUFSIZE db 0 ; fetch with TIB
keycount: dq 0 ; fetch with SOURCE
nextkey: dq 0 ; fetch with >IN
pad: times 64 db 0 ; fetch with PAD

inputbuf: dq termbuf ; store with EVALUATE
sourceid: dq 0 ; fetch with SOURCE-ID

base: dq 10 ; fetch address with BASE

	section .text

ASMWORD SOURCE, "SOURCE"
	push	qword [inputbuf]
	push	qword [keycount]
	NEXT

ASMWORD EVALUATE, "EVALUATE"
	pop	qword [keycount]
	pop	qword [inputbuf]
	NEXT

ASMWORD	KEY, "KEY" ; ( -- c )
	call	_KEY
	push	rax
	NEXT
_KEY: ; => al=key
	mov	rcx, qword [nextkey]		; get next key index
	cmp	rcx, qword [keycount]		; compare to # chars in buffer
	jge	.read				; if too high, get more input
	inc	qword [nextkey]			; else increment next key index
	mov	rax, qword [inputbuf]		; get pointer to input buffer
	movzx	eax, byte [rax+rcx]		; get key from buffer
	ret					; return it
.read:
	mov	rsi, termbuf			; load terminal buffer address
	mov	qword [inputbuf], rsi		; store as pointer to input buffer
	mov	qword [sourceid], 0		; reset SOURCE_ID
	push	rdi				; preserve rdi for stosb in word
	mov	rax, SYS_READ
	mov	rdi, STDIN
	mov	rdx, BUFSIZE
	syscall					; read(0,termbuf,BUFSIZE)
	pop	rdi				; restore rdi
	test	rax, rax			; check for any bytes read
	jz	BYE_ASM 			; if none, exit
	mov	qword [keycount], rax		; else set keycount
	mov	qword [nextkey], 1		; reset next key index
	movzx	eax, byte [termbuf]		; load first key
	ret					; return key in rax

ASMWORD WORD, "WORD", F_IMM ; ( -- addr u )
	call	_WORD
	push	rsi
	push	rdx
	NEXT

_WORD: ; => rsi=str, rdx=len
	mov	rdi, pad
.start:
	call	_KEY 				; get a key in al
	cmp	al, byte ' '
	jle	.start 				; if key is whitespace, try again
.key:
	stosb 					; store key
	call	_KEY 				; get a key in al
	cmp	al, byte ' '
	jle	.end 				; if key is whitespace, finish
	jmp	.key 				; continue
.end:
	mov	rsi, pad			; load string into rsi
	mov	rdx, rdi
	sub	rdx, rsi			; load length into rdx
	ret

ASMWORD TONUMBER, ">NUMBER" ; ( addr u -- n err )
	pop	rcx				; get string length
	pop	rsi				; get string address
	pop	rax				; get total
	mov	rdi, qword [base]		; get number base
	cmp	byte [rsi], '-'			; check for negative
	push	qword 0				; push 0 in case it isn't
	jne	.loop				; continue if nonnegative
	mov	qword [rsp], 1			; else replace 0 with 1
	inc	rsi				; skip negative sign
	dec	rcx
.loop:
	test	rcx, rcx			; characters left?
	jz	.sign				; if not, finish up
	mul	rdi				; multiply total by base
	movzx	edx, byte [rsi]			; get next digit
	sub	dl, '0'				; get digit's value
	jb	.sign				; if <0, exit early
	cmp	dl, 10
	jl	.chkbase			; if <10, move on
	sub	dl, 'A'-'0'-10			; get digit's A-Z value
	cmp	dl, 10
	jb	.sign				; if <10, exit early
.chkbase:
	cmp	rdx, rdi
	jge	.sign				; if >base, exit early
.add_dig:
	add	rax, rdx			; add to total
	inc	rsi				; increment string pointer
	dec	rcx				; one character down
	jmp	.loop				; get more characters
.sign:						; when finished:
	pop	rdx				; check if it was negative
	test	rdx, rdx
	jz	.done				; if not, return
	neg	rax				; else negate
.done:
	push	rax				; push total
	push	rsi				; push string
	push	rcx				; push # of remaining characters
	NEXT

;;;;;;; "Finding" words ;;;;;;;

ASMWORD FIND, "FIND" ; ( addr u -- xt -1 | xt 1 | addr u 0 )
	pop	rdx				; get string length
	pop	rsi				; get string address
	call	_FIND				; load entry into rax
	test	rcx, rcx			; test error
	jz	.notfound			; if no error:
	lea	rax, [rax+8+1+rdx+1]		; load xt into rax
	push	rax				; push xt
	push	rcx				; push error
	NEXT
.notfound:					; else:
	push	rsi				; put string address back
	push	rdx				; put string length back
	push	rcx				; leave error code on stack
	NEXT
_FIND: ; rsi=str, rdx=len => rsi=str, rdx=len, rax=entry, rcx=-1|0|1
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
	push	rsi				; save search string
	repe	cmpsb 				; compare strings
	pop	rsi				; restore search string
	jne	.next 				; if not equal, try again
	movzx	ecx, byte [rax+8]		; else reload length|flags
	test	cl, F_IMM			; test for immediacy
	mov	rcx, 1				; set error to 1 (found, immediate)
	jnz	.imm				; if immediate, return now
	neg	rcx				; else set error to -1 (found)
.imm:
	ret
.undef:						; if not found:
	xor	rax, rax			; set entry to 0
	xor	rcx, rcx			; set error to 0 (not found)
	ret

ASMWORD TICK, "'", F_IMM
	call	_WORD
	call	_FIND
	lea	rax, [rax+8+1+rdx+1]		; load xt into rax
	push	rax
	NEXT

;;;;;;; System call ;;;;;;;


ASMWORD SYSCALL0, "SYSCALL0"
	jmp	syscall0
ASMWORD SYSCALL1, "SYSCALL1"
	jmp	syscall1
ASMWORD SYSCALL2, "SYSCALL2"
	jmp	syscall2
ASMWORD SYSCALL3, "SYSCALL3"
	jmp	syscall3
ASMWORD SYSCALL4, "SYSCALL4"
	jmp	syscall4
ASMWORD SYSCALL5, "SYSCALL5"
	jmp	syscall5
ASMWORD SYSCALL6, "SYSCALL6"
	jmp	syscall6

syscall6:
	pop	r9
syscall5:
	pop	r8
syscall4:
	pop	r10
syscall3:
	pop	rdx
syscall2:
	pop	rsi
syscall1:
	pop	rdi
syscall0:
	pop	rax
	syscall
	push	rax
	NEXT

;;;;;;; Variables/Constants ;;;;;;;

FORTHCONST HERE, "HERE", [here]
FORTHCONST BUF_INDEX, ">IN", nextkey
FORTHCONST R0, "R0", ret_stack
FORTHCONST DOCOL_CONST, "DOCOL", DOCOL
FORTHCONST S0, "S0", [S0_CONST]
FORTHCONST SOURCE_ID, "SOURCE-ID", [sourceid]
FORTHCONST TIB, "TIB", termbuf
FORTHCONST PAD, "PAD", pad
FORTHCONST BASE, "BASE", base
FORTHCONST F_IMM_CONST, "F_IMM", F_IMM
FORTHCONST CELL, "CELL", 8

FORTHCONST LATEST, "LATEST", last_link

	section .data
S0_CONST: dq 0 ; To be initialized later
here: dq 0 ; To be initialized later
last_link: dq PREVLINK

;;;;;;; Data segment setup ;;;;;;;

	section .text

DATA_SEG_SIZE equ 4096

init_data_seg:
	xor	rdi, rdi
	mov	rax, SYS_BRK
	syscall
	mov	qword [here], rax
	lea	rdi, [rax+DATA_SEG_SIZE]
	mov	rax, SYS_BRK
	syscall
	ret

;;;;;;; Base interpreter code ;;;;;;;

FORTHWORD baseinterp, ""
	dq	DOCOL, $WORD, FIND, ZBRANCH, 32, EXECUTE, BRANCH, -48, \
			LITERAL, 0, UNROT, TONUMBER, ZBRANCH, 24, BRANCH, 32, \
			DROP, BRANCH, -136, \
			DROP, DROP, LITERAL, '?', EMIT, BRANCH, -192

;;;;;;; Executable entry point ;;;;;;;

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
