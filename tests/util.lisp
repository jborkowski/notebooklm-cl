(in-package #:notebooklm-cl.tests)

(define-test test-util
  :parent test-suite)

(define-test test-url-encode
  :parent test-util
  (is string= "hello" (url-encode "hello"))
  (is string= "hello%20world" (url-encode "hello world"))
  (is string= "%21%40%23%24%25%5E%26%2A%28%29" (url-encode "!@#$%^&*()"))
  (is string= "" (url-encode ""))
  (is string= "a1B2c3D4" (url-encode "a1B2c3D4"))
  (is string= "~_.-" (url-encode "~_.-"))
  (is string= "hello%2Fworld" (url-encode "hello/world"))
  (is string= "%2B%3D" (url-encode "+="))
  (is string= "Caf%C3%A9" (url-encode "Café"))
  (is string= "%E2%9D%A4" (url-encode "❤"))
  (is string= "a%20b%20c" (url-encode "a b c")))

(define-test test-starts-with-p
  :parent test-util
  (true (starts-with-p "hello world" "hello"))
  (true (starts-with-p "hello" "hello"))
  (true (starts-with-p "hello" ""))
  (false (starts-with-p "hello" "world"))
  (false (starts-with-p "he" "hello"))
  (false (starts-with-p "" "hello"))
  (true (starts-with-p "prefix rest" "prefix")))

(define-test test-ends-with-p
  :parent test-util
  (true (ends-with-p "hello world" "world"))
  (true (ends-with-p "hello" "hello"))
  (true (ends-with-p "hello" ""))
  (false (ends-with-p "hello" "world"))
  (false (ends-with-p "lo" "hello"))
  (false (ends-with-p "" "hello"))
  (true (ends-with-p "rest suffix" "suffix")))
