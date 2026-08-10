;;;; t/substitution-test.lisp — Substitution & Zonking Tests
;;;
;;; Tests for substitution data structure, zonk on various type constructors,
;;; composition, occurs check, generalize/instantiate, and normalization.
(in-package :cl-cc-type/test)

;;; ─── Substitution Structure ─────────────────────────────────────────────
(progn
  (it-sequential "subst-lookup-empty-cases empty-subst"
    (let ((v (cl-cc/type:fresh-type-var 'a)))
      (multiple-value-bind (val found-p) (subst-lookup v (make-substitution))
        (expect val :to-be-null)
        (expect found-p :to-be-falsy))))
  (it-sequential "subst-lookup-empty-cases nil-subst"
    (let ((v (cl-cc/type:fresh-type-var 'a)))
      (multiple-value-bind (val found-p) (subst-lookup v nil)
        (expect val :to-be-null)
        (expect found-p :to-be-falsy)))))

(it-sequential
  "subst-make-substitution-starts-at-generation-0"
  (let ((s (make-substitution)))
    (expect (substitution-generation s) :to-equal 0)))

(it-sequential
  "subst-extend-leaves-original-unchanged"
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (s1 (make-substitution))
         (s2 (subst-extend v cl-cc/type:type-int s1)))
    (multiple-value-bind (val found) (subst-lookup v s1)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (multiple-value-bind (val found) (subst-lookup v s2)
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-int))))

(it-sequential
  "subst-extend-to-nil-creates-generation-1"
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (s (subst-extend v cl-cc/type:type-int nil)))
    (multiple-value-bind (val found) (subst-lookup v s)
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-int))
    (expect (substitution-generation s) :to-equal 1)))

(it-sequential
  "subst-extend!-mutates-and-increments-generation"
  (let* ((v1 (cl-cc/type:fresh-type-var 'a))
         (v2 (cl-cc/type:fresh-type-var 'b))
         (s (make-substitution)))
    (subst-extend! v1 cl-cc/type:type-int s)
    (multiple-value-bind (val found) (subst-lookup v1 s)
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-int))
    (expect (substitution-generation s) :to-equal 1)
    (subst-extend! v2 cl-cc/type:type-string s)
    (expect (substitution-generation s) :to-equal 2)))
(it-sequential
  "subst-extend-preserves-test-shadowing-generation-and-isolation"
  (let* ((v1 (cl-cc/type:fresh-type-var 'a))
         (v2 (cl-cc/type:fresh-type-var 'b))
         (s0 (make-substitution))
         (s1 (progn
               (setf (substitution-bindings s0)
                     (make-hash-table :test #'equal))
               (subst-extend v1 cl-cc/type:type-int s0)))
         (s2 (subst-extend v1 cl-cc/type:type-string s1))
         (s3 (subst-extend v2 cl-cc/type:type-int s2)))
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
      (expect val :to-be cl-cc/type:type-int))
    (multiple-value-bind (val found) (subst-lookup v1 s2)
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-string))
    (multiple-value-bind (val found) (subst-lookup v2 s2)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (subst-extend! v2 cl-cc/type:type-string s3)
    (expect (substitution-generation s3) :to-equal 4)
    (multiple-value-bind (val found) (subst-lookup v2 s2)
      (declare (ignore val))
      (expect found :to-be-falsy))
    (multiple-value-bind (val found) (subst-lookup v2 s3)
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-string))))

;;; ─── Composition ────────────────────────────────────────────────────────
(it-sequential
  "subst-compose-nil-nil-returns-valid-substitution"
  (let ((s (subst-compose nil nil)))
    (expect (cl-cc/type:substitution-p s) :to-be-truthy)))

(it-sequential
  "subst-compose-nil-left-returns-s2"
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (s2 (subst-extend v cl-cc/type:type-int nil)))
    (expect (subst-compose nil s2) :to-be s2)))

(it-sequential
  "subst-compose-nil-right-preserves-bindings"
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (s1 (subst-extend v cl-cc/type:type-int nil)))
    (multiple-value-bind (val found) (subst-lookup v (subst-compose s1 nil))
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-int))))

(it-sequential
  "subst-compose-resolves-chains-through-s2-range"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (s2 (subst-extend a b nil))
         (s1 (subst-extend b cl-cc/type:type-int nil))
         (result (subst-compose s1 s2)))
    (multiple-value-bind (val found) (subst-lookup a result)
      (expect found :to-be-truthy)
      (expect (cl-cc/type:type-primitive-p val) :to-be-truthy)
      (expect (cl-cc/type:type-primitive-name val) :to-be 'fixnum))))

(it-sequential
  "subst-compose-s2s-binding-wins-over-s1s-for-a-shared-key"
  ;; The pre-existing chains test above copies S1's B->INT entry through
  ;; because B is absent from S2's bindings (S2 only has key A); the other
  ;; side of that UNLESS -- a key present in BOTH, where S1's raw entry
  ;; must be skipped in favor of S2's (zonked) one -- had never fired.
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (s2 (subst-extend a cl-cc/type:type-string nil))
         (s1 (subst-extend a cl-cc/type:type-int nil))
         (result (subst-compose s1 s2)))
    (multiple-value-bind (val found) (subst-lookup a result)
      (expect found :to-be-truthy)
      (expect val :to-be cl-cc/type:type-string))))

;;; ─── Occurs Check ───────────────────────────────────────────────────────
(it-sequential
  "type-occurs-check"
  (let ((s (make-substitution)))
    (let ((v (cl-cc/type:fresh-type-var 'a)))
      (expect (type-occurs-p v v s) :to-be-truthy)
      (expect
        (type-occurs-p
          v
          (cl-cc/type:make-type-arrow-raw :params (list v) :return cl-cc/type:type-int)
          s)
        :to-be-truthy)
      (expect (type-occurs-p v cl-cc/type:type-int s) :to-be-falsy)))
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (b (cl-cc/type:fresh-type-var 'b))
         (fn-ty
        (cl-cc/type:make-type-arrow-raw :params (list a) :return cl-cc/type:type-int))
         (s (subst-extend b fn-ty nil)))
    (expect (type-occurs-p a b s) :to-be-truthy)))

(it-sequential
  "type-occurs-p-treats-a-binders-own-variable-as-shadowed"
  ;; TYPE-OCCURS-P's (IF (AND BOUND-VAR (TYPE-VAR-EQUAL-P VAR BOUND-VAR)) NIL
  ;; ...) short-circuit had never fired: no pre-existing case built a
  ;; binder (TYPE-FORALL/-EXISTS/-LAMBDA/-MU) at all. VAR occurring only as
  ;; a FORALL's own bound variable must not count as a free occurrence,
  ;; even though VAR does appear (shadowed) inside BODY too.
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (forall-ty (cl-cc/type:make-type-forall :var v :knd nil :body v)))
    (expect (type-occurs-p v forall-ty (make-substitution)) :to-be-falsy)))

;;; ─── Generalize / Instantiate ───────────────────────────────────────────
(progn
  (it-sequential "generalize-quantification-cases outside-env"
    (let* ((a (cl-cc/type:fresh-type-var 'a))
           (env nil)
           (ret a)
           (fn-ty (cl-cc/type:make-type-arrow-raw :params (list a) :return ret))
           (scheme (generalize env fn-ty)))
      (expect
        (length (cl-cc/type:type-scheme-quantified-vars scheme))
        :to-equal
        1)))
  (it-sequential "generalize-quantification-cases in-env"
    (let* ((a (cl-cc/type:fresh-type-var 'a))
           (env
          (cl-cc/type:type-env-extend
            'x
            (cl-cc/type:type-to-scheme a)
            (cl-cc/type:type-env-empty)))
           (ret cl-cc/type:type-int)
           (fn-ty (cl-cc/type:make-type-arrow-raw :params (list a) :return ret))
           (scheme (generalize env fn-ty)))
      (expect
        (length (cl-cc/type:type-scheme-quantified-vars scheme))
        :to-equal
        0))))

(it-sequential
  "instantiate-produces-fresh"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (fn-ty (cl-cc/type:make-type-arrow-raw :params (list a) :return a))
         (scheme (generalize nil fn-ty))
         (inst1 (instantiate scheme)))
    (expect (cl-cc/type:type-arrow-p inst1) :to-be-truthy)
    (let ((p1 (car (cl-cc/type:type-arrow-params inst1)))
          (r1 (cl-cc/type:type-arrow-return inst1)))
      (expect (cl-cc/type:type-var-p p1) :to-be-truthy)
      (expect (cl-cc/type:type-var-equal-p p1 r1) :to-be-truthy)
      (expect (cl-cc/type:type-var-equal-p p1 a) :to-be-falsy))))

(it-sequential
  "instantiate-skips-fresh-substitution-for-an-already-linked-quantified-var"
  ;; A quantified var whose TYPE-VAR-LINK is already set (as if some
  ;; unrelated earlier unification had reused the same var object)
  ;; resolves through its own link before INSTANTIATE's freshly built
  ;; substitution is ever consulted -- ZONK checks TYPE-VAR-LINK ahead of
  ;; SUBST-LOOKUP. This exercises the bound-preservation loop's
  ;; (TYPE-VAR-P FRESH) guard's false branch: FRESH resolves to the
  ;; linked-to concrete type, not the freshly minted variable.
  (let* ((v (cl-cc/type:fresh-type-var 'a))
         (scheme (cl-cc/type:make-type-scheme (list v) v)))
    (setf (cl-cc/type:type-var-link v) cl-cc/type:type-int)
    (expect (cl-cc/type:type-equal-p (instantiate scheme) cl-cc/type:type-int)
            :to-be-truthy)))

;;; ─── Normalize ──────────────────────────────────────────────────────────
(it-sequential
  "normalize-type-variables-renames-distinct-vars"
  (let* ((fn
        (cl-cc/type:make-type-arrow-raw
          :params
          (list (cl-cc/type:fresh-type-var 'xyz))
          :return
          (cl-cc/type:fresh-type-var 'qqq)))
         (normed (cl-cc/type:normalize-type-variables fn)))
    (let ((p (car (cl-cc/type:type-arrow-params normed)))
          (r (cl-cc/type:type-arrow-return normed)))
      (expect (cl-cc/type:type-var-p p) :to-be-truthy)
      (expect (cl-cc/type:type-var-p r) :to-be-truthy)
      (expect (cl-cc/type:type-var-equal-p p r) :to-be-falsy))))

(it-sequential
  "normalize-type-variables-preserves-shared-variable"
  (let* ((v (cl-cc/type:fresh-type-var 'x))
         (fn (cl-cc/type:make-type-arrow-raw :params (list v) :return v))
         (normed (cl-cc/type:normalize-type-variables fn)))
    (expect
      (cl-cc/type:type-var-equal-p
        (car (cl-cc/type:type-arrow-params normed))
        (cl-cc/type:type-arrow-return normed))
      :to-be-truthy)))

(it-sequential
  "normalize-type-variables-recurses-into-arrow-effects-when-present"
  ;; %NV-NORM's TYPE-ARROW clause only recurses into :EFFECTS when it is
  ;; non-nil; the pre-existing arrow tests never set :EFFECTS at all.
  (let* ((effects (cl-cc/type:make-type-effect-row
                    :effects (list (cl-cc/type:make-type-effect-op :name 'io :args nil))
                    :row-var nil))
         (fn (cl-cc/type:make-type-arrow-raw
              :params (list (cl-cc/type:fresh-type-var 'p))
              :return (cl-cc/type:fresh-type-var 'r)
              :effects effects))
         (normed (cl-cc/type:normalize-type-variables fn)))
    (expect (cl-cc/type:type-effect-row-p (cl-cc/type:type-arrow-effects normed)) :to-be-truthy)))

(it-sequential
  "normalize-type-variables-recurses-into-type-product-elements"
  ;; %NV-NORM has a dedicated TYPE-PRODUCT clause never reached by any
  ;; pre-existing NORMALIZE-TYPE-VARIABLES test.
  (let* ((v1 (cl-cc/type:fresh-type-var 'a))
         (v2 (cl-cc/type:fresh-type-var 'b))
         (prod (cl-cc/type:make-type-product :elems (list v1 v2)))
         (normed (cl-cc/type:normalize-type-variables prod)))
    (expect (cl-cc/type:type-product-p normed) :to-be-truthy)
    (expect (every #'cl-cc/type:type-var-p (cl-cc/type:type-product-elems normed)) :to-be-truthy)
    (expect (cl-cc/type:type-var-equal-p
             (first (cl-cc/type:type-product-elems normed))
             (second (cl-cc/type:type-product-elems normed)))
            :to-be-falsy)))

(it-sequential
  "zonk-env-substitutes-all-bindings"
  (let* ((a (cl-cc/type:fresh-type-var 'a))
         (env
        (cl-cc/type:make-type-env
          :bindings
          (list (cons 'x a) (cons 'y cl-cc/type:type-string))))
         (s (subst-extend a cl-cc/type:type-int nil))
         (result (cl-cc/type:zonk-env env s))
         (bindings (cl-cc/type:type-env-bindings result)))
    (expect (cl-cc/type:type-primitive-name (cdr (first bindings))) :to-be 'fixnum)
    (expect (cl-cc/type:type-primitive-name (cdr (second bindings))) :to-be 'string)))

;;; ─── %nv-canonical / %nv-norm (extracted helpers) ────────────────────────────
(it-sequential
  "nv-canonical-creates-fresh-var"
  (let ((mapping (make-hash-table :test #'eql))
        (counter-cell (list 0))
        (v (cl-cc/type:fresh-type-var 'x)))
    (let ((nv1 (cl-cc/type::%nv-canonical v mapping counter-cell)))
      (expect (cl-cc/type:type-var-p nv1) :to-be-truthy)
      (expect (car counter-cell) :to-equal 1)
      (let ((nv2 (cl-cc/type::%nv-canonical v mapping counter-cell)))
        (expect nv2 :to-be nv1)
        (expect (car counter-cell) :to-equal 1)))))

(it-sequential
  "nv-norm-passes-through-non-var"
  (let ((mapping (make-hash-table :test #'eql))
        (counter-cell (list 0)))
    (expect
      (cl-cc/type::%nv-norm cl-cc/type:type-int mapping counter-cell)
      :to-be
      cl-cc/type:type-int)
    (expect (car counter-cell) :to-equal 0)))

(it-sequential
  "nv-norm-renames-type-var"
  (let ((mapping (make-hash-table :test #'eql))
        (counter-cell (list 0))
        (v (cl-cc/type:fresh-type-var 'z)))
    (let ((result (cl-cc/type::%nv-norm v mapping counter-cell)))
      (expect (cl-cc/type:type-var-p result) :to-be-truthy)
      (expect (eq result v) :to-be-falsy))))

;;; ─── apply-unification ───────────────────────────────────────────────────────
(it-sequential
  "apply-unification-nil-subst-returns-nil"
  (let ((ty (cl-cc/type:parse-type-specifier 'fixnum)))
    (expect (cl-cc/type:apply-unification ty nil) :to-be-falsy)))

(it-sequential
  "apply-unification-empty-subst-returns-ty"
  (let ((ty (cl-cc/type:parse-type-specifier 'fixnum))
        (subst (make-hash-table :test #'eql)))
    (expect (cl-cc/type:apply-unification ty subst) :to-be ty)))

(it-sequential
  "apply-unification-resolves-mapped-var"
  (let* ((v (cl-cc/type:fresh-type-var 'x))
         (target (cl-cc/type:parse-type-specifier 'fixnum))
         (subst (cl-cc/type:subst-extend v target nil)))
    (let ((result (cl-cc/type:apply-unification v subst)))
      (expect result :to-be-truthy)
      (expect (cl-cc/type:type-var-p result) :to-be-falsy))))
