;;;; t/type-inference-tests.lisp — Type Inference Tests
;;;;
;;;; Covers infer-with-env over hand-lowered sexps, syntactic-value-p, if-guard
;;;; narrowing, and generalize/instantiate.
;;;;
;;;; Ported from the cl-cc monorepo's packages/type/tests/type-inference-tests.lisp.
;;;; `lower-sexp-to-ast` becomes `cl-cc/parse:lower-sexp-to-ast` now that
;;;; cl-cc-parse has its own standalone repository.
;;;;
;;;; The original file's `deftest-each` cases packed `(lambda () ...)` thunks
;;;; and evaluated AST-constructor calls into its :cases tables; that relies on
;;;; the OLD framework evaluating case tuple elements as code. cl-weave's
;;;; it-each destructuring-binds each case from a literal, UNEVALUATED data
;;;; list (see suite-each-cases in cl-weave/src/registration.lisp), so a
;;;; `(lambda () ...)` or `(cl-cc/ast:make-ast-int :value 42)` case element
;;;; would arrive as a literal list, not a closure or struct. Those cases are
;;;; ported as individual it-sequential tests instead; only the plain-sexp
;;;; case table (infer-forms-return-type-int) is safe to keep as it-each.

(in-package :cl-cc-type/test)

;;; Type Inference Tests

(it-each (("infer-forms-return-type-int integer-literal"   42)
          ("infer-forms-return-type-int binop-addition"     (+ 1 2))
          ("infer-forms-return-type-int binop-nested"       (+ (* 2 3) (- 4 1)))
          ("infer-forms-return-type-int let-simple"         (let ((x 42)) x))
          ("infer-forms-return-type-int let-multi-binop"    (let ((x 10) (y 20)) (+ x y)))
          ("infer-forms-return-type-int function-call"      (let ((f (lambda (x) (+ x 1)))) (f 5)))
          ("infer-forms-return-type-int print-expr"         (print 42))
          ("infer-forms-return-type-int progn-last"         (progn 1 2 3))
          ("infer-forms-return-type-int let-poly-identity"  (let ((id (lambda (x) x))) (id 42))))
    "~A"
    (name-ignored form)
  (declare (ignore name-ignored))
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast form)))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-env-and-control-flow-variable-from-env"
  ;; Variable env lookup infers declared type.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast 'x))
         (env (type-env-extend 'x (type-to-scheme type-int) (type-env-empty))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-env-and-control-flow-if-expression"
  ;; if-expr unifies branches when condition is bool.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast '(if cond-var 1 2)))
         (env (type-env-extend 'cond-var
                                (type-to-scheme type-bool)
                                (type-env-empty))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-type-error-signals-unbound-var"
  ;; Unbound variables signal unbound-variable-error.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast 'undefined-var)))
    (signals unbound-variable-error
      (infer-with-env ast))))

(it-sequential "infer-type-error-signals-typed-hole"
  ;; Typed holes signal typed-hole-error.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast '(+ x _)))
         (env (type-env-extend 'x (type-to-scheme type-int) (type-env-empty))))
    (signals typed-hole-error
      (infer ast env))))

(it-sequential "infer-lambda"
  ;; Lambda types inferred as function type: identity has 1 param; arithmetic constrains to int.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) x))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-instance-of 'type-arrow)
      (expect (length (type-arrow-params ty)) :to-equal 1)))
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(lambda (x) (+ x 1)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-instance-of 'type-arrow)
      (expect (type-arrow-return ty) :to-be-type-equal-to type-int)
      (expect (first (type-arrow-params ty)) :to-be-type-equal-to type-int))))

(it-sequential "infer-quote-type-symbol"
  ;; Quoted forms infer to the type corresponding to their datum.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(quote hello))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-symbol))))

(it-sequential "infer-quote-type-integer"
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(quote 42))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

;;; ─── syntactic-value-p (value restriction) ──────────────────────────────────

