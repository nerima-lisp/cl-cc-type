(defpackage :cl-cc/type/simd/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/simd
                #:simd-vector #:make-simd-vector
                #:simd-vector-lanes #:simd-vector-values
                #:simd-add #:simd-map #:make-simd-type)
  (:import-from #:cl-cc/type/type-model
                #:type-int #:type-advanced-p
                #:type-advanced-name #:type-advanced-args))