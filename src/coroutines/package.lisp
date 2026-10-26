(defpackage :cl-cc/type/coroutines
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:any #:type-null
                #:type-primitive-p #:type-primitive-name
                #:type-advanced-p #:type-advanced-name
                #:type-constructor-p #:type-constructor-name)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:generator #:coroutine
           #:typed-generator #:typed-generator-p
           #:typed-generator-yield-type #:typed-generator-return-type
           #:typed-coroutine #:typed-coroutine-p
           #:typed-coroutine-send-type #:typed-coroutine-receive-type
           #:typed-coroutine-return-type #:typed-coroutine-done-p
           #:make-generator #:generator-next #:make-coroutine
           #:coroutine-resume #:make-generator-type #:make-coroutine-type))
