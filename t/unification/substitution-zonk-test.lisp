;;;; t/substitution-zonk-test.lisp — Zonk: Various Type Constructors Tests
;;;
;;; Tests for src/substitution.lisp: zonk over each type-node constructor
;;; (arrow, product, forall, and the rest) — one example per constructor,
;;; since each exercises a different set of fields/accessors. Split out of
;;; t/substitution-test.lisp, which keeps the substitution structure,
;;; composition, occurs check, generalize/instantiate, and normalize sections.
(in-package #:cl-cc/type/unification/test)

;;; ─── Zonk: Various Type Constructors ────────────────────────────────────
(it-sequential
  "zonk-nil-primitive-and-unbound-are-unchanged"
  (let ((s (make-substitution)))
    (expect (zonk nil s) :to-be-null)
    (expect (zonk type-int s) :to-be type-int)
    (let ((v (fresh-type-var 'a)))
      (expect (zonk v s) :to-be v))))

(it-sequential
  "zonk-bound-var-resolves-to-bound-type"
  (let* ((v (fresh-type-var 'a))
         (s (subst-extend v type-int nil)))
    (expect (zonk v s) :to-be type-int)))

(it-sequential
  "zonk-chain-resolves-to-terminal"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (s (make-substitution)))
    (subst-extend! a b s)
    (subst-extend! b type-int s)
    (let ((result (zonk a s)))
      (expect (type-primitive-p result) :to-be-truthy)
      (expect (type-primitive-name result) :to-be 'fixnum))))

(it-sequential
  "zonk-arrow-type-substitutes-params-and-return"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (fn-ty (make-type-arrow-raw :params (list a) :return b))
         (s (make-substitution)))
    (subst-extend! a type-int s)
    (subst-extend! b type-string s)
    (let ((result (zonk fn-ty s)))
      (expect (type-arrow-p result) :to-be-truthy)
      (expect
        (type-primitive-name (car (type-arrow-params result)))
        :to-be
        'fixnum)
      (expect
        (type-primitive-name (type-arrow-return result))
        :to-be
        'string))))

(it-sequential
  "zonk-product-type-substitutes-elements"
  (let* ((a (fresh-type-var 'a))
         (prod (make-type-product :elems (list a type-string)))
         (s (subst-extend a type-int nil))
         (result (zonk prod s)))
    (expect (type-product-p result) :to-be-truthy)
    (expect (length (type-product-elems result)) :to-equal 2)
    (expect
      (type-primitive-name (first (type-product-elems result)))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-forall-type-substitutes-body"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (forall-ty (make-type-forall :var a :body b))
         (s (subst-extend b type-int nil))
         (result (zonk forall-ty s)))
    (expect (type-forall-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-forall-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-type-app-substitutes-fun-and-arg"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (app-ty (make-type-app :fun a :arg b))
         (s (make-substitution)))
    (subst-extend! a type-int s)
    (subst-extend! b type-string s)
    (let ((result (zonk app-ty s)))
      (expect (type-app-p result) :to-be-truthy)
      (expect
        (type-primitive-name (type-app-fun result))
        :to-be
        'fixnum)
      (expect
        (type-primitive-name (type-app-arg result))
        :to-be
        'string))))

(it-sequential
  "zonk-union-type-substitutes-members"
  (let* ((a (fresh-type-var 'a))
         (union-ty
        (make-type-union-raw :types (list a type-string)))
         (s (subst-extend a type-int nil))
         (result (zonk union-ty s)))
    (expect (type-union-p result) :to-be-truthy)
    (expect (length (type-union-types result)) :to-equal 2)))

(it-sequential
  "zonk-effect-row-var-is-resolved"
  (let* ((rv (fresh-type-var 'r))
         (eff (make-type-effect-op :name 'io :args nil))
         (row (make-type-effect-row :effects (list eff) :row-var rv))
         (s
        (subst-extend
          rv
          (make-type-effect-row :effects nil :row-var nil)
          nil)))
    (expect (type-effect-row-p (zonk row s)) :to-be-truthy)))

(it-sequential
  "zonk-effect-rows-are-merged-when-var-resolves-to-row"
  (let* ((rv (fresh-type-var 'r))
         (eff1 (make-type-effect-op :name 'io :args nil))
         (eff2 (make-type-effect-op :name 'exn :args nil))
         (row1 (make-type-effect-row :effects (list eff1) :row-var rv))
         (row2 (make-type-effect-row :effects (list eff2) :row-var nil))
         (s (subst-extend rv row2 nil))
         (result (zonk row1 s)))
    (expect (type-effect-row-p result) :to-be-truthy)
    (expect (length (type-effect-row-effects result)) :to-equal 2)))

(it-sequential
  "zonk-variant-type-substitutes-cases"
  (let* ((a (fresh-type-var 'a))
         (variant-ty (make-type-variant
                      :cases (list (cons 'ok a) (cons 'err type-string))
                      :row-var nil))
         (s (subst-extend a type-int nil))
         (result (zonk variant-ty s)))
    (expect (type-variant-p result) :to-be-truthy)
    (expect
      (type-primitive-name (cdr (assoc 'ok (type-variant-cases result))))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-variant-type-resolves-an-open-row-var"
  ;; The pre-existing case above always builds its variant with :ROW-VAR
  ;; NIL, so ZONK's (WHEN (TYPE-VARIANT-ROW-VAR ty) ...) true branch had
  ;; never fired.
  (let* ((rv (fresh-type-var 'r))
         (variant-ty (make-type-variant
                      :cases (list (cons 'ok type-int))
                      :row-var rv))
         (s (subst-extend rv (fresh-type-var 'r2) nil))
         (result (zonk variant-ty s)))
    (expect (type-variant-p result) :to-be-truthy)
    (expect (type-var-p (type-variant-row-var result)) :to-be-truthy)))

(it-sequential
  "zonk-intersection-type-substitutes-types"
  (let* ((a (fresh-type-var 'a))
         (inter-ty (make-type-intersection (list a type-string)))
         (s (subst-extend a type-int nil))
         (result (zonk inter-ty s)))
    (expect (type-intersection-p result) :to-be-truthy)
    (expect
      (type-primitive-name (first (type-intersection-types result)))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-exists-type-substitutes-body"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (exists-ty (make-type-exists :var a :body b))
         (s (subst-extend b type-int nil))
         (result (zonk exists-ty s)))
    (expect (type-exists-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-exists-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-lambda-type-substitutes-body"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (lambda-ty (make-type-lambda :var a :body b))
         (s (subst-extend b type-int nil))
         (result (zonk lambda-ty s)))
    (expect (type-lambda-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-lambda-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-mu-type-substitutes-body"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (mu-ty (make-type-mu :var a :body b))
         (s (subst-extend b type-int nil))
         (result (zonk mu-ty s)))
    (expect (type-mu-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-mu-body result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-refinement-type-substitutes-base-preserves-predicate"
  (let* ((a (fresh-type-var 'a))
         (refine-ty (make-type-refinement :base a :predicate 'positive-p))
         (s (subst-extend a type-int nil))
         (result (zonk refine-ty s)))
    (expect (type-refinement-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-refinement-base result))
      :to-be
      'fixnum)
    (expect (type-refinement-predicate result) :to-be 'positive-p)))

(it-sequential
  "zonk-linear-type-substitutes-base-preserves-grade"
  (let* ((a (fresh-type-var 'a))
         (linear-ty (make-type-linear :base a :grade :one))
         (s (subst-extend a type-int nil))
         (result (zonk linear-ty s)))
    (expect (type-linear-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-linear-base result))
      :to-be
      'fixnum)
    (expect (type-linear-grade result) :to-be :one)))

(it-sequential
  "zonk-capability-type-substitutes-base-preserves-cap"
  (let* ((a (fresh-type-var 'a))
         (cap-ty (make-type-capability :base a :cap 'read))
         (s (subst-extend a type-int nil))
         (result (zonk cap-ty s)))
    (expect (type-capability-p result) :to-be-truthy)
    (expect
      (type-primitive-name (type-capability-base result))
      :to-be
      'fixnum)
    (expect (type-capability-cap result) :to-be 'read)))

(it-sequential
  "zonk-effect-op-type-substitutes-args"
  (let* ((a (fresh-type-var 'a))
         (op-ty (make-type-effect-op :name 'state :args (list a)))
         (s (subst-extend a type-int nil))
         (result (zonk op-ty s)))
    (expect (type-effect-op-p result) :to-be-truthy)
    (expect (type-effect-op-name result) :to-be 'state)
    (expect
      (type-primitive-name (first (type-effect-op-args result)))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-advanced-type-substitutes-args-properties-and-evidence"
  (let* ((a (fresh-type-var 'a))
         (advanced-ty
          (%make-type-advanced
           :feature-id "FR-1501" :name 'test
           :args (list a)
           :properties (list (cons :k a))
           :evidence a))
         (s (subst-extend a type-int nil))
         (result (zonk advanced-ty s)))
    (expect (type-advanced-p result) :to-be-truthy)
    (expect
      (type-primitive-name (first (type-advanced-args result)))
      :to-be
      'fixnum)
    (expect
      (type-primitive-name (cdr (first (type-advanced-properties result))))
      :to-be
      'fixnum)
    (expect
      (type-primitive-name (type-advanced-evidence result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-handler-type-substitutes-input-and-output"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (eff (make-type-effect-op :name 'io :args nil))
         (handler-ty (make-type-handler :effect eff :input a :output b))
         (s (make-substitution)))
    (subst-extend! a type-int s)
    (subst-extend! b type-string s)
    (let ((result (zonk handler-ty s)))
      (expect (type-handler-p result) :to-be-truthy)
      (expect
        (type-primitive-name (type-handler-input result))
        :to-be
        'fixnum)
      (expect
        (type-primitive-name (type-handler-output result))
        :to-be
        'string))))

(it-sequential
  "zonk-constraint-type-substitutes-type-arg"
  (let* ((a (fresh-type-var 'a))
         (constraint-ty (make-type-constraint :class-name 'eq :type-arg a))
         (s (subst-extend a type-int nil))
         (result (zonk constraint-ty s)))
    (expect (type-constraint-p result) :to-be-truthy)
    (expect (type-constraint-class-name result) :to-be 'eq)
    (expect
      (type-primitive-name (type-constraint-type-arg result))
      :to-be
      'fixnum)))

(it-sequential
  "zonk-qualified-type-substitutes-constraints-and-body"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (constraint-ty (make-type-constraint :class-name 'eq :type-arg a))
         (qualified-ty (make-type-qualified :constraints (list constraint-ty) :body b))
         (s (make-substitution)))
    (subst-extend! a type-int s)
    (subst-extend! b type-string s)
    (let ((result (zonk qualified-ty s)))
      (expect (type-qualified-p result) :to-be-truthy)
      (expect
        (type-primitive-name
         (type-constraint-type-arg
          (first (type-qualified-constraints result))))
        :to-be
        'fixnum)
      (expect
        (type-primitive-name (type-qualified-body result))
        :to-be
        'string))))

