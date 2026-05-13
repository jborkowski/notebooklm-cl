(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; RPC Encoder
;;;
;;; VALIDATION: Round-trip with Python test_encoder.py.
;;; encode-rpc-request → triple-nested [[[method-id, json-params, nil, "generic"]]]
;;; build-request-body → form-encoded with f.req=, at=, trailing &
;;; ===========================================================================

(define-test test-rpc-encoder
  :parent test-suite)

(define-test test-encode-rpc-request
  :parent test-rpc-encoder
  (let ((req (encode-rpc-request "test-method" (list 1 2 3))))
    (true (consp req))
    (true (consp (first req)))
    ;; Triple-nested: (((method-id json nil "generic")))
    ;; (first (first req)) = (method-id json nil "generic") → length 4
    (is = 4 (length (first (first req))))
    (is string= "test-method" (first (first (first req))))
    ;; second element is JSON-encoded params string
    (is string= "[1,2,3]" (second (first (first req))))))

(define-test test-encode-rpc-request-nil-params
  :parent test-rpc-encoder
  (let ((req (encode-rpc-request "method" nil)))
    (is string= "null" (second (first (first req))))))

(define-test test-build-request-body
  :parent test-rpc-encoder
  (let* ((req (encode-rpc-request "myMethod" (list "hello")))
         (body (build-request-body req)))
    (true (starts-with-p body "f.req="))
    ;; The JSON is URL-encoded; "hello" appears as %22hello%22 inside
    ;; escaped JSON: %5C%22hello%5C%22
    (true (search "hello" body))
    (true (ends-with-p body "&"))))

(define-test test-build-request-body-with-csrf
  :parent test-rpc-encoder
  (let* ((req (encode-rpc-request "myMethod" nil))
         (body (build-request-body req :csrf-token "abc123")))
    (true (search "at=abc123" body))
    (true (notebooklm-cl.util:ends-with-p body "&"))))

(define-test test-build-request-body-no-csrf
  :parent test-rpc-encoder
  (let* ((req (encode-rpc-request "myMethod" nil))
         (body (build-request-body req)))
    (false (search "at=" body))))
