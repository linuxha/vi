# vi.asm Description

## Overview
This project implements a vi-like modal screen editor in Motorola 6800 assembly for FLEX.
It uses VT100 escape sequences for screen control and FLEX system calls for keyboard, terminal, and file I/O.

Main source: vi.asm

## Runtime Model
The editor is single-threaded and runs in an infinite input loop:

1. START calls INITED once.
2. MAINLOOP repeatedly calls GETKEY then PROCKEY.
3. PROCKEY dispatches based on current mode and key value.

The editor exits only through EXITVI (jump to WARMS).

## Core Modes
The editor is modal using EDMODE:

- MODECMD (0): command/navigation/edit actions.
- MODEINS (1): text insertion behavior.

Mode switches:

- SETCMD: enters command mode, syncs BUFPOS from CSRBPOS.
- CMDINS and CMDAPP: enter insert mode, sync BUFPOS/CSRBPOS.

## Memory and Data Structures
Key state variables are global RAM symbols:

- Screen state:
  - SCRROWS, SCRCOLS: active screen size (defaults 24x80).
  - CSRROW, CSRCOL: display cursor position (1-based).
- Buffer state:
  - TXTBUF: main text buffer (BUFSZ = 4096 bytes).
  - BUFEND: one-past-last used byte in TXTBUF.
  - BUFPOS: edit position used by insert/delete routines.
  - CSRBPOS: logical cursor position in buffer for navigation.
  - TOPLINE: buffer pointer for first displayed line.
- File state:
  - FILENAME: current file name.
  - FILEFCB: FLEX FCB (320 bytes).
  - FOPEN: file-open flag.
  - DIRTY: modified flag.
- Line/navigation helpers:
  - LNSTART, CURRLINE, LNTOTAL, LASTCOL.
- Edit helpers:
  - YANKBUF, YANKSZ, TMPX, TMPY, YP, DLEN.

Design rule used throughout: CSRBPOS tracks logical cursor; BUFPOS tracks edit location. Routines explicitly resync when changing mode or after display refresh.

## Terminal and Screen Handling
Output uses PUTCHAR -> FLEX PUTCHR; input uses GETKEY -> FLEX GETCHR.

VT100 control helpers:

- CLRSCR: ESC[2J + ESC[H.
- POSCSR: emits ESC[row;colH using PUTDEC.
- GOTOHOME, GOTOBL, GOTOTR, GOTOBR: convenience cursor positioning.

Rendering path:

- DISPBUF redraws editable area from TOPLINE to the line above status line.
- DISPTL prints one logical line until CR or line width.
- STATSLN draws inverse-video status line on bottom row.
- INSRUPD/INSRFDN perform partial refresh in insert workflows.
- UPDCSR recomputes CSRROW/CSRCOL by scanning from TOPLINE to CSRBPOS.

## Input and Command Dispatch
PROCKEY first handles global keys:

- Q -> EXITVI
- ESC -> SETCMD

Then mode-specific behavior:

- Insert mode:
  - CR -> INSNLK (newline insert + refresh)
  - Backspace -> INSBKSP (delete previous char)
  - Printable chars -> INSCH + INSRUPD
- Command mode:
  - PROCCMD normalizes a-z to uppercase then dispatches by jump table.

Implemented command groups include:

- Movement: h/j/k/l, 0, $, G
- Words: w, b
- Search: /, ?
- Mode and edits: i, a, x, d, y, p
- Screen/line: R, :
- File open/open-line multiplex on O (CMDORF)

## Editing Engine
Character edits:

- INSCH inserts one byte at BUFPOS:
  - checks capacity,
  - shifts right via SHFTRGT,
  - writes A,
  - updates BUFPOS, CSRBPOS, BUFEND,
  - sets DIRTY.
- DELCH deletes at BUFPOS:
  - shifts left via SHFTLFT,
  - decrements BUFEND,
  - syncs CSRBPOS,
  - sets DIRTY.
- INSNL inserts CR (carriage return) and increments LNTOTAL.

Line/region helpers:

- FNDCLS/FNDCLE locate current line start/end.
- DELRNG removes a range.
- YANKRNG copies a range to YANKBUF.
- INSYANK inserts yanked bytes.
- MKROOM creates insertion space for multi-byte paste.

## Navigation and Search
Navigation updates CSRBPOS first, then calls UPDCSR.

- Vertical: DNMOVC, MOVCUP, MOVCOL.
- Horizontal: MOVCLEFT, MOVCRT.
- Line anchors: MOVLNST, MOVLNEND, GOFSTLN, GOLSTLN.

Search flow:

1. GETSRCH captures pattern into SRCHPAT.
2. SRCHF or SRCHB scans buffer using MATCHPAT.
3. On match, CSRBPOS updates and display refreshes.
4. On miss, SHWNF message shown.

## File I/O and FLEX Integration
System calls used:

- Console: GETCHR, PUTCHR, OUTDEC.
- Session exit: WARMS.
- File manager: FMS entry with function codes.

Open/read/write path:

- OPNFILE:
  - resolves filename,
  - STPFCB populates FILEFCB,
  - sets FMSREAD,
  - calls FMS.
- RDBUF:
  - repeatedly reads bytes (function 0),
  - appends with ADDCBUF,
  - tracks line count on CR.
- SAVFILE:
  - closes current file,
  - opens write path (OPNWRIT or SAVNEW),
  - writes buffer with WRTBUF,
  - clears DIRTY,
  - reopens for read.

FCB construction:

- STPFCB clears full 320-byte FILEFCB.
- Parses optional drive prefix (for forms like 2.filename).
- Copies name/ext fields into FCB slots.
- Applies default TXT extension with SETEXT.

## Status Line and Messages
The bottom row is reserved for status/message output:

- STATSLN shows mode and filename in inverse video.
- STAMSG shows transient messages (save result, not found, etc.).
- SDLY provides a short blocking delay before redraw.

UPDCSR clamps cursor row to stay above status line.

## Newline and Text Format
Internal logical line delimiter is CR (0x0D).
Display and parsing routines use CR for line boundaries.
This matches FLEX/terminal behavior expected by this codebase.

## Known Limits and TODOs
Current limitations visible in source:

- Screen size detection currently uses defaults only (GETSCSZ TODO).
- ADJTOPL is stubbed (no full viewport auto-scroll policy).
- Undo is message-only (CMDUNDO TODO).
- Some command families are partial (additional motions/operators TODO).
- Filename prompt path uses defaults in some branches.

## High-Level Control Flow Summary
1. Initialize environment, mode, pointers, and optional file load.
2. Wait for key input.
3. Dispatch to mode-appropriate command.
4. Mutate TXTBUF and pointers.
5. Refresh affected display areas and status line.
6. Repeat until explicit quit path.

This architecture keeps implementation simple for 6800 constraints: one shared buffer, explicit pointer arithmetic, and clear separation between navigation position (CSRBPOS) and edit position (BUFPOS).
