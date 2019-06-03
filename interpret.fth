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

HEADER INTERPRET
	DOCOL		,

'	WORD		,
'	FIND		,
'	STATE		,
'	@		,
'	0BRANCH		,
	272		,

'	DUP		,
'	0BRANCH		,
	80		,

'	LITERAL		,
	-1		,
'	=		,
'	0BRANCH		,
	24		,
'	,		,
'	EXIT		,

'	EXECUTE		,
'	EXIT		,

'	DROP		,
'	LITERAL		,
	0		,
'	-ROT		,
'	>NUMBER		,
'	DUP		,
'	0BRANCH		,
	56		,
'	TYPE		,
'	LITERAL		,
	KEY ?		,
'	EMIT		,
'	DROP		,
'	EXIT		,
'	DROP		,
'	DROP		,
'	LITERAL		,
	' LITERAL	,
'	,		,
'	,		,
'	EXIT		,

'	0BRANCH		,
	24		,
'	EXECUTE		,
'	EXIT		,

'	LITERAL		,
	0		,
'	-ROT		,
'	>NUMBER		,
'	DUP		,
'	0BRANCH		,
	56		,
'	TYPE		,
'	LITERAL		,
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
	-16		,

QUIT

HEADER : DOCOL , ] HEADER LITERAL [ DOCOL , ] , ] EXIT [

: ; LITERAL EXIT , [ ' [ , ] EXIT [ IMMEDIATE
