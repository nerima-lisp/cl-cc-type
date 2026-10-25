(defpackage #:cl-cc/type/type-level/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/type-level
                #:make-type-level-natural #:type-level-natural-p
                #:type-level-natural-value #:known-nat-value
                #:type-plus #:type-mul
                #:make-length-indexed-vector-type #:make-matrix-type
                #:matrix-mul-type
                #:make-type-level-string #:type-level-string-p
                #:type-level-string-value
                #:get-field-type #:template-literal-type)
  (:import-from #:cl-cc/type/type-model
                #:type-string #:type-int #:make-type-record
                #:type-constructor-p #:type-constructor-name
                #:type-constructor-args))