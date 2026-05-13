(in-package #:notebooklm-cl.rpc.encoder)

(defun json-encode-compact (object)
  (cl-json:encode-json-to-string object))

(defun encode-rpc-request (method-id params)
  `((,(list method-id (json-encode-compact params) nil "generic"))))

(defun build-request-body (rpc-request &key csrf-token)
  (let* ((freq (json-encode-compact rpc-request))
         (freq-enc (notebooklm-cl.util:url-encode freq))
         (body (format nil "f.req=~A" freq-enc)))
    (when csrf-token
      (setf body (format nil "~A&at=~A" body (notebooklm-cl.util:url-encode csrf-token))))
    (format nil "~A&" body)))
