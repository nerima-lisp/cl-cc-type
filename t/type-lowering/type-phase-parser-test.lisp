;;;; t/type-phase-tests.lisp - Type Phase Integration Tests (Phase A, C, D, E)
;;;;
;;;; Covers: parser integration, inference bug fixes, typeclass dictionary
;;;; passing, row-based effect inference, and rank-N skolem.
;;;;
;;;; Ported from the cl-cc monorepo's tests/type-phase-tests.lisp.
;;;; `lower-sexp-to-ast` becomes `cl-cc/parse:lower-sexp-to-ast` now that
;;;; cl-cc-parse has its own standalone repository. Phase C's dict-env-miss
;;;; case table needed real type-node values (type-string / type-int), which
;;;; cl-weave's it-each cannot supply (case tuples are literal, unevaluated
;;;; data — see suite-each-cases in cl-weave/src/registration.lisp; a bare
;;;; symbol there binds the symbol, not the value), so that one case table
;;;; became two it-sequential tests.

(in-package :cl-cc/type/type-lowering/test)

;;; Phase 4-6: Parser Integration Tests

(it-sequential "parse-type-specifier-forall"
  ;; parse-type-specifier: forall form produces a type-forall binding the named variable.
  (let ((result (parse-type-specifier '(forall a (-> a a)))))
    (expect (type-forall-p result) :to-be-truthy)
    (expect (type-var-name (type-forall-var result)) :to-be 'a)))

(it-sequential "parse-type-specifier-effectful-arrow"
  ;; parse-type-specifier: effectful arrow (-> ! io) has one effect in the effects slot.
  (let ((result (parse-type-specifier '(-> fixnum fixnum ! io))))
    (expect (type-arrow-p result) :to-be-truthy)
    (expect (length (type-arrow-params result)) :to-equal 1)
    (expect (type-equal-p type-int (type-arrow-return result)) :to-be-truthy)
    (let ((effs (type-arrow-effects result)))
      (expect (type-effect-row-p effs) :to-be-truthy)
      (expect (length (type-effect-row-effects effs)) :to-equal 1))))

(it-sequential "parse-type-specifier-qualified"
  ;; parse-type-specifier: => form produces a type-qualified with one named constraint.
  (let ((result (parse-type-specifier '(=> (num a) (-> a a a)))))
    (expect (type-qualified-p result) :to-be-truthy)
    (expect (length (type-qualified-constraints result)) :to-equal 1)
    (let ((constraint (first (type-qualified-constraints result))))
      (expect (symbol-name (type-constraint-class-name constraint)) :to-equal "NUM"))))

;;; Phase A: Inference Bug Fixes

;;; Phase C: Typeclass Dictionary Passing

;;; Phase D: Row-Based Effect Type Inference

;;; Phase E: Rank-N Polymorphism

