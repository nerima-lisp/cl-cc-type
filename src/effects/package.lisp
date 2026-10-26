(defpackage :cl-cc/type/effects
  (:use #:cl)
  (:import-from #:cl-cc/type/registries #:define-registry)
  (:import-from #:cl-cc/type/type-model
                #:type-effect-row #:type-effect-row-p #:type-effect-row-effects #:type-effect-row-row-var #:make-type-effect-row
                #:type-effect-op #:type-effect-op-p #:type-effect-op-name #:type-effect-op-args
                #:type-handler #:type-handler-effect #:type-handler-input #:type-handler-output)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:export #:effect-def #:effect-def-name #:effect-def-operations #:effect-def-p #:effect-def-type-params #:effect-row-subset-p #:effect-row-union #:make-effect-def #:effect-row-extend #:effect-row-restrict #:effect-row-member-p #:*effect-registry* #:register-effect #:lookup-effect))
