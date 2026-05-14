(in-package #:notebooklm-cl.errors)

(defmacro define-error (name parents slots &body options)
  "Like DEFINE-CONDITION but auto-derives slot scaffolding.
For each slot in SLOTS, generates :initarg :SLOT-NAME and
:reader NAME-SLOT-NAME (with optional :initform).

SLOT-SPEC is one of:
  SLOT-NAME                                  -- :initform NIL
  (SLOT-NAME INITFORM)                       -- given initform
  (SLOT-NAME INITFORM :reader CUSTOM-READER) -- override the reader
  (SLOT-NAME INITFORM :initarg CUSTOM-KW)    -- override the initarg

OPTIONS pass through (typically :report)."
  `(define-condition ,name ,parents
     ,(mapcar (lambda (spec)
                (let* ((spec (if (consp spec) spec (list spec nil)))
                       (slot (first spec))
                       (initform (second spec))
                       (props (cddr spec))
                       (reader (or (getf props :reader)
                                   (intern (format nil "~A-~A" name slot))))
                       (initarg (or (getf props :initarg)
                                    (intern (symbol-name slot) :keyword))))
                  `(,slot :initarg ,initarg
                          :reader ,reader
                          :initform ,initform)))
              slots)
     ,@options))

(define-error notebooklm-error (error) ())

(define-error validation-error (notebooklm-error) ())
(define-error configuration-error (notebooklm-error) ())

(define-error network-error (notebooklm-error)
    ((original))
  (:report (lambda (c s)
             (format s "Network error~@[: ~A~]" (network-error-original c)))))

(define-error rpc-error (notebooklm-error)
    ((method-id) (rpc-code) (found-ids) (raw-response))
  (:report (lambda (c s)
             (format s "RPC error~@[ (~A)~]" (rpc-error-method-id c)))))

(define-error decoding-error (rpc-error) ())
(define-error unknown-rpc-method-error (decoding-error) ())

(define-error auth-error (rpc-error) ()
  (:report (lambda (c s)
             (format s "Authentication error~@[ (~A)~]" (rpc-error-method-id c)))))

(define-error rate-limit-error (rpc-error)
    ((retry-after))
  (:report (lambda (c s)
             (format s "Rate limit exceeded~@[ (~A)~]~@[; retry after ~As~]"
                     (rpc-error-method-id c)
                     (rate-limit-error-retry-after c)))))

(define-error server-error (rpc-error)
    ((status-code))
  (:report (lambda (c s)
             (format s "Server error ~D~@[ (~A)~]"
                     (server-error-status-code c)
                     (rpc-error-method-id c)))))

(define-error client-error (rpc-error)
    ((status-code))
  (:report (lambda (c s)
             (format s "Client error ~D~@[ (~A)~]"
                     (client-error-status-code c)
                     (rpc-error-method-id c)))))

(define-error rpc-timeout-error (network-error)
    ((timeout-seconds))
  (:report (lambda (c s)
             (format s "RPC timeout~@[ after ~As~]" (rpc-timeout-error-timeout-seconds c)))))

(define-error notebook-limit-error (notebooklm-error)
    ((current-count 0)
     (limit)
     (original-error nil :reader notebook-limit-error-original))
  (:report (lambda (c s)
             (format s "Notebook quota exceeded (~D notebooks, limit ~D)"
                     (notebook-limit-error-current-count c)
                     (notebook-limit-error-limit c)))))

(define-error source-add-error (notebooklm-error)
    ((label "") (message) (cause))
  (:report (lambda (c s)
             (format s "Failed to add source~@[ (~A)~]~@[: ~A~]"
                     (source-add-error-label c)
                     (or (source-add-error-message c)
                         (and (source-add-error-cause c)
                              (princ-to-string (source-add-error-cause c))))))))

(define-error source-not-found-error (notebooklm-error)
    ((source-id "") (notebook-id))
  (:report (lambda (c s)
             (format s "Source not found~@[ (~A)~]"
                     (source-not-found-error-source-id c)))))

(define-error artifact-not-ready-error (notebooklm-error)
    ((artifact-type) (artifact-id))
  (:report (lambda (c s)
             (format s "No completed ~A artifact~@[ (id=~A)~] available"
                     (artifact-not-ready-error-artifact-type c)
                     (artifact-not-ready-error-artifact-id c)))))

(define-error artifact-not-found-error (notebooklm-error)
    ((artifact-id) (artifact-type))
  (:report (lambda (c s)
             (format s "Artifact ~A not found~@[ (type=~A)~]"
                     (artifact-not-found-error-artifact-id c)
                     (artifact-not-found-error-artifact-type c)))))

(define-error artifact-parse-error (notebooklm-error)
    ((artifact-type) (artifact-id) (details) (cause))
  (:report (lambda (c s)
             (format s "Failed to parse ~A artifact~@[ (id=~A)~]~@[: ~A~]"
                     (artifact-parse-error-artifact-type c)
                     (artifact-parse-error-artifact-id c)
                     (artifact-parse-error-details c)))))

(define-error artifact-download-error (notebooklm-error)
    ((artifact-type) (artifact-id) (details))
  (:report (lambda (c s)
             (format s "Failed to download ~A~@[ (id=~A)~]~@[: ~A~]"
                     (artifact-download-error-artifact-type c)
                     (artifact-download-error-artifact-id c)
                     (artifact-download-error-details c)))))
