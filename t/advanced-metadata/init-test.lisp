;;;; t/types-extended-advanced-init-test.lisp — advanced feature registry
;;;; self-consistency checks
;;;;
;;;; Tests for src/types-extended-advanced-init.lisp:
;;;; %ensure-type-advanced-contract-coverage and
;;;; %ensure-type-advanced-implementation-evidence-coverage. Both run once
;;;; at load time via %initialize-type-advanced-feature-registry, seeded
;;;; from the real +type-advanced-feature-specs+ table, where they always
;;;; pass (or the system would not load at all) -- so their error branches
;;;; had never been exercised. Each test below corrupts one registry with a
;;;; single missing or orphan entry, calls the ensure-function directly, and
;;;; restores full canonical state via %initialize-type-advanced-feature-
;;;; registry in an unwind-protect, following the "FR-9999*" test-only id
;;;; convention from types-extended-advanced-meta-test.lisp. The count-
;;;; mismatch cases below instead corrupt +TYPE-ADVANCED-FEATURE-SPECS+
;;;; itself -- a DEFPARAMETER, not a DEFCONSTANT, so it is a legal (if
;;;; unusual) SETF target -- restoring its exact original value afterward.

(in-package :cl-cc/type/advanced-metadata/test)

(it-sequential "ensure-type-advanced-contract-coverage-signals-for-a-missing-contract"
  (unwind-protect
      (progn
        (remhash "FR-1501" *type-advanced-contract-registry*)
        (signals error (%ensure-type-advanced-contract-coverage)))
    (%initialize-type-advanced-feature-registry)))

(it-sequential "ensure-type-advanced-contract-coverage-signals-for-an-orphan-contract"
  (unwind-protect
      (progn
        (register-type-advanced-feature
         (make-type-advanced-feature :id "FR-9999-ORPHAN-CONTRACT" :title "orphan"))
        (register-type-advanced-contract
         (make-type-advanced-contract :id "FR-9999-ORPHAN-CONTRACT"
                                                   :semantic-domain :test
                                                   :exact-args 1
                                                   :summary "orphan test contract"))
        (signals error (%ensure-type-advanced-contract-coverage)))
    (%initialize-type-advanced-feature-registry)))

(it-sequential "ensure-type-advanced-implementation-evidence-coverage-signals-for-missing-evidence"
  (unwind-protect
      (progn
        (remhash "FR-1501" *type-advanced-implementation-evidence-registry*)
        (signals error (%ensure-type-advanced-implementation-evidence-coverage)))
    (%initialize-type-advanced-feature-registry)))

(it-sequential "ensure-type-advanced-implementation-evidence-coverage-signals-for-orphan-evidence"
  (unwind-protect
      (progn
        (register-type-advanced-feature
         (make-type-advanced-feature :id "FR-9999-ORPHAN-EVIDENCE" :title "orphan"))
        (register-type-advanced-implementation-evidence
         (make-type-advanced-implementation-evidence
          :id "FR-9999-ORPHAN-EVIDENCE"
          :modules '("t/test-module.lisp")
          :api-symbols '(test-symbol)
          :test-anchors '(test-anchor)
          :summary "orphan test evidence"))
        (signals error (%ensure-type-advanced-implementation-evidence-coverage)))
    (%initialize-type-advanced-feature-registry)))

(it-sequential "ensure-type-advanced-contract-coverage-signals-for-a-registry-count-mismatch"
  ;; With no missing and no orphan entries, the registry's key-set and
  ;; +TYPE-ADVANCED-FEATURE-SPECS+'s id-set are already known equal as
  ;; SETS -- the only way HASH-TABLE-COUNT (a true unique count) can
  ;; still differ from (LENGTH FEATURE-IDS) is a duplicate id in the
  ;; spec table itself. Temporarily duplicating the first entry reaches
  ;; this final check directly.
  (let ((saved +type-advanced-feature-specs+))
    (unwind-protect
        (progn
          (setf +type-advanced-feature-specs+
                (cons (first saved) saved))
          (signals error (%ensure-type-advanced-contract-coverage)))
      (setf +type-advanced-feature-specs+ saved)
      (%initialize-type-advanced-feature-registry))))

(it-sequential "ensure-type-advanced-implementation-evidence-coverage-signals-for-a-registry-count-mismatch"
  (let ((saved +type-advanced-feature-specs+))
    (unwind-protect
        (progn
          (setf +type-advanced-feature-specs+
                (cons (first saved) saved))
          (signals error (%ensure-type-advanced-implementation-evidence-coverage)))
      (setf +type-advanced-feature-specs+ saved)
      (%initialize-type-advanced-feature-registry))))
