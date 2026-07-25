;;;; t/unification-tests.lisp — Unification Tests
;;;
;;; Tests for type-unify, type-unify-lists, and unify-effect-rows
;;; focusing on coverage gaps: product types, intersection types,
;;; type constructors, effect rows, and edge cases.

(in-package :cl-cc-type/test)
;;; ─── Product Type Unification ───────────────────────────────────────────

(progn
  (it-sequential "unify-product-cases same-types"
    (let ((types (let ((p (cl-cc/type:make-type-product
                            :elems (list cl-cc/type:type-int cl-cc/type:type-string))))
                   (list p p)))
          (expected-ok t))
      (declare (ignorable types expected-ok))
      (destructuring-bind (lhs rhs) types
        (multiple-value-bind (s ok) (type-unify lhs rhs)
          (if expected-ok
              (progn
                (expect ok :to-be-truthy)
                (expect (cl-cc/type:substitution-p s) :to-be-truthy))
              (expect ok :to-be-falsy))))))
  (it-sequential "unify-product-cases length-mismatch"
    (let ((types (list (cl-cc/type:make-type-product :elems (list cl-cc/type:type-int))
                        (cl-cc/type:make-type-product
                         :elems (list cl-cc/type:type-int cl-cc/type:type-string))))
          (expected-ok nil))
      (declare (ignorable types expected-ok))
      (destructuring-bind (lhs rhs) types
        (multiple-value-bind (s ok) (type-unify lhs rhs)
          (if expected-ok
              (progn
                (expect ok :to-be-truthy)
                (expect (cl-cc/type:substitution-p s) :to-be-truthy))
              (expect ok :to-be-falsy)))))))

;;; ─── Union Type Unification ─────────────────────────────────────────────

