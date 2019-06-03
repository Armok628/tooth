HERE LATEST DUP @	HERE ! 8 ALLOT
	1		HERE C! 1 ALLOT
KEY	,		HERE C! 1 ALLOT
	0		HERE C! 1 ALLOT
	!
	DOCOL		HERE ! 8 ALLOT
'	HERE		HERE ! 8 ALLOT
'	!		HERE ! 8 ALLOT
'	LITERAL		HERE ! 8 ALLOT
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
'	LITERAL		,
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
	80		,
'	SWAP		,
'	DUP		,
'	C@		,
'	C,		,
'	1+		,
'	SWAP		,
'	1-		,
'	BRANCH		,
	-88		,

'	DROP		,
'	DROP		,
'	LITERAL		,
	0		,
'	C,		,

'	!		,
'	EXIT		,

HEADER .
	DOCOL		,
'	LITERAL		,
	-1		,
'	SWAP		,

'	BASE		,
'	@		,
'	/MOD		,
'	DUP		,
'	0BRANCH		,
	24		,
'	BRANCH		,
	-56		,

'	DROP		,

'	LITERAL		,
	KEY 0		,
'	+		,
'	EMIT		,

'	DUP		,
'	LITERAL		,
	-1		,
'	=		,
'	0BRANCH		,
	-72		,

'	EXIT		,

HEADER CONSTANT
	DOCOL		,
'	HEADER		,
'	LITERAL		,
	DOCOL		,
'	,		,
'	LITERAL		,
	' LITERAL	,
'	,		,
'	,		,
'	LITERAL		,
	' EXIT		,
'	,		,
'	EXIT		,

HEADER CREATE
	DOCOL		,
'	HEADER		,
'	LITERAL		,
	DOCOL		,
'	,		,
'	LITERAL		,
	' LITERAL	,
'	,		,
'	HERE		,
'	LITERAL		,
	16		,
'	+		,
'	,		,
'	LITERAL		,
	' EXIT		,
'	,		,
'	EXIT		,

HEADER VARIABLE
	DOCOL		,
'	CREATE		,
'	LITERAL		,
	0		,
'	,		,
'	EXIT		,

HEADER IMMEDIATE
	DOCOL		,
'	LATEST		,
'	CELL		,
'	+		,
'	DUP		,
'	C@		,
'	F_IMM		,
'	OR		,
'	SWAP		,
'	C!		,
'	EXIT		,

VARIABLE STATE

HEADER [
	DOCOL		,
'	LITERAL		,
	0		,
'	STATE		,
'	!		,
'	EXIT		,
IMMEDIATE

HEADER ]
	DOCOL		,
'	LITERAL		,
	1		,
'	STATE		,
'	!		,
'	EXIT		,
