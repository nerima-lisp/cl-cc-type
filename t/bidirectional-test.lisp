;;;; t/bidirectional-test.lisp — Bidirectional Type Checking Tests
;;;;
;;;; Tests for src/bidirectional.lisp:
;;;; check against forall (skolemized body), type-mismatch signaling, and the
;;;; skolem-appears-in-type-p / check-skolem-escape helpers.

(in-package :cl-cc-type/test)

(it-sequential "bidirectional-check-against-forall-checks-the-skolemized-body"
  (let* ((env (cl-cc/type:type-env-empty))
         (identity-ast (cl-cc/ast:make-ast-lambda
                        :params '(x)
                        :body (list (cl-cc/ast:make-ast-var :name 'x))))
         (a (cl-cc/type:fresh-type-var :name 'a))
         (expected (cl-cc/type:make-type-forall
                    :var a
                    :body (cl-cc/type:make-type-arrow (list a) a))))
    ;; Must not signal — the identity function checks against (forall a (-> a a)).
    (expect (progn (cl-cc/type:check identity-ast expected env) t) :to-be-truthy)))

(it-sequential "bidirectional-check-signals-type-mismatch-error-on-conflicting-types"
  (let ((env (cl-cc/type:type-env-empty))
        (ast (cl-cc/ast:make-ast-int :value 1)))
    (signals cl-cc/type:type-mismatch-error
        (cl-cc/type:check ast cl-cc/type:type-string env))))

(it-sequential "skolem-appears-in-type-p-covers-every-node-kind"
  (let* ((sk (cl-cc/type:fresh-rigid-var "sk"))
         (other-sk (cl-cc/type:fresh-rigid-var "other"))
         (v (cl-cc/type:fresh-type-var)))
    (expect (cl-cc/type:skolem-appears-in-type-p sk sk) :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p sk other-sk) :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p sk v) :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-arrow (list sk) cl-cc/type:type-int))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-arrow (list cl-cc/type:type-int) sk))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-arrow (list cl-cc/type:type-int) cl-cc/type:type-int))
            :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-forall :var v :body sk))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-constructor 'list (list sk)))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-constructor 'list (list cl-cc/type:type-int)))
            :to-be-falsy)
    (expect (cl-cc/type:skolem-appears-in-type-p
             sk (cl-cc/type:make-type-product :elems (list sk)))
            :to-be-truthy)
    (expect (cl-cc/type:skolem-appears-in-type-p sk cl-cc/type:type-int) :to-be-falsy)))

(it-sequential "check-skolem-escape-signals-only-when-skolem-leaks-into-substitution"
  (let* ((sk (cl-cc/type:fresh-rigid-var "sk"))
         (v (cl-cc/type:fresh-type-var))
         (leaked-subst (cl-cc/type:subst-extend v sk (cl-cc/type:make-substitution)))
         (safe-subst (cl-cc/type:subst-extend v cl-cc/type:type-int
                                               (cl-cc/type:make-substitution))))
    (signals cl-cc/type:type-inference-error (cl-cc/type:check-skolem-escape sk leaked-subst))
    (expect (cl-cc/type:check-skolem-escape sk safe-subst) :to-be-null)
    (expect (cl-cc/type:check-skolem-escape sk nil) :to-be-null)))

(it-sequential "check-body-returns-nil-for-an-empty-form-sequence"
  ;; CHECK-BODY's (IF (NULL ASTS) NIL ...) true branch: the one call in
  ;; t/type-system-effect-test.lisp always supplies at least one form.
  (expect (cl-cc/type:check-body nil cl-cc/type:type-int (cl-cc/type:type-env-empty))
          :to-be-null))

