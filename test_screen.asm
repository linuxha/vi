; Test program for VI screen control functions
; This will test the basic VT100 escape sequences

;* =============================================================================
;* I/O Interface (Flex System Calls)
;* =============================================================================

;* VT100 Control Sequences
ESC     EQU     $1B             ;* Escape character
LF      EQU     $0A             ;* Line Feed
CR      EQU     $0D             ;* Carriage Return
SPACE   EQU     $20             ;* Space character

;* Flex DOS System Call Addresses
GETCHAR EQU     $AD15           ;* Get character from keyboard
PUTCHAR EQU     $AD18           ;* Put character to terminal
PCRLF   EQU     $AD24           ;* Print CR/LF
WARMS   EQU     $AD03           ;* Warm start (exit to FLEX)
GETFIL  EQU     $AD2D           ;* Get file specification
SETEXT  EQU     $AD33           ;* Set default file extension

;* Screen defaults (will be read from Flex environment)
DEFROWS EQU    24               ;* Default screen rows
DEFCOLS EQU    80               ;* Default screen columns

;* ============================================================================= ;
;* Variable Storage Area
;* =============================================================================

SCRROWS RMB  1                  ;* Current screen rows
SCRCOLS RMB  1                  ;* Current screen columns
CSRROW  RMB  1                  ;* Current cursor row (1-based)
CSRCOL  RMB  1                  ;* Current cursor column (1-based)
EDMODE  RMB  1                  ;* Current editor mode
DIRTY   RMB  1                  ;* File modified flag

;* Screen display variables  
TOPLINE  RMB  2                 ;* First line displayed on screen
CURRLINE RMB  2                 ;* Current line number (1-based)
LNTOTAL  RMB  2                 ;* Total lines in buffer

;* Cursor and navigation variables
CSRBPOS RMB  2                ;* Current position in text buffer
LASTCOL RMB  1                ;* Remember column for vertical movement
YANKBUF RMB  256              ;* Buffer for copy/paste operations
YANKSZ  RMB  1                ;* Size of yanked content

;* Temporary registers (6800 has only one index register X)
YP      RMB  2               ;* Secondary index pointer (Y simulation)
TMPX    RMB  2               ;* Temporary X storage
TMPY    RMB  2               ;* Temporary secondary storage
DLEN    RMB  1               ;* Computed range length
MTMP    RMB  2               ;*

;****************************************
        ORG     $0200           ; Different location for testing

