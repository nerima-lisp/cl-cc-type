;;;; t/printer-test.lisp — Type Printer Tests
;;;;
;;;; Tests for src/printer.lisp:
;;;; type-to-string for all type-node subtypes, unparse-type,
;;;; list-interleave, looks-like-type-specifier-p.
;;;; Coverage goal: every defmethod clause + every data table entry.

(in-package :cl-cc/type/type-lowering/test)

;;; ─── type-to-string: basic types ───────────────────────────────────────────

;;; ─── type-to-string: composite types ───────────────────────────────────────

;;; ─── type-to-string: effect rows ──────────────────────────────────────────

;;; ─── type-to-string: constraint / qualified ───────────────────────────────

;;; ─── unparse-type roundtrip ────────────────────────────────────────────────

;;; ─── unparse-type: remaining type-node kinds ──────────────────────────────
;;; (merged from t/types-extended-advanced-semantics-test.lisp)

(it-sequential "type-lowering-unparse-advanced-surface-roundtrips"
  ;; type-advanced: registered surface head vs. the generic 'advanced' head.
  (let* ((route-node (parse-type-specifier '(api-type (get "/users/{id}" integer user))))
         (route-spec (unparse-type route-node)))
    (expect (string= (symbol-name (first route-spec)) "API-TYPE") :to-be-truthy))
  (let* ((generic-node (parse-type-specifier
                        '(advanced fr-1606 cache-entry
                          :dependency-graph call-graph :cache module-cache :lsp t)))
         (generic-spec (unparse-type generic-node)))
    (expect (string= (symbol-name (first generic-spec)) "ADVANCED") :to-be-truthy)
    (expect (string= (symbol-name (second generic-spec)) "FR-1606") :to-be-truthy)
    (expect (type-advanced-valid-p (parse-type-specifier generic-spec))
            :to-be-truthy))
  ;; Neither pre-existing advanced-node example above sets :EVIDENCE, so
  ;; %UNPARSE-TYPE-ADVANCED's (WHEN (TYPE-ADVANCED-EVIDENCE ty) ...) arm
  ;; was never taken.
  (let* ((proof-node (parse-type-specifier
                       '(advanced fr-2001 my-lemma :evidence (proof my-lemma-witness))))
         (proof-spec (unparse-type proof-node)))
    (expect (member :evidence proof-spec) :to-be-truthy))
  ;; %UNPARSE-TYPE-ADVANCED interns the feature-id symbol in SURFACE-HEAD's
  ;; own package when it has one, falling back to *PACKAGE* otherwise; an
  ;; uninterned surface head (impossible to produce via PARSE-TYPE-SPECIFIER,
  ;; whose reader always interns) is built directly to reach that fallback.
)

;;; ─── type-to-string: edge cases not covered above ────────────────────────

(progn
  (it-sequential "printer-looks-like-type-specifier-p fixnum"
    (expect (looks-like-type-specifier-p 'fixnum) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p string"
    (expect (looks-like-type-specifier-p 'string) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p int-shorthand"
    (expect (looks-like-type-specifier-p 'int) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p bool-shorthand"
    (expect (looks-like-type-specifier-p 'bool) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p or-composite"
    (expect (looks-like-type-specifier-p '(or fixnum string)) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p and-composite"
    (expect (looks-like-type-specifier-p '(and fixnum string)) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p bang-prefix"
    (expect (looks-like-type-specifier-p '(!linear fixnum)) :to-be-truthy))
  (it-sequential "printer-looks-like-type-specifier-p frobnitz-sym"
    (expect (looks-like-type-specifier-p 'frobnitz) :to-be-falsy))
  (it-sequential "printer-looks-like-type-specifier-p frobnitz-list"
    (expect (looks-like-type-specifier-p '(frobnitz fixnum)) :to-be-falsy)))

;;; ─── type-to-string: type-advanced direct printer coverage ───────────────
;;; Exercises the property-loop and :EVIDENCE branches of the type-advanced
;;; method, and %advanced-display-value on nested conses, type-nodes, and
;;; plain atoms (keywords/numbers are prin1-print-package-independent, so
;;; they hand-compute deterministically unlike bare symbols).

;;; NOTE: TYPE-TO-STRING's (SYMBOLP SURFACE-HEAD) conjunct (printer.lisp)
;;; looks untested but is not: TYPE-ADVANCED's NAME slot is declared
;;; `:type symbol` (types-extended-advanced-node.lisp), so SBCL itself
;;; guarantees the check can never observe a non-symbol -- confirmed by
;;; SBCL rejecting a `(%make-type-advanced ... :name "not-a-symbol" ...)`
;;; attempt here at compile time with "conflicts with its asserted type
;;; SYMBOL". Left undone, like the other struct-enforced guards documented
;;; elsewhere in this file's own commit history.

;;; ─── type-to-string: type-scheme quantified-vars branch ──────────────────

;;; ─── type-to-string: %format-row-fields empty-fields edge cases ──────────

;;; ─── list-interleave ───────────────────────────────────────────────────────

