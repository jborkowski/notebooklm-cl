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

(defun %nths (data &rest indices)
  "Safely navigate nested lists by successive indices.
Returns NIL when DATA is not a list, any index is out of bounds, or
any intermediate value is not a list.

Example: (%nths data 3 0) => (nth 0 (nth 3 data)) with full safety.
Single:   (%nths data 4)  => (nth 4 data) with length guard."
  (loop with current = data
        for i in indices
        do (if (and (listp current) (< i (length current)))
               (setf current (nth i current))
               (return nil))
        finally (return current)))
