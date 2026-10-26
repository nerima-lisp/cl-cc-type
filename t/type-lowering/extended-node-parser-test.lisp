;;;; t/types-extended-nodes-test.lisp — Type Representation Tests
;;;;
;;;; Tests for src/types-extended-nodes.lisp (advanced type nodes, type-equal-p
;;;; branches, type-free-vars) and src/types-env.lisp (type-env operations and
;;;; type-constructor encoding).
(in-package :cl-cc/type/type-lowering/test)

;;; ─── type-equal-p: product ─────────────────────────────────────────────────
;;; ─── type-equal-p: type-var ─────────────────────────────────────────────────
;;; ─── type-equal-p: union / intersection ────────────────────────────────────
;;; ─── type-equal-p: type-app / type-linear ──────────────────────────────────
;;; ─── type-equal-p: type-refinement ──────────────────────────────────────────
;;; ─── type-equal-p: effect-row / effect-op ──────────────────────────────────
;;; ─── type-equal-p: constraint / qualified ──────────────────────────────────
;;; ─── type-equal-p: error sentinel and rigid vars ────────────────────────────
;;; ─── type-equal-p: advanced ─────────────────────────────────────────────────
;;; ─── type-free-vars ────────────────────────────────────────────────────────
;;; ─── Type environment operations ───────────────────────────────────────────
;;; ─── Constructor and printing cases ────────────────────────────────────────
(it-sequential
  "type-specifier-parse-unparse-roundtrip"
  (let* ((ty (parse-type-specifier '(Option string)))
         (spec (unparse-type ty)))
    (expect (first spec) :to-be 'Option)
    (expect ty :to-be-type-equal-to (parse-type-specifier spec))))

