;;;;;;; Macros ;;;;;;;

%macro NEXT 0 ; rbx: pointer to next xt in array
	mov	rax, [rbx]
	add	rbx, 8
	jmp	[rax]
%endmacro

%macro RPUSH 1
	sub	rbp, 8
	mov	qword [rbp], %1
%endmacro

%macro RPOP 1
	mov	%1, qword [rbp]
	add	rbp, 8
%endmacro

%define PREVLINK 0

%macro DICTLINK 2-3 0			; to make a new dictionary definition:
	section	.rodata
%1_NAME:				; label for counted string
	%strlen l %2
	db	%[l],%2			; length, string
	align	8
%1_LINK:
	dq	$%[PREVLINK]		; pointer to previous link
	%define PREVLINK %1_LINK	; set next previous link to here
	dq	%3|%[l],%1_NAME		; compile bytes: flags|len, string address
	%undef l
%endmacro

%macro ASMWORD 2-3 0
	DICTLINK %1, %2, %3		; make a dictionary definition
$%1:
	dq	%1_ASM			; set xt address to assembly
	section	.text
%1_ASM:					; define assembly after here
%endmacro

%macro FORTHWORD 2-3+ 0
	DICTLINK %1, %2, %3		; make a dictionary definition
$%1:					; define Forth word here (with dq)
%endmacro

%macro FORTHCONST 3
ASMWORD %1, %2				; define a new assembly word
	push	qword %3		; push the given argument
	NEXT
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

rstack: resq 1024
R0:

	section .text

init_ret_stack:
	mov	rbp, R0
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

ASMWORD RSPFETCH, "SP@"
	push	rsp
	NEXT

ASMWORD RSPSTORE, "SP!"
	pop	rsp
	NEXT

ASMWORD RBPFETCH, "RP@"
	push	rbp
	NEXT

ASMWORD RBPSTORE, "RP!"
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

;;;;;;; User memory interaction ;;;;;;;

FORTHWORD COMMA, ","
dq	DOCOL, HERE, STORE, CELL, ALLOT, EXIT

FORTHWORD CCOMMA, "C,"
dq	DOCOL, HERE, CSTORE, LIT, 1, ALLOT, EXIT

FORTHWORD ALIGNED, "ALIGNED"
dq	DOCOL, DECR, CELL, DECR, INVERT, AND, CELL, ADD, EXIT

FORTHWORD ALIGN, "ALIGN"
dq	DOCOL, HERE, DUP, ALIGNED, SUB, NEGATE, ALLOT, EXIT

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

termbuf: times BUFSIZE db 0
keycount: dq 0 ; fetch with SOURCE
nextkey: dq 0 ; fetch with >IN
wordbuf: times 64 db 0

inputbuf: dq termbuf ; store with EVALUATE
sourceid: dq 0 ; fetch with SOURCE-ID

base: dq 10 ; fetch address with BASE

	section .text

ASMWORD SOURCE, "SOURCE" ; ( -- addr u )
	push	qword [inputbuf]
	push	qword [keycount]
	NEXT

ASMWORD EVALUATE, "EVALUATE" ; ( addr u -- )
	pop	qword [keycount]
	pop	qword [inputbuf]
	NEXT

ASMWORD REFILL, "REFILL" ; ( -- err )
	call	_REFILL
	test	rax, rax
	jz	.none
	push	qword ~0
	NEXT
.none:	push	qword 0
	NEXT
_REFILL: ; => rax=n
	mov	rax, SYS_READ
	mov	rdi, STDIN
	mov	rsi, termbuf
	mov	rdx, BUFSIZE
	syscall					; read(0,termbuf,BUFSIZE)
	mov	qword [inputbuf], rsi
	mov	qword [keycount], rax
	mov	qword [sourceid], 0
	mov	qword [nextkey], 0
	ret

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
	push	rdi				; preserve rdi for stosb in word
	call	_REFILL
	pop	rdi				; restore rdi
	test	rax, rax			; check for any bytes read
	jz	.exit				; if none, exit
	inc	qword [nextkey]			; else increment nextkey
	movzx	eax, byte [termbuf]		; get next key
	ret
.exit:
	mov	rax, SYS_EXIT
	xor	rdi, rdi
	syscall

