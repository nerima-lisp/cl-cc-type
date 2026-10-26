;;;; t/printer-test.lisp — Type Printer Tests
;;;;
;;;; Tests for src/printer.lisp:
;;;; type-to-string for all type-node subtypes, unparse-type,
;;;; list-interleave, looks-like-type-specifier-p.
;;;; Coverage goal: every defmethod clause + every data table entry.

(in-package :cl-cc/type/type-model/test)

;;; ─── type-to-string: basic types ───────────────────────────────────────────

(progn
  (it-sequential "printer-primitive-types int"
    (expect (type-to-string type-int) :to-equal "FIXNUM"))
  (it-sequential "printer-primitive-types string"
    (expect (type-to-string type-string) :to-equal "STRING")))

(progn
  (it-sequential "printer-var-contains-substring named"
    (expect (search "alpha" (type-to-string (fresh-type-var :name "alpha"))) :to-be-truthy))
  (it-sequential "printer-var-contains-substring rigid"
    (expect (search "sk" (type-to-string (fresh-rigid-var "test"))) :to-be-truthy)))

(it-sequential "printer-linked-type-var-shows-resolved-type"
  (let ((v (fresh-type-var :name "a")))
    (setf (type-var-link v) type-int)
    (expect (type-to-string v) :to-equal "FIXNUM")))

(it-sequential "printer-type-scheme-produces-non-empty-string"
  (let* ((v (fresh-type-var :name "a"))
         (scheme (make-type-scheme (list v) v))
         (s (type-to-string scheme)))
    (expect (> (length s) 0) :to-be-truthy)))

;;; ─── type-to-string: composite types ───────────────────────────────────────

(progn
  (it-sequential "printer-arrow-cases single-param"
    (expect (type-to-string (make-type-arrow (list type-int) type-string :effects nil))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\""))
  (it-sequential "printer-arrow-cases multi-param"
    (expect (type-to-string (make-type-arrow (list type-int type-string) type-bool :effects nil))
            :to-match-inline-snapshot "\"(FIXNUM -> STRING) -> BOOLEAN\""))
  (it-sequential "printer-arrow-cases with-effects"
    (expect (type-to-string
             (make-type-arrow (list type-int) type-string :effects +io-effect-row+))
            :to-match-inline-snapshot "\"FIXNUM -[{IO}]-> STRING\""))
  (it-sequential "printer-arrow-cases effects-eq-to-the-pure-singleton"
    ;; TYPE-TO-STRING's (AND EFFECTS (NOT (EQ EFFECTS +PURE-EFFECT-ROW+))
    ;; (TYPE-EFFECT-ROW-EFFECTS EFFECTS)) only ever saw EFFECTS=NIL (the
    ;; first conjunct false, short-circuiting immediately) or a genuine
    ;; I/O row (all three conjuncts true); using +PURE-EFFECT-ROW+ itself
    ;; is non-NIL but EQ to the singleton, isolating the second conjunct.
    (expect (type-to-string
             (make-type-arrow (list type-int) type-string :effects +pure-effect-row+))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\""))
  (it-sequential "printer-arrow-cases effects-non-pure-object-with-no-concrete-effects"
    ;; A distinct (not EQ +PURE-EFFECT-ROW+) row with an open row-var but
    ;; no concrete effects isolates the third conjunct's own false branch.
    (expect (type-to-string
             (make-type-arrow (list type-int) type-string
                              :effects (make-type-effect-row :effects nil
                                                             :row-var (fresh-type-var))))
            :to-match-inline-snapshot "\"FIXNUM -> STRING\"")))

(progn
  (it-sequential "printer-container-type-delimiters product"
    (expect (type-to-string (make-type-product :elems (list type-int type-string)))
            :to-match-inline-snapshot "\"(FIXNUM, STRING)\""))
  (it-sequential "printer-container-type-delimiters type-app"
    (expect (type-to-string (make-type-app :fun type-int :arg type-string))
            :to-match-inline-snapshot "\"(FIXNUM STRING)\"")))

