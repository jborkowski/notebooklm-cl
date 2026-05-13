(in-package #:notebooklm-cl.rpc.types)

(defmacro define-rpc-methods (&rest pairs)
  `(progn
     ,@(loop for (name id) on pairs by #'cddr
             collect `(defparameter ,(intern (format nil "*~A*" name)) ,id))))

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
(defconstant +artifact-audio+ 1)
(defconstant +artifact-report+ 2)
(defconstant +artifact-video+ 3)
(defconstant +artifact-quiz+ 4)
(defconstant +artifact-mind-map+ 5)
(defconstant +artifact-infographic+ 7)
(defconstant +artifact-slide-deck+ 8)
(defconstant +artifact-data-table+ 9)

;; --- Artifact status codes ---
(defconstant +artifact-processing+ 1)
(defconstant +artifact-pending+ 2)
(defconstant +artifact-completed+ 3)
(defconstant +artifact-failed+ 4)

(defun artifact-status-to-str (code)
  (ecase code
    (1 "in_progress")
    (2 "pending")
    (3 "completed")
    (4 "failed")))

;; --- Source status codes ---
(defconstant +source-processing+ 1)
(defconstant +source-ready+ 2)
(defconstant +source-error+ 3)
(defconstant +source-preparing+ 5)

(defun source-status-to-str (code)
  (ecase code
    (1 "processing")
    (2 "ready")
    (3 "error")
    (5 "preparing")))

;; --- Audio format / length ---
(defconstant +audio-deep-dive+ 1)
(defconstant +audio-brief+ 2)
(defconstant +audio-critique+ 3)
(defconstant +audio-debate+ 4)
(defconstant +audio-short+ 1)
(defconstant +audio-default+ 2)
(defconstant +audio-long+ 3)

;; --- Video format / style ---
(defconstant +video-explainer+ 1)
(defconstant +video-brief+ 2)
(defconstant +video-cinematic+ 3)
(defconstant +video-auto-select+ 1)
(defconstant +video-custom+ 2)
(defconstant +video-classic+ 3)
(defconstant +video-whiteboard+ 4)
(defconstant +video-kawaii+ 5)
(defconstant +video-anime+ 6)
(defconstant +video-watercolor+ 7)
(defconstant +video-retro-print+ 8)
(defconstant +video-heritage+ 9)
(defconstant +video-paper-craft+ 10)

;; --- Quiz quantity / difficulty ---
(defconstant +quiz-fewer+ 1)
(defconstant +quiz-standard+ 2)
(defconstant +quiz-more+ 2)
(defconstant +quiz-easy+ 1)
(defconstant +quiz-medium+ 2)
(defconstant +quiz-hard+ 3)

;; --- Infographic orientation / detail / style ---
(defconstant +infographic-landscape+ 1)
(defconstant +infographic-portrait+ 2)
(defconstant +infographic-square+ 3)
(defconstant +infographic-concise+ 1)
(defconstant +infographic-standard+ 2)
(defconstant +infographic-detailed+ 3)
(defconstant +infographic-auto-select+ 1)
(defconstant +infographic-sketch-note+ 2)
(defconstant +infographic-professional+ 3)
(defconstant +infographic-bento-grid+ 4)
(defconstant +infographic-editorial+ 5)
(defconstant +infographic-instructional+ 6)
(defconstant +infographic-bricks+ 7)
(defconstant +infographic-clay+ 8)
(defconstant +infographic-anime+ 9)
(defconstant +infographic-kawaii+ 10)
(defconstant +infographic-scientific+ 11)

;; --- Slide deck ---
(defconstant +slide-deck-detailed+ 1)
(defconstant +slide-deck-presenter+ 2)
(defconstant +slide-deck-default+ 1)
(defconstant +slide-deck-short+ 2)

;; --- Chat ---
(defconstant +chat-default+ 1)
(defconstant +chat-custom+ 2)
(defconstant +chat-learning-guide+ 3)
(defconstant +chat-response-default+ 1)
(defconstant +chat-response-longer+ 4)
(defconstant +chat-response-shorter+ 5)

;; --- Export ---
(defconstant +export-docs+ 1)
(defconstant +export-sheets+ 2)

;; --- Share ---
(defconstant +share-restricted+ 0)
(defconstant +share-anyone-with-link+ 1)
(defconstant +share-full-notebook+ 0)
(defconstant +share-chat-only+ 1)
(defconstant +share-owner+ 1)
(defconstant +share-editor+ 2)
(defconstant +share-viewer+ 3)
(defconstant +share-remove+ 4)

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
