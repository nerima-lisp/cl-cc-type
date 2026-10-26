(defpackage #:cl-cc/type/concurrency/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/concurrency
                #:register-concurrency-traits #:sendable-type-p
                #:shareable-type-p #:validate-shared-reference
                #:validate-spawn-argument))
