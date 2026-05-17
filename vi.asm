* VI Editor for Flex - 6800 Assembly Language Implementation
* Target: TSC 6800 FLEX Operating System
* Memory: Code starts at $0100, available through $7F00
* Display: VT100 terminal with escape sequences

* =============================================================================
* Memory Map and Constants
* =============================================================================

        ORG     $0100           * Code starts here per Flex convention

* =============================================================================
* I/O Interface (Flex System Calls)
* =============================================================================

* Flex DOS System Call Addresses
GETCHR  EQU     $AD15           * Get character from keyboard
PUTCHR  EQU     $AD18           * Put character to terminal
PCRLF   EQU     $AD24           * Print CR/LF
WARMS   EQU     $AD03           * Warm start (exit to FLEX)
GETFIL  EQU     $AD2D           * Get file specification
SETEXT  EQU     $AD33           * Set default file extension
OUTDEC  EQU     $AD39           * Output decimal number
ADDBX   EQU     $AD36           * Add B-register to X-register
LBPTR   EQU     $AC14           * DOS line buffer pointer

* Flex File Management System (FMS) Addresses
FMS     EQU     $B406           * FMS Call entry point
FMSCLS  EQU     $B403           * FMS Close all files

* FMS Function Codes
FMSREAD EQU 1             * Open file for read
FMSWRIT EQU 2             * Open file for write  
FMSCLOS EQU 4             * Close file
FMSRWND EQU 5             * Rewind file

* File Control Block (FCB) - 320 bytes
FCBSZ   EQU 320           * Size of FCB structure

* VT100 Control Sequences
ESC     EQU     $1B             * Escape character
BS      EQU     $08             * Backspace
LF      EQU     $0A             * Line Feed
CR      EQU     $0D             * Carriage Return
SPACE   EQU     $20             * Space character

* Screen defaults (will be read from Flex environment)
DEFROWS EQU    24              * Default screen rows
DEFCOLS EQU    80              * Default screen columns

* Editor modes
MODECMD EQU    0               * Command mode
MODEINS EQU    1               * Insert mode

* =============================================================================
* Variable Storage Area
* =============================================================================

SCRROWS RMB  1              * Current screen rows
SCRCOLS RMB  1              * Current screen columns
CSRROW  RMB  1              * Current cursor row (1-based)
CSRCOL  RMB  1              * Current cursor column (1-based)
EDMODE  RMB  1              * Current editor mode
DIRTY   RMB  1              * File modified flag

* File management variables
FOPEN    RMB  1             * File open flag (0=closed, 1=open)
FILENAME RMB  12            * Current filename (11 chars + null)
FILEFCB  RMB  FCBSZ         * File Control Block (320 bytes)

* Text buffer management
BUFSZ   EQU  4096           * Text buffer size (4KB)
TXTBUF  RMB  BUFSZ          * Main text buffer
BUFEND  RMB  2              * End of text in buffer (pointer)
BUFPOS  RMB  2              * Current position in buffer
LNSTART RMB  2              * Start of current line in buffer

* Screen display variables  
TOPLINE  RMB  2              * First line displayed on screen
CURRLINE RMB  2              * Current line number (1-based)
LNTOTAL  RMB  2              * Total lines in buffer

* Status line mode string pointer
MODESTR RMB 2                * Pointer to mode string for status line

* Cursor and navigation variables
CSRBPOS RMB 2               * Current position in text buffer
LASTCOL RMB  1              * Remember column for vertical movement
YANKBUF RMB  256            * Buffer for copy/paste operations
YANKSZ  RMB  1              * Size of yanked content

* Temporary registers (6800 has only one index register X)
YP      RMB  2              * Secondary index pointer (Y simulation)
TMPX    RMB  2              * Temporary X storage
TMPY    RMB  2              * Temporary secondary storage
DLEN    RMB  1              * Computed range length
MTMP    RMB  2              *

* =============================================================================
* Main Entry Point
* =============================================================================

* START
* Purpose: Entry point
* Input: none
* Output: control transfers to editor loop
START   
*       * Initialize editor
        JSR     INITED
        
*       * Main editor loop
* MAINLOOP
* Purpose: Main event loop
* Input: none
* Output: none (runs until EXITVI)
MAINLOOP
        JSR     GETKEY         * Get keystroke
        JSR     PROCKEY        * Process the keystroke
        BRA     MAINLOOP       * Continue forever

* =============================================================================
* INITED
* Purpose: Initialize editor state
* Input: none
* Output: screen, mode, pointers initialized
INITED
*       * Clear screen and initialize cursor position
        JSR     CLRSCR
        
*       * Initialize screen dimensions from Flex environment
        JSR     GETSCSZ
        
*       * Set command mode
        CLR     EDMODE
        CLR     DIRTY
        CLR     FOPEN
        LDX     #CMDMSG
        STX     MODESTR

*       * Clear current filename so status line is deterministic
        LDX     #FILENAME
        CLRA
        STAA    0,X

*       * If a filename was passed on the command line, load it now
        JSR     GETARG
        BNE     NOARGI
        JSR     OPNFILE
        BNE     NOARGI
        JSR     RDBUF
        BNE     NOARGI
        JSR     DISPBUF
        JSR     UPDCSR
        RTS

NOARGI
        
*       * Initialize text buffer
        LDX     #TXTBUF
        STX     TOPLINE
        STX     BUFPOS
        STX     CSRBPOS
        STX     BUFEND
        
        LDX     #1
        STX     CURRLINE
        STX     LNTOTAL

*       * Set initial cursor position (1,1)
        LDAA    #1
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        JSR     POSCSR
        JSR     STATSLN

        JSR     GOTOHOME

        RTS

* Print null-terminated string pointed to by X
* PRNSTR
* Purpose: Print null-terminated string
* Input: X = pointer to string
* Output: chars emitted via PUTCHAR
PRNSTR
        LDAA    0,X             * Get character
        BEQ     PRNDONE         * If null, we're done
        INX                     * Increment pointer
        JSR     PUTCHAR         * Output character
        BRA     PRNSTR          * Continue
PRNDONE
        RTS

* =============================================================================
* Screen Control Functions
* =============================================================================

