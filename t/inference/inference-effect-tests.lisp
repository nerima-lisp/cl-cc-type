;;;; t/inference-effect-tests.lisp — Effect Inference Tests
;;;;
;;;; Covers effect inference, effect signatures, skolem helpers, bidirectional
;;;; check, annotation, condition classes, value restriction, and polymorphic
;;;; recursion helpers.
;;;;
;;;; Ported from the cl-cc monorepo's
;;;; packages/type/tests/inference-effect-tests.lisp. `cl-cc:lower-sexp-to-ast`
;;;; becomes `cl-cc/parse:lower-sexp-to-ast` now that cl-cc-parse has its own
;;;; standalone repository.

(in-package #:cl-cc/type/inference/test)

;;; ─── Effect Inference ─────────────────────────────────────────────────────

(it-each (("infer-effects-single-forms setq-state"  (setq x 42)    "STATE")
          ("infer-effects-single-forms lambda-pure"  (lambda (x) x) nil))
    "~A"
    (name-ignored sexp expected-effect)
  (declare (ignore name-ignored))
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast sexp))
         (row (infer-effects ast (type-env-empty))))
    (expect (type-effect-row-p row) :to-be-truthy)
    (if expected-effect
        (let* ((effects (type-effect-row-effects row))
               (names (mapcar #'type-effect-op-name effects)))
          (expect (member expected-effect names :key #'symbol-name :test #'string=) :to-be-truthy))
        (expect (type-effect-row-effects row) :to-be-null))))

(it-each (("infer-effects-multi-form-unions if"    (if (print 1) (setq x 2) 3))
          ("infer-effects-multi-form-unions progn" (progn (print 1) (setq x 2))))
    "~A"
    (name-ignored sexp)
  (declare (ignore name-ignored))
  (let* ((ast (cl-cc/parse:lower-sexp-to-ast sexp))
         (row (infer-effects ast (type-env-empty)))
         (names (mapcar #'type-effect-op-name (type-effect-row-effects row))))
    (expect (member "IO" names :key #'symbol-name :test #'string=) :to-be-truthy)
    (expect (member "STATE" names :key #'symbol-name :test #'string=) :to-be-truthy)))

;;; ─── Effect Signature Registry ────────────────────────────────────────────

(it-each (("infer-effect-signature-dispatch print"   print                      "IO")
          ("infer-effect-signature-dispatch error"   error                      "ERROR")
          ("infer-effect-signature-dispatch unknown" completely-unknown-fn-xyz  nil))
    "~A"
    (name-ignored fn-name expected-effect-name)
  (declare (ignore name-ignored))
  (let ((row (lookup-effect-signature fn-name)))
    (expect (type-effect-row-p row) :to-be-truthy)
    (if expected-effect-name
        (let ((names (mapcar #'type-effect-op-name (type-effect-row-effects row))))
          (expect (member expected-effect-name names :key #'symbol-name :test #'string=) :to-be-truthy))
        (expect (type-effect-row-effects row) :to-be-null))))

(it-sequential "infer-custom-effect-signature-register-and-lookup"
  ;; register-effect-signature stores a row and lookup-effect-signature returns it.
  (let ((custom-row (make-type-effect-row
                      :effects (list (make-type-effect-op :name 'network :args nil))
                      :row-var nil)))
    (register-effect-signature 'http-get-xyz custom-row)
    (let ((result (lookup-effect-signature 'http-get-xyz)))
      (expect (eq custom-row result) :to-be-truthy))))

(it-sequential "infer-dict-env-constraint-satisfaction"
  ;; dict-env-extend provides a constraint; missing env signals type-inference-error.
  (let* ((env0 (type-env-empty))
         (env1 (dict-env-extend 'local-num type-int '((plus . #'+)) env0))
         (constraint (make-type-constraint
                      :class-name 'local-num
                      :type-arg type-int))
         (q (make-type-qualified :constraints (list constraint)
                                  :body type-int)))
    (check-qualified-constraints q nil env1)
    (signals type-inference-error
      (check-qualified-constraints q nil env0))))

;;; ─── infer-with-effects ───────────────────────────────────────────────────

(it-sequential "infer-with-effects-returns-triple"
  ;; infer-with-effects returns type, subst, and effect row; (print 42) yields IO effect.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(print 42))))
    (multiple-value-bind (ty subst effects)
        (infer-with-effects ast (type-env-empty))
      (declare (ignore subst))
      (expect (type-primitive-name ty) :to-be 'fixnum)
      (expect (type-effect-row-p effects) :to-be-truthy)
      (let ((names (mapcar #'type-effect-op-name (type-effect-row-effects effects))))
        (expect (member "IO" names :key #'symbol-name :test #'string=) :to-be-truthy)))))

;;; ─── check-body-effects ───────────────────────────────────────────────────

(it-sequential "infer-check-body-effects-io-row-succeeds"
  ;; check-body-effects: IO row accepts (print 42) without signaling.
  (let ((asts (list (cl-cc/parse:lower-sexp-to-ast '(print 42)))))
    (check-body-effects asts +io-effect-row+ (type-env-empty))
    (expect t :to-be-truthy)))

(it-sequential "infer-check-body-effects-pure-row-signals-error"
  ;; check-body-effects: pure row rejects (print 42) with type-inference-error.
  (let ((asts (list (cl-cc/parse:lower-sexp-to-ast '(print 42)))))
    (signals type-inference-error
      (check-body-effects asts +pure-effect-row+ (type-env-empty)))))

;;; ─── Skolem Helpers ───────────────────────────────────────────────────────

;;; ─── Bidirectional check: forall ──────────────────────────────────────────

;;; ─── annotate-type / defun-without-annotation ───────────────────────────

(it-sequential "infer-annotate-type-returns-int-and-original-ast"
  ;; annotate-type on 42 returns type-int and the original AST node.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '42)))
    (multiple-value-bind (ty result-ast)
        (annotate-type ast (type-env-empty))
      (expect ty :to-be-type-equal-to type-int)
      (expect (eq ast result-ast) :to-be-truthy))))

(it-sequential "infer-defun-return-type-is-fixnum"
  ;; defun f (x) (+ x 1) infers a function type with fixnum return.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(defun f (x) (+ x 1)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (type-arrow-return ty) :to-be-type-equal-to type-int))))

;;; ─── Condition Classes ────────────────────────────────────────────────────

(it-sequential "infer-condition-base-error-has-message"
  ;; type-inference-error is an error with a readable message slot.
  (let ((c (make-condition 'type-inference-error :message "test")))
    (expect (typep c 'error) :to-be-truthy)
    (expect (type-inference-error-message c) :to-equal "test")))

(it-sequential "infer-condition-unbound-variable-carries-name"
  ;; unbound-variable-error is a type-inference-error with the variable's name.
  (let ((c (make-condition 'unbound-variable-error :name 'x)))
    (expect (typep c 'type-inference-error) :to-be-truthy)
    (expect (unbound-variable-error-name c) :to-be 'x)))

(it-sequential "infer-condition-type-mismatch-carries-expected-and-actual"
  ;; type-mismatch-error carries expected and actual types accessible via slot readers.
  (let ((c (make-condition 'type-mismatch-error
                            :expected type-int
                            :actual type-string)))
    (expect (typep c 'type-inference-error) :to-be-truthy)
    (expect (type-primitive-name (type-mismatch-error-expected c)) :to-be 'fixnum)
    (expect (type-primitive-name (type-mismatch-error-actual c)) :to-be 'string)))

;;; ─── FR-1604: Value Restriction ──────────────────────────────────────────

(it-each (("infer-syntactic-value-p integer"  42               t)
          ("infer-syntactic-value-p quote"    (quote hello)     t)
          ("infer-syntactic-value-p lambda"   (lambda (x) x)   t)
          ("infer-syntactic-value-p function" (function car)   t)
          ("infer-syntactic-value-p call"     (foo 1)          nil)
          ("infer-syntactic-value-p binop"    (+ x y)          nil)
          ("infer-syntactic-value-p if"       (if t 1 2)       nil)
          ("infer-syntactic-value-p progn"    (progn 1 2)      nil))
    "~A"
    (name-ignored sexp expected)
  (declare (ignore name-ignored))
  (let ((ast (cl-cc/parse:lower-sexp-to-ast sexp)))
    (if expected
        (expect (syntactic-value-p ast) :to-be-truthy)
        (expect (syntactic-value-p ast) :to-be-falsy))))

(it-sequential "infer-value-restriction-lambda-binding-generalizes"
  ;; Value restriction: let binding a lambda generalizes to polymorphic type; applying at int yields int.
  (reset-type-vars!)
  (let ((ast (cl-cc/parse:lower-sexp-to-ast '(let ((id (lambda (x) x))) (id 42)))))
    (multiple-value-bind (ty subst) (infer-with-env ast)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

(it-sequential "infer-value-restriction-call-binding-stays-monomorphic"
  ;; Value restriction: let binding a call result stays monomorphic; result type is int.
  (reset-type-vars!)
  (let* ((fn-ty (make-type-arrow-raw
                 :params (list type-int)
                 :return type-int))
         (env (type-env-extend 'identity (type-to-scheme fn-ty) (type-env-empty)))
         (ast (cl-cc/parse:lower-sexp-to-ast '(let ((x (identity 42))) x))))
    (multiple-value-bind (ty subst) (infer ast env)
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int))))

;;; ─── FR-004: Polymorphic Recursion ──────────────────────────────────────

(it-each (("infer-poly-recursion-helper-cases found"
           ((type (-> fixnum fixnum) length) (optimize (speed 3)))
           length
           (-> fixnum fixnum))
          ("infer-poly-recursion-helper-cases miss-name"
           ((type fixnum x) (type string y))
           length
           nil)
          ("infer-poly-recursion-helper-cases nil-name"
           ((type fixnum x))
           nil
           nil))
    "~A"
    (name-ignored decls name expected)
  (declare (ignore name-ignored))
  (let ((spec (%find-fn-type-declaration name decls)))
    (if expected
        (expect spec :to-equal expected)
        (expect spec :to-be-null))))

;;; ─── %infer-effects-union ────────────────────────────────────────────────

(it-sequential "infer-effects-union-empty-is-pure"
  ;; %infer-effects-union on empty list returns the pure effect row.
  (reset-type-vars!)
  (let ((result (%infer-effects-union nil nil)))
    (expect (effect-row-subset-p result +pure-effect-row+) :to-be-truthy)
    (expect (effect-row-subset-p +pure-effect-row+ result) :to-be-truthy)))

(it-sequential "infer-effects-union-pure-forms-stay-pure"
  ;; %infer-effects-union on a list of pure integer forms returns the pure effect row.
  (reset-type-vars!)
  (let* ((asts (list (cl-cc/parse:lower-sexp-to-ast '1) (cl-cc/parse:lower-sexp-to-ast '2)))
         (result (%infer-effects-union asts nil)))
    (expect (effect-row-subset-p result +pure-effect-row+) :to-be-truthy)))

(in-package cl-cc/type/inference/test)

(progn
  (it-sequential "infer-effects-pure-ast-nodes"
    (dolist (ast (list (cl-cc/ast:make-ast-int :value 1)
                        (cl-cc/ast:make-ast-quote :value 1)
                        (cl-cc/ast:make-ast-var :name 'x)
                        (cl-cc/ast:make-ast-binop :op '+
                                                  :lhs (cl-cc/ast:make-ast-int :value 1)
                                                  :rhs (cl-cc/ast:make-ast-int :value 2))
                        (cl-cc/ast:make-ast-lambda :params nil :body nil)))
      (let ((row (infer-effects ast (type-env-empty))))
        (expect row :to-be-type-equal-to +pure-effect-row+))))
  (it-sequential "infer-effects-print-is-io"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                (type-env-empty))))
      (expect (= (length (type-effect-row-effects row)) 1) :to-equal t)
      (expect (symbol-name (type-effect-op-name (first (type-effect-row-effects row))))
              :to-equal "IO")))
  (it-sequential "infer-effects-setq-is-state"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 1))
                (type-env-empty))))
      (expect (= (length (type-effect-row-effects row)) 1) :to-equal t)
      (expect (symbol-name (type-effect-op-name (first (type-effect-row-effects row))))
              :to-equal "STATE")))
  (it-sequential "infer-effects-if-unions-cond-then-else"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-if
                 :cond (cl-cc/ast:make-ast-var :name 'c)
                 :then (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                 :else (cl-cc/ast:make-ast-int :value 2))
                (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (type-effect-op-name op)) "IO"))
                    (type-effect-row-effects row))
              :to-be-truthy)))
  (it-sequential "infer-effects-let-unions-bindings-and-body"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-let
                 :bindings (list (cons 'x (cl-cc/ast:make-ast-print
                                            :expr (cl-cc/ast:make-ast-int :value 1))))
                 :body (list (cl-cc/ast:make-ast-int :value 2)))
                (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (type-effect-op-name op)) "IO"))
                    (type-effect-row-effects row))
              :to-be-truthy)))
  (it-sequential "infer-effects-progn-and-block-union-forms"
    (let ((progn-row (infer-effects
                       (cl-cc/ast:make-ast-progn
                        :forms (list (cl-cc/ast:make-ast-setq
                                      :var 'x :value (cl-cc/ast:make-ast-int :value 1))))
                       (type-env-empty)))
          (block-row (infer-effects
                      (cl-cc/ast:make-ast-block
                       :name 'blk
                       :body (list (cl-cc/ast:make-ast-setq
                                    :var 'x :value (cl-cc/ast:make-ast-int :value 1))))
                      (type-env-empty))))
      (expect (= (length (type-effect-row-effects progn-row)) 1) :to-equal t)
      (expect (= (length (type-effect-row-effects block-row)) 1) :to-equal t)))
  (it-sequential "infer-effects-call-uses-registered-effect-signature"
    (let ((known-row (infer-effects
                       (cl-cc/ast:make-ast-call
                        :func (cl-cc/ast:make-ast-var :name 'error)
                        :args (list (cl-cc/ast:make-ast-quote :value "boom")))
                       (type-env-empty)))
          (unknown-row (infer-effects
                        (cl-cc/ast:make-ast-call
                         :func (cl-cc/ast:make-ast-var :name 'a-totally-pure-fn)
                         :args (list (cl-cc/ast:make-ast-int :value 1)))
                        (type-env-empty))))
      (expect (some (lambda (op)
                       (string= (symbol-name (type-effect-op-name op)) "ERROR"))
                    (type-effect-row-effects known-row))
              :to-be-truthy)
      (expect unknown-row :to-be-type-equal-to +pure-effect-row+)))
  (it-sequential "infer-effects-fallback-yields-fresh-row-var"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-the :type 'fixnum :value (cl-cc/ast:make-ast-int :value 1))
                (type-env-empty))))
      (expect (type-effect-row-p row) :to-be-truthy)
      (expect (null (type-effect-row-effects row)) :to-be-truthy)
      (expect (type-var-p (type-effect-row-row-var row)) :to-be-truthy)))
  (it-sequential "infer-with-effects-returns-type-subst-and-effects"
    (multiple-value-bind (ty subst effects)
        (infer-with-effects
         (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
         (type-env-empty))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)
      (expect (some (lambda (op) (string= (symbol-name (type-effect-op-name op)) "IO"))
                    (type-effect-row-effects effects))
              :to-be-truthy)))
  (it-sequential "check-body-effects-accepts-declared-superset-and-rejects-undeclared"
    (expect (null (check-body-effects
                   (list (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1)))
                   +io-effect-row+
                   (type-env-empty)))
            :to-be-truthy)
    (signals type-inference-error
        (check-body-effects
         (list (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 1)))
         +pure-effect-row+
         (type-env-empty))))
  (it-sequential "infer-effects-pure-ast-nodes-defun-and-defvar"
    (dolist (ast (list (cl-cc/ast:make-ast-defun
                         :name 'f :params nil
                         :body (list (cl-cc/ast:make-ast-int :value 1)))
                        (cl-cc/ast:make-ast-defvar
                         :name 'x :value (cl-cc/ast:make-ast-int :value 1))))
      (let ((row (infer-effects ast (type-env-empty))))
        (expect row :to-be-type-equal-to +pure-effect-row+))))
  (it-sequential "infer-effects-call-with-non-var-func-defaults-base-to-pure"
    (let ((pure-args-row (infer-effects
                          (cl-cc/ast:make-ast-call
                           :func (cl-cc/ast:make-ast-lambda :params nil :body nil)
                           :args (list (cl-cc/ast:make-ast-int :value 1)))
                          (type-env-empty)))
          (io-args-row (infer-effects
                        (cl-cc/ast:make-ast-call
                         :func (cl-cc/ast:make-ast-lambda :params nil :body nil)
                         :args (list (cl-cc/ast:make-ast-print
                                      :expr (cl-cc/ast:make-ast-int :value 1))))
                        (type-env-empty))))
      (expect pure-args-row :to-be-type-equal-to +pure-effect-row+)
      (expect (some (lambda (op) (string= (symbol-name (type-effect-op-name op)) "IO"))
                    (type-effect-row-effects io-args-row))
              :to-be-truthy)))
  (it-sequential "infer-effects-if-unions-cond-only-effect"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-if
                 :cond (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                 :then (cl-cc/ast:make-ast-int :value 2)
                 :else (cl-cc/ast:make-ast-int :value 3))
                (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (type-effect-op-name op)) "IO"))
                    (type-effect-row-effects row))
              :to-be-truthy)))
  (it-sequential "infer-effects-let-unions-body-only-effect"
    (let ((row (infer-effects
                (cl-cc/ast:make-ast-let
                 :bindings (list (cons 'x (cl-cc/ast:make-ast-int :value 1)))
                 :body (list (cl-cc/ast:make-ast-setq
                              :var 'y :value (cl-cc/ast:make-ast-int :value 2))))
                (type-env-empty))))
      (expect (some (lambda (op) (string= (symbol-name (type-effect-op-name op)) "STATE"))
                    (type-effect-row-effects row))
              :to-be-truthy)))
  (it-sequential "infer-with-effects-pure-ast-returns-pure-effects"
    (multiple-value-bind (ty subst effects)
        (infer-with-effects (cl-cc/ast:make-ast-int :value 42) (type-env-empty))
      (declare (ignore subst))
      (expect ty :to-be-type-equal-to type-int)
      (expect effects :to-be-type-equal-to +pure-effect-row+)))
  (it-sequential "check-body-effects-unions-multiple-forms-and-detects-missing-declared-effect"
    ;; Reuse +io-effect-row+ (rather than building a fresh (make-type-effect-op
    ;; :name 'io ...) here): the op-name symbol must be EQL to the one baked
    ;; into the built-in IO row for effect-row-subset-p's MEMBER check to
    ;; match, and an unquoted 'io read in this package would intern a
    ;; different symbol than IO in the original facade package.
    (let ((declared +io-effect-row+))
      (expect (null (check-body-effects
                     (list (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                           (cl-cc/ast:make-ast-int :value 2))
                     declared
                     (type-env-empty)))
              :to-be-truthy)
      (signals type-inference-error
          (check-body-effects
           (list (cl-cc/ast:make-ast-print :expr (cl-cc/ast:make-ast-int :value 1))
                 (cl-cc/ast:make-ast-setq :var 'x :value (cl-cc/ast:make-ast-int :value 1)))
           declared
           (type-env-empty))))))

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
