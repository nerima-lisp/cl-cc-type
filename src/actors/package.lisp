(defpackage :cl-cc/type/actors
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:any
                #:type-primitive-p #:type-primitive-name
                #:type-advanced-p #:type-advanced-name
                #:type-constructor-p #:type-constructor-name
                #:type-union-p #:type-union-types)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:actor-ref
           #:typed-actor-ref #:typed-actor-ref-p
           #:typed-actor-ref-message-type #:typed-actor-ref-state
           #:typed-actor-ref-remote-p #:typed-actor-ref-mailbox
           #:make-actor-ref #:actor-ref-type
           #:actor-message-accepted-p #:actor-send #:actor-stop))
