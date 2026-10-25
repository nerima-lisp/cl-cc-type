(defpackage :cl-cc/type/generics
  (:use #:cl)
  (:export
   #:generic-u1 #:generic-u1-p #:make-generic-u1
   #:generic-k1 #:generic-k1-p #:make-generic-k1 #:generic-k1-value #:generic-k1-type
   #:generic-m1 #:generic-m1-p #:make-generic-m1 #:generic-m1-meta #:generic-m1-representation
   #:generic-product #:generic-product-p #:make-generic-product
   #:generic-product-left #:generic-product-right
   #:generic-sum #:generic-sum-p #:make-generic-sum #:generic-sum-tag #:generic-sum-value
   #:generic-instance #:generic-instance-p #:make-generic-instance
   #:generic-instance-type #:generic-instance-representation
   #:generic-instance-show #:generic-instance-traverse
   #:*generic-instance-registry*
   #:register-generic-instance #:lookup-generic-instance
   #:generic-representation-of #:generic-show #:generic-transform #:generic-query
   #:generic-representation-valid-p))
