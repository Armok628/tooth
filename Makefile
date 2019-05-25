a.out: *.o
	ld -m elf_x86_64 *.o
*.o: *.s
	$(foreach s,$(wildcard *.s),nasm -f elf64 -gdwarf $s;)
clean:
	rm a.out *.o
