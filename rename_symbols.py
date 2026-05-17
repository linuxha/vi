#!/usr/bin/env python3
"""
Rename all assembly symbols to comply with 8-char uppercase A-Z only constraint.
Uses whole-word regex replacement, longer names replaced before shorter ones.
"""
import re
import sys

# Mapping: old_name -> new_name (all new names: max 8 chars, A-Z only)
MAPPING = {
    # Constants
    'DEF_ROWS': 'DEFROWS',
    'DEF_COLS': 'DEFCOLS',
    'MODE_CMD': 'MODECMD',
    'MODE_INS': 'MODEINS',
    # Variables
    'SCREEN_ROWS': 'SCRROWS',
    'SCREEN_COLS': 'SCRCOLS',
    'CURSOR_ROW': 'CSRROW',
    'CURSOR_COL': 'CSRCOL',
    'EDIT_MODE': 'EDMODE',
    'DIRTY_FLAG': 'DIRTY',
    'FILE_OPEN': 'FOPEN',
    'FILE_FCB': 'FILEFCB',
    'BUFFER_SIZE': 'BUFSZ',
    'TEXT_BUFFER': 'TXTBUF',
    'BUFFER_END': 'BUFEND',
    'BUFFER_POS': 'BUFPOS',
    'LINE_START': 'LNSTART',
    'TOP_LINE': 'TOPLINE',
    'CURR_LINE': 'CURRLINE',
    'LINES_TOTAL': 'LNTOTAL',
    'CURSOR_BUF_POS': 'CSRBPOS',
    'LAST_COL': 'LASTCOL',
    'YANK_BUFFER': 'YANKBUF',
    'YANK_SIZE': 'YANKSZ',
    'SEARCH_PATTERN': 'SRCHPAT',
    # FMS constants
    'FMS_READ': 'FMSREAD',
    'FMS_WRITE': 'FMSWRIT',
    'FMS_CLOSE': 'FMSCLOS',
    'FMS_REWIND': 'FMSRWND',
    'FCB_SIZE': 'FCBSZ',
    # Main
    'MAIN_LOOP': 'MAINLOOP',
    'INIT_EDITOR': 'INITED',
    'EXIT_EDITOR': 'EXITVI',
    # Print
    'PRINT_STRING': 'PRNSTR',
    'PRINT_DONE': 'PRNDONE',
    'INIT_MSG': 'INITMSG',
    # Screen
    'CLEAR_SCREEN': 'CLRSCR',
    'GOTO_HOME': 'GOTOHOME',
    'GOTO_MIDDLE': 'GOTOMID',
    'GOTO_BOTTOM_LEFT': 'GOTOBL',
    'GOTO_TOP_RIGHT': 'GOTOTR',
    'GOTO_BOTTOM_RIGHT': 'GOTOBR',
    'POSITION_CURSOR': 'POSCSR',
    'GET_SCREEN_SIZE': 'GETSCSZ',
    'PUT_DECIMAL': 'PUTDEC',
    'PUT_TENS_DONE': 'PTENSDN',
    'PUT_TENS': 'PUTTENS',
    'PUT_SINGLE': 'PUTSING',
    # Keys
    'GET_KEY': 'GETKEY',
    'PROCESS_KEY_DONE': 'PRCKDN',
    'PROCESS_KEY': 'PROCKEY',
    'INSERT_NEWLINE_KEY': 'INSNLK',
    'INSERT_BACKSPACE': 'INSBKSP',
    'INSERT_FAILED': 'INSFAIL',
    'BACKSPACE_DONE': 'BKSPDONE',
    'PROCESS_COMMAND': 'PROCCMD',
    # Commands
    'CMD_OPEN_OR_FILE': 'CMDORF',
    'SET_COMMAND_MODE': 'SETCMD',
    'CMD_OPEN_FILE': 'CMDOPNF',
    'OPEN_FILE_ERROR': 'OPNFERR',
    'READ_FILE_ERROR': 'RDFERR',
    'CMD_SCROLL_UP': 'CMDSUP',
    'CMD_SCROLL_DOWN': 'CMDSDN',
    'CMD_REFRESH': 'CMDREF',
    'CMD_SAVE_FILE': 'CMDSAVE',
    'SAVE_CMD_ERROR': 'SAVCERR',
    'CMD_COMMAND_LINE': 'CMDCOLN',
    'PROCESS_COLON_COMMAND': 'PRCCOL',
    'COLON_WRITE_ONLY': 'COLWRTO',
    'COLON_WRITE_QUIT': 'COLWRTQ',
    'COLON_WRITE': 'COLWRIT',
    'SAVE_BEFORE_QUIT_ERROR': 'SAVBQE',
    'COLON_QUIT': 'COLQUIT',
    'QUIT_WITH_CHANGES': 'QUITCHG',
    'CMD_INSERT_MODE': 'CMDINS',
    'CMD_APPEND_MODE': 'CMDAPP',
    'CMD_DELETE_CHAR': 'CMDDLCH',
    'SHOW_INSERT_MODE': 'SHWINS',
    'SHOW_COMMAND_MODE': 'SHWCMD',
    'INSERT_MSG': 'INSMSG',
    'COMMAND_MSG': 'CMDMSG',
    # Navigation commands
    'CMD_CURSOR_DOWN': 'CMDCDN',
    'CMD_CURSOR_UP': 'CMDCUP',
    'CMD_CURSOR_LEFT': 'CMDCLFT',
    'CMD_CURSOR_RIGHT': 'CMDCRGT',
    'CMD_LINE_START': 'CMDLNST',
    'CMD_LINE_END': 'CMDLNEND',
    'CMD_GO_LAST_LINE': 'CMDGOLST',
    'CMD_GO_FIRST_LINE': 'CMDGOFST',
    'CMD_GO_FIRST_DONE': 'CMDGOFD',
    'CMD_WORD_FORWARD': 'CMDWDF',
    'CMD_WORD_BACKWARD': 'CMDWDB',
    'CMD_SEARCH_FORWARD': 'CMDSRF',
    'CMD_SEARCH_BACKWARD': 'CMDSRB',
    # Cursor movement
    'MOVE_CURSOR_DOWN': 'MOVCDOWN',
    'FIND_NEXT_CR': 'FNDNCR',
    'DOWN_AT_END': 'DNATEND',
    'MOVE_CURSOR_UP': 'MOVCUP',
    'UP_AT_START': 'UPATST',
    'MOVE_CURSOR_LEFT': 'MOVCLEFT',
    'LEFT_AT_LINE_START': 'LFTLNST',
    'LEFT_AT_START': 'LFTATST',
    'MOVE_CURSOR_RIGHT': 'MOVCRT',
    'RIGHT_AT_LINE_END': 'RGTLNEND',
    'RIGHT_AT_END': 'RGTEND',
    'MOVE_TO_LINE_START': 'MOVLNST',
    'MOVE_TO_LINE_END': 'MOVLNEND',
    'GO_TO_FIRST_LINE': 'GOFSTLN',
    'GO_TO_LAST_LINE': 'GOLSTLN',
    'FIND_CURRENT_LINE_START': 'FNDCLS',
    'FIND_LINE_START_LOOP': 'FNDCLSLP',
    'FOUND_LINE_START': 'FNDCLSOK',
    'FIND_CURRENT_LINE_END': 'FNDCLE',
    'FIND_LINE_END_LOOP': 'FNDCLELP',
    'FOUND_LINE_END': 'FNDCLEOK',
    'MOVE_TO_COLUMN': 'MOVCOL',
    'MOVE_COL_LOOP': 'MOVCLP',
    'MOVE_COL_DONE': 'MOVCDONE',
    'UPDATE_DISPLAY_CURSOR': 'UPDCSR',
    'REFRESH_SCREEN': 'REFSCR',
    'ADJUST_TOP_LINE': 'ADJTOPL',
    # Word movement
    'MOVE_WORD_FORWARD': 'MOVWDF',
    'MOVE_WORD_BACKWARD': 'MOVWDB',
    'SKIP_WORD_CHARS_BACK': 'SKPWCHB',
    'SKIP_WORD_BACK_LOOP': 'SKPWCLB',
    'SKIP_WORD_BACK_DONE': 'SKPWCBD',
    'SKIP_WORD_CHARS': 'SKPWCH',
    'SKIP_WORD_LOOP': 'SKPWLP',
    'SKIP_WORD_DONE': 'SKPWDN',
    'SKIP_WHITESPACE_BACK': 'SKPWSB',
    'SKIP_WHITE_BACK_LOOP': 'SKPWSLB',
    'SKIP_WHITE_BACK_DONE': 'SKPWSBD',
    'SKIP_WHITESPACE': 'SKPWS',
    'SKIP_WHITE_LOOP': 'SKPWSLP',
    'SKIP_WHITE_NEXT': 'SKPWSNX',
    'SKIP_WHITE_DONE': 'SKPWSDN',
    'IS_WORD_CHAR_YES': 'ISWCHYES',
    'IS_WORD_CHAR': 'ISWCH',
    'NOT_WORD_CHAR': 'NOTWCH',
    # Search
    'GET_SEARCH_PATTERN': 'GETSRCH',
    'SEARCH_FORWARD_DONE': 'SRCHFDN',
    'SEARCH_FORWARD': 'SRCHFWD',
    'SEARCH_NOT_FOUND': 'SRCHNF',
    'SEARCH_BACKWARD_DONE': 'SRCHBDN',
    'SEARCH_BACKWARD': 'SRCHBWD',
    'CLEAR_PATTERN': 'CLRPAT',
    'GET_PATTERN_BACKSPACE': 'GETPBK',
    'GET_PATTERN_CANCEL': 'GETPCAN',
    'GET_PATTERN_DONE': 'GETPDN',
    'GET_PATTERN_LOOP': 'GETPLP',
    'DO_SEARCH_FORWARD': 'DOSRCHF',
    'SEARCH_FWD_NOT_FOUND': 'SRCHFNF',
    'SEARCH_FWD_FOUND': 'SRCHFFD',
    'SEARCH_FWD_LOOP': 'SRCHFLP',
    'DO_SEARCH_BACKWARD': 'DOSRCHB',
    'SEARCH_BACK_NOT_FOUND': 'SRCHBNF',
    'SEARCH_BACK_FOUND': 'SRCHBFD',
    'SEARCH_BACK_LOOP': 'SRCHBLP',
    'MATCH_PATTERN': 'MATCHPAT',
    'MATCH_SUCCESS': 'MATCHOK',
    'MATCH_LOOP': 'MATCHLP',
    'MATCH_FAIL': 'MATCHFL',
    'SHOW_NOT_FOUND': 'SHWNF',
    'NOT_FOUND_MSG': 'NFNDMSG',
    # Advanced editing commands
    'CMD_OPEN_LINE_BELOW': 'CMDOLB',
    'OPEN_BELOW_ERROR': 'OPNBERR',
    'CMD_OPEN_LINE_ABOVE': 'CMDOLA',
    'OPEN_ABOVE_ERROR': 'OPNAERR',
    'CMD_DELETE_LINE': 'CMDDLN',
    'CMD_DELETE_WORD': 'CMDDW',
    'CMD_DELETE': 'CMDDEL',
    'CMD_YANK_LINE': 'CMDYNKL',
    'CMD_YANK_WORD': 'CMDYNKW',
    'CMD_YANK': 'CMDYANK',
    'CMD_PUT_AFTER': 'CMDPUTA',
    'PUT_NOTHING': 'PUTNONE',
    'CMD_PUT_BEFORE': 'CMDPUTB',
    'CMD_UNDO': 'CMDUNDO',
    # Text manipulation helpers
    'YANK_TEXT_RANGE': 'YANKRNG',
    'YANK_COPY_DONE': 'YANKCDO',
    'YANK_COPY_LOOP': 'YANKCLP',
    'YANK_SIZE_OK': 'YANKSOK',
    'DELETE_TEXT_RANGE': 'DELRNG',
    'DELETE_SHIFT_LOOP': 'DELSLP',
    'DELETE_SHIFT_DONE': 'DELSDN',
    'INSERT_YANKED_TEXT': 'INSYANK',
    'INSERT_YANK_ERROR': 'INSYERR',
    'INSERT_YANK_DONE': 'INSYDN',
    'INSERT_YANK_LOOP': 'INSYLP',
    'MAKE_ROOM_IN_BUFFER': 'MKROOM',
    'MAKE_ROOM_SHIFT_LOOP': 'MKRSLP',
    'MAKE_ROOM_ERROR': 'MKRERR',
    'MAKE_ROOM_DONE': 'MKRDN',
    'SHOW_YANK_MSG': 'SHWYNK',
    'YANK_MSG_TEXT': 'YNKMSG',
    'UNDO_MSG': 'UNDOMSG',
    'SHORT_DELAY': 'SDLY',
    'DELAY_LOOP2': 'DLYLP',
    'SAVE_ERROR_MSG': 'SAVEMSG',
    'SAVE_MSG': 'SAVMSG',
    'UNSAVED_MSG': 'UNSAVMSG',
    # File I/O
    'READ_FILE_TO_BUFFER': 'RDBUF',
    'ADD_CHAR_TO_BUFFER': 'ADDCBUF',
    'OPEN_FILE_WRITE': 'OPNWRIT',
    'WRITE_BUFFER_TO_FILE': 'WRTBUF',
    'WRITE_CHAR_ERROR': 'WRTCERR',
    'WRITE_CHAR_LOOP': 'WRTCLP',
    'WRITE_COMPLETE': 'WRTCOMP',
    'WRITE_OPEN_ERROR': 'WRTERR',
    'SAVE_AS_NEW_FILE': 'SAVNEW',
    'SAVE_AS_ERROR': 'SAVNERR',
    'CREATE_NEW_FILE': 'CRTNEW',
    'CREATE_BACKUP': 'CRTBAK',
    'CREATE_ERROR': 'CRTERR',
    'PROMPT_FILENAME': 'PRMPFN',
    'DEFAULT_FILENAME': 'DEFFNAM',
    'COPY_NEW_NAME': 'CPYNEW',
    'COPY_FILENAME': 'CPYFNAM',
    'GET_FILENAME': 'GETFNAM',
    'NO_BACKUP_NEEDED': 'NOBAK',
    'BUFFER_OVERFLOW': 'BUFOVF',
    'BUFFER_FULL': 'BUFFUL',
    'OPEN_FILE': 'OPNFILE',
    'OPEN_ERROR': 'OPNERR',
    'CLOSE_FILE': 'CLSFILE',
    'CLOSE_DONE': 'CLSDN',
    'READ_LOOP': 'RDLOOP',
    'READ_COMPLETE': 'RDCOMP',
    'READ_ERROR': 'RDERR',
    'COUNT_LINE': 'CNTLN',
    'SETUP_FCB': 'STPFCB',
    'CLEAR_FCB': 'CLRFCB',
    'COPY_TO_FCB': 'CPTOFCB',
    'SETUP_DONE': 'STPDN',
    'SAVE_NO_FILE': 'SAVNOFL',
    'SAVE_ERROR': 'SAVERR',
    'SAVE_FILE': 'SAVFILE',
    # Display
    'DISPLAY_TEXT_LINE': 'DISPTL',
    'DISPLAY_BUFFER': 'DISPBUF',
    'DISPLAY_CHAR': 'DISPCH',
    'DISPLAY_DONE': 'DISPDN',
    'DISPLAY_LINE': 'DISPLN',
    'FIND_NEXT_LINE': 'FNDNLN',
    'SCROLL_UP_DONE': 'SCRLUDN',
    'SCROLL_UP': 'SCRLUP',
    'SCROLL_DOWN_DONE': 'SCRLDDN',
    'SCROLL_DOWN': 'SCRLDOWN',
    'FIND_PREV_LINE': 'FNDPLN',
    'FOUND_PREV_LINE': 'FNDPLNOK',
    'SKIP_CHAR': 'SKPCH',
    'LINE_DONE': 'LNDN',
    # Text editing
    'SHIFT_TEXT_RIGHT': 'SHFTRGT',
    'SHIFT_RIGHT_LOOP': 'SHFTRLP',
    'SHIFT_RIGHT_DONE': 'SHFTRDN',
    'SHIFT_TEXT_LEFT': 'SHFTLFT',
    'SHIFT_LEFT_LOOP': 'SHFTLLP',
    'SHIFT_LEFT_DONE': 'SHFTLDN',
    'INSERT_NEWLINE': 'INSNL',
    'INSERT_ERROR': 'INSERR',
    'INSERT_FULL': 'INSFUL',
    'INSERT_CHAR': 'INSCH',
    'DELETE_DONE': 'DELDONE',
    'DELETE_CHAR': 'DELCH',
    'MARK_DIRTY': 'MKDIRTY',
    'NEWLINE_ERROR': 'NLERR',
    'FIND_LINE_START': 'FNDLNS',
    'FIND_START_LOOP': 'FNDLNSLP',
    'FOUND_START_AFTER_CR': 'FNDLNACR',
    'FOUND_START': 'FNDLNSOK',
    'FIND_LINE_END': 'FNDLNE',
    'FIND_END_LOOP': 'FNDLNELP',
    'FOUND_END': 'FNDLNEOK',
    'NEW_FILENAME': 'NEWFNAM',
}

