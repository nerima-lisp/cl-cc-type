(defpackage #:cl-cc/type/hlist/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/hlist
                #:make-hlist-type #:hlist-head-type #:hlist-tail-type)
  (:import-from #:cl-cc/type/type-model
                #:type-int #:type-string #:type-bool
                #:type-advanced-p #:type-advanced-feature-id))