(in-package :cl-cc/type)
;;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;; Type Inference — Condition Classes
;;;
;;; Extracted from inference-forms.lisp.
;;; Depends on inference-forms.lisp (type-to-string).
;;; Load order: immediately after inference-forms.lisp.
;;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

;;; Condition Classes

(define-simple-condition type-inference-error type-system-error
  (message)
  "Type inference error: ~A" (type-inference-error-message condition))

(define-condition typed-hole-error (type-inference-error)
  ())

(define-simple-condition unbound-variable-error type-inference-error
  ((name nil))
  "Unbound variable: ~A" (unbound-variable-error-name condition))

(define-simple-condition type-mismatch-error type-inference-error
  ((expected nil) (actual nil))
  "Type mismatch: expected ~A, got ~A"
  (type-to-string (type-mismatch-error-expected condition))
  (type-to-string (type-mismatch-error-actual condition)))
