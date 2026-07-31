;;;; t/type-system-inference-test.lisp - Type System Inference Tests
;;;;
;;;; Direct-dispatch AST inference tests for the HM type system, split out of
;;;; t/type-system-test.lisp: infer / synthesize / infer-with-env driven directly
;;;; off hand-built AST nodes (the `infer` typecase dispatcher in
;;;; inference-handlers.lisp and its infer-* handlers in inference-forms.lisp /
;;;; inference-forms-advanced-init.lisp), as opposed to t/type-system-test.lisp's
;;;; constraint-collection (collect/solve) Algorithm W tests.

(in-package :cl-cc-type/test)

;;; ─── Direct-Dispatch AST Inference Tests (infer / synthesize / infer-with-env) ─
;;;
;;; The tests above exercise Algorithm W via the constraint-collection pipeline
;;; (collect/solve). These tests instead drive the *direct-dispatch* inference
;;; chain (the `infer` typecase dispatcher in inference-handlers.lisp and its
;;; infer-* handlers in inference-forms.lisp / inference-forms-advanced-init.lisp)
;;; by building AST nodes directly and calling infer / infer-with-env / synthesize.

(it-sequential "infer-ast-int-is-type-int"
  (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-int :value 42))
    (declare (ignore subst))
    (expect ty :to-be-type-equal-to type-int)))

