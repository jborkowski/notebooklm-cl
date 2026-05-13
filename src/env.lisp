(in-package #:notebooklm-cl.env)

(defparameter *default-base-url* "https://notebooklm.google.com")

(defparameter *allowed-hosts* '("notebooklm.google.com" "notebooklm.cloud.google.com"))

(defun parse-url-host (url)
  (let* ((after-scheme (subseq url (1+ (position #\/ url :start (+ 2 (length "https://"))))))
         (host-end (or (position #\/ after-scheme) (position #\? after-scheme) (position #\# after-scheme) (length after-scheme)))
         (host-part (subseq after-scheme 0 host-end))
         (colon (position #\: host-part)))
    (if colon (subseq host-part 0 colon) host-part)))

(defun get-base-url ()
  (let* ((raw (or (uiop:getenv "NOTEBOOKLM_BASE_URL") *default-base-url*))
         (stripped (string-right-trim '(#\/) (string-trim " " raw))))
    (unless (notebooklm-cl.util:starts-with-p stripped "https://")
      (error 'notebooklm-cl.errors:configuration-error
             :format-control "NOTEBOOKLM_BASE_URL must use https"))
    (let ((host (parse-url-host stripped)))
      (unless (member host *allowed-hosts* :test #'string=)
        (error 'notebooklm-cl.errors:configuration-error
               :format-control "NOTEBOOKLM_BASE_URL must use one of: ~{~A~^, ~}"
               :format-arguments (list *allowed-hosts*)))
      (format nil "https://~A" host))))

(defun get-base-host ()
  (parse-url-host (get-base-url)))

(defun get-default-language ()
  (let ((raw (or (uiop:getenv "NOTEBOOKLM_HL") "")))
    (if (string= (string-trim " " raw) "")
        "en"
        (string-trim " " raw))))