def validate_mapping(mapping):
    """Validate all new names comply with constraints."""
    errors = []
    seen = {}
    for old, new in mapping.items():
        if len(new) > 8:
            errors.append(f"TOO LONG: {old} -> {new} ({len(new)} chars)")
        if not re.match(r'^[A-Z]+$', new):
            errors.append(f"INVALID CHARS: {old} -> {new}")
        if new in seen:
            errors.append(f"DUPLICATE: {old} -> {new} (already used by {seen[new]})")
        seen[new] = old
    return errors

def apply_replacements(text, mapping):
    """Replace all symbols using whole-word matching, longest first."""
    # Sort by length descending to avoid partial replacements
    sorted_keys = sorted(mapping.keys(), key=len, reverse=True)
    
    for old in sorted_keys:
        new = mapping[old]
        # Use word boundary matching
        pattern = r'\b' + re.escape(old) + r'\b'
        text = re.sub(pattern, new, text)
    
    return text

if __name__ == '__main__':
    filepath = '/home/njc/dev/git/vi00/vi.asm'
    
    # Validate mapping first
    errors = validate_mapping(MAPPING)
    if errors:
        print("MAPPING ERRORS:")
        for e in errors:
            print(f"  {e}")
        sys.exit(1)
    
    print(f"Mapping validated: {len(MAPPING)} symbols to rename")
    
    # Check for new names that might conflict with existing valid names
    valid_existing = {'START', 'FILENAME', 'GETCHR', 'PUTCHR', 'PCRLF', 
                      'WARMS', 'GETFIL', 'SETEXT', 'FMS', 'FMSCLS', 
                      'PUTCHAR', 'ESC', 'LF', 'CR', 'SPACE'}
    for old, new in MAPPING.items():
        if new in valid_existing:
            print(f"WARNING: new name {new} conflicts with existing valid label")
    
    # Read file
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Apply replacements
    new_content = apply_replacements(content, MAPPING)
    
    # Count replacements
    changes = sum(1 for old in MAPPING if old in content)
    print(f"Found {changes} symbols in source file")
    
    # Write result
    with open(filepath, 'w') as f:
        f.write(new_content)
    
    print("Done. Verifying remaining violations...")
    
    # Check for remaining invalid symbols (column 0 labels > 8 chars or with underscore/lowercase)
    violations = []
    for i, line in enumerate(new_content.split('\n'), 1):
        m = re.match(r'^([A-Za-z][A-Za-z0-9_]*)', line)
        if m:
            sym = m.group(1)
            if len(sym) > 8 or not re.match(r'^[A-Z]+$', sym):
                violations.append(f"Line {i}: {sym}")
    
    if violations:
        print(f"\n{len(violations)} remaining violations:")
        for v in violations:
            print(f"  {v}")
    else:
        print("No violations remaining!")
