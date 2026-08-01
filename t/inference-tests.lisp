;;;; t/inference-tests.lisp — Type Inference Registry + Predicate Tests
;;;;
;;;; Covers functions in src/inference.lisp and src/inference-forms.lisp:
;;;; class/alias registries, type predicate mapping, type guard extraction,
;;;; union narrowing, constant effect table.
;;;;
;;;; Ported from the cl-cc monorepo's tests/unit/type/inference-tests.lisp.
;;;; `cl-cc:lower-sexp-to-ast` (the monorepo's umbrella re-export) becomes
;;;; `cl-cc/parse:lower-sexp-to-ast` now that cl-cc-parse has its own
;;;; standalone repository.

(in-package :cl-cc-type/test)

;;; ─── Class Type Registry ──────────────────────────────────────────────────

(it-sequential "infer-class-type-register-returns-slot-list"
  ;; register-class-type + lookup-class-type returns the registered slot list.
  (let ((slots (list (cons 'x cl-cc/type:type-int)
                      (cons 'y cl-cc/type:type-string))))
    (cl-cc/type:register-class-type 'test-class-7891 slots)
    (let ((result (cl-cc/type:lookup-class-type 'test-class-7891)))
      (expect result :to-be-truthy)
      (expect (length result) :to-equal 2))))

(it-sequential "infer-class-type-lookup-slot-finds-slot-type"
  ;; lookup-slot-type finds the registered type for a known slot.
  (cl-cc/type:register-class-type 'test-class-7892
   (list (cons 'name cl-cc/type:type-string)
         (cons 'age cl-cc/type:type-int)))
  (let ((ty (cl-cc/type:lookup-slot-type 'test-class-7892 'age)))
    (expect (cl-cc/type:type-primitive-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name ty) :to-be 'fixnum)))

(it-sequential "infer-class-type-lookup-nonexistent-slot-returns-nil"
  ;; lookup-slot-type returns nil for a slot not in the registered class.
  (cl-cc/type:register-class-type 'test-class-7893
   (list (cons 'x cl-cc/type:type-int)))
  (expect (cl-cc/type:lookup-slot-type 'test-class-7893 'nonexistent) :to-be-null))

(it-sequential "infer-class-type-lookup-unknown-class-returns-nil"
  ;; lookup-class-type returns nil for a class that was never registered.
  (expect (cl-cc/type:lookup-class-type 'completely-unknown-class-xyz) :to-be-null))

;;; ─── Type Alias Registry / Predicate Registry ────────────────────────────

(it-sequential "infer-registry-alias-roundtrip"
  ;; register-type-alias + lookup returns the registered form; unknown alias returns nil.
  (cl-cc/type:register-type-alias 'test-alias-7891 '(or fixnum string))
  (expect (cl-cc/type:lookup-type-alias 'test-alias-7891) :to-equal '(or fixnum string))
  (expect (cl-cc/type:lookup-type-alias 'no-such-alias-xyz) :to-be-null))

(it-sequential "infer-registry-predicate-roundtrip"
  ;; register-type-predicate + type-predicate-to-type returns the registered type; unknown returns nil.
  (cl-cc/type:register-type-predicate 'custom-pred-xyz-7891 cl-cc/type:type-int)
  (let ((ty (cl-cc/type::type-predicate-to-type 'custom-pred-xyz-7891)))
    (expect ty :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name ty) :to-be 'fixnum))
  (expect (cl-cc/type::type-predicate-to-type 'foobar-p) :to-be-null))

;;; it-each's case tuples are literal, unevaluated data (see suite-each-cases
;;; in cl-weave/src/registration.lisp): a bare symbol in a case binds the
;;; symbol itself, not its value. *type-predicate-table* and
;;; *constant-effect-table* need their runtime values here, so these stay two
;;; plain it-sequential tests rather than an it-each over the two special vars.

(it-sequential "infer-global-tables-are-hash-tables-predicate-table"
  (expect (hash-table-p cl-cc/type:*type-predicate-table*) :to-be-truthy))

(it-sequential "infer-global-tables-are-hash-tables-effect-table"
  (expect (hash-table-p cl-cc/type:*constant-effect-table*) :to-be-truthy))

;;; ─── Constant Effect Table ────────────────────────────────────────────────

(it-each (("infer-constant-effect-table-entries int-pure"   cl-cc/ast:ast-int   nil)
          ("infer-constant-effect-table-entries print-io"   cl-cc/ast:ast-print "IO")
          ("infer-constant-effect-table-entries setq-state" cl-cc/ast:ast-setq  "STATE"))
    "~A"
    (name-ignored ast-type expected-effect-name)
  (declare (ignore name-ignored))
  (let ((row (gethash ast-type cl-cc/type:*constant-effect-table*)))
    (expect (cl-cc/type:type-effect-row-p row) :to-be-truthy)
    (let ((names (mapcar #'cl-cc/type:type-effect-op-name
                          (cl-cc/type:type-effect-row-effects row))))
      (if expected-effect-name
          (expect (member expected-effect-name names :key #'symbol-name :test #'string=) :to-be-truthy)
          (expect (member expected-effect-name names :key #'symbol-name :test #'string=) :to-be-falsy)))))

;;; ─── type-predicate-to-type ───────────────────────────────────────────────

(it-each (("infer-predicate-to-type-known numberp"    numberp    fixnum)
          ("infer-predicate-to-type-known integerp"   integerp   fixnum)
          ("infer-predicate-to-type-known stringp"    stringp    string)
          ("infer-predicate-to-type-known symbolp"    symbolp    symbol)
          ("infer-predicate-to-type-known consp"      consp      cons)
          ("infer-predicate-to-type-known null"       null       null)
          ("infer-predicate-to-type-known characterp" characterp character)
          ("infer-predicate-to-type-known functionp"  functionp  function))
    "~A"
    (name-ignored pred expected-name)
  (declare (ignore name-ignored))
  (let ((ty (cl-cc/type::type-predicate-to-type pred)))
    (expect ty :to-be-truthy)
    (expect (cl-cc/type:type-primitive-name ty) :to-be expected-name)))

;;; ─── extract-type-guard ───────────────────────────────────────────────────

(it-each (("infer-extract-type-guard-known-predicates numberp" (numberp x)         x fixnum)
          ("infer-extract-type-guard-known-predicates typep"   (typep x 'my-class) x my-class))
    "~A"
    (name-ignored form expected-var expected-type-name)
  (declare (ignore name-ignored))
  (let ((ast (cl-cc/parse:lower-sexp-to-ast form)))
    (multiple-value-bind (var-name guard-type)
        (cl-cc/type:extract-type-guard ast)
      (expect var-name :to-be expected-var)
      (expect (cl-cc/type:type-primitive-name guard-type) :to-be expected-type-name))))

(it-each (("infer-extract-type-guard-returns-nil non-predicate-call" (foo x))
          ("infer-extract-type-guard-returns-nil non-call-integer"   42))
    "~A"
    (name-ignored form)
  (declare (ignore name-ignored))
  (let ((ast (cl-cc/parse:lower-sexp-to-ast form)))
    (multiple-value-bind (v g) (cl-cc/type:extract-type-guard ast)
      (expect v :to-be-null)
      (expect g :to-be-null))))

;;; ─── narrow-union-type ────────────────────────────────────────────────────

(it-sequential "infer-narrow-union-cases-removes-member"
  (let* ((union-ty (cl-cc/type:make-type-union
                     (list type-int type-string type-symbol)))
         (result (narrow-union-type union-ty type-int)))
    (expect (type-union-p result) :to-be-truthy)
    (expect (length (type-union-types result)) :to-equal 2)))

(it-sequential "infer-narrow-union-cases-collapses-to-single"
  (let* ((union-ty (cl-cc/type:make-type-union (list type-int type-string)))
         (result (narrow-union-type union-ty type-int)))
    (expect (type-primitive-p result) :to-be-truthy)
    (expect (type-primitive-name result) :to-be 'string)))

(it-sequential "infer-narrow-union-cases-non-union-passthrough"
  (let ((result (narrow-union-type type-int type-string)))
    (expect (type-primitive-name result) :to-be 'fixnum)))
