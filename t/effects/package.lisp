(defpackage #:cl-cc/type/effects/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/effects
    #:*effect-registry* #:effect-def-name #:effect-def-operations #:effect-def-p
    #:effect-row-extend #:effect-row-member-p #:effect-row-restrict
    #:effect-row-subset-p #:effect-row-union #:lookup-effect #:make-effect-def
    #:register-effect)
  (:import-from #:cl-cc/type/type-model
    #:+io-effect-row+ #:+pure-effect-row+ #:fresh-type-var #:make-type-arrow
    #:make-type-effect-op #:make-type-effect-row #:make-type-handler #:reset-type-vars!
    #:type-effect-op-name #:type-effect-row-effects #:type-effect-row-p
    #:type-effect-row-row-var #:type-env-empty #:type-int #:type-string #:type-var-p)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:import-from #:cl-cc/parse #:lower-sexp-to-ast)
  (:import-from #:cl-cc/type-test-support #:internal-function))
