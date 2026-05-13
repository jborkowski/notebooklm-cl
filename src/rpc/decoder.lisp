(in-package #:notebooklm-cl.rpc.decoder)

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
  (loop for chunk in chunks
        for items = (if (and (consp chunk) (consp (first chunk))) chunk (list chunk))
        nconc (loop for item in items
                    when (and (consp item) (>= (length item) 2)
                              (member (first item) '("wrb.fr" "er") :test #'string=)
                              (stringp (second item)))
                    collect (second item))))

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
  (dolist (chunk chunks)
    (dolist (item (if (and (consp chunk) (consp (first chunk))) chunk (list chunk)))
      (when (and (consp item) (>= (length item) 6))
        (destructuring-bind (kind id result nil nil error-info) item
          (declare (ignore result))
          (when (and (string= kind "wrb.fr")
                     (string= id rpc-id)
                     error-info)
            (let ((status (extract-status-code error-info)))
              (when status (return-from find-wrb-status status)))))))))

(defun extract-rpc-result (chunks rpc-id)
  (dolist (chunk chunks)
    (dolist (item (if (and (consp chunk) (consp (first chunk))) chunk (list chunk)))
      (when (and (consp item) (>= (length item) 3))
        (let ((kind (first item))
              (id (second item)))
          (when (string= id rpc-id)
            (cond
              ((string= kind "er")
               (error 'notebooklm-cl.errors:rpc-error
                      :method-id rpc-id
                      :rpc-code (third item)))
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
                     (return-from extract-rpc-result result))))))))))
  nil))

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
               (error 'notebooklm-cl.errors:rpc-error
                      :method-id rpc-id
                      :found-ids found-ids
                      :raw-response preview))
              ((member rpc-id found-ids :test #'string=)
               (let ((status (find-wrb-status chunks rpc-id)))
                 (if status
                     (if (member (car status) '(5 7))
                         (error 'notebooklm-cl.errors:client-error
                                :method-id rpc-id
                                :rpc-code (car status)
                                :found-ids found-ids
                                :raw-response preview)
                         (error 'notebooklm-cl.errors:rpc-error
                                :method-id rpc-id
                                :rpc-code (car status)
                                :found-ids found-ids
                                :raw-response preview))
                     (error 'notebooklm-cl.errors:rpc-error
                            :method-id rpc-id
                            :found-ids found-ids
                            :raw-response preview))))
              (t
               (error 'notebooklm-cl.errors:rpc-error
                      :method-id rpc-id
                      :raw-response preview))))
          result)
      (notebooklm-cl.errors:rpc-error (e)
        (unless (notebooklm-cl.errors:rpc-error-found-ids e)
          (setf (slot-value e 'notebooklm-cl.errors::found-ids) found-ids))
        (error e)))))
