(defpackage #:cl-cc/type/dependent/test
  (:use #:cl #:cl-weave)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-cc/type/dependent
                #:cic-inductive-constructors #:cic-inductive-name
                #:cic-inductive-p #:cic-inductive-universe
                #:cic-large-elimination-allowed-p #:cic-proof-premises
                #:cic-proof-valid-p #:lexicographic-decrease-p
                #:make-cic-inductive #:make-cic-proof #:make-cic-proposition
                #:make-nonzero-obligation #:make-proof-carrying-code
                #:make-proof-evidence #:make-proof-obligation
                #:make-termination-evidence #:make-type-obligation
                #:make-universe-sort #:max-universe
                #:proof-carrying-code-obligations #:proof-erasable-p
                #:proof-evidence-form-valid-p #:proof-obligation-description
                #:structural-decrease-p #:termination-evidence-form-valid-p
                #:termination-evidence-valid-p #:universe-sort-kind
                #:universe-sort-level #:universe<= #:valid-universe-sort-p
                #:verify-proof-carrying-code #:verify-proof-evidence
                #:verify-proof-obligation)
  (:import-from #:cl-cc/type/advanced-metadata
                #:make-type-advanced #:type-advanced-valid-p)
  (:import-from #:cl-cc/type-test-support #:internal-function))
