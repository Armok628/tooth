HERE LATEST DUP @	HERE ! 8 ALLOT
	1		HERE C! 1 ALLOT
KEY	,		HERE C! 1 ALLOT
	0		HERE C! 1 ALLOT
	!
	DOCOL		HERE ! 8 ALLOT
'	HERE		HERE ! 8 ALLOT
'	!		HERE ! 8 ALLOT
'	LIT		HERE ! 8 ALLOT
	8		HERE ! 8 ALLOT
'	ALLOT		HERE ! 8 ALLOT
'	EXIT		HERE ! 8 ALLOT

HERE LATEST DUP @	,
	2		HERE C! 1 ALLOT
KEY	C		HERE C! 1 ALLOT
KEY	,		HERE C! 1 ALLOT
	0		HERE C! 1 ALLOT
	!
	DOCOL		,
'	HERE		,
'	C!		,
'	LIT		,
	1		,
'	ALLOT		,
'	EXIT		,

HERE LATEST DUP @	,
	6		C,
KEY	H		C,
KEY	E		C,
KEY	A		C,
KEY	D		C,
KEY	E		C,
KEY	R		C,
	0		C,
	!
	DOCOL		,
'	HERE		,
'	LATEST		,
'	DUP		,
'	@		,
'	,		,

'	WORD		,

'	DUP		,
'	C,		,

'	DUP		,
'	0BRANCH		,
	10 CELL *	,
'	SWAP		,
'	DUP		,
'	C@		,
'	C,		,
'	1+		,
'	SWAP		,
'	1-		,
'	BRANCH		,
	-11 CELL *	,

'	DROP		,
'	DROP		,
'	LIT		,
	0		,
'	C,		,

'	!		,
'	EXIT		,

HEADER TYPE
	DOCOL		,
'	DUP		,
'	0BRANCH		,
	10 CELL *	,
'	SWAP		,
'	DUP		,
'	C@		,
'	EMIT		,
'	1+		,
'	SWAP		,
'	1-		,
'	BRANCH		,
	-11 CELL *	,
'	DROP		,
'	DROP		,
'	EXIT		,

HEADER IMMEDIATE
	DOCOL		,
'	LATEST		,
'	@		,
'	CELL		,
'	+		,
'	DUP		,
'	C@		,
'	F_IMM		,
'	OR		,
'	SWAP		,
'	C!		,
'	EXIT		,

HEADER STATE
	DOCOL		,
'	LIT		,
HERE CELL DUP + +	,
'	EXIT		,
	0		,

HEADER [
	DOCOL		,
'	LIT		,
	0		,
'	STATE		,
'	!		,
'	EXIT		,
IMMEDIATE

HEADER ]
	DOCOL		,
'	LIT		,
	1		,
'	STATE		,
'	!		,
'	EXIT		,

HEADER INTERPRET
	DOCOL		,

'	WORD		,
'	FIND		,
'	STATE		,
'	@		,
'	0BRANCH		,
	34 CELL *	,

'	DUP		,
'	0BRANCH		,
	10 CELL *	,

'	LIT		,
	-1		,
'	=		,
'	0BRANCH		,
	3 CELL *	,
'	,		,
'	EXIT		,

'	EXECUTE		,
'	EXIT		,

'	DROP		,
'	LIT		,
	0		,
'	-ROT		,
'	>NUMBER		,
'	DUP		,
'	0BRANCH		,
	7 CELL *	,
'	TYPE		,
'	LIT		,
	KEY ?		,
'	EMIT		,
'	DROP		,
'	EXIT		,
'	DROP		,
'	DROP		,
'	LIT		,
	' LIT	,
'	,		,
'	,		,
'	EXIT		,

'	0BRANCH		,
	3 CELL *	,
'	EXECUTE		,
'	EXIT		,

'	LIT		,
	0		,
'	-ROT		,
'	>NUMBER		,
'	DUP		,
'	0BRANCH		,
	7 CELL *	,
'	TYPE		,
'	LIT		,
	KEY ?		,
'	EMIT		,
'	DROP		,
'	EXIT		,
'	DROP		,
'	DROP		,
'	EXIT		,

HEADER QUIT
	DOCOL		,
'	R0		,
'	RP!		,
'	INTERPRET	,
'	BRANCH		,
	-2 CELL *	,

QUIT

HEADER : DOCOL , ] HEADER DOCOL , ] EXIT [

: ; LIT EXIT , [ ' [ , ] EXIT [ IMMEDIATE

: POSTPONE ' , ; IMMEDIATE

: COMPILE, , ; IMMEDIATE

: LITERAL LIT LIT , , ; IMMEDIATE

: ['] ' POSTPONE LITERAL ; IMMEDIATE

: [CHAR] KEY POSTPONE LITERAL ; IMMEDIATE

: CONSTANT
	HEADER DOCOL ,
	POSTPONE LITERAL
	['] EXIT ,
;

: CREATE
	HEADER DOCOL ,
	HERE CELL 3 * + POSTPONE LITERAL
	['] EXIT ,
;

: VARIABLE CREATE CELL ALLOT ;

: CR 10 EMIT ;

: CLEAR S0 SP! ;
: ABORT TIB 0 EVALUATE CLEAR QUIT ;

: IF ['] 0BRANCH , HERE 0 , ; IMMEDIATE
: THEN HERE OVER - SWAP ! ; IMMEDIATE
: ELSE ['] BRANCH , HERE 0 , SWAP POSTPONE THEN ; IMMEDIATE

: BEGIN HERE ; IMMEDIATE
: AGAIN ['] BRANCH , HERE - , ; IMMEDIATE
: UNTIL ['] 0BRANCH , HERE - , ; IMMEDIATE
: WHILE POSTPONE IF ; IMMEDIATE
: REPEAT ['] BRANCH , SWAP HERE - , POSTPONE THEN ; IMMEDIATE

: \ BEGIN KEY 10 = UNTIL ; IMMEDIATE

: DECIMAL 10 BASE ! ;
: HEX 16 BASE ! ;
: BINARY 2 BASE ! ;

: U.
	-1 SWAP
	BEGIN
		BASE @ /MOD
	DUP 0 = UNTIL
	DROP
	BEGIN
		DUP 10 < IF
			[CHAR] 0 +
		ELSE
			[ KEY A 10 - LITERAL ] +
		THEN
		EMIT
	DUP -1 = UNTIL
	DROP
;

: . DUP 0 < IF NEGATE [CHAR] - EMIT THEN U. ;

\ 10 0 DO ... LOOP -> 10 0 SWAP >R >R BEGIN ... R> 1+ R@ OVER >R >= UNTIL R> R> DROP DROP ;

: DO
	['] SWAP ,
	['] >R DUP , ,
	POSTPONE BEGIN
; IMMEDIATE

: UNLOOP
	['] R> DUP , ,
	['] DROP DUP , ,
; IMMEDIATE

: +LOOP
	['] R> ,
	['] + ,
	['] R@ ,
	['] OVER ,
	['] >R ,
	['] >= ,
	POSTPONE UNTIL
	POSTPONE UNLOOP
; IMMEDIATE

: LOOP
	1 POSTPONE LITERAL
	POSTPONE +LOOP
; IMMEDIATE

: I R@ ;
: I' RP@ CELL + ! ;
: J RP@ CELL DUP + + ! ;
: J' RP@ CELL 3 * + ! ;
