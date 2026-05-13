(in-package #:notebooklm-cl.rpc.types)

(defmacro define-rpc-methods (&rest pairs)
  `(progn
     ,@(loop for (name id) on pairs by #'cddr
             collect `(defparameter ,(intern (format nil "*~A*" name)) ,id))))

(defmacro define-rpc-constants (&rest pairs)
  "Define multiple defconstants at once.  Each PAIR is (NAME VALUE).
Expands to (defconstant +NAME+ VALUE) for each pair."
  `(progn
     ,@(loop for (name val) on pairs by #'cddr
             collect `(defconstant ,(intern (format nil "+~A+" name)) ,val))))

(define-rpc-methods
  list-notebooks             "wXbhsf"
  create-notebook            "CCqFvf"
  get-notebook               "rLM1Ne"
  rename-notebook            "s0tc2d"
  delete-notebook            "WWINqb"
  add-source                 "izAoDd"
  add-source-file            "o4cbdc"
  delete-source              "tGMBJ"
  get-source                 "hizoJc"
  refresh-source             "FLmJqe"
  check-source-freshness     "yR9Yof"
  update-source              "b7Wfje"
  discover-sources           "qXyaNe"
  summarize                  "VfAZjd"
  get-source-guide           "tr032e"
  get-suggested-reports      "ciyUvf"
  create-artifact            "R7cb6c"
  list-artifacts             "gArtLc"
  delete-artifact            "V5N4be"
  rename-artifact            "rc3d8d"
  export-artifact            "Krh3pd"
  share-artifact             "RGP97b"
  get-interactive-html       "v9rmvd"
  revise-slide               "KmcKPe"
  start-fast-research        "Ljjv0c"
  start-deep-research        "QA9ei"
  poll-research              "e3bVqc"
  import-research             "LBwxtb"
  generate-mind-map          "yyryJe"
  create-note                "CYK0Xb"
  get-notes-and-mind-maps    "cFji9"
  update-note                "cYAfTb"
  delete-note                "AH0mwd"
  get-last-conversation-id   "hPTbtc"
  get-conversation-turns     "khqZz"
  share-notebook             "QDyure"
  get-share-status           "JFMDGd"
  remove-recently-viewed     "fejl7e"
  get-user-settings          "ZwVcOc"
  set-user-settings          "hT54vc"
  get-user-tier              "ozz5Z")

(defparameter *query-endpoint*
  "/_/LabsTailwindUi/data/google.internal.labs.tailwind.orchestration.v1.LabsTailwindOrchestrationService/GenerateFreeFormStreamed")

;; --- Artifact type codes ---
(define-rpc-constants
  artifact-audio 1
  artifact-report 2
  artifact-video 3
  artifact-quiz 4
  artifact-mind-map 5
  artifact-infographic 7
  artifact-slide-deck 8
  artifact-data-table 9)

;; --- Artifact status codes ---
(define-rpc-constants
  artifact-processing 1
  artifact-pending 2
  artifact-completed 3
  artifact-failed 4)

(defun artifact-status-to-str (code)
  (ecase code
    (#.+artifact-processing+ "in_progress")
    (#.+artifact-pending+ "pending")
    (#.+artifact-completed+ "completed")
    (#.+artifact-failed+ "failed")))

;; --- Source status codes ---
(define-rpc-constants
  source-processing 1
  source-ready 2
  source-error 3
  source-preparing 5)

(defun source-status-to-str (code)
  (ecase code
    (#.+source-processing+ "processing")
    (#.+source-ready+ "ready")
    (#.+source-error+ "error")
    (#.+source-preparing+ "preparing")))

;; --- Audio format / length ---
(define-rpc-constants
  audio-deep-dive 1
  audio-brief 2
  audio-critique 3
  audio-debate 4
  audio-short 1
  audio-default 2
  audio-long 3)

;; --- Video format / style ---
(define-rpc-constants
  video-explainer 1
  video-brief 2
  video-cinematic 3
  video-auto-select 1
  video-custom 2
  video-classic 3
  video-whiteboard 4
  video-kawaii 5
  video-anime 6
  video-watercolor 7
  video-retro-print 8
  video-heritage 9
  video-paper-craft 10)

;; --- Quiz quantity / difficulty ---
(define-rpc-constants
  quiz-fewer 1
  quiz-standard 2
  quiz-more 2
  quiz-easy 1
  quiz-medium 2
  quiz-hard 3)

;; --- Infographic orientation / detail / style ---
(define-rpc-constants
  infographic-landscape 1
  infographic-portrait 2
  infographic-square 3
  infographic-concise 1
  infographic-standard 2
  infographic-detailed 3
  infographic-auto-select 1
  infographic-sketch-note 2
  infographic-professional 3
  infographic-bento-grid 4
  infographic-editorial 5
  infographic-instructional 6
  infographic-bricks 7
  infographic-clay 8
  infographic-anime 9
  infographic-kawaii 10
  infographic-scientific 11)

;; --- Slide deck ---
(define-rpc-constants
  slide-deck-detailed 1
  slide-deck-presenter 2
  slide-deck-default 1
  slide-deck-short 2)

;; --- Chat ---
(define-rpc-constants
  chat-default 1
  chat-custom 2
  chat-learning-guide 3
  chat-response-default 1
  chat-response-longer 4
  chat-response-shorter 5)

;; --- Export ---
(define-rpc-constants
  export-docs 1
  export-sheets 2)

;; --- Share ---
(define-rpc-constants
  share-restricted 0
  share-anyone-with-link 1
  share-full-notebook 0
  share-chat-only 1
  share-owner 1
  share-editor 2
  share-viewer 3
  share-remove 4)

;; --- URL helpers ---
(defun get-batchexecute-url ()
  (format nil "~A/_/LabsTailwindUi/data/batchexecute"
          (notebooklm-cl.env:get-base-url)))

(defun get-query-url ()
  (format nil "~A~A"
          (notebooklm-cl.env:get-base-url)
          *query-endpoint*))

(defun get-upload-url ()
  (format nil "~A/upload/_/"
          (notebooklm-cl.env:get-base-url)))
