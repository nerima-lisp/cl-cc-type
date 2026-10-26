(defpackage #:cl-cc/type/inference/test
 (:use #:cl #:cl-weave)
 (:shadowing-import-from #:cl-weave #:describe)
 (:import-from #:cl-cc/type/actors #:actor-ref #:make-actor-ref)
 (:import-from #:cl-cc/type/channels #:channel #:make-buffered-channel #:make-channel-type #:make-typed-channel)
 (:import-from #:cl-cc/type/coroutines #:coroutine #:generator #:make-coroutine-type #:make-generator-type)
 (:import-from #:cl-cc/type/effects #:effect-row-subset-p)
 (:import-from #:cl-cc/type/inference
  #:%advanced-call-apply-mapped-transform #:%advanced-call-parse-type-form
  #:%advanced-call-same-symbol-name-p #:%advanced-call-symbol-keyword
  #:%advanced-call-type-arg #:%advanced-call-type-designator
  #:%advanced-call-type-head-name #:%find-fn-type-declaration
  #:%infer-effects-union #:%make-advanced-call-policy-from-spec
  #:%make-lambda-param-env #:%narrow-else-env #:%typed-hole-message
  #:*constant-effect-table* #:*type-predicate-table* #:annotate-type
  #:check-body-effects #:check-qualified-constraints #:collect-constraints
  #:extract-type-guard #:format-type #:infer #:infer-args #:infer-body
  #:infer-effects #:infer-with-constraints #:infer-with-effects #:infer-with-env
  #:lookup-advanced-call-policy #:narrow-union-type #:register-advanced-call-policy
  #:register-type-predicate #:register-effect-signature #:lookup-effect-signature
  #:syntactic-value-p #:type-predicate-to-type)
 (:import-from #:cl-cc/type/registries
  #:lookup-type-alias #:lookup-type-interface-export #:register-smt-solver
  #:register-type-alias #:register-type-checker-plugin #:register-type-synthesis-strategy)
 (:import-from #:cl-cc/type/routing #:make-api-type)
 (:import-from #:cl-cc/type/simd #:make-simd-type #:simd-vector)
 (:import-from #:cl-cc/type/stm #:make-tvar #:stm)
 (:import-from #:cl-cc/type/subtyping
  #:lookup-class-method-type #:lookup-class-method-types #:lookup-class-type
  #:lookup-slot-type #:register-class-method-type #:register-class-type)
 (:import-from #:cl-cc/type/type-classes
  #:*typeclass-instance-registry* #:dict-env-extend #:register-typeclass-instance)
 (:import-from #:cl-cc/type/type-lowering #:register-type-interface)
 (:import-from #:cl-cc/type/type-model
  #:+io-effect-row+ #:+pure-effect-row+ #:+type-unknown+ #:fresh-rigid-var
  #:fresh-type-var #:make-type-arrow #:make-type-arrow-raw #:make-type-constraint #:make-type-constructor
  #:make-type-effect-op #:make-type-effect-row #:make-type-forall #:make-type-primitive
  #:make-type-product #:make-type-qualified #:make-type-record #:make-type-scheme
  #:make-type-union #:make-type-variant #:reset-type-vars! #:type-advanced-feature-id
  #:type-advanced-name #:type-advanced-p #:type-any #:type-arrow #:type-arrow-p
  #:type-arrow-params #:type-arrow-return #:type-bool #:type-capability-cap
  #:type-capability-p #:type-char #:type-cons #:type-effect-op-name #:type-effect-row-effects
  #:type-effect-row-p #:type-effect-row-row-var #:type-env-empty #:type-env-extend
  #:type-env-lookup #:type-env-p #:type-equal-p #:type-inference-error
  #:type-inference-error-message #:type-int #:type-mismatch-error
  #:type-mismatch-error-actual #:type-mismatch-error-expected #:type-null
  #:type-float #:type-primitive-name #:type-primitive-p #:type-record-fields
  #:type-record-p #:type-refinement-base #:type-refinement-p
  #:type-scheme #:type-scheme-quantified-vars #:type-scheme-type #:type-string #:type-symbol
  #:type-to-scheme #:type-union-p #:type-union-types #:type-unknown-p #:type-var
  #:type-var-equal-p #:type-var-p #:type-variant-cases #:typed-hole-error
  #:unbound-variable-error #:unbound-variable-error-name)
 (:import-from #:cl-cc/type/unification #:make-substitution #:constraint-kind #:subst-extend #:generalize #:instantiate))