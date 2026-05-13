(in-package #:notebooklm-cl.notebooks)

;;; ===========================================================================
;;; Helpers
;;; ===========================================================================

(defparameter *create-notebook-quota-rpc-code* 3)

(defun %notebook-source-path (notebook-id)
  (format nil "/notebook/~A" notebook-id))

(defun %notebook-url (notebook-id)
  (format nil "~A/notebook/~A" (get-base-url) notebook-id))

(defun %summarize-raw (client notebook-id)
  "Raw RPC call to SUMMARIZE. Returns result list or NIL."
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*summarize*
   (list notebook-id (list 2))
   :source-path (%notebook-source-path notebook-id)))

(defun %build-get-user-settings-params ()
  "Build params for GET_USER_SETTINGS RPC call."
  (list nil (list 1 nil nil nil nil nil nil nil nil nil (list 1))))

;;; ===========================================================================
;;; list-notebooks
;;; ===========================================================================

(defun list-notebooks (client)
  "List all notebooks.
Returns a list of NOTEBOOK structs."
  (let* ((params (list nil 1 nil (list 2)))
         (result (notebooklm-cl.core:rpc-call
                  client notebooklm-cl.rpc.types:*list-notebooks* params)))
    (if (and result (listp result) result)
        (let ((raw (if (listp (first result)) (first result) result)))
          (loop for nb in raw
                when (listp nb)
                collect (notebook-from-api-response nb)))
        nil)))

;;; ===========================================================================
;;; create-notebook
;;; ===========================================================================

(defun %get-account-limits (client)
  "Fetch account limits from user settings."
  (let ((result (notebooklm-cl.core:rpc-call
                 client notebooklm-cl.rpc.types:*get-user-settings*
                 (%build-get-user-settings-params)
                 :source-path "/")))
    (account-limits-from-api-response result)))

(defun %raise-quota-error-if-detected (client error)
  "If error is a CREATE_NOTEBOOK quota failure, convert to notebook-limit-error."
  (unless (and (string= (rpc-error-method-id error)
                        notebooklm-cl.rpc.types:*create-notebook*)
               (eql (rpc-error-rpc-code error)
                    *create-notebook-quota-rpc-code*))
    (return-from %raise-quota-error-if-detected nil))

  (let ((acct-limits (ignore-errors (%get-account-limits client))))
    (when (or (null acct-limits) (null (limits-notebook-limit acct-limits)))
      (return-from %raise-quota-error-if-detected nil))

    (let* ((notebook-limit (limits-notebook-limit acct-limits))
           (notebooks (ignore-errors (list-notebooks client))))
      (when notebooks
        (let ((owned-count (count-if #'notebook-is-owner notebooks)))
          (unless (< owned-count (max (1- notebook-limit) 0))
            (error 'notebook-limit-error
                   :current-count owned-count
                   :limit notebook-limit
                   :original-error error)))))))

(defun create-notebook (client title)
  "Create a new notebook with the given TITLE.
Returns the created NOTEBOOK struct."
  (let* ((params (list title nil nil (list 2) (list 1)))
         (result
           (handler-case
               (notebooklm-cl.core:rpc-call
                client notebooklm-cl.rpc.types:*create-notebook* params)
             (rpc-error (e)
               (%raise-quota-error-if-detected client e)
               (error e)))))
    (notebook-from-api-response result)))

;;; ===========================================================================
;;; get-notebook
;;; ===========================================================================

(defun get-notebook (client notebook-id)
  "Get notebook details by NOTEBOOK-ID.
Returns a NOTEBOOK struct."
  (let* ((params (list notebook-id nil (list 2) nil 0))
         (result (notebooklm-cl.core:rpc-call
                  client notebooklm-cl.rpc.types:*get-notebook*
                  params
                  :source-path (%notebook-source-path notebook-id)))
         (nb-info (if (and result (listp result) result)
                      (first result)
                      nil)))
    (notebook-from-api-response nb-info)))

;;; ===========================================================================
;;; delete-notebook
;;; ===========================================================================

(defun delete-notebook (client notebook-id)
  "Delete a notebook. Returns T on success."
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*delete-notebook*
   (list (list notebook-id) (list 2)))
  t)

;;; ===========================================================================
;;; rename-notebook
;;; ===========================================================================

(defun rename-notebook (client notebook-id new-title)
  "Rename a notebook. Returns the updated NOTEBOOK struct."
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*rename-notebook*
   (list notebook-id (list (list nil nil nil (list nil new-title))))
   :source-path "/"
   :allow-null t)
  (get-notebook client notebook-id))

;;; ===========================================================================
;;; get-summary / get-description
;;; ===========================================================================

(defun get-summary (client notebook-id)
  "Get raw summary text for a notebook. Returns a string."
  (let ((result (%summarize-raw client notebook-id)))
    (handler-case
        (if (and result (listp result) result
                 (listp (first result)) (first result)
                 (listp (first (first result))))
            (princ-to-string (first (first (first result))))
            "")
      (error () ""))))

(defun get-description (client notebook-id)
  "Get AI-generated summary and suggested topics for a notebook.
Returns a NOTEBOOK-DESCRIPTION struct."
  (let* ((result (%summarize-raw client notebook-id))
         (summary "")
         (suggested-topics nil))
    (when (and result (listp result) result)
      (let ((outer (first result)))
        (handler-case
            (when (and (listp outer) outer)
              (let ((summary-val (first outer)))
                (when (and (listp summary-val) summary-val)
                  (setf summary (princ-to-string (first summary-val)))))
              (when (and (>= (length outer) 2) (listp (second outer)))
                (let ((topics-list (first (second outer))))
                  (when (listp topics-list)
                    (dolist (topic topics-list)
                      (when (and (listp topic) (>= (length topic) 2))
                        (push (make-suggested-topic
                               :question (princ-to-string (or (first topic) ""))
                               :prompt (princ-to-string (or (second topic) "")))
                              suggested-topics))))))
              (setf suggested-topics (nreverse suggested-topics)))
          (error ()))))
    (make-notebook-description :summary summary
                               :suggested-topics suggested-topics)))

;;; ===========================================================================
;;; remove-from-recent
;;; ===========================================================================

(defun remove-from-recent (client notebook-id)
  "Remove a notebook from the recently viewed list."
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*remove-recently-viewed*
   (list notebook-id)
   :allow-null t)
  nil)

