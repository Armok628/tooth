a.out: *.o
	ld -melf_x86_64 *.o
*.o: *.s
	$(foreach s,$(wildcard *.s),nasm -felf64 -gdwarf $s;)
clean:
	rm -f a.out *.o
