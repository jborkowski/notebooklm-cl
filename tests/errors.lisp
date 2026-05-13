;;; ===========================================================================
;;; Errors — condition type hierarchy, slots, and report strings
;;; ===========================================================================

(in-package #:notebooklm-cl.tests)

(define-test test-errors
  :parent test-suite)

;;; --- Condition type hierarchy ---

(define-test test-condition-hierarchy
  :parent test-errors
  ;; notebooklm-error is the root
  (true (typep (make-condition 'notebooklm-error) 'notebooklm-error))
  (true (typep (make-condition 'notebooklm-error) 'error))
  ;; validation-error is a notebooklm-error
  (true (typep (make-condition 'validation-error) 'notebooklm-error))
  ;; configuration-error is a notebooklm-error
  (true (typep (make-condition 'configuration-error) 'notebooklm-error))
  ;; network-error is a notebooklm-error
  (true (typep (make-condition 'network-error) 'notebooklm-error)))

(define-test test-rpc-error-hierarchy
  :parent test-errors
  ;; rpc-error is a notebooklm-error
  (let ((c (make-condition 'rpc-error :method-id "testMethod")))
    (true (typep c 'rpc-error))
    (true (typep c 'notebooklm-error))
    (is string= "testMethod" (rpc-error-method-id c)))
  ;; auth-error is an rpc-error
  (true (typep (make-condition 'auth-error) 'rpc-error))
  ;; rate-limit-error is an rpc-error
  (true (typep (make-condition 'rate-limit-error) 'rpc-error))
  ;; server-error is an rpc-error
  (true (typep (make-condition 'server-error) 'rpc-error))
  ;; client-error is an rpc-error
  (true (typep (make-condition 'client-error) 'rpc-error))
  ;; decoding-error is an rpc-error
  (true (typep (make-condition 'decoding-error) 'rpc-error))
  ;; unknown-rpc-method-error is a decoding-error (and rpc-error)
  (let ((c (make-condition 'unknown-rpc-method-error)))
    (true (typep c 'unknown-rpc-method-error))
    (true (typep c 'decoding-error))
    (true (typep c 'rpc-error))))

(define-test test-network-error-hierarchy
  :parent test-errors
  (let ((c (make-condition 'network-error :original "socket closed")))
    (true (typep c 'network-error))
    (true (typep c 'notebooklm-error))
    (is string= "socket closed" (network-error-original c)))
  ;; rpc-timeout-error is a network-error
  (let ((c (make-condition 'rpc-timeout-error :timeout-seconds 30)))
    (true (typep c 'rpc-timeout-error))
    (true (typep c 'network-error))))

;;; --- rpc-error slots ---

(define-test test-rpc-error-slots
  :parent test-errors
  ;; All slots filled
  (let ((c (make-condition 'rpc-error
             :method-id "m1"
             :rpc-code "ERR"
             :found-ids '("id1" "id2")
             :raw-response "raw body")))
    (is string= "m1" (rpc-error-method-id c))
    (is string= "ERR" (rpc-error-rpc-code c))
    (is equal '("id1" "id2") (rpc-error-found-ids c))
    (is string= "raw body" (rpc-error-raw-response c)))
  ;; Defaults
  (let ((c (make-condition 'rpc-error)))
    (is eq nil (rpc-error-method-id c))
    (is eq nil (rpc-error-rpc-code c))
    (is eq nil (rpc-error-found-ids c))
    (is eq nil (rpc-error-raw-response c))))

;;; --- rate-limit-error slots ---

(define-test test-rate-limit-error-slots
  :parent test-errors
  (let ((c (make-condition 'rate-limit-error
             :method-id "m2"
             :retry-after 42)))
    (is string= "m2" (rpc-error-method-id c))
    (is = 42 (rate-limit-error-retry-after c)))
  (let ((c (make-condition 'rate-limit-error)))
    (is eq nil (rate-limit-error-retry-after c))))

;;; --- server-error slots ---

(define-test test-server-error-slots
  :parent test-errors
  (let ((c (make-condition 'server-error
             :method-id "m3"
             :status-code 503)))
    (is string= "m3" (rpc-error-method-id c))
    (is = 503 (server-error-status-code c))))

;;; --- client-error slots ---

(define-test test-client-error-slots
  :parent test-errors
  (let ((c (make-condition 'client-error
             :method-id "m4"
             :status-code 422)))
    (is string= "m4" (rpc-error-method-id c))
    (is = 422 (client-error-status-code c))))

;;; --- rpc-timeout-error slots ---

(define-test test-rpc-timeout-error-slots
  :parent test-errors
  (let ((c (make-condition 'rpc-timeout-error
             :timeout-seconds 15.5)))
    (true (typep c 'network-error))
    (is = 15.5 (rpc-timeout-error-timeout-seconds c))))

;;; --- notebook-limit-error slots ---

(define-test test-notebook-limit-error-slots
  :parent test-errors
  (let ((c (make-condition 'notebook-limit-error
             :current-count 5
             :limit 3
             :original-error "some error")))
    (true (typep c 'notebooklm-error))
    (is = 5 (notebook-limit-error-current-count c))
    (is = 3 (notebook-limit-error-limit c))
    (is string= "some error" (notebook-limit-error-original c))))

;;; --- Report strings (verify format control works) ---

(define-test test-error-report-strings
  :parent test-errors
  ;; network-error report
  (let ((c (make-condition 'network-error :original "timeout")))
    (true (search "Network error" (princ-to-string c))))
  ;; rpc-error report
  (let ((c (make-condition 'rpc-error :method-id "foo")))
    (true (search "RPC error" (princ-to-string c)))
    (true (search "foo" (princ-to-string c))))
  ;; auth-error report
  (let ((c (make-condition 'auth-error :method-id "bar")))
    (true (search "Authentication error" (princ-to-string c)))
    (true (search "bar" (princ-to-string c))))
  ;; rate-limit-error report
  (let ((c (make-condition 'rate-limit-error :method-id "baz" :retry-after 30)))
    (let ((s (princ-to-string c)))
      (true (search "Rate limit exceeded" s))
      (true (search "baz" s))
      (true (search "30s" s))))
  ;; server-error report
  (let ((c (make-condition 'server-error :status-code 500 :method-id "srv")))
    (let ((s (princ-to-string c)))
      (true (search "Server error 500" s))
      (true (search "srv" s))))
  ;; client-error report
  (let ((c (make-condition 'client-error :status-code 404 :method-id "cli")))
    (let ((s (princ-to-string c)))
      (true (search "Client error 404" s))
      (true (search "cli" s))))
  ;; rpc-timeout-error report
  (let ((c (make-condition 'rpc-timeout-error :timeout-seconds 10)))
    (let ((s (princ-to-string c)))
      (true (search "RPC timeout" s))
      (true (search "10s" s))))
  ;; notebook-limit-error report
  (let ((c (make-condition 'notebook-limit-error :current-count 4 :limit 3)))
    (let ((s (princ-to-string c)))
      (true (search "Notebook quota exceeded" s))
      (true (search "4" s))
      (true (search "3" s)))))

;;; --- Signal + handler-case integration ---

(define-test test-signal-and-catch-errors
  :parent test-errors
  ;; Catch rpc-error
  (let ((caught nil))
    (handler-case
        (error 'rpc-error :method-id "catch-me")
      (rpc-error (c)
        (setf caught (rpc-error-method-id c))))
    (is string= "catch-me" caught))
  ;; Catch rate-limit-error as rpc-error (subclass)
  (let ((caught nil))
    (handler-case
        (error 'rate-limit-error :method-id "rate" :retry-after 5)
      (rpc-error (c)
        (setf caught (rpc-error-method-id c))))
    (is string= "rate" caught))
  ;; Catch notebook-limit-error (not an rpc-error)
  (let ((caught nil))
    (handler-case
        (error 'notebook-limit-error :current-count 1 :limit 2)
      (notebook-limit-error (c)
        (setf caught (notebook-limit-error-current-count c))))
    (is = 1 caught)))