(progn
  (it-sequential "printer-binary-separator-types union"
    (expect (type-to-string (make-type-union (list type-int type-string)))
            :to-match-inline-snapshot "\"(FIXNUM | STRING)\""))
  (it-sequential "printer-binary-separator-types intersection"
    (expect (type-to-string (make-type-intersection (list type-int type-string)))
            :to-match-inline-snapshot "\"(FIXNUM & STRING)\"")))

(progn
  (it-sequential "printer-quantified-types forall"
    (let ((ty (let ((v (fresh-type-var :name "a"))) (make-type-forall :var v :body type-int))))
      (expect (> (length (type-to-string ty)) 0) :to-be-truthy)))
  (it-sequential "printer-quantified-types exists"
    (let ((ty (let ((v (fresh-type-var :name "a"))) (make-type-exists :var v :body type-int))))
      (expect (> (length (type-to-string ty)) 0) :to-be-truthy))))

(it-sequential "printer-binder-types"
  (let ((v (fresh-type-var :name "a")))
    (expect (> (length (type-to-string
                         (make-type-lambda :var v :knd nil :body type-int)))
                0)
            :to-be-truthy)
    (expect (> (length (type-to-string (make-type-mu :var v :body v))) 0) :to-be-truthy)))

(progn
  (it-sequential "printer-wrapper-type-annotations refinement"
    (expect (search "<pred>"
                     (type-to-string
                      (make-type-refinement :base type-int :predicate nil)))
            :to-be-truthy))
  (it-sequential "printer-wrapper-type-annotations capability"
    (expect (search "READ"
                     (type-to-string
                      (make-type-capability :base type-int :cap 'read)))
            :to-be-truthy)))

(it-sequential "printer-gadt-constructor-includes-double-colon"
  (expect (type-to-string
           (make-type-gadt-con
            :name 'just :arg-types (list type-int) :index-type type-any))
          :to-match-inline-snapshot "\"JUST :: FIXNUM -> T\""))

;;; ─── type-to-string: effect rows ──────────────────────────────────────────

;;; ─── type-to-string: constraint / qualified ───────────────────────────────

(it-sequential "printer-constraint-and-qualified"
  (let ((tc (make-type-constraint :class-name 'eq :type-arg type-int)))
    (expect (type-to-string tc) :to-match-inline-snapshot "\"(EQ FIXNUM)\"")
    (expect (type-to-string (make-type-qualified :constraints (list tc) :body type-int))
            :to-match-inline-snapshot "\"((EQ FIXNUM)) => FIXNUM\"")
    (let ((s (type-to-string (make-type-qualified :constraints nil :body type-int))))
      (expect s :to-equal "FIXNUM"))))

;;; ─── unparse-type roundtrip ────────────────────────────────────────────────

(it-sequential "unparse-type-forms"
  (expect (unparse-type type-int) :to-be 'fixnum)
  (expect (first (unparse-type (make-type-arrow (list type-int) type-string)))
          :to-be '->)
  (expect (first (unparse-type (make-type-union (list type-int type-string))))
          :to-be 'or)
  (expect (first (unparse-type (make-type-product :elems (list type-int))))
          :to-be 'values))

;;; ─── unparse-type: remaining type-node kinds ──────────────────────────────
;;; (merged from t/types-extended-advanced-semantics-test.lisp)

(it-sequential "unparse-type-covers-vars-app-forall-intersection-advanced-and-default"
  (expect (unparse-type (fresh-type-var :name 'x)) :to-be 'x)
  (expect (symbolp (unparse-type (fresh-type-var))) :to-be-truthy)
  (let ((a (fresh-type-var :name 'a)))
    (expect (string= (symbol-name
                       (first (unparse-type
                               (make-type-forall :var a :body type-int))))
                      "FORALL")
            :to-be-truthy))
  (expect (first (unparse-type
                  (make-type-intersection
                   (list type-int type-string))))
          :to-be 'and)
  (expect (first (unparse-type
                  (make-type-constructor 'list (list type-int))))
          :to-be 'list)
  (let ((anon-app (make-type-app :fun (fresh-type-var)
                                             :arg type-int)))
    (expect (listp (unparse-type anon-app)) :to-be-truthy)
    (expect (= (length (unparse-type anon-app)) 2) :to-be-truthy))
  (expect (unparse-type :not-a-type-node) :to-be :not-a-type-node)
  ;; type-advanced: registered surface head vs. the generic 'advanced' head.
  ;; Neither pre-existing advanced-node example above sets :EVIDENCE, so
  ;; %UNPARSE-TYPE-ADVANCED's (WHEN (TYPE-ADVANCED-EVIDENCE ty) ...) arm
  ;; was never taken.
  ;; %UNPARSE-TYPE-ADVANCED interns the feature-id symbol in SURFACE-HEAD's
  ;; own package when it has one, falling back to *PACKAGE* otherwise; an
  ;; uninterned surface head (impossible to produce via PARSE-TYPE-SPECIFIER,
  ;; whose reader always interns) is built directly to reach that fallback.
  (let ((uninterned-head-node
          (%make-type-advanced :feature-id "FR-1601" :name (make-symbol "CUSTOM-HEAD")
                                         :args (list 'payload) :properties nil)))
    (expect (unparse-type uninterned-head-node) :to-be-truthy)))

;;; ─── type-to-string: edge cases not covered above ────────────────────────

(progn
  (it-sequential "printer-atomic-sentinel-strings nil-val"
    (expect (type-to-string nil) :to-equal "NIL"))
  (it-sequential "printer-atomic-sentinel-strings unknown"
    (expect (type-to-string +type-unknown+) :to-equal "?")))

(progn
  (it-sequential "printer-unnamed-var-format type-var"
    (let ((s (type-to-string (fresh-type-var :name nil))))
      (expect (search "?t" s) :to-be-truthy)))
  (it-sequential "printer-unnamed-var-format rigid-var"
    (let ((s (type-to-string (fresh-rigid-var nil))))
      (expect (search "sk" s) :to-be-truthy)
      (expect (search "[" s) :to-be-falsy))))

(it-sequential "printer-fallback-hash-table"
  (expect (search "#<type" (type-to-string (make-hash-table))) :to-be-truthy))

(it-sequential "printer-type-error-sentinel"
  (let ((e1 (make-type-error :message "unbound x"))
        (e2 (make-type-error :message "unknown")))
    (expect (type-to-string e1) :to-match-inline-snapshot "\"<error: unbound x>\"")
    (expect (type-to-string e2) :to-equal "?")
    (expect (type-to-string +type-unknown+) :to-equal "?")))

(it-sequential "printer-compound-types"
  (with-soft-assertions
    (let ((pair (make-type-product :elems (list type-int type-string))))
      (expect (type-to-string pair) :to-match-inline-snapshot "\"(FIXNUM, STRING)\""))))

(progn
  (it-sequential "printer-unicode-type-operators forall"
    (let* ((a  (fresh-type-var :name 'a))
           (fn (make-type-arrow (list a) a))
           (ty (make-type-forall :var a :body fn)))
      (expect (search "∀" (type-to-string ty)) :to-be-truthy)))
  (it-sequential "printer-unicode-type-operators mu"
    (let* ((a (fresh-type-var :name 'a))
           (ty (make-type-mu :var a :body (make-type-union (list type-null a)))))
      (expect (search "μ" (type-to-string ty)) :to-be-truthy))))

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

(it-sequential "printer-type-scheme-null-vars"
  (expect (type-to-string (make-type-scheme nil type-int))
          :to-match-inline-snapshot "\"FIXNUM\""))

(it-sequential "printer-type-scheme-non-null-vars-exact"
  (let* ((v (fresh-type-var :name "a"))
         (scheme (make-type-scheme (list v) v)))
    (expect (type-to-string scheme) :to-match-inline-snapshot "\"(∀?a. ?a)\"")))

;;; ─── type-to-string: %format-row-fields empty-fields edge cases ──────────

;;; ─── list-interleave ───────────────────────────────────────────────────────

(it-sequential "list-interleave-behavior"
  (expect (list-interleave '(a b c) 'x) :to-equal '(a x b x c))
  (expect (list-interleave '(a) 'x) :to-equal '(a))
  (expect (list-interleave nil 'x) :to-be-null))
