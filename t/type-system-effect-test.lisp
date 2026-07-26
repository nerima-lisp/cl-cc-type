;;;; t/type-system-effect-test.lisp - Type Effect, Free Variables, Substitution, and Rank-N Tests
;;;;
;;;; Covers: free variables, substitution, bidirectional checking, typeclass,
;;;; effect types, effect rows, and rank-N polymorphism (forall).

(in-package :cl-cc-type/test)

(defbefore :each (cl-cc-type-serial-suite)
  (cl-cc/type:reset-type-vars!)
  (setf cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))

;;; Free Variables Tests

(progn
  (it-sequential "free-vars-primitives int"
    (let ((ty type-int))
      (declare (ignorable ty))
      (expect (type-free-vars ty) :to-be-null)))
  (it-sequential "free-vars-primitives string"
    (let ((ty type-string))
      (declare (ignorable ty))
      (expect (type-free-vars ty) :to-be-null))))

(it-sequential "free-vars-single-var-returns-itself"
  (let* ((v  (fresh-type-var))
         (fv (type-free-vars v)))
    (expect (length fv) :to-equal 1)
    (expect (type-var-equal-p (first fv) v) :to-be-truthy)))

(it-sequential "free-vars-function-type-returns-param-and-return-vars"
  (let* ((v1 (fresh-type-var))
         (v2 (fresh-type-var))
         (fn (make-type-arrow-raw :params (list v1) :return v2))
         (fv (type-free-vars fn)))
    (expect (length fv) :to-equal 2)))

;;; Substitution Tests

(it-sequential "substitution-primitive-unchanged"
  (expect (zonk type-int (make-substitution)) :to-be type-int))

(it-sequential "substitution-bound-var-replaced"
  (let* ((v (fresh-type-var))
         (result (zonk v (subst-extend v type-int (make-substitution)))))
    (expect result :to-be-type-equal-to type-int)))

(it-sequential "substitution-unbound-var-is-identity"
  (let* ((v (fresh-type-var))
         (result (zonk v (make-substitution))))
    (expect (type-var-equal-p result v) :to-be-truthy)))

