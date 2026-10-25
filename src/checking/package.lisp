(defpackage :cl-cc/type/checking
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
    #:fresh-rigid-var #:type-arrow #:type-arrow-params #:type-arrow-return
    #:type-constructor #:type-constructor-args #:type-forall
    #:type-forall-body #:type-forall-var #:type-inference-error #:type-mismatch-error
    #:type-product #:type-product-elems
    #:type-rigid #:type-rigid-equal-p #:type-unknown-p #:type-var #:type-var-name)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:import-from #:cl-cc/type/inference #:infer)
  (:import-from #:cl-cc/type/unification
    #:make-substitution #:subst-compose #:subst-extend
    #:substitution-bindings #:substitution-p #:type-unify #:zonk #:zonk-env)
  (:export
    #:synthesize #:check #:check-body
    #:check-skolem-escape #:skolem-appears-in-type-p))

