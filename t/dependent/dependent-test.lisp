;;;; t/types-extended-dependent-test.lisp — CIC and Proof-Carrying-Code Tests
;;;;
;;;; Tests for src/dependent/types-extended-dependent.lisp:
;;;; CIC universe sorts, propositions, and proof erasure; termination evidence
;;;; and proof-carrying-code obligation verification.

(in-package #:cl-cc/type/dependent/test)

(it-sequential "cic-scaffolding-validates-universes-and-proof-erasure"
  (let* ((prop (make-universe-sort :prop))
         (type0 (make-universe-sort :type 0))
         (proposition (make-cic-proposition 'non-zero prop '(d)))
         (proof (make-cic-proof proposition 'witness)))
    (expect (valid-universe-sort-p prop) :to-be-truthy)
    (expect (universe<= prop type0) :to-be-truthy)
    (expect (cic-large-elimination-allowed-p prop type0) :to-be-falsy)
    (expect (cic-proof-valid-p proof) :to-be-truthy)
    (expect (proof-erasable-p proof) :to-be-truthy)))

(it-sequential "termination-and-pcc-evidence-check-real-obligations"
  (let* ((termination (make-termination-evidence :structural '(5 4 3 2 1)))
         (obligation (make-nonzero-obligation 'non-zero-denominator))
         (evidence (make-proof-evidence 'non-zero-denominator 2))
         (bundle (make-proof-carrying-code 'safe-div (list obligation) (list evidence))))
    (expect (termination-evidence-valid-p termination) :to-be-truthy)
    (expect (verify-proof-obligation obligation 2) :to-be-truthy)
    (expect (verify-proof-evidence obligation evidence) :to-be-truthy)
    (expect (verify-proof-carrying-code bundle) :to-be-truthy)
    (expect
     (verify-proof-carrying-code
      (make-proof-carrying-code
       'unsafe-div
       (list obligation)
       (list (make-proof-evidence 'non-zero-denominator 0))))
     :to-be-falsy)
    ;; MAKE-NONZERO-OBLIGATION's checker's (AND (NUMBERP payload) ...) had
    ;; only ever been called with numeric payloads (2 and 0 above); a
    ;; non-numeric payload closes NUMBERP's own false branch.
    (expect (verify-proof-obligation obligation "not-a-number") :to-be-falsy)))

;;; ── make-universe-sort / valid-universe-sort-p / max-universe ───────────

(it-sequential "make-universe-sort-signals-error-for-unknown-kind-and-invalid-type-level"
  (signals error (make-universe-sort :bogus))
  (signals error (make-universe-sort :type -1))
  (signals error (make-universe-sort :type "not-an-integer")))

(it-sequential "make-universe-sort-normalizes-non-keyword-kind-symbols"
  (let ((set (make-universe-sort 'set))
        (prop (make-universe-sort 'prop 0)))
    (expect (universe-sort-kind set) :to-be :set)
    (expect (universe-sort-level set) :to-equal 0)
    (expect (valid-universe-sort-p set) :to-be-truthy)
    (expect (universe-sort-kind prop) :to-be :prop)))

(it-sequential "valid-universe-sort-p-rejects-non-struct-and-malformed-universes"
  (expect (valid-universe-sort-p 42) :to-be-falsy)
  (expect (valid-universe-sort-p nil) :to-be-falsy)
  (expect (valid-universe-sort-p
           (funcall (internal-function "cl-cc/type/dependent" "%MAKE-UNIVERSE-SORT") :kind :bogus :level 0))
          :to-be-falsy)
  (expect (valid-universe-sort-p
           (funcall (internal-function "cl-cc/type/dependent" "%MAKE-UNIVERSE-SORT") :kind :type :level -1))
          :to-be-falsy)
  (expect (valid-universe-sort-p
           (funcall (internal-function "cl-cc/type/dependent" "%MAKE-UNIVERSE-SORT") :kind :type :level "zero"))
          :to-be-falsy))

(it-sequential "valid-universe-sort-p-accepts-a-well-formed-type-level-universe"
  ;; Every pre-existing VALID-UNIVERSE-SORT-P call on a :TYPE-kinded
  ;; universe passes a negative level (rejected before the level check's
  ;; own true side is reached); this closes the (NOT (MINUSP level)) arm
  ;; that actually returns T.
  (expect (valid-universe-sort-p (make-universe-sort :type 0))
          :to-be-truthy))

(it-sequential "max-universe-returns-the-higher-ranked-of-two-universes"
  (let ((prop (make-universe-sort :prop))
        (set (make-universe-sort :set))
        (type1 (make-universe-sort :type 1)))
    (expect (max-universe prop set) :to-be set)
    (expect (max-universe set prop) :to-be set)
    (expect (max-universe set type1) :to-be type1)))

;;; ── cic-large-elimination-allowed-p / make-cic-proposition ───────────────

(it-sequential "cic-large-elimination-allowed-p-permits-non-prop-source-and-prop-target"
  (let ((prop (make-universe-sort :prop))
        (set (make-universe-sort :set))
        (type0 (make-universe-sort :type 0)))
    (expect (cic-large-elimination-allowed-p set type0) :to-be-truthy)
    (expect (cic-large-elimination-allowed-p prop prop) :to-be-truthy)))

(it-sequential "make-cic-proposition-signals-error-for-invalid-universe"
  (signals error (make-cic-proposition 'bad-prop "not-a-universe")))

;;; ── cic-proof-valid-p / proof-erasable-p ─────────────────────────────────

(it-sequential "cic-proof-valid-p-rejects-non-proof-non-prop-and-nil-witness"
  (let* ((set (make-universe-sort :set))
         (prop (make-universe-sort :prop))
         (set-proposition (make-cic-proposition 'in-set set))
         (prop-proposition (make-cic-proposition 'in-prop prop))
         (nil-witness-proof (make-cic-proof prop-proposition nil))
         (set-proof (make-cic-proof set-proposition 'witness))
         (bad-proposition-proof (make-cic-proof "not-a-proposition" 'witness)))
    (expect (cic-proof-valid-p "not-a-proof") :to-be-falsy)
    (expect (cic-proof-valid-p nil-witness-proof) :to-be-falsy)
    (expect (cic-proof-valid-p set-proof) :to-be-falsy)
    (expect (cic-proof-valid-p bad-proposition-proof) :to-be-falsy)
    (expect (proof-erasable-p set-proof) :to-be-falsy)))

;;; ── make-cic-inductive / list-argument copying ───────────────────────────

(it-sequential "make-cic-inductive-and-make-cic-proof-copy-their-list-arguments"
  (let* ((type0 (make-universe-sort :type 0))
         (ctors (list 'zero 'succ))
         (inductive (make-cic-inductive 'nat type0 ctors))
         (prop (make-universe-sort :prop))
         (proposition (make-cic-proposition 'p prop))
         (premises (list 'p1 'p2))
         (proof (make-cic-proof proposition 'w premises)))
    (expect (cic-inductive-p inductive) :to-be-truthy)
    (expect (cic-inductive-name inductive) :to-be 'nat)
    (expect (cic-inductive-universe inductive) :to-be type0)
    (expect (cic-inductive-constructors inductive) :to-equal ctors)
    (expect (eq (cic-inductive-constructors inductive) ctors) :to-be-falsy)
    (expect (cic-proof-premises proof) :to-equal premises)
    (expect (eq (cic-proof-premises proof) premises) :to-be-falsy)))

;;; ── structural-decrease-p / lexicographic-decrease-p ─────────────────────

(it-sequential "structural-decrease-p-and-lexicographic-decrease-p-cover-measure-kinds"
  (expect (structural-decrease-p 5 3) :to-be-truthy)
  (expect (structural-decrease-p 3 5) :to-be-falsy)
  (expect (structural-decrease-p "hello" "hi") :to-be-truthy)
  (expect (structural-decrease-p #(1 2 3) #(1)) :to-be-truthy)
  (expect (structural-decrease-p '(1 2 3) '(1)) :to-be-truthy)
  (expect (structural-decrease-p 'sym 3) :to-be-falsy)
  (expect (lexicographic-decrease-p '(1 2) '(1)) :to-be-falsy)
  (expect (lexicographic-decrease-p '(1 2 3) '(1 2 3)) :to-be-falsy)
  (expect (lexicographic-decrease-p '(3 5) '(3 2)) :to-be-truthy)
  (expect (lexicographic-decrease-p '(1 5) '(2 1)) :to-be-falsy))

;;; ── termination-evidence-valid-p / termination-evidence-form-valid-p ─────

(it-sequential "termination-evidence-valid-p-rejects-non-evidence-partial-and-unknown-strategy"
  (expect (termination-evidence-valid-p "not-evidence") :to-be-falsy)
  (expect (termination-evidence-valid-p
           (make-termination-evidence :structural '(5 4 3) :partial-p t))
          :to-be-falsy)
  (expect (termination-evidence-valid-p
           (make-termination-evidence :unknown-strategy '(5 4 3)))
          :to-be-falsy)
  (expect (termination-evidence-valid-p
           (make-termination-evidence :structural '(1 2 3)))
          :to-be-falsy))

(it-sequential "termination-evidence-valid-p-checks-lexicographic-measure-sequences"
  (expect (termination-evidence-valid-p
           (make-termination-evidence :lexicographic '((3 5) (3 2) (1 9))))
          :to-be-truthy)
  (expect (termination-evidence-valid-p
           (make-termination-evidence :lexicographic '((1 5) (2 3))))
          :to-be-falsy))

(it-sequential "termination-evidence-form-valid-p-accepts-keyword-and-symbol-forms"
  (expect (termination-evidence-form-valid-p '(:termination :structural (5 4 3)))
          :to-be-truthy)
  (expect (termination-evidence-form-valid-p '(termination lexicographic (5 4)))
          :to-be-truthy)
  (expect (termination-evidence-form-valid-p 42) :to-be-falsy)
  (expect (termination-evidence-form-valid-p '(:bogus :structural (1)))
          :to-be-falsy)
  (expect (termination-evidence-form-valid-p '(:termination :bogus-strategy (1)))
          :to-be-falsy)
  (expect (termination-evidence-form-valid-p '(:termination :structural))
          :to-be-falsy)
  ;; Distinct from the :BOGUS-head case above (a keyword that fails the
  ;; name comparison): a HEAD that is not a symbol at all fails the
  ;; SYMBOLP conjunct itself, not just the name match.
  (expect (termination-evidence-form-valid-p '(42 :structural (1)))
          :to-be-falsy)
  ;; Mirrors the HEAD case above but for STRATEGY: :BOGUS-STRATEGY is a
  ;; symbol that fails the name-list MEMBER check, still reaching (and
  ;; failing) the string-based SYMBOLP conjunct's own true side; a
  ;; strategy that is not a symbol at all fails that conjunct itself.
  (expect (termination-evidence-form-valid-p '(:termination 42 (1)))
          :to-be-falsy))

;;; ── proof-evidence-form-valid-p ───────────────────────────────────────────

(it-sequential "proof-evidence-form-valid-p-accepts-keyword-and-symbol-heads"
  (expect (proof-evidence-form-valid-p '(:proof witness-x)) :to-be-truthy)
  (expect (proof-evidence-form-valid-p '(assumption foo)) :to-be-truthy)
  (expect (proof-evidence-form-valid-p '(:refl)) :to-be-falsy)
  (expect (proof-evidence-form-valid-p '(:bogus x)) :to-be-falsy)
  (expect (proof-evidence-form-valid-p 42) :to-be-falsy)
  ;; Distinct from (:BOGUS X) above: a HEAD that is not a symbol at all
  ;; fails the SYMBOLP conjunct itself, not just the name comparison.
  (expect (proof-evidence-form-valid-p '(42 x)) :to-be-falsy))

;;; ── make-type-obligation / verify-proof-obligation / verify-proof-evidence

(it-sequential "make-type-obligation-verifies-payload-against-expected-type"
  (let ((obligation (make-type-obligation 'must-be-integer 'integer)))
    (expect (verify-proof-obligation obligation 42) :to-be-truthy)
    (expect (verify-proof-obligation obligation "not-an-integer") :to-be-falsy)
    (expect (proof-obligation-description obligation)
            :to-equal "Payload must satisfy INTEGER")))

(it-sequential "verify-proof-obligation-rejects-non-obligations-and-non-function-checkers"
  (expect (verify-proof-obligation "not-an-obligation" 5) :to-be-falsy)
  (expect (verify-proof-obligation
           (make-proof-obligation 'broken "not-a-function")
           5)
          :to-be-falsy))

(it-sequential "verify-proof-evidence-rejects-name-mismatch-non-evidence-and-non-obligation"
  (let* ((obligation (make-nonzero-obligation 'denom))
         (mismatched-evidence (make-proof-evidence 'wrong-name 5)))
    (expect (verify-proof-evidence obligation mismatched-evidence) :to-be-falsy)
    (expect (verify-proof-evidence obligation "not-evidence") :to-be-falsy)
    (expect (verify-proof-evidence
             "not-obligation"
             (make-proof-evidence 'denom 5))
            :to-be-falsy)))

;;; ── verify-proof-carrying-code / make-proof-carrying-code list copying ───

(it-sequential "verify-proof-carrying-code-rejects-non-bundles-and-missing-evidence"
  (let* ((obligation (make-nonzero-obligation 'denom))
         (obligations (list obligation))
         (bundle (make-proof-carrying-code 'artifact obligations nil)))
    (expect (verify-proof-carrying-code "not-a-bundle") :to-be-falsy)
    (expect (verify-proof-carrying-code bundle) :to-be-falsy)
    (expect (proof-carrying-code-obligations bundle) :to-equal obligations)
    (expect (eq (proof-carrying-code-obligations bundle) obligations)
            :to-be-falsy)))

