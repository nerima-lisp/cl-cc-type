;;;; t/substitution-test.lisp — Substitution & Zonking Tests
;;;
;;; Tests for substitution data structure, zonk on various type constructors,
;;; composition, occurs check, generalize/instantiate, and normalization.
(in-package #:cl-cc/type/unification/test)

;;; ─── Substitution Structure ─────────────────────────────────────────────
(progn
  (it-sequential "subst-lookup-empty-cases empty-subst"
    (let ((v (fresh-type-var 'a)))
      (multiple-value-bind (val found-p) (subst-lookup v (make-substitution))
        (expect val :to-be-null)
        (expect found-p :to-be-falsy))))
  (it-sequential "subst-lookup-empty-cases nil-subst"
    (let ((v (fresh-type-var 'a)))
      (multiple-value-bind (val found-p) (subst-lookup v nil)
        (expect val :to-be-null)
        (expect found-p :to-be-falsy)))))

(it-sequential
  "subst-make-substitution-starts-at-generation-0"
  (let ((s (make-substitution)))
    (expect (substitution-generation s) :to-equal 0)))

(it-sequential
  "subst-extend-leaves-original-unchanged"
  (let* ((v (fresh-type-var 'a))
         (s1 (make-substitution))
         (s2 (subst-extend v type-int s1)))
    (multiple-value-bind (val found) (subst-lookup v s1)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (multiple-value-bind (val found) (subst-lookup v s2)
      (expect found :to-be-truthy)
      (expect val :to-be type-int))))

(it-sequential
  "subst-extend-to-nil-creates-generation-1"
  (let* ((v (fresh-type-var 'a))
         (s (subst-extend v type-int nil)))
    (multiple-value-bind (val found) (subst-lookup v s)
      (expect found :to-be-truthy)
      (expect val :to-be type-int))
    (expect (substitution-generation s) :to-equal 1)))

(it-sequential
  "subst-extend!-mutates-and-increments-generation"
  (let* ((v1 (fresh-type-var 'a))
         (v2 (fresh-type-var 'b))
         (s (make-substitution)))
    (subst-extend! v1 type-int s)
    (multiple-value-bind (val found) (subst-lookup v1 s)
      (expect found :to-be-truthy)
      (expect val :to-be type-int))
    (expect (substitution-generation s) :to-equal 1)
    (subst-extend! v2 type-string s)
    (expect (substitution-generation s) :to-equal 2)))
(it-sequential
  "subst-extend-preserves-test-shadowing-generation-and-isolation"
  (let* ((v1 (fresh-type-var 'a))
         (v2 (fresh-type-var 'b))
         (s0 (make-substitution))
         (s1 (progn
               (setf (substitution-bindings s0)
                     (make-hash-table :test #'equal))
               (subst-extend v1 type-int s0)))
         (s2 (subst-extend v1 type-string s1))
         (s3 (subst-extend v2 type-int s2)))
    (expect (hash-table-test (substitution-bindings s1))
            :to-be (hash-table-test (substitution-bindings s0)))
    (expect (hash-table-test (substitution-bindings s2))
            :to-be (hash-table-test (substitution-bindings s0)))
    (expect (substitution-generation s0) :to-equal 0)
    (expect (substitution-generation s1) :to-equal 1)
    (expect (substitution-generation s2) :to-equal 2)
    (expect (substitution-generation s3) :to-equal 3)
    (expect (hash-table-count (substitution-bindings s0)) :to-equal 0)
    (expect (hash-table-count (substitution-bindings s1)) :to-equal 1)
    (expect (hash-table-count (substitution-bindings s2)) :to-equal 1)
    (expect (hash-table-count (substitution-bindings s3)) :to-equal 2)
    (multiple-value-bind (val found) (subst-lookup v1 s0)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (multiple-value-bind (val found) (subst-lookup v1 s1)
      (expect found :to-be-truthy)
      (expect val :to-be type-int))
    (multiple-value-bind (val found) (subst-lookup v1 s2)
      (expect found :to-be-truthy)
      (expect val :to-be type-string))
    (multiple-value-bind (val found) (subst-lookup v2 s2)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (subst-extend! v2 type-string s3)
    (expect (substitution-generation s3) :to-equal 4)
    (multiple-value-bind (val found) (subst-lookup v2 s2)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (multiple-value-bind (val found) (subst-lookup v2 s3)
      (expect found :to-be-truthy)
      (expect val :to-be type-string))))

;;; ─── Composition ────────────────────────────────────────────────────────
(it-sequential
  "subst-compose-nil-nil-returns-valid-substitution"
  (let ((s (subst-compose nil nil)))
    (expect (substitution-p s) :to-be-truthy)))

(it-sequential
  "subst-compose-nil-left-returns-s2"
  (let* ((v (fresh-type-var 'a))
         (s2 (subst-extend v type-int nil)))
    (expect (subst-compose nil s2) :to-be s2)))

(it-sequential
  "subst-compose-nil-right-preserves-bindings"
  (let* ((v (fresh-type-var 'a))
         (s1 (subst-extend v type-int nil)))
    (multiple-value-bind (val found) (subst-lookup v (subst-compose s1 nil))
      (expect found :to-be-truthy)
      (expect val :to-be type-int))))

(it-sequential
  "subst-compose-resolves-chains-through-s2-range"
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (s2 (subst-extend a b nil))
         (s1 (subst-extend b type-int nil))
         (result (subst-compose s1 s2)))
    (multiple-value-bind (val found) (subst-lookup a result)
      (expect found :to-be-truthy)
      (expect (type-primitive-p val) :to-be-truthy)
      (expect (type-primitive-name val) :to-be 'fixnum))))

(it-sequential
  "subst-compose-s2s-binding-wins-over-s1s-for-a-shared-key"
  ;; The pre-existing chains test above copies S1's B->INT entry through
  ;; because B is absent from S2's bindings (S2 only has key A); the other
  ;; side of that UNLESS -- a key present in BOTH, where S1's raw entry
  ;; must be skipped in favor of S2's (zonked) one -- had never fired.
  (let* ((a (fresh-type-var 'a))
         (s2 (subst-extend a type-string nil))
         (s1 (subst-extend a type-int nil))
         (result (subst-compose s1 s2)))
    (multiple-value-bind (val found) (subst-lookup a result)
      (expect found :to-be-truthy)
      (expect val :to-be type-string))))

;;; ─── Occurs Check ───────────────────────────────────────────────────────
(it-sequential
  "type-occurs-check"
  (let ((s (make-substitution)))
    (let ((v (fresh-type-var 'a)))
      (expect (type-occurs-p v v s) :to-be-truthy)
      (expect
        (type-occurs-p
          v
          (make-type-arrow-raw :params (list v) :return type-int)
          s)
        :to-be-truthy)
      (expect (type-occurs-p v type-int s) :to-be-falsy)))
  (let* ((a (fresh-type-var 'a))
         (b (fresh-type-var 'b))
         (fn-ty
        (make-type-arrow-raw :params (list a) :return type-int))
         (s (subst-extend b fn-ty nil)))
    (expect (type-occurs-p a b s) :to-be-truthy)))

(it-sequential
  "type-occurs-p-treats-a-binders-own-variable-as-shadowed"
  ;; TYPE-OCCURS-P's (IF (AND BOUND-VAR (TYPE-VAR-EQUAL-P VAR BOUND-VAR)) NIL
  ;; ...) short-circuit had never fired: no pre-existing case built a
  ;; binder (TYPE-FORALL/-EXISTS/-LAMBDA/-MU) at all. VAR occurring only as
  ;; a FORALL's own bound variable must not count as a free occurrence,
  ;; even though VAR does appear (shadowed) inside BODY too.
  (let* ((v (fresh-type-var 'a))
         (forall-ty (make-type-forall :var v :knd nil :body v)))
    (expect (type-occurs-p v forall-ty (make-substitution)) :to-be-falsy)))

;;; ─── Generalize / Instantiate ───────────────────────────────────────────
(progn
  (it-sequential "generalize-quantification-cases outside-env"
    (let* ((a (fresh-type-var 'a))
           (env nil)
           (ret a)
           (fn-ty (make-type-arrow-raw :params (list a) :return ret))
           (scheme (generalize env fn-ty)))
      (expect
        (length (type-scheme-quantified-vars scheme))
        :to-equal
        1)))
  (it-sequential "generalize-quantification-cases in-env"
    (let* ((a (fresh-type-var 'a))
           (env
          (type-env-extend
            'x
            (type-to-scheme a)
            (type-env-empty)))
           (ret type-int)
           (fn-ty (make-type-arrow-raw :params (list a) :return ret))
           (scheme (generalize env fn-ty)))
      (expect
        (length (type-scheme-quantified-vars scheme))
        :to-equal
        0))))

(it-sequential
  "instantiate-produces-fresh"
  (let* ((a (fresh-type-var 'a))
         (fn-ty (make-type-arrow-raw :params (list a) :return a))
         (scheme (generalize nil fn-ty))
         (inst1 (instantiate scheme)))
    (expect (type-arrow-p inst1) :to-be-truthy)
    (let ((p1 (car (type-arrow-params inst1)))
          (r1 (type-arrow-return inst1)))
      (expect (type-var-p p1) :to-be-truthy)
      (expect (type-var-equal-p p1 r1) :to-be-truthy)
      (expect (type-var-equal-p p1 a) :to-be-falsy))))

(it-sequential
  "instantiate-skips-fresh-substitution-for-an-already-linked-quantified-var"
  ;; A quantified var whose TYPE-VAR-LINK is already set (as if some
  ;; unrelated earlier unification had reused the same var object)
  ;; resolves through its own link before INSTANTIATE's freshly built
  ;; substitution is ever consulted -- ZONK checks TYPE-VAR-LINK ahead of
  ;; SUBST-LOOKUP. This exercises the bound-preservation loop's
  ;; (TYPE-VAR-P FRESH) guard's false branch: FRESH resolves to the
  ;; linked-to concrete type, not the freshly minted variable.
  (let* ((v (fresh-type-var 'a))
         (scheme (make-type-scheme (list v) v)))
    (setf (type-var-link v) type-int)
    (expect (type-equal-p (instantiate scheme) type-int)
            :to-be-truthy)))

;;; ─── Normalize ──────────────────────────────────────────────────────────
(it-sequential
  "normalize-type-variables-renames-distinct-vars"
  (let* ((fn
        (make-type-arrow-raw
          :params
          (list (fresh-type-var 'xyz))
          :return
          (fresh-type-var 'qqq)))
         (normed (normalize-type-variables fn)))
    (let ((p (car (type-arrow-params normed)))
          (r (type-arrow-return normed)))
      (expect (type-var-p p) :to-be-truthy)
      (expect (type-var-p r) :to-be-truthy)
      (expect (type-var-equal-p p r) :to-be-falsy))))

(it-sequential
  "normalize-type-variables-preserves-shared-variable"
  (let* ((v (fresh-type-var 'x))
         (fn (make-type-arrow-raw :params (list v) :return v))
         (normed (normalize-type-variables fn)))
    (expect
      (type-var-equal-p
        (car (type-arrow-params normed))
        (type-arrow-return normed))
      :to-be-truthy)))

(it-sequential
  "normalize-type-variables-recurses-into-arrow-effects-when-present"
  ;; %NV-NORM's TYPE-ARROW clause only recurses into :EFFECTS when it is
  ;; non-nil; the pre-existing arrow tests never set :EFFECTS at all.
  (let* ((effects (make-type-effect-row
                    :effects (list (make-type-effect-op :name 'io :args nil))
                    :row-var nil))
         (fn (make-type-arrow-raw
              :params (list (fresh-type-var 'p))
              :return (fresh-type-var 'r)
              :effects effects))
         (normed (normalize-type-variables fn)))
    (expect (type-effect-row-p (type-arrow-effects normed)) :to-be-truthy)))

(it-sequential
  "normalize-type-variables-recurses-into-type-product-elements"
  ;; %NV-NORM has a dedicated TYPE-PRODUCT clause never reached by any
  ;; pre-existing NORMALIZE-TYPE-VARIABLES test.
  (let* ((v1 (fresh-type-var 'a))
         (v2 (fresh-type-var 'b))
         (prod (make-type-product :elems (list v1 v2)))
         (normed (normalize-type-variables prod)))
    (expect (type-product-p normed) :to-be-truthy)
    (expect (every #'type-var-p (type-product-elems normed)) :to-be-truthy)
    (expect (type-var-equal-p
             (first (type-product-elems normed))
             (second (type-product-elems normed)))
            :to-be-falsy)))

(it-sequential
  "zonk-env-substitutes-all-bindings"
  (let* ((a (fresh-type-var 'a))
         (env
        (make-type-env
          :bindings
          (list (cons 'x a) (cons 'y type-string))))
         (s (subst-extend a type-int nil))
         (result (zonk-env env s))
         (bindings (type-env-bindings result)))
    (expect (type-primitive-name (cdr (first bindings))) :to-be 'fixnum)
    (expect (type-primitive-name (cdr (second bindings))) :to-be 'string)))

;;; ─── %nv-canonical / %nv-norm (extracted helpers) ────────────────────────────
(it-sequential
  "nv-canonical-creates-fresh-var"
  (let ((mapping (make-hash-table :test #'eql))
        (counter-cell (list 0))
        (v (fresh-type-var 'x)))
    (let ((nv1 (%nv-canonical v mapping counter-cell)))
      (expect (type-var-p nv1) :to-be-truthy)
      (expect (car counter-cell) :to-equal 1)
      (let ((nv2 (%nv-canonical v mapping counter-cell)))
        (expect nv2 :to-be nv1)
        (expect (car counter-cell) :to-equal 1)))))

(it-sequential
  "nv-norm-passes-through-non-var"
  (let ((mapping (make-hash-table :test #'eql))
        (counter-cell (list 0)))
    (expect
      (%nv-norm type-int mapping counter-cell)
      :to-be
      type-int)
    (expect (car counter-cell) :to-equal 0)))

(it-sequential
  "nv-norm-renames-type-var"
  (let ((mapping (make-hash-table :test #'eql))
        (counter-cell (list 0))
        (v (fresh-type-var 'z)))
    (let ((result (%nv-norm v mapping counter-cell)))
      (expect (type-var-p result) :to-be-truthy)
      (expect (eq result v) :to-be-falsy))))

;;; ─── apply-unification ───────────────────────────────────────────────────────
(it-sequential
  "apply-unification-nil-subst-returns-nil"
  (let ((ty (parse-type-specifier 'fixnum)))
    (expect (apply-unification ty nil) :to-be-falsy)))

(it-sequential
  "apply-unification-empty-subst-returns-ty"
  (let ((ty (parse-type-specifier 'fixnum))
        (subst (make-hash-table :test #'eql)))
    (expect (apply-unification ty subst) :to-be ty)))

(it-sequential
  "apply-unification-resolves-mapped-var"
  (let* ((v (fresh-type-var 'x))
         (target (parse-type-specifier 'fixnum))
         (subst (subst-extend v target nil)))
    (let ((result (apply-unification v subst)))
      (expect result :to-be-truthy)
      (expect (type-var-p result) :to-be-falsy))))

(in-package cl-cc/type/unification/test)

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

(it-sequential "substitution-through-function-type"
  (let* ((v      (fresh-type-var))
         (fn     (make-type-arrow-raw :params (list v) :return v))
         (result (zonk fn (subst-extend v type-int (make-substitution)))))
    (expect result :to-be-instance-of 'type-arrow)
    (expect (first (type-arrow-params result)) :to-be-type-equal-to type-int)
    (expect (type-arrow-return result) :to-be-type-equal-to type-int)))

(it-sequential "substitution-unbound-var-is-identity"
  (let* ((v (fresh-type-var))
         (result (zonk v (make-substitution))))
    (expect (type-var-equal-p result v) :to-be-truthy)))

(it-sequential "substitution-bound-var-replaced"
  (let* ((v (fresh-type-var))
         (result (zonk v (subst-extend v type-int (make-substitution)))))
    (expect result :to-be-type-equal-to type-int)))

(it-sequential "substitution-primitive-unchanged"
  (expect (zonk type-int (make-substitution)) :to-be type-int))

(in-package :cl-cc/type/unification/test)

(it-sequential "subst-advanced-operations"
  (let* ((v1  (fresh-type-var))
         (v2  (fresh-type-var))
         (s1  (subst-extend v1 type-int (make-substitution)))
         (s2  (subst-extend v2 v1 (make-substitution)))
         (s12 (subst-compose s1 s2)))
    (expect type-int :to-be-type-equal-to (zonk v2 s12)))
  (let* ((v  (fresh-type-var))
         (fn (make-type-arrow (list v) v))
         (s  (subst-extend v type-bool (make-substitution)))
         (r  (zonk fn s)))
    (expect (type-arrow-p r) :to-be-truthy)
    (expect type-bool :to-be-type-equal-to (first (type-arrow-params r)))
    (expect type-bool :to-be-type-equal-to (type-arrow-return r)))
  (let* ((v  (fresh-type-var))
         (fn (make-type-arrow (list v) type-int))
         (s  (make-substitution))
         (w  (fresh-type-var)))
    (expect (type-occurs-p v fn s) :to-be-truthy)
    (expect (type-occurs-p v type-int s) :to-be-falsy)
    (expect (type-occurs-p w fn s) :to-be-falsy)))

(it-sequential "subst-extend!-mutates-in-place"
  (let* ((v (fresh-type-var))
         (s (make-substitution)))
    (subst-extend! v type-string s)
    (multiple-value-bind (bound found) (subst-lookup v s)
      (expect found :to-be-truthy)
      (expect type-string :to-be-type-equal-to bound))))

(it-sequential "subst-extend-is-functional"
  (let* ((v  (fresh-type-var))
         (s0 (make-substitution))
         (s1 (subst-extend v type-int s0)))
    (multiple-value-bind (b f) (subst-lookup v s0) (declare (ignore b)) (expect f :to-be-falsy))
    (multiple-value-bind (bound found) (subst-lookup v s1)
      (expect found :to-be-truthy)
      (expect type-int :to-be-type-equal-to bound))
    (expect (> (substitution-generation s1) (substitution-generation s0)) :to-be-truthy)))

(it-sequential "subst-empty-has-no-bindings"
  (let ((s (make-substitution)))
    (expect (substitution-p s) :to-be-truthy)
    (expect (substitution-generation s) :to-equal 0)
    (let ((v (fresh-type-var)))
      (multiple-value-bind (bound found) (subst-lookup v s)
        (declare (ignore bound))
        (expect found :to-be-falsy)))))

(it-sequential "type-occurs-p-finds-var-in-nested-union"
  (let* ((a (fresh-type-var :name "a"))
         (ty (make-type-union
              (list type-int
                    (make-type-product :elems
                      (list type-string
                            (make-type-arrow (list a) type-bool)))))))
    (expect (type-occurs-p a ty (make-substitution)) :to-be-truthy)))

(it-sequential "type-occurs-p-follows-subst-chain"
  (let* ((a (fresh-type-var :name "a"))
         (b (fresh-type-var :name "b"))
         (subst (make-substitution)))
    (subst-extend! b a subst)
    (expect (type-occurs-p a b subst) :to-be-truthy)))

(it-sequential "type-occurs-p-direct-arrow-and-absent"
  (let ((a (fresh-type-var :name "a"))
        (b (fresh-type-var :name "b"))
        (s (make-substitution)))
    (expect (type-occurs-p a a s) :to-be-truthy)
    (expect (type-occurs-p a (make-type-arrow (list a) type-int) s) :to-be-truthy)
    (expect (type-occurs-p b (make-type-arrow (list a) type-int) s) :to-be-falsy)))