;;; ===========================================================================
;;; get-notebook-raw
;;; ===========================================================================

(defun get-notebook-raw (client notebook-id)
  "Get raw notebook API response data."
  (notebooklm-cl.core:rpc-call
   client notebooklm-cl.rpc.types:*get-notebook*
   (list notebook-id nil (list 2) nil 0)
   :source-path (%notebook-source-path notebook-id)))

;;; ===========================================================================
;;; share-notebook
;;; ===========================================================================

(defun share-notebook (client notebook-id &key public artifact-id)
  "Toggle notebook sharing.
When PUBLIC is true, enables sharing. When false, disables.
Returns a plist with keys :public, :url, and :artifact-id."
  (let* ((share-options (list (if public 1 0)))
         (params (if artifact-id
                     (list share-options notebook-id artifact-id)
                     (list share-options notebook-id))))
    (notebooklm-cl.core:rpc-call
     client notebooklm-cl.rpc.types:*share-artifact*
     params
     :source-path (%notebook-source-path notebook-id)
     :allow-null t)
    (let ((base-url (%notebook-url notebook-id)))
      (list :public public
            :url (cond
                   ((and public artifact-id)
                    (format nil "~A?artifactId=~A" base-url artifact-id))
                   (public base-url)
                   (t nil))
            :artifact-id artifact-id))))

;;; ===========================================================================
;;; get-share-url
;;; ===========================================================================

(defun get-share-url (client notebook-id &optional artifact-id)
  "Get the share URL for a notebook or artifact.
This does NOT toggle sharing — just returns the URL format."
  (declare (ignore client))
  (let ((base-url (%notebook-url notebook-id)))
    (if artifact-id
        (format nil "~A?artifactId=~A" base-url artifact-id)
        base-url)))

;;; ===========================================================================
;;; get-metadata
;;; ===========================================================================

(defun get-metadata (client notebook-id)
  "Get notebook metadata with sources list.
Note: full source listing depends on Module 3 (sources.lisp).
Currently returns notebook with an empty sources list."
  (let ((notebook (get-notebook client notebook-id)))
    (make-notebook-metadata :notebook notebook :sources nil)))
