(defpackage #:notebooklm-cl.cli
  (:use #:cl)
  (:import-from #:notebooklm-cl.core
                #:client-core #:make-client-core
                #:auth-tokens #:make-auth-tokens
                #:auth-tokens-csrf-token #:auth-tokens-session-id
                #:auth-tokens-cookie-header
                #:open-client #:close-client)
  (:import-from #:notebooklm-cl.notebooks
                #:list-notebooks #:create-notebook #:get-notebook
                #:delete-notebook #:rename-notebook #:get-metadata)
  (:import-from #:notebooklm-cl.sources
                #:list-sources #:get-source #:add-url
                #:add-file-source #:delete-source #:rename-source)
  (:import-from #:notebooklm-cl.artifacts
                #:list-artifacts #:list-audio #:list-video #:list-reports
                #:list-quizzes #:list-flashcards #:list-infographics
                #:list-slide-decks #:list-data-tables
                #:get-artifact #:suggest-reports
                #:generate-audio #:generate-report #:generate-quiz
                #:generate-flashcards #:generate-video
                #:generate-infographic #:generate-slide-deck
                #:generate-data-table #:generate-cinematic-video
                #:generate-mind-map
                #:wait-for-artifact
                #:download-audio #:download-video #:download-infographic
                #:download-report #:download-data-table #:download-slide-deck
                #:download-quiz #:download-flashcards #:download-mind-map
                #:delete-artifact #:rename-artifact
                #:export-report #:export-data-table)
  (:import-from #:notebooklm-cl.errors
                #:notebooklm-error #:rpc-error
                #:rpc-error-method-id #:rpc-error-rpc-code)
  (:export #:main))

(in-package #:notebooklm-cl.cli)

;;; ===========================================================================
;;; Config file
;;; ===========================================================================

(defvar *config-dir* (merge-pathnames ".notebooklm-cl/" (user-homedir-pathname)))
(defvar *config-file* (merge-pathnames "auth.json" *config-dir*))

(defun config-dir ()
  (ensure-directories-exist *config-dir*)
  (namestring *config-dir*))

(defun load-auth ()
  "Load auth from ~/.notebooklm-cl/auth.json.  Returns AUTH-TOKENS or NIL."
  (handler-case
      (let* ((path *config-file*)
             (json (cl-json:decode-json-from-string
                    (with-open-file (in path :external-format :utf-8)
                      (let ((s (make-string (file-length in))))
                        (read-sequence s in)
                        s)))))
        (make-auth-tokens
         :csrf-token (cdr (assoc :csrf--token json))
         :session-id (cdr (assoc :session--id json))
         :cookie-header (cdr (assoc :cookie--header json))))
    (file-error () nil)
    (error (e)
      (format *error-output* "~&Warning: Could not load auth: ~A~%" e)
      nil)))

(defun save-auth (csrf session &optional cookie-header)
  "Save auth credentials to ~/.notebooklm-cl/auth.json."
  (ensure-directories-exist *config-file*)
  (let ((data `((:csrf--token . ,csrf)
                (:session--id . ,session)
                (:cookie--header . ,(or cookie-header "")))))
    (with-open-file (out *config-file* :direction :output
                         :if-exists :supersede
                         :external-format :utf-8)
      (write-string (cl-json:encode-json-to-string data) out))
    (namestring *config-file*)))

(defun require-auth (auth)
  "Die if AUTH is NIL."
  (unless auth
    (format *error-output* "~&Error: Not logged in.~%")
    (format *error-output* "Run: notebooklm login --csrf TOKEN --session ID [--cookie HEADER]~%")
    (uiop:quit 1)))

(defun make-client ()
  "Build a client from saved auth.  Dies if not logged in."
  (let ((auth (load-auth)))
    (require-auth auth)
    (let ((client (make-client-core :auth auth)))
      (open-client client)
      client)))

;;; ===========================================================================
;;; Argument parsing
;;; ===========================================================================

(defun split-args (argv)
  "Split ARGV into positional and keyword pairs.  Returns (pos . kvs)."
  (let ((pos nil) (kvs nil))
    (loop for i from 0 below (length argv)
          for arg = (nth i argv)
          do (if (and (>= (length arg) 2) (char= (char arg 0) #\-))
                 (if (char= (char arg 1) #\-)
                     ;; --key or --key=val
                     (let* ((rest (subseq arg 2))
                            (eq-pos (position #\= rest)))
                       (if eq-pos
                           (push (cons (subseq rest 0 eq-pos)
                                       (subseq rest (1+ eq-pos))) kvs)
                           (let ((next (nth (1+ i) argv)))
                             (if (and next (not (and (>= (length next) 1)
                                                     (char= (char next 0) #\-))))
                                 (progn
                                   (push (cons rest next) kvs)
                                   (incf i))
                                 (push (cons rest "1") kvs)))))
                     ;; -x → treat as positional for subcommands
                     (push arg pos))
                 (push arg pos)))
    (cons (nreverse pos) (nreverse kvs))))

(defun kv (kvs key &optional default)
  (or (cdr (assoc key kvs :test #'string=)) default))

(defun has-kv (kvs key)
  (not (null (cdr (assoc key kvs :test #'string=)))))

;;; ===========================================================================
;;; Output helpers
;;; ===========================================================================

(defun print-json (obj)
  (write-string (cl-json:encode-json-to-string obj) *standard-output*)
  (terpri))

(defun print-table (rows format-str &rest args)
  (apply #'format *standard-output* format-str args)
  (dolist (row rows)
    (format *standard-output* "~&~A" row)))

;;; ===========================================================================
;;; Commands
;;; ===========================================================================

(defun cmd-login (pos kvs)
  (declare (ignore pos))
  (let ((csrf (kv kvs "csrf"))
        (session (kv kvs "session"))
        (cookie (kv kvs "cookie")))
    (unless (and csrf session)
      (format *error-output* "~&Usage: notebooklm login --csrf TOKEN --session ID [--cookie HEADER]~%")
      (uiop:quit 1))
    (let ((path (save-auth csrf session cookie)))
      (format t "~&✅ Saved credentials to ~A~%" path)
      (format t "~&Try: notebooklm notebooks~%"))))

(defun cmd-notebooks (pos kvs)
  (declare (ignore pos kvs))
  (let ((client (make-client)))
    (unwind-protect
        (handler-case
            (let ((nbs (list-notebooks client)))
              (if nbs
                  (dolist (nb nbs)
                    (format t "~&~A  ~A~%"
                            (notebooklm-cl.types:notebook-id nb)
                            (notebooklm-cl.types:notebook-title nb)))
                  (format t "~&No notebooks found.~%")))
          (notebooklm-error (e)
            (format *error-output* "~&Error: ~A~%" e)
            (uiop:quit 1)))
      (close-client client))))

(defun cmd-sources (pos kvs)
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm sources <notebook-id> [--json]~%")
      (uiop:quit 1))
    (let* ((client (make-client))
           (json-p (has-kv kvs "json")))
      (unwind-protect
          (handler-case
              (let ((sources (list-sources client nb-id)))
                (if sources
                    (if json-p
                        (print-json (mapcar (lambda (s)
                                              `(("id" . ,(notebooklm-cl.types:source-id s))
                                                ("title" . ,(notebooklm-cl.types:source-title s))
                                                ("kind" . ,(notebooklm-cl.types:source-kind s))))
                                            sources))
                        (dolist (s sources)
                          (format t "~&~A  ~A  [~A]~%"
                                  (notebooklm-cl.types:source-id s)
                                  (notebooklm-cl.types:source-title s)
                                  (notebooklm-cl.types:source-kind s))))
                    (format t "~&No sources in notebook.~%")))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

(defun cmd-artifacts (pos kvs)
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm artifacts <notebook-id> [--type TYPE] [--json]~%")
      (uiop:quit 1))
    (let* ((client (make-client))
           (type-str (kv kvs "type"))
           (json-p (has-kv kvs "json"))
           (type-kw (when type-str
                      (intern (string-upcase type-str) :keyword))))
      (unwind-protect
          (handler-case
              (let ((arts (list-artifacts client nb-id :artifact-type type-kw)))
                (if arts
                    (if json-p
                        (print-json (mapcar (lambda (a)
                                              `(("id" . ,(notebooklm-cl.types:art-id a))
                                                ("title" . ,(notebooklm-cl.types:art-title a))
                                                ("kind" . ,(notebooklm-cl.types:artifact-kind a))
                                                ("status" . ,(notebooklm-cl.types:artifact-status-str a))))
                                            arts))
                        (dolist (a arts)
                          (format t "~&~A  ~A  ~A  ~A~%"
                                  (notebooklm-cl.types:art-id a)
                                  (notebooklm-cl.types:artifact-kind a)
                                  (notebooklm-cl.types:artifact-status-str a)
                                  (or (notebooklm-cl.types:art-title a) ""))))
                    (format t "~&No artifacts found.~%")))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

;;; ===========================================================================
;;; Generate command
;;; ===========================================================================

(defun cmd-generate (pos kvs)
  (let ((type (second pos))
        (nb-id (third pos)))
    (unless (and type nb-id)
      (format *error-output* "~&Usage: notebooklm generate <type> <notebook-id> [options]~%")
      (format *error-output* "~&Types: audio, report, quiz, flashcards, video, cinematic, infographic, slide-deck, data-table, mind-map~%")
      (uiop:quit 1))
    (let* ((client (make-client))
           (src-ids (when (has-kv kvs "source-ids")
                      (uiop:split-string (kv kvs "source-ids") :separator ",")))
           (lang (kv kvs "language"))
           (instr (kv kvs "instructions"))
           (result nil))
      (unwind-protect
          (handler-case
              (progn
                (setf result
                      (cond
                        ((string= type "audio")
                         (generate-audio client nb-id
                                         :source-ids src-ids :language lang
                                         :instructions instr))
                        ((string= type "report")
                         (let* ((fmt-str (kv kvs "format" "briefing_doc")))
                           (generate-report client nb-id
                                           :source-ids src-ids :language lang
                                           :report-format fmt-str
                                           :custom-prompt (kv kvs "prompt")
                                           :extra-instructions instr)))
                        ((string= type "quiz")
                         (generate-quiz client nb-id
                                        :source-ids src-ids :instructions instr))
                        ((string= type "flashcards")
                         (generate-flashcards client nb-id
                                              :source-ids src-ids :instructions instr))
                        ((string= type "video")
                         (generate-video client nb-id
                                         :source-ids src-ids :language lang
                                         :instructions instr))
                        ((string= type "cinematic")
                         (generate-cinematic-video client nb-id
                                                   :source-ids src-ids :language lang
                                                   :instructions instr))
                        ((string= type "infographic")
                         (generate-infographic client nb-id
                                               :source-ids src-ids :language lang
                                               :instructions instr))
                        ((string= type "slide-deck")
                         (generate-slide-deck client nb-id
                                              :source-ids src-ids :language lang
                                              :instructions instr))
                        ((string= type "data-table")
                         (generate-data-table client nb-id
                                              :source-ids src-ids :language lang
                                              :instructions instr))
                        ((string= type "mind-map")
                         (generate-mind-map client nb-id
                                            :source-ids src-ids :language lang
                                            :instructions instr))
                        (t
                         (format *error-output* "~&Unknown generate type: ~A~%" type)
                         (uiop:quit 1))))
                (let ((status (notebooklm-cl.types:gen-status result))
                      (task-id (notebooklm-cl.types:gen-task-id result)))
                  (format t "~&Status: ~A~%" status)
                  (format t "~&Task ID: ~A~%" task-id)
                  (when (and (string= status "in_progress") task-id
                             (plusp (length task-id)))
                    (format t "~&Run: notebooklm wait ~A ~A~%" nb-id task-id))))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

;;; ===========================================================================
;;; Download command
;;; ===========================================================================

(defun cmd-download (pos kvs)
  (let ((type (second pos))
        (nb-id (third pos))
        (out-path (fourth pos)))
    (unless (and type nb-id out-path)
      (format *error-output* "~&Usage: notebooklm download <type> <notebook-id> <output-path> [--id ARTIFACT-ID] [options]~%")
      (format *error-output* "~&Types: audio, video, infographic, report, data-table, slide-deck, quiz, flashcards, mind-map~%")
      (uiop:quit 1))
    (let* ((client (make-client))
           (art-id (kv kvs "id")))
      (unwind-protect
          (handler-case
              (let ((saved-path
                      (cond
                        ((string= type "audio")
                         (download-audio client nb-id out-path :artifact-id art-id))
                        ((string= type "video")
                         (download-video client nb-id out-path :artifact-id art-id))
                        ((string= type "infographic")
                         (download-infographic client nb-id out-path :artifact-id art-id))
                        ((string= type "report")
                         (download-report client nb-id out-path :artifact-id art-id))
                        ((string= type "data-table")
                         (download-data-table client nb-id out-path :artifact-id art-id))
                        ((string= type "slide-deck")
                         (download-slide-deck client nb-id out-path :artifact-id art-id
                                              :output-format (kv kvs "format" "pdf")))
                        ((string= type "quiz")
                         (download-quiz client nb-id out-path :artifact-id art-id
                                        :output-format (kv kvs "format" "markdown")))
                        ((string= type "flashcards")
                         (download-flashcards client nb-id out-path :artifact-id art-id
                                              :output-format (kv kvs "format" "markdown")))
                        ((string= type "mind-map")
                         (download-mind-map client nb-id out-path :artifact-id art-id))
                        (t
                         (format *error-output* "~&Unknown download type: ~A~%" type)
                         (uiop:quit 1)))))
                (format t "~&✅ Downloaded to ~A~%" saved-path))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

;;; ===========================================================================
;;; Wait command
;;; ===========================================================================

(defun cmd-wait (pos kvs)
  (let ((nb-id (second pos))
        (task-id (third pos)))
    (unless (and nb-id task-id)
      (format *error-output* "~&Usage: notebooklm wait <notebook-id> <task-id> [--timeout SECONDS]~%")
      (uiop:quit 1))
    (let* ((client (make-client))
           (timeout (ignore-errors (parse-integer (kv kvs "timeout" "300")))))
      (unwind-protect
          (handler-case
              (let ((result (wait-for-artifact client nb-id task-id :timeout (or timeout 300))))
                (let ((status (notebooklm-cl.types:gen-status result)))
                  (format t "~&Status: ~A~%" status)
                  (when (string= status "completed")
                    (format t "~&URL: ~A~%" (notebooklm-cl.types:gen-url result)))
                  (when (string= status "failed")
                    (format t "~&Error: ~A~%" (notebooklm-cl.types:gen-error result)))))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

;;; ===========================================================================
;;; Suggest command
;;; ===========================================================================

(defun cmd-suggest (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm suggest <notebook-id>~%")
      (uiop:quit 1))
    (let ((client (make-client)))
      (unwind-protect
          (handler-case
              (let ((suggestions (suggest-reports client nb-id)))
                (if suggestions
                    (dolist (s suggestions)
                      (format t "~&~A~%  ~A~%~%"
                              (notebooklm-cl.types:rs-title s)
                              (notebooklm-cl.types:rs-description s)))
                    (format t "~&No suggestions available.~%")))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

;;; ===========================================================================
;;; Delete / rename / add-url
;;; ===========================================================================

(defun cmd-delete-artifact (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos))
        (art-id (third pos)))
    (unless (and nb-id art-id)
      (format *error-output* "~&Usage: notebooklm delete-artifact <notebook-id> <artifact-id>~%")
      (uiop:quit 1))
    (let ((client (make-client)))
      (unwind-protect
          (handler-case
              (progn
                (delete-artifact client nb-id art-id)
                (format t "~&✅ Deleted ~A~%" art-id))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

(defun cmd-add-url (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos))
        (url (third pos)))
    (unless (and nb-id url)
      (format *error-output* "~&Usage: notebooklm add-url <notebook-id> <url>~%")
      (uiop:quit 1))
    (let ((client (make-client)))
      (unwind-protect
          (handler-case
              (let ((src (add-url client nb-id url)))
                (format t "~&✅ Added: ~A (~A)~%"
                        (notebooklm-cl.types:source-title src)
                        (notebooklm-cl.types:source-id src)))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

(defun cmd-delete-source (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos))
        (src-id (third pos)))
    (unless (and nb-id src-id)
      (format *error-output* "~&Usage: notebooklm delete-source <notebook-id> <source-id>~%")
      (uiop:quit 1))
    (let ((client (make-client)))
      (unwind-protect
          (handler-case
              (progn
                (delete-source client nb-id src-id)
                (format t "~&✅ Deleted source ~A~%" src-id))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

(defun cmd-get-metadata (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm metadata <notebook-id> [--json]~%")
      (uiop:quit 1))
    (let ((client (make-client)))
      (unwind-protect
          (handler-case
              (let ((meta (get-metadata client nb-id)))
                (if (has-kv kvs "json")
                    (print-json `(("notebook" . ,(when (notebooklm-cl.types:nb-meta-notebook meta)
                                                   `(("id" . ,(notebooklm-cl.types:notebook-id (notebooklm-cl.types:nb-meta-notebook meta)))
                                                     ("title" . ,(notebooklm-cl.types:notebook-title (notebooklm-cl.types:nb-meta-notebook meta))))))
                                  ("sources" . ,(mapcar (lambda (ss)
                                                          `(("kind" . ,(notebooklm-cl.types:ss-kind ss))
                                                            ("title" . ,(notebooklm-cl.types:ss-title ss))))
                                                        (notebooklm-cl.types:nb-meta-sources meta)))))
                    (progn
                      (let ((nb (notebooklm-cl.types:nb-meta-notebook meta)))
                        (when nb
                          (format t "~&Notebook: ~A~%" (notebooklm-cl.types:notebook-title nb))))
                      (dolist (ss (notebooklm-cl.types:nb-meta-sources meta))
                        (format t "~&  [~A] ~A~%"
                                (notebooklm-cl.types:ss-kind ss)
                                (notebooklm-cl.types:ss-title ss))))))
            (notebooklm-error (e)
              (format *error-output* "~&Error: ~A~%" e)
              (uiop:quit 1)))
        (close-client client)))))

;;; ===========================================================================
;;; Whoami
;;; ===========================================================================

(defun cmd-whoami (pos kvs)
  (declare (ignore pos kvs))
  (let ((auth (load-auth)))
    (if auth
        (format t "~&Logged in~%  csrf: ~A...~%  session: ~A~%  cookie: ~:[(none)~;~A...~]~%"
                (subseq (auth-tokens-csrf-token auth) 0 (min 20 (length (auth-tokens-csrf-token auth))))
                (auth-tokens-session-id auth)
                (and (auth-tokens-cookie-header auth)
                     (plusp (length (auth-tokens-cookie-header auth))))
                (when (auth-tokens-cookie-header auth)
                  (subseq (auth-tokens-cookie-header auth) 0 (min 40 (length (auth-tokens-cookie-header auth))))))
        (format t "~&Not logged in.~%  Run: notebooklm login --csrf TOKEN --session ID~%"))))

;;; ===========================================================================
;;; Main dispatcher
;;; ===========================================================================

(defun usage ()
  (format t "~&notebooklm — Common Lisp CLI for NotebookLM~%")
  (format t "~&~%")
  (format t "~&COMMANDS:~%")
  (format t "~&  login       Save credentials (first step)~%")
  (format t "~&  whoami      Show login status~%")
  (format t "~&  notebooks   List all notebooks~%")
  (format t "~&  sources     List sources in a notebook~%")
  (format t "~&  artifacts   List artifacts in a notebook~%")
  (format t "~&  generate    Generate an artifact~%")
  (format t "~&  download    Download an artifact~%")
  (format t "~&  wait        Wait for generation to complete~%")
  (format t "~&  suggest     Get suggested reports~%")
  (format t "~&  metadata    Get notebook metadata~%")
  (format t "~&  add-url     Add a URL source to a notebook~%")
  (format t "~&  delete-artifact  Delete an artifact~%")
  (format t "~&  delete-source    Delete a source~%")
  (format t "~&~%")
  (format t "~&EXAMPLES:~%")
  (format t "~&  notebooklm login --csrf AF1_QpN-... --session abc123...~%")
  (format t "~&  notebooklm notebooks~%")
  (format t "~&  notebooklm artifacts <nb-id> --type audio~%")
  (format t "~&  notebooklm generate audio <nb-id>~%")
  (format t "~&  notebooklm wait <nb-id> <task-id>~%")
  (format t "~&  notebooklm download audio <nb-id> overview.wav~%")
  (format t "~&  notebooklm add-url <nb-id> https://example.com/article~%")
  (format t "~&~%")
  (format t "~&Config stored at: ~A~%" (namestring *config-file*)))

(defun main ()
  (let* ((args (cdr (uiop:command-line-arguments)))
         (parsed (split-args args))
         (pos (car parsed))
         (kvs (cdr parsed))
         (cmd (first pos)))
    (cond
      ((or (null cmd) (string= cmd "help") (string= cmd "--help") (string= cmd "-h"))
       (usage))
      ((string= cmd "login")
       (cmd-login pos kvs))
      ((string= cmd "whoami")
       (cmd-whoami pos kvs))
      ((string= cmd "notebooks")
       (cmd-notebooks pos kvs))
      ((string= cmd "sources")
       (cmd-sources pos kvs))
      ((string= cmd "artifacts")
       (cmd-artifacts pos kvs))
      ((string= cmd "generate")
       (cmd-generate pos kvs))
      ((string= cmd "download")
       (cmd-download pos kvs))
      ((string= cmd "wait")
       (cmd-wait pos kvs))
      ((string= cmd "suggest")
       (cmd-suggest pos kvs))
      ((string= cmd "metadata")
       (cmd-get-metadata pos kvs))
      ((string= cmd "add-url")
       (cmd-add-url pos kvs))
      ((string= cmd "delete-artifact")
       (cmd-delete-artifact pos kvs))
      ((string= cmd "delete-source")
       (cmd-delete-source pos kvs))
      (t
       (format *error-output* "~&Unknown command: ~A~%" cmd)
       (terpri *error-output*)
       (usage)
       (uiop:quit 1)))))
