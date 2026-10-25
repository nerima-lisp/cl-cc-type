(defpackage #:cl-cc/type/utility-types/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/utility-types
                #:frozen-value-p #:freeze
                #:writable-type #:deep-readonly-type
                #:partial-type #:required-type #:pick-type #:omit-type
                #:exclude-type #:extract-type #:non-nullable-type
                #:return-type-of)
  (:import-from #:cl-cc/type/type-model
                #:make-type-record #:type-string #:type-int #:type-bool
                #:make-type-union #:type-null #:type-advanced-p
                #:type-capability-p #:type-capability-base
                #:type-record-fields #:type-union-p #:make-type-arrow))