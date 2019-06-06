: test_if_else IF [CHAR] 1 EMIT ELSE [CHAR] 0 EMIT THEN ;

: test_begin_while_repeat DUP 1- BEGIN DUP 0 > WHILE TUCK + SWAP 1- REPEAT DROP ;

: test_begin_until 0 SWAP BEGIN TUCK + SWAP 1- DUP 0 <= UNTIL DROP ;

\ 0 EXECUTE (comment test)
: test_begin_again 0 BEGIN DUP . CR 1+ AGAIN ;

: test_do_loop 0 DO I . CR LOOP ;

: test_do_+loop 0 DO I . CR 2 +LOOP ;

: test_?do_loop ?DO I . CR LOOP ;
