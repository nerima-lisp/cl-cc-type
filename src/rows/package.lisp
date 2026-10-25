(defpackage :cl-cc/type/rows
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:make-type-record #:type-record #:type-record-p #:type-record-fields #:type-record-row-var
                #:type-variant #:type-variant-p #:type-variant-cases #:type-variant-row-var
                #:type-effect-row-p #:type-effect-row-row-var #:%format-row-fields)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:export #:row-closed-p
           #:row-extend
           #:row-labels
           #:row-open-p
           #:row-restrict
           #:row-select))
