(defpackage :cl-cc/type/ffi
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
   #:define-simple-condition #:type-system-error #:require-with-detail #:error-with-detail
   #:type-int #:type-float #:type-string #:type-bool #:type-null #:type-char #:type-any
   #:type-node #:make-type-primitive #:make-type-arrow
   #:type-advanced-args)
  (:import-from #:cl-cc/type/advanced-metadata
   #:register-type-advanced-validator
   #:%type-advanced-invalid
   #:%type-advanced-require-min-args)
  (:export
   #:ffi-validation-error #:+ffi-scalar-kinds+
   #:ffi-scalar-type #:ffi-scalar-type-p #:ffi-scalar-type-kind #:make-ffi-scalar-type
   #:ffi-pointer-type #:ffi-pointer-type-p #:ffi-pointer-type-pointee
   #:ffi-pointer-type-borrowed-p #:ffi-pointer-type-nullable-p #:make-ffi-pointer-type
   #:ffi-callback-type #:ffi-callback-type-p #:ffi-callback-type-argument-types
   #:ffi-callback-type-return-type #:make-ffi-callback-type
   #:ffi-function-descriptor #:ffi-function-descriptor-p #:ffi-function-descriptor-name
   #:ffi-function-descriptor-argument-types #:ffi-function-descriptor-return-type
   #:ffi-function-descriptor-abi #:make-ffi-function-descriptor
   #:ffi-type-valid-p #:ffi-lisp-type-compatible-p #:ffi-descriptor-form-valid-p
   #:ffi-descriptor-from-form #:ffi-descriptor-lisp-type))
