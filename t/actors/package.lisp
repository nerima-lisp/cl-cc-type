(defpackage :cl-cc/type/actors/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/actors
                #:actor-ref #:make-actor-ref #:actor-ref-type
                #:actor-message-accepted-p #:actor-send #:actor-stop
                #:typed-actor-ref-mailbox #:typed-actor-ref-remote-p)
  (:import-from #:cl-cc/type/type-model
                #:make-type-union #:type-advanced-p #:type-advanced-name))