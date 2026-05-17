#!/usr/bin/env python3
"""
Fix all remaining invalid MC6800 mnemonics in vi.asm:
- Replace ,X+ (post-increment) with 0,X + INX
- Replace ,Y+ with YP-based sequences
- Replace ,-X / ,-Y with DEX/DEY + 0,X sequences
- Replace LDY/INY/STY with YP-based sequences
- Replace PSH X / PUL X with STX/LDX TMPX
- Replace PSH X,X / PUL X,X
- Replace TFR Y,X, SUB Y,X, TFR X,B, SUB D,X, AB Y
- Rewrite MATCHPAT, YANKRNG, DELRNG, INSYANK, MKROOM
- Rewrite SHFTRGT, SHFTLFT
- Rewrite CPYFNAM, CPTOFCB, CPYNEW
- Fix WRTCLP, ADDCBUF, CLRFCB, STAA/LDAA ,X+ patterns
"""

REPLACEMENTS = [

    # =========================================================================
    # FNDNCR: ,X+ -> 0,X + INX
    # =========================================================================
    (
        "        ; Look for CR\n"
        "        LDAA     ,X+\n"
        "        CMPA     #CR\n"
        "        BNE     FNDNCR",

        "        ; Look for CR\n"
        "        LDAA    0,X             ; Get character\n"
        "        INX                     ; Advance pointer\n"
        "        CMPA    #CR\n"
        "        BNE     FNDNCR"
    ),

    # =========================================================================
    # GETSRCH CLRPAT: STAA ,X+ -> 0,X + INX
    # =========================================================================
    (
        "CLRPAT\n"
        "        STAA     ,X+\n"
        "        DECB\n"
        "        BNE     CLRPAT",

        "CLRPAT\n"
        "        STAA    0,X             ; Store zero\n"
        "        INX                     ; Advance pointer\n"
        "        DECB\n"
        "        BNE     CLRPAT"
    ),

    # =========================================================================
    # GETPLP: STAA ,X+ -> 0,X + INX
    # =========================================================================
    (
        "        STAA     ,X+             ; Store character\n"
        "        INCB                     ; Increment length",

        "        STAA    0,X             ; Store character\n"
        "        INX                     ; Advance pattern pointer\n"
        "        INCB                    ; Increment length"
    ),

    # =========================================================================
    # MATCHPAT: full rewrite (PSH X, LDY, ,Y+, ,X+, PUL X)
    # =========================================================================
    (
        "* Match pattern at position X\n"
        "* Returns: Z flag set if match, clear if no match\n"
        "MATCHPAT\n"
        "        PSH     X               ; Save position\n"
        "        LDY     #SRCHPAT\n"
        "        \n"
        "MATCHLP\n"
        "        LDAA     ,Y+             ; Get pattern character\n"
        "        BEQ     MATCHOK   ; End of pattern = match\n"
        "        \n"
        "        CMPA     ,X+             ; Compare with buffer\n"
        "        BNE     MATCHFL\n"
        "        \n"
        "        ; Check buffer bounds\n"
        "        CPX     BUFEND\n"
        "        BHI     MATCHFL\n"
        "        \n"
        "        BRA     MATCHLP\n"
        "\n"
        "MATCHOK\n"
        "        PUL     X               ; Restore position\n"
        "        LDAA     #0              ; Set Z flag\n"
        "        RTS\n"
        "\n"
        "MATCHFL\n"
        "        PUL     X               ; Restore position\n"
        "        LDAA     #1              ; Clear Z flag\n"
        "        RTS",

        "* Match pattern at position X\n"
        "* Returns: Z flag set if match, clear if no match\n"
        "MATCHPAT\n"
        "        STX     TMPX            ; Save buffer position\n"
        "        LDX     #SRCHPAT        ; X points to pattern\n"
        "\n"
        "MATCHLP\n"
        "        LDAA    0,X             ; Get pattern character\n"
        "        INX                     ; Advance pattern pointer\n"
        "        BEQ     MATCHOK         ; End of pattern = match\n"
        "        STX     YP              ; Save pattern pointer\n"
        "        LDX     TMPX            ; Load buffer pointer\n"
        "        CMPA    0,X             ; Compare with buffer\n"
        "        BNE     MATCHFL\n"
        "        INX                     ; Advance buffer pointer\n"
        "        STX     TMPX            ; Save buffer pointer\n"
        "        CPX     BUFEND          ; Check buffer bounds\n"
        "        BHI     MATCHFL\n"
        "        LDX     YP              ; Restore pattern pointer\n"
        "        BRA     MATCHLP\n"
        "\n"
        "MATCHOK\n"
        "        LDX     TMPX            ; Restore buffer position\n"
        "        LDAA    #0              ; Set Z flag\n"
        "        RTS\n"
        "\n"
        "MATCHFL\n"
        "        LDX     TMPX            ; Restore buffer position\n"
        "        LDAA    #1              ; Clear Z flag\n"
        "        RTS"
    ),

    # =========================================================================
    # CMDDLN: LDY BUFPOS / INY -> STX YP pattern
    # =========================================================================
    (
        "        ; Find end of line (including CR)\n"
        "        JSR     FNDCLE\n"
        "        LDX     BUFPOS      ; End position\n"
        "        INX                     ; Include the CR\n"
        "        \n"
        "        ; Calculate line length\n"
        "        LDX     LNSTART\n"
        "        LDY     BUFPOS\n"
        "        INY                     ; Include CR\n"
        "        \n"
        "        ; Copy line to yank buffer for potential restore\n"
        "        JSR     YANKRNG",

        "        ; Find end of line (including CR)\n"
        "        JSR     FNDCLE\n"
        "        LDX     BUFPOS          ; Get end position\n"
        "        INX                     ; Include the CR\n"
        "        STX     YP              ; YP = end pointer\n"
        "        LDX     LNSTART         ; X = start pointer\n"
        "        \n"
        "        ; Copy line to yank buffer for potential restore\n"
        "        JSR     YANKRNG"
    ),

    # =========================================================================
    # CMDDW: PSH X,X / LDY CSRBPOS / PUL X,X -> STX/LDX TMPX + YP
    # =========================================================================
    (
        "* Delete word (dw command)\n"
        "CMDDW\n"
        "        ; Save start position\n"
        "        LDX     CSRBPOS\n"
        "        PSH     X,X             ; Save as start\n"
        "        \n"
        "        ; Move forward one word\n"
        "        JSR     MOVWDF\n"
        "        \n"
        "        ; End position is current cursor\n"
        "        LDY     CSRBPOS\n"
        "        PUL     X,X             ; Restore start\n"
        "        \n"
        "        ; Delete range\n"
        "        JSR     DELRNG",

        "* Delete word (dw command)\n"
        "CMDDW\n"
        "        ; Save start position\n"
        "        LDX     CSRBPOS\n"
        "        STX     TMPX            ; Save start position\n"
        "        \n"
        "        ; Move forward one word\n"
        "        JSR     MOVWDF\n"
        "        \n"
        "        ; End position is current cursor\n"
        "        LDX     CSRBPOS         ; Load end position\n"
        "        STX     YP              ; YP = end pointer\n"
        "        LDX     TMPX            ; Restore start position\n"
        "        \n"
        "        ; Delete range\n"
        "        JSR     DELRNG"
    ),

    # =========================================================================
    # CMDYNKL: LDY BUFPOS / INY -> YP pattern
    # =========================================================================
    (
        "* Yank current line (yy command)\n"
        "CMDYNKL\n"
        "        ; Find start of line\n"
        "        JSR     FNDCLS\n"
        "        LDX     LNSTART\n"
        "        \n"
        "        ; Find end of line (including CR)\n"
        "        JSR     FNDCLE\n"
        "        LDY     BUFPOS\n"
        "        INY                     ; Include CR\n"
        "        \n"
        "        ; Yank the text\n"
        "        JSR     YANKRNG",

        "* Yank current line (yy command)\n"
        "CMDYNKL\n"
        "        ; Find start of line\n"
        "        JSR     FNDCLS\n"
        "        LDX     LNSTART\n"
        "        STX     TMPX            ; Save start pointer\n"
        "        \n"
        "        ; Find end of line (including CR)\n"
        "        JSR     FNDCLE\n"
        "        LDX     BUFPOS\n"
        "        INX                     ; Include CR\n"
        "        STX     YP              ; YP = end pointer\n"
        "        LDX     TMPX            ; X = start pointer\n"
        "        \n"
        "        ; Yank the text\n"
        "        JSR     YANKRNG"
    ),

    # =========================================================================
    # CMDYNKW: PSH X,X / LDY CSRBPOS / PUL X,X -> STX/LDX + YP
    # =========================================================================
    (
        "* Yank word (yw command)\n"
        "CMDYNKW\n"
        "        ; Save start position\n"
        "        LDX     CSRBPOS\n"
        "        PSH     X,X\n"
        "        \n"
        "        ; Move forward one word\n"
        "        JSR     MOVWDF\n"
        "        LDY     CSRBPOS  ; End position\n"
        "        PUL     X,X             ; Start position\n"
        "        \n"
        "        ; Restore cursor position\n"
        "        STX     CSRBPOS",

        "* Yank word (yw command)\n"
        "CMDYNKW\n"
        "        ; Save start position\n"
        "        LDX     CSRBPOS\n"
        "        STX     TMPX            ; Save start position\n"
        "        \n"
        "        ; Move forward one word\n"
        "        JSR     MOVWDF\n"
        "        LDX     CSRBPOS         ; End position\n"
        "        STX     YP              ; YP = end pointer\n"
        "        LDX     TMPX            ; Restore start position\n"
        "        \n"
        "        ; Restore cursor position\n"
        "        STX     CSRBPOS"
    ),

    # =========================================================================
    # YANKRNG: full rewrite
    # =========================================================================
    (
        "* Yank (copy) text from X to Y into yank buffer\n"
        "YANKRNG\n"
        "        ; Calculate length\n"
        "        TFR     Y,D\n"
        "        SUB     X,D             ; D = length\n"
        "        CMPA     #255\n"
        "        BLO     YANKSOK\n"
        "        LDAA     #255            ; Limit to buffer size\n"
        "\n"
        "YANKSOK\n"
        "        STAA     YANKSZ\n"
        "        \n"
        "        ; Copy text to yank buffer\n"
        "        LDY     #YANKBUF\n"
        "        LDAB     YANKSZ\n"
        "        \n"
        "YANKCLP\n"
        "        TSTB\n"
        "        BEQ     YANKCDO\n"
        "        \n"
        "        LDAA     ,X+\n"
        "        STAA     ,Y+\n"
        "        DECB\n"
        "        BRA     YANKCLP\n"
        "\n"
        "YANKCDO\n"
        "        RTS",

        "* Yank (copy) text from X to YP into yank buffer\n"
        "YANKRNG\n"
        "        ; Calculate length (YP - X, low bytes sufficient for <256 range)\n"
        "        STX     TMPY            ; Save start pointer\n"
        "        LDAB    YP+1            ; Low byte of end pointer (YP)\n"
        "        SUBB    TMPY+1          ; Low byte of start pointer\n"
        "        CMPB    #255\n"
        "        BLO     YANKSOK\n"
        "        LDAB    #255            ; Limit to buffer size\n"
        "\n"
        "YANKSOK\n"
        "        STAB    YANKSZ\n"
        "        LDX     TMPY            ; Restore start pointer\n"
        "        STX     YP              ; YP = current source pointer\n"
        "        LDX     #YANKBUF        ; X = dest pointer (yank buffer)\n"
        "        LDAB    YANKSZ\n"
        "\n"
        "YANKCLP\n"
        "        TSTB\n"
        "        BEQ     YANKCDO\n"
        "        STX     TMPX            ; Save dest pointer\n"
        "        LDX     YP              ; Load source pointer\n"
        "        LDAA    0,X             ; Get character\n"
        "        INX\n"
        "        STX     YP              ; Update source pointer\n"
        "        LDX     TMPX            ; Restore dest pointer\n"
        "        STAA    0,X             ; Store character\n"
        "        INX\n"
        "        DECB\n"
        "        BRA     YANKCLP\n"
        "\n"
        "YANKCDO\n"
        "        RTS"
    ),

    # =========================================================================
    # DELRNG: full rewrite
    # =========================================================================
    (
        "* Delete text from X to Y\n"
        "DELRNG\n"
        "        ; Calculate bytes to delete\n"
        "        TFR     Y,D\n"
        "        SUB     X,D             ; D = delete length\n"
        "        \n"
        "        ; Shift remaining text left\n"
        "        ; Source: Y, Dest: X, Length: BUFEND - Y\n"
        "        LDX     BUFEND\n"
        "        SUB     Y,X             ; Remaining bytes after delete range\n"
        "        TFR     X,B             ; B = bytes to shift\n"
        "        \n"
        "        ; Shift text\n"
        "        TFR     Y,X             ; Source\n"
        "        LDY     CSRBPOS  ; Destination (delete start)\n"
        "        \n"
        "DELSLP\n"
        "        TSTB\n"
        "        BEQ     DELSDN\n"
        "        \n"
        "        LDAA     ,X+\n"
        "        STAA     ,Y+\n"
        "        DECB\n"
        "        BRA     DELSLP\n"
        "\n"
        "DELSDN\n"
        "        ; Update buffer end\n"
        "        LDX     BUFEND\n"
        "        SUB     D,X             ; Subtract deleted bytes\n"
        "        STX     BUFEND\n"
        "        RTS",

        "* Delete text from X to YP\n"
        "DELRNG\n"
        "        ; Calculate delete length (YP - X, low bytes)\n"
        "        STX     TMPY            ; Save start pointer\n"
        "        LDAB    YP+1            ; Low byte of end (YP)\n"
        "        SUBB    TMPY+1          ; Low byte of start\n"
        "        STAB    DLEN            ; Save delete length\n"
        "        ; Calculate shift count (BUFEND - YP)\n"
        "        LDAB    BUFEND+1        ; Low byte of BUFEND\n"
        "        SUBB    YP+1            ; Low byte of YP\n"
        "        ; B = bytes after deleted range to shift left\n"
        "        ; Set up: X = source (YP), YP = dest (TMPY = start)\n"
        "        LDX     YP              ; X = source (start of remaining)\n"
        "        STX     TMPX            ; Save source pointer\n"
        "        LDX     TMPY            ; X = dest (deletion start)\n"
        "        STX     YP              ; YP = dest pointer\n"
        "        LDX     TMPX            ; X = source pointer\n"
        "\n"
        "DELSLP\n"
        "        TSTB\n"
        "        BEQ     DELSDN\n"
        "        LDAA    0,X             ; Get source character\n"
        "        INX\n"
        "        STX     TMPX            ; Save source pointer\n"
        "        LDX     YP              ; Load dest pointer\n"
        "        STAA    0,X             ; Store character\n"
        "        INX\n"
        "        STX     YP              ; Save dest pointer\n"
        "        LDX     TMPX            ; Restore source pointer\n"
        "        DECB\n"
        "        BRA     DELSLP\n"
        "\n"
        "DELSDN\n"
        "        ; Update BUFEND: BUFEND = BUFEND - DLEN\n"
        "        LDAB    BUFEND+1        ; Low byte of BUFEND\n"
        "        SUBB    DLEN            ; Subtract delete length\n"
        "        STAB    BUFEND+1\n"
        "        BCC     DELSDNX         ; No borrow\n"
        "        DEC     BUFEND          ; Handle borrow in high byte\n"
        "DELSDNX\n"
        "        RTS"
    ),

    # =========================================================================
    # INSYANK: LDY CSRBPOS, ,X+, ,Y+ -> YP-based
    # =========================================================================
    (
        "        ; Copy from yank buffer\n"
        "        LDX     #YANKBUF\n"
        "        LDY     CSRBPOS\n"
        "        LDAB     YANKSZ\n"
        "        \n"
        "INSYLP\n"
        "        TSTB\n"
        "        BEQ     INSYDN\n"
        "        \n"
        "        LDAA     ,X+\n"
        "        STAA     ,Y+\n"
        "        DECB\n"
        "        BRA     INSYLP\n"
        "\n"
        "INSYDN\n"
        "        ; Update buffer end\n"
        "        LDAA     YANKSZ\n"
        "        LDX     BUFEND\n"
        "        ABX\n"
        "        STX     BUFEND\n"
        "        \n"
        "INSYERR\n"
        "        RTS",

        "        ; Copy from yank buffer to insertion point\n"
        "        LDX     #YANKBUF        ; X = source (yank buffer)\n"
        "        STX     YP              ; YP = source pointer\n"
        "        LDX     CSRBPOS         ; X = dest (insertion point)\n"
        "        LDAB    YANKSZ\n"
        "\n"
        "INSYLP\n"
        "        TSTB\n"
        "        BEQ     INSYDN\n"
        "        STX     TMPX            ; Save dest pointer\n"
        "        LDX     YP              ; Load source pointer\n"
        "        LDAA    0,X             ; Get character from yank buffer\n"
        "        INX\n"
        "        STX     YP              ; Update source pointer\n"
        "        LDX     TMPX            ; Restore dest pointer\n"
        "        STAA    0,X             ; Store to dest\n"
        "        INX\n"
        "        DECB\n"
        "        BRA     INSYLP\n"
        "\n"
        "INSYDN\n"
        "        ; Update buffer end\n"
        "        LDAB    YANKSZ\n"
        "        LDX     BUFEND\n"
        "        ABX\n"
        "        STX     BUFEND\n"
        "\n"
        "INSYERR\n"
        "        RTS"
    ),

    # =========================================================================
    # MKROOM: full rewrite (AB Y, SUB CSRBPOS,A, TFR A,B, ,-X, ,-Y)
    # =========================================================================
    (
        "* Make room in buffer for B bytes at current cursor position\n"
        "MKROOM\n"
        "        ; Check if we have room\n"
        "        LDX     BUFEND\n"
        "        ABX               ; Add bytes needed\n"
        "        CPX     #TXTBUF+BUFSZ\n"
        "        BHI     MKRERR ; Not enough room\n"
        "        \n"
        "        ; Shift text right\n"
        "        ; Source: CSRBPOS to BUFEND\n"
        "        ; Dest: CSRBPOS + B\n"
        "        LDX     BUFEND      ; Start from end\n"
        "        LDY     BUFEND\n"
        "        AB      Y               ; Destination\n"
        "        \n"
        "        ; Calculate bytes to shift\n"
        "        LDAA     BUFEND\n"
        "        SUB     CSRBPOS,A\n"
        "        TAB\n"
        "        \n"
        "MKRSLP\n"
        "        TSTB\n"
        "        BEQ     MKRDN\n"
        "        \n"
        "        LDAA     ,-X\n"
        "        STAA     ,-Y\n"
        "        DECB\n"
        "        BRA     MKRSLP\n"
        "\n"
        "MKRDN\n"
        "        CLRA               ; Success\n"
        "        RTS\n"
        "\n"
        "MKRERR\n"
        "        LDAA     #1              ; Error\n"
        "        RTS",

        "* Make room in buffer for B bytes at current cursor position\n"
        "MKROOM\n"
        "        ; Check if we have room (BUFEND + B <= TXTBUF+BUFSZ)\n"
        "        LDX     BUFEND\n"
        "        ABX                     ; X = BUFEND + B\n"
        "        CPX     #TXTBUF+BUFSZ\n"
        "        BHI     MKRERR          ; Not enough room\n"
        "        STX     YP              ; YP = BUFEND+B (dest, working backward)\n"
        "        ; Compute shift count: B = BUFEND - CSRBPOS\n"
        "        LDAB    BUFEND+1        ; Low byte of BUFEND\n"
        "        SUBB    CSRBPOS+1       ; Low byte of CSRBPOS\n"
        "        BEQ     MKRDN           ; Nothing to shift\n"
        "        ; Source: X starts at BUFEND, works backward\n"
        "        LDX     BUFEND\n"
        "\n"
        "MKRSLP\n"
        "        TSTB\n"
        "        BEQ     MKRDN\n"
        "        DEX                     ; Pre-decrement source\n"
        "        LDAA    0,X             ; Get character\n"
        "        STX     TMPX            ; Save source pointer\n"
        "        LDX     YP\n"
        "        DEX                     ; Pre-decrement dest\n"
        "        STAA    0,X             ; Store character\n"
        "        STX     YP              ; Save dest pointer\n"
        "        LDX     TMPX            ; Restore source pointer\n"
        "        DECB\n"
        "        BRA     MKRSLP\n"
        "\n"
        "MKRDN\n"
        "        CLRA                    ; Success\n"
        "        RTS\n"
        "\n"
        "MKRERR\n"
        "        LDAA    #1              ; Error\n"
        "        RTS"
    ),

    # =========================================================================
    # ADDCBUF: STAA ,X+ -> 0,X + INX
    # =========================================================================
    (
        "        ; Store character\n"
        "        STAA     ,X+\n"
        "        STX     BUFEND",

        "        ; Store character\n"
        "        STAA    0,X             ; Store in buffer\n"
        "        INX                     ; Advance end pointer\n"
        "        STX     BUFEND"
    ),

    # =========================================================================
    # GETFNAM / CPYFNAM: LDY + ,X+ ,Y+ -> YP-based
    # =========================================================================
    (
        "        LDX     #DEFFNAM\n"
        "        LDY     #FILENAME\n"
        "        \n"
        "CPYFNAM\n"
        "        LDAA     ,X+\n"
        "        STAA     ,Y+\n"
        "        BNE     CPYFNAM   ; Continue until null terminator\n"
        "        \n"
        "        CLRA               ; Success\n"
        "        RTS",

        "        LDX     #FILENAME       ; Set destination pointer\n"
        "        STX     YP              ; YP = dest (FILENAME)\n"
        "        LDX     #DEFFNAM        ; X = source (default filename)\n"
        "\n"
        "CPYFNAM\n"
        "        LDAA    0,X             ; Get source character\n"
        "        INX\n"
        "        STX     TMPX            ; Save source pointer\n"
        "        LDX     YP              ; Load dest pointer\n"
        "        STAA    0,X             ; Store to dest\n"
        "        INX\n"
        "        STX     YP              ; Update dest pointer\n"
        "        LDX     TMPX            ; Restore source pointer\n"
        "        TSTA                    ; Test character (Z set if null)\n"
        "        BNE     CPYFNAM         ; Continue until null terminator\n"
        "        CLRA                    ; Success\n"
        "        RTS"
    ),

    # =========================================================================
    # STPFCB / CLRFCB / CPTOFCB: ,X+, LDY, ,Y+ -> fixed
    # =========================================================================
    (
        "CLRFCB\n"
        "        STAA     ,X+\n"
        "        DECB\n"
        "        BNE     CLRFCB\n"
        "        \n"
        "        ; Copy filename to FCB (bytes 4-15)\n"
        "        LDX     #FILENAME\n"
        "        LDY     #FILEFCB+4     ; File name starts at byte 4\n"
        "        \n"
        "CPTOFCB\n"
        "        LDAA     ,X+\n"
        "        BEQ     STPDN\n"
        "        STAA     ,Y+\n"
        "        BRA     CPTOFCB",

        "CLRFCB\n"
        "        STAA    0,X             ; Store zero\n"
        "        INX                     ; Advance pointer\n"
        "        DECB\n"
        "        BNE     CLRFCB\n"
        "        \n"
        "        ; Copy filename to FCB (bytes 4-15)\n"
        "        LDX     #FILEFCB+4      ; Set destination pointer\n"
        "        STX     YP              ; YP = dest (FCB filename field)\n"
        "        LDX     #FILENAME       ; X = source (filename)\n"
        "\n"
        "CPTOFCB\n"
        "        LDAA    0,X             ; Get source character\n"
        "        BEQ     STPDN           ; Stop at null terminator\n"
        "        INX\n"
        "        STX     TMPX            ; Save source pointer\n"
        "        LDX     YP              ; Load dest pointer\n"
        "        STAA    0,X             ; Store to dest\n"
        "        INX\n"
        "        STX     YP              ; Update dest pointer\n"
        "        LDX     TMPX            ; Restore source pointer\n"
        "        BRA     CPTOFCB"
    ),

    # =========================================================================
    # DISPBUF / DISPCH: LDAA ,X+ -> 0,X + INX (with adjusted bounds check)
    # =========================================================================
    (
        "DISPCH\n"
        "        ; Check if at end of buffer\n"
        "        CPX     BUFEND\n"
        "        BHS     LNDN\n"
        "        \n"
        "        ; Get character\n"
        "        LDAA     ,X+",

        "DISPCH\n"
        "        ; Check if at end of buffer\n"
        "        CPX     BUFEND\n"
        "        BHS     LNDN\n"
        "        \n"
        "        ; Get character\n"
        "        LDAA    0,X\n"
        "        INX"
    ),

    # =========================================================================
    # SCRLUP / FNDNLN: LDAA ,X+ -> 0,X + INX
    # =========================================================================
    (
        "FNDNLN\n"
        "        CPX     BUFEND\n"
        "        BHS     SCRLUDN  ; At end\n"
        "        \n"
        "        LDAA     ,X+\n"
        "        CMPA     #CR\n"
        "        BNE     FNDNLN",

        "FNDNLN\n"
        "        CPX     BUFEND\n"
        "        BHS     SCRLUDN         ; At end\n"
        "        LDAA    0,X             ; Get character\n"
        "        INX                     ; Advance pointer\n"
        "        CMPA    #CR\n"
        "        BNE     FNDNLN"
    ),

    # =========================================================================
    # WRTCLP: LDAA ,X+ + PSH X / PUL X -> STX/LDX TMPX
    # =========================================================================
    (
        "        ; Get character from buffer\n"
        "        LDAA     ,X+\n"
        "        PSH     X               ; Save buffer pointer\n"
        "        \n"
        "        ; Write character to file (function code 0)\n"
        "        PSHA               ; Save character\n"
        "        LDAA     #0              ; Write function code\n"
        "        STAA     FILEFCB\n"
        "        PULA               ; Restore character\n"
        "        \n"
        "        LDX     #FILEFCB\n"
        "        JSR     FMS\n"
        "        \n"
        "        PUL     X               ; Restore buffer pointer",

        "        ; Get character from buffer\n"
        "        LDAA    0,X             ; Get character\n"
        "        INX                     ; Advance buffer pointer\n"
        "        STX     TMPX            ; Save buffer pointer\n"
        "        \n"
        "        ; Write character to file (function code 0)\n"
        "        PSHA                    ; Save character\n"
        "        LDAA    #0              ; Write function code\n"
        "        STAA    FILEFCB\n"
        "        PULA                    ; Restore character\n"
        "        \n"
        "        LDX     #FILEFCB\n"
        "        JSR     FMS\n"
        "        \n"
        "        LDX     TMPX            ; Restore buffer pointer"
    ),

    # =========================================================================
    # PRMPFN / CPYNEW: LDY + ,X+, ,Y+ -> YP-based
    # =========================================================================
    (
        "        LDX     #NEWFNAM\n"
        "        LDY     #FILENAME\n"
        "        \n"
        "CPYNEW\n"
        "        LDAA     ,X+\n"
        "        STAA     ,Y+\n"
        "        BNE     CPYNEW\n"
        "        \n"
        "        CLRA               ; Success\n"
        "        RTS",

        "        LDX     #FILENAME       ; Set destination pointer\n"
        "        STX     YP              ; YP = dest (FILENAME)\n"
        "        LDX     #NEWFNAM        ; X = source (new filename)\n"
        "\n"
        "CPYNEW\n"
        "        LDAA    0,X             ; Get source character\n"
        "        INX\n"
        "        STX     TMPX            ; Save source pointer\n"
        "        LDX     YP              ; Load dest pointer\n"
        "        STAA    0,X             ; Store to dest\n"
        "        INX\n"
        "        STX     YP              ; Update dest pointer\n"
        "        LDX     TMPX            ; Restore source pointer\n"
        "        TSTA                    ; Test character\n"
        "        BNE     CPYNEW\n"
        "        CLRA                    ; Success\n"
        "        RTS"
    ),

    # =========================================================================
    # SHFTRGT: rewrite without Y (dest = source+1, so use INX trick)
    # =========================================================================
    (
        "* Shift text right from current position (for insertion)\n"
        "SHFTRGT\n"
        "        ; Start from end of buffer and work backwards\n"
        "        LDX     BUFEND\n"
        "        LDY     BUFEND\n"
        "        INY                     ; Destination (one position right)\n"
        "        \n"
        "SHFTRLP\n"
        "        ; Check if we've reached the insertion point\n"
        "        CPX     BUFPOS\n"
        "        BLO     SHFTRDN\n"
        "        \n"
        "        ; Copy character\n"
        "        LDAA     ,X\n"
        "        STAA     ,Y\n"
        "        \n"
        "        ; Move pointers left\n"
        "        DEX\n"
        "        DEY\n"
        "        \n"
        "        BRA     SHFTRLP\n"
        "\n"
        "SHFTRDN\n"
        "        CLRA               ; Success\n"
        "        RTS",

        "* Shift text right from current position (for insertion)\n"
        "* Since dest = source+1, use INX/DEX trick to avoid needing Y\n"
        "SHFTRGT\n"
        "        LDX     BUFEND          ; Start from end (inclusive)\n"
        "\n"
        "SHFTRLP\n"
        "        CPX     BUFPOS          ; Check if at insertion point\n"
        "        BLO     SHFTRDN\n"
        "        LDAA    0,X             ; Get character at source (X)\n"
        "        INX                     ; Temporarily advance to dest (X+1)\n"
        "        STAA    0,X             ; Store to dest\n"
        "        DEX                     ; Back to source\n"
        "        DEX                     ; Move to previous source position\n"
        "        BRA     SHFTRLP\n"
        "\n"
        "SHFTRDN\n"
        "        CLRA                    ; Success\n"
        "        RTS"
    ),

    # =========================================================================
    # SHFTLFT: rewrite without Y (source = dest+1, use offset trick)
    # =========================================================================
    (
        "* Shift text left from current position (for deletion)\n"
        "SHFTLFT\n"
        "        ; Start from current position and move forward\n"
        "        LDX     BUFPOS\n"
        "        LDY     BUFPOS\n"
        "        INX                     ; Source (one position right)\n"
        "        \n"
        "SHFTLLP\n"
        "        ; Check if past end of buffer\n"
        "        CPX     BUFEND\n"
        "        BHI     SHFTLDN\n"
        "        \n"
        "        ; Copy character\n"
        "        LDAA     ,X\n"
        "        STAA     ,Y\n"
        "        \n"
        "        ; Move pointers right\n"
        "        INX\n"
        "        INY\n"
        "        \n"
        "        BRA     SHFTLLP\n"
        "\n"
        "SHFTLDN\n"
        "        CLRA               ; Success\n"
        "        RTS",

        "* Shift text left from current position (for deletion)\n"
        "* Since source = dest+1, use 1,X for source and 0,X for dest\n"
        "SHFTLFT\n"
        "        LDX     BUFPOS          ; X = dest start (insertion point)\n"
        "\n"
        "SHFTLLP\n"
        "        ; Source is at X+1, dest is at X\n"
        "        LDAA    1,X             ; Get from source (X+1)\n"
        "        STAA    0,X             ; Store to dest (X)\n"
        "        INX                     ; Advance to next pair\n"
        "        CPX     BUFEND          ; Past end of buffer?\n"
        "        BLO     SHFTLLP         ; Continue if not\n"
        "\n"
        "SHFTLDN\n"
        "        CLRA                    ; Success\n"
        "        RTS"
    ),

]


