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
