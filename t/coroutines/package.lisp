(defpackage :cl-cc/type/coroutines/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/coroutines
                #:generator #:coroutine
                #:make-generator #:generator-next
                #:make-coroutine #:coroutine-resume
                #:typed-coroutine-done-p
                #:make-generator-type #:make-coroutine-type)
  (:import-from #:cl-cc/type/type-model
                #:type-int #:type-string #:type-bool
                #:type-advanced-p #:type-advanced-name
                #:type-advanced-args))