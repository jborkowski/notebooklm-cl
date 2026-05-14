(in-package #:notebooklm-cl.errors)

(define-condition notebooklm-error (error) ())

(define-condition validation-error (notebooklm-error) ())
(define-condition configuration-error (notebooklm-error) ())

(define-condition network-error (notebooklm-error)
  ((original :initarg :original :reader network-error-original))
  (:report (lambda (c s)
             (format s "Network error~@[: ~A~]" (network-error-original c)))))

(define-condition rpc-error (notebooklm-error)
  ((method-id :initarg :method-id :reader rpc-error-method-id :initform nil)
   (rpc-code :initarg :rpc-code :reader rpc-error-rpc-code :initform nil)
   (found-ids :initarg :found-ids :reader rpc-error-found-ids :initform nil)
   (raw-response :initarg :raw-response :reader rpc-error-raw-response :initform nil))
  (:report (lambda (c s)
             (format s "RPC error~@[ (~A)~]" (rpc-error-method-id c)))))

(define-condition decoding-error (rpc-error) ())
(define-condition unknown-rpc-method-error (decoding-error) ())

(define-condition auth-error (rpc-error) ()
  (:report (lambda (c s)
             (format s "Authentication error~@[ (~A)~]" (rpc-error-method-id c)))))

(define-condition rate-limit-error (rpc-error)
  ((retry-after :initarg :retry-after :reader rate-limit-error-retry-after :initform nil))
  (:report (lambda (c s)
             (format s "Rate limit exceeded~@[ (~A)~]~@[; retry after ~As~]"
                     (rpc-error-method-id c)
                     (rate-limit-error-retry-after c)))))

(define-condition server-error (rpc-error)
  ((status-code :initarg :status-code :reader server-error-status-code :initform nil))
  (:report (lambda (c s)
             (format s "Server error ~D~@[ (~A)~]"
                     (server-error-status-code c)
                     (rpc-error-method-id c)))))

(define-condition client-error (rpc-error)
  ((status-code :initarg :status-code :reader client-error-status-code :initform nil))
  (:report (lambda (c s)
             (format s "Client error ~D~@[ (~A)~]"
                     (client-error-status-code c)
                     (rpc-error-method-id c)))))

(define-condition rpc-timeout-error (network-error)
  ((timeout-seconds :initarg :timeout-seconds :reader rpc-timeout-error-timeout-seconds :initform nil))
  (:report (lambda (c s)
             (format s "RPC timeout~@[ after ~As~]" (rpc-timeout-error-timeout-seconds c)))))

(define-condition notebook-limit-error (notebooklm-error)
  ((current-count :initarg :current-count :reader notebook-limit-error-current-count :initform 0)
   (limit :initarg :limit :reader notebook-limit-error-limit :initform nil)
   (original-error :initarg :original-error :reader notebook-limit-error-original :initform nil))
  (:report (lambda (c s)
             (format s "Notebook quota exceeded (~D notebooks, limit ~D)"
                     (notebook-limit-error-current-count c)
                     (notebook-limit-error-limit c)))))

(define-condition source-add-error (notebooklm-error)
  ((label :initarg :label :reader source-add-error-label :initform "")
   (message :initarg :message :reader source-add-error-message :initform nil)
   (cause :initarg :cause :reader source-add-error-cause :initform nil))
  (:report (lambda (c s)
             (format s "Failed to add source~@[ (~A)~]~@[: ~A~]"
                     (source-add-error-label c)
                     (or (source-add-error-message c)
                         (and (source-add-error-cause c)
                              (princ-to-string (source-add-error-cause c))))))))

(define-condition source-not-found-error (notebooklm-error)
  ((source-id :initarg :source-id :reader source-not-found-error-source-id :initform "")
   (notebook-id :initarg :notebook-id :reader source-not-found-error-notebook-id :initform nil))
  (:report (lambda (c s)
             (format s "Source not found~@[ (~A)~]"
                     (source-not-found-error-source-id c)))))

(define-condition artifact-not-ready-error (notebooklm-error)
  ((artifact-type :initarg :artifact-type :reader artifact-not-ready-error-artifact-type)
   (artifact-id :initarg :artifact-id :reader artifact-not-ready-error-artifact-id :initform nil))
  (:report (lambda (c s)
             (format s "No completed ~A artifact~@[ (id=~A)~] available"
                     (artifact-not-ready-error-artifact-type c)
                     (artifact-not-ready-error-artifact-id c)))))

(define-condition artifact-not-found-error (notebooklm-error)
  ((artifact-id :initarg :artifact-id :reader artifact-not-found-error-artifact-id)
   (artifact-type :initarg :artifact-type :reader artifact-not-found-error-artifact-type :initform nil))
  (:report (lambda (c s)
             (format s "Artifact ~A not found~@[ (type=~A)~]"
                     (artifact-not-found-error-artifact-id c)
                     (artifact-not-found-error-artifact-type c)))))

(define-condition artifact-parse-error (notebooklm-error)
  ((artifact-type :initarg :artifact-type :reader artifact-parse-error-artifact-type)
   (artifact-id :initarg :artifact-id :reader artifact-parse-error-artifact-id :initform nil)
   (details :initarg :details :reader artifact-parse-error-details :initform nil)
   (cause :initarg :cause :reader artifact-parse-error-cause :initform nil))
  (:report (lambda (c s)
             (format s "Failed to parse ~A artifact~@[ (id=~A)~]~@[: ~A~]"
                     (artifact-parse-error-artifact-type c)
                     (artifact-parse-error-artifact-id c)
                     (artifact-parse-error-details c)))))

(define-condition artifact-download-error (notebooklm-error)
  ((artifact-type :initarg :artifact-type :reader artifact-download-error-artifact-type)
   (artifact-id :initarg :artifact-id :reader artifact-download-error-artifact-id :initform nil)
   (details :initarg :details :reader artifact-download-error-details :initform nil))
  (:report (lambda (c s)
             (format s "Failed to download ~A~@[ (id=~A)~]~@[: ~A~]"
                     (artifact-download-error-artifact-type c)
                     (artifact-download-error-artifact-id c)
                     (artifact-download-error-details c)))))