* Clear entire screen and position cursor at home
* CLRSCR
* Purpose: Clear terminal and home cursor
* Input: none
* Output: screen cleared, CSRROW/CSRCOL reset
CLRSCR
*       * Send ESC[2J (clear entire screen)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'2
        JSR     PUTCHAR
        LDAA    #'J
        JSR     PUTCHAR

*       * Send ESC[H (cursor home)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'H
        JSR     PUTCHAR

*       * Update cursor location
        LDAA    #1
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL

        RTS

* Position cursor at home (1,1)
* 1x1
* GOTOHOME
* Purpose: Move cursor to row 1 col 1
* Input: none
* Output: CSRROW/CSRCOL updated, cursor moved
GOTOHOME
        LDAA    #1
        STAA    CSRROW
        STAA    CSRCOL
        JSR     POSCSR
        RTS

* Position cursor at bottom left
* GOTOBL
* Purpose: Move cursor to bottom-left
* Input: SCRROWS
* Output: cursor positioned to SCRROWS,1
GOTOBL
        LDAA    SCRROWS
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        JSR     POSCSR
        RTS

* Position cursor at top right
* GOTOTR
* Purpose: Move cursor to top-right
* Input: SCRCOLS
* Output: cursor positioned to 1,SCRCOLS
GOTOTR
        LDAA    #1
        STAA    CSRROW
        LDAA    SCRCOLS
        STAA    CSRCOL
        JSR     POSCSR
        RTS

* Position cursor at bottom right
* GOTOBR
* Purpose: Move cursor to bottom-right
* Input: SCRROWS, SCRCOLS
* Output: cursor positioned to SCRROWS,SCRCOLS
GOTOBR
        LDAA    SCRROWS
        STAA    CSRROW
        LDAA    SCRCOLS
        STAA    CSRCOL
        JSR     POSCSR
        RTS

* Position cursor at current CSRROW, CSRCOL
* Uses VT100 ESC[row;colH sequence
* POSCSR
* Purpose: Position cursor using CSRROW/CSRCOL
* Input: CSRROW, CSRCOL
* Output: VT100 cursor-position sequence emitted
POSCSR
*       * Send ESC[
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        
*       * Send row number
        LDAA    CSRROW
        JSR     PUTDEC
        
*       * Send semicolon
        LDAA    #';
        JSR     PUTCHAR
        
*       * Send column number
        LDAA    CSRCOL
        JSR     PUTDEC
        
*       * Send H
        LDAA    #'H
        JSR     PUTCHAR
        
        RTS

* =============================================================================
* Screen Size Detection
* =============================================================================

* Get screen size from Flex environment
* Check if we can detect actual terminal size, otherwise use defaults
* GETSCSZ
* Purpose: Initialize screen size values
* Input: none
* Output: SCRROWS/SCRCOLS set
GETSCSZ
*       * For now, try to detect common terminal sizes
*       * Later we can enhance this with actual Flex environment calls
        
*       * TODO: Add actual Flex terminal size detection
*       * For now, assume standard VT100 terminal
        LDAA     #DEFROWS
        STAA     SCRROWS
        LDAA     #DEFCOLS  
        STAA     SCRCOLS
        
*       * Could add environment variable checks here:
*       * Check for LINES and COLUMNS environment variables
*       * Or use VT100 Device Status Report (DSR) sequences
        
        RTS

* =============================================================================
* Utility Functions
* =============================================================================

* Output decimal number in A register (1-99 range for cursor positioning)
* PUTDEC
* Purpose: Print A as decimal via OUTDEC
* Input: A = value
* Output: decimal text emitted
PUTDEC
        NOP
        CLRB                    * No leading-space suppression
        CLR     MTMP            * Build 16-bit value for OUTDEC
        STAA    MTMP+1
        LDX     #MTMP
        JMP     OUTDEC

* =============================================================================
* Keyboard Input
* =============================================================================

* Get a single keystroke (blocking)
* character is returned to the calling program in the A-register
* GETKEY
* Purpose: Blocking keyboard read
* Input: none
* Output: A = key value
GETKEY
        JSR     GETCHR          * Call Flex GETCHR routine
        CMPA    #1
        BLT     GETKEY
        RTS

* =============================================================================
* Key Processing
* =============================================================================

* Process keystroke in A register
* PROCKEY
* Purpose: Route key to mode handler
* Input: A = key value
* Output: invokes command/insert actions
PROCKEY
        CMPA    #'Q            * Quit command
        BEQ     JXITVI
        
        CMPA    #ESC           * Escape key (command mode)
        BEQ     JETCMD
        
*       * Check current mode
        TST     EDMODE
        BEQ     JROCCMD        * Command mode
        
*       * Insert mode - handle text input
        CMPA    #CR            * Enter key
        BEQ     JNSNLK
        
        CMPA    #8             * Backspace
        BEQ     JNSBKSP
        
        CMPA    #SPACE         * Printable character?
        BLO     JRCKDN         * Ignore control chars
        
*       * Insert the character
        JSR     INSCH
        BNE     INSFAIL
        
*       * Update only affected rows and restore cursor
        JSR     INSRUPD
        
INSFAIL
PRCKDN
        RTS
****************************************
* Jump table
****************************************
JXITVI  JMP     EXITVI          * Quit command
JETCMD  JMP     SETCMD          * Escape key (command mode)
JROCCMD JMP     PROCCMD         * Command mode
JNSNLK  JMP     INSNLK          * Enter key
JNSBKSP JMP     INSBKSP         * Backspace
JRCKDN  JMP     PRCKDN          * Ignore control chars

****************************************

* INSNLK
* Purpose: Insert newline and refresh view
* Input: BUFPOS/CSRBPOS state
* Output: buffer/display updated
INSNLK
        JSR     INSNL
        BNE     NLKERR
        JSR     INSRUPD
NLKERR
        RTS

INSBKSP
*       * Delete previous character
        LDX     BUFPOS
        CPX     #TXTBUF
        BEQ     BKSPDONE  * At start of buffer
        
*       * Move position back
        DEX
        STX     BUFPOS
        
*       * Delete character
        JSR     DELCH
        JSR     INSRUPD
        
BKSPDONE
        RTS

* Refresh insert-mode display from the edited row down and restore cursor
* INSRUPD
* Purpose: Refresh insert-mode affected rows
* Input: CSRROW/CSRCOL and CSRBPOS
* Output: display refreshed, cursor restored
INSRUPD
        JSR     UPDCSR
        LDAA    CSRROW
        STAA    TMPY
        LDAA    CSRCOL
        STAA    TMPY+1
        LDAA    TMPY
        CMPA    #1
        BEQ     INSRU1
        SUBA    #1
INSRU1
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        JSR     INSRFDN
        LDAA    TMPY
        STAA    CSRROW
        LDAA    TMPY+1
        STAA    CSRCOL
        JSR     POSCSR
        LDX     CSRBPOS
        STX     BUFPOS
        RTS

PROCCMD
*       * Command mode key processing
        CMPA    #'a
        BLO     CMDNORM
        CMPA    #'z+1
        BHS     CMDNORM
        SUBA    #$20
CMDNORM
        CMPA    #'H            * Move left
        BEQ     KMDCLFT
        
        CMPA    #'J            * Move down
        BEQ     KMDCDN
        
        CMPA    #'K            * Move up  
        BEQ     KMDCUP
        
        CMPA    #'L            * Move right
        BEQ     KMDCRGT
        
        CMPA    #'0            * Beginning of line
        BEQ     KMDLNST
        
        CMPA    #'$            * End of line
        BEQ     KMDLNEND
        
        CMPA    #'G            * Go to last line
        BEQ     KMDGOLST
        
*        CMPA    #'g            * Go to first line (gg)
*        BEQ     KMDGOFST
        
        CMPA    #'w            * Word forward (changed from save)
        BEQ     KMDWDF
        
        CMPA    #'b            * Word backward
        BEQ     KMDWDB
        
        CMPA    #'/            * Search forward
        BEQ     KMDSRF
        
        CMPA    #'?            * Search backward
        BEQ     KMDSRB
        
        CMPA    #'O            * Open file OR open line below
        BEQ     KMDORF
         
*       CMPA    #'O            * Open line above 
*       BEQ     KMDOLA
        
        CMPA    #'R            * Refresh display
        BEQ     KMDREF
        
        CMPA    #':            * Command line mode
        BEQ     KMDCOLN
        
        CMPA    #'I            * Insert mode
        BEQ     KMDINS
        
        CMPA    #'A            * Append mode  
        BEQ     KMDAPP
        
        CMPA    #'X            * Delete character
        BEQ     KMDDLCH
        
        CMPA    #'D            * Delete command
        BEQ     KMDDEL
        
        CMPA    #'Y            * Yank (copy) command
        BEQ     KMDYANK
        
        CMPA    #'P            * Put (paste) after
        BEQ     KMDPUTA
        
*        CMPA    #'P            * Put (paste) before
*        BEQ     KMDPUTB
        
        CMPA    #'U            * Undo
        BEQ     KMDUNDO
        
*       * Unknown command, ignore
        RTS
************************************************
* Jump table
************************************************
KMDCLFT  JMP     CMDCLFT         * Move left
KMDCDN   JMP     CMDCDN          * Move down
KMDCUP   JMP     CMDCUP          * Move up  
KMDCRGT  JMP     CMDCRGT         * Move right
KMDLNST  JMP     CMDLNST         * Beginning of line
KMDLNEND JMP     CMDLNEND        * End of line
KMDGOLST JMP     CMDGOLST        * Go to last line
KMDWDF   JMP     CMDWDF          * Word forward (changed from save)
KMDWDB   JMP     CMDWDB          * Word backward
KMDSRF   JMP     CMDSRF          * forward
KMDSRB   JMP     CMDSRB          * backward
KMDORF   JMP     CMDORF          * Open file OR open line below
KMDREF   JMP     CMDREF          * Refresh display
KMDCOLN  JMP     CMDCOLN         * line mode
KMDINS   JMP     CMDINS          * Insert mode
KMDAPP   JMP     CMDAPP          * Append mode  
KMDDLCH  JMP     CMDDLCH         * Delete character
KMDDEL   JMP     CMDDEL          * Delete command
KMDYANK  JMP     CMDYANK         * Yank (copy) command
KMDPUTA  JMP     PUTACMD         * Put (paste) after
KMDUNDO  JMP     CMDUNDO         * Undo

* Handle 'o command - open file if no file loaded, open line if file loaded
CMDORF
        TST     FOPEN
        BEQ     CMDOPNF         * No file open, open file
*       BRA     CMDOLB          * File open, open line below
        JMP     CMDOLB          * File open, open line below

* SETCMD
* Purpose: Switch to command mode
* Input: EDMODE, CSRBPOS
* Output: EDMODE cleared, status/cursor refreshed
SETCMD
        TST     EDMODE          * Leaving insert mode?
        BEQ     SCMDNX
        LDX     CSRBPOS
        STX     BUFPOS
SCMDNX
        CLR     EDMODE          * Set command mode
        LDX     #CMDMSG
        STX     MODESTR
        JSR     STATSLN
        JSR     UPDCSR
        RTS

CMDOPNF
        JSR     OPNFILE
        BNE     OPNFERR
        
*       * File opened, read it into buffer
        JSR     RDBUF
        BNE     RDFERR
        
*       * Initialize display
        LDX     #TXTBUF
        STX     TOPLINE
        
*       * Display the file
        JSR     DISPBUF
        RTS

OPNFERR
*       * TODO: Display error message
        RTS

RDFERR  
*       * Close file and display error
        JSR     CLSFILE
*       * TODO: Display error message
        RTS

CMDSUP
        JSR     SCRLUP
        RTS

CMDSDN
        JSR     SCRLDOWN
        RTS

CMDREF
        JSR     DISPBUF
        RTS

CMDSAVE
        JSR     SAVFILE
        BNE     SAVCERR
        
*       * Display save confirmation
        LDX     #SAVMSG
        JSR     STAMSG
        
*       * Wait briefly then refresh
        JSR     SDLY
        JSR     DISPBUF
        RTS

SAVCERR
*       * Display error message
        LDX     #SAVEMSG
        JSR     STAMSG
        
        JSR     SDLY
        JSR     DISPBUF
        RTS

CMDCOLN
*       * Handle : commands (like :w, :q, :wq)
        JSR     PRCCOL
        RTS

* Process colon commands (:w, :q, :wq, etc.)
PRCCOL
*       * Draw status line, then enter command on status line
        JSR     STATSLN
        JSR     GOTOBL
        LDAA     #':
        JSR     PUTCHAR
        
*       * Get command character
        JSR     GETKEY
        JSR     PUTCHAR
        
        CMPA     #'W            * Write command
        BEQ     COLWRIT
        
        CMPA     #'Q            * Quit command
        BEQ     COLQUIT
        
*       * Unknown command
        JMP     COLRSTR

COLWRIT
*       * Check for 'q after 'w (wq command)
        JSR     GETKEY
        CMPA    #CR             * Just :w
        BEQ     OCOLWRT
        JSR     PUTCHAR
        
        CMPA    #'Q            * :wq command
        BEQ     QCOLWRT
        
*       * Invalid command
        JMP     COLRSTR

OCOLWRT
        JSR     SAVFILE
        JMP     COLRSTR

QCOLWRT
        JSR     SAVFILE
        BNE     SAVBQE
*       BRA     EXITVI
        JMP     EXITVI

SAVBQE
*       * Display error and don't quit
        JMP     COLRSTR

COLRSTR
        JSR     STATSLN
        JSR     UPDCSR
        RTS

COLQUIT
*       * Check for unsaved changes
        TST     DIRTY
*       BNE     QUITCHG
        JMP     EXITVI
        
*       * Safe to quit
*       BRA     EXITVI

QUITCHG
*       * Warn about unsaved changes
        LDX     #UNSAVMSG
        JSR     STAMSG
        
*       * Get confirmation
        JSR     GETKEY
        CMPA     #'!            * Force quit
*       BEQ     EXITVI
        JMP     EXITVI
        
*       * Cancel quit
        JSR     DISPBUF
        RTS

* CMDINS
* Purpose: Switch to insert mode
* Input: CSRBPOS
* Output: EDMODE set, BUFPOS synced, status updated
CMDINS
        LDAA     #MODEINS
        STAA     EDMODE
        LDX     CSRBPOS
        STX     BUFPOS

*       * Update status line
        LDX     #INSMSG
        STX     MODESTR
        JSR     STATSLN
        JSR     UPDCSR
        RTS
* =============================================================================
* Status Line Functions
* =============================================================================

* Print status line at bottom of screen in inverse video
STATSLN
        LDAA    CSRROW
        STAA    MTMP
        LDAA    CSRCOL
        STAA    MTMP+1
        LDAA    SCRROWS
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        JSR     POSCSR

*       * Enable inverse video (ESC [ 7 m)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'7
        JSR     PUTCHAR
        LDAA    #'m
        JSR     PUTCHAR

*       * Print mode string
        LDX     MODESTR
        JSR     PRNSTR

*       * Print space
        LDAA    #SPACE
        JSR     PUTCHAR

*       * Print filename
        LDX     #FILENAME
        JSR     PRNSTR

*       * Clear to end of line (ESC [ K)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'K
        JSR     PUTCHAR

*       * Disable inverse video (ESC [ 0 m)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'0
        JSR     PUTCHAR
        LDAA    #'m
        JSR     PUTCHAR
        LDAA    MTMP
        STAA    CSRROW
        LDAA    MTMP+1
        STAA    CSRCOL
        RTS

* Print transient status message from X on bottom line in inverse video
STAMSG
        LDAA    CSRROW
        STAA    MTMP
        LDAA    CSRCOL
        STAA    MTMP+1
        LDAA    SCRROWS
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        JSR     POSCSR

*       * Enable inverse video (ESC [ 7 m)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'7
        JSR     PUTCHAR
        LDAA    #'m
        JSR     PUTCHAR

*       * Print message text
        JSR     PRNSTR

*       * Clear to end of line (ESC [ K)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'K
        JSR     PUTCHAR

*       * Disable inverse video (ESC [ 0 m)
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'0
        JSR     PUTCHAR
        LDAA    #'m
        JSR     PUTCHAR
        LDAA    MTMP
        STAA    CSRROW
        LDAA    MTMP+1
        STAA    CSRCOL
        RTS
* =============================================================================
* Mode Strings
* =============================================================================
CMDMSG  FCC     "-- COMMAND --"
        FCB     0
INSMSG  FCC     "-- INSERT --"
        FCB     0

CMDAPP
*       * Move cursor forward one position for append
        LDX     CSRBPOS
        CPX     BUFEND
        BHS     APPSNX
        LDAA    0,X
        CMPA    #CR
        BEQ     APPSNX
        INX
APPSNX
        STX     CSRBPOS
        STX     BUFPOS
        LDAA     #MODEINS
        STAA     EDMODE
        LDX     #INSMSG
        STX     MODESTR
        JSR     STATSLN
        JSR     UPDCSR
        RTS

CMDDLCH
        JSR     DELCH
        JSR     MKDIRTY
        
*       * Refresh current line display
        JSR     DISPBUF
        RTS

* Show insert mode indicator
SHWINS
        JSR     STATSLN
        RTS

* Show command mode indicator  
SHWCMD
        JSR     STATSLN
        RTS

* =============================================================================
* Navigation Commands
* =============================================================================

* Move cursor down one line (j command)
* CMDCDN
* Purpose: Move cursor down one line
* Input: CSRBPOS
* Output: CSRBPOS and on-screen cursor updated
CMDCDN
        JSR     DNMOVC
        JSR     UPDCSR
        RTS

* Move cursor up one line (k command)  
* CMDCUP
* Purpose: Move cursor up one line
* Input: CSRBPOS
* Output: CSRBPOS and on-screen cursor updated
CMDCUP
        JSR     MOVCUP
        JSR     UPDCSR
        RTS

* Move cursor left one character (h command)
* CMDCLFT
* Purpose: Move cursor left one char
* Input: CSRBPOS
* Output: CSRBPOS and on-screen cursor updated
CMDCLFT
        JSR     MOVCLEFT
        JSR     UPDCSR
        RTS

* Move cursor right one character (l command)
* CMDCRGT
* Purpose: Move cursor right one char
* Input: CSRBPOS
* Output: CSRBPOS and on-screen cursor updated
CMDCRGT
        JSR     MOVCRT
        JSR     UPDCSR
        RTS

* Move to beginning of line (0 command)
CMDLNST
        JSR     MOVLNST
        JSR     UPDCSR
        RTS

* Move to end of line ($ command)
CMDLNEND
        JSR     MOVLNEND
        JSR     UPDCSR
        RTS

* Go to last line (G command)
CMDGOLST
        JSR     GOLSTLN
        JSR     REFSCR
        RTS

* Go to first line (gg command)
FSTCMDGO
*       * Check for second 'g
        JSR     GETKEY
        CMPA     #'g
        BNE     CMDGOFD
        
        JSR     GOFSTLN
        JSR     REFSCR
        
CMDGOFD
        RTS

* Word forward movement (w command)
CMDWDF
        JSR     MOVWDF
        JSR     UPDCSR
        RTS

* Word backward movement (b command)
CMDWDB
        JSR     MOVWDB
        JSR     UPDCSR
        RTS

* Search forward (/ command)
CMDSRF
        JSR     SRCHFWD
        RTS

* Search backward (? command)
CMDSRB
        JSR     SRCHBWD
        RTS

* =============================================================================
* Cursor Movement Functions
* =============================================================================

* Move cursor down one line
DNMOVC
*       * Find start of next line
        LDX     CSRBPOS
        
FNDNCR
*       * Check if at end of buffer
        CPX     BUFEND
        BHS     DNATEND
        
*       * Look for CR
        LDAA    0,X             * Get character
        INX                     * Advance pointer
        CMPA    #CR
        BNE     FNDNCR
        
*       * Found CR, X now points to start of next line
        STX     CSRBPOS
        
*       * Try to maintain column position
        JSR     MOVCOL
        RTS

DNATEND
*       * Already at last line
        RTS

* Move cursor up one line
MOVCUP
*       * Find start of current line
        JSR     FNDCLS
        
*       * Check if at first line
        LDX     LNSTART
        CPX     #TXTBUF
        BEQ     UPATST
        
*       * Find start of previous line
        DEX                     * Move to CR of previous line
        STX     CSRBPOS
        JSR     FNDCLS
        
*       * Try to maintain column position
        JSR     MOVCOL
        RTS

UPATST
*       * Already at first line
        RTS

* Move cursor left one character
MOVCLEFT
        LDX     CSRBPOS
        CPX     #TXTBUF
        BEQ     LFTATST
        
*       * Check if at start of line
        DEX
        LDAA     ,X
        CMPA     #CR
        BEQ     LFTLNST
        
*       * Move left
        STX     CSRBPOS
        RTS

LFTATST
LFTLNST
*       * Can't move left
        RTS

* Move cursor right one character
MOVCRT
        LDX     CSRBPOS
        CPX     BUFEND
        BHS     RGTEND
        
*       * Check if at CR
        LDAA     ,X
        CMPA     #CR
        BEQ     RGTLNEND
        
*       * Move right
        INX
        STX     CSRBPOS
        RTS

RGTEND
RGTLNEND
*       * Can't move right
        RTS

* Move to beginning of current line
MOVLNST
        JSR     FNDCLS
        LDX     LNSTART
        STX     CSRBPOS
        RTS

* Move to end of current line
MOVLNEND
        JSR     FNDCLE
        LDX     BUFPOS      * FNDCLE sets this
        STX     CSRBPOS
        RTS

* Go to first line of buffer
GOFSTLN
        LDX     #TXTBUF
        STX     CSRBPOS
        STX     TOPLINE
        
        LDX     #1
        STX     CURRLINE
        RTS

* Go to last line of buffer
GOLSTLN
        LDX     BUFEND
        STX     CSRBPOS
        
*       * Find start of last line
        JSR     FNDCLS
        LDX     LNSTART
        STX     CSRBPOS
        
*       * Update line number
        LDX     LNTOTAL
        STX     CURRLINE
        
*       * Adjust top line for display
        JSR     ADJTOPL
        RTS

* Find start of current line and store in LNSTART
FNDCLS
        LDX     CSRBPOS
        
CLSLPFND
*       * Check if at beginning of buffer
        CPX     #TXTBUF
        BEQ     CLSOKFND
        
*       * Check previous character
        DEX
        LDAA     ,X
        CMPA     #CR
        BNE     CLSLPFND
        
*       * Found CR, move to character after it
        INX
        
CLSOKFND
        STX     LNSTART
        RTS

* Find end of current line
FNDCLE
        LDX     CSRBPOS
        
LPFNDCLE
*       * Check if at end of buffer
        CPX     BUFEND
        BHS     OKFNDCLE
        
*       * Check for CR
        LDAA     ,X
        CMPA     #CR
        BEQ     OKFNDCLE
        
        INX
        BRA     LPFNDCLE

OKFNDCLE
        STX     BUFPOS      * Reuse existing variable
        RTS

* Move to specific column on current line
MOVCOL
*       * Save target column
        LDAA     LASTCOL
        PSHA
        
*       * Start at beginning of line
        JSR     FNDCLS
        LDX     LNSTART
        STX     CSRBPOS
        
*       * Move right up to target column
        PULA               * Get target column
        LDAB     #0              * Current column
        
MOVCLP
        CBA               * Reached target column?
        BEQ     MOVCDN
        
*       * Check if at end of line
        LDX     CSRBPOS
        CPX     BUFEND
        BHS     MOVCDN
        
        LDAA     ,X
        CMPA     #CR
        BEQ     MOVCDN
        
*       * Move right
        INX
        STX     CSRBPOS
        INCB
        
*       * Restore target column
        PULA
        PSHA
        
        BRA     MOVCLP

MOVCDN
        PULA               * Clean stack
        RTS

* Update display cursor position
* UPDCSR
* Purpose: Compute cursor row/col from buffer position
* Input: TOPLINE, CSRBPOS, BUFEND
* Output: CSRROW/CSRCOL set and cursor positioned
UPDCSR
*       * Calculate screen row/col by scanning from TOPLINE to CSRBPOS
        LDX     TOPLINE
        LDAA    #1
        STAA    CSRROW
        STAA    CSRCOL

CSRSCAN
        CPX     CSRBPOS
        BHS     CSRDONE
        CPX     BUFEND
        BHS     CSRDONE
        LDAA    0,X
        CMPA    #CR
        BEQ     CSRNEWL
        INX
        LDAA    CSRCOL
        ADDA    #1
        STAA    CSRCOL
        BRA     CSRSCAN

CSRNEWL
        INX
        LDAA    CSRROW
        ADDA    #1
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        BRA     CSRSCAN

CSRDONE
*       * Keep cursor out of reserved status line
        LDAA    CSRROW
        CMPA    SCRROWS
        BLO     CSROK
        LDAA    SCRROWS
        SUBA    #1
        STAA    CSRROW
CSROK
        JSR     POSCSR
        RTS

* Refresh entire screen
REFSCR
        JSR     DISPBUF
        RTS

* Adjust TOPLINE to keep cursor visible
ADJTOPL
*       * TODO: Implement screen positioning logic
        RTS

* =============================================================================
* Word Movement Functions
* =============================================================================

* Move forward one word
MOVWDF
        LDX     CSRBPOS
        
*       * Skip current word
        JSR     WCHSKP
        
*       * Skip whitespace
        JSR     SKPWS
        
        STX     CSRBPOS
        RTS

* Move backward one word
MOVWDB
        LDX     CSRBPOS
        
*       * Skip whitespace backwards
        JSR     SKPWSB
        
*       * Skip word characters backwards
        JSR     WCHBSKP
        
        STX     CSRBPOS
        RTS

* Skip over word characters (letters, digits, _)
WCHSKP
SKPWLP
        CPX     BUFEND
        BHS     SKPWDN
        
        LDAA     ,X
        JSR     ISWCH
        BEQ     SKPWDN  * Not a word character
        
        INX
        BRA     SKPWLP

SKPWDN
        RTS

* Skip over whitespace
SKPWS
WSLPSKP
        CPX     BUFEND
        BHS     SKPWSDN
        
        LDAA     ,X
        CMPA     #SPACE
        BEQ     SKPWSNX
        CMPA     #9              * TAB
        BEQ     SKPWSNX
        CMPA     #CR
        BEQ     SKPWSDN * Stop at line end
        
*       * Not whitespace
        BRA     SKPWSDN

SKPWSNX
        INX
        BRA     WSLPSKP

SKPWSDN
        RTS

* Skip word characters backwards
WCHBSKP
SKPWCLB
        CPX     #TXTBUF
        BEQ     SKPWCBD
        
        DEX
        LDAA     ,X
        JSR     ISWCH
        BNE     SKPWCLB
        
*       * Not a word character, move forward one
        INX

SKPWCBD
        RTS

* Skip whitespace backwards  
SKPWSB
SKPWSLB
        CPX     #TXTBUF
        BEQ     WSBDSKP
        
        DEX
        LDAA     ,X
        CMPA     #SPACE
        BEQ     SKPWSLB
        CMPA     #9              * TAB
        BEQ     SKPWSLB
        
*       * Not whitespace, move forward one
        INX

WSBDSKP
        RTS

* Check if character in A is a word character
* Returns: Z flag set if not word char, clear if word char
ISWCH
*       * Check for letter
        CMPA     #'A
        BLO     NOTWCH
        CMPA     #'Z+1
        BLO     ISWCHYES
        
        CMPA     #'a
        BLO     NOTWCH
        CMPA     #'z+1
        BLO     ISWCHYES
        
*       * Check for digit
        CMPA     #'0
        BLO     NOTWCH
        CMPA     #'9+1
        BLO     ISWCHYES
        
*       * Check for underscore
        CMPA     #'_ 
        BEQ     ISWCHYES

NOTWCH
        LDAA     #0              * Set Z flag
        RTS

ISWCHYES
        LDAA     #1              * Clear Z flag
        RTS

* =============================================================================
* Search Functions
* =============================================================================

SRCHPAT RMB 32           * Search pattern buffer

* Search forward
SRCHFWD
*       * Get search pattern
        JSR     GETSRCH
        BEQ     SRCHFDN * Empty pattern
        
*       * Perform search
        JSR     SRCHF
        BNE     SRCHNF
        
*       * Found, update cursor
        STX     CSRBPOS
        JSR     REFSCR

SRCHFDN
        RTS

SRCHNF
*       * Display "not found" message
        JSR     SHWNF
        RTS

* Search backward
SRCHBWD
*       * Get search pattern
        JSR     GETSRCH
        BEQ     SRCHBDN
        
*       * Perform search
        JSR     SRCHB
        BNE     SRCHNF
        
*       * Found, update cursor
        STX     CSRBPOS
        JSR     REFSCR

SRCHBDN
        RTS

* Get search pattern from user
GETSRCH
*       * Clear pattern buffer
        LDX     #SRCHPAT
        LDAA     #0
        LDAB     #32
CLRPAT
        STAA    0,X             * Store zero
        INX                     * Advance pointer
        DECB
        BNE     CLRPAT
        
*       * Position cursor at bottom for input
        JSR     GOTOBL
        
*       * Display search prompt
        LDAA     #'/
        JSR     PUTCHAR
        
*       * Get pattern from user
        LDX     #SRCHPAT
        LDAB     #0              * Pattern length
        
GETPLP
        JSR     GETKEY
        
        CMPA     #CR             * End of input
        BEQ     GETPDN
        
        CMPA     #ESC            * Cancel search
        BEQ     GETPCAN
        
        CMPA     #8              * Backspace
        BEQ     GETPBK
        
*       * Add character to pattern
        CMPA     #SPACE
        BLO     GETPLP * Ignore control chars
        
        CMPB     #30             * Check pattern length
        BHS     GETPLP * Too long
        
        STAA    0,X             * Store character
        INX                     * Advance pattern pointer
        INCB                    * Increment length
        JSR     PUTCHAR         * Echo character
        
        BRA     GETPLP

GETPBK
        TSTB               * Any characters to delete?
        BEQ     GETPLP
        
        DEX                     * Move back in pattern
        CLR     ,X              * Clear character
        DECB                    * Decrement length
        
*       * Visual backspace
        LDAA     #8
        JSR     PUTCHAR
        LDAA     #SPACE
        JSR     PUTCHAR
        LDAA     #8
        JSR     PUTCHAR
        
        BRA     GETPLP

GETPCAN
        LDAB     #0              * Empty pattern

GETPDN
        TBA             * Return pattern length
        RTS

* Perform forward search
SRCHF
        LDX     CSRBPOS
        INX                     * Start after current position
        
SRCHFLP
        CPX     BUFEND
        BHS     SRCHFNF
        
*       * Check for pattern match
        JSR     MATCHPAT
        BEQ     SRCHFFD
        
        INX
        BRA     SRCHFLP

SRCHFFD
        CLRA               * Success
        RTS

SRCHFNF
        LDAA     #1              * Not found
        RTS

* Perform backward search
SRCHB
        LDX     CSRBPOS
        
SRCHBLP
        CPX     #TXTBUF
        BEQ     SRCHBNF
        
        DEX
        
*       * Check for pattern match
        JSR     MATCHPAT
        BEQ     SRCHBFD
        
        BRA     SRCHBLP

SRCHBFD
        CLRA               * Success
        RTS

SRCHBNF
        LDAA     #1              * Not found
        RTS

* Match pattern at position X
* Returns: Z flag set if match, clear if no match
MATCHPAT
        STX     TMPX            * Save buffer position
        LDX     #SRCHPAT        * X points to pattern

MATCHLP
        LDAA    0,X             * Get pattern character
        INX                     * Advance pattern pointer
        BEQ     MATCHOK         * End of pattern = match
        STX     YP              * Save pattern pointer
        LDX     TMPX            * Load buffer pointer
        CMPA    0,X             * Compare with buffer
        BNE     MATCHFL
        INX                     * Advance buffer pointer
        STX     TMPX            * Save buffer pointer
        CPX     BUFEND          * Check buffer bounds
        BHI     MATCHFL
        LDX     YP              * Restore pattern pointer
        BRA     MATCHLP

MATCHOK
        LDX     TMPX            * Restore buffer position
        LDAA    #0              * Set Z flag
        RTS

MATCHFL
        LDX     TMPX            * Restore buffer position
        LDAA    #1              * Clear Z flag
        RTS

* Show "not found" message
SHWNF
        LDX     #NFNDMSG
        JSR     STAMSG
        JSR     SDLY
        JSR     REFSCR
        RTS

NFNDMSG
        FCC     "Pattern not found"
        FCB     0

* =============================================================================
* Advanced Editing Commands
* =============================================================================

* Open line below (o command)
CMDOLB
*       * Move to end of current line
        JSR     MOVLNEND
        
*       * Insert newline
        JSR     INSNL
        BNE     OPNBERR
        
*       * Enter insert mode
        LDAA     #MODEINS
        STAA     EDMODE
        JSR     SHWINS
        
OPNBERR
        RTS

* Open line above (O command)
CMDOLA
*       * Move to beginning of current line
        JSR     MOVLNST
        
*       * Insert newline before current line
        LDAA     #CR
        JSR     INSCH
        BNE     OPNAERR
        
*       * Move back to start of new line
        JSR     MOVCUP
        
*       * Enter insert mode
        LDAA     #MODEINS
        STAA     EDMODE
        JSR     SHWINS
        
OPNAERR
        RTS

* Delete command (d + motion)
CMDDEL
*       * Get next character for motion
        JSR     GETKEY
        
        CMPA     #'d            * dd = delete line
        BEQ     CMDDLN
        
        CMPA     #'w            * dw = delete word
        BEQ     CMDDW
        
*       * TODO: Add more delete motions (d$, d0, etc.)
        RTS

* Delete current line (dd command)
CMDDLN
*       * Find start of line
        JSR     FNDCLS
        LDX     LNSTART
        STX     CSRBPOS
        
*       * Find end of line (including CR)
        JSR     FNDCLE
        LDX     BUFPOS          * Get end position
        INX                     * Include the CR
        STX     YP              * YP = end pointer
        LDX     LNSTART         * X = start pointer
        
*       * Copy line to yank buffer for potential restore
        JSR     YANKRNG
        
*       * Delete the line
        JSR     DELRNG
        JSR     MKDIRTY
        JSR     REFSCR
        RTS

* Delete word (dw command)
CMDDW
*       * Save start position
        LDX     CSRBPOS
        STX     TMPX            * Save start position
        
*       * Move forward one word
        JSR     MOVWDF
        
*       * End position is current cursor
        LDX     CSRBPOS         * Load end position
        STX     YP              * YP = end pointer
        LDX     TMPX            * Restore start position
        
*       * Delete range
        JSR     DELRNG
        JSR     MKDIRTY
        JSR     UPDCSR
        RTS

* Yank (copy) command (y + motion)
CMDYANK
*       * Get next character for motion
        JSR     GETKEY
        
        CMPA     #'y            * yy = yank line
        BEQ     YNKLCMD
        
        CMPA     #'w            * yw = yank word
        BEQ     YNKWCMD
        
        RTS

* Yank current line (yy command)
YNKLCMD
*       * Find start of line
        JSR     FNDCLS
        LDX     LNSTART
        STX     TMPX            * Save start pointer
        
*       * Find end of line (including CR)
        JSR     FNDCLE
        LDX     BUFPOS
        INX                     * Include CR
        STX     YP              * YP = end pointer
        LDX     TMPX            * X = start pointer
        
*       * Yank the text
        JSR     YANKRNG
        
*       * Show yank confirmation
        JSR     SHWYNK
        RTS

* Yank word (yw command)
YNKWCMD
*       * Save start position
        LDX     CSRBPOS
        STX     TMPX            * Save start position
        
*       * Move forward one word
        JSR     MOVWDF
        LDX     CSRBPOS         * End position
        STX     YP              * YP = end pointer
        LDX     TMPX            * Restore start position
        
*       * Restore cursor position
        STX     CSRBPOS
        
*       * Yank the text
        JSR     YANKRNG
        JSR     SHWYNK
        RTS

* Put (paste) after cursor (p command)
PUTACMD
*       * Check if we have yanked content
        TST     YANKSZ
        BEQ     PUTNONE
        
*       * Move cursor forward one position
        JSR     MOVCRT
        
*       * Insert yanked content
        JSR     INSYANK
        JSR     MKDIRTY
        JSR     REFSCR

PUTNONE
        RTS

* Put (paste) before cursor (P command) 
PUTBCMD
*       * Check if we have yanked content
        TST     YANKSZ
        BEQ     PUTNONE
        
*       * Insert yanked content at current position
        JSR     INSYANK
        JSR     MKDIRTY
        JSR     REFSCR
        RTS

* Basic undo (u command)
CMDUNDO
*       * TODO: Implement proper undo functionality
*       * For now, just show a message
        LDX     #UNDOMSG
        JSR     STAMSG
        JSR     SDLY
        JSR     REFSCR
        RTS

* =============================================================================
* Text Manipulation Helper Functions
* =============================================================================

* Yank (copy) text from X to YP into yank buffer
YANKRNG
*       * Calculate length (YP - X, low bytes sufficient for <256 range)
        STX     TMPY            * Save start pointer
        LDAB    YP+1            * Low byte of end pointer (YP)
        SUBB    TMPY+1          * Low byte of start pointer
        CMPB    #255
        BLO     YANKSOK
        LDAB    #255            * Limit to buffer size

YANKSOK
        STAB    YANKSZ
        LDX     TMPY            * Restore start pointer
        STX     YP              * YP = current source pointer
        LDX     #YANKBUF        * X = dest pointer (yank buffer)
        LDAB    YANKSZ

YANKCLP
        TSTB
        BEQ     YANKCDO
        STX     TMPX            * Save dest pointer
        LDX     YP              * Load source pointer
        LDAA    0,X             * Get character
        INX
        STX     YP              * Update source pointer
        LDX     TMPX            * Restore dest pointer
        STAA    0,X             * Store character
        INX
        DECB
        BRA     YANKCLP

YANKCDO
        RTS

* Delete text from X to YP
DELRNG
*       * Calculate delete length (YP - X, low bytes)
        STX     TMPY            * Save start pointer
        LDAB    YP+1            * Low byte of end (YP)
        SUBB    TMPY+1          * Low byte of start
        STAB    DLEN            * Save delete length
*       * Calculate shift count (BUFEND - YP)
        LDAB    BUFEND+1        * Low byte of BUFEND
        SUBB    YP+1            * Low byte of YP
*       * B = bytes after deleted range to shift left
*       * Set up: X = source (YP), YP = dest (TMPY = start)
        LDX     YP              * X = source (start of remaining)
        STX     TMPX            * Save source pointer
        LDX     TMPY            * X = dest (deletion start)
        STX     YP              * YP = dest pointer
        LDX     TMPX            * X = source pointer

DELSLP
        TSTB
        BEQ     DELSDN
        LDAA    0,X             * Get source character
        INX
        STX     TMPX            * Save source pointer
        LDX     YP              * Load dest pointer
        STAA    0,X             * Store character
        INX
        STX     YP              * Save dest pointer
        LDX     TMPX            * Restore source pointer
        DECB
        BRA     DELSLP

DELSDN
*       * Update BUFEND: BUFEND = BUFEND - DLEN
        LDAB    BUFEND+1        * Low byte of BUFEND
        SUBB    DLEN            * Subtract delete length
        STAB    BUFEND+1
        BCC     SDNXDEL         * No borrow
        DEC     BUFEND          * Handle borrow in high byte
SDNXDEL
        RTS

* Insert yanked text at current cursor position
INSYANK
*       * Check yank buffer size
        LDAA     YANKSZ
        BEQ     INSYDN
        
*       * Make room in buffer
        LDAB     YANKSZ
        JSR     MKROOM
        BNE     INSYERR
        
*       * Copy from yank buffer to insertion point
        LDX     #YANKBUF        * X = source (yank buffer)
        STX     YP              * YP = source pointer
        LDX     CSRBPOS         * X = dest (insertion point)
        LDAB    YANKSZ

INSYLP
        TSTB
        BEQ     INSYDN
        STX     TMPX            * Save dest pointer
        LDX     YP              * Load source pointer
        LDAA    0,X             * Get character from yank buffer
        INX
        STX     YP              * Update source pointer
        LDX     TMPX            * Restore dest pointer
        STAA    0,X             * Store to dest
        INX
        DECB
        BRA     INSYLP

INSYDN
*       * Update buffer end
        LDAB    YANKSZ
        LDX     BUFEND
        JSR     ADDBX
        STX     BUFEND

INSYERR
        RTS
****************************************
* ABX X <- X + B
****************************************
*ABX     STX  MTMP
*        PSHB                    ;* Save it for later
*        ADDB MTMP+1             ;* B <- B + m
*        STAB MTMP+1             ;* B -> m
*        BCC  SKIP
*        INC  MTMP               ;* We need to sec
*        SEC
*SKIP    LDX  MTMP               ;* I think this clears carry if 0000
*        PULB
*        RTS

****************************************
* Make room in buffer for B bytes at current cursor position
MKROOM
*       * Check if we have room (BUFEND + B <= TXTBUF+BUFSZ)
        LDX     BUFEND
        JSR     ADDBX           * X = BUFEND + B
        CPX     #TXTBUF+BUFSZ
        BHI     MKRERR          * Not enough room
        STX     YP              * YP = BUFEND+B (dest, working backward)
*       * Compute shift count: B = BUFEND - CSRBPOS
        LDAB    BUFEND+1        * Low byte of BUFEND
        SUBB    CSRBPOS+1       * Low byte of CSRBPOS
        BEQ     MKRDN           * Nothing to shift
*       * Source: X starts at BUFEND, works backward
        LDX     BUFEND

MKRSLP
        TSTB
        BEQ     MKRDN
        DEX                     * Pre-decrement source
        LDAA    0,X             * Get character
        STX     TMPX            * Save source pointer
        LDX     YP
        DEX                     * Pre-decrement dest
        STAA    0,X             * Store character
        STX     YP              * Save dest pointer
        LDX     TMPX            * Restore source pointer
        DECB
        BRA     MKRSLP

MKRDN
        CLRA                    * Success
        RTS

MKRERR
        LDAA    #1              * Error
        RTS

* Show yank confirmation message
SHWYNK
        LDX     #YNKMSG
        JSR     STAMSG
        JSR     SDLY
        JSR     REFSCR
        RTS

YNKMSG
        FCC     "Text yanked"
        FCB     0

UNDOMSG
        FCC     "Undo not implemented"
        FCB     0

* Short delay for messages
SDLY
        LDX     #$0400
DLYLP
        DEX
        BNE     DLYLP
        RTS

SAVMSG
        FCC     "File saved"
        FCB     0

SAVEMSG  
        FCC     "Save failed!"
        FCB     0

UNSAVMSG
        FCC     "Unsaved changes! Press ! to force quit"
        FCB     0

* EXITVI
* Purpose: Leave editor and return to FLEX
* Input: none
* Output: screen cleared, jumps to WARMS
EXITVI
*       * Clean exit
        JSR     CLRSCR
*       * Return to Flex
        JMP     WARMS           * Warm start back to FLEX

* Output character in A register
* Except NULLs
PUTCHAR CMPA    #1
        BLT     SKIP
        JSR     PUTCHR          * Call Flex PUTCHR routine

SKIP    RTS

* =============================================================================
* File I/O Functions  
* =============================================================================

* Open file for reading
* Input: Filename should be in command line or prompt user
OPNFILE
*       * Clear file open flag
        CLR     FOPEN
        
*       * If no filename is already loaded, get one now
        LDX     #FILENAME
        LDAA    0,X
        BEQ     OPNFNM
        BRA     OPNFOK

OPNFNM
        JSR     GETFNAM
        BNE     OPNERR      * Error getting filename

OPNFOK
        
*       * Set up FCB for file operation
        LDX     #FILEFCB       * Point to our FCB
        
*       * Parse filename into FCB
        JSR     STPFCB
        BNE     OPNERR
        
*       * Set function code for open read
        LDAA     #FMSREAD
        STAA     FILEFCB        * Function code goes in byte 0
        
*       * Call FMS to open file
        LDX     #FILEFCB
        JSR     FMS
        BNE     OPNERR      * Check for error
        
*       * File opened successfully
        LDAA     #1
        STAA     FOPEN
        
*       * Set binary mode (no space compression)
        LDAA     #$FF
        STAA     FILEFCB+59     * Space compression flag
        
        CLRA               * Success
        RTS

OPNERR
        LDAA     #1              * Error code
        RTS

* Close currently open file
CLSFILE
        TST     FOPEN
        BEQ     CLSDN      * No file open
        
*       * Set function code for close
        LDAA     #FMSCLOS
        STAA     FILEFCB
        
*       * Call FMS
        LDX     #FILEFCB
        JSR     FMS
        
*       * Clear file open flag
        CLR     FOPEN
        
CLSDN
        RTS

* Read file into text buffer
RDBUF
*       * Initialize buffer pointers
        LDX     #TXTBUF
        STX     BUFPOS
        STX     CSRBPOS
        STX     BUFEND
        
*       * Clear line counter
        LDX     #1
        STX     LNTOTAL
        
RDLOOP
*       * Read next character from file
        LDAA     #0              * Function code 0 = read next byte
        STAA     FILEFCB
        
        LDX     #FILEFCB
        JSR     FMS
        BNE     RDERR      * Check for error or EOF
        
*       * Character is in A register
        JSR     ADDCBUF
        BNE     BUFFUL     * Buffer full
        
*       * Check for end of line
        CMPA     #CR
        BEQ     CNTLN
        
        BRA     RDLOOP

CNTLN
*       * Increment line count
        LDX     LNTOTAL
        INX
        STX     LNTOTAL
        BRA     RDLOOP

RDERR
*       * Check if error is EOF (error #8)
        LDAA     FILEFCB+1      * Error status byte
        CMPA     #8              * End of file?
        BEQ     RDCOMP   * Normal end
        
*       * Real error occurred
        LDAA     #1
        RTS

RDCOMP
BUFFUL
        CLRA               * Success
        RTS

* Add character in A to text buffer
ADDCBUF
        LDX     BUFEND
        
*       * Check buffer bounds
        CPX     #TXTBUF+BUFSZ-1
        BHS     BUFOVF
        
*       * Store character
        STAA    0,X             * Store in buffer
        INX                     * Advance end pointer
        STX     BUFEND
        
        CLRA               * Success
        RTS

BUFOVF
        LDAA     #1              * Error
        RTS

* Get filename from command line or prompt user
GETARG
*       * Copy the first command-line argument into FILENAME
        LDX     #FILENAME
        STX     TMPX
        LDAB    #12
ARGCLR
        CLRA
        STAA    0,X
        INX
        DECB
        BNE     ARGCLR

        LDX     LBPTR
        STX     YP

ARGSKP
        LDX     YP
        LDAA    0,X
        CMPA    #SPACE
        BNE     ARGCHK
        INX
        STX     YP
        BRA     ARGSKP

ARGCHK
        CMPA    #SPACE
        BLS     NOARGF

        LDX     #FILENAME
        STX     TMPX
        LDAB    #11

ARGCPY
        LDX     YP
        LDAA    0,X
        CMPA    #SPACE
        BLS     ARGEND
        CMPA    #'a
        BLO     ARGSTO
        CMPA    #'z+1
        BHS     ARGSTO
        SUBA    #$20
ARGSTO
        LDX     TMPX
        STAA    0,X
        INX
        STX     TMPX
        LDX     YP
        INX
        STX     YP
        DECB
        BNE     ARGCPY

ARGEND
        CLRA                    * Success
        RTS

NOARGF
        LDAA    #1              * No filename argument
        RTS

* Get filename from command line or prompt user
GETFNAM
        JSR     GETARG
        BEQ     GFNOK

*       * For now, use a default filename for testing
        
        LDX     #FILENAME       * Set destination pointer
        STX     YP              * YP = dest (FILENAME)
        LDX     #DEFFNAM        * X = source (default filename)

CPYFNAM
        LDAA    0,X             * Get source character
        INX
        STX     TMPX            * Save source pointer
        LDX     YP              * Load dest pointer
        STAA    0,X             * Store to dest
        INX
        STX     YP              * Update dest pointer
        LDX     TMPX            * Restore source pointer
        TSTA                    * Test character (Z set if null)
        BNE     CPYFNAM         * Continue until null terminator
GFNOK   CLRA                    * Success
        RTS

* Set up FCB with filename 
* STPFCB
* Purpose: Build FILEFCB from FILENAME
* Input: FILENAME string
* Output: FILEFCB cleared and populated
STPFCB
*       * Clear the FCB
        LDX      #FILEFCB
*       * Use A:B as 16-bit byte countdown (320 -> 0)
*       LDAA    #1
*       LDAB    #$40            
        LDAA    #FCBSZ/256      * Hi 8 bits of FCBSZ
        LDAB    #FCBSZ          * Lo 8 bits of FCBSZ
CLRFCB
        CLR     0,X             * Store zero
        INX                     * Advance pointer
        DECB
        BNE     CLRFCB
        TSTA
        BEQ     CLRDONE
        DECA
        LDAB    #0
        BRA     CLRFCB
CLRDONE

*       * Parse raw filename into FCB fields
        LDX     #FILENAME
        STX     YP              * Source pointer

*       * Optional drive number (e.g. 2.foo.txt)
        LDX     YP
        LDAA    0,X
        CMPA    #'0
        BLO     NODRIV
        CMPA    #'3+1
        BHS     NODRIV
        LDAB    1,X
        CMPB    #'.
        BNE     NODRIV
        SUBA    #'0
        LDX     #FILEFCB
        STAA    3,X
        LDX     YP
        INX
        INX
        STX     YP

NODRIV
*       * Copy file name bytes 4-11
        LDX     #FILEFCB+4
        STX     TMPX
        LDAB    #8
NAMLOP
        LDX     YP
        LDAA    0,X
        BEQ     NAMDN
        CMPA    #'.
        BEQ     NAMDN
        LDX     TMPX
        STAA    0,X
        INX
        STX     TMPX
        LDX     YP
        INX
        STX     YP
        DECB
        BNE     NAMLOP

NAMDN
        LDX     YP
        LDAA    0,X
        CMPA    #'.
        BNE     SETDFX
        INX
        STX     YP

*       * Copy extension bytes 12-14
        LDX     #FILEFCB+12
        STX     TMPX
        LDAB    #3
EXTLOP
        LDX     YP
        LDAA    0,X
        BEQ     EXTEND
        CMPA    #'.
        BEQ     EXTEND
        LDX     TMPX
        STAA    0,X
        INX
        STX     TMPX
        LDX     YP
        INX
        STX     YP
        DECB
        BNE     EXTLOP

EXTEND
SETDFX
*       * Apply default TXT extension if none was supplied
        LDX     #FILEFCB
        LDAA    #1              * TXT
        JSR     SETEXT
        CLRA               * Success
        RTS

DEFFNAM
        FCC     "TEST.TXT"
        FCB     0

* =============================================================================
* Screen Display Functions
* =============================================================================

* Redraw editing area from current CSRROW to line above status line
INSRFDN
        LDX     TOPLINE
        STX     BUFPOS
        LDAA    #1
        STAA    MTMP

SCNRFDN
        LDAA    MTMP
        CMPA    CSRROW
        BEQ     RFDNROW
        LDX     BUFPOS

SC2RFDN
        CPX     BUFEND
        BHS     RFDNROW
        LDAA    0,X
        INX
        CMPA    #CR
        BNE     SC2RFDN
        STX     BUFPOS
        LDAA    MTMP
        ADDA    #1
        STAA    MTMP
        BRA     SCNRFDN

RFDNROW
        LDAA    CSRROW
        CMPA    SCRROWS
        BHS     RFDNDN
        LDAA    #1
        STAA    CSRCOL
        JSR     POSCSR
        LDAA    #ESC
        JSR     PUTCHAR
        LDAA    #'[
        JSR     PUTCHAR
        LDAA    #'K
        JSR     PUTCHAR
        JSR     DISPTL
        LDAA    CSRROW
        ADDA    #1
        STAA    CSRROW
        BRA     RFDNROW

RFDNDN
        JSR     STATSLN
        RTS

* Display buffer contents on screen
DISPBUF
        JSR     CLRSCR
        
*       * Start from top line
        LDX     TOPLINE
        STX     BUFPOS
        
*       * Display each line
        LDAA     #1
        STAA     CSRROW
        
DISPLN
*       * Check if we've filled the screen
        LDAA     CSRROW
        CMPA     SCRROWS
        BHS     DISPDN
        
*       * Position cursor at start of line
        LDAA     #1
        STAA     CSRCOL
        JSR     POSCSR
        
*       * Display characters until end of line or buffer
        JSR     DISPTL
        
*       * Move to next line
        LDAA     CSRROW
        ADDA     #1
        STAA     CSRROW
        
        BRA     DISPLN

DISPDN
        JSR     STATSLN
        JSR     UPDCSR
        RTS

* Display one line of text from buffer
DISPTL
        LDX     BUFPOS
        
DISPCH
*       * Check if at end of buffer
        CPX     BUFEND
        BHS     LNDN
        
*       * Get character
        LDAA    0,X
        INX
        
*       * Check for end of line
        CMPA     #CR
        BEQ     LNDN
        
*       * Check for line feed (skip it)
        CMPA     #LF
        BEQ     SKPCH
        
*       * Check for printable character
        CMPA     #SPACE
        BLO     SKPCH       * Control character, skip
        
*       * Output character
        JSR     PUTCHAR
        
*       * Update column position
        LDAA     CSRCOL
        ADDA     #1
        STAA     CSRCOL
        
*       * Check for line wrap
        CMPA     SCRCOLS
        BLO     SKPCH
        
*       * Line is full, stop here
        BRA     LNDN
        
SKPCH
        STX     BUFPOS
        BRA     DISPCH

LNDN
        STX     BUFPOS
        RTS

* Scroll screen up (show later text)
SCRLUP
*       * Find next line start
        LDX     TOPLINE
        
FNDNLN
        CPX     BUFEND
        BHS     SCRLUDN         * At end
        LDAA    0,X             * Get character
        INX                     * Advance pointer
        CMPA    #CR
        BNE     FNDNLN
        
*       * Found next line, update top line
        STX     TOPLINE
        JSR     DISPBUF
        
SCRLUDN
        RTS

* Scroll screen down (show earlier text)  
SCRLDOWN
        LDX     TOPLINE
        CPX     #TXTBUF
        BEQ     SCRLDDN * At beginning
        
*       * Find previous line start
        DEX                     * Move back one character
        
FNDPLN
        CPX     #TXTBUF
        BEQ     PLNOKFND * At start of buffer
        
        LDAA     ,X
        CMPA     #CR
        BEQ     PLNOKFND
        
        DEX
        BRA     FNDPLN
        
PLNOKFND
*       * Move to start of line (after CR)
        INX
        STX     TOPLINE
        JSR     DISPBUF
        
SCRLDDN
        RTS

* =============================================================================
* File Writing Functions
* =============================================================================

* Save current buffer to file
SAVFILE
        TST     FOPEN
        BEQ     SAVNOFL    * No file currently open
        
*       * Close current file if open for read
        JSR     CLSFILE
        
*       * Reopen file for write
        JSR     OPNWRIT
        BNE     SAVERR
        
*       * Write buffer contents to file
        JSR     WRTBUF
        BNE     SAVERR
        
*       * Close file
        JSR     CLSFILE
        
*       * Clear dirty flag
        CLR     DIRTY
        
*       * Reopen for reading to continue editing
        JSR     OPNFILE
        
        CLRA               * Success
        RTS

SAVNOFL
*       * No file open, prompt for filename and create new file
        JSR     SAVNEW
        RTS

SAVERR
        LDAA     #1              * Error
        RTS

* Open existing file for writing (overwrites)
OPNWRIT
*       * Set up FCB for file operation
        LDX     #FILEFCB
        
*       * Parse filename into FCB
        JSR     STPFCB
        BNE     WRTERR
        
*       * Set function code for open write
        LDAA     #FMSWRIT
        STAA     FILEFCB        * Function code goes in byte 0
        
*       * Call FMS to open file
        LDX     #FILEFCB
        JSR     FMS
        BNE     WRTERR * Check for error
        
*       * File opened successfully
        LDAA     #1
        STAA     FOPEN
        
*       * Set binary mode (no space compression)
        LDAA     #$FF
        STAA     FILEFCB+59     * Space compression flag
        
        CLRA               * Success
        RTS

WRTERR
        CLR     FOPEN
        LDAA     #1              * Error code
        RTS

* Write buffer contents to currently open file
WRTBUF
*       * Start at beginning of buffer
        LDX     #TXTBUF
        
WRTCLP
*       * Check if at end of buffer
        CPX     BUFEND
        BHS     WRTCOMP  * Done
        
*       * Get character from buffer
        LDAA    0,X             * Get character
        INX                     * Advance buffer pointer
        STX     TMPX            * Save buffer pointer
        
*       * Write character to file (function code 0)
        PSHA                    * Save character
        LDAA    #0              * Write function code
        STAA    FILEFCB
        PULA                    * Restore character
        
        LDX     #FILEFCB
        JSR     FMS
        
        LDX     TMPX            * Restore buffer pointer
        BNE     WRTCERR * Check for error
        
        BRA     WRTCLP

WRTCOMP
        CLRA               * Success
        RTS

WRTCERR
        LDAA     #1              * Error
        RTS

* Save buffer as new file (Save As functionality)
SAVNEW
*       * Prompt for filename
        JSR     PRMPFN
        BNE     SAVNERR
        
*       * Try to create new file
        JSR     CRTNEW
        BNE     SAVNERR
        
*       * Write buffer to new file
        JSR     WRTBUF
        BNE     SAVNERR
        
*       * Close file
        JSR     CLSFILE
        
*       * Set as current file
        LDAA     #1
        STAA     FOPEN
        
        CLR     DIRTY      * File is now saved
        
        CLRA               * Success
        RTS

SAVNERR
        LDAA     #1              * Error
        RTS

* Create a new file for writing
CRTNEW
*       * Set up FCB
        JSR     STPFCB
        BNE     CRTERR
        
*       * Set function code for create/write
        LDAA     #FMSWRIT
        STAA     FILEFCB
        
*       * Call FMS to create file
        LDX     #FILEFCB
        JSR     FMS
        BNE     CRTERR    * File might already exist
        
*       * Set binary mode
        LDAA     #$FF
        STAA     FILEFCB+59
        
        LDAA     #1
        STAA     FOPEN
        
        CLRA               * Success
        RTS

CRTERR
        CLR     FOPEN
        LDAA     #1              * Error
        RTS

* Prompt user for filename (simplified version)
PRMPFN
*       * For now, just use a default "NEW.TXT"
*       * TODO: Implement actual user input
        
        LDX     #FILENAME       * Set destination pointer
        STX     YP              * YP = dest (FILENAME)
        LDX     #NEWFNAM        * X = source (new filename)

CPYNEW
        LDAA    0,X             * Get source character
        INX
        STX     TMPX            * Save source pointer
        LDX     YP              * Load dest pointer
        STAA    0,X             * Store to dest
        INX
        STX     YP              * Update dest pointer
        LDX     TMPX            * Restore source pointer
        TSTA                    * Test character
        BNE     CPYNEW
        CLRA                    * Success
        RTS

* Create backup copy of file before modifying
CRTBAK
        TST     FOPEN
        BEQ     NOBAK
        
*       * TODO: Implement backup functionality
*       * Copy current file to .BAK extension
        
NOBAK
        CLRA               * Success for now
        RTS

* =============================================================================
* Text Editing Functions  
* =============================================================================

* Insert character at current buffer position
* INSCH
* Purpose: Insert one char at BUFPOS
* Input: A = char, BUFPOS/BUFEND
* Output: buffer shifted, BUFPOS/CSRBPOS/BUFEND updated
INSCH
*       * Check buffer space
        LDX     BUFEND
        CPX     #TXTBUF+BUFSZ-1
        BHS     INSFUL     * Buffer full
        
*       * Get current position in buffer
        LDX     BUFPOS
        
*       * Shift text right to make room
        JSR     SHFTRGT
        BNE     INSERR
        
*       * Insert character at current position
        STAA     ,X
        INX
        STX     BUFPOS
        STX     CSRBPOS
        
*       * Update buffer end pointer
        LDX     BUFEND
        INX
        STX     BUFEND
        
*       * Mark buffer as dirty
        JSR     MKDIRTY
        
        CLRA               * Success
        RTS

INSFUL
INSERR
        LDAA     #1              * Error
        RTS

* Delete character at cursor position
* DELCH
* Purpose: Delete char at BUFPOS
* Input: BUFPOS/BUFEND
* Output: buffer shifted left, BUFEND adjusted
DELCH
*       * Get current position
        LDX     BUFPOS
        
*       * Check if at end of buffer
        CPX     BUFEND
        BHS     DELDONE     * Nothing to delete
        
*       * Shift text left to close gap
        JSR     SHFTLFT
        
*       * Update buffer end pointer
        LDX     BUFEND
        DEX
        STX     BUFEND
        
*       * Mark buffer as dirty
        JSR     MKDIRTY
        
DELDONE
        LDX     BUFPOS
        STX     CSRBPOS
        CLRA               * Success
        RTS

* Shift text right from current position (for insertion)
* Since dest = source+1, use INX/DEX trick to avoid needing Y
SHFTRGT
        LDX     BUFEND          * Start from end (inclusive)

SHFTRLP
        CPX     BUFPOS          * Check if at insertion point
        BLO     SHFTRDN
        LDAA    0,X             * Get character at source (X)
        INX                     * Temporarily advance to dest (X+1)
        STAA    0,X             * Store to dest
        DEX                     * Back to source
        DEX                     * Move to previous source position
        BRA     SHFTRLP

SHFTRDN
        CLRA                    * Success
        RTS

* Shift text left from current position (for deletion)
* Since source = dest+1, use 1,X for source and 0,X for dest
SHFTLFT
        LDX     BUFPOS          * X = dest start (insertion point)

SHFTLLP
*       * Source is at X+1, dest is at X
        LDAA    1,X             * Get from source (X+1)
        STAA    0,X             * Store to dest (X)
        INX                     * Advance to next pair
        CPX     BUFEND          * Past end of buffer?
        BLO     SHFTLLP         * Continue if not

SHFTLDN
        CLRA                    * Success
        RTS

* Mark buffer as modified
MKDIRTY
        LDAA     #1
        STAA     DIRTY
        RTS

* Insert a new line at cursor position
* INSNL
* Purpose: Insert CR newline at BUFPOS
* Input: BUFPOS/LNTOTAL
* Output: newline inserted, LNTOTAL incremented
INSNL
        LDAA     #CR             * Carriage return
        JSR     INSCH
        BNE     NLERR
        
*       * Update line count
        LDX     LNTOTAL
        INX
        STX     LNTOTAL
        
        CLRA               * Success
        RTS

NLERR
        LDAA     #1              * Error
        RTS

* Find start of current line
FNDLNS
        LDX     BUFPOS
        
LNSLPFND
*       * Check if at beginning of buffer
        CPX     #TXTBUF
        BEQ     LNSOKFND
        
*       * Check previous character for CR
        DEX
        LDAA     ,X
        CMPA     #CR
        BEQ     FNDLNACR
        
        BRA     LNSLPFND

FNDLNACR
        INX                     * Move to character after CR
        
LNSOKFND
        STX     LNSTART
        RTS

* Find end of current line  
FNDLNE
        LDX     BUFPOS
        
LNELPFND
*       * Check if at end of buffer
        CPX     BUFEND
        BHS     LNEOKFND
        
*       * Check for CR
        LDAA     ,X
        CMPA     #CR
        BEQ     LNEOKFND
        
        INX
        BRA     LNELPFND

LNEOKFND
        STX     BUFPOS      * Update position to end of line
        RTS

NEWFNAM
        FCC     "NEW.TXT"
        FCB     0

****************************************
*       END     START
****************************************

        END     START

        
