(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; RPC Encoder
;;;
;;; VALIDATION: Round-trip with Python test_encoder.py.
;;; encode-rpc-request → `((method-id json-params-string nil \"generic\"))`
;;; i.e. (first REQ) is the inner quad `(method-id json nil generic)`.
;;; build-request-body → form-encoded with f.req=, at=, trailing &
;;; ===========================================================================

(define-test test-rpc-encoder
  :parent test-suite)

(define-test test-encode-rpc-request
  :parent test-rpc-encoder
  (let ((req (encode-rpc-request "test-method" (list 1 2 3))))
    (true (consp req))
    (true (consp (first req)))
    ;; One wrapper list around the quad: ((method-id json nil "generic"))
    (is = 4 (length (first req)))
    (is string= "test-method" (first (first req)))
    ;; second element is JSON-encoded params string
    (is string= "[1,2,3]" (second (first req)))))

(define-test test-encode-rpc-request-nil-params
  :parent test-rpc-encoder
  (let ((req (encode-rpc-request "method" nil)))
    (is string= "null" (second (first req)))))

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

(define-test test-encode-add-source-file-params-shape
  :parent test-rpc-encoder
  (labels ((nth* (seq i)
             (etypecase seq
               (list (nth i seq))
               (vector (aref seq i)))))
    ;; Python `_sources.py`: first RPC param element is [[filename]]
    ;; (nested list wrapping the filename once).
    (let* ((fname "report.pdf")
           (notebook-id "proj-uuid-123")
           (params (list (list fname)
                         notebook-id
                         (list 2)
                         (list 1 nil nil nil nil nil nil nil nil nil (list 1))))
           (req (encode-rpc-request notebooklm-cl.rpc.types:*add-source-file* params))
           (inner-quad (first req))
           (json-params (second inner-quad))
           (parsed (with-input-from-string (s json-params)
                     (cl-json:decode-json s)))
           (file-cell (nth* parsed 0))
           (inner (nth* file-cell 0)))
      (true (equal notebooklm-cl.rpc.types:*add-source-file*
                   (first inner-quad)))
      (true (= 4 (length parsed)))
      (true (equal notebook-id (nth* parsed 1)))
      (is string= fname inner))))
