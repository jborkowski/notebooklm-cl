(in-package #:notebooklm-cl.tests)

(define-test test-artifacts
  :parent test-suite
  ;; Mind-map parsing lives in tests/types (`artifact-from-mind-map-data`).
  ;; RPC calls remain P1-002 integration-deferred.
  )

;;; ===========================================================================
;;; define-artifact-lister macro
;;; ===========================================================================

(define-test test-define-artifact-lister-expands-to-defun
  :parent test-artifacts
  ;; Verify the macro produces a DEFUN that calls LIST-ARTIFACTS with the right keyword.
  (let ((expansion (macroexpand-1 '(define-artifact-lister list-audio :audio))))
    (true (consp expansion))
    (is eq 'defun (first expansion))
    (is eq 'list-audio (second expansion))
    (true (search "LIST-ARTIFACTS" (princ-to-string expansion)))))

(define-test test-define-artifact-lister-all-eight-defined
  :parent test-artifacts
  ;; After compiling the file, all 8 listers should be FBOUNDP.
  (true (fboundp 'list-audio))
  (true (fboundp 'list-video))
  (true (fboundp 'list-reports))
  (true (fboundp 'list-quizzes))
  (true (fboundp 'list-flashcards))
  (true (fboundp 'list-infographics))
  (true (fboundp 'list-slide-decks))
  (true (fboundp 'list-data-tables)))

(define-test test-get-artifact-defined
  :parent test-artifacts
  (true (fboundp 'get-artifact)))

(define-test test-suggest-reports-defined
  :parent test-artifacts
  (true (fboundp 'suggest-reports)))

;;; ===========================================================================
;;; poll-artifact-status-from-rows
;;; ===========================================================================

(define-test poll-artifact-status-from-rows-not-found
  :parent test-artifacts
  (let ((g (poll-artifact-status-from-rows () "task-1")))
    (is string= "not_found" (gen-status g))
    (is string= "task-1" (gen-task-id g))))

(define-test poll-artifact-status-report-completed
  :parent test-artifacts
  (let* ((row (list "r1" "t" +artifact-report+ nil +artifact-completed+))
         (g (poll-artifact-status-from-rows (list row) "r1")))
    (is string= "completed" (gen-status g))
    (is string= "r1" (gen-task-id g))))

(define-test poll-artifact-status-audio-awaiting-media-url
  :parent test-artifacts
  (let* ((row (list "a1" "" +artifact-audio+ nil +artifact-completed+))
         (g (poll-artifact-status-from-rows (list row) "a1")))
    (is string= "in_progress" (gen-status g))))

(define-test poll-artifact-status-failed-with-inline-error
  :parent test-artifacts
  (let* ((row (list "f1" "t" +artifact-report+ "boom" +artifact-failed+))
         (g (poll-artifact-status-from-rows (list row) "f1")))
    (is string= "failed" (gen-status g))
    (is string= "boom" (gen-error g))))

;;; ===========================================================================
;;; Source-id helpers
;;; ===========================================================================

(define-test test-source-ids-triple-shape
  :parent test-artifacts
  (is equal '((("a")) (("b"))) (%source-ids-triple '("a" "b")))
  (is eq () (%source-ids-triple ()))
  (is eq () (%source-ids-triple nil)))

(define-test test-source-ids-double-shape
  :parent test-artifacts
  (is equal '(("a") ("b")) (%source-ids-double '("a" "b")))
  (is eq () (%source-ids-double ()))
  (is eq () (%source-ids-double nil)))

;;; ===========================================================================
;;; Report format config
;;; ===========================================================================

(define-test test-report-format-config-briefing-doc
  :parent test-artifacts
  (let ((cfg (%report-format-config *report-format-briefing-doc* nil nil)))
    (is string= "Briefing Doc" (first cfg))
    (is string= "Key insights and important quotes" (second cfg))
    (true (search "Executive Summary" (third cfg)))))

(define-test test-report-format-config-custom
  :parent test-artifacts
  (let ((cfg (%report-format-config *report-format-custom* "My custom prompt" nil)))
    (is string= "Custom Report" (first cfg))
    (is string= "My custom prompt" (third cfg))))

(define-test test-report-format-config-custom-fallback
  :parent test-artifacts
  (let ((cfg (%report-format-config *report-format-custom* nil nil)))
    (true (search "based on the provided sources" (third cfg)))))

(define-test test-report-format-config-extra-instructions
  :parent test-artifacts
  (let ((cfg (%report-format-config *report-format-briefing-doc* nil "Be concise.")))
    (true (search "Be concise." (third cfg)))
    (true (search "Executive Summary" (third cfg)))))

;;; ===========================================================================
;;; Generate functions — defined
;;; ===========================================================================

(define-test test-generate-audio-defined
  :parent test-artifacts
  (true (fboundp 'generate-audio)))

(define-test test-generate-report-defined
  :parent test-artifacts
  (true (fboundp 'generate-report)))

(define-test test-generate-quiz-defined
  :parent test-artifacts
  (true (fboundp 'generate-quiz)))

(define-test test-generate-flashcards-defined
  :parent test-artifacts
  (true (fboundp 'generate-flashcards)))

(define-test test-generate-video-defined
  :parent test-artifacts
  (true (fboundp 'generate-video)))

(define-test test-generate-video-validation-cinematic-rejects-style-prompt
  :parent test-artifacts
  ;; cinematic + style-prompt → validation-error (no RPC needed — validation happens before call)
  (true (handler-case
            (generate-video nil "nb"
                            :video-format +video-cinematic+
                            :style-prompt "make it pretty")
          (validation-error (e)
            (declare (ignore e))
            t)
          (error () nil))))

(define-test test-generate-infographic-defined
  :parent test-artifacts
  (true (fboundp 'generate-infographic)))

(define-test test-generate-slide-deck-defined
  :parent test-artifacts
  (true (fboundp 'generate-slide-deck)))

(define-test test-generate-data-table-defined
  :parent test-artifacts
  (true (fboundp 'generate-data-table)))

(define-test test-generate-cinematic-video-defined
  :parent test-artifacts
  (true (fboundp 'generate-cinematic-video)))

(define-test test-generate-mind-map-defined
  :parent test-artifacts
  (true (fboundp 'generate-mind-map)))

;;; ===========================================================================
;;; wait-for-artifact helpers
;;; ===========================================================================

(define-test test-now-seconds-returns-float
  :parent test-artifacts
  (let ((t1 (%now-seconds)))
    (sleep 0.05)
    (let ((t2 (%now-seconds)))
      (true (floatp t1))
      (true (floatp t2))
      (true (>= t2 t1)))))

(define-test test-wait-for-artifact-defined
  :parent test-artifacts
  (true (fboundp 'wait-for-artifact)))

;;; ===========================================================================
;;; Download URL validation
;;; ===========================================================================

(define-test test-validate-download-url-accepts-google
  :parent test-artifacts
  (is string= "notebooklm.google.com"
      (%validate-download-url "https://notebooklm.google.com/path/to/file.mp4"))
  (is string= "subdomain.googleapis.com"
      (%validate-download-url "https://subdomain.googleapis.com/download"))
  (is string= "google.com"
      (%validate-download-url "https://google.com/path")))

(define-test test-validate-download-url-accepts-usercontent
  :parent test-artifacts
  (is string= "sub.googleusercontent.com"
      (%validate-download-url "https://sub.googleusercontent.com/image.png")))

(define-test test-validate-download-url-rejects-http
  :parent test-artifacts
  (true (handler-case
            (%validate-download-url "http://notebooklm.google.com/file.mp4")
          (artifact-download-error (e)
            (declare (ignore e))
            t)
          (error () nil))))

(define-test test-validate-download-url-rejects-evil-domain
  :parent test-artifacts
  (true (handler-case
            (%validate-download-url "https://evil.example.com/malware.exe")
          (artifact-download-error (e)
            (declare (ignore e))
            t)
          (error () nil))))

(define-test test-download-url-defined
  :parent test-artifacts
  (true (fboundp '%download-url)))

;;; ===========================================================================
;;; Artifact selection
;;; ===========================================================================

(define-test test-select-artifact-by-id
  :parent test-artifacts
  (let* ((row-1 (list "id-1" "Title 1" 1 nil 3))     ; audio, completed
         (row-2 (list "id-2" "Title 2" 1 nil 3))     ; audio, completed
         (result (%select-artifact (list row-1 row-2) "id-2" "Audio" "audio")))
    (is equal "id-2" (princ-to-string (first result)))))

(define-test test-select-artifact-first-by-timestamp
  :parent test-artifacts
  ;; Newer artifact (larger timestamp at [15][0]) should be selected first
  (let* ((older (list "id-old" "Old" 1 nil 3 nil nil nil nil nil nil nil nil nil nil (list 100)))
         (newer (list "id-new" "New" 1 nil 3 nil nil nil nil nil nil nil nil nil nil (list 200)))
         (result (%select-artifact (list older newer) nil "Audio" "audio")))
    (is equal "id-new" (princ-to-string (first result)))))

(define-test test-select-artifact-signals-not-ready
  :parent test-artifacts
  (true (handler-case
            (%select-artifact nil nil "Audio" "audio")
          (artifact-not-ready-error (e)
            (declare (ignore e))
            t)
          (error () nil))))

;;; ===========================================================================
;;; Cell text extraction
;;; ===========================================================================

(define-test test-extract-cell-text-string
  :parent test-artifacts
  (is string= "hello" (%extract-cell-text "hello")))

(define-test test-extract-cell-text-integer
  :parent test-artifacts
  (is string= "" (%extract-cell-text 42)))

(define-test test-extract-cell-text-nested
  :parent test-artifacts
  (is string= "abc" (%extract-cell-text '("a" 1 "b" 2 "c"))))

;;; ===========================================================================
;;; CSV escape
;;; ===========================================================================

(define-test test-csv-escape-row-simple
  :parent test-artifacts
  (is string= "\"a\",\"b\",\"c\"" (%csv-escape-row '("a" "b" "c"))))

(define-test test-csv-escape-row-with-quotes
  :parent test-artifacts
  (is string= "\"he said \"\"hi\"\"\"" (%csv-escape-row '("he said \"hi\""))))

;;; ===========================================================================
;;; Downloaders — defined
;;; ===========================================================================

(define-test test-download-audio-defined
  :parent test-artifacts
  (true (fboundp 'download-audio)))

(define-test test-download-video-defined
  :parent test-artifacts
  (true (fboundp 'download-video)))

(define-test test-download-infographic-defined
  :parent test-artifacts
  (true (fboundp 'download-infographic)))

(define-test test-download-report-defined
  :parent test-artifacts
  (true (fboundp 'download-report)))

(define-test test-download-data-table-defined
  :parent test-artifacts
  (true (fboundp 'download-data-table)))

(define-test test-download-slide-deck-defined
  :parent test-artifacts
  (true (fboundp 'download-slide-deck)))

(define-test test-define-simple-downloader-expands
  :parent test-artifacts
  (let ((expansion (macroexpand-1 '(define-simple-downloader xxx "test" 99))))
    (true (consp expansion))
    (is eq 'defun (first expansion))
    (true (search "DOWNLOAD" (princ-to-string expansion)))))

;;; ===========================================================================
;;; Interactive content — HTML app-data (quiz / flashcards)
;;; ===========================================================================

(define-test test-html-unescape-minimal-quot
  :parent test-artifacts
  (is string= "\"x\"" (%html-unescape-minimal "&quot;x&quot;"))
  (is string= "a&b" (%html-unescape-minimal "a&amp;b")))

(define-test test-extract-app-data-from-attribute
  :parent test-artifacts
  (let* ((html "<div data-app-data=\"{&quot;quiz&quot;:[{&quot;question&quot;:&quot;Q&quot;}]}\" />")
         (data (%extract-app-data html))
         (quiz (%json-alist-get data "quiz")))
    (true (listp quiz))
    (is = 1 (length quiz))
    (is string= "Q" (%json-alist-get (first quiz) "question"))))

(define-test test-extract-app-data-missing-signals-parse
  :parent test-artifacts
  (true (handler-case
            (%extract-app-data "<html></html>")
          (artifact-parse-error (e)
            (declare (ignore e))
            t)
          (error () nil))))

(define-test test-format-quiz-markdown-shape
  :parent test-artifacts
  (let* ((q `(("question" . "One?")
              ("answerOptions" . ((("text" . "A") ("isCorrect" . nil))
                                  (("text" . "B") ("isCorrect" . t))))))
         (md (%format-quiz-markdown "T" (list q))))
    (true (search "# T" md))
    (true (search "[x] B" md))))

(define-test test-format-flashcards-markdown-shape
  :parent test-artifacts
  (let ((md (%format-flashcards-markdown "Deck"
              (list '(("f" . "front") ("b" . "back"))))))
    (true (search "# Deck" md))
    (true (search "**Q:** front" md))))

(define-test test-download-quiz-flashcards-mind-map-defined
  :parent test-artifacts
  (true (fboundp 'download-quiz))
  (true (fboundp 'download-flashcards))
  (true (fboundp 'download-mind-map)))
