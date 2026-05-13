(in-package #:notebooklm-cl.types)

;;; ===========================================================================
;;; Macros — reduce boilerplate for repeated patterns
;;; ===========================================================================

(defmacro define-status-predicate (name accessor-or-body &optional value)
  "Define (NAME obj) predicate.  Three-arg form: (= (ACCESSOR obj) VALUE) —
uses = for numbers, string= for strings.  Two-arg form: BODY is the predicate
form with 'obj' bound to the argument (for compound predicates)."
  `(defun ,name (obj)
     ,(if value
          (let ((test (cond ((numberp value) '=)
                            ((stringp value) 'string=)
                            (t 'eql))))
            `(,test (,accessor-or-body obj) ,value))
          accessor-or-body)))

(defmacro define-plist-constructor (name make-fn docstring &rest slots)
  "Define (NAME data) → MAKE-FN extracting each SLOT from the plist DATA.
Each SLOT is (keyword &optional default).  When a default is given the getf
result is wrapped in (or … default)."
  (let ((args
         (loop for (key . rest) in slots
               for default = (first rest)
               nconc (if default
                         (list key `(or (getf data ,key) ,default))
                         (list key `(getf data ,key))))))
    `(defun ,name (data)
       ,docstring
       (,make-fn ,@args))))

(defmacro define-print-object (struct-type (fmt &rest accessors))
  `(defmethod print-object ((obj ,struct-type) stream)
     (print-unreadable-object (obj stream :type t)
       (format stream ,fmt ,@(loop for a in accessors collect `(,a obj))))))

;;; ===========================================================================
;;; Code-mapper macro — defines an alist + lookup function in one form
;;; ===========================================================================

(defmacro define-code-mapper (function-name map-var &body mappings)
  "Define MAP-VAR (a parameter holding an alist) and FUNCTION-NAME(CODE)
that looks up CODE in MAP-VAR and returns the string value, or \"unknown\"
if CODE is NIL or not found.

Each MAPPING is (CODE STRING).

Example:
  (define-code-mapper source-type-code-to-kind *source-type-code-map*
    (1 \"google_docs\")
    (2 \"google_slides\"))
  → (source-type-code-to-kind 1) => \"google_docs\"
    (source-type-code-to-kind nil) => \"unknown\"
    (source-type-code-to-kind 99) => \"unknown\""
  `(progn
     (defparameter ,map-var
       ',(loop for (k v) in mappings collect (cons k v)))
     (defun ,function-name (code &optional (default "unknown"))
       (if code
           (let ((entry (assoc code ,map-var)))
             (if entry (cdr entry) default))
           default))))

;;; Helper: simple URL detection (avoids external dependency)
(defun %url-string-p (s)
  (and s (stringp s)
       (or (and (>= (length s) 7) (string= s "http://" :end1 7))
           (and (>= (length s) 8) (string= s "https://" :end1 8)))))

;;; ===========================================================================
;;; Source-type code → string mapping
;;; ===========================================================================

(define-code-mapper source-type-code-to-kind *source-type-code-map*
  (1 "google_docs")
  (2 "google_slides")
  (3 "pdf")
  (4 "pasted_text")
  (5 "web_page")
  (8 "markdown")
  (9 "youtube")
  (10 "media")
  (11 "docx")
  (13 "image")
  (14 "google_spreadsheet")
  (16 "csv")
  (17 "epub"))

;;; ===========================================================================
;;; Artifact-type code + variant → kind string mapping
;;; ===========================================================================

(define-code-mapper artifact-type-code-to-kind *artifact-type-code-map*
  (1 "audio")
  (2 "report")
  (3 "video")
  (5 "mind_map")
  (7 "infographic")
  (8 "slide_deck")
  (9 "data_table"))

(defun artifact-type-to-kind (type-code variant)
  "Convert an artifact type-code + variant to a kind string.
Type 4 with variant 1 → flashcards, variant 2 → quiz."
  (cond
    ((= type-code 4)
     (if (= variant 1) "flashcards"
         (if (= variant 2) "quiz"
             "unknown")))
    (t (artifact-type-code-to-kind type-code))))

;;; ===========================================================================
;;; Helper: strip "thought\n" from notebook titles
;;; ===========================================================================

(defun strip-thought-newline (s)
  "Remove all occurrences of 'thought\n' from string S, then trim whitespace.
'thought' is 7 chars; the newline is the 8th."
  (let ((result (make-array (length s) :element-type 'character :fill-pointer 0 :adjustable t)))
    (loop with i = 0
          while (< i (length s))
          do (if (and (<= (+ i 8) (length s))
                      (string= s "thought" :start1 i :end1 (+ i 7))
                      (char= (char s (+ i 7)) #\Newline))
                 (incf i 8)
                 (progn (vector-push-extend (char s i) result)
                        (incf i))))
    (string-trim " " result)))

;;; ===========================================================================
;;; Helper: timestamp → CL universal-time (or nil)
;;; ===========================================================================

(defun parse-timestamp (value)
  "Convert an API seconds timestamp to a CL universal-time. Returns NIL on failure."
  ;; The API provides epoch seconds as an integer or float.
  ;; Common Lisp universal-time is seconds since 1900-01-01.
  (and (numberp value)
       (not (minusp value))
       ;; Simple sanity check: must be after 2000-01-01
       (>= value 946684800)
       (ignore-errors
         ;; Convert Unix epoch (1970-01-01) to CL universal time (1900-01-01).
         ;; The difference is 70 years ≈ 2208988800 seconds.
         ;; But CL universal-time counts from 1900-01-01 00:00:00 UTC.
         ;; Actually, CL universal-time is seconds from 1900-01-01.
         ;; Unix epoch is 1970-01-01. Difference is exactly 2208988800 seconds
         ;; for years 1900-1970 inclusive (note: no leap seconds in this calc).
         ;; However, we just store the raw epoch seconds since the rest of the
         ;; codebase doesn't convert to readable dates.
         value)))

;;; ===========================================================================
;;; Source
;;; ===========================================================================

(defstruct (source (:conc-name source-))
  (id "" :type string)
  (title nil :type (or null string))
  (url nil :type (or null string))
  (type-code nil :type (or null integer))
  (created-at nil :type (or null real))
  (status 2 :type integer))           ; default READY

(defun source-kind (src)
  "Get the user-facing source kind as a string."
  (source-type-code-to-kind (source-type-code src)))

(define-status-predicate source-is-ready-p source-status 2)
(define-status-predicate source-is-processing-p source-status 1)
(define-status-predicate source-is-error-p source-status 3)

(defun source-from-api-response (data)
  "Parse a Source from a raw API response list.
Handles deeply-nested [[[['id'], 'title', metadata]]], medium-nested
[[['id'], 'title', metadata]], and flat ['id', 'title'] formats."
  (unless (and data (listp data))
    (error "Invalid source data: ~S" data))
  (labels
      ((extract-first-string (x)
         (if (and (listp x) x (stringp (first x)))
             (first x)
             nil))
       (extract-url (metadata)
         (let ((url (%nths metadata 7 0)))
           (when (stringp url)
             (return-from extract-url url)))
         (let ((url (%nths metadata 5 0)))
           (when (stringp url)
             (return-from extract-url url)))
         nil)
       (extract-type-code (metadata)
         (let ((tc (%nths metadata 4)))
           (when (integerp tc) tc)))
       (extract-created-at (metadata)
         (let ((ts (%nths metadata 2 0)))
           (when (numberp ts) (parse-timestamp ts))))
       ;; Normalize the three nesting shapes to a single entry.
       (resolve-entry ()
         (cond
           ;; Deeply nested: [[[['id'], 'title', metadata, ...]]]
           ((and (listp (first data))
                 (listp (first (first data)))
                 (listp (first (first (first data)))))
            (first (first data)))
           ;; Medium nested: data IS the entry [[['id'], 'title', metadata]]
           ((and (listp (first data))
                 (stringp (first (first data))))
            data)
           ;; Flat format: no metadata at all
           (t nil))))
    (let ((entry (resolve-entry)))
      (if entry
          (let* ((id (extract-first-string (first entry)))
                 (title (if (stringp (%nths entry 1)) (%nths entry 1) nil))
                 (metadata (%nths entry 2)))
            (make-source :id (or id "")
                         :title title
                         :url (extract-url metadata)
                         :type-code (extract-type-code metadata)
                         :created-at (extract-created-at metadata)))
          ;; Flat format: [id, title]
          (let ((id (if (stringp (%nths data 0)) (%nths data 0) ""))
                (title (if (stringp (%nths data 1)) (%nths data 1) nil)))
            (make-source :id id :title title))))))

;;; ===========================================================================
;;; Notebook
;;; ===========================================================================

(defstruct (notebook (:conc-name notebook-))
  (id "" :type string)
  (title "" :type string)
  (is-owner t :type boolean)
  (sources-count 0 :type integer)
  (created-at nil :type (or null real)))

(defun notebook-from-api-response (data)
  "Parse a Notebook from a raw API response list.
Structure: [title_str, sources_list, id_str, ..., ..., [..., ..., ..., ..., ..., [ts]]]"
  (let* ((raw-title (if (stringp (%nths data 0)) (%nths data 0) ""))
         (title (strip-thought-newline raw-title))
         (sources-list (%nths data 1))
         (sources-count (if (listp sources-list) (length sources-list) 0))
         (id (if (stringp (%nths data 2)) (%nths data 2) ""))
         (created-at nil)
         (is-owner t))
    ;; data[5] structure: [..., is_shared_flag, ..., ..., ..., [ts]]
    (let ((meta (%nths data 5)))
      (when meta
        ;; data[5][1] = False means owner, True means shared
        (setf is-owner (not (%nths meta 1)))
        (let ((ts (%nths meta 5 0)))
          (when (numberp ts)
            (setf created-at (parse-timestamp ts))))))
    (make-notebook :id id
                   :title title
                   :is-owner is-owner
                   :sources-count sources-count
                   :created-at created-at)))

;;; ===========================================================================
;;; SuggestedTopic
;;; ===========================================================================

(defstruct (suggested-topic (:conc-name topic-))
  (question "" :type string)
  (prompt "" :type string))

;;; ===========================================================================
;;; NotebookDescription
;;; ===========================================================================

(defstruct (notebook-description (:conc-name description-))
  (summary "" :type string)
  (suggested-topics nil :type list))

(defun notebook-description-from-api-response (data)
  "Parse a NotebookDescription from the summarize RPC response dict."
  (let ((summary (or (cdr (assoc :summary data :test #'eq)) ""))
        (topics '()))
    (dolist (t-entry (or (cdr (assoc :suggested--topics data :test #'eq)) nil))
      (push (make-suggested-topic
             :question (or (cdr (assoc :question t-entry :test #'eq)) "")
             :prompt (or (cdr (assoc :prompt t-entry :test #'eq)) ""))
            topics))
    (make-notebook-description :summary summary
                               :suggested-topics (nreverse topics))))

;;; ===========================================================================
;;; SourceSummary
;;; ===========================================================================

(defstruct (source-summary (:conc-name ss-))
  (kind "" :type string)
  (title nil :type (or null string))
  (url nil :type (or null string)))

;;; ===========================================================================
;;; NotebookMetadata
;;; ===========================================================================

(defstruct (notebook-metadata (:conc-name nb-meta-))
  (notebook nil :type (or null notebook))
  (sources nil :type list))

(defun notebook-metadata-from-api-response (notebook sources)
  "Create a NotebookMetadata from a notebook and a list of source summaries."
  (make-notebook-metadata :notebook notebook :sources sources))

;;; ===========================================================================
;;; Artifact
;;; ===========================================================================

(defstruct (artifact (:conc-name art-))
  (id "" :type string)
  (title "" :type string)
  (artifact-type 0 :type integer)      ; internal type code
  (status 0 :type integer)
  (created-at nil :type (or null real))
  (url nil :type (or null string))
  (variant nil :type (or null integer)))

(defun artifact-kind (art)
  "Get the user-facing artifact kind as a string."
  (artifact-type-to-kind (art-artifact-type art) (art-variant art)))

(define-status-predicate artifact-is-completed-p art-status 3)
(define-status-predicate artifact-is-processing-p art-status 1)
(define-status-predicate artifact-is-pending-p art-status 2)
(define-status-predicate artifact-is-failed-p art-status 4)

(define-status-predicate artifact-is-quiz-p
    (and (= (art-artifact-type obj) 4) (= (art-variant obj) 2)))
(define-status-predicate artifact-is-flashcards-p
    (and (= (art-artifact-type obj) 4) (= (art-variant obj) 1)))

(defun artifact-status-str (art)
  (notebooklm-cl.rpc.types:artifact-status-to-str (art-status art)))

(defun %find-media-url (media-lists preferred-mime)
  "Find best URL in MEDIA-LISTS (list-of-lists of [url, ?, mime] entries).
Phase 1: return first URL whose MIME matches PREFERRED-MIME.
Phase 2: fallback to the first HTTP URL found."
  (flet ((urlp (x) (and (listp x) (%url-string-p (first x)))))
    (dolist (ml media-lists)
      (when (listp ml)
        (dolist (item ml)
          (when (and (urlp item) (>= (length item) 3)
                     (string= (third item) preferred-mime))
            (return-from %find-media-url (first item))))))
    (dolist (ml media-lists)
      (when (listp ml)
        (dolist (item ml)
          (when (urlp item)
            (return-from %find-media-url (first item)))))))
  nil)

(defun %extract-audio-url (data)
  "Extract audio download URL from artifact data at data[6][5][*][0]."
  (let ((media-container (%nths data 5)))  ; data[5] (0-indexed)
    (when media-container
      (let ((media-list (%nths media-container 5)))
        (when media-list
          (%find-media-url (list media-list) "audio/mp4"))))))

(defun %extract-video-url (data)
  "Extract video download URL from artifact data at data[8][*][*][0]."
  (let ((media-lists (%nths data 8)))
    (when media-lists
      (%find-media-url media-lists "video/mp4"))))

(defun %extract-infographic-url (data)
  "Extract infographic download URL from artifact data."
  (dolist (item data)
    (when (listp item)
      (let ((content (%nths item 2)))
        (when (listp content)
          (let* ((inner (first content))
                 (img-data (%nths inner 1)))
            (when (and (listp img-data) (%url-string-p (%nths img-data 0)))
              (return-from %extract-infographic-url (%nths img-data 0))))))))
  nil)

(defun %extract-slide-deck-pdf-url (data)
  "Extract slide deck PDF URL from artifact data at data[16][3]."
  (let ((url (%nths data 16 3)))
    (when (%url-string-p url) url)))

(defun %extract-artifact-url (data atype)
  "Extract a public download URL from known artifact response shapes."
  (cond
    ((= atype notebooklm-cl.rpc.types:+artifact-audio+) (%extract-audio-url data))
    ((= atype notebooklm-cl.rpc.types:+artifact-video+) (%extract-video-url data))
    ((= atype notebooklm-cl.rpc.types:+artifact-infographic+) (%extract-infographic-url data))
    ((= atype notebooklm-cl.rpc.types:+artifact-slide-deck+) (%extract-slide-deck-pdf-url data))
    (t nil)))

(defun artifact-from-api-response (data)
  "Parse an Artifact from a raw API response list.
Structure: [id, title, type, ..., status, ..., metadata, ...]
Position 9 contains options with variant code at [9][1][0]."
  (let* ((id (if (%nths data 0) (princ-to-string (%nths data 0)) ""))
         (title (if (stringp (%nths data 1)) (%nths data 1) ""))
         (atype (or (%nths data 2) 0))
         (status (or (%nths data 4) 0))
         (created-at nil)
         (variant nil)
         (url nil))
    ;; Extract timestamp from data[15][0]
    (let ((ts (%nths data 15 0)))
      (when (numberp ts)
        (setf created-at (parse-timestamp ts))))
    ;; Extract variant from data[9][1][0]
    (let ((v (%nths data 9 1 0)))
      (when (numberp v)
        (setf variant v)))
    ;; Extract download URL
    (setf url (%extract-artifact-url data atype))
    (make-artifact :id id
                   :title title
                   :artifact-type atype
                   :status status
                   :created-at created-at
                   :url url
                   :variant variant)))

;;; ===========================================================================
;;; GenerationStatus
;;; ===========================================================================

(defstruct (generation-status (:conc-name gen-))
  (task-id "" :type string)
  (status "" :type string)             ; "pending", "in_progress", "completed", "failed", "not_found"
  (url nil :type (or null string))
  (error nil :type (or null string))
  (error-code nil :type (or null string))
  (metadata nil :type list))

(define-status-predicate generation-is-complete-p gen-status "completed")
(define-status-predicate generation-is-failed-p gen-status "failed")
(define-status-predicate generation-is-pending-p gen-status "pending")

(defun generation-status-from-api-response (data)
  "Parse a GenerationStatus from a create-artifact RPC response.
The API returns a single ID at [0][0] that serves as both task_id and artifact_id.
Status code is at [0][4]."
  (if (and data (listp data) (listp (first data)))
      (let* ((artifact-data (first data))
             (task-id (let ((id0 (%nths artifact-data 0)))
                        (if (listp id0)
                            (princ-to-string (%nths id0 0))
                            (princ-to-string id0))))
             (status-code (%nths artifact-data 4))
             (status (if status-code
                         (notebooklm-cl.rpc.types:artifact-status-to-str status-code)
                         "failed")))
        (make-generation-status :task-id task-id :status status))
      (make-generation-status :task-id ""
                              :status "failed"
                              :error "Generation failed - no artifact_id returned")))

;;; ===========================================================================
;;; Note
;;; ===========================================================================

(defstruct (note (:conc-name note-))
  (id "" :type string)
  (notebook-id "" :type string)
  (title "" :type string)
  (content "" :type string)
  (created-at nil :type (or null real)))

(defun note-from-api-response (data notebook-id)
  "Parse a Note from a raw API response list.
Structure: [id, title, content, [ts], ...]"
  (let* ((id (if (%nths data 0) (princ-to-string (%nths data 0)) ""))
         (title (if (stringp (%nths data 1)) (%nths data 1) ""))
         (content (if (stringp (%nths data 2)) (%nths data 2) ""))
         (created-at nil))
    (let ((ts (%nths data 3 0)))
      (when (numberp ts)
        (setf created-at (parse-timestamp ts))))
    (make-note :id id
               :notebook-id notebook-id
               :title title
               :content content
               :created-at created-at)))

;;; ===========================================================================
;;; SourceFulltext
;;; ===========================================================================

(defstruct (source-fulltext (:conc-name sf-))
  (source-id "" :type string)
  (title "" :type string)
  (content "" :type string)
  (type-code nil :type (or null integer))
  (url nil :type (or null string))
  (char-count 0 :type integer))

(defun source-fulltext-kind (sf)
  (source-type-code-to-kind (sf-type-code sf)))

(defun source-fulltext-from-api-response (data source-id)
  "Parse a SourceFulltext from GET_SOURCE RPC response.
Format: [[title, metadata, ...], ..., ..., [content_blocks], ...]
Title is at result[0][1]; type-code at result[0][2][4]; URL at result[0][2][7] or [5].
Plaintext content at result[3][0]; markdown at result[4][1]."
  (let ((title "")
        (type-code nil)
        (url nil)
        (content ""))
    (when (and data (listp data) (listp (first data)))
      (let ((header (first data)))
        (let ((h1 (%nths header 1)))
          (when (stringp h1)
            (setf title h1)))
        (let ((metadata (%nths header 2)))
          (when metadata
            (let ((tc (%nths metadata 4)))
              (when (integerp tc)
                (setf type-code tc)))
            ;; Try metadata[7][0] then metadata[5][0] for URL
            (let ((u (%nths metadata 7 0)))
              (when (stringp u)
                (setf url u)))
            (unless url
              (let ((u (%nths metadata 5 0)))
                (when (stringp u)
                  (setf url u)))))))
      ;; Plaintext content at result[3][0]
      (let ((content-blocks (%nths data 3 0)))
        (when content-blocks
          (setf content (format nil "~{~A~^~%~}" (%extract-all-text content-blocks))))))
    (make-source-fulltext :source-id source-id
                          :title title
                          :content content
                          :type-code type-code
                          :url url
                          :char-count (length content))))

(defun %extract-all-text (data &optional (max-depth 100))
  "Recursively extract all text strings from nested arrays."
  (let ((texts nil))
    (labels ((walk (d depth)
               (when (and (> depth 0) (listp d))
                 (dolist (item d)
                   (typecase item
                     (string (when (plusp (length (string-trim " " item)))
                               (push (string-trim " " item) texts)))
                     (list (walk item (1- depth))))))))
      (walk data max-depth))
    (nreverse texts)))

;;; ===========================================================================
;;; AccountLimits
;;; ===========================================================================

(defstruct (account-limits (:conc-name limits-))
  (notebook-limit nil :type (or null integer))
  (source-limit nil :type (or null integer))
  (raw-limits nil :type list))

;;; ===========================================================================
;;; AccountTier
;;; ===========================================================================

(defstruct (account-tier (:conc-name tier-))
  (tier nil :type (or null string))
  (plan-name nil :type (or null string)))

(defun account-limits-from-api-response (data)
  "Parse AccountLimits from GET_USER_SETTINGS response data.
Limits are at data[0][1] with notebook limit at [1] and source limit at [2]."
  (let ((notebook-limit nil)
        (source-limit nil)
        (raw-limits nil))
    (when (and data (listp data) (listp (first data)))
      (let ((limits-list (%nths data 0 1)))
        (when (listp limits-list)
          (setf raw-limits (copy-list limits-list))
          (let ((nl (%nths limits-list 1)))
            (when (and (integerp nl) (not (typep nl 'boolean)) (> nl 0))
              (setf notebook-limit nl)))
          (let ((sl (%nths limits-list 2)))
            (when (and (integerp sl) (not (typep sl 'boolean)) (> sl 0))
              (setf source-limit sl))))))
    (make-account-limits :notebook-limit notebook-limit
                         :source-limit source-limit
                         :raw-limits raw-limits)))

;;; ===========================================================================
;;; ChatReference
;;; ===========================================================================

(defstruct (chat-reference (:conc-name ref-))
  (source-id "" :type string)
  (cited-text nil :type (or null string))
  (citation-number nil :type (or null integer))
  (start-char nil :type (or null integer))
  (end-char nil :type (or null integer))
  (chunk-id nil :type (or null string)))

(define-plist-constructor chat-reference-from-api-response make-chat-reference
  "Parse a ChatReference from parsed chat response citation data.
data is a plist or alist with keys :source-id, :cited-text, :citation-number,
:start-char, :end-char, and :chunk-id."
  (:source-id "")
  (:cited-text)
  (:citation-number)
  (:start-char)
  (:end-char)
  (:chunk-id))

;;; ===========================================================================
;;; ConversationTurn
;;; ===========================================================================

(defstruct (conversation-turn (:conc-name turn-))
  (query "" :type string)
  (answer "" :type string)
  (turn-number 0 :type integer)
  (references nil :type list))          ; list of chat-reference

(define-plist-constructor conversation-turn-from-api-response make-conversation-turn
  "Parse a ConversationTurn from a conversation turn plist."
  (:query "")
  (:answer "")
  (:turn-number 0)
  (:references))

;;; ===========================================================================
;;; AskResult
;;; ===========================================================================

(defstruct (ask-result (:conc-name ask-))
  (answer "" :type string)
  (conversation-id "" :type string)
  (turn-number 0 :type integer)
  (is-follow-up nil :type boolean)
  (references nil :type list)           ; list of chat-reference
  (raw-response "" :type string))

(define-plist-constructor ask-result-from-api-response make-ask-result
  "Parse an AskResult from a chat response plist."
  (:answer "")
  (:conversation-id "")
  (:turn-number 0)
  (:is-follow-up)
  (:references)
  (:raw-response ""))

;;; ===========================================================================
;;; SharedUser
;;; ===========================================================================

(defstruct (shared-user (:conc-name su-))
  (email "" :type string)
  (name nil :type (or null string))
  (permission 3 :type integer)          ; default VIEWER
  (photo-url nil :type (or null string)))

(defun shared-user-from-api-response (data)
  "Parse a SharedUser from API response entry.
Format: [email, permission, [], [name, avatar]]"
  (let* ((email (if (stringp (%nths data 0)) (%nths data 0) ""))
         (permission (let ((p (%nths data 1))) (if (integerp p) p 3)))
         (name nil)
         (photo-url nil))
    (let ((user-info (%nths data 3)))
      (when user-info
        (let ((n (%nths user-info 0))) (when (stringp n) (setf name n)))
        (let ((p (%nths user-info 1))) (when (stringp p) (setf photo-url p)))))
    (make-shared-user :email email
                      :name name
                      :permission permission
                      :photo-url photo-url)))

;;; ===========================================================================
;;; ShareStatus
;;; ===========================================================================

(defstruct (share-status (:conc-name share-))
  (notebook-id "" :type string)
  (public nil :type boolean)
  (access-level 0 :type integer)        ; 0=restricted, 1=anyone-with-link
  (view-level 0 :type integer)          ; 0=full-notebook, 1=chat-only
  (users nil :type list)                ; list of shared-user
  (share-url nil :type (or null string)))

(defun share-status-from-api-response (data notebook-id)
  "Parse a ShareStatus from GET_SHARE_STATUS response.
Format: [[[user_entries]], [is_public], 1000]"
  (let* ((users '())
         (is-public nil))
    ;; Parse users from [0]
    (when (and data (listp (first data)))
      (dolist (user-data (first data))
        (when (listp user-data)
          (push (shared-user-from-api-response user-data) users))))
    ;; Parse is_public from [1]
    (let ((pub-data (%nths data 1)))
      (when pub-data
        (setf is-public (not (null (first pub-data))))))
    (let ((access (if is-public 1 0))
          (view-level 0)
          (share-url (if is-public
                         (format nil "~A/notebook/~A"
                                 (notebooklm-cl.env:get-base-url)
                                 notebook-id)
                         nil)))
      (make-share-status :notebook-id notebook-id
                         :public is-public
                         :access-level access
                         :view-level view-level
                         :users (nreverse users)
                         :share-url share-url))))

;;; ===========================================================================
;;; ReportSuggestion
;;; ===========================================================================

(defstruct (report-suggestion (:conc-name rs-))
  (title "" :type string)
  (description "" :type string)
  (prompt "" :type string)
  (audience-level 2 :type integer))

(define-plist-constructor report-suggestion-from-api-response make-report-suggestion
  "Parse a ReportSuggestion from the get_suggested_report_formats response item.
data is a plist with keys :title, :description, :prompt, :audience-level."
  (:title "")
  (:description "")
  (:prompt "")
  (:audience-level 2))

;;; ===========================================================================
;;; Print-object methods for readability
;;; ===========================================================================

(define-print-object source
    ("~A ~S kind=~A status=~D" source-id source-title source-kind source-status))
(define-print-object notebook
    ("~A ~S sources=~D" notebook-id notebook-title notebook-sources-count))
(define-print-object artifact
    ("~A ~S kind=~A status=~D" art-id art-title artifact-kind art-status))
(define-print-object generation-status
    ("~A ~A" gen-task-id gen-status))
(define-print-object note
    ("~A ~S" note-id note-title))
