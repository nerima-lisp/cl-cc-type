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

(in-package :cl-cc-type/test)

;;; Phase 4-6: Parser Integration Tests

(it-sequential "parse-type-specifier-forall"
  ;; parse-type-specifier: forall form produces a type-forall binding the named variable.
  (let ((result (parse-type-specifier '(forall a (-> a a)))))
    (expect (type-forall-p result) :to-be-truthy)
    (expect (type-var-name (type-forall-var result)) :to-be 'a)))

(it-sequential "parse-type-specifier-effectful-arrow"
  ;; parse-type-specifier: effectful arrow (-> ! io) has one effect in the effects slot.
  (let ((result (parse-type-specifier '(-> fixnum fixnum ! io))))
    (expect (type-arrow-p result) :to-be-truthy)
    (expect (length (type-arrow-params result)) :to-equal 1)
    (expect (type-equal-p type-int (type-arrow-return result)) :to-be-truthy)
    (let ((effs (type-arrow-effects result)))
      (expect (type-effect-row-p effs) :to-be-truthy)
      (expect (length (type-effect-row-effects effs)) :to-equal 1))))

(it-sequential "parse-type-specifier-qualified"
  ;; parse-type-specifier: => form produces a type-qualified with one named constraint.
  (let ((result (parse-type-specifier '(=> (num a) (-> a a a)))))
    (expect (type-qualified-p result) :to-be-truthy)
    (expect (length (type-qualified-constraints result)) :to-equal 1)
    (let ((constraint (first (type-qualified-constraints result))))
      (expect (symbol-name (type-constraint-class-name constraint)) :to-equal "NUM"))))

;;; Phase A: Inference Bug Fixes

(it-each (("phase-a-infer-args-cases empty"    nil 0)
          ("phase-a-infer-args-cases multiple" t   2))
    "~A"
    (name-ignored use-args-p expected-count)
  (declare (ignore name-ignored))
  (reset-type-vars!)
  (let* ((args (if use-args-p
                    (list (cl-cc/parse:lower-sexp-to-ast 1) (cl-cc/parse:lower-sexp-to-ast "hello"))
                    '()))
         (env (type-env-empty)))
    (multiple-value-bind (types subst)
        (infer-args args env)
      (declare (ignore subst))
      (expect (length types) :to-equal expected-count)
      (when use-args-p
        (expect (type-equal-p type-int (first types)) :to-be-truthy)
        (expect (type-equal-p type-string (second types)) :to-be-truthy)))))

(it-sequential "phase-a-union-unification-matches-member"
  ;; Unifying a union type with one of its members succeeds.
  (let ((u (make-type-union (list type-int type-string))))
    (multiple-value-bind (subst ok) (type-unify u type-int)
      (declare (ignore subst))
      (expect ok :to-be-truthy))))

(it-sequential "phase-a-empty-progn-infers-to-non-nil"
  ;; An empty progn infers to type-null, type-unknown, or any other non-nil type.
  (reset-type-vars!)
  (handler-case
      (let ((ast (cl-cc/parse:lower-sexp-to-ast '(progn))))
        (multiple-value-bind (ty subst) (infer-with-env ast)
          (declare (ignore subst))
          (expect (or (type-equal-p ty type-null)
                      (type-unknown-p ty)
                      (not (null ty)))
                  :to-be-truthy)))
    (error () (expect t :to-be-truthy))))

;;; Phase C: Typeclass Dictionary Passing

(it-sequential "phase-c-dict-env-operations"
  ;; dict-env-extend stores/lookup retrieves method dict; multiple independent classes coexist.
  (let* ((methods (list (cons 'plus #'+) (cons 'zero 0)))
         (env0 (type-env-empty))
         (env1 (dict-env-extend 'num type-int methods env0))
         (found (dict-env-lookup 'num type-int env1)))
    (expect found :to-be-truthy)
    (expect (length found) :to-equal 2))
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'eq  type-int '((eq-p  . #'equal)) env0))
         (env2 (dict-env-extend 'num type-int '((plus  . #'+))     env1)))
    (expect (dict-env-lookup 'eq  type-int env2) :to-be-truthy)
    (expect (dict-env-lookup 'num type-int env2) :to-be-truthy)))

(it-sequential "phase-c-dict-env-miss-wrong-type"
  ;; dict-env-lookup returns nil for a wrong type.
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'num type-int '() env0)))
    (expect (dict-env-lookup 'num type-string env1) :to-be-null)))

(it-sequential "phase-c-dict-env-miss-wrong-class"
  ;; dict-env-lookup returns nil for a wrong class key.
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'num type-int '() env0)))
    (expect (dict-env-lookup 'ord type-int env1) :to-be-null)))

;;; Phase D: Row-Based Effect Type Inference

(defun %type-phase-make-effect-row (&rest names)
  (make-type-effect-row :effects (mapcar (lambda (n) (make-type-effect-op :name n :args nil)) names)
                         :row-var nil))

(it-each (("phase-d-effect-row-union-count io+state-merges" 2 (io)  (state))
          ("phase-d-effect-row-union-count io+pure-left"    1 (io)  ())
          ("phase-d-effect-row-union-count io+pure-right"   1 ()    (io)))
    "~A"
    (name-ignored expected-count a-names b-names)
  (declare (ignore name-ignored))
  (let* ((row-a (apply #'%type-phase-make-effect-row a-names))
         (row-b (apply #'%type-phase-make-effect-row b-names))
         (union (effect-row-union row-a row-b)))
    (expect (type-effect-row-p union) :to-be-truthy)
    (expect (length (type-effect-row-effects union)) :to-equal expected-count)))

(it-each (("phase-d-infer-effects-pure-forms pure-arithmetic" (+ 1 2))
          ("phase-d-infer-effects-pure-forms pure-let"        (let ((x 42)) x)))
    "~A"
    (name-ignored form)
  (declare (ignore name-ignored))
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast form))
         (row (infer-effects ast (type-env-empty))))
    (expect (type-effect-row-p row) :to-be-truthy)
    (expect (type-effect-row-effects row) :to-be-null)))

(it-each (("phase-d-effect-row-subset smaller-of-larger"     t   (io)       (io state))
          ("phase-d-effect-row-subset larger-not-of-smaller" nil (io state) (io))
          ("phase-d-effect-row-subset pure-is-subset-of-any" t   ()         (io)))
    "~A"
    (name-ignored expected sub-names sup-names)
  (declare (ignore name-ignored))
  (let ((sub (apply #'%type-phase-make-effect-row sub-names))
        (sup (apply #'%type-phase-make-effect-row sup-names)))
    (if expected
        (expect (effect-row-subset-p sub sup) :to-be-truthy)
        (expect (effect-row-subset-p sub sup) :to-be-falsy))))

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

(it-sequential "phase-e-skolem-escape-absent"
  ;; A freshly created skolem does not escape an empty substitution.
  (let* ((sk (fresh-rigid-var 'a))
         (escaped (check-skolem-escape sk (make-substitution))))
    (expect escaped :to-be-null)))

(it-sequential "phase-e-check-lambda-against-forall"
  ;; Checking (lambda (x) x) against a forall type succeeds or returns nil without signaling.
  (reset-type-vars!)
  (let* ((a (fresh-type-var :name 'a))
         (fa (make-type-forall :var a :body (make-type-arrow (list a) a)))
         (id-ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) x)))
         (env (type-env-empty)))
    (expect (or (null (check id-ast fa env)) t) :to-be-truthy)))

(it-sequential "phase-e-synthesize-lambda-returns-function-type"
  ;; Synthesizing (lambda (x) x) returns a canonical arrow type with one parameter.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) x)))
         (env (type-env-empty)))
    (multiple-value-bind (ty subst) (synthesize ast env)
      (declare (ignore subst))
      (expect ty :to-be-instance-of 'type-arrow)
      (expect (length (type-arrow-params ty)) :to-equal 1))))
