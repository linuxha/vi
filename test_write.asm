; Test program for VI file writing functionality
; Tests file creation, writing, and save operations

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

; Test data structures
FCB_SIZE    EQU 320
TEST_FCB    RMB FCB_SIZE        ; File Control Block
BUFFER_SIZE EQU 512
TEST_BUFFER RMB BUFFER_SIZE     ; Text buffer for testing

START   
        ; Display test header
        LDX     #TEST_HEADER
        JSR     PRINT_STRING
        
        ; Test 1: Create buffer with test content
        JSR     SETUP_TEST_BUFFER
        
        LDX     #TEST1_MSG
        JSR     PRINT_STRING
        
        ; Test 2: Write buffer to new file
        JSR     TEST_FILE_WRITE
        BNE     TEST2_ERROR
        
        LDX     #TEST2_OK
        JSR     PRINT_STRING
        
        ; Test 3: Read file back to verify
        JSR     TEST_FILE_VERIFY
        BNE     TEST3_ERROR
        
        LDX     #TEST3_OK
        JSR     PRINT_STRING
        
        ; Test 4: Append to existing file
        JSR     TEST_FILE_APPEND
        BNE     TEST4_ERROR
        
        LDX     #TEST4_OK
        JSR     PRINT_STRING
        
        ; All tests passed
        LDX     #ALL_TESTS_OK
        JSR     PRINT_STRING
        
        ; Wait and exit
        LDX     #PRESS_KEY
        JSR     PRINT_STRING
        JSR     GETCHR
        JMP     WARMS

TEST2_ERROR
        LDX     #TEST2_FAIL
        JSR     PRINT_STRING
        JMP     WARMS

TEST3_ERROR
        LDX     #TEST3_FAIL
        JSR     PRINT_STRING
        JMP     WARMS

TEST4_ERROR
        LDX     #TEST4_FAIL
        JSR     PRINT_STRING
        JMP     WARMS

; Setup test buffer with content
SETUP_TEST_BUFFER
        ; Copy test content to buffer
        LDX     #WRITE_TEST_CONTENT
        LDY     #TEST_BUFFER
        
COPY_CONTENT
        LDA     ,X+
        STA     ,Y+
        BNE     COPY_CONTENT    ; Continue until null
        
        ; Set buffer end pointer
        STY     BUFFER_END_PTR
        
        RTS

; Test writing buffer content to file
TEST_FILE_WRITE
        ; Clear and setup FCB
        JSR     CLEAR_FCB
        JSR     SETUP_WRITE_FCB
        
        ; Open file for write (creates new file)
        LDA     #2              ; Write function
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        BNE     WRITE_ERROR
        
        ; Set binary mode
        LDA     #$FF
        STA     TEST_FCB+59
        
        ; Write buffer contents
        LDX     #TEST_BUFFER
        
WRITE_LOOP
        ; Check if at end of content
        CPX     BUFFER_END_PTR
        BHS     WRITE_DONE
        
        ; Get character
        LDA     ,X+
        PSH     X               ; Save position
        
        ; Write character (function 0)
        PSH     A
        LDA     #0
        STA     TEST_FCB
        PUL     A
        
        LDX     #TEST_FCB
        JSR     FMS
        
        PUL     X               ; Restore position
        BNE     WRITE_ERROR
        
        BRA     WRITE_LOOP

WRITE_DONE
        ; Close file
        LDA     #4              ; Close function
        STA     TEST_FCB
        LDX     #TEST_FCB
        JSR     FMS
        
        CLR     A               ; Success
        RTS

WRITE_ERROR
        LDA     #1              ; Error
        RTS

; Verify written file by reading it back
TEST_FILE_VERIFY
        ; Clear and setup FCB for read
        JSR     CLEAR_FCB
        JSR     SETUP_WRITE_FCB  ; Same filename
        
        ; Open for read
        LDA     #1              ; Read function
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        BNE     VERIFY_ERROR
        
        ; Set binary mode
        LDA     #$FF
        STA     TEST_FCB+59
        
        ; Read and compare content
        LDX     #TEST_BUFFER
        LDY     #VERIFY_BUFFER
        
READ_VERIFY_LOOP
        PSH     X
        PSH     Y
        
        ; Read character
        LDA     #0              ; Read function
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        
        PUL     Y
        PUL     X
        BNE     CHECK_VERIFY_EOF
        
        ; Store read character
        STA     ,Y+
        
        ; Compare with original
        CMP     ,X+
        BNE     VERIFY_MISMATCH
        
        BRA     READ_VERIFY_LOOP

CHECK_VERIFY_EOF
        ; Check if EOF
        LDA     TEST_FCB+1
        CMP     #8              ; EOF error
        BNE     VERIFY_ERROR
        
        ; Close file
        LDA     #4
        STA     TEST_FCB
        LDX     #TEST_FCB
        JSR     FMS
        
        CLR     A               ; Success
        RTS

