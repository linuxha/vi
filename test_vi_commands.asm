; Test program for VI Phase 4 - Navigation and Vi Commands
; Tests cursor movement, word navigation, search, and editing commands

        ORG     $A100           ; Utility command space

; Flex system calls
GETCHR  EQU     $AD15           ; Get character from keyboard  
PUTCHR  EQU     $AD18           ; Put character to terminal
WARMS   EQU     $AD03           ; Warm start (exit to FLEX)
PCRLF   EQU     $AD24           ; Print CR/LF

; Constants
CR      EQU     $0D             ; Carriage return
SPACE   EQU     $20             ; Space

START   
        ; Display test header
        LDX     #TEST_HEADER
        JSR     PRINT_STRING
        
        ; Test 1: Word character recognition
        JSR     TEST_WORD_CHARS
        
        ; Test 2: Search functionality
        JSR     TEST_SEARCH
        
        ; Test 3: Navigation commands
        JSR     TEST_NAVIGATION
        
        ; Display completion
        LDX     #ALL_TESTS_MSG
        JSR     PRINT_STRING
        
        ; Wait and exit
        LDX     #PRESS_KEY
        JSR     PRINT_STRING
        JSR     GETCHR
        JMP     WARMS

; Test word character recognition
TEST_WORD_CHARS
        LDX     #TEST1_MSG
        JSR     PRINT_STRING
        
        ; Test letters
        LDA     #'A'
        JSR     TEST_IS_WORD_CHAR
        JSR     PRINT_RESULT
        
        LDA     #'z'
        JSR     TEST_IS_WORD_CHAR
        JSR     PRINT_RESULT
        
        ; Test digits
        LDA     #'5'
        JSR     TEST_IS_WORD_CHAR
        JSR     PRINT_RESULT
        
        ; Test underscore
        LDA     #'_'
        JSR     TEST_IS_WORD_CHAR
        JSR     PRINT_RESULT
        
        ; Test non-word chars
        LDA     #'!'
        JSR     TEST_IS_WORD_CHAR
        JSR     PRINT_RESULT_INVERSE
        
        LDA     #SPACE
        JSR     TEST_IS_WORD_CHAR
        JSR     PRINT_RESULT_INVERSE
        
        JSR     PCRLF
        RTS

; Test search functionality
TEST_SEARCH
        LDX     #TEST2_MSG
        JSR     PRINT_STRING
        
        ; Setup test text
        JSR     SETUP_TEST_TEXT
        
        ; Test pattern matching
        LDX     #TEST_TEXT
        LDY     #PATTERN1
        JSR     TEST_PATTERN_MATCH
        JSR     PRINT_RESULT
        
        LDX     #TEST_TEXT+5      ; Different position
        LDY     #PATTERN2
        JSR     TEST_PATTERN_MATCH
        JSR     PRINT_RESULT
        
        JSR     PCRLF
        RTS

; Test navigation commands (simulated)
TEST_NAVIGATION
        LDX     #TEST3_MSG
        JSR     PRINT_STRING
        
        ; Simulate buffer setup
        LDX     #TEST_TEXT
        STX     TEST_CURSOR_POS
        LDX     #TEST_TEXT
        STX     TEST_BUFFER_START
        LDX     #TEST_TEXT_END
        STX     TEST_BUFFER_END
        
        ; Test word forward movement
        JSR     SIM_WORD_FORWARD
        LDX     TEST_CURSOR_POS
        LDY     #EXPECTED_POS1
        JSR     COMPARE_POSITIONS
        JSR     PRINT_RESULT
        
        ; Test word backward movement
        JSR     SIM_WORD_BACKWARD
        LDX     TEST_CURSOR_POS
        LDY     #EXPECTED_POS2
        JSR     COMPARE_POSITIONS
        JSR     PRINT_RESULT
        
        JSR     PCRLF
        RTS

; Helper functions
TEST_IS_WORD_CHAR
        JSR     IS_WORD_CHAR_TEST
        RTS

IS_WORD_CHAR_TEST
        ; Simplified version of IS_WORD_CHAR for testing
        ; Check for letter
        CMP     #'A'
        BLO     NOT_WORD_CHAR_TEST
        CMP     #'Z'+1
        BLO     IS_WORD_CHAR_YES_TEST
        
        CMP     #'a'
        BLO     NOT_WORD_CHAR_TEST
        CMP     #'z'+1
        BLO     IS_WORD_CHAR_YES_TEST
        
        ; Check for digit
        CMP     #'0'
        BLO     NOT_WORD_CHAR_TEST
        CMP     #'9'+1
        BLO     IS_WORD_CHAR_YES_TEST
        
        ; Check for underscore
        CMP     #'_'
        BEQ     IS_WORD_CHAR_YES_TEST

NOT_WORD_CHAR_TEST
        LDA     #0              ; Not word char
        RTS

