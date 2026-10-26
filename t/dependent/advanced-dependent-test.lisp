(in-package #:cl-cc/type/dependent/test)

(it-sequential "advanced-validate-proof-like-rejects-malformed-totality-evidence"
  (signals error
      (make-type-advanced :feature-id "FR-1901"
                          :name 'advanced
                          :args (list 'recursive-length)
                          :evidence '(mystery proof))))

(it-sequential "advanced-validate-proof-like-accepts-well-formed-termination-and-curry-howard-evidence"
  (let ((node (make-type-advanced :feature-id "FR-1901" :name 'advanced :args (list 'recursive-length) :evidence '(termination :structural 5 3 1))))
    (expect (type-advanced-valid-p node) :to-be-truthy))
  (let ((node (make-type-advanced :feature-id "FR-2001" :name 'advanced :args (list 'my-lemma) :evidence '(proof my-lemma-witness))))
    (expect (type-advanced-valid-p node) :to-be-truthy)))

(it-sequential "advanced-validate-proof-like-rejects-malformed-curry-howard-proof-evidence"
  (signals error
      (make-type-advanced :feature-id "FR-2001" :name 'advanced :args (list 'my-lemma) :evidence '(nonsense x))))

