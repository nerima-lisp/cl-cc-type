(defpackage #:cl-cc/type/exhaustiveness/test
 (:use #:cl #:cl-weave)
 (:shadowing-import-from #:cl-weave #:describe)
 (:import-from #:cl-cc/type/exhaustiveness
  #:check-etypecase-completeness #:check-typecase-exhaustiveness
  #:typecase-arm-subsumed-p #:useful-typecase-arms))