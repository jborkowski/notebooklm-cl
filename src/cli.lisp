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
                #:delete-source #:rename-source)
  (:import-from #:notebooklm-cl.artifacts
                #:list-artifacts
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
  (:import-from #:notebooklm-cl.types
                #:gen-status #:gen-task-id #:gen-url #:gen-error
                #:artifact-status-str
                #:art-id #:art-title #:artifact-kind
                #:rs-title #:rs-description
                #:notebook-id #:notebook-title
                #:source-id #:source-title #:source-kind
                #:nb-meta-notebook #:nb-meta-sources
                #:ss-kind #:ss-title)
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

(defun load-auth ()
  "Load auth from ~/.notebooklm-cl/auth.json.  Returns (values AUTH-TOKENS HL)."
  (handler-case
      (let* ((path *config-file*)
             (json (cl-json:decode-json-from-string
                    (with-open-file (in path :external-format :utf-8)
                      (let ((s (make-string (file-length in))))
                        (read-sequence s in)
                        s)))))
        (values
         (make-auth-tokens
          :csrf-token (cdr (assoc :csrf--token json))
          :session-id (cdr (assoc :session--id json))
          :cookie-header (cdr (assoc :cookie--header json)))
         (cdr (assoc :hl json))))
    (file-error () (values nil nil))
    (error (e)
      (format *error-output* "~&Warning: Could not load auth: ~A~%" e)
      (values nil nil))))

(defun save-auth (csrf session &optional cookie-header hl)
  "Save auth credentials to ~/.notebooklm-cl/auth.json."
  (ensure-directories-exist *config-file*)
  (let ((data `((:csrf--token . ,csrf)
                (:session--id . ,session)
                (:cookie--header . ,(or cookie-header ""))
                (:hl . ,(or hl "en")))))
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
  (multiple-value-bind (auth hl) (load-auth)
    (declare (ignore hl))
    (require-auth auth)
    (let ((client (make-client-core :auth auth)))
      (open-client client)
      client)))

;;; ===========================================================================
;;; Macro: with-nblm-client
;;; ===========================================================================

(defmacro with-nblm-client ((client-var) &body body)
  "Execute BODY with a live notebooklm client bound to CLIENT-VAR.
Opens client before BODY, closes on unwind, catches notebooklm-error."
  `(let ((,client-var (make-client)))
     (unwind-protect
         (handler-case (progn ,@body)
           (notebooklm-error (e)
             (format *error-output* "~&Error: ~A~%" e)
             (uiop:quit 1)))
       (close-client ,client-var))))

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
                     (let* ((rest (subseq arg 2))
                            (eq-pos (position #\= rest)))
                       (if eq-pos
                           (push (cons (subseq rest 0 eq-pos)
                                       (subseq rest (1+ eq-pos))) kvs)
                           (let ((next (nth (1+ i) argv)))
                             (if (and next (not (and (>= (length next) 1)
                                                     (char= (char next 0) #\-))))
                                 (progn (push (cons rest next) kvs) (incf i))
                                 (push (cons rest "1") kvs)))))
                     (push arg pos))
                 (push arg pos)))
    (cons (nreverse pos) (nreverse kvs))))

(defun kv (kvs key &optional default)
  (or (cdr (assoc key kvs :test #'string=)) default))

(defun has-kv (kvs key)
  (not (null (cdr (assoc key kvs :test #'string=)))))

(defun print-json (obj)
  "Print OBJ as compact JSON to stdout."
  (write-string (cl-json:encode-json-to-string obj))
  (terpri))

;;; ===========================================================================
;;; cURL parser helpers
;;; ===========================================================================

(defun %url-decode (s)
  "Decode percent-encoded URL string (%XX => char)."
  (with-output-to-string (out)
    (loop with i = 0 while (< i (length s))
          for c = (char s i)
          do (if (char= c #\%)
                 (let ((hex (subseq s (1+ i) (min (+ i 3) (length s)))))
                   (when (>= (length hex) 2)
                     (handler-case
                         (write-char (code-char (parse-integer hex :radix 16)) out)
                       (error () (write-char #\% out)))
                     (incf i 3)))
                 (progn (write-char c out) (incf i))))))

(defun %extract-url-param (text param-name)
  "Extract &NAME=VALUE from a URL-ish string."
  (let* ((prefix (concatenate 'string param-name "="))
         (start (search prefix text)))
    (when start
      (let* ((val-start (+ start (length prefix)))
             (end (position-if (lambda (c) (member c '(#\& #\' #\" #\Newline)))
                               text :start val-start)))
        (subseq text val-start (or end (length text)))))))

(defun %extract-curl-b-cookies (text)
  "Extract cookies from Chrome '-b' cURL flag."
  (let ((start (search "-b '" text)))
    (when start
      (let* ((val-start (+ start 4))
             (end (position #\' text :start val-start)))
        (when end (subseq text val-start end))))))

(defun %extract-header (text header-name)
  "Extract 'Header-Name: value' (case-insensitive)."
  (let* ((lower (string-downcase text))
         (prefix (concatenate 'string (string-downcase header-name) ": "))
         (start (search prefix lower)))
    (when start
      (let* ((val-start (+ start (length prefix)))
             (end (position-if (lambda (c) (member c '(#\Newline #\Return #\')))
                               text :start val-start))
             (raw (subseq text val-start (or end (length text)))))
        (string-trim " " raw)))))

(defun %parse-curl-from-stdin ()
  "Read 'Copy as cURL' from stdin, extract f.sid, at=, hl, Cookie header.
Returns (values session-id csrf-token cookie-header hl)."
  (let ((text (make-string-output-stream)))
    (loop for line = (read-line *standard-input* nil nil)
          while line do (write-string line text) (write-char #\Newline text))
    (let* ((s (get-output-stream-string text))
           (session (%extract-url-param s "f.sid"))
           (csrf-raw (%extract-url-param s "at"))
           (csrf (when csrf-raw (%url-decode csrf-raw)))
           (hl (or (%extract-url-param s "hl") "en"))
           (cookie (or (%extract-header s "cookie")
                       (%extract-curl-b-cookies s))))
      (values session csrf cookie hl))))

;;; ===========================================================================
;;; Commands
;;; ===========================================================================

(defun cmd-login (pos kvs)
  (declare (ignore pos))
  (let ((csrf (kv kvs "csrf"))
        (session (kv kvs "session"))
        (cookie (kv kvs "cookie"))
        (hl (kv kvs "hl")))
    (when (has-kv kvs "curl")
      (multiple-value-bind (curl-session curl-csrf curl-cookie curl-hl)
          (%parse-curl-from-stdin)
        (setf session (or session curl-session)
              csrf (or csrf curl-csrf)
              cookie (or cookie curl-cookie)
              hl (or hl curl-hl))))
    (unless (and csrf session)
      (format *error-output* "~&Usage: notebooklm login --csrf TOKEN --session ID [--cookie HEADER]~%")
      (format *error-output* "~&  or: notebooklm login --curl  (paste cURL from DevTools, then Ctrl+D)~%")
      (uiop:quit 1))
    (let ((path (save-auth csrf session cookie hl)))
      (format t "~&Saved credentials to ~A~%" path)
      (format t "~&Try: notebooklm notebooks~%"))))

(defun cmd-whoami (pos kvs)
  (declare (ignore pos kvs))
  (multiple-value-bind (auth hl) (load-auth)
    (if auth
        (format t "~&Logged in~%  csrf: ~A...~%  session: ~A~%  cookie: ~:[(none)~;~A...~]~%  language: ~A~%"
                (subseq (auth-tokens-csrf-token auth) 0 (min 20 (length (auth-tokens-csrf-token auth))))
                (auth-tokens-session-id auth)
                (and (auth-tokens-cookie-header auth)
                     (plusp (length (auth-tokens-cookie-header auth))))
                (when (auth-tokens-cookie-header auth)
                  (subseq (auth-tokens-cookie-header auth) 0 (min 40 (length (auth-tokens-cookie-header auth)))))
                (or hl "en"))
        (format t "~&Not logged in.~%  Run: notebooklm login --csrf TOKEN --session ID~%"))))

(defun cmd-notebooks (pos kvs)
  (declare (ignore pos kvs))
  (with-nblm-client (c)
    (let ((nbs (list-notebooks c)))
      (if nbs
          (dolist (nb nbs)
            (format t "~&~A  ~A~%" (notebook-id nb) (notebook-title nb)))
          (format t "~&No notebooks found.~%")))))

(defun cmd-sources (pos kvs)
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm sources <notebook-id> [--json]~%")
      (uiop:quit 1))
    (let ((json-p (has-kv kvs "json")))
      (with-nblm-client (c)
        (let ((sources (list-sources c nb-id)))
          (if sources
              (if json-p
                  (print-json (mapcar (lambda (s)
                                        `(("id" . ,(source-id s))
                                          ("title" . ,(source-title s))
                                          ("kind" . ,(source-kind s))))
                                      sources))
                  (dolist (s sources)
                    (format t "~&~A  ~A  [~A]~%" (source-id s) (source-title s) (source-kind s))))
              (format t "~&No sources in notebook.~%")))))))

(defun cmd-artifacts (pos kvs)
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm artifacts <notebook-id> [--type TYPE] [--json]~%")
      (uiop:quit 1))
    (let* ((type-str (kv kvs "type"))
           (json-p (has-kv kvs "json"))
           (type-kw (when type-str (intern (string-upcase type-str) :keyword))))
      (with-nblm-client (c)
        (let ((arts (list-artifacts c nb-id :artifact-type type-kw)))
          (if arts
              (if json-p
                  (print-json (mapcar (lambda (a)
                                        `(("id" . ,(art-id a))
                                          ("title" . ,(art-title a))
                                          ("kind" . ,(artifact-kind a))
                                          ("status" . ,(artifact-status-str a))))
                                      arts))
                  (dolist (a arts)
                    (format t "~&~A  ~A  ~A  ~A~%"
                            (art-id a) (artifact-kind a)
                            (artifact-status-str a) (or (art-title a) ""))))
              (format t "~&No artifacts found.~%")))))))

(defun cmd-create-notebook (pos kvs)
  (declare (ignore kvs))
  (let ((title (second pos)))
    (unless title
      (format *error-output* "~&Usage: notebooklm create-notebook <title>~%")
      (uiop:quit 1))
    (with-nblm-client (c)
      (let ((nb (create-notebook c title)))
        (format t "~&Created: ~A~%" (notebook-id nb))
        (format t "~&   Title: ~A~%" (notebook-title nb))))))

(defun cmd-add-url (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos)) (url (third pos)))
    (unless (and nb-id url)
      (format *error-output* "~&Usage: notebooklm add-url <notebook-id> <url>~%")
      (uiop:quit 1))
    (with-nblm-client (c)
      (let ((src (add-url c nb-id url)))
        (format t "~&Added: ~A (~A)~%" (source-title src) (source-id src))))))

(defun cmd-delete-source (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos)) (src-id (third pos)))
    (unless (and nb-id src-id)
      (format *error-output* "~&Usage: notebooklm delete-source <notebook-id> <source-id>~%")
      (uiop:quit 1))
    (with-nblm-client (c)
      (delete-source c nb-id src-id)
      (format t "~&Deleted source ~A~%" src-id))))

(defun cmd-delete-artifact (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos)) (art-id (third pos)))
    (unless (and nb-id art-id)
      (format *error-output* "~&Usage: notebooklm delete-artifact <notebook-id> <artifact-id>~%")
      (uiop:quit 1))
    (with-nblm-client (c)
      (delete-artifact c nb-id art-id)
      (format t "~&Deleted ~A~%" art-id))))

(defun cmd-get-metadata (pos kvs)
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm metadata <notebook-id> [--json]~%")
      (uiop:quit 1))
    (with-nblm-client (c)
      (let ((meta (get-metadata c nb-id)))
        (if (has-kv kvs "json")
            (print-json `(("notebook" . ,(when (nb-meta-notebook meta)
                                           `(("id" . ,(notebook-id (nb-meta-notebook meta)))
                                             ("title" . ,(notebook-title (nb-meta-notebook meta))))))
                          ("sources" . ,(mapcar (lambda (ss)
                                                  `(("kind" . ,(ss-kind ss))
                                                    ("title" . ,(ss-title ss))))
                                                (nb-meta-sources meta)))))
            (progn
              (let ((nb (nb-meta-notebook meta)))
                (when nb (format t "~&Notebook: ~A~%" (notebook-title nb))))
              (dolist (ss (nb-meta-sources meta))
                (format t "~&  [~A] ~A~%" (ss-kind ss) (ss-title ss)))))))))

(defun cmd-suggest (pos kvs)
  (declare (ignore kvs))
  (let ((nb-id (second pos)))
    (unless nb-id
      (format *error-output* "~&Usage: notebooklm suggest <notebook-id>~%")
      (uiop:quit 1))
    (with-nblm-client (c)
      (let ((suggestions (suggest-reports c nb-id)))
        (if suggestions
            (dolist (s suggestions)
              (format t "~&~A~%  ~A~%~%" (rs-title s) (rs-description s)))
            (format t "~&No suggestions available.~%"))))))

(defun cmd-generate (pos kvs)
  (let ((type (second pos)) (nb-id (third pos)))
    (unless (and type nb-id)
      (format *error-output* "~&Usage: notebooklm generate <type> <notebook-id> [options]~%")
      (format *error-output* "~&Types: audio, report, quiz, flashcards, video, cinematic, infographic, slide-deck, data-table, mind-map~%")
      (uiop:quit 1))
    (let ((src-ids (when (has-kv kvs "source-ids")
                     (uiop:split-string (kv kvs "source-ids") :separator ",")))
          (lang (kv kvs "language"))
          (instr (kv kvs "instructions")))
      (with-nblm-client (c)
        (let ((result
                (cond
                  ((string= type "audio")
                   (generate-audio c nb-id :source-ids src-ids :language lang :instructions instr))
                  ((string= type "report")
                   (generate-report c nb-id :source-ids src-ids :language lang
                                    :report-format (kv kvs "format" "briefing_doc")
                                    :custom-prompt (kv kvs "prompt")
                                    :extra-instructions instr))
                  ((string= type "quiz")
                   (generate-quiz c nb-id :source-ids src-ids :instructions instr))
                  ((string= type "flashcards")
                   (generate-flashcards c nb-id :source-ids src-ids :instructions instr))
                  ((string= type "video")
                   (generate-video c nb-id :source-ids src-ids :language lang :instructions instr))
                  ((string= type "cinematic")
                   (generate-cinematic-video c nb-id :source-ids src-ids :language lang
                                             :instructions instr))
                  ((string= type "infographic")
                   (generate-infographic c nb-id :source-ids src-ids :language lang :instructions instr))
                  ((string= type "slide-deck")
                   (generate-slide-deck c nb-id :source-ids src-ids :language lang :instructions instr))
                  ((string= type "data-table")
                   (generate-data-table c nb-id :source-ids src-ids :language lang :instructions instr))
                  ((string= type "mind-map")
                   (generate-mind-map c nb-id :source-ids src-ids :language lang :instructions instr))
                  (t (format *error-output* "~&Unknown generate type: ~A~%" type)
                     (uiop:quit 1)))))
          (let ((status (gen-status result))
                (task-id (gen-task-id result)))
            (format t "~&Status: ~A~%" status)
            (format t "~&Task ID: ~A~%" task-id)
            (when (and (string= status "in_progress") task-id (plusp (length task-id)))
              (format t "~&Run: notebooklm wait ~A ~A~%" nb-id task-id))))))))

(defun cmd-download (pos kvs)
  (let ((type (second pos)) (nb-id (third pos)) (out-path (fourth pos)))
    (unless (and type nb-id out-path)
      (format *error-output* "~&Usage: notebooklm download <type> <notebook-id> <output-path> [--id ARTIFACT-ID] [options]~%")
      (uiop:quit 1))
    (let ((art-id (kv kvs "id")))
      (with-nblm-client (c)
        (let ((saved-path
                (cond
                  ((string= type "audio") (download-audio c nb-id out-path :artifact-id art-id))
                  ((string= type "video") (download-video c nb-id out-path :artifact-id art-id))
                  ((string= type "infographic") (download-infographic c nb-id out-path :artifact-id art-id))
                  ((string= type "report") (download-report c nb-id out-path :artifact-id art-id))
                  ((string= type "data-table") (download-data-table c nb-id out-path :artifact-id art-id))
                  ((string= type "slide-deck")
                   (download-slide-deck c nb-id out-path :artifact-id art-id
                                        :output-format (kv kvs "format" "pdf")))
                  ((string= type "quiz")
                   (download-quiz c nb-id out-path :artifact-id art-id
                                  :output-format (kv kvs "format" "markdown")))
                  ((string= type "flashcards")
                   (download-flashcards c nb-id out-path :artifact-id art-id
                                        :output-format (kv kvs "format" "markdown")))
                  ((string= type "mind-map") (download-mind-map c nb-id out-path :artifact-id art-id))
                  (t (format *error-output* "~&Unknown download type: ~A~%" type)
                     (uiop:quit 1)))))
          (format t "~&Downloaded to ~A~%" saved-path))))))

(defun cmd-wait (pos kvs)
  (let ((nb-id (second pos)) (task-id (third pos)))
    (unless (and nb-id task-id)
      (format *error-output* "~&Usage: notebooklm wait <notebook-id> <task-id> [--timeout SECONDS]~%")
      (uiop:quit 1))
    (let ((timeout (ignore-errors (parse-integer (kv kvs "timeout" "300")))))
      (with-nblm-client (c)
        (let ((result (wait-for-artifact c nb-id task-id :timeout (or timeout 300))))
          (let ((status (gen-status result)))
            (format t "~&Status: ~A~%" status)
            (when (string= status "completed")
              (format t "~&URL: ~A~%" (gen-url result)))
            (when (string= status "failed")
              (format t "~&Error: ~A~%" (gen-error result)))))))))

;;; ===========================================================================
;;; Main dispatcher
;;; ===========================================================================

(defun usage ()
  (format t "~&notebooklm -- Common Lisp CLI for NotebookLM~2%")
  (format t "~&COMMANDS:~%")
  (format t "~&  login             Save credentials (first step)~%")
  (format t "~&  whoami            Show login status~%")
  (format t "~&  notebooks         List all notebooks~%")
  (format t "~&  create-notebook   Create a new notebook~%")
  (format t "~&  sources           List sources in a notebook~%")
  (format t "~&  artifacts         List artifacts in a notebook~%")
  (format t "~&  generate          Generate an artifact~%")
  (format t "~&  download          Download an artifact~%")
  (format t "~&  wait              Wait for generation to complete~%")
  (format t "~&  suggest           Get suggested reports~%")
  (format t "~&  metadata          Get notebook metadata~%")
  (format t "~&  add-url           Add a URL source~%")
  (format t "~&  delete-artifact   Delete an artifact~%")
  (format t "~&  delete-source     Delete a source~2%")
  (format t "~&Login:~%")
  (format t "~&  notebooklm login --csrf TOKEN --session ID~%")
  (format t "~&  pbpaste | notebooklm login --curl  (paste from DevTools)~2%")
  (format t "~&Workflow:~%")
  (format t "~&  notebooklm create-notebook \"Research\"~%")
  (format t "~&  notebooklm add-url <nb-id> <url>~%")
  (format t "~&  notebooklm generate audio <nb-id>~%")
  (format t "~&  notebooklm wait <nb-id> <task-id>~%")
  (format t "~&  notebooklm download audio <nb-id> output.wav~2%")
  (format t "~&Config: ~A~%" (namestring *config-file*)))

(defun main ()
  (let* ((args (uiop:command-line-arguments))
         (parsed (split-args args))
         (pos (car parsed))
         (kvs (cdr parsed))
         (cmd (first pos)))
    (cond
      ((or (null cmd) (string= cmd "help")) (usage))
      ((string= cmd "login")    (cmd-login pos kvs))
      ((string= cmd "whoami")   (cmd-whoami pos kvs))
      ((string= cmd "notebooks") (cmd-notebooks pos kvs))
      ((string= cmd "create-notebook") (cmd-create-notebook pos kvs))
      ((string= cmd "sources")  (cmd-sources pos kvs))
      ((string= cmd "artifacts") (cmd-artifacts pos kvs))
      ((string= cmd "generate") (cmd-generate pos kvs))
      ((string= cmd "download") (cmd-download pos kvs))
      ((string= cmd "wait")     (cmd-wait pos kvs))
      ((string= cmd "suggest")  (cmd-suggest pos kvs))
      ((string= cmd "metadata") (cmd-get-metadata pos kvs))
      ((string= cmd "add-url")  (cmd-add-url pos kvs))
      ((string= cmd "delete-artifact") (cmd-delete-artifact pos kvs))
      ((string= cmd "delete-source") (cmd-delete-source pos kvs))
      (t
       (format *error-output* "~&Unknown command: ~A~2%" cmd)
       (usage)
       (uiop:quit 1)))))
