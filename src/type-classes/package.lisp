(defpackage :cl-cc/type/type-classes
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
    #:make-type-env #:type-env-bindings #:type-env-dict-bindings #:type-equal-p #:type-error-p
    #:type-inference-error #:type-int #:type-product-elems #:type-product-p #:type-unknown-p
    #:type-var-name #:type-var-p)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:import-from #:cl-cc/type/unification
    #:constraint-args #:register-constraint-resolver #:type-unify #:zonk)
  (:export
    #:typeclass-def #:typeclass-def-p #:make-typeclass-def
    #:typeclass-def-name #:typeclass-def-type-params #:typeclass-def-superclasses
    #:typeclass-def-methods #:typeclass-def-defaults #:typeclass-def-associated-types
    #:*typeclass-registry* #:register-typeclass #:lookup-typeclass
    #:typeclass-instance #:typeclass-instance-p
    #:typeclass-instance-class-name #:typeclass-instance-methods
    #:*typeclass-instance-registry* #:register-typeclass-instance
    #:lookup-typeclass-instance #:has-typeclass-instance-p
    #:check-typeclass-constraint #:dict-env-extend #:dict-env-lookup))

