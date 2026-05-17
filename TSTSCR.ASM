* Test program for VI screen control functions
* This will test the basic VT100 escape sequences

* =============================================================================
* I/O Interface (Flex System Calls)
* =============================================================================

*       ADDRESS
ACIACS  EQU     $8004           * Exor serial port 0
ACIADA  EQU     ACIACS+1

* VT100 Control Sequences
ESC     EQU     $1B             * Escape character
LF      EQU     $0A             * Line Feed
CR      EQU     $0D             * Carriage Return
SPACE   EQU     $20             * Space character

* Flex DOS System Call Addresses
GETCHAR EQU     $AD15           * Get character from keyboard
PUTCHR  EQU     $AD18           * Put character to terminal
PCRLF   EQU     $AD24           * Print CR/LF
WARMST  EQU     $AD03           * Warm start (exit to FLEX)
GETFIL  EQU     $AD2D           * Get file specification
SETEXT  EQU     $AD33           * Set default file extension
OUTDEC  EQU     $AD39           * Output Decimanl Number

* Screen defaults (will be read from Flex environment)
DEFROWS EQU    24               * Default screen rows
DEFCOLS EQU    80               * Default screen columns

* =============================================================================
* Variable Storage Area
* =============================================================================
SCRROWS RMB  1                  * Current screen rows
SCRCOLS RMB  1                  * Current screen columns
CSRROW  RMB  1                  * Current cursor row (1-based)
CSRCOL  RMB  1                  * Current cursor column (1-based)
EDMODE  RMB  1                  * Current editor mode
DIRTY   RMB  1                  * File modified flag

* Screen display variables  
TOPLINE  RMB  2                 * First line displayed on screen
CURRLINE RMB  2                 * Current line number (1-based)
LNTOTAL  RMB  2                 * Total lines in buffer

* Cursor and navigation variables
CSRBPOS RMB  2                * Current position in text buffer
LASTCOL RMB  1                * Remember column for vertical movement
YANKBUF RMB  256              * Buffer for copy/paste operations
YANKSZ  RMB  1                * Size of yanked content

* Temporary registers (6800 has only one index register X)
YP      RMB  2               * Secondary index pointer (Y simulation)
TMPX    RMB  2               * Temporary X storage
TMPY    RMB  2               * Temporary secondary storage
DLEN    RMB  1               * Computed range length
MTMP    RMB  2               *
STKBUF  RMB  127
STACK   RMB  1
****************************************
        ORG     $0200           * Different location for testing

MAIN    LDS     #STACK
        JSR     GETSCSZ         * Initialize the default screen size
