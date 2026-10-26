(defpackage :cl-cc/type/unification
  (:use #:cl)
  (:intern #:register-constraint-resolver)
  (:import-from #:cl-cc/type/type-model
    #:fresh-type-var #:kind-equal-p #:type-advanced-feature-id
    #:make-type-app #:make-type-arrow-raw #:make-type-capability
    #:make-type-constraint #:make-type-effect-op #:make-type-effect-row
    #:make-type-env #:make-type-exists #:make-type-forall #:make-type-handler
    #:make-type-intersection #:make-type-intersection-raw #:make-type-lambda
    #:make-type-linear #:make-type-mu #:make-type-product #:make-type-qualified
    #:make-type-record #:make-type-refinement #:make-type-scheme
    #:make-type-union #:make-type-union-raw #:make-type-variant
    #:type-advanced #:type-advanced-args #:type-advanced-evidence
    #:type-advanced-name #:type-advanced-p #:type-advanced-payload-map
    #:type-advanced-properties #:type-app #:type-app-arg #:type-app-fun
    #:type-arrow #:type-arrow-effects #:type-arrow-mult #:type-arrow-p
    #:type-arrow-params #:type-arrow-return #:type-bound-var
    #:type-capability #:type-capability-base #:type-capability-cap
    #:type-children #:type-constraint #:type-constraint-class-name
    #:type-constraint-type-arg #:type-constructor #:type-constructor-args #:type-constructor-name
    #:type-effect-op #:type-effect-op-args #:type-effect-op-name
    #:type-effect-op-p #:type-effect-row #:type-effect-row-effects
    #:type-effect-row-p #:type-effect-row-row-var #:type-env-bindings #:type-env-dict-bindings
    #:type-env-empty #:type-env-free-vars #:type-equal-p #:type-error-p #:type-inference-error
    #:type-exists #:type-exists-body #:type-exists-knd #:type-exists-var
    #:type-forall #:type-forall-body #:type-forall-knd #:type-forall-var
    #:type-free-vars #:type-handler #:type-handler-effect #:type-handler-input
    #:type-handler-output #:type-intersection #:type-intersection-p
    #:type-intersection-types #:type-lambda #:type-lambda-body #:type-lambda-knd
    #:type-lambda-var #:type-linear #:type-linear-base #:type-linear-grade
    #:type-mu #:type-mu-body #:type-mu-var #:type-node #:type-node-p #:type-primitive-name
    #:type-primitive-p #:type-product #:type-product-elems #:type-product-p
    #:type-qualified #:type-qualified-body #:type-qualified-constraints
    #:type-record #:type-record-fields #:type-record-p #:type-record-row-var
    #:type-refinement #:type-refinement-base #:type-refinement-p
    #:type-refinement-predicate #:type-rigid #:type-scheme-p
    #:type-scheme-quantified-vars #:type-scheme-type #:type-union
    #:type-union-constructor-name #:type-union-p #:type-union-types
    #:type-unknown-p #:type-var #:type-var-equal-p #:type-var-id
    #:type-var-link #:type-var-lower-bound #:type-var-name #:type-var-p
    #:type-var-upper-bound #:type-variant #:type-variant-cases
    #:type-variant-p #:type-variant-row-var)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:import-from #:cl-cc/type/subtyping #:is-subtype-p)
  (:import-from #:cl-cc/type/rows #:row-closed-p #:row-select)
  (:import-from #:cl-cc/type/effects #:effect-row-member-p #:effect-row-subset-p)
  (:import-from #:cl-cc/type/quantities #:mult-leq)
  (:import-from #:cl-cc/type/advanced-metadata #:make-type-advanced)
  (:export
    #:substitution #:substitution-p #:make-substitution
    #:substitution-bindings #:substitution-generation
    #:subst-lookup #:subst-extend #:subst-extend! #:subst-compose
    #:generalize #:instantiate #:normalize-type-variables
    #:zonk #:zonk-env #:type-occurs-p #:apply-unification
    #:constraint #:constraint-p #:constraint-kind #:constraint-args
    #:make-equal-constraint #:make-subtype-constraint
    #:make-typeclass-constraint #:make-implication-constraint
    #:make-effect-subset-constraint #:make-mult-leq-constraint
    #:make-row-lacks-constraint #:make-kind-equal-constraint
    #:constraint-free-vars #:constraint-substitute
    #:type-unify #:type-unify-lists #:solve-constraints))


