(in-package #:notebooklm-cl.sources)

;;; ===========================================================================
;;; Path + auth helpers (upload uses browser-style headers)
;;; ===========================================================================

(defun %notebook-path (notebook-id)
  (format nil "/notebook/~A" notebook-id))

(defun %authuser-route (auth)
  "Mirror Python format_authuser_value: prefer account email, else authuser index."
  (if (and auth (auth-tokens-account-email auth))
      (let ((e (string-trim " " (auth-tokens-account-email auth))))
        (if (plusp (length e)) e (format nil "~A" (or (auth-tokens-authuser auth) "0"))))
      (format nil "~A" (or (and auth (auth-tokens-authuser auth)) "0"))))

(defun %upload-url-with-authquery (auth)
  (format nil "~A?authuser=~A"
          (notebooklm-cl.rpc.types:get-upload-url)
          (notebooklm-cl.util:url-encode (%authuser-route auth))))

(defun %dex-header-get (headers key)
  (when headers
    (typecase headers
      (hash-table
       (or (gethash key headers)
           (gethash (string-downcase key) headers)
           (loop for k being the hash-keys of headers using (hash-value v)
                 thereis (when (string-equal k key) v))))
      (list
       (cdr (assoc key headers :test #'string-equal))))))

(defun %first-nested-string (data)
  "First non-empty string found by DFS (ADD_SOURCE_FILE id extraction)."
  (labels ((walk (x)
             (typecase x
               (string (if (plusp (length x)) x nil))
               (list (dolist (el x)
                       (let ((w (walk el)))
                         (when w (return-from walk w)))))
               (t nil))))
    (walk data)))

;;; ===========================================================================
;;; Freshness (CHECK_SOURCE_FRESHNESS) — testable predicate
;;; ===========================================================================

(defun source-freshness-fresh-p (result)
  "Return T if API considers the source fresh, NIL if stale or unknown.
Aligned with notebooklm-py `check_freshness`. Limitation: JSON `false` and
empty array `[]` can both decode as NIL in Common Lisp; both follow the `[]`
branch here via `(LISTP NIL)` ⇒ fresh."
  (cond ((eq result t) t)
        ((listp result)
         (if (null result)
             t
             (let ((first (first result)))
               (when (and (listp first) (> (length first) 1) (eq (second first) t))
                 t))))
        (t nil)))

;;; ===========================================================================
;;; list-sources / get-source
;;; ===========================================================================

(defun list-sources (client notebook-id &key strict)
  "Return sources for NOTEBOOK-ID via GET_NOTEBOOK (same snapshot as Python list())."
  (let* ((params (list notebook-id nil (list 2) nil 0))
         (notebook (notebooklm-cl.core:rpc-call
                    client notebooklm-cl.rpc.types:*get-notebook*
                    params
                    :source-path (%notebook-path notebook-id)))
         (bad (not (and notebook (listp notebook) (plusp (length notebook))))))
    (when bad
      (when strict (error 'notebooklm-cl.errors:validation-error))
      (return-from list-sources nil))
    (let ((nb-info (first notebook)))
      (unless (and (listp nb-info) (> (length nb-info) 1))
        (when strict (error 'notebooklm-cl.errors:validation-error))
        (return-from list-sources nil))
      (let ((sources-list (second nb-info)))
        (unless (listp sources-list)
          (when strict (error 'notebooklm-cl.errors:validation-error))
          (return-from list-sources nil))
        (loop for src in sources-list
              when (and (listp src) (plusp (length src)))
              append (handler-case (list (source-from-api-response src))
                       (error () nil)))))))

(defun get-source (client notebook-id source-id)
  "Look up SOURCE-ID via list-sources (GET_SOURCE RPC is unreliable for new sources)."
  (find source-id (list-sources client notebook-id)
        :key #'source-id :test #'string=))

;;; ===========================================================================
;;; add-url / add-text / add-drive / delete / rename / refresh / freshness
;;; ===========================================================================

(defun %add-youtube (client notebook-id url)
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*add-source*
   (list (list (list nil nil nil nil nil nil nil (list url) nil nil 1))
         notebook-id
         (list 2)
         (list 1 nil nil nil nil nil nil nil nil nil (list 1)))
   :source-path (%notebook-path notebook-id)
   :allow-null t))

(defun %add-web-url (client notebook-id url)
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*add-source*
   (list (list (list nil nil (list url) nil nil nil nil nil))
         notebook-id
         (list 2)
         nil
         nil)
   :source-path (%notebook-path notebook-id)))

(defun add-url (client notebook-id url)
  "Add a URL or YouTube source. Signals source-add-error on failure."
  (handler-case
      (let* ((vid (extract-youtube-video-id url))
             (result (if vid (%add-youtube client notebook-id url)
                         (%add-web-url client notebook-id url))))
        (unless result
          (error 'notebooklm-cl.errors:source-add-error
                 :label url
                 :message "API returned no data"))
        (source-from-api-response result))
    (notebooklm-cl.errors:rpc-error (e)
      (error 'notebooklm-cl.errors:source-add-error :label url :cause e))))

(defun add-text-source (client notebook-id title content)
  "Add pasted text as a source."
  (handler-case
      (let ((result (notebooklm-cl.core:rpc-call
                     client notebooklm-cl.rpc.types:*add-source*
                     (list (list (list nil (list title content) nil nil nil nil nil nil))
                           notebook-id
                           (list 2)
                           nil
                           nil)
                     :source-path (%notebook-path notebook-id))))
        (unless result
          (error 'notebooklm-cl.errors:source-add-error
                 :label title
                 :message "API returned no data"))
        (source-from-api-response result))
    (notebooklm-cl.errors:rpc-error (e)
      (error 'notebooklm-cl.errors:source-add-error :label title :cause e))))

(defun add-drive-source (client notebook-id file-id title
                         &optional (mime-type notebooklm-cl.rpc.types:+drive-mime-google-doc+))
  "Add a Google Drive file by FILE-ID."
  (let ((source-data (list file-id mime-type 1 title
                           nil nil nil nil nil nil nil
                           1))
        (result (notebooklm-cl.core:rpc-call
                 client notebooklm-cl.rpc.types:*add-source*
                 (list (list source-data)
                       notebook-id
                       (list 2)
                       (list 1 nil nil nil nil nil nil nil nil nil (list 1)))
                 :source-path (%notebook-path notebook-id)
                 :allow-null t)))
    (source-from-api-response result)))

(defun delete-source (client notebook-id source-id)
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*delete-source*
   (list (list (list source-id)))
   :source-path (%notebook-path notebook-id)
   :allow-null t)
  t)

(defun rename-source (client notebook-id source-id new-title)
  (let ((result (notebooklm-cl.core:rpc-call
                 client notebooklm-cl.rpc.types:*update-source*
                 (list nil (list source-id) (list (list (list new-title))))
                 :source-path (%notebook-path notebook-id)
                 :allow-null t)))
    (if result
        (source-from-api-response result)
        (make-source :id source-id :title new-title))))

(defun refresh-source (client notebook-id source-id)
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*refresh-source*
   (list nil (list source-id) (list 2))
   :source-path (%notebook-path notebook-id)
   :allow-null t)
  t)

(defun check-source-freshness (client notebook-id source-id)
  (let ((result (notebooklm-cl.core:rpc-call
                 client notebooklm-cl.rpc.types:*check-source-freshness*
                 (list nil (list source-id) (list 2))
                 :source-path (%notebook-path notebook-id)
                 :allow-null t)))
    (source-freshness-fresh-p result)))

(defun get-source-guide (client notebook-id source-id)
  "Return plist (:summary ... :keywords (...))."
  (let* ((result (notebooklm-cl.core:rpc-call
                  client notebooklm-cl.rpc.types:*get-source-guide*
                  (list (list (list (list source-id))))
                  :source-path (%notebook-path notebook-id)
                  :allow-null t))
         (summary-raw (notebooklm-cl.util:%nths result 0 0 1 0))
         (kw (notebooklm-cl.util:%nths result 0 0 2 0)))
    (list :summary (if (stringp summary-raw) summary-raw "")
          :keywords (if (listp kw) kw nil))))

(defun get-source-fulltext (client notebook-id source-id)
  "Plaintext fulltext via GET_SOURCE [2][2] params."
  (let ((result (notebooklm-cl.core:rpc-call
                 client notebooklm-cl.rpc.types:*get-source*
                 (list (list source-id) (list 2) (list 2))
                 :source-path (%notebook-path notebook-id)
                 :allow-null t)))
    (unless (and result (listp result))
      (error 'notebooklm-cl.errors:source-not-found-error
             :source-id source-id :notebook-id notebook-id))
    (source-fulltext-from-api-response result source-id)))

;;; ===========================================================================
;;; File registration + resumable upload (requires Cookie header for Scotty)
;;; ===========================================================================

(defun register-file-source (client notebook-id filename)
  "Step 1 of file upload: RPC intent → source id string.
Matches Python notebooklm-py `[[filename]]` as the first RPC param element."
  (let ((result (notebooklm-cl.core:rpc-call
                 client notebooklm-cl.rpc.types:*add-source-file*
                 (list (list filename)
                       notebook-id
                       (list 2)
                       (list 1 nil nil nil nil nil nil nil nil nil (list 1)))
                 :source-path (%notebook-path notebook-id)
                 :allow-null t)))
    (let ((sid (%first-nested-string result)))
      (unless sid
        (error 'notebooklm-cl.errors:source-add-error
               :label filename
               :message "Failed to get SOURCE_ID from registration response"))
      sid)))

(defun start-resumable-upload (client notebook-id filename file-size source-id)
  "POST upload/_/ start → non-nil upload URL string."
  (let* ((auth (client-core-auth client))
         (base (notebooklm-cl.env:get-base-url))
         (url (%upload-url-with-authquery auth))
         (json (let ((h (make-hash-table :test 'equal)))
                 (setf (gethash "PROJECT_ID" h) notebook-id
                       (gethash "SOURCE_NAME" h) filename
                       (gethash "SOURCE_ID" h) source-id)
                 (cl-json:encode-json-to-string h)))
         (headers `(("Accept" . "*/*")
                    ("Content-Type" . "application/x-www-form-urlencoded;charset=UTF-8")
                    ("Origin" . ,base)
                    ("Referer" . ,(format nil "~A/" base))
                    ("x-goog-authuser" . ,(%authuser-route auth))
                    ("x-goog-upload-command" . "start")
                    ("x-goog-upload-header-content-length" . ,(princ-to-string file-size))
                    ("x-goog-upload-protocol" . "resumable"))))
    (when (and auth (auth-tokens-cookie-header auth))
      (push (cons "Cookie" (auth-tokens-cookie-header auth)) headers))
    (handler-case
        (multiple-value-bind (body-str status response-headers)
            (dex:post url
                      :content json
                      :headers headers
                      :connect-timeout (client-core-connect-timeout client)
                      :read-timeout (client-core-timeout client))
          (declare (ignore body-str))
          (unless (= status 200)
            (error 'notebooklm-cl.errors:source-add-error
                   :label filename
                   :message (format nil "resumable upload start failed (HTTP ~D)" status)))
          (or (%dex-header-get response-headers "x-goog-upload-url")
              (error 'notebooklm-cl.errors:source-add-error
                     :label filename
                     :message "missing x-goog-upload-url header")))
      (dex:http-request-failed (e)
        (error 'notebooklm-cl.errors:source-add-error
               :label filename
               :cause e)))))

(defun upload-file-to-url (client upload-url pathname)
  "Upload binary content of PATHNAME to UPLOAD-URL (finalize)."
  (let* ((auth (client-core-auth client))
         (base (notebooklm-cl.env:get-base-url))
         (headers `(("Accept" . "*/*")
                    ("Content-Type" . "application/x-www-form-urlencoded;charset=utf-8")
                    ("x-goog-authuser" . ,(%authuser-route auth))
                    ("Origin" . ,base)
                    ("Referer" . ,(format nil "~A/" base))
                    ("x-goog-upload-command" . "upload, finalize")
                    ("x-goog-upload-offset" . "0"))))
    (when (and auth (auth-tokens-cookie-header auth))
      (push (cons "Cookie" (auth-tokens-cookie-header auth)) headers))
    (handler-case
        (with-open-file (in pathname :element-type '(unsigned-byte 8))
          (let ((buf (make-array (file-length in) :element-type '(unsigned-byte 8))))
            (read-sequence buf in)
            (multiple-value-bind (body-str status)
                (dex:post upload-url
                          :content buf
                          :headers headers
                          :connect-timeout (client-core-connect-timeout client)
                          :read-timeout (* 10 (client-core-timeout client)))
              (declare (ignore body-str))
              (unless (= status 200)
                (error 'notebooklm-cl.errors:source-add-error
                       :label (namestring pathname)
                       :message (format nil "upload finalize failed (HTTP ~D)" status))))))
      (dex:http-request-failed (e)
        (error 'notebooklm-cl.errors:source-add-error
               :label (namestring pathname)
               :cause e)))))

(defun add-file-source (client notebook-id pathname
                        &key title (mime-type nil mime-type-p))
  "Register + resumable-upload local file. MIME-TYPE accepted for API parity
\(currently unused, matching Python). Optional TITLE triggers rename after upload.
Requires `cookie-header` on auth tokens for production Scotty validation."
  (declare (ignore mime-type mime-type-p))
  (let ((pn (etypecase pathname
              (pathname pathname)
              (string (uiop:parse-native-namestring pathname)))))
    (setf pathname (uiop:truename* pn))
    (unless pathname
      (error 'notebooklm-cl.errors:validation-error))
    (unless (and (uiop:probe-file* pathname)
                 (not (uiop:directory-pathname-p pathname)))
      (error 'notebooklm-cl.errors:validation-error))
    (when title
      (setf title (string-trim " " title))
      (unless (plusp (length title))
        (error 'notebooklm-cl.errors:validation-error)))
    (let* ((filename (file-namestring pathname))
           (size (with-open-file (in pathname :element-type '(unsigned-byte 8))
                   (file-length in)))
           (source-id (register-file-source client notebook-id filename))
           (upload-url (start-resumable-upload client notebook-id filename size source-id)))
      (upload-file-to-url client upload-url pathname)
      (let ((src (or (get-source client notebook-id source-id)
                    (make-source :id source-id :title filename
                                 :status notebooklm-cl.rpc.types:+source-processing+))))
        (if (and title (string/= title filename))
            (rename-source client notebook-id source-id title)
            src)))))

;;; ===========================================================================
;;; Reserved RPC
;;; ===========================================================================

(defun discover-sources (client notebook-id)
  "DISCOVER_SOURCES is reserved in Google's API; not used in notebooklm-py."
  (declare (ignore client notebook-id))
  nil)
