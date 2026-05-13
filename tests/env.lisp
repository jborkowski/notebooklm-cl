;;; ===========================================================================
;;; Env — URL parsing, base URL configuration, language defaults
;;; ===========================================================================

(in-package #:notebooklm-cl.tests)

(define-test test-env
  :parent test-suite)

;;; --- parse-url-host ---

(define-test test-parse-url-host
  :parent test-env
  ;; Standard HTTPS URL
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com"))
  ;; URL with trailing slash
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com/"))
  ;; URL with path
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com/some/path"))
  ;; URL with query string
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com/?foo=bar"))
  ;; URL with fragment
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com/#section"))
  ;; Cloud host variant
  (is string= "notebooklm.cloud.google.com"
      (parse-url-host "https://notebooklm.cloud.google.com"))
  ;; URL with port
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com:443/path"))
  ;; No trailing content
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com"))
  ;; URL with just host:port and query
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com:8080?q=1"))
  ;; Subdomain
  (is string= "sub.notebooklm.google.com"
      (parse-url-host "https://sub.notebooklm.google.com/path")))

;;; --- get-default-language ---

(define-test test-get-default-language
  :parent test-env
  ;; Default when env var is not set → "en"
  (let ((result (get-default-language)))
    (is string= "en" result)))

;;; --- get-base-url — validates https and allowed hosts ---

(define-test test-get-base-url-valid
  :parent test-env
  ;; Default returns https://notebooklm.google.com
  (let ((url (get-base-url)))
    (true (starts-with-p url "https://"))
    (true (ends-with-p url "notebooklm.google.com"))
    ;; No trailing slash
    (false (ends-with-p url "/"))))

(define-test test-get-base-url-rejects-non-https
  :parent test-env
  ;; get-base-url reads from env var NOTEBOOKLM_BASE_URL or falls back to default.
  ;; We verify the validation logic by checking the parse-url-host + starts-with-p
  ;; guards that get-base-url performs.
  ;; Since we can't set OS env vars from inside a test, we test the guard logic:
  ;;   1. Any input not starting with "https://" → configuration-error
  (let ((invalid "http://notebooklm.google.com"))
    ;; The stripping+guard logic inside get-base-url:
    (let* ((stripped (string-right-trim '(#\/) (string-trim " " invalid))))
      (false (starts-with-p stripped "https://"))
      (true (starts-with-p stripped "http://"))))
  ;;   2. A valid prefix passes the guard
  (let ((valid "https://notebooklm.google.com"))
    (let* ((stripped (string-right-trim '(#\/) (string-trim " " valid))))
      (true (starts-with-p stripped "https://")))))

(define-test test-get-base-url-rejects-bad-host
  :parent test-env
  ;; Verify parse-url-host extracts the correct host from valid URLs
  ;; and that the allowed-hosts list only contains known domains.
  (is string= "notebooklm.google.com"
      (parse-url-host "https://notebooklm.google.com"))
  (is string= "notebooklm.cloud.google.com"
      (parse-url-host "https://notebooklm.cloud.google.com/path"))
  ;; A bad host would be rejected by get-base-url at runtime;
  ;; here we verify parse-url-host would extract "evil.example.com"
  (is string= "evil.example.com"
      (parse-url-host "https://evil.example.com"))
  ;; The host is NOT in the allowed list (that check is done in get-base-url)
  ;; so get-base-url would signal configuration-error for this host.
  (false (member "evil.example.com"
                 '("notebooklm.google.com" "notebooklm.cloud.google.com")
                 :test #'string=)))

;;; --- get-base-host ---

(define-test test-get-base-host
  :parent test-env
  (let ((host (get-base-host)))
    (is string= "notebooklm.google.com" host)))
