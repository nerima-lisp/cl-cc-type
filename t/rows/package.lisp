(defpackage #:cl-cc/type/rows/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/rows
    #:row-closed-p #:row-extend #:row-labels #:row-open-p #:row-restrict #:row-select)
  (:import-from #:cl-cc/type/type-model
    #:fresh-type-var #:make-type-effect-op #:make-type-effect-row
    #:make-type-record #:make-type-variant #:type-bool #:type-effect-row-effects
    #:type-effect-row-row-var #:type-int #:type-null #:type-record-fields
    #:type-record-p #:type-record-row-var #:type-string #:type-var-p)
  (:import-from #:cl-cc/type/syntax #:type-to-string))
