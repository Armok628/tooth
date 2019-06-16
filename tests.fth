: test_if_else IF [CHAR] 1 EMIT ELSE [CHAR] 0 EMIT THEN ;

: test_begin_while_repeat DUP 1- BEGIN DUP 0 > WHILE TUCK + SWAP 1- REPEAT DROP ;

: test_begin_until 0 SWAP BEGIN TUCK + SWAP 1- DUP 0 <= UNTIL DROP ;

\ 0 EXECUTE
( comment test )

: test_begin_again 0 BEGIN DUP . CR 1+ AGAIN ;

: test_do_loop 0 DO I . CR LOOP ;

: test_do_+loop 1 DO I DUP . CR +LOOP ;

: test_?do_loop ?DO I . CR LOOP ;

: hello ." Hello, world!" CR ;

: test_>link >LINK 2 CELLS + @ COUNT LENMASK AND TYPE ;
( ^ prints name associated with xt )

: prime?
	DUP 1 < IF
		DROP FALSE EXIT
	ELSE DUP 4 < IF
		DROP TRUE EXIT
	ELSE DUP 1 AND 0= IF
		DROP FALSE EXIT
	THEN THEN THEN
	DUP 3 / 3 ?DO
		DUP I MOD 0= IF
			UNLOOP
			DROP FALSE EXIT
		THEN
	2 +LOOP
	DROP TRUE
;
