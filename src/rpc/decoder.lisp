(in-package #:notebooklm-cl.rpc.decoder)

(defmacro do-rpc-items ((item chunks) &body body)
  "Iterate over ITEM in each CHUNKS entry, normalising each chunk to a list.
The RPC response delivers each chunk as a list of items; when the chunk itself
contains sub-lists the first atomic element is the chunk wrapper — unwrap it."
  `(dolist (chunk ,chunks)
     (dolist (,item (if (and (consp chunk) (consp (first chunk))) chunk (list chunk)))
       ,@body)))

(defmacro do-matched-rpc-items ((kind-var id-var) (item-var chunks rpc-id &key min-length) &body body)
  "Iterate over RPC response chunks, bind KIND-VAR / ID-VAR from each item,
filtering to items where id matches RPC-ID.  MIN-LENGTH guards item length (default 3)."
  `(do-rpc-items (,item-var ,chunks)
     (when (and (consp ,item-var) (>= (length ,item-var) ,(or min-length 3)))
       (let ((,kind-var (first ,item-var))
             (,id-var (second ,item-var)))
         (when (string= ,id-var ,rpc-id)
           ,@body)))))

(defun %signal-rpc-error (condition-type rpc-id &key rpc-code found-ids raw-response)
  "Signal an RPC-derived condition with the common slots filled."
  (error condition-type
         :method-id rpc-id
         :rpc-code rpc-code
         :found-ids found-ids
         :raw-response raw-response))

(defvar *grpc-status-messages*
  '((0 . "OK") (1 . "Cancelled") (2 . "Unknown") (3 . "Invalid argument")
    (4 . "Deadline exceeded") (5 . "Not found") (6 . "Already exists")
    (7 . "Permission denied") (8 . "Resource exhausted") (9 . "Failed precondition")
    (10 . "Aborted") (11 . "Out of range") (12 . "Not implemented")
    (13 . "Internal") (14 . "Unavailable") (15 . "Data loss") (16 . "Unauthenticated")))

(defun split-lines (string)
  (loop for start = 0 then (1+ end)
        for end = (position #\Newline string :start start)
        for line = (subseq string start end)
        unless (string= line "")
        collect line
        while end))

(defun strip-anti-xssi (response)
  (if (notebooklm-cl.util:starts-with-p response ")]}'")
      (let ((pos (position #\Newline response)))
        (if pos (subseq response (1+ pos)) response))
      response))

(defun parse-chunked-response (response)
  (let* ((lines (split-lines response))
         (n (length lines))
         (chunks '())
         (skipped 0))
    (dolist (line lines)
      (cond
        ((ignore-errors (parse-integer line)) nil)
        (t
         (handler-case (push (cl-json:decode-json-from-string line) chunks)
           (error () (incf skipped))))))
    (when (and (> skipped 0) (> (/ skipped (max 1 n)) 0.1))
      (error 'notebooklm-cl.errors:rpc-error
             :raw-response (subseq response 0 (min 500 (length response)))))
    (nreverse chunks)))

(defun collect-rpc-ids (chunks)
  (let ((ids nil))
    (do-rpc-items (item chunks)
      (when (and (consp item) (>= (length item) 2)
                 (member (first item) '("wrb.fr" "er") :test #'string=)
                 (stringp (second item)))
        (push (second item) ids)))
    (nreverse ids)))

(defun contains-user-displayable-error-p (obj)
  (typecase obj
    (string (search "UserDisplayableError" obj))
    (list (some #'contains-user-displayable-error-p obj))
    (t nil)))

(defun extract-status-code (error-info)
  (when (and (consp error-info)
             (= (length error-info) 1)
             (integerp (first error-info))
             (assoc (first error-info) *grpc-status-messages*))
    (cons (first error-info)
          (cdr (assoc (first error-info) *grpc-status-messages*)))))

(defun find-wrb-status (chunks rpc-id)
  (do-matched-rpc-items (kind id) (item chunks rpc-id :min-length 6)
    (when (string= kind "wrb.fr")
      (destructuring-bind (nil nil nil nil nil error-info) item
        (when error-info
          (let ((status (extract-status-code error-info)))
            (when status (return-from find-wrb-status status))))))))

(defun extract-rpc-result (chunks rpc-id)
  (do-matched-rpc-items (kind id) (item chunks rpc-id)
    (cond
      ((string= kind "er")
       (%signal-rpc-error 'notebooklm-cl.errors:rpc-error rpc-id :rpc-code (third item)))
      ((string= kind "wrb.fr")
       (let ((result (third item)))
         (when (and (null result) (>= (length item) 6))
           (let ((error-info (sixth item)))
             (when (and (consp error-info)
                        (contains-user-displayable-error-p error-info))
               (error 'notebooklm-cl.errors:rate-limit-error
                      :method-id rpc-id
                      :rpc-code "USER_DISPLAYABLE_ERROR"))))
         (if (stringp result)
             (handler-case (return-from extract-rpc-result
                             (cl-json:decode-json-from-string result))
               (error () (return-from extract-rpc-result result)))
             (return-from extract-rpc-result result))))))
  nil)

(defun decode-response (raw-response rpc-id &key allow-null)
  (let* ((cleaned (strip-anti-xssi raw-response))
         (chunks (parse-chunked-response cleaned))
         (preview (subseq cleaned 0 (min 500 (length cleaned))))
         (found-ids (collect-rpc-ids chunks)))
    (handler-case
        (let ((result (extract-rpc-result chunks rpc-id)))
          (when (and (null result) (not allow-null))
            (cond
              ((and found-ids (not (member rpc-id found-ids :test #'string=)))
               (%signal-rpc-error 'rpc-error rpc-id :found-ids found-ids :raw-response preview))
              ((member rpc-id found-ids :test #'string=)
               (let ((status (find-wrb-status chunks rpc-id)))
                 (if status
                     (%signal-rpc-error
                      (if (member (car status) '(5 7)) 'client-error 'rpc-error)
                      rpc-id :rpc-code (car status) :found-ids found-ids :raw-response preview)
                     (%signal-rpc-error 'rpc-error rpc-id :found-ids found-ids :raw-response preview))))
              (t
               (%signal-rpc-error 'rpc-error rpc-id :raw-response preview))))
          result)
      (notebooklm-cl.errors:rpc-error (e)
        (unless (notebooklm-cl.errors:rpc-error-found-ids e)
          (setf (slot-value e 'notebooklm-cl.errors::found-ids) found-ids))
        (error e)))))
