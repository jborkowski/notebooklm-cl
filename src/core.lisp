(in-package #:notebooklm-cl.core)

(defvar *default-timeout* 30.0)
(defvar *default-connect-timeout* 10.0)

;;; Optional cookie-header supplies browser Cookie header for `/upload/_/`
;;; resumable uploads; batchexecute RPC uses csrf + session in the URL/body.
(defstruct auth-tokens
  (csrf-token nil :type (or null string))
  (session-id nil :type (or null string))
  (account-email nil :type (or null string))
  (authuser nil :type (or null string))
  (cookie-header nil :type (or null string)))

(defstruct client-core
  (auth nil :type (or null auth-tokens))
  (http nil)
  (timeout *default-timeout* :type real)
  (connect-timeout *default-connect-timeout* :type real)
  (refresh-callback nil)
  (reqid-counter 100000 :type integer))

(defun open-client (client)
  (unless (client-core-http client)
    (setf (client-core-http client) t)))

(defun close-client (client)
  (setf (client-core-http client) nil))

(defun client-open-p (client)
  (not (null (client-core-http client))))

(defun build-url (method-id source-path auth)
  (let ((base (notebooklm-cl.rpc.types:get-batchexecute-url))
        (authuser (or (auth-tokens-account-email auth)
                      (auth-tokens-authuser auth))))
    (format nil "~A?rpcids=~A&source-path=~A&f.sid=~A&hl=~A&rt=c~@[&authuser=~A~]"
            base
            (notebooklm-cl.util:url-encode method-id)
            (notebooklm-cl.util:url-encode source-path)
            (notebooklm-cl.util:url-encode (or (auth-tokens-session-id auth) ""))
            (notebooklm-cl.env:get-default-language)
            (when authuser
              (notebooklm-cl.util:url-encode authuser)))))

(defun classify-http-error (status method-id)
  (cond
    ((= status 429)
     (error 'notebooklm-cl.errors:rate-limit-error :method-id method-id))
    ((<= 500 status 599)
     (error 'notebooklm-cl.errors:server-error :method-id method-id :status-code status))
    ((and (<= 400 status 499) (not (member status '(401 403))))
     (error 'notebooklm-cl.errors:client-error :method-id method-id :status-code status))
    (t
     (error 'notebooklm-cl.errors:rpc-error :method-id method-id))))

(defun rpc-call (client method-id params &key source-path allow-null)
  (let* ((sp (or source-path "/"))
         (auth (client-core-auth client))
         (url (build-url method-id sp auth))
         (rpc-request (notebooklm-cl.rpc.encoder:encode-rpc-request method-id params))
         (body (notebooklm-cl.rpc.encoder:build-request-body
                rpc-request :csrf-token (auth-tokens-csrf-token auth)))
         (headers `(("Content-Type" . "application/x-www-form-urlencoded;charset=UTF-8")
                    ,@(when (auth-tokens-cookie-header auth)
                        `(("Cookie" . ,(auth-tokens-cookie-header auth)))))))
    (handler-case
        (multiple-value-bind (body-str status)
            (dex:post url
                      :content body
                      :headers headers
                      :connect-timeout (client-core-connect-timeout client)
                      :read-timeout (client-core-timeout client))
          (declare (ignore status))
          (notebooklm-cl.rpc.decoder:decode-response
           body-str method-id :allow-null allow-null))
      (dex:http-request-failed (e)
        (classify-http-error (dex:response-status e) method-id))
      #+sbcl
      (sb-bsd-sockets:socket-error (e)
        (error 'notebooklm-cl.errors:network-error :original e))
      (error (e)
        (error 'notebooklm-cl.errors:network-error :original e)))))
