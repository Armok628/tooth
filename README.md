# twoth
A minimal-core Forth implementation for x86-64 Linux

### The Plan

Take the set of basic words from the Forth standard glossary.
Minimize the set to primitive words from which all others can be derived.
Implement those words (and necessary variables/constants) in assembly.
Then, implement a barebones interpreter in assembly.
e.g.:	WORD, FIND, EXECUTE, BRANCH (to beginning)

At this point, the "core" of the language would be complete.
It would then be the most minimal Forth possible.

Then, to implement the rest of the glossary in the language itself,
begin with the compiler (which would need to be itself compiled manually).
Then use the new compiler to build up the rest of the language's words.

Some more words may need to be defined in assembly during this process,
if not out of necessity, then out of convenience or efficiency.
e.g.:	It is much faster (and easier?) to use a function with `rep movsb`
	than to write a string copy word in pure Forth.
