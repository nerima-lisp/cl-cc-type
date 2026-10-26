(defpackage :cl-cc/type/quantities
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model #:type-linear #:type-linear-base #:type-linear-grade)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:import-from #:cl-cc/type/advanced-metadata #:register-type-advanced-normalizer #:register-type-advanced-validator #:%type-advanced-invalid #:%type-advanced-require-min-args #:type-advanced-args)
  (:export #:+mult-omega+
           #:+mult-one+
           #:+mult-zero+
           #:finite-semiring
           #:finite-semiring-add
           #:finite-semiring-elements
           #:finite-semiring-multiply
           #:finite-semiring-name
           #:finite-semiring-one
           #:finite-semiring-p
           #:finite-semiring-preorder
           #:finite-semiring-valid-p
           #:finite-semiring-zero
           #:grade-designator-p
           #:graded-add
           #:graded-compose
           #:graded-value
           #:graded-value-grade
           #:graded-value-p
           #:graded-value-payload
           #:graded-value-semiring
           #:make-finite-semiring
           #:make-graded-value
           #:make-qtt-binding
           #:make-qtt-semiring
           #:mult-add
           #:mult-leq
           #:mult-mul
           #:mult-to-string
           #:multiplicity
           #:multiplicity*
           #:multiplicity+
           #:multiplicity-one-p
           #:multiplicity-p
           #:multiplicity-unrestricted-p
           #:multiplicity-zero-p
           #:multiplicity<=
           #:normalize-multiplicity
           #:qtt-binding
           #:qtt-binding-multiplicity
           #:qtt-binding-name
           #:qtt-binding-p
           #:qtt-binding-type
           #:qtt-erased-p
           #:usage-satisfies-multiplicity-p
           #:valid-multiplicity-p)
)