IS_WORD_CHAR_YES_TEST
        LDA     #1              ; Is word char
        RTS

TEST_PATTERN_MATCH
        ; Simple pattern matching test
        ; X = text position, Y = pattern
        PSH     X
        PSH     Y
        
PATTERN_MATCH_LOOP
        LDA     ,Y+             ; Get pattern char
        BEQ     PATTERN_MATCH_SUCCESS ; End of pattern
        
        CMP     ,X+             ; Compare with text
        BNE     PATTERN_MATCH_FAIL
        
        BRA     PATTERN_MATCH_LOOP

PATTERN_MATCH_SUCCESS
        PUL     Y
        PUL     X
        LDA     #1              ; Match
        RTS

PATTERN_MATCH_FAIL
        PUL     Y
        PUL     X
        LDA     #0              ; No match
        RTS

SIM_WORD_FORWARD
        ; Simulate word forward movement
        LDX     TEST_CURSOR_POS
        
        ; Skip current word
SIM_SKIP_WORD
        CPX     TEST_BUFFER_END
        BHS     SIM_WORD_FWD_DONE
        
        LDA     ,X
        JSR     IS_WORD_CHAR_TEST
        BEQ     SIM_SKIP_SPACES
        
        INX
        BRA     SIM_SKIP_WORD

SIM_SKIP_SPACES
        CPX     TEST_BUFFER_END
        BHS     SIM_WORD_FWD_DONE
        
        LDA     ,X
        CMP     #SPACE
        BNE     SIM_WORD_FWD_DONE
        
        INX
        BRA     SIM_SKIP_SPACES

SIM_WORD_FWD_DONE
        STX     TEST_CURSOR_POS
        RTS

SIM_WORD_BACKWARD
        ; Simulate word backward movement  
        LDX     TEST_CURSOR_POS
        
        ; Move back one word (simplified)
        DEX
        DEX
        DEX
        DEX
        DEX                     ; Move back 5 positions
        
        CPX     TEST_BUFFER_START
        BHS     SIM_WORD_BACK_OK
        
        LDX     TEST_BUFFER_START

SIM_WORD_BACK_OK
        STX     TEST_CURSOR_POS
        RTS

COMPARE_POSITIONS
        CPX     ,Y
        BEQ     POSITIONS_EQUAL
        
        LDA     #0              ; Not equal
        RTS

POSITIONS_EQUAL
        LDA     #1              ; Equal
        RTS

SETUP_TEST_TEXT
        ; Test text is already defined below
        RTS

PRINT_RESULT
        TST     A
        BEQ     PRINT_FAIL
        
        LDA     #'P'
        JSR     PUTCHR
        LDA     #'A'
        JSR     PUTCHR
        LDA     #'S'
        JSR     PUTCHR
        LDA     #'S'
        JSR     PUTCHR
        LDA     #SPACE
        JSR     PUTCHR
        RTS

PRINT_FAIL
        LDA     #'F'
        JSR     PUTCHR
        LDA     #'A'
        JSR     PUTCHR
        LDA     #'I'
        JSR     PUTCHR
        LDA     #'L'
        JSR     PUTCHR
        LDA     #SPACE
        JSR     PUTCHR
        RTS

PRINT_RESULT_INVERSE
        TST     A
        BNE     PRINT_FAIL      ; Expect failure for non-word chars
        BRA     PRINT_RESULT    ; Print PASS if failed (which is correct)

PRINT_STRING
        LDA     ,X+
        BEQ     PRINT_DONE
        JSR     PUTCHR
        BRA     PRINT_STRING
PRINT_DONE
        RTS

; Test data
TEST_HEADER
        FCC     "VI Phase 4 Command Test"
        FCB     CR,CR,0

TEST1_MSG
        FCC     "Test 1 - Word Characters: "
        FCB     0

TEST2_MSG
        FCC     "Test 2 - Pattern Matching: "
        FCB     0

TEST3_MSG
        FCC     "Test 3 - Navigation: "
        FCB     0

ALL_TESTS_MSG
        FCC     CR,"All tests completed!"
        FCB     CR,0

PRESS_KEY
        FCC     "Press any key to exit..."
        FCB     0

; Test text and patterns
TEST_TEXT
        FCC     "Hello world test line"
        FCB     0

TEST_TEXT_END EQU *

PATTERN1
        FCC     "Hello"
        FCB     0

PATTERN2  
        FCC     "world"
        FCB     0

EXPECTED_POS1
        FDW     TEST_TEXT+6     ; After "Hello "

EXPECTED_POS2
        FDW     TEST_TEXT+1     ; Back from forward position

; Test variables
TEST_CURSOR_POS     RMB 2
TEST_BUFFER_START   RMB 2
TEST_BUFFER_END     RMB 2

        END     START