# vi editor for Flex 

This is an assembly language version of the vi editor for Flex using VT100 escape sequences for screen control.

Vi (pronounced "vee-aye") is a screen-oriented, modal text editor designed for Unix and Unix-like operating systems. Originally developed by Bill Joy in 1976, its name comes from the shortest abbreviation of the command visual, which shifts a line-based editor into a full-screen mode.

Key Characteristics and Features

• Modal Editing: Vi is famous for its separation of modes, primarily Command Mode (used for navigation and manipulation) and Insert Mode (used for typing text). 
• Keyboard Driven: It is designed for high efficiency, allowing users to perform complex text editing without moving their hands from the home row of the keyboard. 
• Ubiquitous: As part of the Single UNIX Specification, vi is pre-installed on virtually all Unix
• Lightweight: It is highly efficient for quick edits, often loading faster than more modern editors or IDEs.

# Implementation phases

In 6800 Assembly language as per the Flex manual, both in the docs directory.

Available RAM starts at 0x0000 but code starts at 0x0100 through $7F00.

1. screen control
  - read a flex enviroment for the screen length and width
  - create screen controls to reach each corner of the screen and the middle
2. Add the capability to read a file
  - create scrolling of the screens
3. Add the capabilty to write a file
4. add vi commands from the cheat sheet in the docs directory
