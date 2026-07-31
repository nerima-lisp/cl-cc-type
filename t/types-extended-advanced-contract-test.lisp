;;;; t/types-extended-advanced-contract-test.lisp — Advanced Contract Registry Tests
;;;;
;;;; Tests for src/types-extended-advanced-contract.lisp:
;;;; the type-advanced-contract struct/registry, and the incremental-staging,
;;;; optics, test-generation, constraint-analysis, tooling, and TypeScript-style
;;;; encoding contracts it enforces via parse-type-specifier.

(in-package :cl-cc-type/test)

(defun %expect-valid (form expected-id)
  "Parse FORM as a type specifier, assert it is valid and has EXPECTED-ID as its feature id.
Returns the parsed node."
  (let ((node (cl-cc/type:parse-type-specifier form)))
    (expect (cl-cc/type:type-advanced-valid-p node) :to-be-truthy)
    (expect (cl-cc/type:type-advanced-feature-id node) :to-equal expected-id)
    node))

(it-sequential "advanced-contracts-enforce-incremental-staging-optics-and-test-generation"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1606 cache-entry :dependency-graph call-graph)))
  (%expect-valid
   '(advanced fr-1606 cache-entry :dependency-graph call-graph :cache module-cache :lsp t)
   "FR-1606")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1703 (code integer) :stage 0 :transition :run)))
  (%expect-valid
   '(advanced fr-1703 (code integer) :stage 1 :transition :run :evidence (proof staged-eval))
   "FR-1703")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-1801 (zoom a b) :lawful t)))
  (%expect-valid '(advanced fr-1801 (lens a b s t) :lawful t)
                 "FR-1801")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2101 (list integer) :generator fuzz :coverage-target 0)))
  (%expect-valid
   '(advanced fr-2101 (list integer) :generator (arbitrary integer)
              :coverage-target 100 :samples 20)
   "FR-2101"))

(it-sequential "advanced-contracts-enforce-constraint-analysis-and-tooling-families"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2405 user-module :exports (lookup lookup) :fingerprint "")))
  (%expect-valid '(advanced fr-2405 user-module :exports (lookup save) :fingerprint "sha256:abc")
                 "FR-2405")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2406 (< v n) :solver :unknown :theory :lia)))
  (%expect-valid
   '(advanced fr-2406 (< v n) :solver :z3 :theory :lia :evidence (proof smt-discharge))
   "FR-2406")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing widen)))
  (%expect-valid
   '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing narrow)
   "FR-2804")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-2902 (pointer integer) (pointer integer) :disjoint t :alias-class heap)))
  (%expect-valid '(advanced fr-2902 (pointer integer) (pointer float) :disjoint t :alias-class heap)
                 "FR-2902")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-3002 nat-normalise :hook solver :phase :emit)))
  (%expect-valid '(advanced fr-3002 nat-normalise :hook solver :phase :solve)
                 "FR-3002")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 0)))
  (%expect-valid '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 8)
                 "FR-3003"))

(it-sequential "advanced-contracts-enforce-typescript-encodings-effects-and-equality"
  (signals error
      (cl-cc/type:parse-type-specifier
       '(mapped-type (list fixnum) :transform mysterious)))
  (%expect-valid '(mapped-type (list fixnum) :transform optional)
                 "FR-3301")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(conditional-type (list fixnum) :extends list :then item :else item)))
  (%expect-valid '(conditional-type (list fixnum) :extends list :infer item :then item :else null)
                 "FR-3302")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(church-encoding integer :encoding :scott)))
  (%expect-valid '(church-encoding integer :encoding :church)
                 "FR-3403")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(open-union (io io) fixnum)))
  (%expect-valid '(open-union (io state) fixnum)
                 "FR-3404")

  (signals error
      (cl-cc/type:parse-type-specifier
       '(type-theory-equality (-> integer integer) (-> integer integer) :mode :extensional)))
  (%expect-valid '(type-theory-equality (-> integer integer) (-> integer integer)
                                        :mode :extensional
                                        :evidence (proof functional-extensionality))
                 "FR-3405"))

(it-sequential "advanced-contract-registry-rejects-invalid-specs-duplicates-and-unknown-features"
  (expect (cl-cc/type::lookup-type-advanced-contract "FR-9999-NOT-A-FEATURE") :to-be-null)
  (signals error
      (cl-cc/type::make-type-advanced-contract :id "FR-1501" :semantic-domain nil :min-args 1))
  (signals error
      (cl-cc/type::make-type-advanced-contract :id "FR-1501" :semantic-domain :safety))
  (let ((contract (cl-cc/type::make-type-advanced-contract
                    :id "FR-1501" :semantic-domain :safety :min-args 1)))
    (expect (cl-cc/type::type-advanced-contract-p contract) :to-be-truthy)
    (expect (cl-cc/type::type-advanced-contract-feature-id contract) :to-equal "FR-1501")
    (signals error (cl-cc/type::register-type-advanced-contract contract))
    (signals error
        (cl-cc/type::register-type-advanced-contract
         (cl-cc/type::make-type-advanced-contract
          :id "FR-UNKNOWN-FEATURE" :semantic-domain :safety :min-args 1)))))

