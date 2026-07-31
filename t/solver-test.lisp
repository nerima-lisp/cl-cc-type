;;;; t/solver-test.lisp — Constraint Solver Tests
;;;;
;;;; Tests for src/solver.lisp:
;;;; solve-constraints and collect-constraints.
(in-package :cl-cc-type/test)

;;; ─── solve-constraints: equality ───────────────────────────────────────────
(it-sequential
  "solver-equality-trivial"
  (let* ((v (fresh-type-var :name "a"))
         (c (make-equal-constraint v type-int))
         (s (make-substitution)))
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints (list c) s)
      (expect residual :to-be-null)
      (let ((resolved (zonk v new-subst)))
        (expect type-int :to-be-type-equal-to resolved)))))

(it-sequential
  "solver-equality-chain"
  (let* ((v1 (fresh-type-var :name "a"))
         (v2 (fresh-type-var :name "b"))
         (c1 (make-equal-constraint v1 v2))
         (c2 (make-equal-constraint v2 type-int))
         (s (make-substitution)))
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints (list c1 c2) s)
      (expect residual :to-be-null)
      (expect type-int :to-be-type-equal-to (zonk v1 new-subst))
      (expect type-int :to-be-type-equal-to (zonk v2 new-subst)))))

(it-sequential
  "solver-bounded-type-var-equality"
  (let* ((number-type (make-type-primitive :name 'number))
         (upper-ok (fresh-type-var :name "a" :upper-bound number-type))
         (upper-bad (fresh-type-var :name "b" :upper-bound number-type))
         (lower-ok (fresh-type-var :name "c" :lower-bound type-int))
         (lower-bad (fresh-type-var :name "d" :lower-bound type-int)))
    (with-soft-assertions
      (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints
          (list (make-equal-constraint upper-ok type-int))
          (make-substitution))
        (declare (ignore _subst))
        (expect residual :to-be-null))
      (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints
          (list (make-equal-constraint upper-bad type-string))
          (make-substitution))
        (declare (ignore _subst))
        (expect (length residual) :to-equal 1))
      (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints
          (list (make-equal-constraint lower-ok type-any))
          (make-substitution))
        (declare (ignore _subst))
        (expect residual :to-be-null))
      (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints
          (list (make-equal-constraint lower-bad type-string))
          (make-substitution))
        (declare (ignore _subst))
        (expect (length residual) :to-equal 1)))))

