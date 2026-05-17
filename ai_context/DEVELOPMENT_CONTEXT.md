# Development Context

## Session Snapshot
- Date: 2026-05-16
- Workspace root: /home/njc/dev/git/vi00
- OS: Linux
- Primary source file: vi.asm
- Current objective trend: implement/fix/document a vi-like editor for FLEX on Motorola 6800

## Project Goal
Build and maintain a vi-like screen editor in Motorola 6800 assembly language for FLEX, with VT100-style terminal control, modal editing, file read/write support, and command-driven navigation/edit actions.

## Active Constraints and Conventions
- Keep existing assembly comment layout style in source files.
- Do not convert code to ASL syntax unless explicitly requested.
- Prefer minimal, targeted edits.
- Preserve existing behavior unless a bugfix/change is requested.
- Newline semantics in editor logic are CR-based for FLEX compatibility.

## Important Instruction Context
- Assistant identity for model questions: GPT-5.3-Codex.
- Response style mode in this repo/session favors terse output.
- Use repo instructions in .github/instructions, especially FLEX-specific guidance.

## Current Codebase Understanding
- Core file: vi.asm
- Runtime structure:
  - START -> INITED -> MAINLOOP
  - MAINLOOP cycles GETKEY -> PROCKEY
  - Exit path via EXITVI -> WARMS
- Modes:
  - Command mode (MODECMD)
  - Insert mode (MODEINS)
- Pointer model:
  - CSRBPOS = logical cursor in buffer
  - BUFPOS = edit position for insert/delete routines
  - Explicit synchronization between them during mode transitions and refresh paths

## Major Implemented Areas (Observed)
- Screen control and cursor positioning with VT100 escape sequences.
- Key processing and mode-based dispatch.
- Navigation commands (h/j/k/l and related line movements).
- Insert/delete/newline buffer mutation routines.
- Status line/message rendering.
- File open/read/write flows through FLEX FMS and FCB setup.

## Recent Work Completed In This Session
1. Added routine-level documentation blocks in vi.asm for key labels (Purpose/Input/Output format) without introducing assembly errors.
2. Created docs/description.md with an architectural walkthrough of editor behavior, data model, control flow, file I/O, and known TODOs.
3. Verified diagnostics reported no new errors for modified/new documentation files.

## Key Files Updated This Session
- vi.asm (comment/documentation additions on major routines)
- docs/description.md (new high-level code explanation)

## Known Gaps / TODO Signals In Source
- GETSCSZ currently uses defaults; dynamic size detection is TODO.
- ADJTOPL is a stub.
- Undo path is placeholder-level.
- Some command families and prompts remain partial/simplified.

## Testing and Validation State
- Static diagnostics were checked for edited files and showed no errors.
- Runtime behavior validation depends on user-side execution/tests in FLEX environment.

## Next Likely Steps
- Expand routine docs to any remaining unlabeled helper routines if requested.
- Add/upgrade tests for movement, insert/newline behavior, and file save/open edge cases.
- Implement TODO-marked routines incrementally with minimal regressions.
