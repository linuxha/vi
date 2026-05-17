# VI Cheat sheet

## Input commands (end with Esc)
| cmd | description |
| a | Append after cursor |
| i | Insert before cursor |
| o | Open line below |
| O | Open line above |
| :r | file Insert file after current line |

Any of these commands leaves vi in input mode until you
press Esc. Pressing the RETURN key will not take you out
of input mode.

## Change commands (Input mode)

| R | Replace (Esc) - typeover |
| s | Substitute (Esc) - 1 char with string |
| S | Substitute (Esc) - Rest of line with text |

## Changes during insert mode
| <ctrl>h | Back one character |
| <ctrl>w | Back one word |
| <ctrl>u | Back to beginning of insert |

## File management commands
:w name Write edit buffer to file name
:wq Write to file and quit
:q! Quit without saving changes
ZZ Same as :wq
:sh Execute shell commands (<ctrl>d)

## Window motions
<ctrl>d Scroll down (half a screen)
<ctrl>u Scroll up (half a screen)
<ctrl>f Page forward
<ctrl>b Page backward
/string Search forward
?string Search backward
<ctrl>l Redraw screen
<ctrl>g Display current line number and

## file information
n Repeat search
N Repeat search reverse
G Go to last line
nG Go to line n
:n Go to line n
z<CR> Reposition window: cursor at top
z. Reposition window: cursor in middle
z- Reposition window: cursor at bottom

## Cursor motions
H Upper left corner (home)
M Middle line
L Lower left corner
h Back a character
j Down a line
k Up a line
^ Beginning of line
$ End of line
l Forward a character
w One word forward
b Back one word
fc Find c
; Repeat find (find next c)

## Deletion commands
dd or ndd Delete n lines to general buffer
dw Delete word to general buffer
dnw Delete n words
d) Delete to end of sentence
db Delete previous word
D Delete to end of line
x Delete character

## Recovering deletions
p Put general buffer after cursor
P Put general buffer before cursor

## Undo commands
u Undo last change
U Undo all changes on line

## Rearrangement commands
yy or Y Yank (copy) line to general buffer
“z6yy Yank 6 lines to buffer z
yw Yank word to general buffer
“a9dd Delete 9 lines to buffer a
“A9dd Delete 9 lines; Append to buffer a
“ap Put text from buffer a after cursor
p Put general buffer after cursor
P Put general buffer before cursor
J Join lines

## Parameters
:set list Show invisible characters
:set nolist Don’t show invisible characters
:set number Show line numbers
:set nonumber Don’t show line numbers
:set autoindent Indent after carriage return
:set noautoindent Turn off autoindent
:set showmatch Show matching sets of parentheses as they are typed
:set noshowmatch Turn off showmatch
:set showmode Display mode on last line of screen
:set noshowmode Turn off showmode
:set all Show values of all possible parameters

## Move text from file old to file new
vi old
“a10yy yank 10 lines to buffer a
:w write work buffer
:e new edit new file
“ap put text from a after cursor
:30,60w new Write lines 30 to 60 in file new

## Regular expressions (search strings)
^ Matches beginning of line
$ Matches end of line
. Matches any single character
* Matches any previous character
.* Matches any character

## Search and replace commands
Syntax:
:[address]s/old_text/new_text/

## Address components:
. Current line
n Line number n
.+m Current line plus m lines
$ Last line
/string/ A line that contains "string"
% Entire file
[addr1],[addr2] Specifies a range
