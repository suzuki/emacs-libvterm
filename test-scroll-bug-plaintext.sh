#!/bin/bash
# Test to verify if plain text (without escape sequences) causes the same scrolling bug

echo "=== Plain Text Scrolling Bug Test ==="
echo ""
echo "This test uses ONLY plain text (no ANSI escape sequences)"
echo "to verify if the bug occurs with regular text output."
echo ""
echo "Press Enter to start..."
read

echo "Step 1: Filling buffer with plain text (no colors)..."
for i in {1..500}; do
    echo "Plain text line $i - no escape sequences or colors here"
done

echo ""
echo "Step 2: Buffer now has ~500 lines"
echo "Step 3: Outputting more plain text..."
echo ""

# Output plain text WITHOUT any escape sequences
echo "This is line 501 - plain text only"
echo "This is line 502 - plain text only"
echo "This is line 503 - plain text only"
echo "This is line 504 - plain text only"
echo "This is line 505 - plain text only"

echo ""
echo "=== Bug Check ==="
echo "If the bug ALSO occurs with plain text:"
echo "  - Your view jumped to earlier content (around lines 1-200)"
echo ""
echo "If the bug is SPECIFIC to escape sequences:"
echo "  - Your view stayed here at the bottom with the prompt"
echo ""
echo "Expected: Based on the code analysis, the bug should NOT occur"
echo "with plain text alone, because plain text usually doesn't trigger"
echo "the conditions that cause linenum_added > 0 in a noticeable way."
echo ""
echo "=== Test Complete ==="