; Include the screen control routines from vi.asm
; (In a real assembler, we'd use includes)

; Test sequence
TEST_START
        JSR     TEST_CLEAR      ; Test screen clearing
        JSR     TEST_CORNERS    ; Test corner positioning
        JSR     TEST_MIDDLE     ; Test middle positioning
        JSR     WAIT_KEY        ; Wait for keypress
        RTS

TEST_CLEAR
        JSR     CLEAR_SCREEN
        
        ; Display test message
        LDX     #MSG_CLEAR
        JSR     PRINT_STRING
        
        JSR     DELAY           ; Brief pause
        RTS

TEST_CORNERS
        ; Test all four corners
        JSR     GOTO_HOME
        LDX     #MSG_HOME
        JSR     PRINT_STRING
        JSR     DELAY
        
        JSR     GOTO_TOP_RIGHT  
        LDX     #MSG_TOP_RIGHT
        JSR     PRINT_STRING
        JSR     DELAY
        
        JSR     GOTO_BOTTOM_LEFT
        LDX     #MSG_BOT_LEFT  
        JSR     PRINT_STRING
        JSR     DELAY
        
        JSR     GOTO_BOTTOM_RIGHT
        LDX     #MSG_BOT_RIGHT
        JSR     PRINT_STRING
        JSR     DELAY
        
        RTS

TEST_MIDDLE
        JSR     GOTO_MIDDLE
        LDX     #MSG_MIDDLE
        JSR     PRINT_STRING
        RTS

; Print null-terminated string pointed to by X
PRINT_STRING
        LDA     ,X              ; Get character and increment pointer
        INX
        BEQ     PRINT_DONE      ; If null, we're done
        JSR     PUTCHAR         ; Output character
        BRA     PRINT_STRING    ; Continue
PRINT_DONE
        RTS

; Simple delay routine
DELAY
        LDX     #$1000          ; Delay counter
DELAY_LOOP
        DEX
        BNE     DELAY_LOOP
        RTS

; Wait for keypress
WAIT_KEY
        JSR     GETCHAR
        RTS

; Test messages
MSG_CLEAR   FCB "Screen cleared",0
MSG_HOME    FCB "HOME",0
MSG_TOP_RIGHT FCB "TOP-R",0  
MSG_BOT_LEFT  FCB "BOT-L",0
MSG_BOT_RIGHT FCB "BOT-R",0
MSG_MIDDLE    FCB "CENTER",0

;* =============================================================================
;* Screen Control Functions
;* =============================================================================

;* Clear entire screen and position cursor at home
CLEAR_SCREEN
CLRSCR
;*       ;* Send ESC[2J (clear entire screen)
        LDAA     #ESC
        JSR     PUTCHAR
        LDAA     #'['
        JSR     PUTCHAR
        LDAA     #'2'
        JSR     PUTCHAR
        LDAA     #'J'
        JSR     PUTCHAR
        
;*       ;* Send ESC[H (cursor home)
        LDAA     #ESC
        JSR     PUTCHAR
        LDAA     #'['
        JSR     PUTCHAR
        LDAA     #'H'
        JSR     PUTCHAR
        
        RTS

;* Position cursor at home (1,1)
GOTO_HOME
        LDAA     #1
        STAA     CSRROW
        STAA     CSRCOL
        JSR     POSCSR
        RTS

;* Position cursor at middle of screen
GOTO_MIDDLE
        LDAA     SCRROWS
        LSR     A               ;* Divide by 2
        STAA     CSRROW
        
        LDAA     SCRCOLS
        LSR     A               ;* Divide by 2  
        STAA     CSRCOL
        
        JSR     POSCSR
        RTS

;* Position cursor at bottom left
GOTO_BOTTOM_LEFT
        LDAA     SCRROWS
        STAA     CSRROW
        LDAA     #1
        STAA     CSRCOL
        JSR     POSCSR
        RTS

;* Position cursor at top right
GOTO_TOP_RIGHT
        LDAA     #1
        STAA     CSRROW
        LDAA     SCRCOLS
        STAA     CSRCOL
        JSR     POSCSR
        RTS

;* Position cursor at bottom right
GOTO_BOTTOM_RIGHT
        LDAA     SCRROWS
        STAA     CSRROW
        LDAA     SCRCOLS
        STAA     CSRCOL
        JSR     POSCSR
        RTS

;* Position cursor at current CSRROW, CSRCOL
;* Uses VT100 ESC[row;colH sequence
POSCSR
;*       ;* Send ESC[
        LDAA     #ESC
        JSR     PUTCHAR
        LDAA    #'['
        JSR     PUTCHAR
        
;*       ;* Send row number
        LDAA    CSRROW
        JSR     PUTDEC
        
;*       ;* Send semicolon
        LDAA    #';'
        JSR     PUTCHAR
        
;*       ;* Send column number
        LDAA    CSRCOL
        JSR     PUTDEC
        
;*       ;* Send H
        LDAA    #'H'
        JSR     PUTCHAR
        
        RTS

;* =============================================================================
;* Screen Size Detection
;* =============================================================================

;* Get screen size from Flex environment
;* Check if we can detect actual terminal size, otherwise use defaults
GETSCSZ
;*       ;* For now, try to detect common terminal sizes
;*       ;* Later we can enhance this with actual Flex environment calls
        
;*       ;* TODO: Add actual Flex terminal size detection
;*       ;* For now, assume standard VT100 terminal
        LDAA     #DEFROWS
        STAA     SCRROWS
        LDAA     #DEFCOLS  
        STAA     SCRCOLS
        
;*       ;* Could add environment variable checks here:
;*       ;* Check for LINES and COLUMNS environment variables
;*       ;* Or use VT100 Device Status Report (DSR) sequences
        
        RTS
;* =============================================================================
;* Utility Functions
;* =============================================================================

;* Output decimal number in A register (1-99 range for cursor positioning)
PUTDEC
        CMPA    #10
        BLO     PUTSING         ;* Less than 10, single digit
        
;*       ;* Two digits - use B as tens character counter
        LDAB    #'0'            ;* Start with ASCII '0
PUTTENS
        CMPA    #10
        BLO     PTENSDN         ;* Less than 10, we're done
        SUBA    #10             ;* Subtract 10
        INCB                    ;* Increment tens digit
        BRA     PUTTENS         ;* Continue
        
PTENSDN
        PSHA                    ;* Save ones digit
        TBA                     ;* Move tens digit to A
        JSR     PUTCHAR         ;* Output tens digit
        PULA                    ;* Restore ones digit
        
PUTSING
        ADDA    #'0'            ;* Convert to ASCII
        JSR     PUTCHAR         ;* Output ones digit
        RTS

;****************************************
        END     TEST_START
