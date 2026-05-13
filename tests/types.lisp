(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; VALIDATION NOTES
;;;
;;; Round-trip with real API responses captured from Python (notebooklm-py v0.4.1).
;;; Ensure exact field positions match Python's `from_api_response`.
;;; Fixtures in fixtures.lisp mirror test_types.py / test_sharing_types.py.
;;; ===========================================================================

;;; ===========================================================================
;;; strip-thought-newline
;;; ===========================================================================

(define-test test-types
  :parent test-suite)

(define-test test-strip-thought-newline
  :parent test-types
  (is string= "" (strip-thought-newline ""))
  (is string= "My Notebook" (strip-thought-newline "My Notebook"))
  (is string= "My Notebook" (strip-thought-newline "thought
My Notebook"))
  (is string= "My Notebook" (strip-thought-newline "thought
My thought
Notebook"))
  (is string= "My Notebook" (strip-thought-newline "thought
My Notebook thought
"))
  (is string= "Thoughtful" (strip-thought-newline "Thoughtful"))
  ;; "thought" without newline is not stripped
  (is string= "thought about it" (strip-thought-newline "thought about it"))
  ;; leading/trailing whitespace is trimmed
  (is string= "title" (strip-thought-newline "  title  "))
  (is string= "title" (strip-thought-newline "thought
  title  ")))

;;; ===========================================================================
;;; parse-timestamp
;;; ===========================================================================

(define-test test-parse-timestamp
  :parent test-types
  ;; Unix epoch for 2020-01-01
  (true (numberp (parse-timestamp 1577836800)))
  ;; Unix epoch for 2024-01-01
  (true (numberp (parse-timestamp 1704067200)))
  ;; Returns nil for non-number
  (false (parse-timestamp nil))
  (false (parse-timestamp "not a number"))
  ;; Returns nil for negative values
  (false (parse-timestamp -1))
  ;; Returns nil for values before 2000
  (is eq nil (parse-timestamp 100))
  (is eq nil (parse-timestamp 0))
  ;; Returns nil for too-small values
  (is eq nil (parse-timestamp 946684799)))

;;; ===========================================================================
;;; source-type-code-to-kind
;;; ===========================================================================

(define-test test-source-type-code-to-kind
  :parent test-types
  (is string= "google_docs" (source-type-code-to-kind 1))
  (is string= "google_slides" (source-type-code-to-kind 2))
  (is string= "pdf" (source-type-code-to-kind 3))
  (is string= "pasted_text" (source-type-code-to-kind 4))
  (is string= "web_page" (source-type-code-to-kind 5))
  (is string= "markdown" (source-type-code-to-kind 8))
  (is string= "youtube" (source-type-code-to-kind 9))
  (is string= "media" (source-type-code-to-kind 10))
  (is string= "docx" (source-type-code-to-kind 11))
  (is string= "image" (source-type-code-to-kind 13))
  (is string= "google_spreadsheet" (source-type-code-to-kind 14))
  (is string= "csv" (source-type-code-to-kind 16))
  (is string= "epub" (source-type-code-to-kind 17))
  (is string= "unknown" (source-type-code-to-kind nil))
  (is string= "unknown" (source-type-code-to-kind 999))
  (is string= "unknown" (source-type-code-to-kind 0)))

;;; ===========================================================================
;;; artifact-type-to-kind
;;; ===========================================================================

(define-test test-artifact-type-to-kind
  :parent test-types
  (is string= "audio" (artifact-type-to-kind 1 0))
  (is string= "report" (artifact-type-to-kind 2 0))
  (is string= "video" (artifact-type-to-kind 3 0))
  (is string= "flashcards" (artifact-type-to-kind 4 1))
  (is string= "quiz" (artifact-type-to-kind 4 2))
  (is string= "unknown" (artifact-type-to-kind 4 99))
  (is string= "mind_map" (artifact-type-to-kind 5 0))
  (is string= "infographic" (artifact-type-to-kind 7 0))
  (is string= "slide_deck" (artifact-type-to-kind 8 0))
  (is string= "data_table" (artifact-type-to-kind 9 0))
  (is string= "unknown" (artifact-type-to-kind 999 0)))

;;; ===========================================================================
;;; Source struct
;;; ===========================================================================

(define-test test-source-struct
  :parent test-types
  (let ((s (make-source :id "src-1" :title "my doc" :type-code 1 :status 2)))
    (is string= "src-1" (source-id s))
    (is string= "my doc" (source-title s))
    (is = 1 (source-type-code s))
    (is = 2 (source-status s))
    (is string= "google_docs" (source-kind s))
    (true (source-is-ready-p s))
    (false (source-is-processing-p s))
    (false (source-is-error-p s))))

(define-test test-source-status-predicates
  :parent test-types
  ;; Processing
  (let ((s (make-source :status 1)))
    (true (source-is-processing-p s))
    (false (source-is-ready-p s))
    (false (source-is-error-p s)))
  ;; Ready
  (let ((s (make-source :status 2)))
    (false (source-is-processing-p s))
    (true (source-is-ready-p s))
    (false (source-is-error-p s)))
  ;; Error
  (let ((s (make-source :status 3)))
    (false (source-is-processing-p s))
    (false (source-is-ready-p s))
    (true (source-is-error-p s))))

;;; ===========================================================================
;;; source-from-api-response
;;; ===========================================================================

(define-test test-source-from-api-response-flat
  :parent test-types
  (let ((s (source-from-api-response '("abc123" "My Source"))))
    (is string= "abc123" (source-id s))
    (is string= "My Source" (source-title s))))

(define-test test-source-from-api-response-medium
  :parent test-types
  (let ((s (source-from-api-response
            '(("abc123") "My Source"
              (nil nil (1704067200) nil 1 nil nil ("https://example.com"))))))
    (is string= "abc123" (source-id s))
    (is string= "My Source" (source-title s))
    (is = 1 (source-type-code s))
    (is string= "https://example.com" (source-url s))))

(define-test test-source-from-api-response-deep
  :parent test-types
  (let ((s (source-from-api-response
            '(((("abc123") "My Deep Source"
               (nil nil (1704067200) nil 1 nil nil ("https://deep.com")))))))
         )
    (is string= "abc123" (source-id s))
    (is string= "My Deep Source" (source-title s))
    (is = 1 (source-type-code s))
    (is string= "https://deep.com" (source-url s))))

(define-test test-source-from-api-response-no-url
  :parent test-types
  (let ((s (source-from-api-response
            '(("src99") "No URL source" (nil nil nil nil nil)))))
    (is string= "src99" (source-id s))
    (is string= "No URL source" (source-title s))
    (is eq nil (source-url s))))

;;; ===========================================================================
;;; notebook-from-api-response
;;; ===========================================================================

(define-test test-notebook-from-api-response
  :parent test-types
  (let* ((nb (notebook-from-api-response
              '("thought
My Notebook" (("s1") ("s2") ("s3")) "nb-123"
                nil nil (nil t nil nil nil (1704067200)))))
         (title (notebook-title nb)))
    (is string= "nb-123" (notebook-id nb))
    ;; title should have "thought\n" stripped
    (false (search "thought" title))
    (is = 3 (notebook-sources-count nb))
    ;; is-owner: data[5][1] = t means shared, so false
    (false (notebook-is-owner nb))))

(define-test test-notebook-from-api-response-owner
  :parent test-types
  (let* ((nb (notebook-from-api-response
              '("Owner NB" nil "nb-456" nil nil (nil nil nil nil nil (1704067200)))))
         (title (notebook-title nb)))
    (is string= "nb-456" (notebook-id nb))
    (is string= "Owner NB" title)
    (is = 0 (notebook-sources-count nb))
    (true (notebook-is-owner nb))))

;;; ===========================================================================
;;; notebook-description-from-api-response
;;; ===========================================================================

(define-test test-notebook-description-from-api-response
  :parent test-types
  (let ((desc (notebook-description-from-api-response
               '((:summary . "A test summary")
                 (:suggested--topics
                  ((:question . "What is this?") (:prompt . "Explain this"))
                  ((:question . "How does it work?") (:prompt . "Detail the mechanism")))))))
    (is string= "A test summary" (description-summary desc))
    (is = 2 (length (description-suggested-topics desc)))
    (is string= "What is this?"
        (topic-question (first (description-suggested-topics desc))))
    (is string= "Detail the mechanism"
        (topic-prompt (second (description-suggested-topics desc))))))

;;; ===========================================================================
;;; Artifact struct
;;; ===========================================================================

(define-test test-artifact-struct
  :parent test-types
  (let ((a (make-artifact :id "art-1" :title "My Report"
                          :artifact-type 2 :status 3 :variant nil)))
    (is string= "art-1" (art-id a))
    (is string= "My Report" (art-title a))
    (is = 2 (art-artifact-type a))
    (is = 3 (art-status a))
    (is string= "report" (artifact-kind a))
    (true (artifact-is-completed-p a))
    (false (artifact-is-processing-p a))
    (false (artifact-is-pending-p a))
    (false (artifact-is-failed-p a))))

(define-test test-artifact-quiz-flashcards
  :parent test-types
  (let ((quiz (make-artifact :artifact-type 4 :variant 2)))
    (true (artifact-is-quiz-p quiz))
    (false (artifact-is-flashcards-p quiz))
    (is string= "quiz" (artifact-kind quiz)))
  (let ((fc (make-artifact :artifact-type 4 :variant 1)))
    (false (artifact-is-quiz-p fc))
    (true (artifact-is-flashcards-p fc))
    (is string= "flashcards" (artifact-kind fc))))

(define-test test-artifact-status-predicates
  :parent test-types
  (true (artifact-is-processing-p (make-artifact :status 1)))
  (true (artifact-is-pending-p (make-artifact :status 2)))
  (true (artifact-is-completed-p (make-artifact :status 3)))
  (true (artifact-is-failed-p (make-artifact :status 4)))
  (is string= "in_progress" (artifact-status-str (make-artifact :status 1)))
  (is string= "pending" (artifact-status-str (make-artifact :status 2)))
  (is string= "completed" (artifact-status-str (make-artifact :status 3)))
  (is string= "failed" (artifact-status-str (make-artifact :status 4))))

;;; ===========================================================================
;;; artifact-from-api-response
;;; ===========================================================================

(define-test test-artifact-from-api-response-minimal
  :parent test-types
  (let ((a (artifact-from-api-response
            '("art-id" "Test Artifact" 2 nil 3))))
    (is string= "art-id" (art-id a))
    (is string= "Test Artifact" (art-title a))
    (is = 2 (art-artifact-type a))
    (is = 3 (art-status a))))

;;; ===========================================================================
;;; GenerationStatus struct
;;; ===========================================================================

(define-test test-generation-status
  :parent test-types
  (let ((gs (make-generation-status :task-id "task-1" :status "completed")))
    (is string= "task-1" (gen-task-id gs))
    (is string= "completed" (gen-status gs))
    (true (generation-is-complete-p gs))
    (false (generation-is-failed-p gs))
    (false (generation-is-pending-p gs)))
  (let ((gs (make-generation-status :status "failed")))
    (true (generation-is-failed-p gs))
    (false (generation-is-complete-p gs)))
  (let ((gs (make-generation-status :status "pending")))
    (true (generation-is-pending-p gs))))

(define-test test-generation-status-from-api-response
  :parent test-types
  (let ((gs (generation-status-from-api-response
             '((("art-99") nil nil nil 3)))))
    (is string= "art-99" (gen-task-id gs))
    (is string= "completed" (gen-status gs)))
  (let ((gs (generation-status-from-api-response nil)))
    (is string= "" (gen-task-id gs))
    (is string= "failed" (gen-status gs))))

;;; ===========================================================================
;;; Note struct
;;; ===========================================================================

(define-test test-note-from-api-response
  :parent test-types
  (let ((n (note-from-api-response
            '("note-1" "My Note" "Some content" (1704067200))
            "nb-1")))
    (is string= "note-1" (note-id n))
    (is string= "nb-1" (note-notebook-id n))
    (is string= "My Note" (note-title n))
    (is string= "Some content" (note-content n))))

;;; ===========================================================================
;;; SourceFulltext
;;; ===========================================================================

(define-test test-source-fulltext-kind
  :parent test-types
  (let ((sf (make-source-fulltext :type-code 1)))
    (is string= "google_docs" (source-fulltext-kind sf)))
  (let ((sf (make-source-fulltext :type-code nil)))
    (is string= "unknown" (source-fulltext-kind sf))))

;;; ===========================================================================
;;; AccountLimits
;;; ===========================================================================

(define-test test-account-limits-from-api-response
  :parent test-types
  (let ((limits (account-limits-from-api-response
                 '((nil (100 200 50 300))))))
    ;; notebook-limit is at index 1 of limits list (second)
    (is = 200 (limits-notebook-limit limits))
    (is = 50 (limits-source-limit limits))))

;;; ===========================================================================
;;; ChatReference
;;; ===========================================================================

(define-test test-chat-reference-from-api-response
  :parent test-types
  (let ((ref (chat-reference-from-api-response
              '(:source-id "src-1" :cited-text "some text"
                :citation-number 1 :start-char 10 :end-char 20
                :chunk-id "chunk-a"))))
    (is string= "src-1" (ref-source-id ref))
    (is string= "some text" (ref-cited-text ref))
    (is = 1 (ref-citation-number ref))
    (is = 10 (ref-start-char ref))
    (is = 20 (ref-end-char ref))
    (is string= "chunk-a" (ref-chunk-id ref))))

;;; ===========================================================================
;;; ConversationTurn
;;; ===========================================================================

(define-test test-conversation-turn-from-api-response
  :parent test-types
  (let ((turn (conversation-turn-from-api-response
               '(:query "What is Lisp?"
                 :answer "A great language"
                 :turn-number 1
                 :references nil))))
    (is string= "What is Lisp?" (turn-query turn))
    (is string= "A great language" (turn-answer turn))
    (is = 1 (turn-turn-number turn))
    (is eq nil (turn-references turn))))

;;; ===========================================================================
;;; AskResult
;;; ===========================================================================

(define-test test-ask-result-from-api-response
  :parent test-types
  (let ((ar (ask-result-from-api-response
             '(:answer "42" :conversation-id "conv-1"
               :turn-number 3 :is-follow-up t
               :references nil :raw-response "raw"))))
    (is string= "42" (ask-answer ar))
    (is string= "conv-1" (ask-conversation-id ar))
    (is = 3 (ask-turn-number ar))
    (true (ask-is-follow-up ar))
    (is string= "raw" (ask-raw-response ar))))

;;; ===========================================================================
;;; SharedUser
;;; ===========================================================================

(define-test test-shared-user-from-api-response
  :parent test-types
  (let ((u (shared-user-from-api-response
            '("user@example.com" 2 nil ("User Name" "https://photo.url")))))
    (is string= "user@example.com" (su-email u))
    (is string= "User Name" (su-name u))
    (is = 2 (su-permission u))
    (is string= "https://photo.url" (su-photo-url u))))

(define-test test-shared-user-from-api-response-minimal
  :parent test-types
  (let ((u (shared-user-from-api-response '("min@example.com"))))
    (is string= "min@example.com" (su-email u))
    (is eq nil (su-name u))
    (is = 3 (su-permission u))))

;;; ===========================================================================
;;; ShareStatus
;;; ===========================================================================

(define-test test-share-status-from-api-response-not-public
  :parent test-types
  (let ((status (share-status-from-api-response
                 '(nil (nil) 1000) "nb-1")))
    (is string= "nb-1" (share-notebook-id status))
    (false (share-public status))
    (is = 0 (share-access-level status))))

(define-test test-share-status-from-api-response-public
  :parent test-types
  (let ((status (share-status-from-api-response
                 '(nil (t) 1000) "nb-2")))
    (true (share-public status))
    (is = 1 (share-access-level status))
    (true (not (null (share-share-url status))))))

;;; ===========================================================================
;;; ReportSuggestion
;;; ===========================================================================

(define-test test-report-suggestion-from-api-response
  :parent test-types
  (let ((rs (report-suggestion-from-api-response
             '(:title "My Report" :description "A report about things"
               :prompt "Write a report" :audience-level 2))))
    (is string= "My Report" (rs-title rs))
    (is string= "A report about things" (rs-description rs))
    (is string= "Write a report" (rs-prompt rs))
    (is = 2 (rs-audience-level rs))))

;;; ===========================================================================
;;; Round-trip tests using Python-captured fixtures
;;; ===========================================================================

(define-test test-fixtures-notebook
  :parent test-types)

(define-test test-fixture-notebook-basic
  :parent test-fixtures-notebook
  (let ((nb (notebook-from-api-response *fixture-notebook-basic*)))
    (is string= "nb_123" (notebook-id nb))
    (is string= "My Notebook" (notebook-title nb))
    (is = 0 (notebook-sources-count nb))
    (true (notebook-is-owner nb))))

(define-test test-fixture-notebook-with-sources
  :parent test-fixtures-notebook
  (let ((nb (notebook-from-api-response *fixture-notebook-with-sources*)))
    (is = 3 (notebook-sources-count nb))))

(define-test test-fixture-notebook-with-timestamp
  :parent test-fixtures-notebook
  (let ((nb (notebook-from-api-response *fixture-notebook-with-timestamp*)))
    (is string= "nb_456" (notebook-id nb))
    (true (not (null (notebook-created-at nb))))))

(define-test test-fixture-notebook-thought-prefix
  :parent test-fixtures-notebook
  (let ((nb (notebook-from-api-response *fixture-notebook-thought-prefix*)))
    (is string= "Actual Title" (notebook-title nb))
    (false (search "thought" (notebook-title nb)))))

(define-test test-fixture-notebook-shared
  :parent test-fixtures-notebook
  (let ((nb (notebook-from-api-response *fixture-notebook-shared*)))
    (false (notebook-is-owner nb))))

(define-test test-fixtures-source
  :parent test-types)

(define-test test-fixture-source-flat
  :parent test-fixtures-source
  (let ((s (source-from-api-response *fixture-source-flat*)))
    (is string= "src_123" (source-id s))
    (is string= "Source Title" (source-title s))))

(define-test test-fixture-source-medium-nested
  :parent test-fixtures-source
  (let ((s (source-from-api-response *fixture-source-medium-nested*)))
    (is string= "src_456" (source-id s))
    (is string= "Nested Source" (source-title s))
    (is string= "https://example.com" (source-url s))))

(define-test test-fixture-source-deep-nested
  :parent test-fixtures-source
  (let ((s (source-from-api-response *fixture-source-deep-nested*)))
    (is string= "src_789" (source-id s))
    (is string= "Deep Source" (source-title s))
    (is string= "https://deep.example.com" (source-url s))))

(define-test test-fixture-source-youtube
  :parent test-fixtures-source
  (let ((s (source-from-api-response *fixture-source-youtube*)))
    (is string= "src_yt" (source-id s))
    (is string= "youtube" (source-kind s))))

(define-test test-fixture-source-web-page
  :parent test-fixtures-source
  (let ((s (source-from-api-response *fixture-source-web-page*)))
    (is string= "src_web" (source-id s))
    (is string= "web_page" (source-kind s))))

(define-test test-fixtures-artifact
  :parent test-types)

(define-test test-fixture-artifact-basic
  :parent test-fixtures-artifact
  (let ((a (artifact-from-api-response *fixture-artifact-basic*)))
    (is string= "art_123" (art-id a))
    (is string= "Audio Overview" (art-title a))
    (is = 1 (art-artifact-type a))
    (is = 3 (art-status a))
    (is string= "audio" (artifact-kind a))
    (true (artifact-is-completed-p a))))

(define-test test-fixture-artifact-quiz
  :parent test-fixtures-artifact
  (let ((a (artifact-from-api-response *fixture-artifact-quiz*)))
    (is string= "art_quiz" (art-id a))
    (is string= "quiz" (artifact-kind a))
    (true (artifact-is-quiz-p a))
    (false (artifact-is-flashcards-p a))))

(define-test test-fixture-artifact-flashcards
  :parent test-fixtures-artifact
  (let ((a (artifact-from-api-response *fixture-artifact-flashcards*)))
    (is string= "art_fc" (art-id a))
    (is string= "flashcards" (artifact-kind a))
    (true (artifact-is-flashcards-p a))
    (false (artifact-is-quiz-p a))))

(define-test test-fixture-generation-status
  :parent test-types
  (let ((gs (generation-status-from-api-response
             *fixture-generation-status-completed*)))
    (is string= "art-99" (gen-task-id gs))
    (is string= "completed" (gen-status gs))
    (true (generation-is-complete-p gs))))

(define-test test-fixture-note
  :parent test-types
  (let ((n (note-from-api-response *fixture-note-basic* "nb_123")))
    (is string= "note_123" (note-id n))
    (is string= "Note Title" (note-title n))
    (is string= "Note content here" (note-content n))
    (is string= "nb_123" (note-notebook-id n))))

(define-test test-fixtures-shared-user
  :parent test-types)

(define-test test-fixture-shared-user-full
  :parent test-fixtures-shared-user
  (let ((u (shared-user-from-api-response *fixture-shared-user-full*)))
    (is string= "user@example.com" (su-email u))
    (is string= "Test User" (su-name u))
    (is = 3 (su-permission u))
    (is string= "https://avatar.url" (su-photo-url u))))

(define-test test-fixture-shared-user-minimal
  :parent test-fixtures-shared-user
  (let ((u (shared-user-from-api-response *fixture-shared-user-minimal*)))
    (is string= "user@example.com" (su-email u))
    (is = 2 (su-permission u))
    (is eq nil (su-name u))))

(define-test test-fixtures-share-status
  :parent test-types)

(define-test test-fixture-share-status-public
  :parent test-fixtures-share-status
  (let ((status (share-status-from-api-response
                 *fixture-share-status-public* "notebook-123")))
    (is string= "notebook-123" (share-notebook-id status))
    (true (share-public status))
    (is = 1 (share-access-level status))
    (is = 1 (length (share-users status)))
    (true (not (null (share-share-url status))))))

(define-test test-fixture-share-status-private
  :parent test-fixtures-share-status
  (let ((status (share-status-from-api-response
                 *fixture-share-status-private* "notebook-456")))
    (false (share-public status))
    (is = 0 (share-access-level status))
    (is eq nil (share-share-url status))))

(define-test test-fixture-share-status-multi-user
  :parent test-fixtures-share-status
  (let ((status (share-status-from-api-response
                 *fixture-share-status-multi-user* "notebook-789")))
    (is = 3 (length (share-users status)))
    (is = 1 (su-permission (first (share-users status))))
    (is = 2 (su-permission (second (share-users status))))
    (is = 3 (su-permission (third (share-users status))))))

(define-test test-fixture-notebook-description
  :parent test-types
  (let ((desc (notebook-description-from-api-response
               *fixture-notebook-description*)))
    (is string= "This is a summary." (description-summary desc))
    (is = 2 (length (description-suggested-topics desc)))
    (is string= "Q1?" (topic-question (first (description-suggested-topics desc))))
    (is string= "P2" (topic-prompt (second (description-suggested-topics desc))))))

(define-test test-fixture-report-suggestion
  :parent test-types
  (let ((rs (report-suggestion-from-api-response *fixture-report-suggestion*)))
    (is string= "Research Report" (rs-title rs))
    (is string= "A detailed report" (rs-description rs))
    (is string= "Write a report" (rs-prompt rs))
    (is = 1 (rs-audience-level rs))))

(define-test test-fixture-account-limits
  :parent test-types
  (let ((limits (account-limits-from-api-response *fixture-account-limits*)))
    ;; notebook-limit is at index 1 of limits list (second)
    (is = 200 (limits-notebook-limit limits))
    (is = 50 (limits-source-limit limits))))

(define-test test-fixture-chat-reference
  :parent test-types
  (let ((ref (chat-reference-from-api-response *fixture-chat-reference-full*)))
    (is string= "abc123-def456-789" (ref-source-id ref))
    (is string= "some text" (ref-cited-text ref))
    (is = 1 (ref-citation-number ref))
    (is = 100 (ref-start-char ref))
    (is = 200 (ref-end-char ref))))

(define-test test-fixture-conversation-turn
  :parent test-types
  (let ((turn (conversation-turn-from-api-response *fixture-conversation-turn*)))
    (is string= "What is AI?" (turn-query turn))
    (is string= "AI stands for Artificial Intelligence." (turn-answer turn))
    (is = 1 (turn-turn-number turn))))

(define-test test-fixture-ask-result
  :parent test-types
  (let ((ar (ask-result-from-api-response *fixture-ask-result*)))
    (is string= "The answer is 42." (ask-answer ar))
    (is string= "conv_123" (ask-conversation-id ar))
    (is = 1 (ask-turn-number ar))
    (false (ask-is-follow-up ar))
    (is string= "Full raw response" (ask-raw-response ar))))