* Include the screen control routines from vi.asm
* (In a real assembler, we'd use includes)

* Test sequence
TESTSTART
        JSR     TESTCLEAR      * Test screen clearing

        JSR     TESTCORNERS    * Test corner positioning
        JSR     TESTMIDDLE     * Test middle positioning

*       JSR     WAITKEY        * Wait for keypress

        JSR     BOTLEFT
XIT     JSR     PCRLF

        JMP     WARMST         * Exit to Flex

TESTCLEAR
        JSR     CLS
        
*       * Display test message
        LDX     #MSGCLEAR
        JSR     PRINTSTRING
        
        JSR     DELAY           * Brief pause
        RTS

TESTCORNERS
*       * Test all four corners
        JSR     HOME
        LDX     #MSGHOME
        JSR     PRINTSTRING
        JSR     DELAY
        
        JSR     TOPRIGHT  
        LDX     #RTMSGTOP
        JSR     PRINTSTRING
        JSR     DELAY
        
        JSR     BOTLEFT
        LDX     #LFMSGBOT  
        JSR     PRINTSTRING
        JSR     DELAY
        
        JSR     BOTRIGHT
        LDX     #RTMSGBOT
        JSR     PRINTSTRING
        JSR     DELAY
        
        RTS

TESTMIDDLE
*       LDX     #CONTMSG
*       JSR     PRINTSTRING
*       JSR     WAITKEY        * Wait for keypress

        JSR     MIDDLE
        LDX     #MIDMSG
        JSR     PRINTSTRING
        RTS

* Print null-terminated string pointed to by X
PRINTSTRING
        LDAA    ,X              * Get character and increment pointer
        BEQ     PRINTDONE       * If null, we're done
        INX
        JSR     PUTCHAR         * Output character
        BRA     PRINTSTRING     * Continue
*
PRINTDONE
        RTS

* Simple delay routine
DELAY
        LDX     #$1000          * Delay counter
DELAYLOOP
        DEX
        BNE     DELAYLOOP
        RTS

* Wait for keypress
* This routine gets a single character from the keyboard. The
* character is returned to the calling program in the A-register.
WAITKEY
        JSR     GETCHAR
        CMPA    #1
        BLT     WAITKEY
        RTS

* Test messages
MSGCLEAR      FCB 13,10
              FCC "Screen cleared"
              FCB 0
MSGHOME       FCC "HOME"
              FCB 0
RTMSGTOP      FCC "TOP-R"
              FCB 0
LFMSGBOT      FCC "BOT-L"
              FCB 0
RTMSGBOT      FCC "BOT-R"
              FCB 0
MIDMSG        FCC "CENTER"
              FCB 0
CONTMSG       FCB 13,10
              FCC "Press any to continue: "
              FCB 0

* =============================================================================
* Screen Control Functions
* =============================================================================

* Clear entire screen and position cursor at home
CLS
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
        
        RTS

* Position cursor at home (1,1)
* 1x1
HOME
        LDAA    #1
        STAA    CSRROW
        STAA    CSRCOL
        JSR     SCRPOS
        RTS

* Position cursor at middle of screen
* 40x12
MIDDLE
        LDAA    SCRROWS
        LSR     A               * Divide by 2
        STAA    CSRROW
        
        LDAA    SCRCOLS
        LSR     A               * Divide by 2  
        STAA    CSRCOL
        
        JSR     SCRPOS
        RTS

* Position cursor at bottom left
* 1x24
BOTLEFT
        LDAA    SCRROWS
        STAA    CSRROW
        LDAA    #1
        STAA    CSRCOL
        JSR     SCRPOS
        RTS

* Position cursor at top right
* 80x1
TOPRIGHT
        LDAA    #1
        STAA    CSRROW
        LDAA    SCRCOLS
        STAA    CSRCOL
        JSR     SCRPOS
        RTS

* Position cursor at bottom right
* 80x24 (Cols x Rows)
BOTRIGHT
        LDAA    SCRROWS
        STAA    CSRROW
        LDAA    SCRCOLS
        STAA    CSRCOL
        JSR     SCRPOS
        RTS

* Position cursor at current CSRROW, CSRCOL
* Uses VT100 ESC[{row};{col}H sequence
* Where {row} and {col} are value to decimal string
SCRPOS
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
* X points to a value
PUTDEC
        NOP
        CLRB                    * space suppression flag
        CLR     TMPX
        STAA    TMPX+1
        LDX     #TMPX           * X points to 16 bit digit
        JMP     OUTDEC

* Output decimal number in A register (1-99 range for cursor positioning)
xPUTDEC
        NOP
*
        CMPA    #10
*       BLO     PUTSING         * Less than 10, single digit (BCS = 0x25 Carry = 1 , BCS = BLO))
        BCS     PUTSING         * Less than 10, single digit (BCS = 0x25 Carry = 1)
        
*       * Two digits - use B as tens character counter
*       LDAB    #'0             * Start with ASCII '0
        CLRB                    * Start with ASCII '0
PUTTENS
        CMPA    #10
        BLO     PTENSDN         * Less than 10, we're done
        SUBA    #10             * Subtract 10
        INCB                    * Increment tens digit
        BRA     PUTTENS         * Continue
        
PTENSDN
        PSHA                    * Save ones digit
        TBA                     * Move tens digit to A
        CLRB
        ADDA    #'0             * Convert to ASCII
        JSR     PUTCHAR         * Output tens digit
        PULA                    * Restore ones digit
        
PUTSING
        CLRB
        ADDA    #'0             * Convert to ASCII
        JSR     PUTCHAR         * Output ones digit
        RTS

*       OUTPUT ONE CHAR 
PUTCHAR
OUTEE   PSHA                    * Save the character
*
OUTEE1  LDAA    ACIACS          * Check the status
        ASRA
        ASRA
        BCC     OUTEE1          * If not ready then loop until it is
*
        PULA                    * Retore the character
        STAA    ACIADA          * Send it to the Serial Port
        RTS

****************************************
        END     MAIN
