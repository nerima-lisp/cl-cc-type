(defpackage :cl-cc/type/simd
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
                #:any
                #:type-primitive-p #:type-primitive-name
                #:type-advanced-p #:type-advanced-name
                #:type-constructor-p #:type-constructor-name)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export #:simd-vector #:simd-vector-p
           #:simd-vector-element-type #:simd-vector-lanes
           #:simd-vector-values #:make-simd-vector
           #:simd-map #:simd-add #:make-simd-type))
