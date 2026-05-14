(in-package #:notebooklm-cl.artifacts)

;;; ===========================================================================
;;; Type-specific listers (macro-generated)
;;; ===========================================================================

(defmacro define-artifact-lister (name artifact-type &optional docstring)
  "Define a thin wrapper around LIST-ARTIFACTS with a fixed ARTIFACT-TYPE filter.
ARTIFACT-TYPE is a keyword (e.g. :AUDIO, :REPORT, :QUIZ) passed directly."
  `(defun ,name (client notebook-id)
     ,(or docstring (format nil "List ~(~A~) artifacts in a notebook." artifact-type))
     (list-artifacts client notebook-id :artifact-type ,artifact-type)))

(define-artifact-lister list-audio :audio)
(define-artifact-lister list-video :video)
(define-artifact-lister list-reports :report)
(define-artifact-lister list-quizzes :quiz)
(define-artifact-lister list-flashcards :flashcards)
(define-artifact-lister list-infographics :infographic)
(define-artifact-lister list-slide-decks :slide-deck)
(define-artifact-lister list-data-tables :data-table)

;;; ===========================================================================
;;; get-artifact
;;; ===========================================================================

(defun get-artifact (client notebook-id artifact-id)
  "Get a single artifact by ID, or NIL if not found."
  (find artifact-id (list-artifacts client notebook-id)
        :key #'notebooklm-cl.types::art-id
        :test #'string=))

;;; ===========================================================================
;;; suggest-reports
;;; ===========================================================================

(defun suggest-reports (client notebook-id)
  "Return a list of REPORT-SUGGESTION structs for NOTEBOOK-ID.
RPC: GET_SUGGESTED_REPORTS with params [[2], notebook-id].
Response format: result[0] is a list of [title, desc, nil, nil, prompt, audience_level]."
  (let* ((params (list (list 2) notebook-id))
         (result (rpc-call client
                           notebooklm-cl.rpc.types:*get-suggested-reports*
                           params
                           :source-path (%notebook-path notebook-id)
                           :allow-null t))
         (out '()))
    (when (and result (listp result) (listp (first result)))
      (dolist (item (first result))
        (when (listp item)
          (push (report-suggestion-from-api-response item) out))))
    (nreverse out)))

;;; ===========================================================================
;;; Paths / params
;;; ===========================================================================

(defun %notebook-path (notebook-id)
  (format nil "/notebook/~A" notebook-id))

(defun %list-artifacts-params (notebook-id)
  (list (list 2) notebook-id
        "NOT artifact.status = \"ARTIFACT_STATUS_SUGGESTED\""))

(defun %artifact-filter-keyword->kind (kw)
  "Map :MIND-MAP → \"mind_map\", :SLIDE-DECK → \"slide_deck\", etc."
  (when kw
    (substitute #\_ #\- (string-downcase (symbol-name kw)))))

;;; ===========================================================================
;;; Raw list (internal)
;;; ===========================================================================

(defun %normalize-list-artifacts-body (result)
  "Match Python list(): first element if it is a list, else RESULT."
  (when (and result (listp result) (plusp (length result)))
    (if (listp (first result))
        (first result)
        result)))

(defun %list-raw (client notebook-id)
  "Return raw artifact rows from LIST_ARTIFACTS RPC."
  (let* ((params (%list-artifacts-params notebook-id))
         (result (notebooklm-cl.core:rpc-call
                  client notebooklm-cl.rpc.types:*list-artifacts*
                  params
                  :source-path (%notebook-path notebook-id)
                  :allow-null t)))
    (%normalize-list-artifacts-body result)))

;;; ===========================================================================
;;; Mind maps (notes RPC)
;;; ===========================================================================

(defun %extract-notes-item-content (item)
  "Extract content string from a notes/mind-map row (mirrors Python _extract_content)."
  (when (and (listp item) (> (length item) 1))
    (let ((cell (nth 1 item)))
      (cond
        ((stringp cell) cell)
        ((and (listp cell) (> (length cell) 1) (stringp (nth 1 cell)))
         (nth 1 cell))
        (t nil)))))

(defun %mind-map-content-p (content)
  (and (stringp content)
       (or (search "\"children\":" content)
           (search "\"nodes\":" content))))

(defun %notes-item-deleted-p (item)
  (and (listp item) (>= (length item) 3)
       (null (nth 1 item))
       (eql (nth 2 item) 2)))

(defun %fetch-notes-items (client notebook-id)
  "Raw rows from GET_NOTES_AND_MIND_MAPS (valid shape only)."
  (let* ((params (list notebook-id))
         (result (notebooklm-cl.core:rpc-call
                  client notebooklm-cl.rpc.types:*get-notes-and-mind-maps*
                  params
                  :source-path (%notebook-path notebook-id)
                  :allow-null t)))
    (when (and result (listp result) (plusp (length result))
               (listp (first result)))
      (let ((notes-list (first result))
            (out '()))
        (dolist (item notes-list)
          (when (and (listp item) (plusp (length item)) (stringp (first item)))
            (push item out)))
        (nreverse out)))))

(defun %list-mind-maps (client notebook-id)
  "Mind-map rows only (excludes deleted); mirrors NotesAPI.list_mind_maps."
  (loop for item in (%fetch-notes-items client notebook-id)
        unless (%notes-item-deleted-p item)
        when (%mind-map-content-p (%extract-notes-item-content item))
        collect item))

;;; ===========================================================================
;;; list-artifacts
;;; ===========================================================================

(defun list-artifacts (client notebook-id &key artifact-type)
  "List artifacts in NOTEBOOK-ID, optionally filtered by ARTIFACT-TYPE keyword.
Merges mind maps from the notes RPC when not filtering to a non–mind-map kind."
  (let ((out '())
        (kind-filter (%artifact-filter-keyword->kind artifact-type)))
    (dolist (art-data (%list-raw client notebook-id))
      (when (listp art-data)
        (let ((art (artifact-from-api-response art-data)))
          (when (or (null kind-filter)
                    (string= (artifact-kind art) kind-filter))
            (push art out)))))
    (when (or (null artifact-type)
              (string= (or kind-filter "") "mind_map"))
      (handler-case
          (dolist (mm (%list-mind-maps client notebook-id))
            (let ((art (artifact-from-mind-map-data mm)))
              (when (and art (or (null kind-filter)
                                 (string= (artifact-kind art) kind-filter)))
                (push art out))))
        (error (e)
          (warn "Failed to fetch mind maps: ~A" e))))
    (nreverse out)))

;;; ===========================================================================
;;; Generate helpers
;;; ===========================================================================

(defun %get-source-ids (client notebook-id)
  "Return a list of source-id strings for NOTEBOOK-ID, or NIL if the call fails."
  (handler-case
      (mapcar #'source-id (list-sources client notebook-id :strict t))
    (error () nil)))

(defun %source-ids-triple (ids)
  "Python: [[[sid]] for sid in source_ids]"
  (when ids (mapcar (lambda (id) (list (list id))) ids)))

(defun %source-ids-double (ids)
  "Python: [[sid] for sid in source_ids]"
  (when ids (mapcar (lambda (id) (list id)) ids)))

(defun %call-generate (client notebook-id params)
  "Make a CREATE_ARTIFACT RPC call with USER_DISPLAYABLE_ERROR handling.
Returns a GENERATION-STATUS (task-id + status on success, error info on failure)."
  (handler-case
      (let ((result (rpc-call client *create-artifact* params
                              :source-path (%notebook-path notebook-id)
                              :allow-null t)))
        (generation-status-from-api-response result))
    (rpc-error (e)
      (if (string= (rpc-error-rpc-code e) "USER_DISPLAYABLE_ERROR")
          (make-generation-status :task-id ""
                                  :status "failed"
                                  :error (princ-to-string e)
                                  :error-code (rpc-error-rpc-code e))
          (error e)))))

;;; ===========================================================================
;;; generate-audio
;;; ===========================================================================

(defun generate-audio (client notebook-id &key source-ids language instructions
                                          (audio-format nil) (audio-length nil))
  "Generate an Audio Overview (podcast).
Returns GENERATION-STATUS with task-id for polling.

Keyword args:
  :SOURCE-IDS    — list of source-id strings (default: all sources in notebook)
  :LANGUAGE      — language code (default: NOTEBOOKLM_HL env var or \"en\")
  :INSTRUCTIONS  — custom instructions for the podcast hosts
  :AUDIO-FORMAT  — one of +AUDIO-DEEP-DIVE+, +AUDIO-BRIEF+, +AUDIO-CRITIQUE+, +AUDIO-DEBATE+
  :AUDIO-LENGTH  — one of +AUDIO-SHORT+, +AUDIO-DEFAULT+, +AUDIO-LONG+"
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (double (%source-ids-double source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-audio+
                             triple nil nil
                             (list nil
                                   (list instructions
                                         audio-length
                                         nil double language nil
                                         audio-format))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-report
;;; ===========================================================================

(defun %report-format-config (format-str custom-prompt extra-instructions)
  "Return (list title description prompt) for FORMAT-STR.
FORMAT-STR is one of the *report-format-* string constants."
  (let ((base
          (cond
            ((string= format-str *report-format-briefing-doc*)
             (list "Briefing Doc"
                   "Key insights and important quotes"
                   (concatenate 'string
                                "Create a comprehensive briefing document that includes an "
                                "Executive Summary, detailed analysis of key themes, important "
                                "quotes with context, and actionable insights.")))
            ((string= format-str *report-format-study-guide*)
             (list "Study Guide"
                   "Short-answer quiz, essay questions, glossary"
                   (concatenate 'string
                                "Create a comprehensive study guide that includes key concepts, "
                                "short-answer practice questions, essay prompts for deeper "
                                "exploration, and a glossary of important terms.")))
            ((string= format-str *report-format-blog-post*)
             (list "Blog Post"
                   "Insightful takeaways in readable article format"
                   (concatenate 'string
                                "Write an engaging blog post that presents the key insights "
                                "in an accessible, reader-friendly format. Include an attention-"
                                "grabbing introduction, well-organized sections, and a compelling "
                                "conclusion with takeaways.")))
            (t
             (list "Custom Report"
                   "Custom format"
                   (or custom-prompt "Create a report based on the provided sources."))))))
    (if (and extra-instructions (not (string= format-str *report-format-custom*)))
        (list (first base)
              (second base)
              (concatenate 'string (third base) "

" extra-instructions))
        base)))

(defun generate-report (client notebook-id &key source-ids language
                                            (report-format *report-format-briefing-doc*)
                                            custom-prompt extra-instructions)
  "Generate a report artifact.
Returns GENERATION-STATUS with task-id for polling.

Keyword args:
  :SOURCE-IDS         — list of source-id strings (default: all sources)
  :LANGUAGE           — language code (default: NOTEBOOKLM_HL env var or \"en\")
  :REPORT-FORMAT      — *report-format-briefing-doc*, *report-format-study-guide*,
                        *report-format-blog-post*, or *report-format-custom*
  :CUSTOM-PROMPT      — prompt for CUSTOM format (ignored otherwise)
  :EXTRA-INSTRUCTIONS — appended to built-in prompt (ignored for CUSTOM)"
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (double (%source-ids-double source-ids))
         (config (%report-format-config report-format custom-prompt extra-instructions))
         (title (first config))
         (description (second config))
         (prompt (third config))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-report+
                             triple nil nil nil
                             (list nil
                                   (list title description nil double language
                                         prompt nil t))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-quiz
;;; ===========================================================================

(defun generate-quiz (client notebook-id &key source-ids instructions
                                         (quantity nil) (difficulty nil))
  "Generate a quiz artifact.  Returns GENERATION-STATUS.

Keyword args:
  :SOURCE-IDS    — list of source-id strings (default: all sources)
  :INSTRUCTIONS  — custom instructions
  :QUANTITY      — +QUIZ-FEWER+, +QUIZ-STANDARD+, or +QUIZ-MORE+
  :DIFFICULTY    — +QUIZ-EASY+, +QUIZ-MEDIUM+, or +QUIZ-HARD+"
  (let* ((source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-quiz+
                             triple nil nil nil nil nil
                             (list nil
                                   (list 2  ; variant: quiz
                                         nil instructions nil nil nil nil
                                         (list quantity difficulty)))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-flashcards
;;; ===========================================================================

(defun generate-flashcards (client notebook-id &key source-ids instructions
                                             (quantity nil) (difficulty nil))
  "Generate a flashcard artifact.  Returns GENERATION-STATUS.

Keyword args:
  :SOURCE-IDS    — list of source-id strings (default: all sources)
  :INSTRUCTIONS  — custom instructions
  :QUANTITY      — +QUIZ-FEWER+, +QUIZ-STANDARD+, or +QUIZ-MORE+
  :DIFFICULTY    — +QUIZ-EASY+, +QUIZ-MEDIUM+, or +QUIZ-HARD+"
  (let* ((source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-quiz+
                             triple nil nil nil nil nil
                             (list nil
                                   (list 1  ; variant: flashcards
                                         nil instructions nil nil nil
                                         (list difficulty quantity)))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-video
;;; ===========================================================================

(defun generate-video (client notebook-id &key source-ids language instructions
                                          (video-format nil) (video-style nil)
                                          style-prompt)
  "Generate a Video Overview.  Returns GENERATION-STATUS.

Keyword args:
  :SOURCE-IDS    — list of source-id strings (default: all sources)
  :LANGUAGE      — language code (default: NOTEBOOKLM_HL env var or \"en\")
  :INSTRUCTIONS  — custom instructions
  :VIDEO-FORMAT  — +VIDEO-EXPLAINER+, +VIDEO-BRIEF+, or +VIDEO-CINEMATIC+
  :VIDEO-STYLE   — +VIDEO-CLASSIC+, +VIDEO-WHITEBOARD+, etc.
  :STYLE-PROMPT  — custom visual style (requires :VIDEO-STYLE +VIDEO-CUSTOM+)"
  (let* ((language (or language (get-default-language)))
         (prompt (when style-prompt (string-trim " " style-prompt)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (double (%source-ids-double source-ids)))
    ;; Validation (Python parity)
    (when (and (= video-format notebooklm-cl.rpc.types:+video-cinematic+) prompt)
      (error 'validation-error))
    (when (and (= video-style notebooklm-cl.rpc.types:+video-custom+)
               (or (null prompt) (zerop (length prompt))))
      (error 'validation-error))
    (when (and prompt (not (= video-style notebooklm-cl.rpc.types:+video-custom+)))
      (error 'validation-error))
    (let* ((video-config (list double language instructions nil
                                video-format video-style))
           (video-config (if prompt
                             (append video-config (list prompt))
                             video-config))
           (params (list (list 2)
                         notebook-id
                         (list nil nil +artifact-video+
                               triple nil nil nil nil
                               (list nil nil video-config)))))
      (%call-generate client notebook-id params))))

;;; ===========================================================================
;;; generate-infographic
;;; ===========================================================================

(defun generate-infographic (client notebook-id &key source-ids language instructions
                                                (orientation nil) (detail-level nil)
                                                (style nil))
  "Generate an infographic artifact.  Returns GENERATION-STATUS."
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-infographic+
                             triple nil nil nil nil nil nil nil nil nil nil nil
                             (list (list instructions language nil
                                          orientation detail-level style))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-slide-deck
;;; ===========================================================================

(defun generate-slide-deck (client notebook-id &key source-ids language instructions
                                               (slide-format nil) (slide-length nil))
  "Generate a slide deck artifact.  Returns GENERATION-STATUS."
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-slide-deck+
                             triple nil nil nil nil nil nil nil nil nil nil nil nil nil nil
                             (list (list instructions language
                                          slide-format slide-length))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-data-table
;;; ===========================================================================

(defun generate-data-table (client notebook-id &key source-ids language instructions)
  "Generate a data table artifact.  Returns GENERATION-STATUS."
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-data-table+
                             triple nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
                             nil
                             (list nil (list instructions language))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-cinematic-video
;;; ===========================================================================

(defun generate-cinematic-video (client notebook-id &key source-ids language instructions)
  "Generate a Cinematic Video Overview (Veo 3 documentary style).
Uses VideoFormat.CINEMATIC internally; does not accept VideoStyle options.
Note: generation can take 30-40 minutes."
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (double (%source-ids-double source-ids))
         (params (list (list 2)
                       notebook-id
                       (list nil nil +artifact-video+
                             triple nil nil nil nil
                             (list nil nil
                                   (list double language instructions nil
                                         notebooklm-cl.rpc.types:+video-cinematic+))))))
    (%call-generate client notebook-id params)))

;;; ===========================================================================
;;; generate-mind-map
;;; ===========================================================================

(defun %create-mind-map-note (client notebook-id title json-content)
  "Create a note to persist the mind map.  Returns the note-id or NIL."
  (handler-case
      (let* ((params (list notebook-id
                           (list title json-content)))
             (result (rpc-call client notebooklm-cl.rpc.types:*create-note*
                               params
                               :source-path (%notebook-path notebook-id)
                               :allow-null t)))
        (when (and result (listp result) (listp (first result))
                   (listp (first (first result))))
          (princ-to-string (first (first (first result))))))
    (error () nil)))

(defun generate-mind-map (client notebook-id &key source-ids language instructions)
  "Generate an interactive mind map.  Returns plist (:mind-map DATA :note-id ID).
Mind maps use GENERATE_MIND_MAP RPC (not CREATE_ARTIFACT) and are persisted
via CREATE_NOTE.  They appear in artifact listings as type MIND_MAP."
  (let* ((language (or language (get-default-language)))
         (source-ids (or source-ids (%get-source-ids client notebook-id)))
         (triple (%source-ids-triple source-ids))
         (params (list triple nil nil nil nil
                       (list "interactive_mindmap"
                             (list (list "[CONTEXT]" (or instructions "")))
                             language)
                       nil
                       (list 2 nil (list 1))))
         (result (rpc-call client notebooklm-cl.rpc.types:*generate-mind-map*
                           params
                           :source-path (%notebook-path notebook-id)
                           :allow-null t)))
    (when (and result (listp result) (listp (first result)))
      (let* ((inner (first result))
             (mind-map-json (when (listp inner) (first inner)))
             (mind-map-data (if (stringp mind-map-json)
                                (handler-case
                                    (cl-json:decode-json-from-string mind-map-json)
                                  (error () mind-map-json))
                                mind-map-json))
             (title (if (and (listp mind-map-data)
                             (assoc "name" mind-map-data :test #'string=))
                        (cdr (assoc "name" mind-map-data :test #'string=))
                        "Mind Map"))
             (json-str (if (stringp mind-map-json)
                           mind-map-json
                           (cl-json:encode-json-to-string mind-map-json)))
             (note-id (%create-mind-map-note client notebook-id title json-str)))
        (list :mind-map mind-map-data :note-id note-id)))))

;;; ===========================================================================
;;; Poll status — Python poll_status (+ media URL downgrade)
;;; ===========================================================================

(defun %artifact-row-id-equal (row id)
  (and row (equal (princ-to-string (first row)) (princ-to-string id))))

(defun poll-artifact-status-from-rows (rows task-id)
  "Locate TASK-ID in raw LIST_ARTIFACT rows (see `%list-raw`).
Matches Python ``poll_status``: media artifacts stay `in_progress` until URLs exist."
  (loop for art in rows
        when (%artifact-row-id-equal art task-id)
        do (let* ((tid (princ-to-string task-id))
                  (atype (if (and art (listp art) (> (length art) 2)) (nth 2 art) 0))
                  (scode (if (and art (listp art) (> (length art) 4)) (nth 4 art) 0))
                  (adjusted
                    (if (and (= scode notebooklm-cl.rpc.types:+artifact-completed+)
                             (not (artifact-row-media-download-ready-p art atype)))
                        notebooklm-cl.rpc.types:+artifact-processing+
                        scode)))
             (let* ((status-str (notebooklm-cl.rpc.types:artifact-status-to-str adjusted))
                    (failed-p (equal status-str "failed")))
               (return-from poll-artifact-status-from-rows
                 (make-generation-status
                  :task-id tid
                  :status status-str
                  :url (artifact-row-download-url art atype)
                  :error (when failed-p (artifact-row-error-message art)))))))
  (make-generation-status :task-id (princ-to-string task-id) :status "not_found"))

(defun poll-artifact-status (client notebook-id task-id)
  (poll-artifact-status-from-rows (%list-raw client notebook-id) task-id))

;;; ===========================================================================
;;; wait-for-artifact — exponential backoff poller
;;; ===========================================================================

(defun %now-seconds ()
  "Current real time in seconds (monotonic)."
  (/ (get-internal-real-time) internal-time-units-per-second 1.0))

(defun wait-for-artifact (client notebook-id task-id
                          &key (initial-interval 2.0)
                               (max-interval 10.0)
                               (timeout 300.0)
                               (max-not-found 5)
                               (min-not-found-window 10.0))
  "Wait for a generation task to complete using exponential backoff.

Returns the final GENERATION-STATUS on completion or failure.
Signals RPC-TIMEOUT-ERROR if the task doesn't complete within TIMEOUT seconds.

Keyword args (matching Python ``wait_for_completion``):
  :INITIAL-INTERVAL    — initial seconds between polls (default 2.0)
  :MAX-INTERVAL        — maximum seconds between polls (default 10.0)
  :TIMEOUT             — maximum total seconds to wait (default 300.0)
  :MAX-NOT-FOUND       — consecutive \"not_found\" polls before treating as failed (default 5)
  :MIN-NOT-FOUND-WINDOW — minimum seconds before consecutive-not-found can trigger (default 10.0)"
  (let ((start-time (%now-seconds))
        (current-interval initial-interval)
        (consecutive-not-found 0)
        (total-not-found 0)
        (first-not-found-time nil)
        (last-status nil))
    (loop
      (let* ((status (poll-artifact-status client notebook-id task-id))
             (status-str (gen-status status)))
        (setf last-status status-str)
        (when (or (generation-is-complete-p status)
                  (generation-is-failed-p status))
          (return status))
        ;; Track not-found responses
        (if (string= status-str "not_found")
            (progn
              (incf consecutive-not-found)
              (incf total-not-found)
              (let ((now (%now-seconds)))
                (unless first-not-found-time
                  (setf first-not-found-time now))
                (when (or (and (>= consecutive-not-found max-not-found)
                               (>= (- now first-not-found-time) min-not-found-window))
                          (>= total-not-found (* max-not-found 2)))
                  (return (make-generation-status
                           :task-id (princ-to-string task-id)
                           :status "failed"
                           :error (concatenate 'string
                                     "Generation failed: artifact was removed by the server. "
                                     "This may indicate a daily quota/rate limit was exceeded, "
                                     "an invalid notebook ID, or a transient API issue. "
                                     "Try again later."))))))
            (setf consecutive-not-found 0))
        ;; Timeout check
        (let ((elapsed (- (%now-seconds) start-time)))
          (when (> elapsed timeout)
            (error 'notebooklm-cl.errors:rpc-timeout-error
                   :timeout-seconds timeout)))
        ;; Sleep with clamp to respect timeout
        (let* ((remaining (- timeout (- (%now-seconds) start-time)))
               (sleep-dur (min current-interval (max 0 remaining))))
          (when (plusp sleep-dur)
            (sleep sleep-dur)))
        ;; Exponential backoff
        (setf current-interval (min (* current-interval 2) max-interval))))))

;;; ===========================================================================
;;; Download helper — streaming GET with domain validation
;;; ===========================================================================

(defun %validate-download-url (url)
  "Validate that URL is HTTPS and the host is a trusted Google domain.
Returns the host string on success, signals ARTIFACT-DOWNLOAD-ERROR on failure."
  (unless (and (stringp url) (>= (length url) 8)
               (string-equal url "https://" :end1 8))
    (error 'artifact-download-error
           :artifact-type "media"
           :details (format nil "Download URL must use HTTPS: ~A"
                            (if url (subseq url 0 (min 80 (length url))) "null"))))
  (let* ((proto-end 8)
         (host-end (or (position-if (lambda (c) (member c '(#\/ #\? #\#))) url
                                    :start proto-end)
                       (length url)))
         (host (string-downcase (subseq url proto-end host-end))))
    (unless (or (string= host "google.com")
                (and (> (length host) 11) (string= host ".google.com" :start1 (- (length host) 11)))
                (and (> (length host) 22) (string= host ".googleusercontent.com" :start1 (- (length host) 22)))
                (and (> (length host) 15) (string= host ".googleapis.com" :start1 (- (length host) 15))))
      (error 'artifact-download-error
             :artifact-type "media"
             :details (format nil "Untrusted download domain: ~A" host)))
    host))

(defun %download-url (url output-path)
  "Download a file from URL to OUTPUT-PATH using streaming GET.
Validates domain, streams to temp file, renames on success.
Signals ARTIFACT-DOWNLOAD-ERROR on failure."
  (%validate-download-url url)
  (let ((temp-path (concatenate 'string output-path ".tmp")))
    (ensure-directories-exist output-path)
    (unwind-protect
        (handler-case
            (multiple-value-bind (body status headers)
                (dex:get url
                         :force-binary t
                         :connect-timeout 10
                         :read-timeout 30)
              (unless (= status 200)
                (error 'artifact-download-error
                       :artifact-type "media"
                       :details (format nil "HTTP ~D from download URL" status)))
              (let ((content-type (cdr (assoc :content-type headers :test #'eq))))
                (when (and (stringp content-type) (search "text/html" content-type))
                  (error 'artifact-download-error
                         :artifact-type "media"
                         :details (concatenate 'string
                                   "Download failed: received HTML instead of media file. "
                                   "Authentication may have expired."))))
              (unless (and body (plusp (length body)))
                (error 'artifact-download-error
                       :artifact-type "media"
                       :details "Download produced 0 bytes"))
              (with-open-file (out temp-path
                                   :direction :output
                                   :element-type '(unsigned-byte 8)
                                   :if-exists :supersede)
                (write-sequence body out))
              (rename-file temp-path output-path)
              output-path)
          (dex:http-request-failed (e)
            (error 'artifact-download-error
                   :artifact-type "media"
                   :details (format nil "HTTP request failed: ~A" e)))
          (error (e)
            (error 'artifact-download-error
                   :artifact-type "media"
                   :details (format nil "Download error: ~A" e))))
      (ignore-errors (delete-file temp-path)))))

;;; ===========================================================================
;;; Artifact selection helper
;;; ===========================================================================

(defun %select-artifact (candidates artifact-id type-name type-name-lower)
  "Select an artifact from CANDIDATES (raw row list) by ID, or first completed.
Sorts by creation timestamp descending (position 15, index 0).
Signals ARTIFACT-NOT-READY-ERROR if no candidates or ID not found."
  (if artifact-id
      (or (find artifact-id candidates
                :key (lambda (a) (princ-to-string (first a)))
                :test #'string=)
          (error 'artifact-not-ready-error
                 :artifact-type type-name-lower
                 :artifact-id artifact-id))
      (if candidates
          (first (sort (copy-list candidates) #'>
                       :key (lambda (a)
                              (let ((ts (%nths a 15 0)))
                                (if (numberp ts) ts 0)))))
          (error 'artifact-not-ready-error
                 :artifact-type type-name-lower))))

;;; ===========================================================================
;;; Simple downloader macro (audio, video, infographic)
;;; ===========================================================================

(defmacro define-simple-downloader (name artifact-type type-code)
  "Define a downloader for artifact types that only need URL extraction.
Generates a function (NAME CLIENT NOTEBOOK-ID OUTPUT-PATH &KEY ARTIFACT-ID)
that filters by TYPE-CODE, selects completed artifact, extracts URL, downloads."
  `(defun ,name (client notebook-id output-path &key artifact-id)
     ,(format nil "Download ~A artifact to OUTPUT-PATH." artifact-type)
     (let* ((raw (%list-raw client notebook-id))
            (candidates (remove-if-not
                         (lambda (a)
                           (and (listp a) (> (length a) 4)
                                (= (nth 2 a) ,type-code)
                                (= (nth 4 a) +artifact-completed+)))
                         raw))
            (selected (%select-artifact candidates artifact-id
                                        ,(string-capitalize artifact-type)
                                        ,(string-downcase artifact-type)))
            (url (artifact-row-download-url selected ,type-code)))
       (unless url
         (error 'artifact-parse-error
                :artifact-type ,artifact-type
                :artifact-id artifact-id
                :details "Could not extract download URL"))
       (%download-url url output-path))))

(define-simple-downloader download-audio "audio" +artifact-audio+)
(define-simple-downloader download-video "video" +artifact-video+)
(define-simple-downloader download-infographic "infographic" +artifact-infographic+)

;;; ===========================================================================
;;; Custom downloaders
;;; ===========================================================================

(defun download-report (client notebook-id output-path &key artifact-id)
  "Download a report artifact as markdown to OUTPUT-PATH.
Reads artifact row index 7 (report content wrapper)."
  (let* ((raw (%list-raw client notebook-id))
         (candidates (remove-if-not
                      (lambda (a)
                        (and (listp a) (> (length a) 7)
                             (= (nth 2 a) +artifact-report+)
                             (= (nth 4 a) +artifact-completed+)))
                      raw))
         (selected (%select-artifact candidates artifact-id "Report" "report"))
         (content-wrapper (%nths selected 7))
         (markdown (if (and (listp content-wrapper) content-wrapper)
                       (first content-wrapper)
                       content-wrapper)))
    (unless (stringp markdown)
      (error 'artifact-parse-error
             :artifact-type "report_content"
             :details "Invalid report content structure"))
    (ensure-directories-exist output-path)
    (with-open-file (out output-path :direction :output
                         :if-exists :supersede
                         :external-format :utf-8)
      (write-string markdown out))
    output-path))

(defun download-data-table (client notebook-id output-path &key artifact-id)
  "Download a data table artifact as CSV to OUTPUT-PATH.
Reads artifact row index 18 (table raw data), parses headers + rows."
  (let* ((raw (%list-raw client notebook-id))
         (candidates (remove-if-not
                      (lambda (a)
                        (and (listp a) (> (length a) 18)
                             (= (nth 2 a) +artifact-data-table+)
                             (= (nth 4 a) +artifact-completed+)))
                      raw))
         (selected (%select-artifact candidates artifact-id "Data table" "data table"))
         (raw-data (%nths selected 18))
         (headers nil)
         (rows nil))
    (unless raw-data
      (error 'artifact-parse-error
             :artifact-type "data_table"
             :details "No raw data at index 18"))
    ;; Navigate: raw-data[0][0][0][0][4][2] → rows array
    (let ((rows-array (%nths raw-data 0 0 0 0 4 2)))
      (unless (listp rows-array)
        (error 'artifact-parse-error
               :artifact-type "data_table"
               :details "Cannot find rows array"))
      (loop for i from 0 below (length rows-array)
            for row-section = (nth i rows-array)
            when (and (listp row-section) (>= (length row-section) 3))
            do (let* ((cell-array (nth 2 row-section))
                      (values (when (listp cell-array)
                                (loop for cell in cell-array
                                      collect (%extract-cell-text cell)))))
                 (if (= i 0)
                     (setf headers values)
                     (push values rows)))))
    (unless headers
      (error 'artifact-parse-error
             :artifact-type "data_table"
             :details "Failed to extract headers"))
    (setf rows (nreverse rows))
    (ensure-directories-exist output-path)
    (with-open-file (out output-path :direction :output
                         :if-exists :supersede
                         :external-format :utf-8)
      ;; Write CSV
      (write-string (%csv-escape-row headers) out)
      (dolist (row rows)
        (terpri out)
        (write-string (%csv-escape-row row) out)))
    output-path))

(defun %extract-cell-text (cell)
  "Recursively extract text from a nested data-table cell structure."
  (cond
    ((stringp cell) cell)
    ((integerp cell) "")
    ((listp cell)
     (with-output-to-string (s)
       (dolist (item cell)
         (write-string (%extract-cell-text item) s))))
    (t "")))

(defun %csv-escape-row (cells)
  "Format a list of cell strings as a CSV line (simple comma-escape)."
  (with-output-to-string (s)
    (loop for cell in cells
          for first = t then nil
          do (unless first (write-char #\, s))
             (write-char #\" s)
             (when (stringp cell)
               ;; Escape embedded double-quotes
               (loop for c across cell
                     do (when (char= c #\")
                          (write-char #\" s))
                        (write-char c s)))
             (write-char #\" s))))

(defun download-slide-deck (client notebook-id output-path &key artifact-id
                                                    (output-format "pdf"))
  "Download a slide deck artifact as PDF or PPTX to OUTPUT-PATH.
Reads artifact row index 16: metadata[3]=PDF, metadata[4]=PPTX."
  (unless (member output-format '("pdf" "pptx") :test #'string=)
    (error 'notebooklm-cl.errors:validation-error))
  (let* ((raw (%list-raw client notebook-id))
         (candidates (remove-if-not
                      (lambda (a)
                        (and (listp a) (> (length a) 16)
                             (= (nth 2 a) +artifact-slide-deck+)
                             (= (nth 4 a) +artifact-completed+)))
                      raw))
         (selected (%select-artifact candidates artifact-id "Slide deck" "slide deck"))
         (metadata (%nths selected 16))
         (url-index (if (string= output-format "pptx") 4 3)))
    (unless (and (listp metadata) (> (length metadata) url-index))
      (error 'artifact-parse-error
             :artifact-type "slide_deck"
             :details (format nil "Invalid slide deck metadata structure")))
    (let ((url (nth url-index metadata)))
      (unless (and (stringp url) (>= (length url) 8)
                   (string-equal url "https://" :end1 8))
        (error 'artifact-download-error
               :artifact-type "slide_deck"
               :details (format nil "Could not find ~A download URL"
                                (string-upcase output-format))))
      (%download-url url output-path))))

;;; ===========================================================================
;;; Delete / rename / export
;;; ===========================================================================

(defun delete-artifact (client notebook-id artifact-id)
  (rpc-call client notebooklm-cl.rpc.types:*delete-artifact*
            (list (list 2) artifact-id)
            :source-path (%notebook-path notebook-id)
            :allow-null t)
  t)

(defun rename-artifact (client notebook-id artifact-id new-title)
  (rpc-call client notebooklm-cl.rpc.types:*rename-artifact*
            (list (list artifact-id new-title) (list (list "title")))
            :source-path (%notebook-path notebook-id)
            :allow-null t))

(defun export-artifact (client notebook-id &key artifact-id content (title "Export")
                                              (export-type notebooklm-cl.rpc.types:+export-docs+))
  (rpc-call client notebooklm-cl.rpc.types:*export-artifact*
            (list nil artifact-id content title export-type)
            :source-path (%notebook-path notebook-id)
            :allow-null t))

(defun export-report (client notebook-id artifact-id &key (title "Export")
                                                (export-type notebooklm-cl.rpc.types:+export-docs+))
  (export-artifact client notebook-id :artifact-id artifact-id :title title :export-type export-type))

(defun export-data-table (client notebook-id artifact-id &key (title "Export"))
  (export-artifact client notebook-id :artifact-id artifact-id :title title
                                         :export-type notebooklm-cl.rpc.types:+export-sheets+))
