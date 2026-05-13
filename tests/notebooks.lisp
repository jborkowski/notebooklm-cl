;;; ===========================================================================
;;; Notebooks — pure helpers and API response parsing functions
;;; ===========================================================================

(in-package #:notebooklm-cl.tests)

;;; ===========================================================================
;;; Tests for notebooks.lisp helper functions.
;;; Note: RPC-calling functions (list-notebooks, create-notebook, etc.)
;;; require a live HTTP client so are integration-tested separately.
;;; Pure helpers are tested here.
;;; ===========================================================================

(define-test test-notebooks
  :parent test-suite)

;;; --- source-path and URL helpers ---

(define-test test-notebook-source-path
  :parent test-notebooks
  ;; %notebook-source-path is a local function in notebooks.lisp — not exported.
  ;; However its logic is simple: (format nil "/notebook/~A" notebook-id).
  ;; Test via the public functions that use it:
  ;; get-share-url uses %notebook-url which uses %notebook-source-path
  (let* ((cc (notebooklm-cl.core:make-client-core))
         (url (notebooklm-cl.notebooks:get-share-url cc "abc-123")))
    (true (search "/notebook/abc-123" url))
    (true (starts-with-p url "https://"))))

(define-test test-get-share-url
  :parent test-notebooks
  (let* ((cc (notebooklm-cl.core:make-client-core))
         (url (notebooklm-cl.notebooks:get-share-url cc "nb-42")))
    (is string= "https://notebooklm.google.com/notebook/nb-42" url)))

(define-test test-get-share-url-with-artifact
  :parent test-notebooks
  (let* ((cc (notebooklm-cl.core:make-client-core))
         (url (notebooklm-cl.notebooks:get-share-url cc "nb-42" "art-7")))
    (is string= "https://notebooklm.google.com/notebook/nb-42?artifactId=art-7" url)))

;;; --- get-summary — can be tested with fixture-like simulated result ---
;;; NOTE: get-summary calls rpc-call internally; here we test the parsing
;;; path directly by using notebook-description-from-api-response

(define-test test-notebook-get-summary-parsing
  :parent test-notebooks
  ;; The get-summary function converts result to string.
  ;; We can test the same data path via notebook-description-from-api-response
  ;; which uses the same result format.
  (let ((desc (notebook-description-from-api-response
               '((:summary . "A test summary")
                 (:suggested--topics nil)))))
    (is string= "A test summary" (description-summary desc))))

;;; --- get-description parsing ---

(define-test test-notebook-get-description-parsing
  :parent test-notebooks
  (let ((desc (notebook-description-from-api-response
               '((:summary . "Learning about CL")
                 (:suggested--topics
                  ((:question . "What is Common Lisp?")
                   (:prompt . "Write about the history of Common Lisp"))
                  ((:question . "Why use Lisp?")
                   (:prompt . "Benefits and use cases")))))))
    (is string= "Learning about CL" (description-summary desc))
    (is = 2 (length (description-suggested-topics desc)))
    (let ((t1 (first (description-suggested-topics desc)))
          (t2 (second (description-suggested-topics desc))))
      (is string= "What is Common Lisp?" (topic-question t1))
      (is string= "Write about the history of Common Lisp" (topic-prompt t1))
      (is string= "Why use Lisp?" (topic-question t2))
      (is string= "Benefits and use cases" (topic-prompt t2)))))

;;; --- get-description with empty topics ---

(define-test test-notebook-get-description-empty-topics
  :parent test-notebooks
  (let ((desc (notebook-description-from-api-response
               '((:summary . "Summary only") (:suggested--topics . nil)))))
    (is string= "Summary only" (description-summary desc))
    (is = 0 (length (description-suggested-topics desc)))))

;;; --- get-description with missing summary ---

(define-test test-notebook-get-description-no-summary
  :parent test-notebooks
  (let ((desc (notebook-description-from-api-response
               '((:suggested--topics nil)))))
    (is string= "" (description-summary desc))))

;;; --- get-metadata ---

(define-test test-notebook-get-metadata
  :parent test-notebooks
  ;; Make metadata directly — get-metadata calls get-notebook internally
  (let* ((nb (make-notebook :id "nb-1" :title "Test" :sources-count 2))
         (meta (make-notebook-metadata :notebook nb :sources nil)))
    (is string= "nb-1" (notebook-id (nb-meta-notebook meta)))
    (is string= "Test" (notebook-title (nb-meta-notebook meta)))
    (is = 2 (notebook-sources-count (nb-meta-notebook meta)))
    (is eq nil (nb-meta-sources meta))))

;;; --- share-notebook URL generation (unit-test the URL logic) ---
;;; NOTE: share-notebook makes an RPC call, but the URL it generates can be
;;; tested via get-share-url.

(define-test test-share-notebook-url-logic
  :parent test-notebooks
  ;; Public share with artifact
  (let* ((cc (notebooklm-cl.core:make-client-core))
         (url (notebooklm-cl.notebooks:get-share-url cc "nb-1" "art-2")))
    (is string= "https://notebooklm.google.com/notebook/nb-1?artifactId=art-2" url))
  ;; Public share without artifact
  (let* ((cc (notebooklm-cl.core:make-client-core))
         (url (notebooklm-cl.notebooks:get-share-url cc "nb-1")))
    (is string= "https://notebooklm.google.com/notebook/nb-1" url)))
