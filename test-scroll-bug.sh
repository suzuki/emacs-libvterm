#!/bin/bash
# Simple shell script to manually reproduce the vterm scroll bug

echo "=== VTerm Scroll Bug Reproduction Script ==="
echo ""
echo "This script helps reproduce the bug where vterm scrolls to the"
echo "beginning of the buffer when escape sequences are present in a large buffer."
echo ""
echo "Instructions:"
echo "1. Open vterm in Emacs (M-x vterm)"
echo "2. Run this script: ./test-scroll-bug.sh"
echo "3. Observe if the visible area jumps to earlier content"
echo ""
echo "Press Enter to start..."
read

echo "Step 1: Filling buffer with many lines..."
for i in {1..500}; do
    echo "Line $i of 500"
done

echo ""
echo "Step 2: Buffer should now have ~500 lines of scrollback"
echo "Step 3: Sending output with ANSI escape sequences..."
echo ""

# Send colored output with escape sequences
printf '\033[1;31mRed Text\033[0m\n'
printf '\033[1;32mGreen Text\033[0m\n'
printf '\033[1;34mBlue Text\033[0m\n'
printf '\033[1;33mYellow Text\033[0m\n'

echo ""
printf '\033[1;35m=== Bug Check ===\033[0m\n'
echo "If the bug is present, your view should have jumped to show"
echo "content from much earlier in the buffer (around lines 1-200)"
echo "instead of staying here at the bottom with the prompt."
echo ""
printf '\033[1;36mExpected behavior:\033[0m You should see this text and the prompt\n'
printf '\033[1;31mBuggy behavior:\033[0m You see content from lines 1-200 instead\n'
echo ""
echo "Current line should be near line ~510"
echo "=== Test Complete ==="
