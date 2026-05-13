(asdf:defsystem #:notebooklm-cl
  :description "Common Lisp client for Google NotebookLM RPC API."
  :version "0.2.1"
  :depends-on (#:dexador #:cl-json)
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "packages")
                             (:file "util")
                             (:file "env")
                             (:file "errors")
                             (:file "types")
                             (:module "rpc"
                              :serial t
                              :components ((:file "types")
                                           (:file "encoder")
                                           (:file "decoder")))
                             (:file "core")
                             (:file "notebooks")))))

;;; ===========================================================================
;;; Test system
;;; ===========================================================================

(asdf:defsystem #:notebooklm-cl/tests
  :description "Tests for notebooklm-cl."
  :version "0.2.1"
  :depends-on (#:notebooklm-cl #:parachute)
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "packages")
                             (:file "fixtures")
                             (:file "main")
                             (:file "util")
                             (:file "rpc-types")
                             (:file "rpc-encoder")
                             (:file "rpc-decoder")
                             (:file "types")))))

(defmethod asdf:perform ((o asdf:test-op) (c (eql (asdf:find-system :notebooklm-cl))))
  (asdf:load-system :notebooklm-cl/tests)
  (uiop:symbol-call :notebooklm-cl.tests :run-tests))
