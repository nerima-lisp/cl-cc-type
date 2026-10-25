(defpackage #:cl-cc/type-test-support
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/type-model #:type-equal-p)
  (:import-from #:cl-cc/type/unification #:type-unify)
  (:export #:assert-when-present
           #:internal-function
           #:internal-symbol))
