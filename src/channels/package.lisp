(defpackage :cl-cc/type/channels
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:any
                #:type-primitive-p #:type-primitive-name
                #:type-advanced-p #:type-advanced-name
                #:type-constructor-p #:type-constructor-name)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:channel
           #:typed-channel #:typed-channel-p
           #:send-channel #:send-channel-p #:send-channel-channel
           #:recv-channel #:recv-channel-p #:recv-channel-channel
           #:make-typed-channel #:make-buffered-channel
           #:channel-payload-type #:channel-send #:channel-recv
           #:close-typed-channel #:make-channel-type))
