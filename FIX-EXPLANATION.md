# Fix for Terminal Buffer Scrolling Bug

## Problem Description

When a vterm buffer grows large (many scrollback lines) and escape sequences are output (e.g., colored text), the buffer would unexpectedly scroll to the beginning instead of staying at the current cursor position.

## Root Cause

In `vterm-module.c`, the `adjust_topline()` function is called after buffer updates to adjust the scroll position. The function calculates where to position the point using:

```c
goto_line(env, pos.row - term->height);
```

This calculation moves backward from the end of the buffer. However, when new lines are added to the buffer (tracked in `term->linenum_added`), the end of the buffer moves down. The original calculation didn't account for these newly added lines, causing the point to jump to an incorrect position—often near the beginning of the buffer.

## The Fix

**File**: `vterm-module.c:527`

**Before**:
```c
goto_line(env, pos.row - term->height);
```

**After**:
```c
goto_line(env, pos.row - term->height - term->linenum_added);
```

By subtracting `term->linenum_added`, we account for the newly added lines and calculate the correct position relative to the new buffer end.

## Context Flow

In `term_redraw()` (lines 613-623):
1. Save old line count: `oldlinenum = term->linenum`
2. Update buffer: `refresh_scrollback()` and `refresh_screen()`
3. Calculate added lines: `term->linenum_added = term->linenum - oldlinenum`
4. Adjust position: `adjust_topline()` (now uses `linenum_added`)
5. Reset counter: `term->linenum_added = 0`

## Testing

Two test methods are provided:

### 1. Shell Script (Manual Test)
```bash
./test-scroll-bug.sh
```
This script:
- Fills the buffer with 500 lines
- Outputs colored text with ANSI escape sequences
- With the bug: view jumps to beginning
- With the fix: view stays at bottom with prompt

### 2. ERT Tests (Automated)
```elisp
;; Load test file
(load-file "vterm-test-scroll-bug.el")

;; Run automated test
(ert-run-tests-interactively "vterm-test-scroll-position-with-large-buffer")
```

## Expected Behavior After Fix

- Cursor and view stay near the bottom of the buffer where the active terminal is
- No unexpected jumps to earlier buffer content
- Smooth scrolling behavior even with large scrollback buffers
