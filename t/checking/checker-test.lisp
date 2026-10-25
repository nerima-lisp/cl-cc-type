;;;; t/checker-test.lisp — checker module boundary tests

(in-package #:cl-cc/type/checking/test)

(it-sequential "checker-interface-ready"
  (expect (checker-interface-ready-p) :to-be-truthy))

(it-sequential "checker-rigid-constructor-available"
  (let ((sk (fresh-rigid-var 'alpha)))
    (expect (type-rigid-p sk) :to-be-truthy)
    (expect (type-rigid-name sk) :to-be 'alpha)))

(in-package #:cl-cc/type/checking/test)

(it-sequential "infer-check-type-unknown-returns-nil-subst"
  ;; check: any expression against +type-unknown+ returns nil substitution.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '42))
        (env (type-env-empty)))
    (let ((subst (check ast +type-unknown+ env)))
      (expect subst :to-be-null))))

(it-sequential "infer-check-forall-type-skolemizes-and-succeeds"
  ;; check: lambda against forall type skolemizes the type variable and succeeds.
  (reset-type-vars!)
  (let* ((a (fresh-type-var 'a))
         (fn-body (make-type-arrow-raw :params (list a) :return a))
         (forall-ty (make-type-forall :var a :body fn-body))
         (ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) x)))
         (env (type-env-empty)))
    (check ast forall-ty env)
    (expect t :to-be-truthy)))

(it-sequential "infer-check-skolem-escape-signals-error"
  ;; check-skolem-escape signals type-inference-error when a skolem escapes its scope.
  (let* ((sk (fresh-rigid-var "a"))
         (v (fresh-type-var 'x))
         (s (subst-extend v sk (make-substitution))))
    (signals type-inference-error
      (check-skolem-escape sk s))))

(it-sequential "infer-skolem-appears-in-subst-p"
  ;; skolem-appears-in-subst-p returns T when skolem is a value in the substitution, NIL otherwise.
  (let* ((sk (fresh-rigid-var "a"))
         (v (fresh-type-var 'x)))
    (expect (skolem-appears-in-subst-p sk (subst-extend v sk (make-substitution))) :to-be-truthy)
    (expect (skolem-appears-in-subst-p sk (subst-extend v type-int (make-substitution))) :to-be-falsy)))

(it-sequential "infer-skolem-appears-in-type-p"
  ;; skolem-appears-in-type-p returns T when skolem is in the type, NIL when absent.
  (let* ((sk (fresh-rigid-var "a"))
         (fn-with (make-type-arrow-raw
                   :params (list sk) :return type-int))
         (fn-without (make-type-arrow-raw
                      :params (list type-int) :return type-int)))
    (expect (skolem-appears-in-type-p sk fn-with) :to-be-truthy)
    (expect (skolem-appears-in-type-p sk fn-without) :to-be-falsy)))
