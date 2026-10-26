;;;; t/types-core-nodes-test.lisp - 2026 Type System Node and Substitution API Tests
;;;;
;;;; Covers: 2026 type node extensions (rigid vars, product/variant, exists/mu, HKT app,
;;;; record, arrow-mult, linear), ANSI upgrade helpers, and hash-table substitution API.

(in-package :cl-cc/type/type-lowering/test)

;;; ─────────────────────────────────────────────────────────────────────────
;;; 2026 Type System: New Type Node Tests (direct new API)
;;; ─────────────────────────────────────────────────────────────────────────

(progn
  (it-sequential "upgraded-array-and-complex-part-types"
    (let ((bit-upgraded (upgraded-array-element-type 'bit))
          (char-upgraded (upgraded-array-element-type 'character))
          (fallback-upgraded (upgraded-array-element-type '(or fixnum string)))
          (complex-part (upgraded-complex-part-type 'complex)))
      (expect (parse-type-specifier 'bit) :to-be-type-equal-to bit-upgraded)
      (expect (parse-type-specifier 'character) :to-be-type-equal-to char-upgraded)
      (expect type-any :to-be-type-equal-to fallback-upgraded)
      (expect (parse-type-specifier 'real) :to-be-type-equal-to complex-part)))
  (it-sequential "upgraded-array-element-type-bit"
    (expect (upgraded-array-element-type 'bit)
            :to-be-type-equal-to (parse-type-specifier 'bit)))
  (it-sequential "upgraded-array-element-type-character"
    (expect (upgraded-array-element-type 'character)
            :to-be-type-equal-to (parse-type-specifier 'character)))
  (it-sequential "upgraded-array-element-type-non-symbol-input-defaults-to-top"
    ;; Compound specifiers bypass parsing and use the top-type fallback.
    (expect (upgraded-array-element-type '(vector fixnum))
            :to-be-type-equal-to (parse-type-specifier 't))))

;;; ─────────────────────────────────────────────────────────────────────────
;;; 2026 Type System: Hash-Table Substitution API Tests
;;; ─────────────────────────────────────────────────────────────────────────

(it-sequential "subtypep-wrapper-returns-two-values"
  (multiple-value-bind (ok surep)
      (subtypep 'fixnum 'integer)
    (expect ok :to-be-truthy)
    (expect surep :to-be-truthy)))

(it-sequential "subtypep-accepts-type-nodes-directly"
  (multiple-value-bind (ok surep) (subtypep type-int type-any)
    (expect ok :to-be-truthy)
    (expect surep :to-be-truthy))
  (multiple-value-bind (ok surep) (subtypep type-string 'integer)
    (expect ok :to-be-falsy)
    (expect surep :to-be-truthy))
  (multiple-value-bind (ok surep) (subtypep 'fixnum type-any)
    (expect ok :to-be-truthy)
    (expect surep :to-be-truthy)))

(it-sequential "register-protocol-type-name-and-specifier-pair"
  (let ((*protocol-type-registry* (make-hash-table :test #'eq)))
    (register-protocol-type 'countable '((count integer)))
    (let ((fields (lookup-protocol-type 'countable)))
      (expect fields :to-be-truthy)
      (expect (cdr (first fields))
              :to-be-type-equal-to (parse-type-specifier 'integer)))))

(it-sequential "upgraded-array-element-type-defaults-to-top"
  (expect (upgraded-array-element-type 'fixnum)
          :to-be-type-equal-to (parse-type-specifier 't)))

(it-sequential "upgraded-array-element-type-accepts-type-node-directly"
  (expect (upgraded-array-element-type type-char)
          :to-be-type-equal-to (parse-type-specifier 'character)))

(it-sequential "upgraded-complex-part-type-always-real"
  (expect (upgraded-complex-part-type 'fixnum)
          :to-be-type-equal-to (parse-type-specifier 'real))
  (expect (upgraded-complex-part-type 'string nil)
          :to-be-type-equal-to (parse-type-specifier 'real)))