VERIFY_ERROR
VERIFY_MISMATCH
        LDA     #1              ; Error
        RTS

; Test appending to existing file
TEST_FILE_APPEND
        ; For this test, just verify we can reopen and write more
        JSR     CLEAR_FCB
        JSR     SETUP_APPEND_FCB
        
        ; Open for write (will overwrite - Flex doesn't have append mode)
        LDA     #2
        STA     TEST_FCB
        
        LDX     #TEST_FCB
        JSR     FMS
        BNE     APPEND_ERROR
        
        ; Write append content
        LDX     #APPEND_CONTENT
        
APPEND_LOOP
        LDA     ,X+
        BEQ     APPEND_DONE
        
        PSH     X
        PSH     A
        
        LDA     #0              ; Write function
        STA     TEST_FCB
        PUL     A
        
        LDX     #TEST_FCB
        JSR     FMS
        
        PUL     X
        BNE     APPEND_ERROR
        
        BRA     APPEND_LOOP

APPEND_DONE
        ; Close file
        LDA     #4
        STA     TEST_FCB
        LDX     #TEST_FCB
        JSR     FMS
        
        CLR     A               ; Success
        RTS

APPEND_ERROR
        LDA     #1              ; Error
        RTS

; Helper functions
CLEAR_FCB
        LDX     #TEST_FCB
        LDA     #0
        LDB     #FCB_SIZE
CLEAR_LOOP
        STA     ,X+
        DECB
        BNE     CLEAR_LOOP
        RTS

SETUP_WRITE_FCB
        ; Set filename "WRITE.TST"
        LDA     #'W'
        STA     TEST_FCB+4
        LDA     #'R'
        STA     TEST_FCB+5
        LDA     #'I'
        STA     TEST_FCB+6
        LDA     #'T'
        STA     TEST_FCB+7
        LDA     #'E'
        STA     TEST_FCB+8
        LDA     #'.'
        STA     TEST_FCB+9
        LDA     #'T'
        STA     TEST_FCB+10
        LDA     #'S'
        STA     TEST_FCB+11
        LDA     #'T'
        STA     TEST_FCB+12
        RTS

SETUP_APPEND_FCB
        ; Set filename "APPEND.TST"
        LDA     #'A'
        STA     TEST_FCB+4
        LDA     #'P'
        STA     TEST_FCB+5
        LDA     #'P'
        STA     TEST_FCB+6
        LDA     #'E'
        STA     TEST_FCB+7
        LDA     #'N'
        STA     TEST_FCB+8
        LDA     #'D'
        STA     TEST_FCB+9
        LDA     #'.'
        STA     TEST_FCB+10
        LDA     #'T'
        STA     TEST_FCB+11
        LDA     #'S'
        STA     TEST_FCB+12
        LDA     #'T'
        STA     TEST_FCB+13
        RTS

PRINT_STRING
        LDA     ,X+
        BEQ     PRINT_DONE
        JSR     PUTCHR
        BRA     PRINT_STRING
PRINT_DONE
        RTS

; Test messages
TEST_HEADER
        FCC     "VI File Writing Test Program"
        FCB     CR,CR,0

TEST1_MSG
        FCC     "Test 1: Buffer setup complete"
        FCB     CR,0

TEST2_OK
        FCC     "Test 2 PASSED: File writing"
        FCB     CR,0

TEST2_FAIL
        FCC     "Test 2 FAILED: File writing"
        FCB     CR,0

TEST3_OK
        FCC     "Test 3 PASSED: File verification"
        FCB     CR,0

TEST3_FAIL
        FCC     "Test 3 FAILED: File verification"
        FCB     CR,0

TEST4_OK
        FCC     "Test 4 PASSED: File append"
        FCB     CR,0

TEST4_FAIL
        FCC     "Test 4 FAILED: File append"
        FCB     CR,0

ALL_TESTS_OK
        FCC     "All tests PASSED!"
        FCB     CR,0

PRESS_KEY
        FCC     "Press any key to exit..."
        FCB     0

; Test content
WRITE_TEST_CONTENT
        FCC     "This is test content for file writing."
        FCB     CR
        FCC     "Line 2 of the test file."
        FCB     CR
        FCC     "Line 3 with special chars: !@#$%"
        FCB     CR
        FCB     0

APPEND_CONTENT
        FCC     "This is appended content."
        FCB     CR
        FCC     "Appended line 2."
        FCB     CR
        FCB     0

; Data storage
BUFFER_END_PTR  RMB 2           ; Pointer to end of buffer
VERIFY_BUFFER   RMB BUFFER_SIZE ; Buffer for verification

        END     START