(it-sequential "unify-union-identical-succeeds"
  (let ((u (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify u u)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-left-member-succeeds"
  (let ((u (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify u cl-cc/type:type-int)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-right-member-succeeds"
  (let ((u (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify cl-cc/type:type-string u)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-non-member-fails"
  (let ((u (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (_ ok) (type-unify u cl-cc/type:type-bool)
      (declare (ignore _))
      (expect ok :to-be-falsy))))

;;; ─── Primitive Unification Edge Cases ───────────────────────────────────

(it-sequential "unify-different-primitives-fail"
  (multiple-value-bind (s ok) (type-unify cl-cc/type:type-int cl-cc/type:type-string)
    (declare (ignore s))
    (expect ok :to-be-falsy)))

(it-sequential "unify-error-type-with-anything"
  (let ((err (cl-cc/type:make-type-error)))
    (multiple-value-bind (s ok) (type-unify err cl-cc/type:type-int)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))
    (multiple-value-bind (s ok) (type-unify cl-cc/type:type-string err)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

;;; ─── Variable Binding ───────────────────────────────────────────────────

(it-sequential "unify-var-bound-in-subst"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (s (subst-extend a cl-cc/type:type-int nil)))
    (multiple-value-bind (s2 ok) (type-unify a cl-cc/type:type-int s)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s2) :to-be-truthy))))

(it-sequential "unify-var-bound-conflicting-fails"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (s (subst-extend a cl-cc/type:type-int nil)))
    (multiple-value-bind (s2 ok) (type-unify a cl-cc/type:type-string s)
      (declare (ignore s2))
      (expect ok :to-be-falsy))))

;;; ─── type-unify-lists ───────────────────────────────────────────────────

(it-sequential "unify-lists-empty"
  (multiple-value-bind (s ok) (type-unify-lists nil nil (make-substitution))
    (expect ok :to-be-truthy)
    (expect (cl-cc/type:substitution-p s) :to-be-truthy)))

(it-sequential "unify-lists-length-mismatch"
  (multiple-value-bind (s ok) (type-unify-lists
                                (list cl-cc/type:type-int)
                                nil
                                (make-substitution))
    (declare (ignore s))
    (expect ok :to-be-falsy)))

(it-sequential "unify-lists-pairwise"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b)))
    (multiple-value-bind (s ok)
        (type-unify-lists (list a b)
                          (list cl-cc/type:type-int cl-cc/type:type-string)
                          (make-substitution))
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-primitive-name (zonk a s)) :to-be 'fixnum)
      (expect (cl-cc/type:type-primitive-name (zonk b s)) :to-be 'string))))

(it-sequential "unify-lists-partial-failure"
  (multiple-value-bind (s ok)
      (type-unify-lists (list cl-cc/type:type-int cl-cc/type:type-int)
                        (list cl-cc/type:type-int cl-cc/type:type-string)
                        (make-substitution))
    (declare (ignore s))
    (expect ok :to-be-falsy)))

;;; ─── Arrow Unification Edge Cases ───────────────────────────────────────

(progn
  (it-sequential "unify-arrow-mismatch-cases arity-mismatch"
    (let ((lhs (cl-cc/type:make-type-arrow-raw :params (list cl-cc/type:type-int)
                                                :return cl-cc/type:type-int))
          (rhs (cl-cc/type:make-type-arrow-raw :params (list cl-cc/type:type-int cl-cc/type:type-int)
                                                :return cl-cc/type:type-int)))
      (declare (ignorable lhs rhs))
      (multiple-value-bind (s ok) (type-unify lhs rhs)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-arrow-mismatch-cases return-mismatch"
    (let ((lhs (cl-cc/type:make-type-arrow-raw :params (list cl-cc/type:type-int)
                                                :return cl-cc/type:type-int))
          (rhs (cl-cc/type:make-type-arrow-raw :params (list cl-cc/type:type-int)
                                                :return cl-cc/type:type-string)))
      (declare (ignorable lhs rhs))
      (multiple-value-bind (s ok) (type-unify lhs rhs)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

;;; ─── Effect Row Unification ─────────────────────────────────────────────

(it-sequential "unify-effect-row-empty-rows-succeed"
  (let* ((r1 (cl-cc/type:make-type-effect-row :effects nil :row-var nil))
         (r2 (cl-cc/type:make-type-effect-row :effects nil :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-effect-row-same-effects-succeed"
  (let* ((e1 (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (e2 (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e1) :row-var nil))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e2) :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-effect-row-open-absorbs-extra-effect"
  (let* ((rv (cl-cc/type:fresh-type-var 'r))
         (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e-io e-exn) :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (let ((bound (zonk rv s)))
        (expect (cl-cc/type:type-effect-row-p bound) :to-be-truthy)))))

(it-sequential "unify-effect-row-closed-rejects-extra-effect"
  (let* ((e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var nil))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e-io e-exn) :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

;;; ─── Occurs Check in Unification ────────────────────────────────────────

(it-sequential "unify-occurs-check-circular"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (fn (cl-cc/type:make-type-arrow-raw :params (list a) :return cl-cc/type:type-int)))
    (multiple-value-bind (s ok) (type-unify a fn)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

;;; ─── Advanced Feature Node Unification ──────────────────────────────────
;;; %type-advanced-unify / %unify-payload-pairs / %type-advanced-payload-unify
;;; / %unify-property-alist were entirely unexercised: no test previously
;;; unified two type-advanced nodes at all.

(it-sequential "unify-advanced-same-feature-succeeds"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :name 'widget
                                          :args (list cl-cc/type:type-int)
                                          :properties '((:mode . strict))))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :name 'widget
                                          :args (list cl-cc/type:type-int)
                                          :properties '((:mode . strict)))))
    (multiple-value-bind (s ok) (type-unify a b)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-advanced-different-feature-id-fails"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :name 'widget))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9002" :name 'widget)))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-mismatched-typed-args-fail"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list cl-cc/type:type-int)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-type-node-vs-plain-arg-fails"
  ;; one side's arg is a type-node, the other's is a plain symbol at the same
  ;; cons position: exercises the "shapes don't match" payload branch.
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list cl-cc/type:type-int)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                          :args (list 'not-a-type))))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-nonequal-plain-args-fail"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :args (list 1)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :args (list 2))))
    (multiple-value-bind (s ok) (type-unify a b)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-advanced-equal-evidence-atoms-succeed"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :evidence "proof"))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :evidence "proof")))
    (multiple-value-bind (s ok) (type-unify a b)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(progn
  (it-sequential "unify-advanced-property-alist-cases length-mismatch"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict) (:extra . t)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-advanced-property-alist-cases key-missing"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:other . strict)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-advanced-property-alist-cases value-mismatch"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . strict))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties '((:mode . loose)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy))))
  (it-sequential "unify-advanced-property-alist-cases typed-value-unifies"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-int))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-int)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:substitution-p s) :to-be-truthy))))
  (it-sequential "unify-advanced-property-alist-cases typed-value-fails"
    (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-int))))
          (b (cl-cc/type::%make-type-advanced :feature-id "FR-9001"
                                            :properties (list (cons :ty cl-cc/type:type-string)))))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

;;; ─── Union-vs-Union and Intersection-vs-Intersection Unification ───────
;;; type-unify's own dispatch clauses for "both union" / "both intersection"
;;; were unexercised — prior union tests only unified a union against a
;;; single distinct object (eq) or a plain type.

(it-sequential "unify-union-union-reordered-members-succeeds"
  (let ((u1 (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int cl-cc/type:type-string)))
        (u2 (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-string cl-cc/type:type-int))))
    (multiple-value-bind (s ok) (type-unify u1 u2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-union-length-mismatch-fails"
  (let ((u1 (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int cl-cc/type:type-string)))
        (u2 (cl-cc/type:make-type-union-raw :types (list cl-cc/type:type-int))))
    (multiple-value-bind (s ok) (type-unify u1 u2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-intersection-intersection-succeeds"
  (let ((i1 (cl-cc/type:make-type-intersection (list cl-cc/type:type-int cl-cc/type:type-string)))
        (i2 (cl-cc/type:make-type-intersection (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify i1 i2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-intersection-intersection-length-mismatch-fails"
  (let ((i1 (cl-cc/type:make-type-intersection (list cl-cc/type:type-int cl-cc/type:type-string)))
        (i2 (cl-cc/type:make-type-intersection (list cl-cc/type:type-int))))
    (multiple-value-bind (s ok) (type-unify i1 i2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

;;; ─── Type-Constructor (curried type-app) Unification ────────────────────
;;; The "both are type-constructors" clause in type-unify was entirely
;;; unexercised.

(it-sequential "unify-type-constructor-same-name-same-args-succeeds"
  (let ((c1 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int)))
        (c2 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int))))
    (multiple-value-bind (s ok) (type-unify c1 c2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-type-constructor-same-name-diff-args-fails"
  (let ((c1 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int)))
        (c2 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify c1 c2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-type-constructor-diff-name-fails"
  (let ((c1 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int)))
        (c2 (cl-cc/type:make-type-constructor 'matrix (list cl-cc/type:type-int))))
    (multiple-value-bind (s ok) (type-unify c1 c2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

(it-sequential "unify-type-constructor-arity-mismatch-fails"
  (let ((c1 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int)))
        (c2 (cl-cc/type:make-type-constructor 'vector (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify c1 c2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

;;; ─── Refinement Type Unification ────────────────────────────────────────
;;; type-unify's refinement clauses (unify through the base type) were
;;; unexercised.

(it-sequential "unify-refinement-t1-recurses-into-base"
  (let ((r (cl-cc/type:make-type-refinement :base cl-cc/type:type-int :predicate nil)))
    (multiple-value-bind (s ok) (type-unify r cl-cc/type:type-int)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-refinement-t2-recurses-into-base"
  (let ((r (cl-cc/type:make-type-refinement :base cl-cc/type:type-int :predicate nil)))
    (multiple-value-bind (s ok) (type-unify cl-cc/type:type-int r)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-refinement-both-sides-recurse-and-fail-on-base-mismatch"
  (let ((r1 (cl-cc/type:make-type-refinement :base cl-cc/type:type-int :predicate nil))
        (r2 (cl-cc/type:make-type-refinement :base cl-cc/type:type-string :predicate nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

;;; ─── Primitive Identity vs Structural Equality ──────────────────────────

(it-sequential "unify-distinct-but-name-equal-primitive-objects-succeeds"
  ;; two separately-allocated (not EQ) type-primitive structs sharing a name
  ;; must still unify via the primitive-name-equality clause, not the EQ
  ;; identity shortcut.
  (let ((p1 (cl-cc/type:make-type-primitive :name 'fixnum))
        (p2 (cl-cc/type:make-type-primitive :name 'fixnum)))
    (multiple-value-bind (s ok) (type-unify p1 p2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

;;; ─── Unhandled Shape Pair (final fallback) ──────────────────────────────

(it-sequential "unify-unhandled-shape-pair-fails"
  (let ((r (cl-cc/type:make-type-record :fields (list (cons 'x cl-cc/type:type-int)) :row-var nil))
        (v (cl-cc/type:make-type-variant :cases (list (cons 'y cl-cc/type:type-int)) :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r v)
      (declare (ignore s))
      (expect ok :to-be-falsy))))

;;; ─── unify-effect-rows: remaining branches ──────────────────────────────
;;; Prior tests only exercised: both-sides-empty-no-row-vars, same-effects,
;;; open-absorbs-extra (row2 has extras, rv1 present), closed-rejects-extra
;;; (row2 has extras, rv1 absent). The branches below were unexercised.

(it-sequential "unify-effect-row-equal-sets-both-row-vars-unify-vars"
  (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
         (rv2 (cl-cc/type:fresh-type-var 'r2))
         (e (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv1))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv2)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-var-equal-p (zonk rv1 s) (zonk rv2 s)) :to-be-truthy))))

(it-sequential "unify-effect-row-equal-sets-only-row1-has-var"
  (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
         (e (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv1))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e) :row-var nil)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-effect-row-p (zonk rv1 s)) :to-be-truthy))))

(it-sequential "unify-effect-row-equal-sets-only-row2-has-var"
  (let* ((rv2 (cl-cc/type:fresh-type-var 'r2))
         (e (cl-cc/type:make-type-effect-op :name 'io :args nil))
         (r1 (cl-cc/type:make-type-effect-row :effects (list e) :row-var nil))
         (r2 (cl-cc/type:make-type-effect-row :effects (list e) :row-var rv2)))
    (multiple-value-bind (s ok) (type-unify r1 r2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:type-effect-row-p (zonk rv2 s)) :to-be-truthy))))

(progn
  (it-sequential "unify-effect-row-row1-extra-effects-cases row2-var-present-succeeds"
    (let* ((rv2 (cl-cc/type:fresh-type-var 'r2))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io e-exn) :row-var nil))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv2)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-effect-row-p (zonk rv2 s)) :to-be-truthy))))
  (it-sequential "unify-effect-row-row1-extra-effects-cases row2-var-absent-fails"
    (let* ((e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io e-exn) :row-var nil))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var nil)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

(progn
  (it-sequential "unify-effect-row-both-unique-effects-cases both-vars-present-succeeds"
    (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
           (rv2 (cl-cc/type:fresh-type-var 'r2))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv1))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-exn) :row-var rv2)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:substitution-p s) :to-be-truthy))))
  (it-sequential "unify-effect-row-both-unique-effects-cases missing-row-var-fails"
    (let* ((rv1 (cl-cc/type:fresh-type-var 'r1))
           (e-io (cl-cc/type:make-type-effect-op :name 'io :args nil))
           (e-exn (cl-cc/type:make-type-effect-op :name 'exn :args nil))
           (r1 (cl-cc/type:make-type-effect-row :effects (list e-io) :row-var rv1))
           (r2 (cl-cc/type:make-type-effect-row :effects (list e-exn) :row-var nil)))
      (multiple-value-bind (s ok) (type-unify r1 r2)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

;;; ─── Bounded-Type-Var Merge: %combine-upper-bound / %combine-lower-bound ──
;;; Prior tests only exercised the "target bound absent" branch (both
;;; combine-* functions return the source's bound unchanged via their first
;;; clause). The remaining branches — target-only, type-equal, either-side
;;; subtype, and the incomparable fallback — were unexercised.

(progn
  (it-sequential "unify-var-var-upper-bound-merge-cases target-only-kept"
    (let* ((bounded (cl-cc/type:fresh-type-var :name "u" :upper-bound cl-cc/type:type-int))
           (plain (cl-cc/type:fresh-type-var :name "v")))
      ;; plain (t1, no bound) unified against bounded (t2): merges plain's
      ;; (nil) bound as SOURCE into bounded's (type-int) TARGET bound.
      (multiple-value-bind (s ok) (type-unify plain bounded)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-equal-p cl-cc/type:type-int
                                         (cl-cc/type:type-var-upper-bound bounded))
                :to-be-truthy))))
  (it-sequential "unify-var-var-upper-bound-merge-cases equal-bounds-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-equal-p cl-cc/type:type-int
                                         (cl-cc/type:type-var-upper-bound b))
                :to-be-truthy))))
  (it-sequential "unify-var-var-upper-bound-merge-cases left-tighter-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-any))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-int)))
      ;; a (t1, upper=any) unified against b (t2, upper=int): target=b's
      ;; upper (int) is the LEFT combine argument and is already tighter.
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-equal-p cl-cc/type:type-int
                                         (cl-cc/type:type-var-upper-bound b))
                :to-be-truthy))))
  (it-sequential "unify-var-var-upper-bound-merge-cases right-tighter-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-any)))
      ;; a (t1, upper=int) unified against b (t2, upper=any): target=b's
      ;; upper (any) is the LEFT combine argument, source's (int) RIGHT
      ;; argument is tighter and replaces it.
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-equal-p cl-cc/type:type-int
                                         (cl-cc/type:type-var-upper-bound b))
                :to-be-truthy))))
  (it-sequential "unify-var-var-upper-bound-merge-cases incomparable-yields-intersection"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-string))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-intersection-p (cl-cc/type:type-var-upper-bound b))
                :to-be-truthy)))))

(progn
  (it-sequential "unify-var-var-lower-bound-merge-cases target-only-kept"
    (let* ((bounded (cl-cc/type:fresh-type-var :name "u" :lower-bound cl-cc/type:type-int))
           (plain (cl-cc/type:fresh-type-var :name "v")))
      (multiple-value-bind (s ok) (type-unify plain bounded)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-equal-p cl-cc/type:type-int
                                         (cl-cc/type:type-var-lower-bound bounded))
                :to-be-truthy))))
  (it-sequential "unify-var-var-lower-bound-merge-cases equal-bounds-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-equal-p cl-cc/type:type-int
                                         (cl-cc/type:type-var-lower-bound b))
                :to-be-truthy))))
  (it-sequential "unify-var-var-lower-bound-merge-cases either-subtype-consistent"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-any))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy))))
  (it-sequential "unify-var-var-lower-bound-merge-cases incomparable-yields-union"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-string))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-union-p (cl-cc/type:type-var-lower-bound b))
                :to-be-truthy)))))
