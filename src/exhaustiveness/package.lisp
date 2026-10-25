(defpackage :cl-cc/type/exhaustiveness
  (:use #:cl)
  (:import-from #:cl-cc/type/subtyping #:type-name-subtype-p)
  (:export
    #:check-typecase-exhaustiveness #:check-etypecase-completeness
    #:useful-typecase-arms #:typecase-arm-subsumed-p))

