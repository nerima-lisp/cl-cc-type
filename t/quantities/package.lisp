(defpackage #:cl-cc/type/quantities/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/quantities
    #:+mult-zero+ #:+mult-one+ #:+mult-omega+
    #:finite-semiring-valid-p #:grade-designator-p #:graded-add #:graded-compose
    #:graded-value-grade #:make-finite-semiring #:make-graded-value #:make-qtt-binding
    #:make-qtt-semiring #:mult-add #:mult-leq #:mult-mul #:mult-to-string
    #:multiplicity-p #:multiplicity* #:multiplicity+ #:multiplicity<=
    #:multiplicity-one-p #:multiplicity-unrestricted-p #:normalize-multiplicity
    #:qtt-erased-p #:usage-satisfies-multiplicity-p #:valid-multiplicity-p)
  (:import-from #:cl-cc/type/type-model
    #:make-type-linear #:make-type-arrow #:type-int #:type-string)
  (:import-from #:cl-cc/type/syntax #:parse-type-specifier #:type-to-string)
  (:import-from #:cl-cc/type/advanced-metadata #:type-advanced-valid-p))
