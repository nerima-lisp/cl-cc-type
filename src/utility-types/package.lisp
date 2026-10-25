(defpackage :cl-cc/type/utility-types
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:make-type-capability
                #:type-record-p #:make-type-record
                #:type-record-fields #:type-record-row-var
                #:type-union-p #:make-type-union #:type-union-types
                #:type-union-constructor-name #:type-null
                #:type-equal-p #:type-arrow-p #:type-arrow-return)
  (:import-from #:cl-cc/type/subtyping #:is-subtype-p)
  (:export #:frozen-value #:frozen-value-p #:make-frozen-value
           #:frozen-value-value #:frozen-value-type
           #:readonly-type #:writable-type #:deep-readonly-type #:freeze
           #:partial-type #:required-type #:pick-type #:omit-type
           #:exclude-type #:extract-type #:non-nullable-type
           #:return-type-of))