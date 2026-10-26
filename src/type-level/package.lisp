(defpackage :cl-cc/type/type-level
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:type-advanced-p #:type-advanced-feature-id
                #:type-advanced-name #:type-advanced-args
                #:make-type-constructor #:type-constructor-p
                #:type-constructor-name #:type-constructor-args
                #:type-equal-p #:type-record-p #:type-record-fields)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:make-type-level-natural #:type-level-natural-p
           #:type-level-natural-value #:known-nat-value
           #:type-plus #:type-mul
           #:make-length-indexed-vector-type #:make-matrix-type
           #:matrix-mul-type
           #:make-type-level-string #:type-level-string-p
           #:type-level-string-value #:has-field-type
           #:get-field-type #:template-literal-type))