(it-sequential
  "solver-bounded-type-var-propagates-through-var"
  (let* ((number-type (make-type-primitive :name 'number))
         (bounded (fresh-type-var :name "a" :upper-bound number-type))
         (survivor (fresh-type-var :name "b")))
    (multiple-value-bind (subst ok) (cl-cc/type:type-unify bounded survivor (make-substitution))
      (expect ok :to-be-truthy)
      (expect number-type :to-be-type-equal-to (cl-cc/type:type-var-upper-bound survivor))
      (multiple-value-bind (_bad bad-ok) (cl-cc/type:type-unify survivor type-string subst)
        (declare (ignore _bad))
        (expect bad-ok :to-be-falsy))
      (multiple-value-bind (_good good-ok) (cl-cc/type:type-unify survivor type-int subst)
        (declare (ignore _good))
        (expect good-ok :to-be-truthy)))))

(it-sequential
  "solver-instantiate-preserves-bounded-quantifier"
  (let* ((number-type (make-type-primitive :name 'number))
         (qvar (fresh-type-var :name "a" :upper-bound number-type :lower-bound type-int))
         (scheme (make-type-scheme (list qvar) qvar))
         (instantiated (instantiate scheme)))
    (expect (type-var-p instantiated) :to-be-truthy)
    (expect (type-var-equal-p qvar instantiated) :to-be-falsy)
    (expect number-type :to-be-type-equal-to (cl-cc/type:type-var-upper-bound instantiated))
    (expect type-int :to-be-type-equal-to (cl-cc/type:type-var-lower-bound instantiated))))

(it-sequential
  "solver-conflicting-equalities-produce-residual"
  (let* ((v (fresh-type-var :name "a"))
         (c1 (make-equal-constraint v type-int))
         (c2 (make-equal-constraint v type-string))
         (s (make-substitution)))
    (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints (list c1 c2) s)
      (declare (ignore _subst))
      (expect (> (length residual) 0) :to-be-truthy))))

(it-sequential
  "solver-trivial-equality-has-no-residual"
  (let* ((c (make-equal-constraint type-int type-int))
         (s (make-substitution)))
    (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints (list c) s)
      (declare (ignore _subst))
      (expect residual :to-be-null))))

;;; ─── solve-constraints: subtyping ──────────────────────────────────────────
(progn
  (it-sequential "solver-binary-constraint-kinds subtype"
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-subtype-constraint type-int type-any)) :to-be-null)
      (expect (length (residuals (make-subtype-constraint type-string type-int))) :to-equal 1)))
  (it-sequential "solver-binary-constraint-kinds typeclass"
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-typeclass-constraint 'eq cl-cc/type:+type-unknown+)) :to-be-null)
      (expect (length (residuals (make-typeclass-constraint 'eq (fresh-type-var :name "a"))))
              :to-equal 1)))
  (it-sequential "solver-binary-constraint-kinds effect-subset"
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-effect-subset-constraint +pure-effect-row+ +io-effect-row+))
              :to-be-null)
      (expect (length (residuals (make-effect-subset-constraint +io-effect-row+ +pure-effect-row+)))
              :to-equal 1)))
  (it-sequential "solver-binary-constraint-kinds mult-leq"
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-mult-leq-constraint :zero :omega)) :to-be-null)
      (expect (length (residuals (make-mult-leq-constraint :omega :zero))) :to-equal 1)))
  (it-sequential "solver-binary-constraint-kinds kind-equal"
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-kind-equal-constraint +kind-type+ +kind-type+)) :to-be-null)
      (expect (length (residuals (make-kind-equal-constraint +kind-type+ +kind-effect+)))
              :to-equal 1)))
  (it-sequential "solver-typeclass-constraint-on-a-concrete-type"
    ;; The pre-existing typeclass test only ever passes +TYPE-UNKNOWN+ (a
    ;; TYPE-ERROR whose message happens to be "unknown", so it takes the
    ;; TYPE-UNKNOWN-P clause) or a free TYPE-VAR; a concrete, resolved type
    ;; reaching TYPE-ERROR-P and HAS-TYPECLASS-INSTANCE-P was untested.
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-typeclass-constraint
                           'eq (cl-cc/type:make-type-error :message "not-the-unknown-sentinel")))
              :to-be-truthy)
      (register-typeclass-instance 'solver-typeclass-test type-int nil)
      (expect (residuals (make-typeclass-constraint 'solver-typeclass-test type-int))
              :to-be-null)
      (expect (length (residuals (make-typeclass-constraint 'solver-typeclass-test type-string)))
              :to-equal 1)))
  (it-sequential "solver-effect-subset-constraint-is-trivially-satisfied-for-a-non-effect-row"
    ;; %SOLVE-EFFECT-SUBSET-CONSTRAINT's (AND (type-effect-row-p e1)
    ;; (type-effect-row-p e2)) had only ever seen both sides be real effect
    ;; rows; when either side is not an effect row at all, the constraint
    ;; does not apply and is discharged rather than kept residual.
    (flet ((residuals (c)
             (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
      (expect (residuals (make-effect-subset-constraint type-int +io-effect-row+))
              :to-be-null))))

;;; ─── solve-constraints: row-lacks ──────────────────────────────────────────
(it-sequential
  "solver-row-lacks-constraints"
  (flet ((residuals (c)
           (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
    (expect
      (residuals (make-row-lacks-constraint (fresh-type-var :name "rho") 'x))
      :to-be-null)
    (expect
      (residuals
        (make-row-lacks-constraint
          (make-type-record :fields (list (cons 'y type-int)) :row-var nil)
          'x))
      :to-be-null)
    (expect
      (length
        (residuals
          (make-row-lacks-constraint
            (make-type-record :fields (list (cons 'x type-int)) :row-var nil)
            'x)))
      :to-equal
      1)))

(it-sequential
  "solver-row-lacks-open-concrete-row-stays-residual"
  ;; Per %SOLVE-ROW-LACKS-CONSTRAINT's own docstring, "concrete open rows
  ;; stay residual so the caller can refine them later" -- a later
  ;; refinement of the row variable could still add the label, so this
  ;; must never be discharged as satisfied. Previously it always was
  ;; (a real bug fixed in src/solver.lisp alongside this test): neither
  ;; an open row already containing the label nor one that does not yet
  ;; can be soundly treated as "definitely lacks it."
  (flet ((residuals (c)
           (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
    (expect
      (length
        (residuals
          (make-row-lacks-constraint
            (make-type-record :fields (list (cons 'x type-int))
                               :row-var (fresh-type-var :name "rho"))
            'x)))
      :to-equal
      1)
    (expect
      (length
        (residuals
          (make-row-lacks-constraint
            (make-type-record :fields (list (cons 'y type-int))
                               :row-var (fresh-type-var :name "rho"))
            'x)))
      :to-equal
      1)))

(it-sequential
  "solver-row-lacks-covers-variant-and-effect-row-shapes"
  ;; The pre-existing row-lacks tests only ever pass a TYPE-RECORD; the OR
  ;; disjuncts for TYPE-VARIANT-P and TYPE-EFFECT-ROW-P, and the
  ;; effect-row-specific EFFECT-ROW-MEMBER-P branch, were untested.
  (flet ((residuals (c)
           (nth-value 1 (cl-cc/type:solve-constraints (list c) (make-substitution)))))
    (expect
      (residuals
        (make-row-lacks-constraint
         (make-type-variant :cases (list (cons :some type-int)) :row-var nil)
         :none))
      :to-be-null)
    (expect
      (length
       (residuals
        (make-row-lacks-constraint
         (make-type-effect-row
          :effects (list (make-type-effect-op :name :io :args nil))
          :row-var nil)
         :io)))
      :to-equal
      1)))

(it-sequential
  "solver-row-lacks-non-row-concrete-type-falls-through-to-the-catchall-clause"
  ;; The prior test drives all three OR disjuncts (TYPE-RECORD-P,
  ;; TYPE-VARIANT-P, TYPE-EFFECT-ROW-P) true at least once, but every RHO
  ;; that ever reaches the third disjunct in this suite turns out to
  ;; actually be a TYPE-EFFECT-ROW, so that disjunct's own FALSE outcome --
  ;; and the outer COND's final (T (VALUES CURRENT-SUBST C)) clause it
  ;; leads to -- had never been reached. A plain TYPE-PRIMITIVE is
  ;; concrete (not a TYPE-VAR) yet none of record/variant/effect-row.
  (expect
    (length
     (nth-value 1 (cl-cc/type:solve-constraints
                   (list (make-row-lacks-constraint type-int 'x))
                   (make-substitution))))
    :to-equal
    1))

;;; ─── solve-constraints: implication ────────────────────────────────────────
(it-sequential
  "solver-implication-solvable"
  (let* ((v (fresh-type-var :name "a"))
         (given (list (make-equal-constraint v type-int)))
         (wanted (list (make-equal-constraint v type-int)))
         (c (make-implication-constraint (list v) given wanted))
         (s (make-substitution)))
    (multiple-value-bind (_subst residual) (cl-cc/type:solve-constraints (list c) s)
      (declare (ignore _subst))
      (expect residual :to-be-null))))

(it-sequential
  "solver-defaults-numeric-typeclass-vars"
  (let* ((v (fresh-type-var :name "a"))
         (c (make-typeclass-constraint 'num v))
         (s (make-substitution)))
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints (list c) s)
      (expect residual :to-be-null)
      (expect type-int :to-be-type-equal-to (zonk v new-subst)))))

;;; ─── solve-constraints: empty input ────────────────────────────────────────
(it-sequential
  "solver-empty-and-nil-subst"
  (multiple-value-bind (subst residual) (cl-cc/type:solve-constraints nil nil)
    (expect (substitution-p subst) :to-be-truthy)
    (expect residual :to-be-null))
  (multiple-value-bind (subst residual) (cl-cc/type:solve-constraints
      (list (make-equal-constraint type-int type-int))
      nil)
    (expect (substitution-p subst) :to-be-truthy)
    (expect residual :to-be-null)))

;;; ─── solve-constraints: mixed ──────────────────────────────────────────────
(it-sequential
  "solver-mixed-constraints"
  (let* ((v (fresh-type-var :name "a"))
         (c1 (make-equal-constraint v type-int))
         (c2 (make-subtype-constraint type-string type-int))
         (c3 (make-mult-leq-constraint :zero :omega))
         (s (make-substitution)))
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints (list c1 c2 c3) s)
      (expect type-int :to-be-type-equal-to (zonk v new-subst))
      (expect (length residual) :to-equal 1)
      (expect (constraint-kind (first residual)) :to-be :subtype))))

(it-sequential
  "solve-constraints-trivial-success"
  (let* ((subst (cl-cc/type:make-substitution))
         (result (cl-cc/type:solve-constraints nil subst)))
    (expect (cl-cc/type:substitution-p result) :to-be-truthy))
  (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
      (list (cl-cc/type:make-equal-constraint type-int type-int))
      (cl-cc/type:make-substitution))
    (expect (cl-cc/type:substitution-p new-subst) :to-be-truthy)
    (expect residual :to-be-null)))

(it-sequential
  "solve-constraints-equal-binds-var"
  (let* ((tvar (cl-cc/type:fresh-type-var "a"))
         (subst (cl-cc/type:make-substitution)))
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
        (list (cl-cc/type:make-equal-constraint tvar type-int))
        subst)
      (expect residual :to-be-null)
      (let ((bound (cl-cc/type:zonk tvar new-subst)))
        (expect type-int :to-be-type-equal-to bound)))))

(progn
  (it-sequential "solve-constraints-produces-residual equal-mismatch"
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
        (list (cl-cc/type:make-equal-constraint type-int type-string))
        (cl-cc/type:make-substitution))
      (declare (ignore new-subst))
      (expect (length residual) :to-equal 1)))
  (it-sequential "solve-constraints-produces-residual subtype-violation"
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
        (list (cl-cc/type:make-subtype-constraint type-string type-int))
        (cl-cc/type:make-substitution))
      (declare (ignore new-subst))
      (expect (length residual) :to-equal 1))))

(progn
  (it-sequential "solve-constraints-subtype-ok fixnum<integer"
    (let ((t1 (make-type-primitive :name 'fixnum))
          (t2 (make-type-primitive :name 'integer)))
      (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
          (list (cl-cc/type:make-subtype-constraint t1 t2))
          (cl-cc/type:make-substitution))
        (declare (ignore new-subst))
        (expect residual :to-be-null))))
  (it-sequential "solve-constraints-subtype-ok integer<number"
    (let ((t1 (make-type-primitive :name 'integer))
          (t2 (make-type-primitive :name 'number)))
      (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
          (list (cl-cc/type:make-subtype-constraint t1 t2))
          (cl-cc/type:make-substitution))
        (declare (ignore new-subst))
        (expect residual :to-be-null))))
  (it-sequential "solve-constraints-subtype-ok float<real"
    (let ((t1 (make-type-primitive :name 'float))
          (t2 (make-type-primitive :name 'real)))
      (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
          (list (cl-cc/type:make-subtype-constraint t1 t2))
          (cl-cc/type:make-substitution))
        (declare (ignore new-subst))
        (expect residual :to-be-null)))))

(it-sequential
  "solve-constraints-multiple-sequential"
  (let* ((ta (cl-cc/type:fresh-type-var "a"))
         (tb (cl-cc/type:fresh-type-var "b")))
    (multiple-value-bind (new-subst residual) (cl-cc/type:solve-constraints
        (list
          (cl-cc/type:make-equal-constraint ta type-int)
          (cl-cc/type:make-equal-constraint tb ta))
        (cl-cc/type:make-substitution))
      (expect residual :to-be-null)
      (expect type-int :to-be-type-equal-to (cl-cc/type:zonk ta new-subst))
      (expect type-int :to-be-type-equal-to (cl-cc/type:zonk tb new-subst)))))
