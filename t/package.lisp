;;;; t/package.lisp — cl-cc-type test package.
;;;;
;;;; Tests call cl-weave's native forms directly: it-sequential, it-each,
;;;; expect/expect-not with the built-in matchers plus the two domain
;;;; matchers below, signals, before-each/before-all.

(defpackage :cl-cc-type/test
  (:use :cl :cl-weave :cl-cc/type :cl-cc/ast)
  (:shadowing-import-from :cl-weave #:describe)
  ;; cl-cc/type defines its own compiler-domain names that shadow CL
  ;; (subtypep, type-error, upgraded-*) and cl-weave (measure, capability);
  ;; prefer the cl-cc/type versions — that is what the type tests use.
  (:shadowing-import-from :cl-cc/type
   #:type-error #:subtypep
   #:upgraded-array-element-type #:upgraded-complex-part-type
   #:measure #:capability)
  (:export #:assert-when-present))

(in-package :cl-cc-type/test)

(defmacro assert-when-present (value form)
  "Evaluate FORM (an assertion) only when VALUE is non-nil.
Shared by test bodies that assert an optional field's shape only when the
fixture under test actually populated it."
  `(when ,value ,form))

;;; ── native cl-weave matchers for domain assertions ──────────────────────
;;; Used directly at call sites, e.g. (expect actual :to-be-type-equal-to
;;; expected) / (expect t2 :to-unify-with t1) / (expect-not t2 :to-unify-with
;;; t1).

(defmatcher :to-be-type-equal-to (actual expected)
  (cl-cc/type:type-equal-p (cl-weave::expected-one expected :to-be-type-equal-to) actual))

(defmatcher :to-unify-with (actual expected)
  (nth-value 1 (cl-cc/type:type-unify (cl-weave::expected-one expected :to-unify-with) actual)))

