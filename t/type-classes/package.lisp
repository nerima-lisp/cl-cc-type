(defpackage #:cl-cc/type/type-classes/test
 (:use #:cl #:cl-weave)
 (:shadowing-import-from #:cl-weave #:describe)
 (:import-from #:cl-cc/type/type-classes
  #:%existing-class-instances #:%typeclass-instance-args #:%typeclass-instance-overlaps-p
  #:%typeclass-name-string #:%typeclass-param-name #:*typeclass-instance-registry*
  #:*typeclass-registry* #:check-typeclass-constraint #:default-numeric-typeclass-p
  #:dict-env-extend #:dict-env-lookup #:has-typeclass-instance-p #:lookup-typeclass
  #:lookup-typeclass-instance #:make-typeclass-def #:register-typeclass
  #:register-typeclass-instance #:typeclass-def-methods #:typeclass-def-name
  #:typeclass-def-p #:typeclass-def-superclasses #:typeclass-def-type-params
  #:typeclass-instance-class-name #:typeclass-instance-methods #:typeclass-instance-p)
 (:import-from #:cl-cc/type/type-model #:make-type-error #:+type-unknown+ #:fresh-type-var #:make-type-arrow #:make-type-product
  #:reset-type-vars! #:type-any #:type-bool #:type-char #:type-env-empty
  #:type-inference-error #:type-int #:type-string)
 (:import-from #:cl-cc/type/unification #:make-substitution #:make-typeclass-constraint #:solve-constraints))