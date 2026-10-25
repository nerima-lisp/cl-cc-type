(defpackage :cl-cc/type/security-labels
  (:use #:cl)
  (:intern #:%type-advanced-payload-security-label)
  (:import-from #:cl-cc/type/type-model
   #:define-keyword-normalizer
   #:type-advanced-args #:type-advanced-evidence #:type-advanced-property)
  (:import-from #:cl-cc/type/advanced-metadata
   #:register-type-advanced-validator
   #:%type-advanced-invalid
   #:%type-advanced-require-min-args)
  (:export
   #:+security-label-order+ #:normalize-security-label #:security-label-rank
   #:security-label-p #:security-label<= #:join-security-labels #:meet-security-labels
   #:labeled-value #:labeled-value-p #:labeled-value-value #:labeled-value-label
   #:labeled-value-tainted-p #:labeled-value-audit-trail
   #:make-labeled-value #:labeled-value-flow-allowed-p
   #:sanitize-labeled-value #:declassify-labeled-value
   #:type-advanced-security-label<=))
