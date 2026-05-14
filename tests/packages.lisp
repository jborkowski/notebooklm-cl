(defpackage #:notebooklm-cl.tests
  (:use #:cl #:parachute)
  (:export #:run-tests #:test-suite)
  (:import-from #:notebooklm-cl.util
                #:url-encode #:starts-with-p #:ends-with-p
                #:extract-youtube-video-id #:valid-youtube-video-id-p)
  (:import-from #:notebooklm-cl.rpc.types
                #:artifact-status-to-str #:source-status-to-str
                #:+artifact-audio+ #:+artifact-report+ #:+artifact-video+
                #:+artifact-quiz+ #:+artifact-mind-map+
                #:+artifact-infographic+ #:+artifact-slide-deck+
                #:+artifact-data-table+
                #:+artifact-processing+ #:+artifact-pending+
                #:+artifact-completed+ #:+artifact-failed+
                #:+source-processing+ #:+source-ready+
                #:+source-error+ #:+source-preparing+
                #:+audio-deep-dive+ #:+audio-brief+ #:+audio-critique+
                #:+audio-debate+ #:+audio-short+ #:+audio-default+ #:+audio-long+
                #:+video-explainer+ #:+video-brief+ #:+video-cinematic+
                #:+video-auto-select+ #:+video-custom+ #:+video-classic+
                #:+video-whiteboard+ #:+video-kawaii+ #:+video-anime+
                #:+video-watercolor+ #:+video-retro-print+ #:+video-heritage+
                #:+video-paper-craft+
                #:+quiz-fewer+ #:+quiz-standard+ #:+quiz-more+
                #:+quiz-easy+ #:+quiz-medium+ #:+quiz-hard+
                #:+infographic-landscape+ #:+infographic-portrait+
                #:+infographic-square+ #:+infographic-concise+
                #:+infographic-standard+ #:+infographic-detailed+
                #:+infographic-auto-select+ #:+infographic-sketch-note+
                #:+infographic-professional+ #:+infographic-bento-grid+
                #:+infographic-editorial+ #:+infographic-instructional+
                #:+infographic-bricks+ #:+infographic-clay+
                #:+infographic-anime+ #:+infographic-kawaii+
                #:+infographic-scientific+
                #:+slide-deck-detailed+ #:+slide-deck-presenter+
                #:+slide-deck-default+ #:+slide-deck-short+
                #:+chat-default+ #:+chat-custom+ #:+chat-learning-guide+
                #:+chat-response-default+ #:+chat-response-longer+
                #:+chat-response-shorter+
                #:+export-docs+ #:+export-sheets+
                #:+share-restricted+ #:+share-anyone-with-link+
                #:+share-full-notebook+ #:+share-chat-only+
                #:+share-owner+ #:+share-editor+ #:+share-viewer+ #:+share-remove+
                #:*list-notebooks* #:*create-notebook* #:*get-notebook*
                #:*rename-notebook* #:*delete-notebook* #:*add-source*
                #:*add-source-file* #:*delete-source* #:*get-source*
                #:*refresh-source* #:*check-source-freshness*
                #:*update-source* #:*discover-sources* #:*summarize*
                #:*get-source-guide* #:*get-suggested-reports*
                #:*create-artifact* #:*list-artifacts* #:*delete-artifact*
                #:*rename-artifact* #:*export-artifact* #:*share-artifact*
                #:*get-interactive-html* #:*revise-slide*
                #:*start-fast-research* #:*start-deep-research*
                #:*poll-research* #:*import-research*
                #:*generate-mind-map* #:*create-note*
                #:*get-notes-and-mind-maps* #:*update-note* #:*delete-note*
                #:*get-last-conversation-id* #:*get-conversation-turns*
                #:*share-notebook* #:*get-share-status*
                #:*remove-recently-viewed* #:*get-user-settings*
                #:*set-user-settings* #:*get-user-tier*
                #:*report-format-briefing-doc* #:*report-format-study-guide*
                #:*report-format-blog-post* #:*report-format-custom*
                #:define-rpc-methods
                #:+drive-mime-google-doc+ #:+drive-mime-pdf+)
  (:import-from #:notebooklm-cl.types
                #:source-type-code-to-kind #:artifact-type-to-kind
                #:*source-type-code-map* #:*artifact-type-code-map*
                #:strip-thought-newline #:parse-timestamp
                #:source #:make-source #:source-id #:source-title
                #:source-url #:source-type-code #:source-status #:source-kind
                #:source-created-at
                #:source-is-ready-p #:source-is-processing-p #:source-is-error-p
                #:source-from-api-response
                #:notebook #:make-notebook #:notebook-id #:notebook-title
                #:notebook-is-owner #:notebook-sources-count
                #:notebook-created-at
                #:notebook-from-api-response
                #:suggested-topic #:make-suggested-topic #:topic-question #:topic-prompt
                #:notebook-description #:make-notebook-description
                #:description-summary #:description-suggested-topics
                #:notebook-description-from-api-response
                #:source-summary #:make-source-summary #:ss-kind #:ss-title #:ss-url
                #:notebook-metadata #:make-notebook-metadata
                #:nb-meta-notebook #:nb-meta-sources
                #:artifact #:make-artifact #:art-id #:art-title
                #:art-artifact-type #:art-status #:art-variant #:art-error
                #:art-created-at
                #:artifact-kind #:artifact-is-completed-p
                #:artifact-is-processing-p #:artifact-is-pending-p
                #:artifact-is-failed-p #:artifact-is-quiz-p
                #:artifact-is-flashcards-p #:artifact-status-str
                #:artifact-from-api-response
                #:artifact-from-mind-map-data
                #:generation-status #:make-generation-status
                #:gen-task-id #:gen-status #:gen-error
                #:generation-is-complete-p #:generation-is-failed-p
                #:generation-is-pending-p
                #:generation-status-from-api-response
                #:note #:make-note #:note-id #:note-notebook-id
                #:note-title #:note-content
                #:note-from-api-response
                #:source-fulltext #:make-source-fulltext
                #:sf-source-id #:sf-title #:sf-content
                #:sf-type-code #:sf-url #:sf-char-count
                #:source-fulltext-kind
                #:account-limits #:make-account-limits
                #:limits-notebook-limit #:limits-source-limit
                #:limits-raw-limits #:account-limits-from-api-response
                #:account-tier #:make-account-tier
                #:tier-tier #:tier-plan-name
                #:chat-reference #:make-chat-reference
                #:ref-source-id #:ref-cited-text #:ref-citation-number
                #:ref-start-char #:ref-end-char #:ref-chunk-id
                #:chat-reference-from-api-response
                #:conversation-turn #:make-conversation-turn
                #:turn-query #:turn-answer #:turn-turn-number #:turn-references
                #:conversation-turn-from-api-response
                #:ask-result #:make-ask-result
                #:ask-answer #:ask-conversation-id #:ask-turn-number
                #:ask-is-follow-up #:ask-references #:ask-raw-response
                #:ask-result-from-api-response
                #:shared-user #:make-shared-user
                #:su-email #:su-name #:su-permission #:su-photo-url
                #:shared-user-from-api-response
                #:share-status #:make-share-status
                #:share-notebook-id #:share-public #:share-access-level
                #:share-view-level #:share-users #:share-share-url
                #:share-status-from-api-response
                #:report-suggestion #:make-report-suggestion
                #:rs-title #:rs-description #:rs-prompt #:rs-audience-level
                #:report-suggestion-from-api-response)
  (:import-from #:notebooklm-cl.rpc.encoder
                #:encode-rpc-request #:build-request-body)
  (:import-from #:notebooklm-cl.rpc.decoder
                #:strip-anti-xssi #:split-lines
                #:parse-chunked-response #:collect-rpc-ids
                #:contains-user-displayable-error-p
                #:extract-status-code)
  (:import-from #:notebooklm-cl.env
                #:parse-url-host #:*default-base-url*
                #:get-default-language #:get-base-url #:get-base-host)
  (:import-from #:notebooklm-cl.errors
                #:notebooklm-error #:validation-error #:configuration-error
                #:network-error #:network-error-original
                #:rpc-error #:rpc-error-method-id #:rpc-error-rpc-code
                #:rpc-error-found-ids #:rpc-error-raw-response
                #:auth-error #:rate-limit-error
                #:rate-limit-error-retry-after
                #:server-error #:server-error-status-code
                #:client-error #:client-error-status-code
                #:rpc-timeout-error #:rpc-timeout-error-timeout-seconds
                #:decoding-error #:unknown-rpc-method-error
                #:notebook-limit-error #:notebook-limit-error-current-count
                #:notebook-limit-error-limit #:notebook-limit-error-original
                #:source-add-error #:source-not-found-error
                #:artifact-not-ready-error #:artifact-not-found-error
                #:artifact-parse-error #:artifact-download-error)
  (:import-from #:notebooklm-cl.core
                #:make-client-core #:open-client #:close-client
                #:client-open-p #:build-url)
  (:import-from #:notebooklm-cl.notebooks
                #:get-share-url #:get-summary #:get-description)
  (:import-from #:notebooklm-cl.artifacts
                #:poll-artifact-status-from-rows
                #:define-artifact-lister
                #:list-audio #:list-video #:list-reports
                #:list-quizzes #:list-flashcards #:list-infographics
                #:list-slide-decks #:list-data-tables
                #:get-artifact #:suggest-reports
                #:generate-audio #:generate-report
                #:generate-quiz #:generate-flashcards #:generate-video
                #:generate-infographic #:generate-slide-deck
                #:generate-data-table #:generate-cinematic-video
                #:generate-mind-map
                #:wait-for-artifact
                #:%source-ids-triple #:%source-ids-double
                #:%report-format-config #:%now-seconds
                #:%download-url #:%validate-download-url
                #:%select-artifact #:%extract-cell-text #:%csv-escape-row
                #:define-simple-downloader
                #:download-audio #:download-video #:download-infographic
                #:download-report #:download-data-table #:download-slide-deck
                #:download-quiz #:download-flashcards #:download-mind-map
                #:%extract-app-data #:%format-quiz-markdown #:%format-flashcards-markdown
                #:%html-unescape-minimal #:%json-alist-get))
