;;;; t/solver-collect-test.lisp — collect-constraints Tests
;;;;
;;;; Full coverage for packages/type/src/solver-collect.lisp.
;;;; Each typecase arm is exercised at least once, plus constraint emission
;;;; and the gradual-typing fallback.
(in-package :cl-cc-type/test)

;;; helpers
(defun empty-env ()
  (cl-cc/type:type-env-empty))

(defun collect (ast)
  (cl-cc/type:collect-constraints ast (empty-env)))

(defun collect-in (ast env)
  (cl-cc/type:collect-constraints ast env))

;;; ─── ast-int → type-int, no constraints ─────────────────────────────────────
(it-sequential
  "collect-int-literal"
  (multiple-value-bind (ty cs) (collect (cl-cc/ast:make-ast-int :value 42))
    (expect type-int :to-be-type-equal-to ty)
    (expect cs :to-be-null)))

;;; ─── ast-var → instantiated scheme ──────────────────────────────────────────
(it-sequential
  "collect-var-bound"
  (let* ((env
        (cl-cc/type:type-env-extend 'x (cl-cc/type:type-to-scheme type-int) (empty-env))))
    (multiple-value-bind (ty cs) (collect-in (cl-cc/ast:make-ast-var :name 'x) env)
      (expect type-int :to-be-type-equal-to ty)
      (expect cs :to-be-null))))

(it-sequential
  "collect-var-unbound-signals"
  (signals
    cl-cc/type:unbound-variable-error
    (collect (cl-cc/ast:make-ast-var :name 'missing-var))))

;;; ─── ast-quote → literal type dispatch ──────────────────────────────────────
(progn
  (it-sequential "collect-quote-literal-types integer"
    (multiple-value-bind (ty cs) (collect (cl-cc/ast:make-ast-quote :value 42))
      (expect (symbol-value 'type-int) :to-be-type-equal-to ty)
      (expect cs :to-be-null)))
  (it-sequential "collect-quote-literal-types string"
    (multiple-value-bind (ty cs) (collect (cl-cc/ast:make-ast-quote :value "hi"))
      (expect (symbol-value 'type-string) :to-be-type-equal-to ty)
      (expect cs :to-be-null)))
  (it-sequential "collect-quote-literal-types symbol"
    (multiple-value-bind (ty cs) (collect (cl-cc/ast:make-ast-quote :value 'foo))
      (expect (symbol-value 'type-symbol) :to-be-type-equal-to ty)
      (expect cs :to-be-null)))
  (it-sequential "collect-quote-literal-types cons"
    (multiple-value-bind (ty cs) (collect (cl-cc/ast:make-ast-quote :value '(1 2)))
      (expect (symbol-value 'type-cons) :to-be-type-equal-to ty)
      (expect cs :to-be-null))))

(it-sequential
  "collect-quote-unknown"
  (multiple-value-bind (ty cs) (collect (cl-cc/ast:make-ast-quote :value #\a))
    (expect (cl-cc/type:type-unknown-p ty) :to-be-truthy)
    (expect cs :to-be-null)))

;;; ─── ast-if → fresh result var + 2 equality constraints ─────────────────────
(it-sequential
  "collect-if-emits-two-constraints"
  (let* ((env
        (cl-cc/type:type-env-extend 'b (cl-cc/type:type-to-scheme type-int) (empty-env))))
    (multiple-value-bind (ty cs) (collect-in
        (cl-cc/ast:make-ast-if
          :cond
          (cl-cc/ast:make-ast-var :name 'b)
          :then
          (cl-cc/ast:make-ast-int :value 1)
          :else
          (cl-cc/ast:make-ast-int :value 2))
        env)
      (expect (cl-cc/type:type-var-p ty) :to-be-truthy)
      (expect (length cs) :to-equal 2)
      (expect
        (every
          (lambda (c)
            (eq :equal (cl-cc/type:constraint-kind c)))
          cs)
        :to-be-truthy))))

;;; ─── ast-let → extends env, body type is result ─────────────────────────────
(it-sequential
  "collect-let-behavior"
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-let
        :bindings
        (list (cons 'n (cl-cc/ast:make-ast-int :value 5)))
        :body
        (list (cl-cc/ast:make-ast-int :value 99))))
    (declare (ignore _cs))
    (expect type-int :to-be-type-equal-to ty))
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-let
        :bindings
        (list (cons 'n (cl-cc/ast:make-ast-int :value 5)))
        :body
        (list (cl-cc/ast:make-ast-var :name 'n))))
    (declare (ignore _cs))
    (expect type-int :to-be-type-equal-to ty)))

;;; ─── ast-lambda → type-arrow ─────────────────────────────────────────────────
(it-sequential
  "collect-lambda-no-params-yields-arrow-with-int-return"
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-lambda
        :params
        '()
        :body
        (list (cl-cc/ast:make-ast-int :value 1))))
    (declare (ignore _cs))
    (expect (cl-cc/type:type-arrow-p ty) :to-be-truthy)
    (expect (cl-cc/type:type-arrow-params ty) :to-be-null)
    (expect type-int :to-be-type-equal-to (cl-cc/type:type-arrow-return ty))))

(it-sequential
  "collect-lambda-one-param-yields-arrow-with-one-param"
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-lambda
        :params
        '(x)
        :body
        (list (cl-cc/ast:make-ast-int :value 0))))
    (declare (ignore _cs))
    (expect (cl-cc/type:type-arrow-p ty) :to-be-truthy)
    (expect (length (cl-cc/type:type-arrow-params ty)) :to-equal 1)))

(it-sequential
  "collect-lambda-empty-body-yields-null-return-type"
  (multiple-value-bind (ty _cs) (collect (cl-cc/ast:make-ast-lambda :params '() :body '()))
    (declare (ignore _cs))
    (expect type-null :to-be-type-equal-to (cl-cc/type:type-arrow-return ty))))

;;; ─── ast-call → ret type-var + arrow constraint ──────────────────────────────
(it-sequential
  "collect-call-emits-arrow-constraint"
  (let* ((env
        (cl-cc/type:type-env-extend
          'f
          (cl-cc/type:type-to-scheme
            (cl-cc/type:make-type-arrow (list type-int) type-string))
          (empty-env))))
    (multiple-value-bind (ty cs) (collect-in
        (cl-cc/ast:make-ast-call
          :func
          (cl-cc/ast:make-ast-var :name 'f)
          :args
          (list (cl-cc/ast:make-ast-int :value 1)))
        env)
      (expect (cl-cc/type:type-var-p ty) :to-be-truthy)
      (expect (>= (length cs) 1) :to-be-truthy)
      (expect
        (some
          (lambda (c)
            (eq :equal (cl-cc/type:constraint-kind c)))
          cs)
        :to-be-truthy))))

;;; ─── ast-progn → type of last form ──────────────────────────────────────────
(it-sequential
  "collect-progn-behavior"
  (multiple-value-bind (ty _cs) (collect (cl-cc/ast:make-ast-progn :forms '()))
    (declare (ignore _cs))
    (expect type-null :to-be-type-equal-to ty))
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-progn
        :forms
        (list (cl-cc/ast:make-ast-int :value 1) (cl-cc/ast:make-ast-int :value 2))))
    (declare (ignore _cs))
    (expect type-int :to-be-type-equal-to ty)))

;;; ─── ast-defun → type-symbol ─────────────────────────────────────────────────
(it-sequential
  "collect-defun-returns-symbol-type"
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-defun
        :name
        'my-fn
        :params
        '(x)
        :body
        (list (cl-cc/ast:make-ast-int :value 0))))
    (declare (ignore _cs))
    (expect type-symbol :to-be-type-equal-to ty)))

;;; ─── ast-defvar ──────────────────────────────────────────────────────────────
(it-sequential
  "collect-defvar-returns-symbol-type"
  (multiple-value-bind (ty _cs) (collect
      (cl-cc/ast:make-ast-defvar :name '*x* :value (cl-cc/ast:make-ast-int :value 0)))
    (declare (ignore _cs))
    (expect type-symbol :to-be-type-equal-to ty))
  (multiple-value-bind (ty _cs) (collect (cl-cc/ast:make-ast-defvar :name '*x* :value nil))
    (declare (ignore _cs))
    (expect type-symbol :to-be-type-equal-to ty)))

;;; ─── ast-setq ────────────────────────────────────────────────────────────────
(it-sequential
  "collect-setq-behavior"
  (let* ((env
        (cl-cc/type:type-env-extend 'n (cl-cc/type:type-to-scheme type-int) (empty-env))))
    (multiple-value-bind (ty cs) (collect-in
        (cl-cc/ast:make-ast-setq :var 'n :value (cl-cc/ast:make-ast-int :value 99))
        env)
      (expect type-int :to-be-type-equal-to ty)
      (expect (length cs) :to-equal 1)
      (expect (cl-cc/type:constraint-kind (first cs)) :to-be :equal)))
  (multiple-value-bind (ty cs) (collect
      (cl-cc/ast:make-ast-setq :var 'unbound :value (cl-cc/ast:make-ast-int :value 0)))
    (expect type-int :to-be-type-equal-to ty)
    (expect cs :to-be-null)))

;;; ─── gradual-typing fallback (t arm) ─────────────────────────────────────────
(it-sequential
  "collect-unknown-node-returns-fresh-var"
  (multiple-value-bind (ty cs) (collect
      (cl-cc/ast:make-ast-apply :func (cl-cc/ast:make-ast-int :value 0) :args '()))
    (expect (cl-cc/type:type-var-p ty) :to-be-truthy)
    (expect cs :to-be-null)))
