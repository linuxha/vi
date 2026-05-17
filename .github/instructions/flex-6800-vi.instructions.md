---
description: "Use when editing FLEX Motorola 6800 vi editor sources, command/input handling, file I/O, or screen control. Enforces repo-specific assembly conventions and terminal behavior."
name: "FLEX 6800 vi Conventions"
applyTo:
  - "**/*.asm"
  - "**/*.ASM"
---
# FLEX 6800 vi Conventions

- Preserve existing comment layout and spacing style in assembly sources.
- Do not convert source syntax to ASL or target ASL compatibility unless explicitly requested.
- Treat carriage return (CR, $0D) as the only newline terminator for FLEX input/command flows unless explicitly requested otherwise.
- Keep fixes minimal and behavior-focused; avoid broad refactors while implementing vi command behavior.
- Do not change established constants or magic values unless explicitly requested.

# Assembler EXPRESSIONS
Expressions consist of combinations of numbers and symbols separated by
one of the four arithmetic operators +, -, , /. The arithmetic is done
with 16 bit integer operands and truncated as necessary. 8 bit results
are taken from the least significant 8 bits. Unary (+) and (-) are
allowed. Expressions must not contain spaces.
for a 16 value, to get the upper 8 bits, divide by 256
for a 16 value, to get the lower 8 bits, just post the value

# Assembler OPEATOR FIELDS
The operator is 3 alphabetic characters (A-Z,a-z) which must be followed by a space.
Mnemonics such as LDA A and AND B may be written as LDAA and ANDB, respectively. In this case, the fourth character must be followed by a space.
Only use valid Motorola 6800 operands.

# Comments
Comments are optional
Comments always start with an asterisk and space, followed by the comment

# Numbers
Decimals have no prefix
Binary uses a % as a prefix
Octal uses a @ as a prefix
Hexadecimal uses a $ as a prefix
ASCII uses a ' (single quote) as a prefix

# SYMBOLS
Symbols are groupings of letters and numerals the first 6 of which are
significant and the first of which must be a letter. The single
character * is a special symbol whose value is the current value of the
program counter (PC). Upper case letters are not equivelent to lower
case, so the label 'START' is different from 'start'.

# Additional assembler directives
FCC	form constant character
FCB	form constant byte
FDB	form double byte
ORG	define new origin (PC)
EQU	assign value to symbol
END	signal end of source program
RMB	reserve memory bytes
LIB	process library file
