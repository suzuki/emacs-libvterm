;;; vterm-test-scroll-bug.el --- Test to reproduce terminal buffer scrolling bug -*- lexical-binding: t; -*-

;; This test reproduces the bug where terminal buffer scrolls to the
;; beginning when the buffer grows large and escape sequences are present.

;;; Commentary:

;; This test creates a vterm buffer, fills it with many lines to create
;; a large scrollback buffer, then sends output with escape sequences.
;; The bug manifests as the point jumping to near the beginning of the
;; buffer instead of staying at the bottom where the active terminal is.

;;; Code:

(require 'ert)
(require 'vterm)

(defun vterm-test--wait-for-output (buffer timeout)
  "Wait for BUFFER to receive output, with TIMEOUT in seconds.
Returns t if output was received, nil on timeout."
  (let ((start-time (current-time))
        (original-point (with-current-buffer buffer (point))))
    (while (and (< (float-time (time-since start-time)) timeout)
                (with-current-buffer buffer
                  (= (point) original-point)))
      (accept-process-output nil 0.1))
    (< (float-time (time-since start-time)) timeout)))

(defun vterm-test--send-string (buffer str)
  "Send STR to vterm BUFFER and wait for processing."
  (with-current-buffer buffer
    (vterm-send-string str)
    (vterm-send-return))
  (accept-process-output nil 0.2))

(ert-deftest vterm-test-scroll-position-with-large-buffer ()
  "Test that scroll position is maintained with large buffer and escape sequences.

This test reproduces the bug where:
1. Terminal buffer becomes large (many scrollback lines)
2. Escape sequences are output (e.g., colored text)
3. Point jumps to near the beginning instead of staying at bottom

Expected behavior: Point should stay near the end of the buffer where
the active terminal is.

Actual buggy behavior: Point jumps toward the beginning of the buffer."
  :tags '(:vterm :scroll :bug)

  (skip-unless module-file-suffix)
  (skip-unless (executable-find "bash"))

  (let ((test-buffer (generate-new-buffer "*vterm-scroll-test*"))
        (vterm-shell "bash")
        (vterm-max-scrollback 10000))

    (unwind-protect
        (with-current-buffer test-buffer
          ;; Create vterm session
          (vterm-mode)
          (should (eq major-mode 'vterm-mode))

          ;; Wait for shell to be ready
          (sleep-for 1)

          ;; Generate large scrollback buffer by outputting many lines
          ;; This simulates a terminal session that has been running for a while
          (message "Filling buffer with many lines...")
          (vterm-test--send-string test-buffer "for i in {1..500}; do echo \"Line $i\"; done")

          ;; Wait for output to complete
          (sleep-for 2)

          ;; Record the current buffer size and point position
          (let ((initial-line-count (line-number-at-pos (point-max)))
                (initial-point (point)))

            (message "Buffer has %d lines, point at %d" initial-line-count initial-point)
            (should (> initial-line-count 100)) ;; Ensure we have a large buffer

            ;; Move to end of buffer (simulating user at active prompt)
            (goto-char (point-max))
            (let ((point-before-escape (point))
                  (line-before-escape (line-number-at-pos)))

              (message "Point before escape sequences: %d (line %d/%d)"
                       point-before-escape line-before-escape initial-line-count)

              ;; Send output with ANSI escape sequences (colored output)
              ;; This triggers the code path through term_redraw -> adjust_topline
              (vterm-test--send-string test-buffer
                "printf '\\033[31mRed text\\033[0m\\n\\033[32mGreen text\\033[0m\\n'")

              ;; Wait for processing
              (sleep-for 0.5)

              (let ((point-after-escape (point))
                    (line-after-escape (line-number-at-pos))
                    (total-lines (line-number-at-pos (point-max))))

                (message "Point after escape sequences: %d (line %d/%d)"
                         point-after-escape line-after-escape total-lines)

                ;; The bug causes point to jump toward the beginning
                ;; Point should stay near the end (within ~50 lines of max)
                ;; If bug is present, point will be much earlier in the buffer

                (let ((distance-from-end (- total-lines line-after-escape)))
                  (message "Distance from end: %d lines" distance-from-end)

                  ;; This is the key assertion: point should stay near the end
                  ;; If distance-from-end is large (> 100), the bug is present
                  (should (< distance-from-end 100)
                          (format "Point jumped too far from end: %d lines away (bug reproduced!)"
                                  distance-from-end)))))))

      ;; Cleanup
      (when (buffer-live-p test-buffer)
        (with-current-buffer test-buffer
          (when (get-buffer-process test-buffer)
            (set-process-query-on-exit-flag (get-buffer-process test-buffer) nil)))
        (kill-buffer test-buffer)))))

(ert-deftest vterm-test-scroll-position-manual-reproduction ()
  "Interactive test to manually observe the scrolling bug.

Run this test and observe the buffer behavior. If the bug is present,
after sending escape sequences, the visible portion will jump to show
much earlier content instead of staying at the active prompt."
  :tags '(:vterm :scroll :bug :interactive)

  (skip-unless module-file-suffix)
  (skip-unless (executable-find "bash"))

  (let* ((test-buffer (generate-new-buffer "*vterm-scroll-manual-test*"))
         (vterm-shell "bash")
         (vterm-max-scrollback 10000))

    (switch-to-buffer test-buffer)
    (vterm-mode)

    (message "=== Manual Scroll Bug Test ===")
    (message "1. Wait for the buffer to fill with lines...")
    (sleep-for 1)

    ;; Fill buffer
    (vterm-send-string "for i in {1..500}; do echo \"Line $i\"; done")
    (vterm-send-return)
    (message "2. Waiting for output to complete...")
    (sleep-for 3)

    (message "3. Current position: line %d of %d"
             (line-number-at-pos) (line-number-at-pos (point-max)))
    (message "4. Sending colored output with escape sequences...")
    (sleep-for 1)

    (vterm-send-string "printf '\\033[31mRed\\033[0m \\033[32mGreen\\033[0m \\033[34mBlue\\033[0m\\n'")
    (vterm-send-return)
    (sleep-for 0.5)

    (message "5. After escape sequences: line %d of %d"
             (line-number-at-pos) (line-number-at-pos (point-max)))
    (message "=== If bug is present, you should see the view jumped to earlier content ===")
    (message "=== Expected: view should stay at bottom with the prompt ===")

    ;; Keep buffer open for manual inspection
    (message "Buffer kept open for inspection. Kill it manually when done.")))

(provide 'vterm-test-scroll-bug)
;;; vterm-test-scroll-bug.el ends here
