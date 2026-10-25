(defpackage #:cl-cc/type/subtyping/test
 (:use #:cl #:cl-weave)
 (:shadowing-import-from #:cl-weave #:describe)
 (:import-from #:cl-cc/type/subtyping
  #:%primitive-class-record-type #:*class-method-type-registry* #:*class-type-registry*
  #:*protocol-type-registry* #:*subtype-table* #:find-common-supertype #:is-subtype-p
  #:lookup-class-method-types #:lookup-class-type #:lookup-protocol-type
  #:register-class-method-type #:register-class-type
  #:type-join #:type-meet #:type-name-subtype-p)
 (:import-from #:cl-cc/type/type-model
  #:+type-unknown+ #:fresh-type-var #:make-type-arrow #:make-type-constructor
  #:make-type-effect-op #:make-type-effect-row #:make-type-intersection
  #:make-type-primitive
  #:%make-type-advanced #:make-type-record #:make-type-refinement #:make-type-union
  #:make-type-variant #:type-any #:type-bool #:type-int #:type-intersection-p
  #:type-intersection-types #:type-null #:type-primitive-name #:type-primitive-p
  #:type-string #:type-union-p #:type-union-types #:type-unknown-p))