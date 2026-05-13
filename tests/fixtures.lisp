;;; ===========================================================================
;;; Fixtures — Real API response data captured from Python notebooklm-py tests
;;; ===========================================================================
;;;
;;; These fixtures mirror the exact structures used in Python's test_types.py,
;;; test_decoder.py, test_encoder.py, and test_sharing_types.py.
;;; They enable round-trip validation: same input → same output as Python's
;;; from_api_response constructors.
;;;
;;; Fields are positional and must match exactly what the API returns.

(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; Notebook fixtures (from Python test_types.py TestNotebook)
;;; ===========================================================================

;; Basic notebook: title, sources (empty), id, emoji
(defparameter *fixture-notebook-basic*
  '("My Notebook" nil "nb_123" "📓"))

;; Notebook with sources
(defparameter *fixture-notebook-with-sources*
  '("My Notebook" (("src_1") ("src_2") ("src_3")) "nb_123" "📓"))

;; Notebook with timestamp (2024-01-01)
(defparameter *fixture-notebook-with-timestamp*
  '("Timestamped Notebook" nil "nb_456" "📘"
    nil
    (nil nil nil nil nil (1704067200 0))))

;; Notebook with "thought\n" prefix to strip
(defparameter *fixture-notebook-thought-prefix*
  '("thought
Actual Title" nil "nb_789" "📓"))

;; Shared notebook (is_owner = false)
(defparameter *fixture-notebook-shared*
  '("Shared Notebook" nil "nb_shared" "📓"
    nil
    (nil t)))                          ; data[5][1] = t means shared

;; Minimal (empty) notebook
(defparameter *fixture-notebook-empty*
  '())

;;; ===========================================================================
;;; Source fixtures (from Python test_types.py TestSource)
;;; ===========================================================================

;; Flat format: [id, title]
(defparameter *fixture-source-flat*
  '("src_123" "Source Title"))

;; Medium nested: [['id'], 'title', metadata] — data IS the entry
(defparameter *fixture-source-medium-nested*
  '(("src_456") "Nested Source"
    (nil nil nil nil nil nil nil ("https://example.com"))))

;; Medium nested with timestamp
(defparameter *fixture-source-medium-nested-timestamp*
  '(("src_ts") "Timestamped Source"
    (nil nil (1704067200 0) nil 5 nil nil ("https://example.com"))))

;; Deeply nested: [[[['id'], 'title', metadata]]] — 4 levels before id
(defparameter *fixture-source-deep-nested*
  '((((("src_789") "Deep Source"
       (nil nil nil nil nil nil nil ("https://deep.example.com")))))))

;; YouTube source (type code 9)
(defparameter *fixture-source-youtube*
  '((((("src_yt") "YouTube Video"
       (nil nil nil nil 9 nil nil ("https://youtube.com/watch?v=abc")))))))

;; YouTube deep nested with URL at index 5 (regression test for issue #265)
(defparameter *fixture-source-youtube-index-5*
  '((((("src_yt_deep") "YouTube Video"
       (nil nil nil nil 9
        ("https://www.youtube.com/watch?v=dcWU-qD8ISQ" "dcWU-qD8ISQ" "john newquist")
        nil nil))))))

;; Web page source (type code 5)
(defparameter *fixture-source-web-page*
  '((((("src_web") "Web Article"
       (nil nil nil nil 5 nil nil ("https://example.com/article")))))))

;;; ===========================================================================
;;; Artifact fixtures (from Python test_types.py TestArtifact)
;;; ===========================================================================

;; Basic audio artifact
(defparameter *fixture-artifact-basic*
  '("art_123" "Audio Overview" 1 nil 3))

;; Artifact with timestamp
(defparameter *fixture-artifact-with-timestamp*
  '("art_123" "Audio" 1 nil 3 nil nil nil nil nil nil nil nil nil nil nil (1704067200)))

;; Audio artifact with download URL
(defparameter *fixture-artifact-audio-url*
  '("art_audio" "Audio" 1 nil 3
    nil
    (nil nil nil nil nil (("https://audio.example/file.mp4" nil "audio/mp4")))))

;; Video artifact with MP4 URL
(defparameter *fixture-artifact-video-url*
  '("art_video" "Video" 3 nil 3
    nil nil nil
    ((("https://video.example/low.webm" 1 "video/webm")
      ("https://video.example/high.mp4" 4 "video/mp4")))))

;; Infographic artifact
(defparameter *fixture-artifact-infographic-url*
  '("art_info" "Infographic" 7 nil 3
    (nil nil (("ignored" ("https://image.example/info.png"))))))

;; Slide deck artifact
(defparameter *fixture-artifact-slide-deck-url*
  '("art_slides" "Slides" 8 nil 3
    nil nil nil nil nil nil nil nil nil nil nil
    (nil nil nil "https://slides.example/deck.pdf")))

