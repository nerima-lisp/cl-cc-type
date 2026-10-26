(defpackage #:cl-cc/type/checking/test
 (:use #:cl #:cl-weave)
 (:shadowing-import-from #:cl-weave #:describe)
 (:import-from #:cl-cc/type/checking
  #:check #:check-body #:check-skolem-escape #:checker-interface-ready-p
  #:skolem-appears-in-subst-p #:skolem-appears-in-type-p #:synthesize)
 (:import-from #:cl-cc/ast #:make-ast-int)
 (:import-from #:cl-cc/type/type-model #:make-type-arrow-raw #:+type-unknown+ #:fresh-rigid-var #:fresh-type-var #:make-type-arrow
  #:make-type-constructor #:make-type-forall #:make-type-product #:reset-type-vars!
  #:type-arrow #:type-arrow-params #:type-env-empty #:type-inference-error
  #:type-int #:type-mismatch-error #:type-rigid-name #:type-rigid-p #:type-string)
 (:import-from #:cl-cc/type/unification #:make-substitution #:subst-extend))