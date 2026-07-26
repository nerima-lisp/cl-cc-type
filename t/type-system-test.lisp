;;;; t/type-system-test.lisp - Type System Tests
;;;;
;;;; Comprehensive tests for the HM type system including:
;;;; - Type representation (primitives, variables, functions)
;;;; - Unification (with occurs check)
;;;; - Type inference (Algorithm W)
;;;; - Generalization and instantiation (let-polymorphism)

(in-package :cl-cc-type/test)

;;; Type Representation Tests

(progn
  (it-sequential "type-repr-primitive-is-type-primitive int"
    (let ((tp type-int))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive string"
    (let ((tp type-string))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive bool"
    (let ((tp type-bool))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive symbol"
    (let ((tp type-symbol))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive null"
    (let ((tp type-null))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive)))
  (it-sequential "type-repr-primitive-is-type-primitive any"
    (let ((tp type-any))
      (declare (ignorable tp))
      (expect tp :to-be-instance-of 'type-primitive))))

(progn
  (it-sequential "type-repr-primitive-name int"
    (let ((tp type-int) (expected-name 'fixnum))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name string"
    (let ((tp type-string) (expected-name 'string))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name bool"
    (let ((tp type-bool) (expected-name 'boolean))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name symbol"
    (let ((tp type-symbol) (expected-name 'symbol))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name null"
    (let ((tp type-null) (expected-name 'null))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name)))
  (it-sequential "type-repr-primitive-name any"
    (let ((tp type-any) (expected-name 't))
      (declare (ignorable tp expected-name))
      (expect (type-primitive-name tp) :to-be expected-name))))

(it-sequential "type-repr-variable-and-function-creation"
  ;; Variables: distinct IDs, correct names
  (let ((v1 (fresh-type-var :name 'a))
        (v2 (fresh-type-var :name 'b)))
    (expect v1 :to-be-instance-of 'type-var)
    (expect v2 :to-be-instance-of 'type-var)
    (expect (= (type-var-id v1) (type-var-id v2)) :to-be-falsy)
    (expect (type-var-name v1) :to-be 'a)
    (expect (type-var-name v2) :to-be 'b))
  ;; Function type: accessors
  (let ((fn-type (make-type-arrow-raw
                  :params (list type-int type-int)
                  :return type-int)))
    (expect fn-type :to-be-instance-of 'type-arrow)
    (expect (length (type-arrow-params fn-type)) :to-equal 2)
    (expect (type-arrow-return fn-type) :to-be type-int)))

(progn
  (it-sequential "type-repr-equality-and-strings primitive-same"
    (let ((verify (lambda ()
                    (expect type-int :to-be-type-equal-to type-int))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings primitive-distinct"
    (let ((verify (lambda ()
                    (expect (type-equal-p type-int type-string) :to-be-falsy))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings variable-self"
    (let ((verify (lambda ()
                    (let ((v (fresh-type-var)))
                      (expect v :to-be-type-equal-to v)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings function-equal"
    (let ((verify (lambda ()
                    (let ((fn1 (make-type-arrow-raw :params (list type-int) :return type-int))
                          (fn2 (make-type-arrow-raw :params (list type-int) :return type-int)))
                      (expect fn2 :to-be-type-equal-to fn1)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings function-different"
    (let ((verify (lambda ()
                    (let ((fn1 (make-type-arrow-raw :params (list type-int)    :return type-int))
                          (fn3 (make-type-arrow-raw :params (list type-string) :return type-int)))
                      (expect (type-equal-p fn1 fn3) :to-be-falsy)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "type-repr-equality-and-strings arrow-to-string"
    (let ((verify (lambda ()
                    (let ((fn (make-type-arrow-raw :params (list type-int) :return type-int)))
                      (expect (type-to-string fn) :to-equal "FIXNUM -> FIXNUM")))))
      (declare (ignorable verify))
      (funcall verify))))

(progn
  (it-sequential "type-repr-primitive-type-to-string int"
    (let ((expected "FIXNUM") (type type-int))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected)))
  (it-sequential "type-repr-primitive-type-to-string string"
    (let ((expected "STRING") (type type-string))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected)))
  (it-sequential "type-repr-primitive-type-to-string bool"
    (let ((expected "BOOLEAN") (type type-bool))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected)))
  (it-sequential "type-repr-primitive-type-to-string unknown"
    (let ((expected "?") (type cl-cc/type:+type-unknown+))
      (declare (ignorable expected type))
      (expect (type-to-string type) :to-equal expected))))


(it-sequential "type-repr-unknown-type"
  (expect (type-equal-p cl-cc/type:+type-unknown+ cl-cc/type:+type-unknown+) :to-be-falsy)
  (expect (type-error-p cl-cc/type:+type-unknown+) :to-be-truthy))

;;; Unification Tests

(progn
  (it-sequential "unify-primitive same"
    (let ((should-unify t) (a type-int) (b type-int))
      (declare (ignorable should-unify a b))
      (if should-unify
          (expect b :to-unify-with a)
          (expect-not b :to-unify-with a))))
  (it-sequential "unify-primitive different"
    (let ((should-unify nil) (a type-int) (b type-string))
      (declare (ignorable should-unify a b))
      (if should-unify
          (expect b :to-unify-with a)
          (expect-not b :to-unify-with a)))))

(progn
  (it-sequential "unify-advanced-cases variable-binds"
    (let ((verify (lambda ()
                    (let ((v (fresh-type-var)))
                      (multiple-value-bind (result ok) (type-unify v type-int)
                        (expect ok :to-be-truthy)
                        (multiple-value-bind (binding found) (subst-lookup v result)
                          (expect found :to-be-truthy)
                          (expect type-int :to-be-type-equal-to binding))))
                    (expect (fresh-type-var) :to-unify-with (fresh-type-var))
                    (let ((v (fresh-type-var)))
                      (expect v :to-unify-with v)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "unify-advanced-cases structural-binding"
    (let ((verify (lambda ()
                    (let* ((v   (fresh-type-var))
                           (fn1 (make-type-arrow-raw :params (list v) :return type-int))
                           (fn2 (make-type-arrow-raw :params (list type-string) :return type-int)))
                      (multiple-value-bind (result ok) (type-unify fn1 fn2)
                        (expect ok :to-be-truthy)
                        (multiple-value-bind (binding found) (subst-lookup v result)
                          (expect found :to-be-truthy)
                          (expect type-string :to-be-type-equal-to binding)))))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "unify-advanced-cases failure-cases"
    (let ((verify (lambda ()
                    (expect-not
                     (make-type-arrow-raw :params (list type-int type-int) :return type-int)
                     :to-unify-with
                     (make-type-arrow-raw :params (list type-int) :return type-int))
                    (let* ((v  (fresh-type-var))
                           (fn (make-type-arrow-raw :params (list v) :return type-int)))
                      (expect-not fn :to-unify-with v)))))
      (declare (ignorable verify))
      (funcall verify)))
  (it-sequential "unify-advanced-cases subst-chains"
    (let ((verify (lambda ()
                    (let* ((v1       (fresh-type-var))
                           (v2       (fresh-type-var))
                           (s1       (subst-extend v1 type-int (make-substitution)))
                           (s2       (subst-extend v2 v1 (make-substitution)))
                           (composed (subst-compose s1 s2)))
                      (expect (zonk v2 composed) :to-be-type-equal-to type-int))
                    (let* ((v1 (fresh-type-var))
                           (v2 (fresh-type-var)))
                      (multiple-value-bind (subst1 ok1) (type-unify v1 v2)
                        (expect ok1 :to-be-truthy)
                        (multiple-value-bind (subst2 ok2) (type-unify v2 type-int subst1)
                          (expect ok2 :to-be-truthy)
                          (expect (zonk v1 subst2) :to-be-type-equal-to type-int)))))))
      (declare (ignorable verify))
      (funcall verify))))

(progn
  (it-sequential "unify-lists success"
    (let ((expected t) (a (list type-int type-string)) (b (list type-int type-string)))
      (declare (ignorable expected a b))
      (let ((ok (nth-value 1 (type-unify-lists a b nil))))
        (expect (not (null ok)) :to-equal expected))))
  (it-sequential "unify-lists type-mismatch"
    (let ((expected nil) (a (list type-int type-string)) (b (list type-string type-int)))
      (declare (ignorable expected a b))
      (let ((ok (nth-value 1 (type-unify-lists a b nil))))
        (expect (not (null ok)) :to-equal expected))))
  (it-sequential "unify-lists length-mismatch"
    (let ((expected nil) (a (list type-int)) (b (list type-int type-string)))
      (declare (ignorable expected a b))
      (let ((ok (nth-value 1 (type-unify-lists a b nil))))
        (expect (not (null ok)) :to-equal expected)))))

(progn
  (it-sequential "unify-type-error-fails unknown-int"
    (let ((a cl-cc/type:+type-unknown+) (b type-int))
      (declare (ignorable a b))
      (expect-not b :to-unify-with a)))
  (it-sequential "unify-type-error-fails string-unknown"
    (let ((a type-string) (b cl-cc/type:+type-unknown+))
      (declare (ignorable a b))
      (expect-not b :to-unify-with a)))
  (it-sequential "unify-type-error-fails unknown-unknown"
    (let ((a cl-cc/type:+type-unknown+) (b cl-cc/type:+type-unknown+))
      (declare (ignorable a b))
      (expect-not b :to-unify-with a))))

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
    (expect (type-equal-p ty type-int) :to-be-truthy)))

(it-sequential "infer-ast-var-bound-and-unbound"
  (let ((env (type-env-extend 'x (make-type-scheme nil type-int) (type-env-empty))))
    (multiple-value-bind (ty subst) (infer (cl-cc/ast:make-ast-var :name 'x) env)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy)))
  (signals unbound-variable-error
      (infer-with-env (cl-cc/ast:make-ast-var :name 'nowhere-to-be-found))))

(progn
  (it-sequential "infer-ast-quote-cases int"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value 7))
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy)))
  (it-sequential "infer-ast-quote-cases string"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value "hi"))
      (declare (ignore subst))
      (expect (type-equal-p ty type-string) :to-be-truthy)))
  (it-sequential "infer-ast-quote-cases symbol"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value 'foo))
      (declare (ignore subst))
      (expect (type-equal-p ty type-symbol) :to-be-truthy)))
  (it-sequential "infer-ast-quote-cases cons"
    (multiple-value-bind (ty subst) (infer-with-env (cl-cc/ast:make-ast-quote :value '(1 2)))
      (declare (ignore subst))
      (expect (type-equal-p ty type-cons) :to-be-truthy)))
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
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
      (expect (type-equal-p ty type-string) :to-be-truthy))
    (multiple-value-bind (var ty) (extract-type-guard typep-guard)
      (expect var :to-be 'v)
      (expect (type-primitive-p ty) :to-be-truthy)
      (expect (type-primitive-name ty) :to-be 'point))
    (multiple-value-bind (var ty) (extract-type-guard non-guard)
      (expect var :to-be-null)
      (expect ty :to-be-null))))

(it-sequential "narrow-union-type-removes-and-collapses-members"
  (let ((union-ty (make-type-union (list type-int type-string type-symbol))))
    (let ((remaining (narrow-union-type union-ty type-int)))
      (expect (type-union-p remaining) :to-be-truthy)
      (expect (length (type-union-types remaining)) :to-equal 2)))
  (let* ((two-ty (make-type-union (list type-int type-string)))
         (remaining (narrow-union-type two-ty type-int)))
    (expect (type-equal-p remaining type-string) :to-be-truthy))
  ;; Non-union types pass through unchanged.
  (expect (type-equal-p (narrow-union-type type-int type-string) type-int) :to-be-truthy))

(it-sequential "register-and-lookup-type-predicate"
  (let ((marker-type (make-type-primitive :name 'marker-test-type)))
    (register-type-predicate 'marker-test-type-p marker-type)
    (expect (type-equal-p (cl-cc/type::type-predicate-to-type 'marker-test-type-p) marker-type)
            :to-be-truthy)))

(it-sequential "infer-ast-let-generalizes-syntactic-values"
  ;; (let ((x 1)) x) — x is bound to a syntactic value (int literal) and may be
  ;; generalized under the value restriction (FR-1604).
  (let ((ast (cl-cc/ast:make-ast-let
              :bindings (list (cons 'x (cl-cc/ast:make-ast-int :value 1)))
              :body (list (cl-cc/ast:make-ast-var :name 'x)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
      (expect (type-equal-p ty type-string) :to-be-truthy))))

(it-sequential "infer-ast-print-returns-printed-expression-type"
  (let ((ast (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 9))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy))))

(it-sequential "infer-ast-the-matches-and-mismatches"
  (let ((ok-ast (cl-cc/ast:make-ast-the :type 'fixnum :value (cl-cc/ast:make-ast-int :value 1))))
    (multiple-value-bind (ty subst) (infer-with-env ok-ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy)))
  (let ((bad-ast (cl-cc/ast:make-ast-the :type 'string :value (cl-cc/ast:make-ast-int :value 1))))
    (signals type-mismatch-error (infer-with-env bad-ast))))

(it-sequential "infer-ast-setq-declared-and-undeclared"
  (let* ((env (type-env-extend 'x (make-type-scheme nil type-int) (type-env-empty)))
         (ast (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 3))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy)))
  (let ((ast (cl-cc/ast:make-ast-setq :var 'undeclared :value (cl-cc/ast:make-ast-int :value 3))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy))))

(it-sequential "infer-ast-binop-adds-two-ints"
  (let ((ast (cl-cc/ast:make-ast-binop :op '+
                                       :lhs (cl-cc/ast:make-ast-int :value 1)
                                       :rhs (cl-cc/ast:make-ast-int :value 2))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
  (expect (type-equal-p (infer-with-env (cl-cc/ast:make-ast-defvar :name '*x* :value nil))
                        type-symbol)
          :to-be-truthy)
  (expect (type-equal-p (infer-with-env
                          (cl-cc/ast:make-ast-defvar :name '*y*
                                                     :value (cl-cc/ast:make-ast-int :value 1)))
                        type-symbol)
          :to-be-truthy))

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
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
      (expect (type-equal-p ty type-int) :to-be-truthy))))

(it-sequential "infer-ast-block-and-return-from"
  (let ((ast (cl-cc/ast:make-ast-block
              :name 'blk
              :body (list (cl-cc/ast:make-ast-return-from
                           :name 'blk
                           :value (cl-cc/ast:make-ast-int :value 1))))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy))))

(it-sequential "infer-ast-defclass-defmethod-make-instance-slot-value"
  (let ((defclass-ast (cl-cc/ast:make-ast-defclass
                        :name 'point-test
                        :slots (list (cl-cc/ast:make-ast-slot-def :name 'x :type 'fixnum)))))
    (multiple-value-bind (ty subst) (infer-with-env defclass-ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-symbol) :to-be-truthy)))
  (expect (type-equal-p (lookup-slot-type 'point-test 'x) type-int) :to-be-truthy)
  (let ((defmethod-ast (cl-cc/ast:make-ast-defmethod
                         :name 'area
                         :specializers (list (cons 'obj 'point-test))
                         :params '(obj)
                         :body nil)))
    (multiple-value-bind (ty subst) (infer-with-env defmethod-ast)
      (declare (ignore subst))
      (expect (type-equal-p ty type-symbol) :to-be-truthy)))
  (expect (type-equal-p (lookup-class-method-type 'point-test 'area) type-any) :to-be-truthy)
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
      (expect (type-equal-p ty type-int) :to-be-truthy))))

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
      (expect (type-equal-p ty type-int) :to-be-truthy)))
  (let* ((f-type (make-type-arrow (list type-int) type-int))
         (env (type-env-extend 'f (make-type-scheme nil f-type) (type-env-empty)))
         (bad-ast (cl-cc/ast:make-ast-call
                   :func (cl-cc/ast:make-ast-var :name 'f)
                   :args (list (cl-cc/ast:make-ast-quote :value "not an int")))))
    (signals type-mismatch-error (infer bad-ast env))))

(it-sequential "annotate-type-returns-inferred-type-and-original-ast"
  (let ((ast (cl-cc/ast:make-ast-int :value 5)))
    (multiple-value-bind (ty annotated) (annotate-type ast (type-env-empty))
      (expect (type-equal-p ty type-int) :to-be-truthy)
      (expect (eq annotated ast) :to-be-truthy))))