(it-sequential "substitution-through-function-type"
  (let* ((v      (fresh-type-var))
         (fn     (make-type-arrow-raw :params (list v) :return v))
         (result (zonk fn (subst-extend v type-int (make-substitution)))))
    (expect result :to-be-instance-of 'type-arrow)
    (expect (first (type-arrow-params result)) :to-be-type-equal-to type-int)
    (expect (type-arrow-return result) :to-be-type-equal-to type-int)))

;;; Normalize Type Variables Tests

(it-sequential "normalize-type-variables-canonical"
  (let* ((v1 (fresh-type-var))
         (v2 (fresh-type-var))
         (fn (make-type-arrow-raw
                            :params (list v1)
                            :return v2))
         (normalized (normalize-type-variables fn)))
    (expect normalized :to-be-instance-of 'type-arrow)
    ;; The param and return should be different canonical variables
    (let ((p (first (type-arrow-params normalized)))
          (r (type-arrow-return normalized)))
      (expect p :to-be-instance-of 'type-var)
      (expect r :to-be-instance-of 'type-var)
      (expect (type-var-equal-p p r) :to-be-falsy))))

;;; Phase 3: Bidirectional Type Checking Tests

(it-sequential "bidirectional-checking-synthesize-and-check-integer"
  (let* ((env (type-env-empty))
         (ast (make-ast-int :value 42)))
    (multiple-value-bind (ty _subst) (synthesize ast env)
      (declare (ignore _subst))
      (expect (type-equal-p ty type-int) :to-be-truthy))
    (expect (null (check ast type-int env)) :to-be-truthy)
    (expect (null (check ast cl-cc/type:+type-unknown+ env)) :to-be-truthy)))

(it-sequential "bidirectional-checking-check-body-verifies-last-form"
  (let* ((env (type-env-empty))
         (ast1 (make-ast-int :value 1))
         (ast2 (make-ast-int :value 2)))
    (expect (null (check-body (list ast1 ast2) type-int env)) :to-be-truthy)))

;;; Phase 4: Typeclass Tests

(progn
  (it-sequential "typeclass-instance-registration int-registered"
    (let ((query-type type-int) (expected-p t))
      (declare (ignorable query-type expected-p))
      (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'num-test type-int (list (cons 'plus #'+)))
        (if expected-p
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-truthy)
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-falsy)))))
  (it-sequential "typeclass-instance-registration string-not-present"
    (let ((query-type type-string) (expected-p nil))
      (declare (ignorable query-type expected-p))
      (let ((cl-cc/type:*typeclass-instance-registry* (make-hash-table :test #'equal)))
        (register-typeclass-instance 'num-test type-int (list (cons 'plus #'+)))
        (if expected-p
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-truthy)
            (expect (has-typeclass-instance-p 'num-test query-type) :to-be-falsy))))))

;;; Phase 5: Effect Type Tests


(progn
  (it-sequential "effect-row-singleton-cases pure"
    (let ((row +pure-effect-row+) (expected-count 0) (expected-name nil))
      (declare (ignorable row expected-count expected-name))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (length (type-effect-row-effects row)) :to-equal expected-count)
      (when expected-name
        (expect (symbol-name (cl-cc/type:type-effect-op-name (first (type-effect-row-effects row)))) :to-equal expected-name))))
  (it-sequential "effect-row-singleton-cases io"
    (let ((row +io-effect-row+) (expected-count 1) (expected-name "IO"))
      (declare (ignorable row expected-count expected-name))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (length (type-effect-row-effects row)) :to-equal expected-count)
      (when expected-name
        (expect (symbol-name (cl-cc/type:type-effect-op-name (first (type-effect-row-effects row)))) :to-equal expected-name))))
  (it-sequential "effect-row-singleton-cases custom"
    (let ((row (make-type-effect-row :effects (list (cl-cc/type:make-type-effect-op :name 'state :args nil)
                                                      (cl-cc/type:make-type-effect-op :name 'error :args nil))
                                      :row-var nil))
          (expected-count 2) (expected-name nil))
      (declare (ignorable row expected-count expected-name))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (length (type-effect-row-effects row)) :to-equal expected-count)
      (when expected-name
        (expect (symbol-name (cl-cc/type:type-effect-op-name (first (type-effect-row-effects row)))) :to-equal expected-name)))))

(progn
  (it-sequential "effect-row-to-string pure"
    (let ((row +pure-effect-row+) (expected "{}") (substr-p nil))
      (declare (ignorable row expected substr-p))
      (let ((s (type-to-string row)))
        (if substr-p
            (expect (search expected (string-upcase s)) :to-be-truthy)
            (expect s :to-equal expected)))))
  (it-sequential "effect-row-to-string io"
    (let ((row +io-effect-row+) (expected "IO") (substr-p t))
      (declare (ignorable row expected substr-p))
      (let ((s (type-to-string row)))
        (if substr-p
            (expect (search expected (string-upcase s)) :to-be-truthy)
            (expect s :to-equal expected))))))


;;; ─── Effect Inference Tests (infer-effects / infer-with-effects / check-body-effects) ─
;;;
;;; The tests above exercise the effect-row *data structure*. These tests drive
;;; infer-effects itself (inference-effects.lisp) via directly-built AST nodes.

(progn
  (it-sequential "infer-effects-pure-ast-nodes"
    (dolist (ast (list (cl-cc/ast:make-ast-int :value 1)
                        (cl-cc/ast:make-ast-quote :value 1)
                        (cl-cc/ast:make-ast-var :name 'x)
                        (cl-cc/ast:make-ast-binop :op '+
                                                  :lhs (cl-cc/ast:make-ast-int :value 1)
                                                  :rhs (cl-cc/ast:make-ast-int :value 2))
                        (cl-cc/ast:make-ast-lambda :params nil :body nil)))
      (let ((row (cl-cc/type:infer-effects ast (type-env-empty))))
        (expect (type-equal-p row +pure-effect-row+) :to-be-truthy))))
  (it-sequential "infer-effects-print-is-io"
    (let ((row (cl-cc/type:infer-effects
                (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                (type-env-empty))))
      (expect (= (length (type-effect-row-effects row)) 1) :to-equal t)
      (expect (symbol-name (cl-cc/type:type-effect-op-name (first (type-effect-row-effects row))))
              :to-equal "IO")))
  (it-sequential "infer-effects-setq-is-state"
    (let ((row (cl-cc/type:infer-effects
                (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 1))
                (type-env-empty))))
      (expect (= (length (type-effect-row-effects row)) 1) :to-equal t)
      (expect (symbol-name (cl-cc/type:type-effect-op-name (first (type-effect-row-effects row))))
              :to-equal "STATE")))
  (it-sequential "infer-effects-if-unions-cond-then-else"
    (let ((row (cl-cc/type:infer-effects
                (cl-cc/ast:make-ast-if
                 :cond (cl-cc/ast:make-ast-var :name 'c)
                 :then (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                 :else (cl-cc/ast:make-ast-int :value 2))
                (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (cl-cc/type:type-effect-op-name op)) "IO"))
                    (type-effect-row-effects row))
              :to-be-truthy)))
  (it-sequential "infer-effects-let-unions-bindings-and-body"
    (let ((row (cl-cc/type:infer-effects
                (cl-cc/ast:make-ast-let
                 :bindings (list (cons 'x (cl-cc/ast:make-ast-print
                                            :expr (cl-cc/ast:make-ast-int :value 1))))
                 :body (list (cl-cc/ast:make-ast-int :value 2)))
                (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (cl-cc/type:type-effect-op-name op)) "IO"))
                    (type-effect-row-effects row))
              :to-be-truthy)))
  (it-sequential "infer-effects-progn-and-block-union-forms"
    (let ((progn-row (cl-cc/type:infer-effects
                       (cl-cc/ast:make-ast-progn
                        :forms (list (cl-cc/ast:make-ast-setq
                                      :var 'x :value (cl-cc/ast:make-ast-int :value 1))))
                       (type-env-empty)))
          (block-row (cl-cc/type:infer-effects
                      (cl-cc/ast:make-ast-block
                       :name 'blk
                       :body (list (cl-cc/ast:make-ast-setq
                                    :var 'x :value (cl-cc/ast:make-ast-int :value 1))))
                      (type-env-empty))))
      (expect (= (length (type-effect-row-effects progn-row)) 1) :to-equal t)
      (expect (= (length (type-effect-row-effects block-row)) 1) :to-equal t)))
  (it-sequential "infer-effects-call-uses-registered-effect-signature"
    (let ((known-row (cl-cc/type:infer-effects
                       (cl-cc/ast:make-ast-call
                        :func (cl-cc/ast:make-ast-var :name 'error)
                        :args (list (cl-cc/ast:make-ast-quote :value "boom")))
                       (type-env-empty)))
          (unknown-row (cl-cc/type:infer-effects
                        (cl-cc/ast:make-ast-call
                         :func (cl-cc/ast:make-ast-var :name 'a-totally-pure-fn)
                         :args (list (cl-cc/ast:make-ast-int :value 1)))
                        (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (cl-cc/type:type-effect-op-name op)) "ERROR"))
                    (type-effect-row-effects known-row))
              :to-be-truthy)
      (expect (type-equal-p unknown-row +pure-effect-row+) :to-be-truthy)))
  (it-sequential "infer-effects-fallback-yields-fresh-row-var"
    (let ((row (cl-cc/type:infer-effects
                (cl-cc/ast:make-ast-the :type 'fixnum :value (cl-cc/ast:make-ast-int :value 1))
                (type-env-empty))))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (null (type-effect-row-effects row)) :to-be-truthy)
      (expect (type-var-p (cl-cc/type:type-effect-row-row-var row)) :to-be-truthy)))
  (it-sequential "infer-with-effects-returns-type-subst-and-effects"
    (multiple-value-bind (ty subst effects)
        (cl-cc/type:infer-with-effects
         (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
         (type-env-empty))
      (declare (ignore subst))
      (expect (type-equal-p ty type-int) :to-be-truthy)
      (expect (some (lambda (op) (string= (symbol-name (cl-cc/type:type-effect-op-name op)) "IO"))
                    (type-effect-row-effects effects))
              :to-be-truthy)))
  (it-sequential "check-body-effects-accepts-declared-superset-and-rejects-undeclared"
    (expect (null (cl-cc/type:check-body-effects
                   (list (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1)))
                   +io-effect-row+
                   (type-env-empty)))
            :to-be-truthy)
    (signals type-inference-error
        (cl-cc/type:check-body-effects
         (list (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 1)))
         +pure-effect-row+
         (type-env-empty)))))

;;; Phase 6: Rank-N Polymorphism Tests

(it-sequential "rankn-forall-creation-and-equality"
  (let* ((a  (fresh-type-var :name 'a))
         (fn (make-type-arrow (list a) a))
         (fa (make-type-forall :var a :body fn)))
    (expect (type-forall-p fa) :to-be-truthy)
    (expect (type-var-equal-p a (type-forall-var fa)) :to-be-truthy)
    (expect (typep (type-forall-body fa) 'type-arrow) :to-be-truthy)
    (let ((s (type-to-string fa)))
      (expect (stringp s) :to-be-truthy)
      (expect (search "A" (string-upcase s)) :to-be-truthy)))
  (let* ((a  (fresh-type-var :name 'a))
         (b  (fresh-type-var :name 'b))
         (fa (make-type-forall :var a :body (make-type-arrow (list a) a)))
         (fb (make-type-forall :var b :body (make-type-arrow (list b) b))))
    (expect (type-equal-p fa fb) :to-be-falsy)))
