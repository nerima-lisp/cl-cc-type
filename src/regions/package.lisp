(defpackage :cl-cc/type/regions
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
   #:define-simple-condition #:type-system-error)
  (:export
   #:region-lifetime-error #:region-token #:region-token-p #:region-token-id
   #:region-token-generation #:region-token-active-p #:make-region-token #:close-region
   #:region-active-p #:region-ref #:region-ref-p #:region-ref-token
   #:region-ref-generation #:region-ref-value #:region-alloc #:region-ref-valid-p
   #:region-deref #:with-region))
