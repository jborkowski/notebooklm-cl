(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; RPC Constants
;;; ===========================================================================

(define-test test-rpc-types
  :parent test-suite)

(define-test test-rpc-method-ids
  :parent test-rpc-types
  (is string= "wXbhsf" *list-notebooks*)
  (is string= "CCqFvf" *create-notebook*)
  (is string= "rLM1Ne" *get-notebook*)
  (is string= "s0tc2d" *rename-notebook*)
  (is string= "WWINqb" *delete-notebook*)
  (is string= "izAoDd" *add-source*)
  (is string= "o4cbdc" *add-source-file*)
  (is string= "tGMBJ" *delete-source*)
  (is string= "VfAZjd" *summarize*)
  (is string= "R7cb6c" *create-artifact*)
  (is string= "ZwVcOc" *get-user-settings*)
  (is string= "QDyure" *share-notebook*))

(define-test test-artifact-constants
  :parent test-rpc-types
  (is = 1 +artifact-audio+)
  (is = 2 +artifact-report+)
  (is = 3 +artifact-video+)
  (is = 4 +artifact-quiz+)
  (is = 5 +artifact-mind-map+)
  (is = 7 +artifact-infographic+)
  (is = 8 +artifact-slide-deck+)
  (is = 9 +artifact-data-table+))

(define-test test-artifact-status-constants
  :parent test-rpc-types
  (is = 1 +artifact-processing+)
  (is = 2 +artifact-pending+)
  (is = 3 +artifact-completed+)
  (is = 4 +artifact-failed+))

(define-test test-source-status-constants
  :parent test-rpc-types
  (is = 1 +source-processing+)
  (is = 2 +source-ready+)
  (is = 3 +source-error+)
  (is = 5 +source-preparing+))

(define-test test-artifact-status-to-str
  :parent test-rpc-types
  (is string= "in_progress" (artifact-status-to-str 1))
  (is string= "pending" (artifact-status-to-str 2))
  (is string= "completed" (artifact-status-to-str 3))
  (is string= "failed" (artifact-status-to-str 4)))

(define-test test-source-status-to-str
  :parent test-rpc-types
  (is string= "processing" (source-status-to-str 1))
  (is string= "ready" (source-status-to-str 2))
  (is string= "error" (source-status-to-str 3))
  (is string= "preparing" (source-status-to-str 5)))

(define-test test-share-constants
  :parent test-rpc-types
  (is = 0 +share-restricted+)
  (is = 1 +share-anyone-with-link+)
  (is = 0 +share-full-notebook+)
  (is = 1 +share-chat-only+)
  (is = 1 +share-owner+)
  (is = 2 +share-editor+)
  (is = 3 +share-viewer+)
  (is = 4 +share-remove+))

(define-test test-audio-constants
  :parent test-rpc-types
  (is = 1 +audio-deep-dive+)
  (is = 2 +audio-brief+)
  (is = 3 +audio-critique+)
  (is = 4 +audio-debate+)
  (is = 1 +audio-short+)
  (is = 2 +audio-default+)
  (is = 3 +audio-long+))

(define-test test-video-constants
  :parent test-rpc-types
  (is = 1 +video-explainer+)
  (is = 2 +video-brief+)
  (is = 3 +video-cinematic+))

(define-test test-quiz-constants
  :parent test-rpc-types
  (is = 1 +quiz-fewer+)
  (is = 2 +quiz-standard+)
  (is = 1 +quiz-easy+)
  (is = 2 +quiz-medium+)
  (is = 3 +quiz-hard+))
