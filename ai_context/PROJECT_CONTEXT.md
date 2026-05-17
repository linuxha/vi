# Project Context

## Identity
- Project: vi-like screen editor for FLEX
- Language: Motorola 6800 Assembly
- Primary source: vi.asm
- Workspace root: /home/njc/dev/git/vi00
- Date snapshot: 2026-05-17

## Project Goal
Implement a practical vi-style modal editor for FLEX with:
- VT100 screen control
- command and insert modes
- in-memory text buffer editing
- file open/read/write through FLEX FMS
- keyboard-driven navigation/edit commands

## Current Architecture
High-level control loop:
1. START initializes editor state via INITED.
2. MAINLOOP repeatedly does GETKEY then PROCKEY.
3. PROCKEY dispatches by key and mode.
4. EXITVI clears display and returns to FLEX (WARMS).

Core mode model:
- MODECMD: movement and commands.
- MODEINS: text insertion, backspace, newline handling.

Key pointer/state model:
- CSRBPOS: logical cursor location in text buffer.
- BUFPOS: active edit pointer for insert/delete routines.
- BUFEND: end of used bytes in TXTBUF.
- TOPLINE: first displayed buffer line.

Design pattern: navigation updates CSRBPOS; mutators use BUFPOS; explicit synchronization occurs during mode transitions and refresh paths.

## Feature Coverage (Implemented)
- Screen control
  - clear/home and cursor positioning with VT100 escape sequences.
  - status line rendering in inverse video.
- Editing core
  - insert char, delete char, insert newline (CR-based), dirty tracking.
  - range delete/yank/paste helper paths.
- Navigation
  - h/j/k/l style movement and line boundary movement.
  - first/last line movement and partial scrolling support.
- Search
  - forward/backward pattern search with user input and match routine.
- File operations
  - filename parsing and FCB preparation.
  - read buffer from file, write buffer to file, close/reopen flows.

## Code and Docs State
- vi.asm includes routine-level Purpose/Input/Output comments for key entry points and major operations.
- docs/description.md contains a full architecture/flow explanation.
- ai_context/DEVELOPMENT_CONTEXT.md captures prior session-level development notes.

## Constraints and Conventions
- Preserve existing assembly comment layout in source edits.
- Do not convert to ASL syntax unless explicitly requested.
- Keep fixes minimal and behavior-preserving unless change is requested.
- Treat CR (0x0D) as the canonical logical newline in buffer workflows.

## Known Limitations / TODO Signals
- GETSCSZ currently defaults screen size; dynamic detection not implemented.
- ADJTOPL is currently a stub.
- Undo path is placeholder-level.
- Some command families remain partial.
- Some filename prompting/interactive paths use simplified defaults.

## Validation Status
- Static diagnostics for recently edited documentation/source files reported no new errors.
- Runtime behavior verification depends on execution in a FLEX-capable environment.

## Near-Term Engineering Priorities
1. Complete viewport/topline management (ADJTOPL and related scrolling consistency).
2. Improve command completeness and edge-case behavior around motions/operators.
3. Replace simplified filename/prompt paths with robust interactive handling.
4. Add repeatable test scenarios for cursor sync, newline insertion, and file save/load correctness.