;; Quiz artifact (type 4, variant 2)
(defparameter *fixture-artifact-quiz*
  '("art_quiz" "Quiz" 4 nil 3 nil nil nil nil (nil (2))))

;; Flashcards artifact (type 4, variant 1)
(defparameter *fixture-artifact-flashcards*
  '("art_fc" "Flashcards" 4 nil 3 nil nil nil nil (nil (1))))

;;; ===========================================================================
;;; GenerationStatus fixture (from Python test_types.py TestGenerationStatus)
;;; ===========================================================================

(defparameter *fixture-generation-status-completed*
  '((("art-99") nil nil nil 3)))        ; status code 3 = completed

;;; ===========================================================================
;;; Note fixtures (from Python test_types.py TestNote)
;;; ===========================================================================

(defparameter *fixture-note-basic*
  '("note_123" "Note Title" "Note content here"))

(defparameter *fixture-note-with-timestamp*
  '("note_123" "Title" "Content" (1704067200)))

;;; ===========================================================================
;;; SharedUser fixtures (from Python test_sharing_types.py TestSharedUser)
;;; ===========================================================================

(defparameter *fixture-shared-user-full*
  '("user@example.com" 3 nil ("Test User" "https://avatar.url")))

(defparameter *fixture-shared-user-editor*
  '("editor@example.com" 2 nil ("Editor Name" "https://editor.avatar")))

(defparameter *fixture-shared-user-owner*
  '("owner@example.com" 1 nil ("Owner Name" "https://owner.avatar")))

(defparameter *fixture-shared-user-minimal*
  '("user@example.com" 2 nil))

;;; ===========================================================================
;;; ShareStatus fixtures (from Python test_sharing_types.py TestShareStatus)
;;; ===========================================================================

(defparameter *fixture-share-status-public*
  '(((("owner@example.com" 1 nil ("Owner" "https://avatar"))))
    (t)
    1000))

(defparameter *fixture-share-status-private*
  '(((("owner@example.com" 1 nil ("Owner" "https://avatar"))))
    (nil)
    1000))

(defparameter *fixture-share-status-multi-user*
  '((("owner@example.com" 1 nil ("Owner" "https://owner.avatar"))
     ("editor@example.com" 2 nil ("Editor" "https://editor.avatar"))
     ("viewer@example.com" 3 nil ("Viewer" "https://viewer.avatar")))
    (t)
    1000))

;;; ===========================================================================
;;; NotebookDescription fixture (from Python test_types.py TestNotebookDescription)
;;; ===========================================================================

(defparameter *fixture-notebook-description*
  '((:summary . "This is a summary.")
    (:suggested--topics
     ((:question . "Q1?") (:prompt . "P1"))
     ((:question . "Q2?") (:prompt . "P2")))))

;;; ===========================================================================
;;; ReportSuggestion fixture (from Python test_types.py TestReportSuggestion)
;;; ===========================================================================

(defparameter *fixture-report-suggestion*
  '(:title "Research Report" :description "A detailed report"
    :prompt "Write a report" :audience-level 1))

;;; ===========================================================================
;;; AccountLimits fixture (from Python get_user_settings response shape)
;;; ===========================================================================

(defparameter *fixture-account-limits*
  '((nil (100 200 50 300))))

;;; ===========================================================================
;;; ChatReference fixture (from Python test_types.py TestChatReference)
;;; ===========================================================================

(defparameter *fixture-chat-reference-full*
  '(:source-id "abc123-def456-789" :cited-text "some text"
    :citation-number 1 :start-char 100 :end-char 200
    :chunk-id "chunk-1"))

;;; ===========================================================================
;;; ConversationTurn fixture (from Python test_types.py TestConversationTurn)
;;; ===========================================================================

(defparameter *fixture-conversation-turn*
  '(:query "What is AI?" :answer "AI stands for Artificial Intelligence."
    :turn-number 1 :references nil))

;;; ===========================================================================
;;; AskResult fixture (from Python test_types.py TestAskResult)
;;; ===========================================================================

(defparameter *fixture-ask-result*
  '(:answer "The answer is 42." :conversation-id "conv_123"
    :turn-number 1 :is-follow-up nil
    :references nil :raw-response "Full raw response"))

;;; ===========================================================================
;;; RPC Decoder fixtures (from Python test_decoder.py)
;;; ===========================================================================

;; Simulated chunked response: length line + JSON
(defparameter *fixture-decoder-chunked-single*
  "42
[\"hello\"]
0
")

(defparameter *fixture-decoder-chunked-multiple*
  "42
[\"first\"]
42
[\"second\"]
")

;; wrb.fr chunk with nested JSON result
(defparameter *fixture-decoder-wrb-fr-chunks*
  '((("wrb.fr" "id1"
      "[{\"key\":[\"value\"]}]" nil nil nil)
     ("wrb.fr" "id2" "[]" nil nil nil))))

;; Error chunk
(defparameter *fixture-decoder-error-chunks*
  '((("er" "err-id" "some-error-code"))))

;; Chunks with null result + UserDisplayableError
(defparameter *fixture-decoder-rate-limit-chunks*
  '((("wrb.fr" "method-id" nil nil nil
      (8 nil
       (("type.googleapis.com/google.internal.labs.tailwind.orchestration.v1.UserDisplayableError"
         (nil nil nil nil (nil ((1)) 2)))))
      "generic"))))

;; gRPC status code fixture
(defparameter *fixture-grpc-status-codes*
  '((0 . "OK")
    (1 . "Cancelled")
    (2 . "Unknown")
    (3 . "Invalid argument")
    (4 . "Deadline exceeded")
    (5 . "Not found")
    (6 . "Already exists")
    (7 . "Permission denied")
    (8 . "Resource exhausted")
    (9 . "Failed precondition")
    (10 . "Aborted")
    (11 . "Out of range")
    (12 . "Not implemented")
    (13 . "Internal")
    (14 . "Unavailable")
    (15 . "Data loss")
    (16 . "Unauthenticated")))
