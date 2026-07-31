;;;; t/types-extended-advanced-meta-validators-test.lisp — Advanced Meta-Validator Helper Tests
;;;;
;;;; Tests for src/types-extended-advanced-meta-validators.lisp:
;;;; implementation-evidence construction/registration/lookup, the
;;;; contract-argument-arity and format-string invalidation helpers, the
;;;; checker-designator resolver, and the family of one-liner symbol/head-form
;;;; predicates (SMT theories, plugin phases, mapped-type transforms, encoding
;;;; kinds, equality modes, generator/pointer/staged forms, booleans, positive
;;;; integers, symbolic lists, interface export lists, stage designators and
;;;; transitions, fingerprints, SMT solvers, synthesis strategies, effect-label
;;;; lists, and optic forms). Most of these helpers are already exercised
;;;; indirectly (as building blocks) by t/types-extended-advanced-validators-test
;;;; and t/types-extended-advanced-contract-test via parse-type-specifier; this
;;;; file calls them directly so every branch — including the failure/negative
;;;; branches those higher-level round-trips never reach — gets exercised.

(in-package :cl-cc-type/test)

(it-sequential "make-type-advanced-implementation-evidence-builds-a-valid-record-and-rejects-malformed-fields"
  (let ((evidence (cl-cc/type::make-type-advanced-implementation-evidence
                    :id "fr-1501" :modules '("src/foo.lisp")
                    :api-symbols '(foo-fn) :test-anchors '(foo-test-anchor)
                    :summary "custom summary")))
    (expect (cl-cc/type::type-advanced-implementation-evidence-p evidence) :to-be-truthy)
    (expect (cl-cc/type::type-advanced-implementation-evidence-feature-id evidence)
            :to-equal "FR-1501")
    (expect (cl-cc/type::type-advanced-implementation-evidence-modules evidence)
            :to-equal '("src/foo.lisp"))
    (expect (cl-cc/type::type-advanced-implementation-evidence-api-symbols evidence)
            :to-equal '(foo-fn))
    (expect (cl-cc/type::type-advanced-implementation-evidence-test-anchors evidence)
            :to-equal '(foo-test-anchor))
    (expect (cl-cc/type::type-advanced-implementation-evidence-summary evidence)
            :to-equal "custom summary"))
  ;; Omitting :summary defaults to the empty string.
  (let ((evidence (cl-cc/type::make-type-advanced-implementation-evidence
                    :id "FR-1502" :modules '("m") :api-symbols '(s) :test-anchors '(a))))
    (expect (cl-cc/type::type-advanced-implementation-evidence-summary evidence) :to-equal ""))
  ;; Each malformed-field check is independently enforced.
  (signals error
      (cl-cc/type::make-type-advanced-implementation-evidence
       :id "FR-1501" :modules nil :api-symbols '(s) :test-anchors '(a)))
  (signals error
      (cl-cc/type::make-type-advanced-implementation-evidence
       :id "FR-1501" :modules '(42) :api-symbols '(s) :test-anchors '(a)))
  (signals error
      (cl-cc/type::make-type-advanced-implementation-evidence
       :id "FR-1501" :modules '("m") :api-symbols nil :test-anchors '(a)))
  (signals error
      (cl-cc/type::make-type-advanced-implementation-evidence
       :id "FR-1501" :modules '("m") :api-symbols '("not-a-symbol") :test-anchors '(a)))
  (signals error
      (cl-cc/type::make-type-advanced-implementation-evidence
       :id "FR-1501" :modules '("m") :api-symbols '(s) :test-anchors nil))
  (signals error
      (cl-cc/type::make-type-advanced-implementation-evidence
       :id "FR-1501" :modules '("m") :api-symbols '(s) :test-anchors '("not-a-symbol"))))

(it-sequential "implementation-evidence-spec-builders-produce-plists-per-id"
  (expect (cl-cc/type::%type-advanced-implementation-evidence-spec
           "FR-1501" '("m") '(s) '(a) :summary "x")
          :to-equal (list :id "FR-1501" :modules '("m") :api-symbols '(s)
                           :test-anchors '(a) :summary "x"))
  (expect (cl-cc/type::%type-advanced-implementation-evidence-specs
           '("FR-1501" "FR-1502") '("m") '(s) '(a))
          :to-equal (list (list :id "FR-1501" :modules '("m") :api-symbols '(s) :test-anchors '(a))
                           (list :id "FR-1502" :modules '("m") :api-symbols '(s)
                                 :test-anchors '(a)))))

(it-sequential "register-and-lookup-type-advanced-implementation-evidence-enforce-known-ids-and-no-duplicates"
  ;; Every real FR id already has evidence registered by system init, so
  ;; lookup for a known id succeeds and returns a real record.
  (let ((evidence (cl-cc/type::lookup-type-advanced-implementation-evidence "FR-1501")))
    (expect (cl-cc/type::type-advanced-implementation-evidence-p evidence) :to-be-truthy)
    (expect (cl-cc/type::type-advanced-implementation-evidence-feature-id evidence)
            :to-equal "FR-1501"))
  ;; An unknown id (canonicalized but never registered) returns NIL.
  (expect (cl-cc/type::lookup-type-advanced-implementation-evidence "FR-9999-NOT-A-FEATURE")
          :to-be-null)
  ;; Registering evidence for a feature id with no metadata is rejected.
  (signals error
      (cl-cc/type::register-type-advanced-implementation-evidence
       (cl-cc/type::make-type-advanced-implementation-evidence
        :id "FR-9999-NOT-A-FEATURE" :modules '("m") :api-symbols '(s) :test-anchors '(a))))
  ;; Registering evidence for an already-covered feature id is rejected too.
  (signals error
      (cl-cc/type::register-type-advanced-implementation-evidence
       (cl-cc/type::make-type-advanced-implementation-evidence
        :id "FR-1501" :modules '("m") :api-symbols '(s) :test-anchors '(a)))))

(it-sequential "advanced-invalid-arg-count-and-min-args-helpers-signal-only-on-mismatch"
  (let ((dyn (cl-cc/type:make-type-dynamic cl-cc/type:type-int)))
    ;; FR-2501 dynamic nodes carry exactly one positional arg.
    (cl-cc/type::%type-advanced-require-arg-count dyn 1)
    (signals error (cl-cc/type::%type-advanced-require-arg-count dyn 2))
    (cl-cc/type::%type-advanced-require-min-args dyn 0)
    (cl-cc/type::%type-advanced-require-min-args dyn 1)
    (signals error (cl-cc/type::%type-advanced-require-min-args dyn 2))
    (signals error
        (cl-cc/type::%type-advanced-invalid dyn "custom failure: ~A vs ~A" 'x 'y))))

(it-sequential "advanced-resolve-checker-dispatches-on-designator-kind"
  (expect (cl-cc/type::%type-advanced-resolve-checker nil) :to-be-null)
  (expect (funcall (cl-cc/type::%type-advanced-resolve-checker #'oddp) 3) :to-be-truthy)
  (expect (funcall (cl-cc/type::%type-advanced-resolve-checker 'evenp) 4) :to-be-truthy)
  (signals error (cl-cc/type::%type-advanced-resolve-checker 42)))

(it-sequential "advanced-contract-property-key-and-predicate-accessors-handle-bare-and-cons-entries"
  (expect (cl-cc/type::%type-advanced-contract-property-key
           (cons :cache 'cl-cc/type::%type-advanced-symbolic-designator-p))
          :to-be :cache)
  (expect (cl-cc/type::%type-advanced-contract-property-predicate
           (cons :cache 'cl-cc/type::%type-advanced-symbolic-designator-p))
          :to-be 'cl-cc/type::%type-advanced-symbolic-designator-p)
  (expect (cl-cc/type::%type-advanced-contract-property-key :flag) :to-be :flag)
  (expect (cl-cc/type::%type-advanced-contract-property-predicate :flag) :to-be-null))

(it-sequential "advanced-symbol-name-member-p-and-symbolic-designator-p-and-head-symbol-form-p"
  (expect (cl-cc/type::%type-advanced-symbol-name-member-p 'z3 '("Z3" "CVC5")) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-symbol-name-member-p "cvc5" '("Z3" "CVC5")) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-symbol-name-member-p 'nonsense '("Z3" "CVC5")) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-symbol-name-member-p 42 '("Z3" "CVC5")) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-symbolic-designator-p 'foo) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-symbolic-designator-p "foo") :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-symbolic-designator-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-head-symbol-form-p 42 '("LENS")) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-head-symbol-form-p '(1 2 3) '("LENS")) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-head-symbol-form-p '(zoom a b) '("LENS")) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-head-symbol-form-p '(lens) '("LENS")) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-head-symbol-form-p '(lens a) '("LENS")) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-head-symbol-form-p '(lens a) '("LENS") 3) :to-be-falsy))

(it-sequential "generated-symbol-name-and-head-form-predicates-cover-every-table-entry"
  (expect (cl-cc/type::%type-advanced-smt-theory-p 'lia) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-smt-theory-p 'nonsense) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-plugin-phase-p 'solve) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-plugin-phase-p 'nonsense) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-mapped-transform-p 'optional) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-mapped-transform-p 'nonsense) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-encoding-kind-p 'church) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-encoding-kind-p 'nonsense) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-equality-mode-p 'intensional) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-equality-mode-p 'nonsense) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-generator-form-p '(arbitrary integer)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-generator-form-p '(nonsense integer)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-pointerish-form-p '(pointer integer)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-pointerish-form-p '(nonsense integer)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-staged-form-p '(code integer)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-staged-form-p '(nonsense integer)) :to-be-falsy))

(it-sequential "advanced-boolean-value-p-and-positive-integer-p"
  (expect (cl-cc/type::%type-advanced-boolean-value-p nil) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-boolean-value-p t) :to-be-truthy)
  ;; type-any's primitive name is the symbol T, so it also reads as boolean.
  (expect (cl-cc/type::%type-advanced-boolean-value-p cl-cc/type:type-any) :to-be-truthy)
  ;; type-null/type-unit's primitive name is the symbol NULL (spelled
  ;; N-U-L-L), which is a different symbol from CL:NIL, so it does NOT match
  ;; the (member ... '(t nil)) check.
  (expect (cl-cc/type::%type-advanced-boolean-value-p cl-cc/type:type-null) :to-be-falsy)
  ;; type-bool's primitive name is BOOLEAN, which is neither T nor NIL, so
  ;; (perhaps surprisingly) it does not itself count as a boolean *value*.
  (expect (cl-cc/type::%type-advanced-boolean-value-p cl-cc/type:type-bool) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-boolean-value-p 5) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-positive-integer-p 5) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-positive-integer-p 0) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-positive-integer-p -3) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-positive-integer-p "5") :to-be-falsy))

(it-sequential "advanced-non-empty-symbolic-list-p-and-effect-label-list-p"
  (expect (cl-cc/type::%type-advanced-non-empty-symbolic-list-p nil) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-non-empty-symbolic-list-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-non-empty-symbolic-list-p '(a b 42)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-non-empty-symbolic-list-p '(a a)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-non-empty-symbolic-list-p '(a "b" c)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-effect-label-list-p '(read write)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-effect-label-list-p nil) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-effect-label-list-p '(read read)) :to-be-falsy))

(it-sequential "advanced-interface-export-list-p-validates-entry-shapes-and-name-uniqueness"
  (expect (cl-cc/type::%type-advanced-interface-export-list-p nil) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-interface-export-list-p '(lookup save)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-interface-export-list-p '(lookup lookup)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-interface-export-list-p
           '(lookup (save :fn other-fn)))
          :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-interface-export-list-p
           '((lookup :fn a) (lookup :fn b)))
          :to-be-falsy)
  ;; A cons entry whose head is not a symbol is malformed.
  (expect (cl-cc/type::%type-advanced-interface-export-list-p '((42 :fn a))) :to-be-falsy)
  ;; A single-element list entry has no predicate/second element and is
  ;; likewise malformed.
  (expect (cl-cc/type::%type-advanced-interface-export-list-p '((standalone))) :to-be-falsy))

(it-sequential "advanced-stage-designator-p-and-stage-transition-p"
  (expect (cl-cc/type::%type-advanced-stage-designator-p 0) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-designator-p 1) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-designator-p :runtime) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-designator-p "code") :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-designator-p 2) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-stage-designator-p :other) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-stage-transition-p :quote) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-transition-p 'run) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-transition-p "splice") :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-stage-transition-p :other) :to-be-falsy))

(it-sequential "advanced-fingerprint-p-accepts-non-empty-strings-integers-and-symbolic-designators"
  (expect (cl-cc/type::%type-advanced-fingerprint-p "sha256:abc") :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-fingerprint-p 42) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-fingerprint-p 'a-tag) :to-be-truthy)
  ;; The empty string fails the length check, but still qualifies as a
  ;; symbolic designator, so it is (perhaps surprisingly) still accepted.
  (expect (cl-cc/type::%type-advanced-fingerprint-p "") :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-fingerprint-p 3.14) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-fingerprint-p '(a b)) :to-be-falsy))

(it-sequential "advanced-smt-solver-p-and-synthesis-strategy-p-fall-back-to-the-live-registries"
  (expect (cl-cc/type::%type-advanced-smt-solver-p 'z3) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-smt-solver-p "CVC5") :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-smt-solver-p 'totally-unregistered-solver) :to-be-falsy)
  (cl-cc/type:register-smt-solver 'meta-validators-test-dummy-solver
                                  (lambda (constraint theory)
                                    (list :status :unknown :constraint constraint :theory theory)))
  (expect (cl-cc/type::%type-advanced-smt-solver-p 'meta-validators-test-dummy-solver)
          :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-synthesis-strategy-p 'enumerative) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-synthesis-strategy-p 'totally-unregistered-strategy)
          :to-be-falsy)
  (cl-cc/type:register-type-synthesis-strategy
   'meta-validators-test-dummy-strategy
   (lambda (signature fuel) (list :status :candidate :signature signature :fuel fuel)))
  (expect (cl-cc/type::%type-advanced-synthesis-strategy-p 'meta-validators-test-dummy-strategy)
          :to-be-truthy))

(it-sequential "advanced-optic-form-p-checks-lens-prism-arity-and-traversal-minimum-length"
  (expect (cl-cc/type::%type-advanced-optic-form-p 42) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(1 2 3)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(zoom a b s tt)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(lens a b s tt)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(lens a b s)) :to-be-falsy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(prism a b s tt)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(traversal a b)) :to-be-truthy)
  (expect (cl-cc/type::%type-advanced-optic-form-p '(traversal a)) :to-be-falsy))
