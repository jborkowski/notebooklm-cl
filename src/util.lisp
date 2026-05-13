(in-package #:notebooklm-cl.util)

(defun url-encode (string)
  (with-output-to-string (out)
    (loop for c across string
          for code = (char-code c)
          do (cond
               ((or (<= 65 code 90) (<= 97 code 122) (<= 48 code 57)
                    (find c "-_.~" :test #'char=))
                (write-char c out))
               (t
                (format out "%~2,'0X" code))))))

(defun starts-with-p (str prefix)
  (and (>= (length str) (length prefix))
       (string= str prefix :end2 (length prefix))))

(defun ends-with-p (str suffix)
  (and (>= (length str) (length suffix))
       (string= str suffix :start1 (- (length str) (length suffix)))))
