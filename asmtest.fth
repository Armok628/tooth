\ none of this is set in stone; just proof of concept

HEX

\ Intel-style operand order where applicable
\ i.e. %1 %2 ADD => %1+=%2

: REX.W 48 C, ;
: PUSH 50 + C, ;
: POP 58 + C, ;
: LOD REX.W 8B C, 8 * + C, ;
: STO REX.W 89 C, SWAP 8 * + C, ;
: DW, 4 0 DO DUP C, 8 RSHIFT LOOP DROP ;
: ADD REX.W 01 C, 8 * C0 + + C, ;
: ADD$ REX.W 81 C, SWAP C0 + C, DW, ;
: SUB REX.W 29 C, 8 * C0 + + C, ;
: SUB$ REX.W 81 C, SWAP E8 + C, DW, ;
: PUSH$ 68 C, DW, ;
: JMP FF C, 20 + C, ;

0 CONSTANT %1 \ RAX
1 CONSTANT %2 \ RCX
2 CONSTANT %3 \ RDX
6 CONSTANT %4 \ RSI
7 CONSTANT %5 \ RDI
3 CONSTANT %X \ "next xt"	RBX
4 CONSTANT %S \ "stack"		RSP
5 CONSTANT %R \ "ret'n stack"	RBP

: END-CODE
REX.W	%X %1	LOD
REX.W	%X CELL	ADD$
	%1	JMP
;

: CODE HEADER HERE CELL+ , ;

CODE TEST ( implements CELL+ )
	%1	POP
	%1 CELL	ADD$
	%1	PUSH
END-CODE

DECIMAL
