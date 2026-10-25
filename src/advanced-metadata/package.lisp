(defpackage :cl-cc/type/advanced-metadata
  (:use #:cl)
  (:intern #:%type-advanced-invalid #:%type-advanced-require-min-args #:%type-advanced-require-arg-count)
  (:import-from #:cl-cc/type/type-model #:type-node #:type-primitive-name #:type-primitive-p #:type-advanced #:type-advanced-p #:type-advanced-name #:type-advanced-feature-id #:type-advanced-args #:type-advanced-properties #:type-advanced-evidence #:type-advanced-property #:type-advanced-property-present-p #:%make-type-advanced #:%type-advanced-normalize-properties #:%type-advanced-normalize-symbol-keyword #:type-equal-p #:type-advanced-payload-equal-p)
  (:import-from #:cl-cc/type/syntax #:type-to-string)
  (:import-from #:cl-cc/type/registries #:lookup-smt-solver #:lookup-type-synthesis-strategy)
  (:export #:*type-advanced-feature-registry*
           #:+type-advanced-feature-specs+
           #:canonicalize-type-advanced-feature-id
           #:list-type-advanced-feature-ids
           #:list-type-advanced-features
           #:lookup-type-advanced-feature
           #:make-type-advanced
           #:make-type-advanced-feature
           #:make-type-dynamic
           #:make-type-type-rep
           #:register-type-advanced-feature
           #:register-type-advanced-normalizer
           #:register-type-advanced-validator
           #:type-advanced-feature
           #:type-advanced-feature-fr-id
           #:type-advanced-feature-heads
           #:type-advanced-feature-id
           #:type-advanced-feature-id-for-head
           #:type-advanced-feature-p
           #:type-advanced-feature-title
           #:type-advanced-head-p
           #:type-advanced-semantics-implemented-p
           #:type-advanced-valid-p
           #:validate-type-advanced)
)
