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

;;; Helper: simple URL detection (avoids external dependency)
(defun %url-string-p (s)
  (and s (stringp s)
       (or (and (>= (length s) 7) (string= s "http://" :end1 7))
           (and (>= (length s) 8) (string= s "https://" :end1 8)))))

;;; ===========================================================================
;;; Source-type code → string mapping
;;; ===========================================================================

(defparameter *source-type-code-map*
  '((1 . "google_docs")
    (2 . "google_slides")
    (3 . "pdf")
    (4 . "pasted_text")
    (5 . "web_page")
    (8 . "markdown")
    (9 . "youtube")
    (10 . "media")
    (11 . "docx")
    (13 . "image")
    (14 . "google_spreadsheet")
    (16 . "csv")
    (17 . "epub")))

(defun source-type-code-to-kind (code)
  "Convert an internal source type-code integer to a kind string."
  (if code
      (let ((entry (assoc code *source-type-code-map*)))
        (if entry (cdr entry) "unknown"))
      "unknown"))

;;; ===========================================================================
;;; Artifact-type code + variant → kind string mapping
;;; ===========================================================================

(defparameter *artifact-type-code-map*
  '((1 . "audio")
    (2 . "report")
    (3 . "video")
    (5 . "mind_map")
    (7 . "infographic")
    (8 . "slide_deck")
    (9 . "data_table")))

