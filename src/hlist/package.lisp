(defpackage :cl-cc/type/hlist
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:type-node #:type-advanced-p
                #:type-advanced-feature-id #:type-advanced-args)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:make-hlist-type #:hlist-head-type #:hlist-tail-type))