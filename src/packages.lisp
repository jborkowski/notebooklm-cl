(defpackage #:notebooklm-cl.env
  (:use #:cl)
  (:export #:*default-base-url*
           #:get-base-url
           #:get-base-host
           #:get-default-language))

(defpackage #:notebooklm-cl.util
  (:use #:cl)
  (:export #:url-encode
           #:starts-with-p
           #:ends-with-p))

(defpackage #:notebooklm-cl.errors
  (:use #:cl)
  (:export #:notebooklm-error
           #:validation-error
           #:configuration-error
           #:network-error
           #:network-error-original
           #:rpc-error
           #:rpc-error-method-id
           #:rpc-error-rpc-code
           #:rpc-error-found-ids
           #:rpc-error-raw-response
           #:auth-error
           #:rate-limit-error
           #:rate-limit-error-retry-after
           #:server-error
           #:server-error-status-code
           #:client-error
           #:client-error-status-code
           #:rpc-timeout-error
           #:rpc-timeout-error-timeout-seconds
           #:decoding-error
           #:unknown-rpc-method-error))

(defpackage #:notebooklm-cl.rpc.types
  (:use #:cl)
  (:export #:define-rpc-methods
           #:rpc-methods
           ;; artifact type codes
           #:+artifact-audio+
           #:+artifact-report+
           #:+artifact-video+
           #:+artifact-quiz+
           #:+artifact-mind-map+
           #:+artifact-infographic+
           #:+artifact-slide-deck+
           #:+artifact-data-table+
           ;; artifact status codes
           #:+artifact-processing+
           #:+artifact-pending+
           #:+artifact-completed+
           #:+artifact-failed+
           #:artifact-status-to-str
           ;; source status codes
           #:+source-processing+
           #:+source-ready+
           #:+source-error+
           #:+source-preparing+
           #:source-status-to-str
           ;; Audio
           #:+audio-deep-dive+ #:+audio-brief+ #:+audio-critique+ #:+audio-debate+
           #:+audio-short+ #:+audio-default+ #:+audio-long+
           ;; Video
           #:+video-explainer+ #:+video-brief+ #:+video-cinematic+
           #:+video-auto-select+ #:+video-custom+ #:+video-classic+
           #:+video-whiteboard+ #:+video-kawaii+ #:+video-anime+
           #:+video-watercolor+ #:+video-retro-print+ #:+video-heritage+
           #:+video-paper-craft+
           ;; Quiz
           #:+quiz-fewer+ #:+quiz-standard+ #:+quiz-more+
           #:+quiz-easy+ #:+quiz-medium+ #:+quiz-hard+
           ;; Infographic
           #:+infographic-landscape+ #:+infographic-portrait+ #:+infographic-square+
           #:+infographic-concise+ #:+infographic-standard+ #:+infographic-detailed+
           #:+infographic-auto-select+ #:+infographic-sketch-note+
           #:+infographic-professional+ #:+infographic-bento-grid+
           #:+infographic-editorial+ #:+infographic-instructional+
           #:+infographic-bricks+ #:+infographic-clay+
           #:+infographic-anime+ #:+infographic-kawaii+ #:+infographic-scientific+
           ;; Slide Deck
           #:+slide-deck-detailed+ #:+slide-deck-presenter+
           #:+slide-deck-default+ #:+slide-deck-short+
           ;; Chat
           #:+chat-default+ #:+chat-custom+ #:+chat-learning-guide+
           #:+chat-response-default+ #:+chat-response-longer+ #:+chat-response-shorter+
           ;; Export
           #:+export-docs+ #:+export-sheets+
           ;; Share
           #:+share-restricted+ #:+share-anyone-with-link+
           #:+share-full-notebook+ #:+share-chat-only+
           #:+share-owner+ #:+share-editor+ #:+share-viewer+ #:+share-remove+
           ;; URLs
           #:get-batchexecute-url
           #:get-query-url
           #:get-upload-url))

(defpackage #:notebooklm-cl.rpc.encoder
  (:use #:cl)
  (:export #:encode-rpc-request
           #:build-request-body))

(defpackage #:notebooklm-cl.rpc.decoder
  (:use #:cl)
  (:export #:strip-anti-xssi
           #:parse-chunked-response
           #:collect-rpc-ids
           #:extract-rpc-result
           #:decode-response
           #:rpc-error-code
           #:get-error-message-for-code))

(defpackage #:notebooklm-cl.core
  (:use #:cl)
  (:export #:client-core
           #:make-client-core
           #:client-core-p
           #:open-client
           #:close-client
           #:client-open-p
           #:rpc-call
           #:build-url))

(defpackage #:notebooklm-cl
  (:use #:cl)
  (:import-from #:notebooklm-cl.errors
                #:notebooklm-error #:network-error #:rpc-error
                #:auth-error #:rate-limit-error #:server-error #:client-error
                #:rpc-timeout-error)
  (:import-from #:notebooklm-cl.core
                #:client-core #:make-client-core #:open-client #:close-client #:rpc-call)
  (:export #:client-core #:make-client-core #:open-client #:close-client #:rpc-call
           #:notebooklm-error #:rpc-error #:network-error #:auth-error
           #:rate-limit-error #:server-error #:client-error))
