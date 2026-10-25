(defpackage :cl-cc/type/inference
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
    #:+io-effect-row+ #:+pure-effect-row+ #:+type-unknown+ #:fresh-type-var
    #:make-type-arrow #:make-type-arrow-raw #:make-type-capability
    #:make-type-effect-op #:make-type-effect-row #:make-type-primitive
    #:make-type-record #:make-type-scheme #:make-type-union
    #:type-advanced-name #:type-advanced-p #:type-any #:type-arrow-p
    #:type-arrow-params #:type-bool #:type-char #:type-cons
    #:type-constraint-class-name #:type-constraint-type-arg
    #:type-constructor-args #:type-constructor-name #:type-constructor-p
    #:type-env-bindings #:type-env-empty #:type-env-extend #:type-env-extend*
    #:type-env-lookup #:type-env-p #:type-equal-p #:type-float
    #:type-inference-error #:type-mismatch-error #:typed-hole-error
    #:type-int #:type-node #:type-null #:unbound-variable-error
    #:type-primitive #:type-primitive-name #:type-primitive-p #:type-product-p
    #:type-qualified #:type-qualified-constraints #:type-record-fields #:type-record-p
    #:type-record-row-var #:type-scheme-p #:type-scheme-type #:type-string
    #:type-symbol #:type-to-scheme #:type-union #:type-union-p #:type-union-types
    #:type-unknown-p #:type-var-p #:type-variant-p)
  (:import-from #:cl-cc/type/type-lowering #:register-type-interface)
  (:import-from #:cl-cc/type/utility-types #:non-nullable-type)
  (:import-from #:cl-cc/type/syntax #:parse-type-specifier #:type-to-string)
  (:import-from #:cl-cc/type/registries
    #:define-registry #:lookup-type-interface-export
    #:run-type-checker-plugin #:run-type-synthesis #:solve-smt-constraint)
  (:import-from #:cl-cc/type/unification
    #:constraint #:generalize #:instantiate #:make-equal-constraint
    #:solve-constraints #:subst-compose #:type-unify #:zonk #:zonk-env)
  (:import-from #:cl-cc/type/type-classes
    #:dict-env-lookup #:has-typeclass-instance-p)
  (:import-from #:cl-cc/type/effects #:effect-row-subset-p #:effect-row-union)
  (:import-from #:cl-cc/type/subtyping
    #:is-subtype-p #:lookup-slot-type #:register-class-method-type
    #:register-class-type)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:import-from #:cl-cc/type/channels
    #:make-buffered-channel #:make-channel-type #:make-typed-channel)
  (:import-from #:cl-cc/type/actors #:actor-ref-type #:make-actor-ref)
  (:import-from #:cl-cc/type/coroutines #:make-coroutine-type #:make-generator-type)
  (:import-from #:cl-cc/type/stm #:make-stm-type #:make-tvar)
  (:import-from #:cl-cc/type/simd #:make-simd-type)
  (:import-from #:cl-cc/type/concurrency #:sendable-type-p #:shareable-type-p)
  (:import-from #:cl-cc/type/ffi
    #:ffi-descriptor-from-form #:ffi-descriptor-lisp-type
    #:ffi-function-descriptor-argument-types #:ffi-function-descriptor-p
    #:ffi-function-descriptor-return-type #:ffi-lisp-type-compatible-p)
  (:export
    #:narrow-union-type #:extract-type-guard
    #:infer #:infer-with-env #:infer-with-constraints
    #:infer-binop #:infer-if #:infer-let #:infer-lambda
    #:infer-call #:infer-progn #:infer-args #:annotate-type
    #:collect-constraints #:check-qualified-constraints
    #:*type-predicate-table* #:register-type-predicate #:syntactic-value-p
    #:infer-effects #:infer-with-effects #:check-body-effects
    #:*constant-effect-table* #:*pure-ast-effect-types*
    #:*effect-signature-table* #:register-effect-signature
    #:lookup-effect-signature #:format-type
    #:advanced-call-policy #:advanced-call-policy-p
    #:advanced-call-policy-function-name #:advanced-call-policy-summary
    #:advanced-call-policy-exact-args #:advanced-call-policy-min-args
    #:advanced-call-policy-validator #:advanced-call-policy-return-type
    #:*advanced-call-policy-registry* #:register-advanced-call-policy
    #:lookup-advanced-call-policy #:validate-advanced-call #:infer-advanced-call))


