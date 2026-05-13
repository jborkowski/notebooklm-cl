(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; RPC Decoder
;;;
;;; VALIDATION: Round-trip with Python test_decoder.py fixtures.
;;; Fixtures from *fixture-decoder-* in fixtures.lisp.
;;; ===========================================================================

(define-test test-rpc-decoder
  :parent test-suite)

;;; --- strip-anti-xssi ---

(define-test test-strip-anti-xssi
  :parent test-rpc-decoder
  (is string= "hello" (strip-anti-xssi ")]}'
hello"))
  (is string= "no prefix" (strip-anti-xssi "no prefix"))
  (is string= "" (strip-anti-xssi ")]}'
"))
  ;; no change when prefix not present
  (is string= ")]}abc" (strip-anti-xssi ")]}abc"))
  ;; only strips at beginning
  (is string= "foo )]}'" (strip-anti-xssi "foo )]}'"))
  (is string= "" (strip-anti-xssi "")))

;;; --- split-lines ---

(define-test test-split-lines
  :parent test-rpc-decoder
  (is equal '("a" "b" "c") (split-lines "a
b
c"))
  (is equal '("single") (split-lines "single"))
  (is equal '() (split-lines ""))
  (is equal '("line1" "line2") (split-lines "line1
line2
"))
  ;; blank lines are ignored
  (is equal '("a" "b") (split-lines "a

b")))

;;; --- parse-chunked-response ---

(define-test test-parse-chunked-response-valid
  :parent test-rpc-decoder
  ;; A simple valid chunked response: length line + JSON data
  (let ((chunks (parse-chunked-response "42
[\"hello\"]
0
")))
    (is = 1 (length chunks))
    (is equal '("hello") (first chunks))))

(define-test test-parse-chunked-response-json
  :parent test-rpc-decoder
  (let ((chunks (parse-chunked-response "40
{\"key\":[\"value\"]}
0
")))
    (is = 1 (length chunks))
    ;; cl-json wraps decoded objects; (first chunks) = ((:key "value"))
    (is equal '((:key "value")) (first chunks))))

(define-test test-parse-chunked-response-multiple
  :parent test-rpc-decoder
  (let ((chunks (parse-chunked-response "42
[\"first\"]
42
[\"second\"]
")))
    (is = 2 (length chunks))
    (is equal '("first") (first chunks))
    (is equal '("second") (second chunks))))

;;; --- collect-rpc-ids ---

(define-test test-collect-rpc-ids
  :parent test-rpc-decoder
  (let ((chunks '((("wrb.fr" "id1" nil nil nil nil)
                   ("wrb.fr" "id2" nil nil nil nil)))))
    (is equal '("id1" "id2") (collect-rpc-ids chunks)))
  (let ((chunks '(("wrb.fr" "id1" nil nil nil nil))))
    (is equal '("id1") (collect-rpc-ids chunks)))
  (let ((chunks '(("er" "err-id" "error-code"))))
    (is equal '("err-id") (collect-rpc-ids chunks)))
  (let ((chunks '((("other" "x" nil)))))
    (is equal '() (collect-rpc-ids chunks))))

;;; --- contains-user-displayable-error-p ---

(define-test test-contains-user-displayable-error-p
  :parent test-rpc-decoder
  (true (contains-user-displayable-error-p "UserDisplayableError"))
  (true (contains-user-displayable-error-p
         "prefix UserDisplayableError suffix"))
  (true (contains-user-displayable-error-p
         '("something" ("nested" "UserDisplayableError"))))
  (false (contains-user-displayable-error-p "normal error"))
  (false (contains-user-displayable-error-p nil))
  (false (contains-user-displayable-error-p
          '("a" "b" "c")))
  (false (contains-user-displayable-error-p 42)))

;;; --- extract-status-code ---

(define-test test-extract-status-code
  :parent test-rpc-decoder
  ;; Valid gRPC status codes
  (let ((result (extract-status-code '(0))))
    (is = 0 (car result))
    (is string= "OK" (cdr result)))
  (let ((result (extract-status-code '(5))))
    (is = 5 (car result))
    (is string= "Not found" (cdr result)))
  (let ((result (extract-status-code '(16))))
    (is = 16 (car result))
    (is string= "Unauthenticated" (cdr result)))
  ;; Invalid inputs
  (is eq nil (extract-status-code nil))
  (is eq nil (extract-status-code '(999)))
  (is eq nil (extract-status-code "not a list"))
  (is eq nil (extract-status-code '(1 2 3))))

;;; ===========================================================================
;;; Fixture-backed decoder tests (matching Python test_decoder.py)
;;; ===========================================================================

(define-test test-fixture-parse-single-chunk
  :parent test-rpc-decoder
  ;; Matches TestParseChunkedResponse.test_parses_single_chunk
  (let ((chunks (parse-chunked-response *fixture-decoder-chunked-single*)))
    (is = 1 (length chunks))
    (is equal '("hello") (first chunks))))

(define-test test-fixture-parse-multiple-chunks
  :parent test-rpc-decoder
  ;; Matches TestParseChunkedResponse.test_parses_multiple_chunks
  (let ((chunks (parse-chunked-response *fixture-decoder-chunked-multiple*)))
    (is = 2 (length chunks))
    (is equal '("first") (first chunks))
    (is equal '("second") (second chunks))))

(define-test test-fixture-empty-response
  :parent test-rpc-decoder
  ;; Matches TestParseChunkedResponse.test_empty_response
  (is equal '() (parse-chunked-response "")))

(define-test test-fixture-collect-wrb-ids
  :parent test-rpc-decoder
  ;; Matches TestCollectRpcIds.test_collects_multiple_ids
  (is equal '("id1" "id2")
      (collect-rpc-ids *fixture-decoder-wrb-fr-chunks*)))

(define-test test-fixture-collect-error-ids
  :parent test-rpc-decoder
  ;; Matches TestCollectRpcIds.test_collects_error_ids
  (is equal '("err-id")
      (collect-rpc-ids *fixture-decoder-error-chunks*)))

(define-test test-fixture-rate-limit-detection
  :parent test-rpc-decoder
  ;; Matches TestExtractRPCResult.test_user_displayable_error_sets_code
  (true (contains-user-displayable-error-p
         '("UserDisplayableError"))))