def apply_replacements(content, replacements):
    not_found = []
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new, 1)
        else:
            not_found.append(old[:60].replace('\n', '\\n'))
    return content, not_found


if __name__ == '__main__':
    filepath = '/home/njc/dev/git/vi00/vi.asm'

    with open(filepath, 'r') as f:
        content = f.read()

    new_content, not_found = apply_replacements(content, REPLACEMENTS)

    if not_found:
        print(f"WARNING: {len(not_found)} patterns not found:")
        for p in not_found:
            print(f"  '{p}'")

    with open(filepath, 'w') as f:
        f.write(new_content)

    print(f"Applied {len(REPLACEMENTS) - len(not_found)}/{len(REPLACEMENTS)} replacements")

    # Verify remaining invalid patterns
    import re
    remaining = []
    invalid_patterns = [
        r',X\+',       # post-increment X
        r',Y\+',       # post-increment Y
        r',-X',        # pre-decrement X
        r',-Y',        # pre-decrement Y
        r'\bLDY\b',    # Y register load
        r'\bSTY\b',    # Y register store
        r'\bINY\b',    # Y register increment
        r'\bDEY\b',    # Y register decrement
        r'\bPSH\s+X',  # push X
        r'\bPUL\s+X',  # pull X
        r'\bTFR\b',    # transfer register (6809)
        r'\bAB\s+Y',   # add B to Y
        r'\bSUB\s+[A-Z],[A-Z]',  # register-to-register sub
    ]
    for i, line in enumerate(new_content.split('\n'), 1):
        if line.strip().startswith('*'):
            continue  # skip comments
        for pat in invalid_patterns:
            if re.search(pat, line):
                remaining.append(f"Line {i}: {line.strip()}")
                break

    if remaining:
        print(f"\n{len(remaining)} remaining issues:")
        for r in remaining:
            print(f"  {r}")
    else:
        print("\nNo remaining invalid patterns found!")
