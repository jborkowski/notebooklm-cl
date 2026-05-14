;;; ===========================================================================
;;; Sources — pure helpers (RPC wiring covered by encoder/decoder fixtures).
;;; ===========================================================================

(in-package #:notebooklm-cl.tests)

(define-test test-sources
  :parent test-suite)

(define-test test-extract-youtube-watch
  :parent test-sources
  (is string= "dQw4w9WgXcQ"
      (extract-youtube-video-id "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
  (is string= "dQw4w9WgXcQ"
      (extract-youtube-video-id "https://m.youtube.com/watch?feature=x&v=dQw4w9WgXcQ"))
  (is string= "abc-d_12"
      (extract-youtube-video-id "https://youtu.be/abc-d_12"))
  (is string= "xy123"
      (extract-youtube-video-id "https://www.youtube.com/shorts/xy123"))
  (true (null (extract-youtube-video-id "https://example.com/not-youtube"))))

(define-test test-valid-youtube-video-id-p
  :parent test-sources
  (true (valid-youtube-video-id-p "dQw4w9WgXcQ"))
  (true (not (valid-youtube-video-id-p "bad id"))))

(define-test test-source-freshness-predicate
  :parent test-sources
  (true (notebooklm-cl.sources:source-freshness-fresh-p t))
  ;; NIL / [] freshness follows Python empty-array case under LISTP in CL
  (true (notebooklm-cl.sources:source-freshness-fresh-p nil))
  ;; Drive-style nested fresh marker (Python [[null, true, ...]])
  (true (notebooklm-cl.sources:source-freshness-fresh-p '((nil t "sid")))))

(define-test test-drive-mime-constants
  :parent test-sources
  (true (search "google-apps.document"
                notebooklm-cl.rpc.types:+drive-mime-google-doc+))
  (true (string= "application/pdf" notebooklm-cl.rpc.types:+drive-mime-pdf+)))
