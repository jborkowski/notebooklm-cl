;;; ===========================================================================
;;; Test suite runner — loads all test modules and runs them
;;; ===========================================================================
;;;
;;; Usage:
;;;   (asdf:test-system :notebooklm-cl)
;;;     or
;;;   (notebooklm-cl.tests:run-tests)
;;;     or
;;;   (parachute:test 'notebooklm-cl.tests:test-suite)

(in-package #:notebooklm-cl.tests)

;; Top-level suite — all tests hang off this
(define-test test-suite)

(defun run-tests ()
  "Run all notebooklm-cl tests."
  (parachute:test 'test-suite))