(defun artifact-type-to-kind (type-code variant)
  "Convert an artifact type-code + variant to a kind string.
Type 4 with variant 1 → flashcards, variant 2 → quiz."
  (cond
    ((= type-code 4)
     (if (= variant 1) "flashcards"
         (if (= variant 2) "quiz"
             "unknown")))
    (t (let ((entry (assoc type-code *artifact-type-code-map*)))
         (if entry (cdr entry) "unknown")))))

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
         (when (and (listp metadata) (>= (length metadata) 8))
           (let ((url-list (nth 7 metadata))) ; metadata[7]
             (when (and (listp url-list) url-list (stringp (first url-list)))
               (return-from extract-url (first url-list)))))
         (when (and (listp metadata) (>= (length metadata) 6))
           (let ((yt-data (nth 5 metadata)))  ; metadata[5]
             (when (and (listp yt-data) yt-data (stringp (first yt-data)))
               (return-from extract-url (first yt-data)))))
         nil)
       (extract-type-code (metadata)
         (when (and (listp metadata) (>= (length metadata) 5)
                    (integerp (fifth metadata))) ; metadata[4]
           (fifth metadata)))
       (extract-created-at (metadata)
         (when (and (listp metadata) (>= (length metadata) 3))
           (let ((ts-list (third metadata)))   ; metadata[2]
             (when (and (listp ts-list) ts-list (numberp (first ts-list)))
               (parse-timestamp (first ts-list)))))))
    ;; Check if deeply nested: data[0][0][0] is a list
    (if (and (listp (first data))
             (listp (first (first data)))
             (listp (first (first (first data)))))
        ;; Deeply nested: [[[['id'], 'title', metadata, ...]]]
        (let* ((entry (first (first data)))
               (id (extract-first-string (first entry)))
               (title (if (and (>= (length entry) 2) (stringp (second entry)))
                          (second entry) nil))
               (metadata (if (and (>= (length entry) 3) (listp (third entry)))
                             (third entry) nil)))
          (make-source :id (or id "")
                       :title title
                       :url (extract-url metadata)
                       :type-code (extract-type-code metadata)
                       :created-at (extract-created-at metadata)))
        ;; Check if medium nested: data[0][0] is a string or list...
        ;; Actually: medium nested is [[['id'], 'title', metadata], ...]
        ;; data[0] = ['id']→string, or data[0][0] = list with string
        ;; Medium nested: data is the entry itself: [['id'], 'title', metadata]
        ;; Check: (first entry) is a list containing a string (the id)
        (if (and (listp (first data))
                 (stringp (first (first data))))
            ;; Medium nested — data IS the entry
            (let* ((entry data)
                   (id (if (stringp (first entry))
                           (first entry)
                           (extract-first-string (first entry))))
                   (title (if (and (>= (length entry) 2) (stringp (second entry)))
                              (second entry) nil))
                   (metadata (if (and (>= (length entry) 3) (listp (third entry)))
                                 (third entry) nil)))
              (make-source :id (or id "")
                           :title title
                           :url (extract-url metadata)
                           :type-code (extract-type-code metadata)
                           :created-at (extract-created-at metadata)))
            ;; Flat format: [id, title]
            (let ((id (if (and data (stringp (first data))) (first data) ""))
                  (title (if (and (>= (length data) 2) (stringp (second data)))
                             (second data) nil)))
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
  (let* ((raw-title (if (and (>= (length data) 1) (stringp (first data)))
                        (first data) ""))
         (title (strip-thought-newline raw-title))
         (sources-list (if (>= (length data) 2) (second data) nil))
         (sources-count (if (listp sources-list) (length sources-list) 0))
         (id (if (and (>= (length data) 3) (stringp (third data)))
                 (third data) ""))
         (created-at nil)
         (is-owner t))
    ;; data[5] structure: [..., is_shared_flag, ..., ..., ..., [ts]]
    (when (and (>= (length data) 6) (listp (sixth data)))
      (let ((meta (sixth data)))
        (when (and (>= (length meta) 2))
          ;; data[5][1] = False means owner, True means shared
          (setf is-owner (not (second meta))))
        (when (and (>= (length meta) 6) (listp (sixth meta)))
          (let ((ts-list (sixth meta)))
            (when (and ts-list (numberp (first ts-list)))
              (setf created-at (parse-timestamp (first ts-list))))))))
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

(defun %extract-audio-url (data)
  "Extract audio download URL from artifact data.
Audio URL is at data[6][5][*][0] where [*][2] = \"audio/mp4\"."
  (when (and (>= (length data) 7) (listp (sixth data)))
    (let ((media-container (sixth data)))
      (when (and (>= (length media-container) 6) (listp (nth 5 media-container)))
        (let ((media-list (nth 5 media-container)))
          (when (listp media-list)
            ;; Prefer audio/mp4 item
            (dolist (item media-list)
              (when (and (listp item) (>= (length item) 3)
                         (string= (third item) "audio/mp4")
                         (%url-string-p (first item)))
                (return-from %extract-audio-url (first item))))
            ;; Fallback: any item with an HTTP URL
            (dolist (item media-list)
              (when (and (listp item) (%url-string-p (first item)))
                (return-from %extract-audio-url (first item)))))))))
  nil)

(defun %extract-video-url (data)
  "Extract video download URL from artifact data.
Video URLs are at data[8][*][*][0]."
  (when (and (>= (length data) 9) (listp (nth 8 data)))
    (let ((fallback-url nil))
      (block nil
        (dolist (media-list (nth 8 data))
          (when (listp media-list)
            (dolist (item media-list)
              (when (and (listp item) (%url-string-p (first item)))
                (when (null fallback-url)
                  (setf fallback-url (first item)))
                (when (and (>= (length item) 3) (string= (third item) "video/mp4"))
                  (return-from %extract-video-url (first item))))))))
      fallback-url)))

(defun %extract-infographic-url (data)
  "Extract infographic download URL from artifact data."
  (dolist (item data)
    (when (and (listp item) (>= (length item) 3))
      (let ((content (third item)))
        (when (and (listp content) content (listp (first content))
                   (>= (length (first content)) 2))
          (let ((img-data (second (first content))))
            (when (and (listp img-data) img-data (%url-string-p (first img-data)))
              (return-from %extract-infographic-url (first img-data))))))))
  nil)

(defun %extract-slide-deck-pdf-url (data)
  "Extract slide deck PDF URL from artifact data at data[16][3]."
  (when (and (>= (length data) 17) (listp (nth 16 data)))
    (let ((meta (nth 16 data)))
      (when (and (>= (length meta) 4) (%url-string-p (nth 3 meta)))
        (nth 3 meta)))))

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
  (let* ((id (if (and (>= (length data) 1)) (princ-to-string (first data)) ""))
         (title (if (and (>= (length data) 2) (stringp (second data)))
                    (second data) ""))
         (atype (if (>= (length data) 3) (third data) 0))
         (status (if (>= (length data) 5) (fifth data) 0))
         (created-at nil)
         (variant nil)
         (url nil))
    ;; Extract timestamp from data[15][0]
    (when (and (>= (length data) 16) (listp (nth 15 data)))
      (let ((ts-list (nth 15 data)))
        (when (and ts-list (numberp (first ts-list)))
          (setf created-at (parse-timestamp (first ts-list))))))
    ;; Extract variant from data[9][1][0]
    (when (and (>= (length data) 10) (listp (nth 9 data)))
      (let ((options (nth 9 data)))
        (when (and (>= (length options) 2) (listp (second options))
                   (second options) (numberp (first (second options))))
          (setf variant (first (second options))))))
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
  (if (and data (listp data) data (listp (first data)))
      (let* ((artifact-data (first data))
             (task-id (if (and artifact-data (listp artifact-data) artifact-data)
                          (if (listp (first artifact-data))
                              (princ-to-string (first (first artifact-data)))
                              (princ-to-string (first artifact-data)))
                          ""))
             (status-code (if (and artifact-data (>= (length artifact-data) 5))
                              (fifth artifact-data) nil))
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
  (let* ((id (if (and (>= (length data) 1)) (princ-to-string (first data)) ""))
         (title (if (and (>= (length data) 2) (stringp (second data)))
                    (second data) ""))
         (content (if (and (>= (length data) 3) (stringp (third data)))
                      (third data) ""))
         (created-at nil))
    (when (and (>= (length data) 4) (listp (fourth data)) (fourth data))
      (let ((ts (first (fourth data))))
        (when (numberp ts)
          (setf created-at (parse-timestamp ts)))))
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
    (when (and data (listp data) data (listp (first data)))
      (let ((header (first data)))
        (when (and (>= (length header) 2) (stringp (second header)))
          (setf title (second header)))
        (when (and (>= (length header) 3) (listp (third header)))
          (let ((metadata (third header)))
            (when (>= (length metadata) 5)
              (setf type-code (fifth metadata)))
            ;; Try metadata[7] then metadata[5] for URL
            (when (and (>= (length metadata) 8) (listp (nth 7 metadata))
                       (nth 7 metadata) (stringp (first (nth 7 metadata))))
              (setf url (first (nth 7 metadata))))
            (unless url
              (when (and (>= (length metadata) 6) (listp (nth 5 metadata))
                         (nth 5 metadata) (stringp (first (nth 5 metadata))))
                (setf url (first (nth 5 metadata))))))))
      ;; Plaintext content at result[3][0]
      (when (and (>= (length data) 4) (listp (nth 3 data))
                 (nth 3 data) (listp (first (nth 3 data))))
        (setf content (format nil "~{~A~^~%~}" (%extract-all-text (first (nth 3 data)))))))
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
    (when (and data (listp data) data (listp (first data))
               (>= (length (first data)) 2))
      (let ((limits-list (second (first data))))
        (when (listp limits-list)
          (setf raw-limits (copy-list limits-list))
          (when (and (>= (length limits-list) 2) (integerp (second limits-list))
                     (not (typep (second limits-list) 'boolean))
                     (> (second limits-list) 0))
            (setf notebook-limit (second limits-list)))
          (when (and (>= (length limits-list) 3) (integerp (third limits-list))
                     (not (typep (third limits-list) 'boolean))
                     (> (third limits-list) 0))
            (setf source-limit (third limits-list))))))
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
  (let* ((email (if (and data (stringp (first data))) (first data) ""))
         (permission (if (and (>= (length data) 2) (integerp (second data)))
                         (second data) 3))
         (name nil)
         (photo-url nil))
    (when (and (>= (length data) 4) (listp (fourth data)))
      (let ((user-info (fourth data)))
        (when user-info
          (setf name (if (and user-info (stringp (first user-info)))
                         (first user-info) nil))
          (setf photo-url (if (and (>= (length user-info) 2) (stringp (second user-info)))
                              (second user-info) nil)))))
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
    (when (and (>= (length data) 2) (listp (second data)) (second data))
      (setf is-public (not (null (first (second data))))))
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
