(defpackage #:cl-cc/type/regions/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/regions
                #:close-region #:make-region-token #:region-active-p
                #:region-alloc #:region-deref #:region-lifetime-error
                #:region-ref-valid-p #:with-region)
  (:import-from #:cl-cc/type-test-support #:internal-function))
