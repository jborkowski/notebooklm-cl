(in-package #:notebooklm-cl.util)

(defun url-encode (string)
  "Percent-encode STRING using UTF-8 byte encoding (RFC 3986)."
  (let ((bytes (sb-ext:string-to-octets string :external-format :utf-8)))
    (with-output-to-string (out)
      (loop for byte across bytes
            do (cond
                 ((or (<= 65 byte 90) (<= 97 byte 122) (<= 48 byte 57)
                      (find (code-char byte) "-_.~" :test #'char=))
                  (write-char (code-char byte) out))
                 (t
                  (format out "%~2,'0X" byte)))))))

(defun starts-with-p (str prefix)
  (and (>= (length str) (length prefix))
       (string= str prefix :end1 (length prefix))))

(defun ends-with-p (str suffix)
  (and (>= (length str) (length suffix))
       (string= str suffix :start1 (- (length str) (length suffix)))))
