;;;; t/constraint-test.lisp — Constraint Language Tests
;;;;
;;;; Tests for src/constraint.lisp:
;;;; Smart constructors, constraint-free-vars, constraint-substitute.

(in-package :cl-cc-type/test)

;;; ─── Smart constructors ────────────────────────────────────────────────────

(it-sequential "constraint-equal-creation"
  (let ((c (make-equal-constraint type-int type-string)))
    (expect (constraint-p c) :to-be-truthy)
    (expect (constraint-kind c) :to-be :equal)
    (expect (length (constraint-args c)) :to-equal 2)
    (expect type-int :to-be-type-equal-to (first (constraint-args c)))
    (expect type-string :to-be-type-equal-to (second (constraint-args c)))))

(it-sequential "constraint-subtype-creation"
  (let ((c (make-subtype-constraint type-int type-any)))
    (expect (constraint-kind c) :to-be :subtype)
    (expect type-int :to-be-type-equal-to (first (constraint-args c)))))

(it-sequential "constraint-typeclass-creation"
  (let ((c (make-typeclass-constraint 'num type-int)))
    (expect (constraint-kind c) :to-be :typeclass)
    (expect (first (constraint-args c)) :to-be 'num)
    (expect type-int :to-be-type-equal-to (second (constraint-args c)))))

(it-sequential "constraint-implication-creation"
  (let* ((v (fresh-type-var :name "a"))
         (given (list (make-equal-constraint v type-int)))
         (wanted (list (make-subtype-constraint v type-any)))
         (c (make-implication-constraint (list v) given wanted)))
    (expect (constraint-kind c) :to-be :implication)
    (expect (length (constraint-args c)) :to-equal 3)
    (expect (length (first (constraint-args c))) :to-equal 1)
    (expect (length (second (constraint-args c))) :to-equal 1)
    (expect (length (third (constraint-args c))) :to-equal 1)))

(it-sequential "constraint-ground-kinds-creation"
  (expect (constraint-kind
           (make-effect-subset-constraint +pure-effect-row+ +io-effect-row+)) :to-be :effect-subset)
  (expect (constraint-kind
           (make-kind-equal-constraint +kind-type+ +kind-type+)) :to-be :kind-equal)
  (let ((c (make-mult-leq-constraint :zero :omega)))
    (expect (constraint-kind c) :to-be :mult-leq)
    (expect (first  (constraint-args c)) :to-be :zero)
    (expect (second (constraint-args c)) :to-be :omega))
  (let* ((rv (fresh-type-var :name "rho"))
         (c  (make-row-lacks-constraint rv 'x)))
    (expect (constraint-kind c) :to-be :row-lacks)
    (expect (second (constraint-args c)) :to-be 'x)))

;;; ─── constraint-free-vars ──────────────────────────────────────────────────

(it-sequential "constraint-free-vars-binary-constraints equal"
  (let* ((v1 (fresh-type-var :name "a")) (v2 (fresh-type-var :name "b")))
    (expect (length (cl-cc/type:constraint-free-vars (make-equal-constraint v1 v2))) :to-equal 2)))

(it-sequential "constraint-free-vars-binary-constraints subtype"
  (let* ((v1 (fresh-type-var :name "x")) (v2 (fresh-type-var :name "y")))
    (expect (length (cl-cc/type:constraint-free-vars (make-subtype-constraint v1 v2)))
            :to-equal 2)))

(it-sequential "constraint-free-vars-dedup-and-binding"
  (let* ((v  (fresh-type-var :name "a"))
         (c1 (make-equal-constraint v v)))
    (expect (length (cl-cc/type:constraint-free-vars c1)) :to-equal 1))
  (let* ((v  (fresh-type-var :name "a"))
         (c2 (make-typeclass-constraint 'eq v)))
    (expect (length (cl-cc/type:constraint-free-vars c2)) :to-equal 1))
  (let* ((v  (fresh-type-var :name "a"))
         (c3 (make-implication-constraint
              (list v)
              (list (make-equal-constraint v type-int))
              (list (make-subtype-constraint v type-any)))))
    (expect (length (cl-cc/type:constraint-free-vars c3)) :to-equal 0)))

(it-sequential "constraint-free-vars-ground-types-empty"
  (expect (cl-cc/type:constraint-free-vars (make-mult-leq-constraint :one :omega)) :to-be-null)
  (expect (cl-cc/type:constraint-free-vars (make-kind-equal-constraint +kind-type+ +kind-effect+))
          :to-be-null))

(it-sequential "constraint-free-vars-row-lacks with-var"
  (let* ((c (make-row-lacks-constraint (fresh-type-var :name "rho") 'x))
         (fvs (cl-cc/type:constraint-free-vars c)))
    (expect (length fvs) :to-equal 1)))

(it-sequential "constraint-free-vars-row-lacks without-var"
  (let* ((c (make-row-lacks-constraint 'not-a-type 'x))
         (fvs (cl-cc/type:constraint-free-vars c)))
    (expect (length fvs) :to-equal 0)))

;;; ─── constraint-substitute ─────────────────────────────────────────────────

(it-sequential "constraint-substitute-equal-applies-binding"
  (let* ((v (fresh-type-var :name "a"))
         (c (make-equal-constraint v type-int))
         (s (make-substitution)))
    (subst-extend! v type-string s)
    (let ((c2 (cl-cc/type:constraint-substitute c s)))
      (expect (constraint-kind c2) :to-be :equal)
      (expect type-string :to-be-type-equal-to (first (constraint-args c2)))
      (expect type-int :to-be-type-equal-to (second (constraint-args c2))))))

(it-sequential "constraint-substitute-subtype-applies-bindings"
  (let* ((v1 (fresh-type-var :name "a"))
         (v2 (fresh-type-var :name "b"))
         (c  (make-subtype-constraint v1 v2))
         (s  (make-substitution)))
    (subst-extend! v1 type-int s)
    (subst-extend! v2 type-any s)
    (let ((c2 (cl-cc/type:constraint-substitute c s)))
      (expect type-int :to-be-type-equal-to (first (constraint-args c2)))
      (expect type-any :to-be-type-equal-to (second (constraint-args c2))))))

(it-sequential "constraint-substitute-typeclass-applies-binding"
  (let* ((v  (fresh-type-var :name "a"))
         (c  (make-typeclass-constraint 'show v))
         (s  (make-substitution)))
    (subst-extend! v type-string s)
    (let ((c2 (cl-cc/type:constraint-substitute c s)))
      (expect (first (constraint-args c2)) :to-be 'show)
      (expect type-string :to-be-type-equal-to (second (constraint-args c2))))))

(it-sequential "constraint-substitute-ground-and-effect"
  (let ((s (make-substitution)))
    (let ((c (make-mult-leq-constraint :one :omega)))
      (expect (cl-cc/type:constraint-substitute c s) :to-be c))
    (let ((c (make-kind-equal-constraint +kind-type+ +kind-type+)))
      (expect (cl-cc/type:constraint-substitute c s) :to-be c)))
  (let* ((v  (fresh-type-var :name "ε"))
         (c  (make-effect-subset-constraint v +pure-effect-row+))
         (s  (make-substitution)))
    (subst-extend! v +io-effect-row+ s)
    (expect (constraint-kind (cl-cc/type:constraint-substitute c s)) :to-be :effect-subset)))

(it-sequential "constraint-kind-check subtype"
  (expect (cl-cc/type:constraint-kind
           (cl-cc/type:make-subtype-constraint type-int type-any))
          :to-be :subtype))

(it-sequential "constraint-kind-check typeclass"
  (expect (cl-cc/type:constraint-kind
           (cl-cc/type:make-typeclass-constraint 'num (cl-cc/type:fresh-type-var "a")))
          :to-be :typeclass))

(it-sequential "constraint-kind-check implication"
  (expect (cl-cc/type:constraint-kind
           (let* ((tv (cl-cc/type:fresh-type-var "a"))
                  (eq-c (cl-cc/type:make-equal-constraint tv type-int))
                  (tc-c (cl-cc/type:make-typeclass-constraint 'num tv)))
             (cl-cc/type:make-implication-constraint (list tv) (list eq-c) (list tc-c))))
          :to-be :implication))

(it-sequential "constraint-kind-check effect-subset"
  (expect (cl-cc/type:constraint-kind
           (cl-cc/type:make-effect-subset-constraint
            cl-cc/type:+pure-effect-row+ cl-cc/type:+io-effect-row+))
          :to-be :effect-subset))

(it-sequential "constraint-kind-check kind-equal"
  (expect (cl-cc/type:constraint-kind
           (cl-cc/type:make-kind-equal-constraint
            cl-cc/type:+kind-type+ cl-cc/type:+kind-type+))
          :to-be :kind-equal))

(it-sequential "constraint-kind-check mult-leq"
  (expect (cl-cc/type:constraint-kind
           (cl-cc/type:make-mult-leq-constraint :one :omega))
          :to-be :mult-leq))

(it-sequential "constraint-kind-check row-lacks"
  (expect (cl-cc/type:constraint-kind
           (cl-cc/type:make-row-lacks-constraint (cl-cc/type:fresh-type-var "r") 'x))
          :to-be :row-lacks))

(it-sequential "constraint-free-vars-count"
  (let* ((tv1   (cl-cc/type:fresh-type-var "a"))
         (tv2   (cl-cc/type:fresh-type-var "b"))
         (ceq   (cl-cc/type:make-equal-constraint tv1 tv2))
         (ctc   (cl-cc/type:make-typeclass-constraint 'num tv1)))
    (expect (length (cl-cc/type:constraint-free-vars ceq)) :to-equal 2)
    (expect (length (cl-cc/type:constraint-free-vars ctc)) :to-equal 1)))

(it-sequential "constraint-free-vars-zero-vars mult-leq"
  (expect (cl-cc/type:constraint-free-vars (cl-cc/type:make-mult-leq-constraint :one :omega))
          :to-be-null))

(it-sequential "constraint-free-vars-zero-vars kind-equal"
  (expect (cl-cc/type:constraint-free-vars
           (cl-cc/type:make-kind-equal-constraint
            cl-cc/type:+kind-type+ cl-cc/type:+kind-effect+))
          :to-be-null))

(it-sequential "constraint-free-vars-zero-vars implication-quantified"
  (let* ((tv    (cl-cc/type:fresh-type-var "a"))
         (inner (cl-cc/type:make-equal-constraint tv type-int)))
    (expect (cl-cc/type:constraint-free-vars
             (cl-cc/type:make-implication-constraint (list tv) (list inner) (list inner)))
            :to-be-null)))

(it-sequential "constraint-substitute"
  (let* ((tv    (cl-cc/type:fresh-type-var "a"))
         (c     (cl-cc/type:make-equal-constraint tv type-string))
         (subst (cl-cc/type:subst-extend tv type-int (cl-cc/type:make-substitution)))
         (c2    (cl-cc/type:constraint-substitute c subst)))
    (expect (cl-cc/type:constraint-kind c2) :to-be :equal)
    (expect type-int :to-be-type-equal-to (first (cl-cc/type:constraint-args c2))))
  (let* ((c     (cl-cc/type:make-mult-leq-constraint :one :omega))
         (c2    (cl-cc/type:constraint-substitute c (cl-cc/type:make-substitution))))
    (expect c2 :to-be c)))
