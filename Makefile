a.out: *.o
	ld -melf_x86_64 *.o
%.o: %.asm
	nasm -felf64 -gdwarf $<
clean:
	rm -f a.out *.o
