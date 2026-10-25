(defpackage #:cl-cc/type/generics/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/generics
                #:*generic-instance-registry*
                #:generic-k1-p #:generic-k1-value
                #:generic-product-left #:generic-product-p
                #:generic-query #:generic-representation-of
                #:generic-representation-valid-p #:generic-show
                #:generic-sum-p #:generic-transform #:generic-u1-p
                #:lookup-generic-instance
                #:make-generic-k1 #:make-generic-m1 #:make-generic-product
                #:make-generic-sum #:make-generic-u1
                #:register-generic-instance))