(it-sequential "infer-syntactic-value-p-truthy"
  ;; Syntactic values: int, var, lambda, quote, function-ref, typed-hole are generalizable.
  (expect (syntactic-value-p (cl-cc/ast:make-ast-int :value 42)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-var :name 'x)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-lambda :params '(x) :body nil)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-quote :value 'foo)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-function :name 'f)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-hole)) :to-be-truthy))

(it-sequential "infer-syntactic-value-p-falsy"
  ;; Non-syntactic values: call, binop, if, let, progn are not generalizable (value restriction).
  (expect (syntactic-value-p (cl-cc/ast:make-ast-call :func 'f :args nil)) :to-be-falsy)
  (expect (syntactic-value-p
           (cl-cc/ast:make-ast-binop :op '+ :lhs (cl-cc/ast:make-ast-int :value 1)
                                             :rhs (cl-cc/ast:make-ast-int :value 2)))
          :to-be-falsy)
  (expect (syntactic-value-p
           (cl-cc/ast:make-ast-if :cond (cl-cc/ast:make-ast-var :name 'c)
                                   :then (cl-cc/ast:make-ast-int :value 1)
                                   :else (cl-cc/ast:make-ast-int :value 2)))
          :to-be-falsy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-let :bindings nil :body nil)) :to-be-falsy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-progn :forms nil)) :to-be-falsy))

;;; ─── infer-if type narrowing ──────────────────────────────────────────────────

(it-sequential "infer-if-narrows-type-in-then-branch"
  ;; infer-if narrows the guard variable's type to the predicate type in the then branch.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast '(if (numberp x) (+ x 1) 0)))
         (env (type-env-extend 'x
                                (make-type-scheme nil
                                                   (make-type-union (list type-int type-string)))
                                (type-env-empty))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-truthy))))

(it-sequential "infer-if-no-narrowing-without-predicate"
  ;; infer-if with a plain boolean condition (no predicate call) leaves types unchanged.
  (reset-type-vars!)
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast '(if flag 1 2)))
         (env (type-env-extend 'flag (type-to-scheme type-bool) (type-env-empty))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

;;; Generalization / Instantiation Tests

(it-sequential "generalize-and-scheme-ops-nil-env-quantifies-all"
  (let* ((v (fresh-type-var :name 'a))
         (fn (make-type-arrow-raw :params (list v) :return v))
         (s (generalize nil fn)))
    (expect s :to-be-instance-of 'type-scheme)
    (expect (length (type-scheme-quantified-vars s)) :to-equal 1)))

(it-sequential "generalize-and-scheme-ops-non-nil-env-excludes"
  (let* ((v1 (fresh-type-var :name 'a))
         (v2 (fresh-type-var :name 'b))
         (fn (make-type-arrow-raw :params (list v1) :return v2))
         (env (type-env-extend 'x (type-to-scheme v1) (type-env-empty)))
         (s (generalize env fn)))
    (expect (length (type-scheme-quantified-vars s)) :to-equal 1)
    (expect (type-var-equal-p (first (type-scheme-quantified-vars s)) v2) :to-be-truthy)))

(it-sequential "generalize-and-scheme-ops-instantiate-fresh-vars"
  (let* ((v (fresh-type-var :name 'a))
         (fn-type (make-type-arrow-raw :params (list v) :return v))
         (scheme (make-type-scheme (list v) fn-type))
         (inst (instantiate scheme)))
    (expect inst :to-be-instance-of 'type-arrow)
    (let ((new-param (first (type-arrow-params inst)))
          (new-ret (type-arrow-return inst)))
      (expect new-param :to-be-instance-of 'type-var)
      (expect (type-var-equal-p new-param v) :to-be-falsy)
      (expect (type-var-equal-p new-param new-ret) :to-be-truthy))))

(it-sequential "generalize-and-scheme-ops-monomorphic-scheme"
  (let ((scheme (type-to-scheme type-int)))
    (expect scheme :to-be-instance-of 'type-scheme)
    (expect (type-scheme-quantified-vars scheme) :to-be-null)
    (expect (type-scheme-type scheme) :to-be-type-equal-to type-int)))