(it-sequential "infer-ast-var-bound-and-unbound"
  (let ((env (type-env-extend 'x (make-type-scheme nil type-int) (type-env-empty))))
    (multiple-value-bind (ty subst) (infer (cl-cc/ast:make-ast-var :name 'x) env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)))
  (signals unbound-variable-error
      (infer-with-env (cl-cc/ast:make-ast-var :name 'nowhere-to-be-found))))

(progn
  (it-sequential "infer-ast-quote-cases int"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value 7))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)))
  (it-sequential "infer-ast-quote-cases string"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value "hi"))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-string)))
  (it-sequential "infer-ast-quote-cases symbol"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value 'foo))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-symbol)))
  (it-sequential "infer-ast-quote-cases cons"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value '(1 2)))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-cons)))
  (it-sequential "infer-ast-quote-cases unknown-fallback"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value #\a))
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy))))

(it-sequential "infer-ast-if-unifies-matching-branches"
  (let ((ast (cl-cc/ast:make-ast-if
              :cond (cl-cc/ast:make-ast-var :name 'b)
              :then (cl-cc/ast:make-ast-int :value 1)
              :else (cl-cc/ast:make-ast-int :value 2)))
        (env (type-env-extend 'b (make-type-scheme nil type-bool) (type-env-empty))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-if-narrows-union-type-via-type-guard"
  ;; env: v :: (or fixnum string). (if (integerp v) v 0) exercises the guard
  ;; narrowing that binds v :: fixnum inside the then-branch (and, via
  ;; %build-if-branch-envs / %narrow-else-env, narrows v to the remaining
  ;; union member inside the else-branch even though it is unused there).
  ;; Without narrowing, the then-branch's union-typed v would fail to unify
  ;; with the else-branch's plain fixnum literal.
  (let* ((union-ty (make-type-union (list type-int type-string)))
         (env (type-env-extend 'v (make-type-scheme nil union-ty) (type-env-empty)))
         (guard-cond (cl-cc/ast:make-ast-call
                      :func (cl-cc/ast:make-ast-var :name 'integerp)
                      :args (list (cl-cc/ast:make-ast-var :name 'v))))
         (ast (cl-cc/ast:make-ast-if
               :cond guard-cond
               :then (cl-cc/ast:make-ast-var :name 'v)
               :else (cl-cc/ast:make-ast-int :value 0))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "extract-type-guard-recognizes-predicate-and-typep-patterns"
  (let ((predicate-guard (cl-cc/ast:make-ast-call
                           :func (cl-cc/ast:make-ast-var :name 'stringp)
                           :args (list (cl-cc/ast:make-ast-var :name 'v))))
        (typep-guard (cl-cc/ast:make-ast-call
                      :func (cl-cc/ast:make-ast-var :name 'typep)
                      :args (list (cl-cc/ast:make-ast-var :name 'v)
                                  (cl-cc/ast:make-ast-quote :value 'point))))
        (non-guard (cl-cc/ast:make-ast-var :name 'v)))
    (multiple-value-bind (var ty) (extract-type-guard predicate-guard)
      (expect var :to-be 'v)
      (expect ty :to-be-type-equal-to type-string))
    (multiple-value-bind (var ty) (extract-type-guard typep-guard)
      (expect var :to-be 'v)
      (expect (type-primitive-p ty) :to-be-truthy)
      (expect (type-primitive-name ty) :to-be 'point))
    (multiple-value-bind (var ty) (extract-type-guard non-guard)
      (expect var :to-be-null)
      (expect ty :to-be-null))
    ;; NON-GUARD above fails EXTRACT-TYPE-GUARD's outer (typep cond-ast
    ;; 'ast-call) check entirely, never reaching the inner COND at all, so
    ;; its final (T (VALUES NIL NIL)) fallback clause is still untested:
    ;; an AST-CALL shaped like neither the (predicate var) nor the
    ;; (typep var 'classname) pattern (two args, not named TYPEP).
    (let ((unrecognized-shape (cl-cc/ast:make-ast-call
                                :func (cl-cc/ast:make-ast-var :name 'some-other-fn)
                                :args (list (cl-cc/ast:make-ast-var :name 'v)
                                            (cl-cc/ast:make-ast-var :name 'w)))))
      (multiple-value-bind (var ty) (extract-type-guard unrecognized-shape)
        (expect var :to-be-null)
        (expect ty :to-be-null))))
  ;; A call genuinely named TYPEP but with the wrong arity: the (EQ ...
  ;; 'TYPEP) conjunct above is TRUE here, unlike UNRECOGNIZED-SHAPE, so
  ;; this reaches the typep-clause's own (= (LENGTH ARGS) 2) conjunct and
  ;; is the first case to make it false. Three args, not one: with a
  ;; single arg this would also satisfy the EARLIER (predicate var)
  ;; clause's own (= (LENGTH ARGS) 1) test (TYPEP looks like any other
  ;; predicate name there), matching that clause instead and never
  ;; reaching this one at all.
  (let ((wrong-arity-typep (cl-cc/ast:make-ast-call
                            :func (cl-cc/ast:make-ast-var :name 'typep)
                            :args (list (cl-cc/ast:make-ast-var :name 'v)
                                        (cl-cc/ast:make-ast-quote :value 'point)
                                        (cl-cc/ast:make-ast-var :name 'extra)))))
    (multiple-value-bind (var ty) (extract-type-guard wrong-arity-typep)
      (expect var :to-be-null)
      (expect ty :to-be-null)))
  ;; Right arity, but the first arg isn't an AST-VAR: the false branch of
  ;; (TYPEP (FIRST ARGS) 'AST-VAR), never reached by any case above.
  (let ((non-var-first-arg (cl-cc/ast:make-ast-call
                            :func (cl-cc/ast:make-ast-var :name 'typep)
                            :args (list (cl-cc/ast:make-ast-int :value 1)
                                        (cl-cc/ast:make-ast-quote :value 'point)))))
    (multiple-value-bind (var ty) (extract-type-guard non-var-first-arg)
      (expect var :to-be-null)
      (expect ty :to-be-null)))
  ;; First arg is an AST-VAR, but the second isn't an AST-QUOTE: the false
  ;; branch of (TYPEP (SECOND ARGS) 'AST-QUOTE).
  (let ((non-quote-second-arg (cl-cc/ast:make-ast-call
                               :func (cl-cc/ast:make-ast-var :name 'typep)
                               :args (list (cl-cc/ast:make-ast-var :name 'v)
                                           (cl-cc/ast:make-ast-var :name 'w)))))
    (multiple-value-bind (var ty) (extract-type-guard non-quote-second-arg)
      (expect var :to-be-null)
      (expect ty :to-be-null))))

(it-sequential "narrow-union-type-removes-and-collapses-members"
  (let ((union-ty (make-type-union (list type-int type-string type-symbol))))
    (let ((remaining (narrow-union-type union-ty type-int)))
      (expect (type-union-p remaining) :to-be-truthy)
      (expect (length (type-union-types remaining)) :to-equal 2)))
  (let* ((two-ty (make-type-union (list type-int type-string)))
         (remaining (narrow-union-type two-ty type-int)))
    (expect remaining :to-be-type-equal-to type-string))
  ;; Non-union types pass through unchanged.
  (expect (narrow-union-type type-int type-string) :to-be-type-equal-to type-int)
  ;; Removing a union's only member leaves nothing to narrow to. Identity
  ;; comparison, not TYPE-EQUAL-P: type-error nodes (which is what
  ;; +TYPE-UNKNOWN+ is) are deliberately never TYPE-EQUAL-P to anything,
  ;; even themselves (see types-extended-nodes-test.lisp's
  ;; type-equal-error-node-never-equal), so :TO-BE-TYPE-EQUAL-TO would
  ;; fail here regardless of correctness.
  (expect (narrow-union-type (make-type-union (list type-int)) type-int)
          :to-be cl-cc/type:+type-unknown+))

(it-sequential "narrow-else-env-only-narrows-when-the-guard-var-is-a-bound-union"
  ;; The AND's first conjunct (VAR-TYPE) is false when the guard var isn't
  ;; bound in BASE-ENV at all; when it IS bound but to a non-union type,
  ;; the conjunct reaches (and passes) VAR-TYPE but fails the TYPEP check.
  ;; The pre-existing if-narrowing test only drives the "both true" case.
  (let ((empty-env (cl-cc/type:type-env-empty)))
    (expect (cl-cc/type::%narrow-else-env 'v type-int empty-env) :to-be empty-env))
  (let* ((env (cl-cc/type:type-env-extend 'v (cl-cc/type:make-type-scheme nil type-int)
                                          (cl-cc/type:type-env-empty))))
    (expect (cl-cc/type::%narrow-else-env 'v type-int env) :to-be env)))

(it-sequential "make-lambda-param-env-returns-the-env-unchanged-for-no-params"
  (let ((env (cl-cc/type:type-env-empty)))
    (multiple-value-bind (types body-env) (cl-cc/type::%make-lambda-param-env nil env)
      (expect types :to-be-null)
      (expect body-env :to-be env))))

(it-sequential "register-and-lookup-type-predicate"
  (let ((marker-type (make-type-primitive :name 'marker-test-type)))
    (register-type-predicate 'marker-test-type-p marker-type)
    (expect (cl-cc/type::type-predicate-to-type 'marker-test-type-p) :to-be-type-equal-to marker-type)))

(it-sequential "infer-ast-let-generalizes-syntactic-values"
  ;; (let ((x 1)) x) — x is bound to a syntactic value (int literal) and may be
  ;; generalized under the value restriction (FR-1604).
  (let ((ast (cl-cc/ast:make-ast-let
              :bindings (list (cons 'x (cl-cc/ast:make-ast-int :value 1)))
              :body (list (cl-cc/ast:make-ast-var :name 'x)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-let-keeps-applications-monomorphic"
  ;; (let ((x (f 1))) x) — x is bound to a call (not a syntactic value), so the
  ;; value restriction keeps its scheme monomorphic.
  (let* ((f-type (make-type-arrow (list type-int) type-int))
         (env (type-env-extend 'f (make-type-scheme nil f-type) (type-env-empty)))
         (ast (cl-cc/ast:make-ast-let
               :bindings (list (cons 'x (cl-cc/ast:make-ast-call
                                          :func (cl-cc/ast:make-ast-var :name 'f)
                                          :args (list (cl-cc/ast:make-ast-int :value 1)))))
               :body (list (cl-cc/ast:make-ast-var :name 'x)))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "syntactic-value-p-classifies-ast-nodes"
  (expect (syntactic-value-p (cl-cc/ast:make-ast-int :value 1)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-var :name 'x)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-quote :value 1)) :to-be-truthy)
  (expect (syntactic-value-p (cl-cc/ast:make-ast-lambda :params nil :body nil)) :to-be-truthy)
  (expect (syntactic-value-p
           (cl-cc/ast:make-ast-call :func (cl-cc/ast:make-ast-var :name 'f) :args nil))
          :to-be-falsy))

(it-sequential "infer-ast-lambda-produces-arrow-type"
  (let ((ast (cl-cc/ast:make-ast-lambda
              :params '(x)
              :body (list (cl-cc/ast:make-ast-var :name 'x)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (= (length (type-arrow-params ty)) 1) :to-equal t))))

(it-sequential "infer-ast-progn-returns-last-form-type"
  (let ((ast (cl-cc/ast:make-ast-progn
              :forms (list (cl-cc/ast:make-ast-int :value 1)
                           (cl-cc/ast:make-ast-quote :value "last")))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-string))))

(it-sequential "infer-ast-print-returns-printed-expression-type"
  (let ((ast (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 9))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-the-matches-and-mismatches"
  (let ((ok-ast (cl-cc/ast:make-ast-the :type 'fixnum :value (cl-cc/ast:make-ast-int :value 1))))
    (multiple-value-bind (ty subst) (infer-with-env ok-ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)))
  (let ((bad-ast (cl-cc/ast:make-ast-the :type 'string :value (cl-cc/ast:make-ast-int :value 1))))
    (signals type-mismatch-error (infer-with-env bad-ast))))

(it-sequential "infer-ast-setq-declared-and-undeclared"
  (let* ((env (type-env-extend 'x (make-type-scheme nil type-int) (type-env-empty)))
         (ast (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 3))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)))
  (let ((ast (cl-cc/ast:make-ast-setq :var 'undeclared :value (cl-cc/ast:make-ast-int :value 3))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-setq-signals-type-mismatch-against-a-declared-type"
  ;; The pre-existing case above only ever assigns a value matching the
  ;; declared type; INFER-SETQ's own TYPE-UNIFY failure branch (assigning a
  ;; value that conflicts with the variable's declared type) had no test.
  (let* ((env (type-env-extend 'x (make-type-scheme nil type-string) (type-env-empty)))
         (ast (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 3))))
    (signals type-mismatch-error (infer ast env))))

(it-sequential "infer-ast-binop-adds-two-ints"
  (let ((ast (cl-cc/ast:make-ast-binop :op '+
                                       :lhs (cl-cc/ast:make-ast-int :value 1)
                                       :rhs (cl-cc/ast:make-ast-int :value 2))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-defun-declared-and-inferred"
  (let ((declared-ast (cl-cc/ast:make-ast-defun
                        :name 'f
                        :params '(x)
                        :declarations (list '(type (-> fixnum fixnum) f))
                        :body (list (cl-cc/ast:make-ast-var :name 'x)))))
    (multiple-value-bind (ty subst) (infer-with-env declared-ast)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy)))
  (let ((inferred-ast (cl-cc/ast:make-ast-defun
                        :name nil
                        :params '(x y)
                        :body (list (cl-cc/ast:make-ast-binop
                                     :op '+
                                     :lhs (cl-cc/ast:make-ast-var :name 'x)
                                     :rhs (cl-cc/ast:make-ast-var :name 'y))))))
    (multiple-value-bind (ty subst) (infer-with-env inferred-ast)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (= (length (type-arrow-params ty)) 2) :to-equal t))))

(it-sequential "infer-ast-defvar-always-type-symbol"
  (expect (infer-with-env (cl-cc/ast:make-ast-defvar :name '*x* :value nil)) :to-be-type-equal-to type-symbol)
  (expect (infer-with-env
                          (cl-cc/ast:make-ast-defvar :name '*y*
                                                     :value (cl-cc/ast:make-ast-int :value 1))) :to-be-type-equal-to type-symbol))

(it-sequential "infer-ast-function-found-and-not-found"
  (let* ((f-type (make-type-arrow (list type-int) type-int))
         (env (type-env-extend 'f (make-type-scheme nil f-type) (type-env-empty))))
    (multiple-value-bind (ty subst) (infer (cl-cc/ast:make-ast-function :name 'f) env)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy)))
  (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-function :name 'unknown-fn))
    (declare (ignore subst))
    (expect (type-unknown-p ty) :to-be-truthy)))

(it-sequential "infer-ast-flet-binds-local-function"
  (let ((ast (cl-cc/ast:make-ast-flet
              :bindings (list (list 'f '(x) (cl-cc/ast:make-ast-var :name 'x)))
              :body (list (cl-cc/ast:make-ast-call
                           :func (cl-cc/ast:make-ast-var :name 'f)
                           :args (list (cl-cc/ast:make-ast-int :value 5)))))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-labels-supports-mutual-reference"
  ;; Both bindings are seeded with fresh type variables before either is
  ;; inferred (pass 1), then inferred in binding order against that shared
  ;; mutual environment (pass 2): h first (self-contained), then g (which
  ;; calls h and therefore observes h's already-generalized scheme).
  (let ((ast (cl-cc/ast:make-ast-labels
              :bindings (list (list 'h '(y) (cl-cc/ast:make-ast-var :name 'y))
                              (list 'g '(x)
                                    (cl-cc/ast:make-ast-call
                                     :func (cl-cc/ast:make-ast-var :name 'h)
                                     :args (list (cl-cc/ast:make-ast-var :name 'x)))))
              :body (list (cl-cc/ast:make-ast-call
                           :func (cl-cc/ast:make-ast-var :name 'g)
                           :args (list (cl-cc/ast:make-ast-int :value 1)))))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-block-and-return-from"
  (let ((ast (cl-cc/ast:make-ast-block
              :name 'blk
              :body (list (cl-cc/ast:make-ast-return-from
                           :name 'blk
                           :value (cl-cc/ast:make-ast-int :value 1))))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-defclass-defmethod-make-instance-slot-value"
  (let ((defclass-ast (cl-cc/ast:make-ast-defclass
                        :name 'point-test
                        :slots (list (cl-cc/ast:make-ast-slot-def :name 'x :type 'fixnum)))))
    (multiple-value-bind (ty subst) (infer-with-env defclass-ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-symbol)))
  (expect (lookup-slot-type 'point-test 'x) :to-be-type-equal-to type-int)
  (let ((defmethod-ast (cl-cc/ast:make-ast-defmethod
                         :name 'area
                         :specializers (list (cons 'obj 'point-test))
                         :params '(obj)
                         :body nil)))
    (multiple-value-bind (ty subst) (infer-with-env defmethod-ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-symbol)))
  (expect (lookup-class-method-type 'point-test 'area) :to-be-type-equal-to type-any)
  (let ((make-instance-ast (cl-cc/ast:make-ast-make-instance
                             :class (cl-cc/ast:make-ast-quote :value 'point-test)
                             :initargs nil)))
    (multiple-value-bind (ty subst) (infer-with-env make-instance-ast)
      (declare (ignore subst))
      (expect (type-primitive-p ty) :to-be-truthy)
      (expect (type-primitive-name ty) :to-be 'point-test)))
  (let* ((env (type-env-extend 'obj
                               (make-type-scheme nil (make-type-primitive :name 'point-test))
                               (type-env-empty)))
         (slot-value-ast (cl-cc/ast:make-ast-slot-value
                          :object (cl-cc/ast:make-ast-var :name 'obj)
                          :slot 'x)))
    (multiple-value-bind (ty subst) (infer slot-value-ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-ast-hole-signals-typed-hole-error"
  (signals typed-hole-error
      (infer-with-env (cl-cc/ast:make-ast-hole))))

(it-sequential "infer-call-applies-function-and-checks-argument-types"
  (let* ((f-type (make-type-arrow (list type-int) type-int))
         (env (type-env-extend 'f (make-type-scheme nil f-type) (type-env-empty)))
         (ok-ast (cl-cc/ast:make-ast-call
                  :func (cl-cc/ast:make-ast-var :name 'f)
                  :args (list (cl-cc/ast:make-ast-int :value 1)))))
    (multiple-value-bind (ty subst) (infer ok-ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)))
  (let* ((f-type (make-type-arrow (list type-int) type-int))
         (env (type-env-extend 'f (make-type-scheme nil f-type) (type-env-empty)))
         (bad-ast (cl-cc/ast:make-ast-call
                   :func (cl-cc/ast:make-ast-var :name 'f)
                   :args (list (cl-cc/ast:make-ast-quote :value "not an int")))))
    (signals type-mismatch-error (infer bad-ast env))))

(it-sequential "annotate-type-returns-inferred-type-and-original-ast"
  (let ((ast (cl-cc/ast:make-ast-int :value 5)))
    (multiple-value-bind (ty annotated) (annotate-type ast (type-env-empty))
      (expect ty :to-be-type-equal-to type-int)
      (expect (eq annotated ast) :to-be-truthy))))

;;; ─── Additional infer-handlers.lisp branch coverage ────────────────────────

(it-sequential "infer-var-resolves-via-type-interface-export-when-unbound-in-env"
  ;; infer-var's second lookup path: the name is absent from the local env,
  ;; but has been registered as an imported interface export, so it should
  ;; resolve through lookup-type-interface-export rather than signalling
  ;; unbound-variable-error.
  (register-type-interface 'inference-handlers-test-module
                            '((inference-handlers-test-export fixnum))
                            "fingerprint-inference-handlers-test")
  (multiple-value-bind (ty subst)
      (infer (cl-cc/ast:make-ast-var :name 'inference-handlers-test-export) (type-env-empty))
    (declare (ignore subst))
    (expect ty :to-be-type-equal-to type-int)))

(it-sequential "infer-defmethod-skips-t-and-non-symbol-specializers-registers-bare-symbol-under-nil"
  ;; Specializer class-name = T: symbolp is true but (member 'T '(T)) matches,
  ;; so registration is skipped.
  (infer-with-env (cl-cc/ast:make-ast-defmethod
                    :name 'skip-t-area
                    :specializers (list (cons 'obj t))
                    :params '(obj)
                    :body nil))
  (expect (lookup-class-method-type t 'skip-t-area) :to-be-null)
  ;; Specializer whose cdr is a non-symbol class-name (a list): symbolp is
  ;; false, so registration is skipped.
  (infer-with-env (cl-cc/ast:make-ast-defmethod
                    :name 'skip-nonsymbol-area
                    :specializers (list (cons 'obj '(eql 42)))
                    :params '(obj)
                    :body nil))
  (expect (lookup-class-method-type '(eql 42) 'skip-nonsymbol-area) :to-be-null)
  ;; Specializer that isn't a cons at all: class-name becomes NIL via the
  ;; (and (consp spec) ...) short-circuit. NIL is itself a symbol and is not
  ;; EQ to T, so the WHEN body still runs and registers under class-name NIL.
  (infer-with-env (cl-cc/ast:make-ast-defmethod
                    :name 'registers-under-nil
                    :specializers (list 'obj)
                    :params '(obj)
                    :body nil))
  (expect (lookup-class-method-type nil 'registers-under-nil) :to-be-type-equal-to type-any))

(it-sequential "infer-make-instance-falls-back-to-unknown-for-non-quote-or-non-symbol-class"
  ;; class-expr is not an ast-quote node at all -> falls through to +type-unknown+.
  (let ((ast (cl-cc/ast:make-ast-make-instance
              :class (cl-cc/ast:make-ast-var :name 'dynamic-class)
              :initargs nil)))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy)))
  ;; class-expr is an ast-quote, but its value isn't a symbol -> also unknown.
  (let ((ast (cl-cc/ast:make-ast-make-instance
              :class (cl-cc/ast:make-ast-quote :value 42)
              :initargs nil)))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy))))

(it-sequential "infer-slot-value-falls-back-to-unknown-for-non-primitive-object-and-unregistered-slot"
  ;; TYPE-INT is itself a TYPE-PRIMITIVE struct (see types-extended-nodes.lisp),
  ;; so this case and the one below it both actually hit INFER-SLOT-VALUE's
  ;; (TYPEP OBJ-TYPE 'TYPE-PRIMITIVE) TRUE branch with an unregistered
  ;; class/slot pair -- LOOKUP-SLOT-TYPE returns NIL, the OR falls through to
  ;; +TYPE-UNKNOWN+. Neither ever drove the outer IF's own FALSE branch (an
  ;; object whose type isn't TYPE-PRIMITIVE at all); the case after them does.
  (let* ((env (type-env-extend 'n (make-type-scheme nil type-int) (type-env-empty)))
         (ast (cl-cc/ast:make-ast-slot-value
               :object (cl-cc/ast:make-ast-var :name 'n)
               :slot 'whatever)))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy)))
  ;; obj-type is a type-primitive, but the class/slot pair isn't registered ->
  ;; also +type-unknown+ (lookup-slot-type returns NIL, the OR falls through).
  (let* ((env (type-env-extend
               'obj
               (make-type-scheme nil (make-type-primitive :name 'unregistered-class-test))
               (type-env-empty)))
         (ast (cl-cc/ast:make-ast-slot-value
               :object (cl-cc/ast:make-ast-var :name 'obj)
               :slot 'missing-slot)))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy)))
  ;; obj-type is not a TYPE-PRIMITIVE at all (a TYPE-ARROW here) -> the
  ;; outer IF's FALSE branch, never reached by either case above.
  (let* ((env (type-env-extend
               'f (make-type-scheme nil (make-type-arrow (list type-int) type-int))
               (type-env-empty)))
         (ast (cl-cc/ast:make-ast-slot-value
               :object (cl-cc/ast:make-ast-var :name 'f)
               :slot 'whatever)))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect (type-unknown-p ty) :to-be-truthy))))

(it-sequential "typed-hole-error-message-lists-available-bindings"
  (let ((env (type-env-extend
              'x (make-type-scheme nil type-int)
              (type-env-extend 'y (make-type-scheme nil type-string) (type-env-empty)))))
    (handler-case
        (progn (infer (cl-cc/ast:make-ast-hole) env)
               (error "expected typed-hole-error to be signalled"))
      (typed-hole-error (e)
        (let ((msg (type-inference-error-message e)))
          (expect (search "X ::" msg) :to-be-truthy)
          (expect (search "Y ::" msg) :to-be-truthy)
          (expect (search "Available" msg) :to-be-truthy))))))

(it-sequential "typed-hole-error-message-formats-a-binding-whose-value-is-a-bare-type-not-a-scheme"
  ;; %TYPED-HOLE-MESSAGE's per-binding (IF (TYPE-SCHEME-P SCHEME) ...) only
  ;; ever saw genuine TYPE-SCHEME values above, since every prior test binds
  ;; via MAKE-TYPE-SCHEME. TYPE-ENV-EXTEND itself does not enforce that its
  ;; SCHEME argument actually be a scheme, so a bare type-node is a legal,
  ;; if unusual, binding value -- exercising the FALSE branch, which uses
  ;; the value as-is instead of unwrapping it.
  (let ((env (type-env-extend 'z type-int (type-env-empty))))
    (handler-case
        (progn (infer (cl-cc/ast:make-ast-hole) env)
               (error "expected typed-hole-error to be signalled"))
      (typed-hole-error (e)
        (expect (search "Z ::" (type-inference-error-message e)) :to-be-truthy)))))

(it-sequential "typed-hole-message-treats-a-non-type-env-argument-as-having-no-bindings"
  ;; %TYPED-HOLE-MESSAGE's (AND (TYPE-ENV-P ENV) ...) guard is defensive:
  ;; every real call site passes a genuine type-env, so its own FALSE
  ;; branch had never fired. Calling it directly is cheap and exercises
  ;; the guard without depending on any invariant elsewhere breaking.
  (expect (search "Available: none." (cl-cc/type::%typed-hole-message 42)) :to-be-truthy))

(it-sequential "infer-ast-binop-signals-type-mismatch-on-non-int-operand"
  (let ((ast (cl-cc/ast:make-ast-binop :op '+
                                       :lhs (cl-cc/ast:make-ast-quote :value "not-an-int")
                                       :rhs (cl-cc/ast:make-ast-int :value 1))))
    (signals type-mismatch-error (infer-with-env ast))))

(it-sequential "infer-ast-defun-named-without-declaration-still-infers-arrow-type"
  ;; fn-name is present but there is no (declare (type ...)) form, so the
  ;; body-env's (if (and fn-name declared-type) ...) takes its else branch
  ;; even though fn-name itself is non-nil (unlike the anonymous-defun case
  ;; already covered above).
  (let ((ast (cl-cc/ast:make-ast-defun
              :name 'named-no-decl-test
              :params '(x)
              :body (list (cl-cc/ast:make-ast-var :name 'x)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (= (length (type-arrow-params ty)) 1) :to-equal t))))

(it-sequential "infer-defclass-slot-without-declared-type-defaults-to-unknown"
  (let ((ast (cl-cc/ast:make-ast-defclass
              :name 'untyped-slot-test
              :slots (list (cl-cc/ast:make-ast-slot-def :name 'y)))))
    (infer-with-env ast))
  (expect (type-unknown-p (lookup-slot-type 'untyped-slot-test 'y)) :to-be-truthy))

(it-sequential "register-class-method-type-overwrites-an-existing-entry-in-place"
  ;; The pre-existing tests only ever register a (class . method) pair
  ;; once, so REGISTER-CLASS-METHOD-TYPE's (IF ENTRY (SETF (CDR ENTRY) ...)
  ;; ...) always took the PUSH arm, never the update-in-place arm.
  (register-class-method-type 'reregister-test 'area type-int)
  (expect (lookup-class-method-type 'reregister-test 'area) :to-be-type-equal-to type-int)
  (register-class-method-type 'reregister-test 'area type-string)
  (expect (lookup-class-method-type 'reregister-test 'area) :to-be-type-equal-to type-string)
  (expect (length (lookup-class-method-types 'reregister-test)) :to-equal 1))

(it-sequential "find-fn-type-declaration-covers-every-shape-of-a-non-matching-declaration"
  ;; %FIND-FN-TYPE-DECLARATION is exercised elsewhere only through
  ;; already-matching declarations produced by the AST inference pipeline;
  ;; drive its guard clauses directly.
  (expect (cl-cc/type::%find-fn-type-declaration nil '((type fixnum my-fn))) :to-be-null)
  (expect (cl-cc/type::%find-fn-type-declaration 'my-fn '(not-a-cons)) :to-be-null)
  (expect (cl-cc/type::%find-fn-type-declaration 'my-fn '((ignore my-fn))) :to-be-null)
  (expect (cl-cc/type::%find-fn-type-declaration 'my-fn '((type fixnum))) :to-be-null)
  (expect (cl-cc/type::%find-fn-type-declaration 'my-fn '((type fixnum other-fn))) :to-be-null)
  (expect (cl-cc/type::%find-fn-type-declaration 'my-fn '((type fixnum my-fn))) :to-equal 'fixnum))

;;; ─── inference-forms-advanced-init.lisp: infer-body / infer-with-constraints ──

(it-sequential "infer-body-returns-type-null-for-an-empty-form-sequence"
  ;; INFER-BODY's (IF (NULL ASTS) ...) true branch: every other call site
  ;; (progn/let/lambda/defun/flet/labels/block bodies) in this suite always
  ;; supplies at least one form, so the empty-sequence base case had never
  ;; been driven directly.
  (multiple-value-bind (ty subst) (cl-cc/type::infer-body nil (cl-cc/type:type-env-empty))
    (expect ty :to-be-type-equal-to type-null)
    (expect subst :to-be-null)))

(it-sequential "infer-with-constraints-resolves-a-fully-solvable-program-with-no-residual"
  ;; INFER-WITH-CONSTRAINTS threads COLLECT-CONSTRAINTS' output through
  ;; SOLVE-CONSTRAINTS and zonks the result -- exported (restored per a
  ;; prior commit for cl-cc's own use) but had no test anywhere in this
  ;; suite. (if b 1 2) forces a real constraint-solving round: IF's fresh
  ;; result type-var is unified with both branches' TYPE-INT via two
  ;; emitted equality constraints, both of which should discharge cleanly.
  (let* ((env (cl-cc/type:type-env-extend 'b (cl-cc/type:make-type-scheme nil type-bool)
                                          (cl-cc/type:type-env-empty)))
         (ast (cl-cc/ast:make-ast-if
               :cond (cl-cc/ast:make-ast-var :name 'b)
               :then (cl-cc/ast:make-ast-int :value 1)
               :else (cl-cc/ast:make-ast-int :value 2))))
    (multiple-value-bind (ty subst residual) (cl-cc/type:infer-with-constraints ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)
      (expect residual :to-be-null))))

(it-sequential "infer-falls-back-to-unknown-for-a-value-that-is-not-any-recognized-ast-node"
  ;; INFER's dispatching TYPECASE ends in a (T (VALUES +TYPE-UNKNOWN+ NIL))
  ;; catch-all; every other test in this suite always passes a genuine
  ;; CL-CC/AST node, so this arm had never fired.
  (multiple-value-bind (ty subst) (cl-cc/type:infer 42 (cl-cc/type:type-env-empty))
    (expect (cl-cc/type:type-unknown-p ty) :to-be-truthy)
    (expect subst :to-be-null)))
