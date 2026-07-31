;;;; t/exhaustiveness-test.lisp
;;;; FR-1903: Exhaustiveness / Coverage Checking Tests
;;;;
;;;; Tests for check-typecase-exhaustiveness, check-etypecase-completeness,
;;;; useful-typecase-arms, and typecase-arm-subsumed-p.

(in-package :cl-cc-type/test)
;;; ─── typecase-arm-subsumed-p ──────────────────────────────────────────────

(it-each (("exhaustiveness-arm-subsumed-p-cases int-by-T"          integer (t) t)
          ("exhaustiveness-arm-subsumed-p-cases string-by-T"       string  (t) t)
          ("exhaustiveness-arm-subsumed-p-cases fixnum-by-T"       fixnum  (t) t)
          ("exhaustiveness-arm-subsumed-p-cases integer-by-exact"  integer (integer) t)
          ("exhaustiveness-arm-subsumed-p-cases string-in-list"    string (symbol integer string) t)
          ("exhaustiveness-arm-subsumed-p-cases fixnum-by-integer" fixnum  (integer) t)
          ("exhaustiveness-arm-subsumed-p-cases cons-by-list"      cons    (list) t)
          ("exhaustiveness-arm-subsumed-p-cases string-not-int"    string  (integer) nil)
          ("exhaustiveness-arm-subsumed-p-cases symbol-not-in"     symbol  (integer string) nil)
          ("exhaustiveness-arm-subsumed-p-cases int-no-arms"       integer nil nil)
          ;; TYPECASE-ARM-SUBSUMED-P is exported public API whose docstring
          ;; documents (not enforces) that ARM-TYPE/ALREADY-COVERED members
          ;; are "type name symbols (or T)"; every case above honors that,
          ;; so (SYMBOLP ARM-TYPE) and (SYMBOLP COVERED) had only ever been
          ;; observed true. Neither errors on a non-symbol -- both simply
          ;; fail to subsume, since a non-symbol can be neither T nor EQ to
          ;; a covered member representing a different type.
          ("exhaustiveness-arm-subsumed-p-cases non-symbol-arm-type" 42 (integer) nil)
          ("exhaustiveness-arm-subsumed-p-cases non-symbol-covered-member" integer (42) nil))
    "~A"
    (name-ignored arm-type covered expected)
  (declare (ignore name-ignored))
  (if expected
    (expect (cl-cc/type:typecase-arm-subsumed-p arm-type covered) :to-be-truthy)
    (expect (cl-cc/type:typecase-arm-subsumed-p arm-type covered) :to-be-falsy)))

;;; ─── typecase-arm-subsumed-p — self-subsumption (property-based) ───────────
;;;
;;; Any type is subsumed by a covered list containing itself: the very first
;;; disjunct in typecase-arm-subsumed-p's `some` is (eq covered arm-type), an
;;; exact-duplicate check that fires unconditionally whenever arm-type
;;; literally appears in already-covered — independent of the nominal
;;; subtyping hierarchy. Sample tp from the arm-type vocabulary already used
;;; in the case tables above.

(it-property "typecase-arm-subsumed-by-covered-list-containing-itself"
    ((tp (gen-member '(integer string fixnum symbol cons list t))))
  (expect (cl-cc/type:typecase-arm-subsumed-p tp (list tp)) :to-be-truthy))

;;; ─── check-typecase-exhaustiveness ───────────────────────────────────────

(it-each (("exhaustiveness-basic-coverage-cases with-t"    (integer string t) t)
          ("exhaustiveness-basic-coverage-cases without-t" (integer string)   nil))
    "~A"
    (name-ignored arms expected-exhaustive)
  (declare (ignore name-ignored))
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-typecase-exhaustiveness arms)
    (if expected-exhaustive
      (expect exhaustive-p :to-be-truthy)
      (expect exhaustive-p :to-be-falsy))
    (expect unreachable :to-be-null)
    (expect warnings :to-be-null)))

(it-sequential "exhaustiveness-detects-duplicate-arm"
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-typecase-exhaustiveness '(integer integer t))
    (expect exhaustive-p :to-be-truthy)
    (expect (length unreachable) :to-equal 1)
    (expect (first unreachable) :to-equal 1)        ; second 'integer (index 1) is unreachable
    (expect (length warnings) :to-equal 1)))

(it-sequential "exhaustiveness-detects-subsumed-arm"
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-typecase-exhaustiveness '(integer fixnum t))
    (expect exhaustive-p :to-be-truthy)
    (expect (member 1 unreachable) :to-be-truthy)    ; fixnum (index 1) subsumed by integer
    (expect (> (length warnings) 0) :to-be-truthy)))

(it-sequential "exhaustiveness-t-after-t-is-unreachable"
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-typecase-exhaustiveness '(integer t t))
    (expect exhaustive-p :to-be-truthy)
    (expect (member 2 unreachable) :to-be-truthy)    ; second T (index 2) unreachable
    (expect (> (length warnings) 0) :to-be-truthy)))

(it-each (("exhaustiveness-boundary-cases single-T" (t)  t)
          ("exhaustiveness-boundary-cases empty"    nil  nil))
    "~A"
    (name-ignored arms expected-exhaustive)
  (declare (ignore name-ignored))
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-typecase-exhaustiveness arms)
    (if expected-exhaustive
      (expect exhaustive-p :to-be-truthy)
      (expect exhaustive-p :to-be-falsy))
    (expect unreachable :to-be-null)
    (expect warnings :to-be-null)))

;;; ─── check-etypecase-completeness ────────────────────────────────────────

(it-sequential "etypecase-completeness-with-t-is-exhaustive"
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-etypecase-completeness '(integer string t))
    (expect exhaustive-p :to-be-truthy)
    (expect unreachable :to-be-null)
    (expect warnings :to-be-null)))

(it-sequential "etypecase-completeness-without-t-warns"
  (multiple-value-bind (exhaustive-p unreachable warnings)
      (cl-cc/type:check-etypecase-completeness '(integer string))
    (expect exhaustive-p :to-be-falsy)
    (expect unreachable :to-be-null)
    (expect (length warnings) :to-equal 1)
    (expect (search "etypecase" (first warnings)) :to-be-truthy)))

;;; ─── useful-typecase-arms ─────────────────────────────────────────────────

(it-sequential "useful-arms-removes-subsumed"
  (let ((useful (cl-cc/type:useful-typecase-arms '(integer fixnum string t))))
    ;; fixnum is subsumed by integer, so result is (integer string t)
    (expect (length useful) :to-equal 3)
    (expect (member 'fixnum useful) :to-be-falsy)))

(it-sequential "useful-arms-keeps-all-distinct"
  (let ((useful (cl-cc/type:useful-typecase-arms '(integer string symbol))))
    (expect (length useful) :to-equal 3)))

(it-sequential "useful-arms-empty-input"
  (expect (cl-cc/type:useful-typecase-arms '()) :to-be-null))
