: TIME 201 0 SYSCALL1 ;

( translated from imneme/pcg-c-basic )

CREATE RSTATE 2 CELLS ALLOT

: RAND ( pcg32_random )
	RSTATE 2@						( oldstate inc )
	OVER 6364136223846793005 * SWAP 1 OR + RSTATE !		( oldstate )
	DUP DUP 18 RSHIFT XOR 27 RSHIFT				( oldstate xorshifted )
	SWAP 59 RSHIFT						( xorshifted rot )
	2DUP RSHIFT -ROT					( xorshifted>>rot xorshifted rot )
	NEGATE 31 AND LSHIFT OR
;

: SEED ( pcg32_srandom )
	0 RSTATE !
	1 LSHIFT 1 OR RSTATE CELL+ !
	RAND DROP
	RSTATE +!
	RAND DROP
;

HIDE RSTATE
