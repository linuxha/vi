; Simple test for VI screen control with Flex I/O
; Test basic VT100 functions and Flex integration

        ORG     $A100           ; Utility command space

; Flex system calls
GETCHR  EQU     $AD15           ; Get character from keyboard  
PUTCHR  EQU     $AD18           ; Put character to terminal
WARMS   EQU     $AD03           ; Warm start (exit to FLEX)

; VT100 Constants
ESC     EQU     $1B             ; Escape character

START   
        JSR     TEST_SCREEN_CTRL
        JMP     WARMS           ; Exit to FLEX

TEST_SCREEN_CTRL
        ; Clear screen
        JSR     CLEAR_SCREEN
        
        ; Test message at home position
        LDX     #MSG_START
        JSR     PRINT_STRING
        
        ; Wait for key
        JSR     WAIT_KEY
        
        ; Test corner positions
        JSR     TEST_CORNERS
        
        ; Wait for key
        JSR     WAIT_KEY
        
        ; Test center position
        JSR     GOTO_MIDDLE
        LDX     #MSG_DONE
        JSR     PRINT_STRING
        
        ; Final wait
        JSR     WAIT_KEY
        
        RTS

TEST_CORNERS
        ; Home position
        JSR     GOTO_HOME
        LDX     #MSG_HOME
        JSR     PRINT_STRING
        JSR     SHORT_DELAY
        
        ; Top right
        JSR     GOTO_TOP_RIGHT
        LDX     #MSG_TOP_RIGHT
        JSR     PRINT_STRING
        JSR     SHORT_DELAY
        
        ; Bottom right  
        JSR     GOTO_BOTTOM_RIGHT
        LDX     #MSG_BOT_RIGHT
        JSR     PRINT_STRING
        JSR     SHORT_DELAY
        
        ; Bottom left
        JSR     GOTO_BOTTOM_LEFT
        LDX     #MSG_BOT_LEFT
        JSR     PRINT_STRING
        
        RTS

; Screen control functions
CLEAR_SCREEN
        LDA     #ESC
        JSR     PUTCHR
        LDA     #'['
        JSR     PUTCHR
        LDA     #'2'
        JSR     PUTCHR
        LDA     #'J'
        JSR     PUTCHR
        
        ; Cursor home
        LDA     #ESC
        JSR     PUTCHR
        LDA     #'['
        JSR     PUTCHR
        LDA     #'H'
        JSR     PUTCHR
        RTS

GOTO_HOME
        LDA     #1
        LDB     #1
        JSR     POSITION_CURSOR
        RTS

GOTO_MIDDLE
        LDA     #12             ; Middle row (assume 24 line screen)
        LDB     #40             ; Middle column (assume 80 col screen)
        JSR     POSITION_CURSOR
        RTS

GOTO_TOP_RIGHT
        LDA     #1              ; Top row
        LDB     #75             ; Near right edge
        JSR     POSITION_CURSOR
        RTS

GOTO_BOTTOM_RIGHT  
        LDA     #24             ; Bottom row
        LDB     #75             ; Near right edge
        JSR     POSITION_CURSOR
        RTS

GOTO_BOTTOM_LEFT
        LDA     #24             ; Bottom row
        LDB     #1              ; Left edge
        JSR     POSITION_CURSOR
        RTS

; Position cursor at row A, column B
POSITION_CURSOR
        PSH     A               ; Save row
        PSH     B               ; Save column
        
        ; Send ESC[
        LDA     #ESC
        JSR     PUTCHR
        LDA     #'['
        JSR     PUTCHR
        
        ; Send row
        PUL     B               ; Get column (will need later)
        PUL     A               ; Get row
        PSH     B               ; Save column again
        JSR     PUT_DECIMAL
        
        ; Send semicolon
        LDA     #';'
        JSR     PUTCHR
        
        ; Send column
        PUL     A               ; Get column
        JSR     PUT_DECIMAL
        
        ; Send H
        LDA     #'H'
        JSR     PUTCHR
        
        RTS

; Print null-terminated string at X
PRINT_STRING
        LDA     ,X+
        BEQ     PRINT_DONE
        JSR     PUTCHR
        BRA     PRINT_STRING
PRINT_DONE
        RTS

; Wait for keypress
WAIT_KEY
        JSR     GETCHR
        RTS

; Short delay
SHORT_DELAY
        LDX     #$0800
DELAY_LOOP
        DEX
        BNE     DELAY_LOOP
        RTS

; Output decimal number (1-99)
PUT_DECIMAL
        CMP     #10
        BLO     PUT_SINGLE
        
        ; Handle tens
        LDB     #'0'
PUT_TENS
        CMP     #10
        BLO     PUT_TENS_DONE
        SUB     #10
        INC     B
        BRA     PUT_TENS
        
PUT_TENS_DONE
        PSH     A
        TFR     B,A
        JSR     PUTCHR
        PUL     A
        
PUT_SINGLE
        ADD     #'0'
        JSR     PUTCHR
        RTS

; Test messages
MSG_START   FCC "VI Screen Test - Press any key"
            FCB 0
MSG_HOME    FCC "HOME"
            FCB 0
MSG_TOP_RIGHT FCC "TOP-R"
            FCB 0
MSG_BOT_RIGHT FCC "BOT-R"  
            FCB 0
MSG_BOT_LEFT  FCC "BOT-L"
            FCB 0
MSG_DONE    FCC "Test Complete - Press any key to exit"
            FCB 0

        END     START