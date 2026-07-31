;;;; t/substitution-zonk-test.lisp — Zonk: Various Type Constructors Tests
;;;
;;; Tests for src/substitution.lisp: zonk over each type-node constructor
;;; (arrow, product, forall, and the rest) — one example per constructor,
;;; since each exercises a different set of fields/accessors. Split out of
;;; t/substitution-test.lisp, which keeps the substitution structure,
;;; composition, occurs check, generalize/instantiate, and normalize sections.
(in-package :cl-cc-type/test)

;;; ─── Zonk: Various Type Constructors ────────────────────────────────────
(it-sequential
  "zonk-nil-primitive-and-unbound-are-unchanged"
  (let ((s (make-substitution)))
    (expect (zonk nil s) :to-be-null)
    (expect (zonk cl-cc/type:type-int s) :to-be cl-cc/type:type-int)
    (let ((v (cl-cc/type:fresh-type-var 'a)))
      (expect (zonk v s) :to-be v))))

(it-sequential
  "zonk-bound-var-resolves-to-bound-type"
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (s (subst-extend v cl-cc/type:type-int nil)))
    (expect (zonk v s) :to-be cl-cc/type:type-int)))

(it-sequential
  "zonk-chain-resolves-to-terminal"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (s (make-substitution)))
    (subst-extend! a b s)
    (subst-extend! b cl-cc/type:type-int s)
    (let ((result (zonk a s)))
      (expect (cl-cc/type:type-primitive-p result) :to-be-truthy)
      (expect (cl-cc/type:type-primitive-name result) :to-be 'fixnum))))

(it-sequential
  "zonk-arrow-type-substitutes-params-and-return"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (fn-ty (cl-cc/type:make-type-arrow-raw :params (list a) :return b))
         (s (make-substitution)))
    (subst-extend! a cl-cc/type:type-int s)
    (subst-extend! b cl-cc/type:type-string s)
    (let ((result (zonk fn-ty s)))
      (expect (cl-cc/type:type-arrow-p result) :to-be-truthy)
      (expect
        (cl-cc/type:type-primitive-name (car (cl-cc/type:type-arrow-params result)))
        :to-be
        'fixnum)
      (expect
        (cl-cc/type:type-primitive-name (cl-cc/type:type-arrow-return result))
        :to-be
        'string))))

(it-sequential
  "zonk-product-type-substitutes-elements"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (prod (cl-cc/type:make-type-product :elems (list a cl-cc/type:type-string)))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk prod s)))
    (expect (cl-cc/type:type-product-p result) :to-be-truthy)
    (expect (length (cl-cc/type:type-product-elems result)) :to-equal 2)
    (expect
      (cl-cc/type:type-primitive-name (first (cl-cc/type:type-product-elems result)))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-forall-type-substitutes-body"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (forall-ty (cl-cc/type:make-type-forall :var a :body b))
         (s (subst-extend b cl-cc/type:type-int nil))
         (result (zonk forall-ty s)))
    (expect (cl-cc/type:type-forall-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-forall-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-type-app-substitutes-fun-and-arg"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (app-ty (cl-cc/type:make-type-app :fun a :arg b))
         (s (make-substitution)))
    (subst-extend! a cl-cc/type:type-int s)
    (subst-extend! b cl-cc/type:type-string s)
    (let ((result (zonk app-ty s)))
      (expect (cl-cc/type:type-app-p result) :to-be-truthy)
      (expect
        (cl-cc/type:type-primitive-name (cl-cc/type:type-app-fun result))
        :to-be
        'fixnum)
      (expect
        (cl-cc/type:type-primitive-name (cl-cc/type:type-app-arg result))
        :to-be
        'string))))

(it-sequential
  "zonk-union-type-substitutes-members"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (union-ty
        (cl-cc/type:make-type-union-raw :types (list a cl-cc/type:type-string)))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk union-ty s)))
    (expect (cl-cc/type:type-union-p result) :to-be-truthy)
    (expect (length (cl-cc/type:type-union-types result)) :to-equal 2)))

(it-sequential
  "zonk-effect-row-var-is-resolved"
  (let* ((rv (cl-cc/type:fresh-type-var 'r))
         (eff (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (row (cl-cc/type:make-type-effect-row :effects (list eff) :row-var rv))
         (s
        (subst-extend
          rv
          (cl-cc/type:make-type-effect-row :effects nil :row-var nil)
          nil)))
    (expect (cl-cc/type:type-effect-row-p (zonk row s)) :to-be-truthy)))

(it-sequential
  "zonk-effect-rows-are-merged-when-var-resolves-to-row"
  (let* ((rv (cl-cc/type:fresh-type-var 'r))
         (eff1 (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (eff2 (cl-cc/type:make-type-effect-op :name 'exn :args nil))
         (row1 (cl-cc/type:make-type-effect-row :effects (list eff1) :row-var rv))
         (row2 (cl-cc/type:make-type-effect-row :effects (list eff2) :row-var nil))
         (s (subst-extend rv row2 nil))
         (result (zonk row1 s)))
    (expect (cl-cc/type:type-effect-row-p result) :to-be-truthy)
    (expect (length (cl-cc/type:type-effect-row-effects result)) :to-equal 2)))

(it-sequential
  "zonk-variant-type-substitutes-cases"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (variant-ty (cl-cc/type:make-type-variant
                      :cases (list (cons 'ok a) (cons 'err cl-cc/type:type-string))
                      :row-var nil))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk variant-ty s)))
    (expect (cl-cc/type:type-variant-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cdr (assoc 'ok (cl-cc/type:type-variant-cases result))))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-variant-type-resolves-an-open-row-var"
  ;; The pre-existing case above always builds its variant with :ROW-VAR
  ;; NIL, so ZONK's (WHEN (TYPE-VARIANT-ROW-VAR ty) ...) true branch had
  ;; never fired.
  (let* ((rv (cl-cc/type:fresh-type-var 'r))
         (variant-ty (cl-cc/type:make-type-variant
                      :cases (list (cons 'ok cl-cc/type:type-int))
                      :row-var rv))
         (s (subst-extend rv (cl-cc/type:fresh-type-var 'r2) nil))
         (result (zonk variant-ty s)))
    (expect (cl-cc/type:type-variant-p result) :to-be-truthy)
    (expect (cl-cc/type:type-var-p (cl-cc/type:type-variant-row-var result)) :to-be-truthy)))

(it-sequential
  "zonk-intersection-type-substitutes-types"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (inter-ty (cl-cc/type:make-type-intersection (list a cl-cc/type:type-string)))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk inter-ty s)))
    (expect (cl-cc/type:type-intersection-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (first (cl-cc/type:type-intersection-types result)))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-exists-type-substitutes-body"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (exists-ty (cl-cc/type:make-type-exists :var a :body b))
         (s (subst-extend b cl-cc/type:type-int nil))
         (result (zonk exists-ty s)))
    (expect (cl-cc/type:type-exists-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-exists-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-lambda-type-substitutes-body"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (lambda-ty (cl-cc/type:make-type-lambda :var a :body b))
         (s (subst-extend b cl-cc/type:type-int nil))
         (result (zonk lambda-ty s)))
    (expect (cl-cc/type:type-lambda-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-lambda-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-mu-type-substitutes-body"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (mu-ty (cl-cc/type:make-type-mu :var a :body b))
         (s (subst-extend b cl-cc/type:type-int nil))
         (result (zonk mu-ty s)))
    (expect (cl-cc/type:type-mu-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-mu-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-refinement-type-substitutes-base-preserves-predicate"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (refine-ty (cl-cc/type:make-type-refinement :base a :predicate 'positive-p))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk refine-ty s)))
    (expect (cl-cc/type:type-refinement-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-refinement-base result))
      :to-be
      'fixnum)
    (expect (cl-cc/type:type-refinement-predicate result) :to-be 'positive-p)))

(it-sequential
  "zonk-linear-type-substitutes-base-preserves-grade"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (linear-ty (cl-cc/type:make-type-linear :base a :grade :one))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk linear-ty s)))
    (expect (cl-cc/type:type-linear-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-linear-base result))
      :to-be
      'fixnum)
    (expect (cl-cc/type:type-linear-grade result) :to-be :one)))

(it-sequential
  "zonk-capability-type-substitutes-base-preserves-cap"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (cap-ty (cl-cc/type:make-type-capability :base a :cap 'read))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk cap-ty s)))
    (expect (cl-cc/type:type-capability-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-capability-base result))
      :to-be
      'fixnum)
    (expect (cl-cc/type:type-capability-cap result) :to-be 'read)))

(it-sequential
  "zonk-effect-op-type-substitutes-args"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (op-ty (cl-cc/type:make-type-effect-op :name 'state :args (list a)))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk op-ty s)))
    (expect (cl-cc/type:type-effect-op-p result) :to-be-truthy)
    (expect (cl-cc/type:type-effect-op-name result) :to-be 'state)
    (expect
      (cl-cc/type:type-primitive-name (first (cl-cc/type:type-effect-op-args result)))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-advanced-type-substitutes-args-properties-and-evidence"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (advanced-ty
          (cl-cc/type:make-type-advanced
           :feature-id "FR-1501" :name 'test
           :args (list a)
           :properties (list (cons :k a))
           :evidence a))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk advanced-ty s)))
    (expect (cl-cc/type:type-advanced-p result) :to-be-truthy)
    (expect
      (cl-cc/type:type-primitive-name (first (cl-cc/type:type-advanced-args result)))
      :to-be
      'fixnum)
    (expect
      (cl-cc/type:type-primitive-name (cdr (first (cl-cc/type:type-advanced-properties result))))
      :to-be
      'fixnum)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-advanced-evidence result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-handler-type-substitutes-input-and-output"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (eff (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (handler-ty (cl-cc/type:make-type-handler :effect eff :input a :output b))
         (s (make-substitution)))
    (subst-extend! a cl-cc/type:type-int s)
    (subst-extend! b cl-cc/type:type-string s)
    (let ((result (zonk handler-ty s)))
      (expect (cl-cc/type:type-handler-p result) :to-be-truthy)
      (expect
        (cl-cc/type:type-primitive-name (cl-cc/type:type-handler-input result))
        :to-be
        'fixnum)
      (expect
        (cl-cc/type:type-primitive-name (cl-cc/type:type-handler-output result))
        :to-be
        'string))))

(it-sequential
  "zonk-constraint-type-substitutes-type-arg"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (constraint-ty (cl-cc/type:make-type-constraint :class-name 'eq :type-arg a))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (zonk constraint-ty s)))
    (expect (cl-cc/type:type-constraint-p result) :to-be-truthy)
    (expect (cl-cc/type:type-constraint-class-name result) :to-be 'eq)
    (expect
      (cl-cc/type:type-primitive-name (cl-cc/type:type-constraint-type-arg result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-qualified-type-substitutes-constraints-and-body"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (constraint-ty (cl-cc/type:make-type-constraint :class-name 'eq :type-arg a))
         (qualified-ty (cl-cc/type:make-type-qualified :constraints (list constraint-ty) :body b))
         (s (make-substitution)))
    (subst-extend! a cl-cc/type:type-int s)
    (subst-extend! b cl-cc/type:type-string s)
    (let ((result (zonk qualified-ty s)))
      (expect (cl-cc/type:type-qualified-p result) :to-be-truthy)
      (expect
        (cl-cc/type:type-primitive-name
         (cl-cc/type:type-constraint-type-arg
          (first (cl-cc/type:type-qualified-constraints result))))
        :to-be
        'fixnum)
      (expect
        (cl-cc/type:type-primitive-name (cl-cc/type:type-qualified-body result))
        :to-be
        'string))))

