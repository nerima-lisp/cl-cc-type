(defpackage #:cl-cc/type/facade/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/type-level
                #:has-field-type #:get-field-type)
  (:import-from #:cl-cc/type/utility-types
                #:freeze #:frozen-value-p #:partial-type #:required-type)
  (:import-from #:cl-cc/type/type-model
                #:make-type-record #:type-advanced-p #:type-int
                #:type-string #:type-union-p))
