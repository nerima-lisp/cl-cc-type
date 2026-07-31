;;;; t/unification-test.lisp — Unification Tests
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
  (let ((u (cl-cc/type:make-type-union-raw
            :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify u u)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-left-member-succeeds"
  (let ((u (cl-cc/type:make-type-union-raw
            :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify u cl-cc/type:type-int)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-right-member-succeeds"
  (let ((u (cl-cc/type:make-type-union-raw
            :types (list cl-cc/type:type-int cl-cc/type:type-string))))
    (multiple-value-bind (s ok) (type-unify cl-cc/type:type-string u)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-non-member-fails"
  (let ((u (cl-cc/type:make-type-union-raw
            :types (list cl-cc/type:type-int cl-cc/type:type-string))))
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

(it-sequential "unify-free-var-identity-check-matches-by-id-not-object-eq"
  ;; %UNIFY-FREE-VAR's own identity clause, (AND (TYPE-VAR-P OTHER)
  ;; (TYPE-VAR-EQUAL-P VAR OTHER)), is distinct from TYPE-UNIFY's own
  ;; top-level (EQ T1 T2) fast path: it catches two DIFFERENT TYPE-VAR
  ;; objects that share the same ID (TYPE-VAR-EQUAL-P compares by ID,
  ;; not object identity), which every FRESH-TYPE-VAR call elsewhere in
  ;; this suite avoids by construction (each mints a genuinely unique
  ;; id). Built directly via the low-level constructor to share one.
  (let* ((v1 (cl-cc/type::%make-type-var :id 999001))
         (v2 (cl-cc/type::%make-type-var :id 999001)))
    (multiple-value-bind (s ok) (type-unify v1 v2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

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

(it-sequential "unify-var-bound-in-subst-as-t2"
  ;; %TYPE-UNIFY-VAR-T2's "already bound" branch, (TYPE-UNIFY T1 binding
  ;; SUBST), is the (TYPE-VAR-P T2) mirror of the T1-bound case above;
  ;; every prior test with a bound variable puts it in the T1 position.
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (s (subst-extend a cl-cc/type:type-int nil)))
    (multiple-value-bind (s2 ok) (type-unify cl-cc/type:type-int a s)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s2) :to-be-truthy))))

;;; ─── Impredicative Instantiation (Rank-N types) ───────────────────────────
;;; %TYPE-UNIFY-VAR-T1/-T2 reject unifying a bare, unbound type variable
;;; directly with a still-quantified TYPE-FORALL -- Rank-N types must appear
;;; in argument positions, not be substituted for a monomorphic variable.
;;; Neither error path had any test anywhere in this suite.

(it-sequential "unify-var-t1-rejects-impredicative-instantiation-against-a-forall"
  (let ((v (cl-cc/type:fresh-type-var))
        (forall-ty (cl-cc/type:make-type-forall
                    :var (cl-cc/type:fresh-type-var 'a) :knd nil
                    :body cl-cc/type:type-int)))
    (signals cl-cc/type:type-inference-error (type-unify v forall-ty))))

(it-sequential "unify-var-t2-rejects-impredicative-instantiation-against-a-forall"
  (let ((v (cl-cc/type:fresh-type-var))
        (forall-ty (cl-cc/type:make-type-forall
                    :var (cl-cc/type:fresh-type-var 'a) :knd nil
                    :body cl-cc/type:type-int)))
    (signals cl-cc/type:type-inference-error (type-unify forall-ty v))))

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
          (rhs (cl-cc/type:make-type-arrow-raw
                :params (list cl-cc/type:type-int cl-cc/type:type-int)
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

(it-sequential "unify-var-with-a-var-already-aliased-to-it-via-subst"
  ;; B is already bound to A in SUBST (B is simply an alias for A at this
  ;; point). Unifying A with B is a trivial success -- they already
  ;; denote the same type -- via %UNIFY-FREE-VAR's alias check: OTHER (B)
  ;; resolves through the substitution chain to VAR (A) itself, which is
  ;; identity, not TYPE-OCCURS-P's notion of "occurs nested inside".
  ;; This was a real completeness bug until fixed alongside this test:
  ;; TYPE-OCCURS-P could not distinguish the two, so this case used to
  ;; fail the occurs check and reject a perfectly valid unification.
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (s (subst-extend b a nil)))
    (multiple-value-bind (s2 ok) (type-unify a b s)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s2) :to-be-truthy))))

;;; ─── Union-vs-Union and Intersection-vs-Intersection Unification ───────
;;; type-unify's own dispatch clauses for "both union" / "both intersection"
;;; were unexercised — prior union tests only unified a union against a
;;; single distinct object (eq) or a plain type.

(it-sequential "unify-union-union-reordered-members-succeeds"
  (let ((u1 (cl-cc/type:make-type-union-raw
             :types (list cl-cc/type:type-int cl-cc/type:type-string)))
        (u2 (cl-cc/type:make-type-union-raw
             :types (list cl-cc/type:type-string cl-cc/type:type-int))))
    (multiple-value-bind (s ok) (type-unify u1 u2)
      (expect ok :to-be-truthy)
      (expect (cl-cc/type:substitution-p s) :to-be-truthy))))

(it-sequential "unify-union-union-length-mismatch-fails"
  (let ((u1 (cl-cc/type:make-type-union-raw
             :types (list cl-cc/type:type-int cl-cc/type:type-string)))
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
        (c2 (cl-cc/type:make-type-constructor
             'vector (list cl-cc/type:type-int cl-cc/type:type-string))))
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
        (expect cl-cc/type:type-int :to-be-type-equal-to (cl-cc/type:type-var-upper-bound bounded)))))
  (it-sequential "unify-var-var-upper-bound-merge-cases equal-bounds-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect cl-cc/type:type-int :to-be-type-equal-to (cl-cc/type:type-var-upper-bound b)))))
  (it-sequential "unify-var-var-upper-bound-merge-cases left-tighter-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-any))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-int)))
      ;; a (t1, upper=any) unified against b (t2, upper=int): target=b's
      ;; upper (int) is the LEFT combine argument and is already tighter.
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect cl-cc/type:type-int :to-be-type-equal-to (cl-cc/type:type-var-upper-bound b)))))
  (it-sequential "unify-var-var-upper-bound-merge-cases right-tighter-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-any)))
      ;; a (t1, upper=int) unified against b (t2, upper=any): target=b's
      ;; upper (any) is the LEFT combine argument, source's (int) RIGHT
      ;; argument is tighter and replaces it.
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect cl-cc/type:type-int :to-be-type-equal-to (cl-cc/type:type-var-upper-bound b)))))
  (it-sequential "unify-var-var-upper-bound-merge-cases incomparable-yields-intersection"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-string))
           (b (cl-cc/type:fresh-type-var :name "b" :upper-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-intersection-p (cl-cc/type:type-var-upper-bound b))
                :to-be-truthy))))
  (it-sequential "unify-var-var-bound-merge-fails-when-the-merged-bounds-are-inconsistent"
    ;; %MERGE-TYPE-VAR-BOUNDS-INTO!'s own (WHEN (%BOUNDS-CONSISTENT-P
    ;; lower upper subst) ...) guard had only ever been observed true:
    ;; every case above merges bounds that stay consistent (LOWER <:
    ;; UPPER). A merges its upper bound (STRING) into B, which already
    ;; carries a lower bound (INT) -- since INT is not a subtype of
    ;; STRING, the merged bounds are inconsistent and the whole
    ;; unification must fail rather than silently keeping a
    ;; contradictory bound.
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :upper-bound cl-cc/type:type-string))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-falsy)))))

