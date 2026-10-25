(defpackage :cl-cc/type/dependent
  (:use #:cl)
  (:import-from #:cl-cc/type/type-model
   #:type-advanced-feature-id #:type-advanced-evidence)
  (:import-from #:cl-cc/type/advanced-metadata
   #:register-type-advanced-validator
   #:%type-advanced-invalid
   #:%type-advanced-require-min-args)
  (:export
   #:universe-sort #:universe-sort-p #:universe-sort-kind #:universe-sort-level
   #:make-universe-sort #:valid-universe-sort-p #:universe<= #:max-universe
   #:cic-proposition #:cic-proposition-p #:cic-proposition-name
   #:cic-proposition-universe #:cic-proposition-payload #:make-cic-proposition
   #:cic-proof #:cic-proof-p #:cic-proof-proposition #:cic-proof-witness
   #:cic-proof-premises #:make-cic-proof #:cic-proof-valid-p #:proof-erasable-p
   #:cic-inductive #:cic-inductive-p #:cic-inductive-name #:cic-inductive-universe
   #:cic-inductive-constructors #:make-cic-inductive
   #:cic-large-elimination-allowed-p
   #:termination-evidence #:termination-evidence-p #:termination-evidence-strategy
   #:termination-evidence-measures #:termination-evidence-partial-p
   #:make-termination-evidence #:structural-decrease-p #:lexicographic-decrease-p
   #:termination-evidence-valid-p #:termination-evidence-form-valid-p
   #:proof-obligation #:proof-obligation-p #:proof-obligation-name
   #:proof-obligation-checker #:proof-obligation-description #:make-proof-obligation
   #:proof-evidence #:proof-evidence-p #:proof-evidence-obligation-name
   #:proof-evidence-payload #:make-proof-evidence
   #:proof-carrying-code #:proof-carrying-code-p #:proof-carrying-code-artifact
   #:proof-carrying-code-obligations #:proof-carrying-code-evidence
   #:make-proof-carrying-code #:make-nonzero-obligation #:make-type-obligation
   #:verify-proof-obligation #:verify-proof-evidence #:verify-proof-carrying-code
   #:proof-evidence-form-valid-p))
