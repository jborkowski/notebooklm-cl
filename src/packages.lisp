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
           #:ends-with-p
           #:%nths
           #:with-nested-extract
           #:extract-youtube-video-id
           #:valid-youtube-video-id-p))

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
           #:unknown-rpc-method-error
           #:notebook-limit-error
           #:notebook-limit-error-current-count
           #:notebook-limit-error-limit
           #:notebook-limit-error-original
           #:source-add-error
           #:source-add-error-label
           #:source-add-error-message
           #:source-add-error-cause
           #:source-not-found-error
           #:source-not-found-error-source-id
           #:source-not-found-error-notebook-id
           #:artifact-not-ready-error
           #:artifact-not-ready-error-artifact-type
           #:artifact-not-ready-error-artifact-id
           #:artifact-not-found-error
           #:artifact-not-found-error-artifact-id
           #:artifact-not-found-error-artifact-type
           #:artifact-parse-error
           #:artifact-parse-error-artifact-type
           #:artifact-parse-error-artifact-id
           #:artifact-parse-error-details
           #:artifact-parse-error-cause
           #:artifact-download-error
           #:artifact-download-error-artifact-type
           #:artifact-download-error-artifact-id
           #:artifact-download-error-details))

(defpackage #:notebooklm-cl.rpc.types
  (:use #:cl)
  (:export #:define-rpc-methods
           ;; RPC method IDs
           #:*list-notebooks* #:*create-notebook* #:*get-notebook*
           #:*rename-notebook* #:*delete-notebook* #:*add-source*
           #:*add-source-file* #:*delete-source* #:*get-source*
           #:*refresh-source* #:*check-source-freshness* #:*update-source*
           #:*discover-sources* #:*summarize* #:*get-source-guide*
           #:*get-suggested-reports* #:*create-artifact* #:*list-artifacts*
           #:*delete-artifact* #:*rename-artifact* #:*export-artifact*
           #:*share-artifact* #:*get-interactive-html* #:*revise-slide*
           #:*start-fast-research* #:*start-deep-research* #:*poll-research*
           #:*import-research* #:*generate-mind-map* #:*create-note*
           #:*get-notes-and-mind-maps* #:*update-note* #:*delete-note*
           #:*get-last-conversation-id* #:*get-conversation-turns*
           #:*share-notebook* #:*get-share-status*
           #:*remove-recently-viewed* #:*get-user-settings*
           #:*set-user-settings* #:*get-user-tier*
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
           #:get-upload-url
           ;; Drive MIME types
           #:+drive-mime-google-doc+
           #:+drive-mime-google-slides+
           #:+drive-mime-google-sheets+
           #:+drive-mime-pdf+
           ;; Report formats (wire strings)
           #:*report-format-briefing-doc*
           #:*report-format-study-guide*
           #:*report-format-blog-post*
           #:*report-format-custom*))

(defpackage #:notebooklm-cl.types
  (:use #:cl)
  (:import-from #:notebooklm-cl.env
                #:get-base-url)
  (:import-from #:notebooklm-cl.util
                #:%nths)
  (:import-from #:notebooklm-cl.rpc.types
                #:artifact-status-to-str
                #:source-status-to-str)
  (:export
   ;; type-to-string helpers
   #:source-type-code-to-kind
   #:artifact-type-to-kind
   #:*source-type-code-map*
   #:*artifact-type-code-map*
   ;; source
   #:source #:make-source #:source-p #:source-id #:source-title #:source-url
   #:source-type-code #:source-created-at #:source-status
   #:source-kind #:source-is-ready-p #:source-is-processing-p #:source-is-error-p
   #:source-from-api-response
   ;; notebook
   #:notebook #:make-notebook #:notebook-p
   #:notebook-id #:notebook-title #:notebook-is-owner
   #:notebook-sources-count #:notebook-created-at
   #:notebook-from-api-response
   ;; suggested-topic
   #:suggested-topic #:make-suggested-topic #:suggested-topic-p
   #:topic-question #:topic-prompt
   ;; notebook-description
   #:notebook-description #:make-notebook-description #:notebook-description-p
   #:description-summary #:description-suggested-topics
   #:notebook-description-from-api-response
   ;; source-summary
   #:source-summary #:make-source-summary #:source-summary-p
   #:ss-kind #:ss-title #:ss-url
   ;; notebook-metadata
   #:notebook-metadata #:make-notebook-metadata #:notebook-metadata-p
   #:nb-meta-notebook #:nb-meta-sources
   #:notebook-metadata-from-api-response
   ;; artifact
   #:artifact #:make-artifact #:artifact-p
   #:art-id #:art-title #:art-artifact-type #:art-status
   #:art-created-at #:art-url #:art-variant #:art-error
   #:artifact-kind #:artifact-is-completed-p #:artifact-is-processing-p
   #:artifact-is-pending-p #:artifact-is-failed-p
   #:artifact-is-quiz-p #:artifact-is-flashcards-p
   #:artifact-status-str
   #:artifact-from-api-response
   #:artifact-from-mind-map-data
   #:artifact-row-media-download-ready-p
   #:artifact-row-download-url
   #:artifact-row-error-message
   ;; generation-status
   #:generation-status #:make-generation-status #:generation-status-p
   #:gen-task-id #:gen-status #:gen-url #:gen-error #:gen-error-code #:gen-metadata
   #:generation-is-complete-p #:generation-is-failed-p #:generation-is-pending-p
   #:generation-status-from-api-response
   ;; note
   #:note #:make-note #:note-p
   #:note-id #:note-notebook-id #:note-title #:note-content #:note-created-at
   #:note-from-api-response
   ;; source-fulltext
   #:source-fulltext #:make-source-fulltext #:source-fulltext-p
   #:sf-source-id #:sf-title #:sf-content #:sf-type-code #:sf-url #:sf-char-count
   #:source-fulltext-kind #:source-fulltext-from-api-response
   ;; account-limits
   #:account-limits #:make-account-limits #:account-limits-p
   #:limits-notebook-limit #:limits-source-limit #:limits-raw-limits
   #:account-limits-from-api-response
   ;; account-tier
   #:account-tier #:make-account-tier #:account-tier-p
   #:tier-tier #:tier-plan-name
   ;; chat-reference
   #:chat-reference #:make-chat-reference #:chat-reference-p
   #:ref-source-id #:ref-cited-text
   #:ref-citation-number #:ref-start-char #:ref-end-char #:ref-chunk-id
   #:chat-reference-from-api-response
   ;; conversation-turn
   #:conversation-turn #:make-conversation-turn #:conversation-turn-p
   #:turn-query #:turn-answer #:turn-turn-number #:turn-references
   #:conversation-turn-from-api-response
   ;; ask-result
   #:ask-result #:make-ask-result #:ask-result-p
   #:ask-answer #:ask-conversation-id #:ask-turn-number
   #:ask-is-follow-up #:ask-references #:ask-raw-response
   #:ask-result-from-api-response
   ;; shared-user
   #:shared-user #:make-shared-user #:shared-user-p
   #:su-email #:su-name #:su-permission #:su-photo-url
   #:shared-user-from-api-response
   ;; share-status
   #:share-status #:make-share-status #:share-status-p
   #:share-notebook-id #:share-public #:share-access-level
   #:share-view-level #:share-users #:share-share-url
   #:share-status-from-api-response
   ;; report-suggestion
   #:report-suggestion #:make-report-suggestion #:report-suggestion-p
   #:rs-title #:rs-description #:rs-prompt #:rs-audience-level
   #:report-suggestion-from-api-response
   ;; helper
   #:parse-timestamp
   #:strip-thought-newline))

(defpackage #:notebooklm-cl.rpc.encoder
  (:use #:cl)
  (:export #:encode-rpc-request
           #:build-request-body))

(defpackage #:notebooklm-cl.rpc.decoder
  (:use #:cl)
  (:export #:strip-anti-xssi
           #:split-lines
           #:parse-chunked-response
           #:collect-rpc-ids
           #:extract-rpc-result
           #:decode-response
           #:rpc-error-code
           #:get-error-message-for-code))

(defpackage #:notebooklm-cl.core
  (:use #:cl)
  (:export #:client-core
           #:client-core-p
           #:client-core-auth
           #:client-core-http
           #:client-core-timeout
           #:client-core-connect-timeout
           #:client-core-refresh-callback
           #:client-core-reqid-counter
           #:make-client-core
           #:auth-tokens
           #:auth-tokens-p
           #:auth-tokens-csrf-token
           #:auth-tokens-session-id
           #:auth-tokens-account-email
           #:auth-tokens-authuser
           #:auth-tokens-cookie-header
           #:make-auth-tokens
           #:open-client
           #:close-client
           #:client-open-p
           #:rpc-call
           #:build-url))

(defpackage #:notebooklm-cl.notebooks
  (:use #:cl)
  (:import-from #:notebooklm-cl.core
                #:client-core #:rpc-call)
  (:import-from #:notebooklm-cl.types
                #:notebook #:make-notebook #:notebook-p
                #:notebook-id #:notebook-title #:notebook-is-owner
                #:notebook-sources-count #:notebook-created-at
                #:notebook-from-api-response
                #:notebook-description #:make-notebook-description #:notebook-description-p
                #:description-summary #:description-suggested-topics
                #:notebook-description-from-api-response
                #:suggested-topic #:make-suggested-topic #:suggested-topic-p
                #:topic-question #:topic-prompt
                #:notebook-metadata #:make-notebook-metadata #:notebook-metadata-p
                #:nb-meta-notebook #:nb-meta-sources
                #:notebook-metadata-from-api-response
                #:source-summary #:make-source-summary #:source-summary-p
                #:ss-kind #:ss-title #:ss-url
                #:account-limits #:make-account-limits #:account-limits-p
                #:limits-notebook-limit #:account-limits-from-api-response)
  (:import-from #:notebooklm-cl.rpc.types
                #:*list-notebooks* #:*create-notebook* #:*get-notebook*
                #:*rename-notebook* #:*delete-notebook*
                #:*summarize* #:*remove-recently-viewed*
                #:*share-artifact*
                #:*get-user-settings* #:get-batchexecute-url)
  (:import-from #:notebooklm-cl.env
                #:get-base-url)
  (:import-from #:notebooklm-cl.errors
                #:notebooklm-error #:rpc-error #:network-error
                #:rpc-error-method-id #:rpc-error-rpc-code
                #:notebook-limit-error)
  (:export
   #:list-notebooks
   #:create-notebook
   #:get-notebook
   #:delete-notebook
   #:rename-notebook
   #:get-summary
   #:get-description
   #:remove-from-recent
   #:get-notebook-raw
   #:share-notebook
   #:get-share-url
   #:get-metadata))

(defpackage #:notebooklm-cl.sources
  (:use #:cl)
  (:import-from #:notebooklm-cl.core
                #:client-core #:client-core-auth #:client-core-connect-timeout
                #:client-core-timeout #:rpc-call
                #:auth-tokens-account-email #:auth-tokens-authuser
                #:auth-tokens-cookie-header)
  (:import-from #:notebooklm-cl.types
                #:source #:make-source #:source-id #:source-from-api-response
                #:source-fulltext-from-api-response)
  (:import-from #:notebooklm-cl.util
                #:extract-youtube-video-id)
  (:export
   #:list-sources #:get-source
   #:add-url #:add-text-source #:add-drive-source
   #:delete-source #:rename-source #:refresh-source
   #:check-source-freshness #:source-freshness-fresh-p
   #:get-source-guide #:get-source-fulltext
   #:register-file-source #:start-resumable-upload #:upload-file-to-url
   #:add-file-source
   #:discover-sources))

(defpackage #:notebooklm-cl.artifacts
  (:use #:cl)
  (:import-from #:notebooklm-cl.core
                #:client-core #:rpc-call)
  (:import-from #:notebooklm-cl.sources
                #:list-sources)
  (:import-from #:notebooklm-cl.env
                #:get-default-language)
  (:import-from #:notebooklm-cl.errors
                #:rpc-error #:rpc-error-rpc-code
                #:rpc-timeout-error
                #:validation-error
                #:artifact-download-error
                #:artifact-download-error-details
                #:artifact-download-error-artifact-type
                #:artifact-parse-error
                #:artifact-not-ready-error)
  (:import-from #:notebooklm-cl.util
                #:%nths)
  (:import-from #:notebooklm-cl.types
                #:artifact-from-api-response #:artifact-from-mind-map-data
                #:artifact-kind #:art-id
                #:source-id
                #:make-generation-status #:generation-status-from-api-response
                #:generation-is-complete-p #:generation-is-failed-p
                #:report-suggestion-from-api-response
                #:artifact-row-media-download-ready-p
                #:artifact-row-download-url
                #:artifact-row-error-message)
  (:import-from #:notebooklm-cl.rpc.types
                #:*list-artifacts* #:*get-notes-and-mind-maps*
                #:*create-artifact*
                #:*generate-mind-map* #:*create-note*
                #:*delete-artifact* #:*rename-artifact* #:*export-artifact*
                #:*get-suggested-reports*
                #:artifact-status-to-str
                #:+artifact-audio+ #:+artifact-report+
                #:+artifact-video+ #:+artifact-infographic+
                #:+artifact-quiz+
                #:+artifact-slide-deck+ #:+artifact-data-table+
                #:+artifact-completed+ #:+artifact-processing+
                #:+video-cinematic+ #:+video-custom+
                #:+export-docs+ #:+export-sheets+
                #:*report-format-briefing-doc* #:*report-format-study-guide*
                #:*report-format-blog-post* #:*report-format-custom*)
  (:export
   #:list-artifacts
   #:define-artifact-lister
   #:list-audio #:list-video #:list-reports
   #:list-quizzes #:list-flashcards #:list-infographics
   #:list-slide-decks #:list-data-tables
   #:get-artifact
   #:suggest-reports
   #:generate-audio
   #:generate-report
   #:generate-quiz
   #:generate-flashcards
   #:generate-video
   #:generate-infographic
   #:generate-slide-deck
   #:generate-data-table
   #:generate-cinematic-video
   #:generate-mind-map
   #:wait-for-artifact
   #:define-simple-downloader
   #:download-audio #:download-video #:download-infographic
   #:download-report #:download-data-table #:download-slide-deck
   ;; internal helpers — exported for tests
   #:%source-ids-triple #:%source-ids-double
   #:%report-format-config #:%now-seconds
   #:%download-url #:%validate-download-url
   #:%select-artifact
   #:delete-artifact
   #:rename-artifact
   #:export-artifact
   #:export-report
   #:export-data-table
   #:poll-artifact-status-from-rows
   #:poll-artifact-status))

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
