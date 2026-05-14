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

;;; ===========================================================================
;;; YouTube URL helpers (aligned with notebooklm-py `_sources.py`)
;;; ===========================================================================

(defun valid-youtube-video-id-p (video-id)
  "Return true if VIDEO-ID looks like a YouTube id (alphanumeric, -, _)."
  (and video-id (stringp video-id) (plusp (length video-id))
       (every (lambda (c)
                (or (alphanumericp c) (member c '(#\- #\_) :test #'char=)))
              video-id)))

(defun %split-http-url (url)
  "Split HTTP(S) URL into host (lowercase), path including leading /, query without ?.
Returns NIL host if URL is too malformed to parse."
  (let ((u (string-trim " " url)))
    (unless (and (> (length u) 8)
                 (or (string-equal u "http://" :end1 7)
                     (string-equal u "https://" :end1 8)))
      (return-from %split-http-url (values nil "" "")))
    (let* ((i (if (char-equal (char u 4) #\s) 8 7))
           (n (length u))
           (host-end (or (position-if (lambda (c) (member c '(#\/ #\? #\#))) u :start i)
                         n))
           (host (string-downcase (subseq u i host-end))))
      (if (= host-end n)
          (values host "/" "")
          (let* ((after (subseq u host-end n))
                 (path-end (or (position #\? after) (position #\# after) (length after)))
                 (path (subseq after 0 path-end))
                 (query (if (and (< path-end (length after)) (char= (char after path-end) #\?))
                            (subseq after (1+ path-end))
                            "")))
            (values host path query))))))

(defun %path-segments (path)
  "PATH without leading slash → list of segments."
  (let ((p (string-left-trim "/" path)))
    (loop while (plusp (length p))
          collect (let ((slash (position #\/ p)))
                    (if slash
                        (prog1 (subseq p 0 slash)
                          (setf p (subseq p (1+ slash))))
                        (prog1 p (setf p "")))))))

(defun %query-param-v (query)
  "Return first `v=` query parameter value or NIL."
  (loop with pos = 0
        while (< pos (length query))
        for amp = (position #\& query :start pos)
        for end = (or amp (length query))
        for pair = (subseq query pos end)
        do (setf pos (if amp (1+ end) (length query)))
        when (and (> (length pair) 2) (string-equal pair "v=" :end1 2))
          return (subseq pair 2)))

(defun extract-youtube-video-id (url)
  "Return a YouTube video id from URL, or NIL if not a recognized YouTube link."
  (multiple-value-bind (host path query) (%split-http-url url)
    (unless host (return-from extract-youtube-video-id nil))
    (let ((video-id
            (cond
              ((string= host "youtu.be")
               (let ((p (string-left-trim "/" path)))
                 (when (plusp (length p))
                   (subseq p 0 (or (position #\/ p) (length p))))))
              ((member host '("youtube.com" "www.youtube.com" "m.youtube.com" "music.youtube.com")
                       :test #'string=)
               (or (let ((segs (%path-segments path)))
                     (when (>= (length segs) 2)
                       (let ((prefix (string-downcase (first segs))))
                         (when (member prefix '("shorts" "embed" "live" "v") :test #'string=)
                           (second segs)))))
                   (%query-param-v query)))
              (t nil))))
      (when (and video-id (valid-youtube-video-id-p video-id))
        video-id))))