(progn
  (it-sequential "unify-var-var-lower-bound-merge-cases target-only-kept"
    (let* ((bounded (cl-cc/type:fresh-type-var :name "u" :lower-bound cl-cc/type:type-int))
           (plain (cl-cc/type:fresh-type-var :name "v")))
      (multiple-value-bind (s ok) (type-unify plain bounded)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect cl-cc/type:type-int :to-be-type-equal-to (cl-cc/type:type-var-lower-bound bounded)))))
  (it-sequential "unify-var-var-lower-bound-merge-cases equal-bounds-kept"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect cl-cc/type:type-int :to-be-type-equal-to (cl-cc/type:type-var-lower-bound b)))))
  (it-sequential "unify-var-var-lower-bound-merge-cases either-subtype-consistent"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-any))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy))))
  (it-sequential "unify-var-var-lower-bound-merge-cases either-subtype-consistent-reversed"
    ;; %COMBINE-LOWER-BOUND's clause order is (IS-SUBTYPE-P LEFT RIGHT)
    ;; before (IS-SUBTYPE-P RIGHT LEFT); the case above (TARGET=B's lower
    ;; INT is LEFT, SOURCE=A's lower ANY is RIGHT) always matches the
    ;; first clause (INT <: ANY), so the second clause -- TARGET not a
    ;; subtype of SOURCE, but SOURCE a subtype of TARGET -- had never
    ;; been reached for a lower bound (only for upper, via "right-
    ;; tighter-kept" above). Swapping which side is broader reaches it.
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-int))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-any)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect cl-cc/type:type-any :to-be-type-equal-to (cl-cc/type:type-var-lower-bound b)))))
  (it-sequential "unify-var-var-lower-bound-merge-cases incomparable-yields-union"
    (let* ((a (cl-cc/type:fresh-type-var :name "a" :lower-bound cl-cc/type:type-string))
           (b (cl-cc/type:fresh-type-var :name "b" :lower-bound cl-cc/type:type-int)))
      (multiple-value-bind (s ok) (type-unify a b)
        (declare (ignore s))
        (expect ok :to-be-truthy)
        (expect (cl-cc/type:type-union-p (cl-cc/type:type-var-lower-bound b))
                :to-be-truthy)))))
