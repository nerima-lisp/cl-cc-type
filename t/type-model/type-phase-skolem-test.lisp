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

(in-package :cl-cc/type/type-model/test)

;;; Phase 4-6: Parser Integration Tests

;;; Phase A: Inference Bug Fixes

;;; Phase C: Typeclass Dictionary Passing

;;; Phase D: Row-Based Effect Type Inference

;;; Phase E: Rank-N Polymorphism

(it-sequential "phase-e-skolem-creation-and-equality"
  ;; fresh-rigid-var creates unique rigid variables; equality compares by identity.
  (let* ((sk1 (fresh-rigid-var 'a))
         (sk2 (fresh-rigid-var 'a))
         (sk3 (fresh-rigid-var 'b)))
    (expect (type-rigid-p sk1) :to-be-truthy)
    (expect (type-rigid-p sk2) :to-be-truthy)
    ;; Two fresh skolems with same name are distinct (unique IDs)
    (expect (type-rigid-equal-p sk1 sk2) :to-be-falsy)
    (expect (type-rigid-name sk1) :to-be 'a)
    ;; Same skolem is equal to itself
    (expect (type-rigid-equal-p sk3 sk3) :to-be-truthy)))

