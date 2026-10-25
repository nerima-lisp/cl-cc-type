(defpackage #:cl-cc/type/ffi/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/ffi
                #:ffi-callback-type-argument-types #:ffi-callback-type-p
                #:ffi-callback-type-return-type #:ffi-descriptor-form-valid-p
                #:ffi-descriptor-from-form #:ffi-descriptor-lisp-type
                #:ffi-function-descriptor-abi #:ffi-function-descriptor-argument-types
                #:ffi-function-descriptor-name #:ffi-function-descriptor-p
                #:ffi-function-descriptor-return-type #:ffi-lisp-type-compatible-p
                #:ffi-pointer-type-borrowed-p #:ffi-pointer-type-nullable-p
                #:ffi-pointer-type-p #:ffi-pointer-type-pointee
                #:ffi-scalar-type-kind #:ffi-scalar-type-p #:ffi-type-valid-p
                #:ffi-validation-error #:make-ffi-callback-type
                #:make-ffi-function-descriptor #:make-ffi-pointer-type
                #:make-ffi-scalar-type)
  (:import-from #:cl-cc/type/type-model
                #:type-arrow-p #:type-arrow-params #:type-arrow-return
                #:type-bool #:type-char #:type-float #:type-int #:type-null
                #:type-primitive-name #:type-string)
  (:import-from #:cl-cc/type-test-support #:internal-symbol)
  (:import-from #:cl-cc/type/advanced-metadata
                #:make-type-advanced #:type-advanced-valid-p))
