# Detailed Analysis: Scrolling Bug - Escape Sequences vs Plain Text

## Question
Does the scrolling bug occur only with escape sequences, or also with plain text output?

## Answer
**The bug can occur with BOTH escape sequences and plain text**, but escape sequences make it much more noticeable and easier to reproduce.

## Why the Bug Occurs

The bug is triggered when these conditions are met:

1. **Large scrollback buffer** - Many lines in the buffer
2. **New lines added to buffer** - `term->linenum_added > 0`
3. **Screen redraw triggered** - `term_redraw()` is called

### When `linenum_added` Becomes Non-Zero

`term->linenum_added` is set in `term_redraw()` (line 622):

```c
int oldlinenum = term->linenum;
refresh_scrollback(term, env);
refresh_screen(term, env);
term->linenum_added = term->linenum - oldlinenum;  // New lines added
```

Lines are added in `refresh_scrollback()` when `term->sb_pending > 0`:

```c
if (term->sb_pending > 0) {
    term->linenum += term->sb_pending;  // Lines added here
    ...
}
```

### When `sb_pending` Increases

`term->sb_pending` increases in `term_sb_push()` callback (line 98):

```c
if (term->sb_pending < term->sb_size) {
    term->sb_pending++;
    ...
}
```

**`term_sb_push` is called by libvterm when:**
- The screen becomes full and needs to scroll up
- Old visible lines are pushed into scrollback buffer
- **This happens regardless of whether the output contains escape sequences or is plain text**

### When `term_redraw()` is Called

`term_redraw()` is triggered when `term->is_invalidated` is true, which happens via `invalidate_terminal()` called by:

1. **`term_damage`** (line 563) - Screen content changed
   - Triggered by ANY output (plain text or escape sequences)

2. **`term_movecursor`** (line 578-579) - Cursor moved
   - Triggered by ANY output that moves the cursor

3. **`term_settermprop`** (line 730, 737, 742, 755) - Terminal properties changed
   - **More frequently triggered by escape sequences** (colors, cursor type, etc.)

4. **`term_resize`** (line 458) - Window resized
   - Triggered by window size changes

## Why Escape Sequences Make It More Noticeable

While the bug CAN occur with plain text, escape sequences make it much more apparent because:

### 1. Frequent Screen Invalidation
Escape sequences (especially color codes) trigger `term_settermprop()`, which calls `invalidate_terminal()` to redraw the affected areas. This means:
- More frequent calls to `term_redraw()`
- Higher chance of calling `adjust_topline()` with pending scrollback lines

### 2. Multiple Properties Per Line
A single line with color codes like:
```
printf '\033[31mRed\033[0m \033[32mGreen\033[0m\n'
```
Triggers multiple property changes, increasing invalidation frequency.

### 3. Larger Screen Updates
Escape sequences often cause larger screen regions to be marked as damaged, leading to more comprehensive redraws.

## Plain Text Scenario

With plain text output:
- `term_damage` and `term_movecursor` are still called
- `term_sb_push` is still called when screen scrolls
- `term_redraw()` is still eventually called

However, plain text typically causes:
- Less frequent screen invalidation
- Smaller damaged regions
- May batch multiple lines before redraw

This means the bug **can** occur with plain text, but:
- Less frequently
- Harder to reproduce consistently
- May require very specific timing of output and screen updates

## Practical Implications

### When Bug is Most Likely to Occur:
1. Large scrollback buffer (500+ lines)
2. Continuous output causing scrolling
3. **Escape sequences present** (colors, cursor movement, etc.)

### When Bug is Less Likely but Still Possible:
1. Large scrollback buffer
2. Continuous plain text output
3. Output happens to trigger `term_redraw()` at the right moment

## Testing

### High Probability of Reproducing Bug (Before Fix):
```bash
# With escape sequences
./test-scroll-bug.sh
```

### Lower Probability but Still Possible (Before Fix):
```bash
# Plain text only
./test-scroll-bug-plaintext.sh
```

## Conclusion

The bug is **not specific to escape sequences**, but escape sequences make it:
- Much easier to reproduce
- More visually obvious
- More likely to occur in normal terminal usage

The fix (accounting for `term->linenum_added` in `adjust_topline()`) addresses the root cause and works for **both** escape sequences and plain text scenarios.
