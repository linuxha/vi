; Test program for VI file reading functionality
; Tests Flex FMS integration and text buffer management

        ORG     $A100           ; Utility command space

; Flex system calls
GETCHR  EQU     $AD15           ; Get character from keyboard  
PUTCHR  EQU     $AD18           ; Put character to terminal
WARMS   EQU     $AD03           ; Warm start (exit to FLEX)
PCRLF   EQU     $AD24           ; Print CR/LF

; FMS calls
FMS     EQU     $B406           ; FMS Call entry point

; Constants
CR      EQU     $0D             ; Carriage return
ESC     EQU     $1B             ; Escape

; Test FCB and buffer
FCB_SIZE    EQU 320
TEST_FCB    RMB FCB_SIZE        ; File Control Block
BUFFER_SIZE EQU 1024
TEST_BUFFER RMB BUFFER_SIZE     ; Text buffer

START   
        ; Display test header
        LDX     #TEST_HEADER
        JSR     PRINT_STRING
        
        ; Test 1: Create a simple test file
        JSR     CREATE_TEST_FILE
        BNE     TEST1_ERROR
        
        LDX     #TEST1_OK
        JSR     PRINT_STRING
        
        ; Test 2: Read the test file
        JSR     READ_TEST_FILE
        BNE     TEST2_ERROR
        
        LDX     #TEST2_OK  
        JSR     PRINT_STRING
        
        ; Test 3: Display buffer contents
        JSR     DISPLAY_BUFFER_CONTENTS
        
        ; Wait for keypress and exit
        LDX     #PRESS_KEY
        JSR     PRINT_STRING
        JSR     GETCHR
        
        JMP     WARMS           ; Exit to FLEX

TEST1_ERROR
        LDX     #TEST1_FAIL
        JSR     PRINT_STRING
        JMP     WARMS

TEST2_ERROR
        LDX     #TEST2_FAIL
        JSR     PRINT_STRING
        JMP     WARMS

; Create a simple test file for reading
CREATE_TEST_FILE
        ; Clear FCB
        LDX     #TEST_FCB
        LDA     #0
        LDB     #FCB_SIZE
CLEAR_FCB1
        STA     ,X+
        DECB
        BNE     CLEAR_FCB1
        
        ; Set filename in FCB (TEST.TXT)
        LDA     #'T'
        STA     TEST_FCB+4
        LDA     #'E'
        STA     TEST_FCB+5
        LDA     #'S'
        STA     TEST_FCB+6
        LDA     #'T'
        STA     TEST_FCB+7
        LDA     #'.'
        STA     TEST_FCB+8
        LDA     #'T'
        STA     TEST_FCB+9
        LDA     #'X'
        STA     TEST_FCB+10
        LDA     #'T'
        STA     TEST_FCB+11
        
        ; Open for write (function code 2)
        LDA     #2
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        BNE     CREATE_ERROR
        
        ; Write test content
        LDX     #TEST_CONTENT
WRITE_CHAR
        LDA     ,X+
        BEQ     WRITE_DONE      ; Null terminator
        
        ; Write character (function code 0)
        PSH     X               ; Save string pointer
        PSH     A               ; Save character
        
        LDA     #0              ; Write function
        STA     TEST_FCB
        
        PUL     A               ; Restore character
        LDX     #TEST_FCB
        JSR     FMS
        
        PUL     X               ; Restore string pointer
        BNE     CREATE_ERROR
        
        BRA     WRITE_CHAR

WRITE_DONE
        ; Close file (function code 4)
        LDA     #4
        STA     TEST_FCB
        LDX     #TEST_FCB
        JSR     FMS
        BNE     CREATE_ERROR
        
        CLR     A               ; Success
        RTS

CREATE_ERROR
        LDA     #1              ; Error
        RTS

; Read test file into buffer
READ_TEST_FILE
        ; Clear FCB
        LDX     #TEST_FCB
        LDA     #0
        LDB     #FCB_SIZE
CLEAR_FCB2
        STA     ,X+
        DECB
        BNE     CLEAR_FCB2
        
        ; Set filename in FCB (TEST.TXT) 
        LDA     #'T'
        STA     TEST_FCB+4
        LDA     #'E'
        STA     TEST_FCB+5
        LDA     #'S'
        STA     TEST_FCB+6
        LDA     #'T'
        STA     TEST_FCB+7
        LDA     #'.'
        STA     TEST_FCB+8
        LDA     #'T'
        STA     TEST_FCB+9
        LDA     #'X'
        STA     TEST_FCB+10
        LDA     #'T'
        STA     TEST_FCB+11
        
        ; Open for read (function code 1)
        LDA     #1
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        BNE     READ_ERROR
        
        ; Set binary mode
        LDA     #$FF
        STA     TEST_FCB+59
        
        ; Read characters into buffer
        LDX     #TEST_BUFFER
        
READ_CHAR
        PSH     X               ; Save buffer pointer
        
        LDA     #0              ; Read function
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        
        PUL     X               ; Restore buffer pointer
        BNE     CHECK_EOF       ; Error or EOF
        
        ; Store character in buffer
        STA     ,X+
        
        ; Check buffer bounds
        CPX     #TEST_BUFFER+BUFFER_SIZE-1
        BLO     READ_CHAR
        
        ; Buffer full
        BRA     READ_COMPLETE

CHECK_EOF
        LDA     TEST_FCB+1      ; Error status
        CMP     #8              ; EOF error?
        BNE     READ_ERROR      ; Real error
        
READ_COMPLETE
        ; Null terminate buffer
        CLR     ,X
        
        ; Close file
        LDA     #4
        STA     TEST_FCB
        LDX     #TEST_FCB
        JSR     FMS
        
        CLR     A               ; Success
        RTS

READ_ERROR
        LDA     #1              ; Error
        RTS

; Display buffer contents
DISPLAY_BUFFER_CONTENTS
        JSR     PCRLF
        LDX     #BUFFER_HDR
        JSR     PRINT_STRING
        
        LDX     #TEST_BUFFER
DISP_CHAR
        LDA     ,X+
        BEQ     DISP_DONE
        
        CMP     #CR
        BEQ     DISP_CR
        
        JSR     PUTCHR
        BRA     DISP_CHAR

DISP_CR
        JSR     PCRLF
        BRA     DISP_CHAR

DISP_DONE
        JSR     PCRLF
        RTS

; Print null-terminated string
PRINT_STRING
        LDA     ,X+
        BEQ     PRINT_DONE
        JSR     PUTCHR
        BRA     PRINT_STRING
PRINT_DONE
        RTS

; Test messages and data
TEST_HEADER 
        FCC     "VI File I/O Test Program"
        FCB     CR,CR,0

TEST1_OK
        FCC     "Test 1 PASSED: File creation"
        FCB     CR,0

TEST1_FAIL
        FCC     "Test 1 FAILED: File creation"
        FCB     CR,0

TEST2_OK
        FCC     "Test 2 PASSED: File reading"
        FCB     CR,0

TEST2_FAIL
        FCC     "Test 2 FAILED: File reading"
        FCB     CR,0

BUFFER_HDR
        FCC     "Buffer Contents:"
        FCB     CR,0

PRESS_KEY
        FCC     "Press any key to exit..."
        FCB     0

TEST_CONTENT
        FCC     "Hello, World!"
        FCB     CR
        FCC     "This is a test file for VI."
        FCB     CR
        FCC     "Line 3 of the test file."
        FCB     CR
        FCC     "End of test content."
        FCB     CR
        FCB     0

        END     START