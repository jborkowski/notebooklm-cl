;;; ===========================================================================
;;; Core — auth-tokens struct, client-core struct, build-url,
;;;        classify-http-error
;;; ===========================================================================
;;;
;;; Uses :: (double-colon) to reach internal symbols not exported by
;;; notebooklm-cl.core.  This is standard practice for white-box tests.

(in-package #:notebooklm-cl.tests)

(define-test test-core
  :parent test-suite)

;;; ===========================================================================
;;; auth-tokens (internal struct)
;;; ===========================================================================

(define-test test-auth-tokens-struct
  :parent test-core
  (let ((auth (notebooklm-cl.core::make-auth-tokens
                :csrf-token "csrf123"
                :session-id "sid456"
                :account-email "user@example.com"
                :authuser "0")))
    (is string= "csrf123" (notebooklm-cl.core::auth-tokens-csrf-token auth))
    (is string= "sid456" (notebooklm-cl.core::auth-tokens-session-id auth))
    (is string= "user@example.com" (notebooklm-cl.core::auth-tokens-account-email auth))
    (is string= "0" (notebooklm-cl.core::auth-tokens-authuser auth))))

(define-test test-auth-tokens-defaults
  :parent test-core
  (let ((auth (notebooklm-cl.core::make-auth-tokens)))
    (is eq nil (notebooklm-cl.core::auth-tokens-csrf-token auth))
    (is eq nil (notebooklm-cl.core::auth-tokens-session-id auth))
    (is eq nil (notebooklm-cl.core::auth-tokens-account-email auth))
    (is eq nil (notebooklm-cl.core::auth-tokens-authuser auth))))

;;; ===========================================================================
;;; client-core
;;; ===========================================================================

(define-test test-client-core-struct
  :parent test-core
  (let ((cc (make-client-core)))
    (is eq nil (notebooklm-cl.core::client-core-auth cc))
    (is eq nil (notebooklm-cl.core::client-core-http cc))
    (is = 30.0 (notebooklm-cl.core::client-core-timeout cc))
    (is = 10.0 (notebooklm-cl.core::client-core-connect-timeout cc))
    (is eq nil (notebooklm-cl.core::client-core-refresh-callback cc))))

(define-test test-client-core-custom-timeout
  :parent test-core
  (let ((cc (make-client-core :timeout 60.0 :connect-timeout 5.0)))
    (is = 60.0 (notebooklm-cl.core::client-core-timeout cc))
    (is = 5.0 (notebooklm-cl.core::client-core-connect-timeout cc))))

(define-test test-client-core-auth
  :parent test-core
  (let* ((auth (notebooklm-cl.core::make-auth-tokens
                 :csrf-token "x" :session-id "y"))
         (cc (make-client-core :auth auth)))
    (is string= "x" (notebooklm-cl.core::auth-tokens-csrf-token
                      (notebooklm-cl.core::client-core-auth cc)))
    (is string= "y" (notebooklm-cl.core::auth-tokens-session-id
                      (notebooklm-cl.core::client-core-auth cc)))))

;;; ===========================================================================
;;; open-client / close-client / client-open-p
;;; ===========================================================================

(define-test test-open-close-client
  :parent test-core
  (let ((cc (make-client-core)))
    (false (client-open-p cc))
    (open-client cc)
    (true (client-open-p cc))
    (close-client cc)
    (false (client-open-p cc))
    ;; Double close: no error
    (close-client cc)
    (false (client-open-p cc))))

;;; ===========================================================================
;;; build-url (pure — no HTTP)
;;; ===========================================================================

(define-test test-build-url-basic
  :parent test-core
  (let* ((auth (notebooklm-cl.core::make-auth-tokens
                 :session-id "test-sid"
                 :account-email "user@example.com"))
         (url (build-url "testMethod" "/" auth)))
    (true (starts-with-p url "https://notebooklm.google.com/_/LabsTailwindUi/data/batchexecute"))
    (true (search "rpcids=testMethod" url))
    (true (search "source-path=%2F" url))
    (true (search "f.sid=test-sid" url))
    (true (search "hl=en" url))
    (true (search "authuser=user%40example.com" url))
    (true (search "rt=c" url))))

(define-test test-build-url-authuser-fallback
  :parent test-core
  (let* ((auth (notebooklm-cl.core::make-auth-tokens
                 :session-id "sid" :authuser "2"))
         (url (build-url "m" "/nb/123" auth)))
    (true (search "authuser=2" url))))

(define-test test-build-url-no-authuser
  :parent test-core
  (let* ((auth (notebooklm-cl.core::make-auth-tokens :session-id "sid"))
         (url (build-url "m" "/" auth)))
    (false (search "authuser" url))))

(define-test test-build-url-empty-session-id
  :parent test-core
  (let* ((auth (notebooklm-cl.core::make-auth-tokens))
         (url (build-url "m" "/" auth)))
    (true (search "f.sid=" url))))

(define-test test-build-url-special-chars-in-path
  :parent test-core
  (let* ((auth (notebooklm-cl.core::make-auth-tokens :session-id "sid"))
         (url (build-url "method" "/notebook/abc-123" auth)))
    (true (search "source-path=%2Fnotebook%2Fabc-123" url))))

;;; ===========================================================================
;;; classify-http-error (internal — signals conditions)
;;; ===========================================================================

(define-test test-classify-http-error-rate-limit
  :parent test-core
  (handler-case
      (notebooklm-cl.core::classify-http-error 429 "m1")
    (rate-limit-error (c)
      (is string= "m1" (rpc-error-method-id c)))))

(define-test test-classify-http-error-server
  :parent test-core
  (handler-case
      (notebooklm-cl.core::classify-http-error 503 "m2")
    (server-error (c)
      (is string= "m2" (rpc-error-method-id c))
      (is = 503 (server-error-status-code c))))
  ;; Edge: 500
  (handler-case
      (notebooklm-cl.core::classify-http-error 500 "m3")
    (server-error (c)
      (is = 500 (server-error-status-code c))))
  ;; Edge: 599
  (handler-case
      (notebooklm-cl.core::classify-http-error 599 "m4")
    (server-error (c)
      (is = 599 (server-error-status-code c)))))

(define-test test-classify-http-error-client
  :parent test-core
  ;; 400-499 except 401/403
  (handler-case
      (notebooklm-cl.core::classify-http-error 404 "m5")
    (client-error (c)
      (is string= "m5" (rpc-error-method-id c))
      (is = 404 (client-error-status-code c))))
  ;; 422
  (handler-case
      (notebooklm-cl.core::classify-http-error 422 "m6")
    (client-error (c)
      (is = 422 (client-error-status-code c)))))

(define-test test-classify-http-error-auth-generic
  :parent test-core
  ;; 401 and 403 fall through to generic rpc-error
  (handler-case
      (notebooklm-cl.core::classify-http-error 401 "m7")
    (rpc-error (c)
      (is string= "m7" (rpc-error-method-id c))))
  (handler-case
      (notebooklm-cl.core::classify-http-error 403 "m8")
    (rpc-error (c)
      (is string= "m8" (rpc-error-method-id c))))
  ;; Unknown code (e.g. 200) → generic rpc-error
  (handler-case
      (notebooklm-cl.core::classify-http-error 200 "m9")
    (rpc-error (c)
      (is string= "m9" (rpc-error-method-id c)))))
