;;;; t/types-extended-advanced-contract-test.lisp — Advanced Contract Registry Tests
;;;;
;;;; Tests for src/types-extended-advanced-contract.lisp:
;;;; the type-advanced-contract struct/registry, and the incremental-staging,
;;;; optics, test-generation, constraint-analysis, tooling, and TypeScript-style
;;;; encoding contracts it enforces via parse-type-specifier.

(in-package :cl-cc/type/advanced-metadata/test)

(defun %expect-valid (form)
  "Parse FORM as a type specifier and assert its advanced feature contract accepts the parsed node.
Returns the parsed node."
  (let ((node (parse-type-specifier form)))
    (expect (type-advanced-valid-p node) :to-be-truthy)
    node))

(it-sequential "advanced-contracts-enforce-incremental-staging-optics-and-test-generation"
  (signals error
      (parse-type-specifier
       '(advanced fr-1606 cache-entry :dependency-graph call-graph)))
  (%expect-valid
   '(advanced fr-1606 cache-entry :dependency-graph call-graph :cache module-cache :lsp t))

  (signals error
      (parse-type-specifier
       '(advanced fr-1703 (code integer) :stage 0 :transition :run)))
  (%expect-valid
   '(advanced fr-1703 (code integer) :stage 1 :transition :run :evidence (proof staged-eval)))

  (signals error
      (parse-type-specifier
       '(advanced fr-1801 (zoom a b) :lawful t)))
  (%expect-valid '(advanced fr-1801 (lens a b s t) :lawful t))

  (signals error
      (parse-type-specifier
       '(advanced fr-2101 (list integer) :generator fuzz :coverage-target 0)))
  (%expect-valid
   '(advanced fr-2101 (list integer) :generator (arbitrary integer)
              :coverage-target 100 :samples 20)))

(it-sequential "advanced-contracts-enforce-constraint-analysis-and-tooling-families"
  (signals error
      (parse-type-specifier
       '(advanced fr-2405 user-module :exports (lookup lookup) :fingerprint "")))
  (%expect-valid '(advanced fr-2405 user-module :exports (lookup save) :fingerprint "sha256:abc"))

  (signals error
      (parse-type-specifier
       '(advanced fr-2406 (< v n) :solver :unknown :theory :lia)))
  (%expect-valid
   '(advanced fr-2406 (< v n) :solver :z3 :theory :lia :evidence (proof smt-discharge)))

  (signals error
      (parse-type-specifier
       '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing widen)))
  (%expect-valid
   '(advanced fr-2804 integer :domain interval-lattice :widening widen :narrowing narrow))

  (signals error
      (parse-type-specifier
       '(advanced fr-2902 (pointer integer) (pointer integer) :disjoint t :alias-class heap)))
  (%expect-valid '(advanced fr-2902 (pointer integer) (pointer float) :disjoint t :alias-class heap))

  (signals error
      (parse-type-specifier
       '(advanced fr-3002 nat-normalise :hook solver :phase :emit)))
  (%expect-valid '(advanced fr-3002 nat-normalise :hook solver :phase :solve))

  (signals error
      (parse-type-specifier
       '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 0)))
  (%expect-valid '(advanced fr-3003 (-> integer integer) :search :enumerative :fuel 8)))

(it-sequential "advanced-contracts-enforce-typescript-encodings-effects-and-equality"
  (signals error
      (parse-type-specifier
       '(mapped-type (list fixnum) :transform mysterious)))
  (%expect-valid '(mapped-type (list fixnum) :transform optional))

  (signals error
      (parse-type-specifier
       '(conditional-type (list fixnum) :extends list :then item :else item)))
  (%expect-valid '(conditional-type (list fixnum) :extends list :infer item :then item :else null))

  (signals error
      (parse-type-specifier
       '(church-encoding integer :encoding :scott)))
  (%expect-valid '(church-encoding integer :encoding :church))

  (signals error
      (parse-type-specifier
       '(open-union (io io) fixnum)))
  (%expect-valid '(open-union (io state) fixnum))

  (signals error
      (parse-type-specifier
       '(type-theory-equality (-> integer integer) (-> integer integer) :mode :extensional)))
  (%expect-valid '(type-theory-equality (-> integer integer) (-> integer integer)
                                        :mode :extensional
                                        :evidence (proof functional-extensionality))))

(it-sequential "advanced-contract-registry-rejects-invalid-specs-duplicates-and-unknown-features"
  (expect (lookup-type-advanced-contract "FR-9999-NOT-A-FEATURE") :to-be-null)
  (signals error
      (make-type-advanced-contract :id "FR-1501" :semantic-domain nil :min-args 1))
  (signals error
      (make-type-advanced-contract :id "FR-1501" :semantic-domain :safety))
  (let ((contract (make-type-advanced-contract
                    :id "FR-1501" :semantic-domain :safety :min-args 1)))
    (expect (type-advanced-contract-p contract) :to-be-truthy)
    (expect (type-advanced-contract-feature-id contract) :to-equal "FR-1501")
    (signals error (register-type-advanced-contract contract))
    (signals error
        (register-type-advanced-contract
         (make-type-advanced-contract
          :id "FR-UNKNOWN-FEATURE" :semantic-domain :safety :min-args 1)))))

