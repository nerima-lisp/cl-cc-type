(defpackage #:cl-cc/type/unification/test
 (:use #:cl #:cl-weave)
 (:shadowing-import-from #:cl-weave #:describe)
 (:import-from #:cl-cc/type/quantities #:mult-leq)
 (:import-from #:cl-cc/type/syntax #:parse-type-specifier)
 (:import-from #:cl-cc/type/type-model
  #:%make-type-advanced #:%make-type-var #:+io-effect-row+ #:+kind-effect+
  #:+kind-type+ #:+pure-effect-row+ #:+type-unknown+ #:fresh-type-var
  #:make-type-app #:make-type-arrow #:make-type-arrow-raw
  #:make-type-union-raw #:make-type-capability #:make-type-constraint #:make-type-constructor
  #:make-type-effect-op #:make-type-effect-row #:make-type-env #:make-type-error
  #:make-type-exists #:make-type-forall #:make-type-handler #:make-type-intersection
  #:make-type-lambda #:make-type-linear #:make-type-mu #:make-type-primitive
  #:make-type-product #:make-type-qualified #:make-type-record #:make-type-refinement
  #:make-type-scheme #:make-type-union #:make-type-variant #:type-advanced-args
  #:type-advanced-evidence #:type-advanced-p #:type-advanced-properties #:type-any
  #:type-app-arg #:type-app-fun #:type-app-p #:type-arrow #:type-arrow-effects
  #:type-arrow-p #:type-arrow-params #:type-arrow-return #:type-bool
  #:type-capability-base #:type-capability-cap #:type-capability-p
  #:type-constraint-class-name #:type-constraint-p #:type-constraint-type-arg
  #:type-effect-op-args #:type-effect-op-name #:type-effect-op-p
  #:type-effect-row-effects #:type-effect-row-p #:type-env-bindings #:type-env-empty
  #:type-env-extend #:type-equal-p #:type-exists-body #:type-exists-p
  #:type-forall-body #:type-forall-p #:type-handler-input #:type-handler-output
  #:type-handler-p #:type-inference-error #:type-int #:type-intersection-p
  #:type-intersection-types #:type-lambda-body #:type-lambda-p #:type-linear-base
  #:type-linear-grade #:type-linear-p #:type-mu-body #:type-mu-p #:type-primitive-name
  #:type-primitive-p #:type-product-elems #:type-product-p #:type-qualified-body
  #:type-qualified-constraints #:type-qualified-p #:type-refinement-base
  #:type-refinement-p #:type-refinement-predicate #:type-scheme-quantified-vars
  #:type-string #:type-to-scheme #:type-union-p #:type-union-types #:type-var
  #:type-var-equal-p #:type-var-link #:type-var-lower-bound #:type-var-p
  #:type-var-upper-bound #:type-variant-cases #:type-variant-p #:type-variant-row-var)
 (:import-from #:cl-cc/type/unification
  #:%nv-canonical #:%nv-norm #:apply-unification #:constraint-args #:constraint-free-vars
  #:constraint-kind #:constraint-p #:constraint-substitute #:generalize #:instantiate
  #:make-effect-subset-constraint #:make-equal-constraint #:make-implication-constraint
  #:make-kind-equal-constraint #:make-mult-leq-constraint #:make-row-lacks-constraint
  #:make-substitution #:make-subtype-constraint #:make-typeclass-constraint
  #:solve-constraints #:subst-compose #:subst-extend #:subst-extend! #:subst-lookup
  #:substitution-bindings #:substitution-generation #:substitution-p #:type-occurs-p
  #:type-unify #:type-unify-lists #:normalize-type-variables #:zonk #:zonk-env))