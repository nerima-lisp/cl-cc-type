(defpackage :cl-cc/type/channels/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/channels
                #:channel #:send-channel #:recv-channel
                #:make-buffered-channel #:channel-payload-type
                #:channel-send #:channel-recv #:close-typed-channel
                #:make-typed-channel #:send-channel-channel
                #:recv-channel-channel #:make-channel-type)
  (:import-from #:cl-cc/type/type-model
                #:make-type-constructor #:type-any
                #:type-advanced-p #:type-advanced-name
                #:type-advanced-args #:type-advanced-properties)
  (:import-from #:cl-cc/type-test-support
                #:internal-function #:internal-symbol))