ASMWORD WORD, "WORD" ; ( -- addr u )
	call	_WORD
	push	rsi
	NEXT
_WORD: ; => rsi=ctstr
	mov	rdi, wordbuf+1
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
	mov	rsi, wordbuf			; load string address into rsi
	mov	rdx, rdi
	sub	rdx, rsi
	dec	rdx				; calculate length into rdx
	mov	byte [rsi], dl			; put length in counted string
	ret

ASMWORD TONUMBER, ">NUMBER" ; ( n str u -- n str err )
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

ASMWORD FIND, "FIND" ; ( ctstr -- ctstr 0 | xt +/-1 )
	mov	rsi, qword [rsp]		; get counted string
	call	_FIND				; load entry into rax
	test	rcx, rcx			; test error
	jz	.notfound			; if no error:
	mov	qword [rsp], rax		; replace counted string with xt
	push	rcx				; push find code (+/-1)
	NEXT
.notfound:					; else:
	push	rcx				; push find code (0)
	NEXT
_FIND: ; rsi=ctstr => rsi=ctstr, rax=entry, rcx=-1|0|1, rdx=ctstrlen
	movzx	edx, byte [rsi]			; get string length
	inc	rsi				; get string
	mov	rax, last_link
.next:
	mov	rax, [rax] 			; go to next word
	test	rax, rax
	jz	.undef 				; if NULL, none left
	mov	rcx, qword [rax+8] 		; get entry string length|flags
	test	cl, F_HID 			; if word is hidden...
	jnz	.next 				; move on.
	and	cl, ~F_IMM 			; remove immediate flag
	cmp	cl, dl 				; compare lengths
	jne	.next 				; if not equal, move on
	mov	rdi, qword [rax+16]		; else load entry string
	inc	rdi				; skip length byte
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
	add	rax, 24				; load xt into rax
	ret					; return
.undef:						; if not found:
	xor	rax, rax			; set entry to 0
	xor	rcx, rcx			; set error to 0 (not found)
	ret

ASMWORD TICK, "'"
	call	_WORD
	call	_FIND
	push	rax
	NEXT

FORTHWORD COUNT, "COUNT"
dq	DOCOL, DUP, INCR, SWAP, CFETCH, EXIT

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
FORTHCONST R0_CONST, "R0", R0
FORTHCONST DOCOL_CONST, "DOCOL", DOCOL
FORTHCONST S0_CONST, "S0", [S0]
FORTHCONST SOURCE_ID, "SOURCE-ID", [sourceid]
FORTHCONST BASE, "BASE", base
FORTHCONST F_IMM_CONST, "F_IMM", F_IMM
FORTHCONST F_HID_CONST, "F_HID", F_HID
FORTHCONST CELL, "CELL", 8

FORTHCONST LATEST, "LATEST", last_link

	section .data
S0: dq 0 ; To be initialized later
here: dq 0 ; To be initialized later
last_link: dq PREVLINK

;;;;;;; Data segment setup ;;;;;;;

	section .text

DATA_SEG_SIZE equ 1024*64

init_data_seg: ; here=brk(0); brk(here+DATA_SEG_SIZE);
	xor	rdi, rdi
	mov	rax, SYS_BRK
	syscall
	mov	qword [here], rax
	lea	rdi, [rax+DATA_SEG_SIZE]
	mov	rax, SYS_BRK
	syscall	
	ret

;;;;;;; Base interpreter code ;;;;;;;

; effectively:
; BEGIN WORD FIND IF EXECUTE ELSE >NUMBER IF DROP DROP [CHAR] ? EMIT ELSE DROP THEN THEN AGAIN

FORTHWORD baseinterp, ""
dq	DOCOL, $WORD, FIND, ZBRANCH, 4*8, EXECUTE, BRANCH, -6*8, \
		LIT, 0, SWAP, COUNT, TONUMBER, ZBRANCH, 3*8, BRANCH, 4*8, \
		DROP, BRANCH, -18*8, \
		DROP, DROP, LIT, '?', EMIT, BRANCH, -25*8

;;;;;;; Executable entry point ;;;;;;;

	section .text

	global _start
_start:
	cld
	mov	qword [S0], rsp
	call	init_data_seg
	call	init_ret_stack
	mov	rbx, entry_point
	NEXT

	section .rodata

entry_point:
	dq	baseinterp
