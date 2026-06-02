## TSTSCR.ASM High-Level Flow Analysis

### Program Goal
The `TSTSCR.ASM` program is a comprehensive, low-level test suite designed to validate critical Input/Output (I/O) and screen manipulation capabilities of a terminal emulator (specifically targeting VT100/Flex system calls). It demonstrates fundamental text editor concepts like cursor movement, status lines, character input, and screen clearing.

### Structure & Key Components
The program is sectioned into distinct, testable modules:
*   **Initialization:** Sets up the environment (stack, screen size) before running tests.
*   **Main Sequence:** The central `TESTSTART` routine that calls various specialized tests sequentially.
*   **Utility Functions:** Small routines for common tasks (e.g., `PUTCHAR`, `DELAY`).
*   **Test Modules:** Dedicated routines for specific shell/display features (e.g., `TESTCORNERS`, `TESTMIDDLE`).

### Execution Flow (The `TESTSTART` Routine)

The program executes a defined sequence of operations, demonstrating:

1.  **Initial Clear:**
    *   Calls `TESTCLEAR` to wipe the entire screen.
    *   Sends VT100 sequences for complete screen clear (`ESC[2J`) and cursor home (`ESC[H`).
2.  **Status Line Setup:**
    *   Moves the cursor to row 5, column 5.
    *   Prints the status line marker ("---Status Line---").
3.  **User Interaction Block:**
    *   Prints an instruction message ("Press any to continue: ").
    *   Suspends execution at `WAITKEY`, awaiting *any* single character input.
4.  **Positional Tests:**
    *   Performs boundary checks by moving the cursor:
        *   **Top-Right:** Moves cursor to (1, `SCRCOLS`) and prints a marker.
        *   **Bottom-Left:** Moves cursor to (`SCRROWS`, 1) and prints a marker.
        *   **Bottom-Right:** Moves cursor to (`SCRROWS`, `SCRCOLS`) and prints a marker.
5.  **Utility Demonstrations:**
    *   **Status Bar (Dynamic):** Demonstrates setting a status bar (`ONSTAT`) and printing a variable message across it, confirming the current status position (`CSRROW`/`CSRCOL`).
    *   **Inverse Video:** Demonstrates capability to toggle inverse video using `ESC[?1`.
6.  **Conclusion:**
    *   Resets the status bar visibility (`OFFSTAT`).
    *   Exits the test sequence by cleaning the line (`CLR2EOL`) and passing control back to the Flex environment (`WARMST`).

### Technical Highlights
*   **VT100 Sequences:** Heavy reliance on sequences like `ESC[<row>;<col>H` (cursor position) and `ESC[2J` (full clear).
*   **Registers:** Uses core registers (`CSRROW`, `CSRCOL`, `SCRROWS`, `SCRCOLS`) to remember and manipulate the visible state.
*   **Flex APIs:** Integrates with simulated Flex DOS calls (`GETCHAR`, `PUTCHR`, etc.) for portability in an educational setting.
\n`