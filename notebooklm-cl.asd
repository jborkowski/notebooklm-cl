(asdf:defsystem #:notebooklm-cl
  :description "Common Lisp client for Google NotebookLM RPC API."
  :version "0.1.0"
  :depends-on (#:dexador #:cl-json)
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "packages")
                             (:file "util")
                             (:file "env")
                             (:file "errors")
                             (:module "rpc"
                              :serial t
                              :components ((:file "types")
                                           (:file "encoder")
                                           (:file "decoder")))
                             (:file "core")))))
