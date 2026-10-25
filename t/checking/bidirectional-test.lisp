;;;; t/bidirectional-test.lisp — Bidirectional Type Checking Tests
;;;;
;;;; Tests for src/bidirectional.lisp:
;;;; check against forall (skolemized body), type-mismatch signaling, and the
;;;; skolem-appears-in-type-p / check-skolem-escape helpers.

(in-package #:cl-cc/type/checking/test)

(it-sequential "bidirectional-check-against-forall-checks-the-skolemized-body"
  (let* ((env (type-env-empty))
         (identity-ast (cl-cc/ast:make-ast-lambda
                        :params '(x)
                        :body (list (cl-cc/ast:make-ast-var :name 'x))))
         (a (fresh-type-var :name 'a))
         (expected (make-type-forall
                    :var a
                    :body (make-type-arrow (list a) a))))
    ;; Must not signal — the identity function checks against (forall a (-> a a)).
    (expect (progn (check identity-ast expected env) t) :to-be-truthy)))

(it-sequential "bidirectional-check-signals-type-mismatch-error-on-conflicting-types"
  (let ((env (type-env-empty))
        (ast (cl-cc/ast:make-ast-int :value 1)))
    (signals type-mismatch-error
        (check ast type-string env))))

(it-sequential "skolem-appears-in-type-p-covers-every-node-kind"
  (let* ((sk (fresh-rigid-var "sk"))
         (other-sk (fresh-rigid-var "other"))
         (v (fresh-type-var)))
    (expect (skolem-appears-in-type-p sk sk) :to-be-truthy)
    (expect (skolem-appears-in-type-p sk other-sk) :to-be-falsy)
    (expect (skolem-appears-in-type-p sk v) :to-be-falsy)
    (expect (skolem-appears-in-type-p
             sk (make-type-arrow (list sk) type-int))
            :to-be-truthy)
    (expect (skolem-appears-in-type-p
             sk (make-type-arrow (list type-int) sk))
            :to-be-truthy)
    (expect (skolem-appears-in-type-p
             sk (make-type-arrow (list type-int) type-int))
            :to-be-falsy)
    (expect (skolem-appears-in-type-p
             sk (make-type-forall :var v :body sk))
            :to-be-truthy)
    (expect (skolem-appears-in-type-p
             sk (make-type-constructor 'list (list sk)))
            :to-be-truthy)
    (expect (skolem-appears-in-type-p
             sk (make-type-constructor 'list (list type-int)))
            :to-be-falsy)
    (expect (skolem-appears-in-type-p
             sk (make-type-product :elems (list sk)))
            :to-be-truthy)
    (expect (skolem-appears-in-type-p sk type-int) :to-be-falsy)))

(it-sequential "check-skolem-escape-signals-only-when-skolem-leaks-into-substitution"
  (let* ((sk (fresh-rigid-var "sk"))
         (v (fresh-type-var))
         (leaked-subst (subst-extend v sk (make-substitution)))
         (safe-subst (subst-extend v type-int
                                               (make-substitution))))
    (signals type-inference-error (check-skolem-escape sk leaked-subst))
    (expect (check-skolem-escape sk safe-subst) :to-be-null)
    (expect (check-skolem-escape sk nil) :to-be-null)))

(it-sequential "check-body-returns-nil-for-an-empty-form-sequence"
  ;; CHECK-BODY's (IF (NULL ASTS) NIL ...) true branch: the one call in
  ;; t/type-system-effect-test.lisp always supplies at least one form.
  (expect (check-body nil type-int (type-env-empty))
          :to-be-null))

(in-package cl-cc/type/checking/test)

(it-sequential "bidirectional-checking-check-body-verifies-last-form"
  (let* ((env (type-env-empty))
         (ast1 (make-ast-int :value 1))
         (ast2 (make-ast-int :value 2)))
    (expect (null (check-body (list ast1 ast2) type-int env)) :to-be-truthy)))

(it-sequential "bidirectional-checking-synthesize-and-check-integer"
  (let* ((env (type-env-empty))
         (ast (make-ast-int :value 42)))
    (multiple-value-bind (ty _subst) (synthesize ast env)
      (declare (ignore _subst))
      (expect ty :to-be-type-equal-to type-int))
    (expect (null (check ast type-int env)) :to-be-truthy)
    (expect (null (check ast +type-unknown+ env)) :to-be-truthy)))

(it-sequential "phase-e-synthesize-lambda-returns-function-type"
  ;; Synthesizing (lambda (x) x) returns a canonical arrow type with one parameter.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) x)))
         (env (type-env-empty)))
    (multiple-value-bind (ty subst) (synthesize ast env)
      (declare (ignore subst))
      (expect ty :to-be-instance-of 'type-arrow)
      (expect (length (type-arrow-params ty)) :to-equal 1))))

(it-sequential "phase-e-check-lambda-against-forall"
  ;; Checking (lambda (x) x) against a forall type succeeds or returns nil without signaling.
  (reset-type-vars!)
  (let* ((a (fresh-type-var :name 'a))
         (fa (make-type-forall :var a :body (make-type-arrow (list a) a)))
         (id-ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) x)))
         (env (type-env-empty)))
    (expect (or (null (check id-ast fa env)) t) :to-be-truthy)))

(it-sequential "phase-e-skolem-escape-absent"
  ;; A freshly created skolem does not escape an empty substitution.
  (let* ((sk (fresh-rigid-var 'a))
         (escaped (check-skolem-escape sk (make-substitution))))
    (expect escaped :to-be-null)))
