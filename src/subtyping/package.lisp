(defpackage :cl-cc/type/subtyping
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
    #:make-type-intersection #:make-type-primitive #:make-type-record
    #:make-type-union #:type-advanced #:type-advanced-args #:type-advanced-feature-id #:type-advanced-p
    #:type-advanced-payload-equal-p #:type-any #:type-arrow
    #:type-arrow-effects #:type-arrow-mult #:type-arrow-p #:type-arrow-params
    #:type-arrow-return #:type-constructor #:type-constructor-args
    #:type-constructor-name #:type-constructor-p #:type-effect-row
    #:type-equal-p #:type-intersection #:type-intersection-types
    #:type-primitive #:type-primitive-name #:type-primitive-p
    #:type-record #:type-record-fields #:type-refinement
    #:type-refinement-base #:type-union #:type-union-types #:type-unknown-p
    #:type-node #:type-variant #:type-variant-cases)
  (:import-from #:cl-cc/type/effects #:effect-row-subset-p)
  (:import-from #:cl-cc/type/registries #:define-registry)
  (:import-from #:cl-cc/type/security-labels
    #:type-advanced-security-label<= #:%type-advanced-payload-security-label)
  (:export
    #:is-subtype-p #:type-join #:type-meet #:*subtype-table*
    #:type-name-subtype-p #:find-common-supertype
    #:*protocol-type-registry* #:register-protocol-type #:lookup-protocol-type
    #:*class-type-registry* #:register-class-type #:lookup-class-type
    #:lookup-slot-type #:*class-method-type-registry*
    #:register-class-method-type #:lookup-class-method-types
    #:lookup-class-method-type))


