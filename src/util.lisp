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

(defmacro with-nested-extract ((data-var) &body clauses-and-body)
  "Extract typed values from nested list DATA-VAR at indexed positions.
Each clause before the body is (VAR PATH &key TYPE DEFAULT TRANSFORM).
  PATH  — list of 0-based indices, e.g. (2 0) → (nth 0 (nth 2 data)).
  TYPE  — predicate symbol (e.g. stringp, integerp). Nil = no check.
  DEFAULT — value when extraction fails (missing path, wrong type, or nil).
  TRANSFORM — 1-arg function applied to extracted value before binding.
Clauses end when a form's second element is not a list.

Example:
  (with-nested-extract (d)
      (id (0) :type stringp :default \"none\")
      (count (1) :type integerp :transform #'1+)
    (list id count))"
  (let ((d (gensym "DATA"))
        (bindings nil)
        (remaining clauses-and-body))
    (loop while (and remaining
                     (consp (car remaining))
                     (symbolp (caar remaining))
                     (consp (cdar remaining))
                     (consp (cadar remaining))
                     (or (null (cadar remaining))
                         (integerp (caadar remaining))))
          for x = (pop remaining)
          do (destructuring-bind (var path &key type default transform) x
               (let ((raw (gensym "RAW")))
                 (push `(,var
                         (let ((,raw (notebooklm-cl.util:%nths ,d ,@path)))
                           ,(cond
                              ((and type transform)
                               `(let ((val (if (,type ,raw) ,raw nil)))
                                  (if val (funcall ,transform val) ,default)))
                              (type
                               `(if (,type ,raw) ,raw ,default))
                              (transform
                               `(funcall ,transform ,raw))
                              (t
                               `(or ,raw ,default)))))
                       bindings))))
    `(let ((,d ,data-var))
       (let* ,(nreverse bindings)
         ,@remaining))))
