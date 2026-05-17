# VT100 Escape Sequences Used in VI Editor

## Screen Control Sequences

| Sequence | Function | Description |
|----------|----------|-------------|
| `ESC[2J` | Clear entire screen | Clears all text from screen |
| `ESC[H` | Cursor home | Moves cursor to position (1,1) |
| `ESC[{row};{col}H` | Position cursor | Moves cursor to specific row/column |
| `ESC[K` | Clear to end of line | Clears from cursor to end of current line |
| `ESC[J` | Clear to end of screen | Clears from cursor to end of screen |

## Cursor Movement Sequences

| Sequence | Function | Description |
|----------|----------|-------------|
| `ESC[A` | Cursor up | Move cursor up one line |
| `ESC[B` | Cursor down | Move cursor down one line |  
| `ESC[C` | Cursor right | Move cursor right one column |
| `ESC[D` | Cursor left | Move cursor left one column |

## Screen Positioning Functions Implemented

- `CLEAR_SCREEN` - ESC[2J + ESC[H
- `GOTO_HOME` - Position at (1,1)
- `GOTO_MIDDLE` - Position at center of screen
- `GOTO_BOTTOM_LEFT` - Position at (max_row, 1)
- `GOTO_TOP_RIGHT` - Position at (1, max_col)
- `GOTO_BOTTOM_RIGHT` - Position at (max_row, max_col)
- `POSITION_CURSOR` - Move to CURSOR_ROW, CURSOR_COL

## Character Codes

- `ESC` = $1B (27 decimal)
- `LF` = $0A (10 decimal)
- `CR` = $0D (13 decimal)
- `[` = $5B (91 decimal)

## Assembly Implementation Notes

1. All coordinates are 1-based (VT100 standard)
2. Row/column values are sent as ASCII decimal digits
3. Maximum screen size assumed to be 99x99 (two digits max)
4. PUT_DECIMAL function handles 1-99 decimal output for positioning