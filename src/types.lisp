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
  (labels ((resolve-entry ()
             (cond
               ((and (listp (first data))
                     (listp (first (first data)))
                     (listp (first (first (first data)))))
                (first (first data)))      ; deeply nested
               ((and (listp (first data))
                     (stringp (first (first data))))
                data)                       ; medium nested
               (t nil))))                   ; flat
    (let ((entry (resolve-entry)))
      (if entry
          (notebooklm-cl.util:with-nested-extract (entry)
              (id (0 0) :type stringp :default "")
              (title (1) :type stringp)
              (url7 (2 7 0) :type stringp)
              (url5 (2 5 0) :type stringp)
              (type-code (2 4) :type integerp)
              (created-at (2 2 0) :type numberp :transform #'parse-timestamp)
            (make-source :id id :title title
                         :url (or url7 url5)
                         :type-code type-code
                         :created-at created-at))
          (notebooklm-cl.util:with-nested-extract (data)
              (id (0) :type stringp :default "")
              (title (1) :type stringp)
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
Structure: [title_str, sources_list, id_str, ..., ..., [..., is_shared_flag, ..., ..., ..., [ts]]]"
  (notebooklm-cl.util:with-nested-extract (data)
      (raw-title (0) :type stringp :default "")
      (sources-list (1) :default nil)
      (id (2) :type stringp :default "")
      (flag (5 1))
      (ts (5 5 0) :type numberp :transform #'parse-timestamp)
    (let ((sources-count (if (listp sources-list) (length sources-list) 0))
          (is-owner (not flag)))
      (make-notebook :id id
                     :title (strip-thought-newline raw-title)
                     :is-owner is-owner
                     :sources-count sources-count
                     :created-at ts))))

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
  (notebooklm-cl.util:with-nested-extract (data)
      (id-raw (0) :default "")
      (title (1) :type stringp :default "")
      (atype (2) :default 0)
      (status (4) :default 0)
      (variant (9 1 0) :type numberp)
      (created-at (15 0) :type numberp :transform #'parse-timestamp)
    (make-artifact :id (if id-raw (princ-to-string id-raw) "")
                   :title title
                   :artifact-type atype
                   :status status
                   :created-at created-at
                   :url (%extract-artifact-url data atype)
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
      (notebooklm-cl.util:with-nested-extract ((first data))
          (id0 (0) :default "")
          (status-code (4) :default nil)
        (make-generation-status
         :task-id (if (listp id0) (princ-to-string (%nths id0 0)) (princ-to-string id0))
         :status (if status-code
                     (notebooklm-cl.rpc.types:artifact-status-to-str status-code)
                     "failed")))
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
  (notebooklm-cl.util:with-nested-extract (data)
      (id-raw (0) :default "")
      (title (1) :type stringp :default "")
      (content (2) :type stringp :default "")
      (created-at (3 0) :type numberp :transform #'parse-timestamp)
    (make-note :id (if id-raw (princ-to-string id-raw) "")
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
  (notebooklm-cl.util:with-nested-extract (data)
      (title (0 1) :type stringp :default "")
      (type-code (0 2 4) :type integerp)
      (url7 (0 2 7 0) :type stringp)
      (url5 (0 2 5 0) :type stringp)
      (content-blocks (3 0) :default nil)
    (let ((content (if content-blocks
                       (format nil "~{~A~^~%~}" (%extract-all-text content-blocks))
                       "")))
      (make-source-fulltext :source-id source-id
                            :title title
                            :content content
                            :type-code type-code
                            :url (or url7 url5)
                            :char-count (length content)))))

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
  (notebooklm-cl.util:with-nested-extract (data)
      (limits-list (0 1) :default nil)
      (notebook-limit (0 1 1) :type integerp)
      (source-limit (0 1 2) :type integerp)
    (flet ((valid-limit (n) (and (integerp n) (not (typep n 'boolean)) (> n 0) n)))
      (make-account-limits
       :notebook-limit (valid-limit notebook-limit)
       :source-limit (valid-limit source-limit)
       :raw-limits (if (listp limits-list) (copy-list limits-list) nil)))))

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
  (notebooklm-cl.util:with-nested-extract (data)
      (email (0) :type stringp :default "")
      (permission (1) :type integerp :default 3)
      (name (3 0) :type stringp)
      (photo-url (3 1) :type stringp)
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
