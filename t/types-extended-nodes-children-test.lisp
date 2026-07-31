;;;; t/types-extended-nodes-children-test.lisp — Type Children & Bound-Var Tests
;;;;
;;;; Tests for type-children and type-bound-var in src/types-extended-nodes.lisp.
;;;; Verifies the structural data layer that enables data/logic separation
;;;; in type-free-vars, type-occurs-p, and zonk.

(in-package :cl-cc-type/test)

;;; ─── type-children: leaf types return nil ──────────────────────────────────

(progn
  (it-sequential "type-children-atomic-leaf-types int"
    (expect (cl-cc/type:type-children type-int) :to-be-null))
  (it-sequential "type-children-atomic-leaf-types string"
    (expect (cl-cc/type:type-children type-string) :to-be-null))
  (it-sequential "type-children-atomic-leaf-types bool"
    (expect (cl-cc/type:type-children type-bool) :to-be-null))
  (it-sequential "type-children-atomic-leaf-types var"
    (expect (cl-cc/type:type-children (fresh-type-var :name "a")) :to-be-null))
  (it-sequential "type-children-atomic-leaf-types rigid"
    (expect (cl-cc/type:type-children (fresh-rigid-var "r")) :to-be-null))
  (it-sequential "type-children-atomic-leaf-types error"
    (expect (cl-cc/type:type-children (make-type-error :message "test")) :to-be-null))
  (it-sequential "type-children-atomic-leaf-types nil"
    (expect (cl-cc/type:type-children nil) :to-be-null)))

;;; ─── type-children: compound types ─────────────────────────────────────────

(it-sequential "type-children-pure-arrow-yields-params-and-return"
  (let* ((arr (make-type-arrow (list type-int type-string) type-bool))
         (ch  (cl-cc/type:type-children arr)))
    (expect (length ch) :to-equal 3)
    (expect type-int :to-be-type-equal-to (first ch))
    (expect type-string :to-be-type-equal-to (second ch))
    (expect type-bool :to-be-type-equal-to (third ch))))

(it-sequential "type-children-arrow-with-effects-has-effect-row-as-child"
  (let* ((arr (make-type-arrow (list type-int) type-bool :effects +io-effect-row+))
         (ch  (cl-cc/type:type-children arr)))
    (expect (length ch) :to-equal 3)
    (expect (type-effect-row-p (third ch)) :to-be-truthy)))

(it-sequential "type-children-product"
  (let* ((p  (make-type-product :elems (list type-int type-string type-bool)))
         (ch (cl-cc/type:type-children p)))
    (expect (length ch) :to-equal 3)
    (expect type-int :to-be-type-equal-to (first ch))))

(progn
  (it-sequential "type-children-binary-collection-types union"
    (expect (length (cl-cc/type:type-children (make-type-union (list type-int type-string))))
            :to-equal 2))
  (it-sequential "type-children-binary-collection-types intersection"
    (expect (length (cl-cc/type:type-children (make-type-intersection (list type-int type-string))))
            :to-equal 2)))

(progn
  (it-sequential "type-children-record-variants closed"
    (let* ((rv (when nil (fresh-type-var :name "rho")))
           (fields (if nil
                       (list (cons :x type-int))
                       (list (cons :x type-int) (cons :y type-string))))
           (r  (make-type-record :fields fields :row-var rv))
           (ch (cl-cc/type:type-children r)))
      (expect (length ch) :to-equal 2)
      (expect type-int :to-be-type-equal-to (first ch))
      (assert-when-present nil
        (expect (type-var-p (second ch)) :to-be-truthy))
      (assert-when-present (not nil)
        (expect type-string :to-be-type-equal-to (second ch)))))
  (it-sequential "type-children-record-variants open"
    (let* ((rv (when t (fresh-type-var :name "rho")))
           (fields (if t
                       (list (cons :x type-int))
                       (list (cons :x type-int) (cons :y type-string))))
           (r  (make-type-record :fields fields :row-var rv))
           (ch (cl-cc/type:type-children r)))
      (expect (length ch) :to-equal 2)
      (expect type-int :to-be-type-equal-to (first ch))
      (assert-when-present t
        (expect (type-var-p (second ch)) :to-be-truthy))
      (assert-when-present (not t)
        (expect nil :to-be-type-equal-to (second ch))))))

(progn
  (it-sequential "type-children-variant-variants closed"
    (let* ((rv (when nil (fresh-type-var :name "rho")))
           (cases (if nil
                      (list (cons :ok type-int))
                      (list (cons :some type-int) (cons :none type-null))))
           (v  (make-type-variant :cases cases :row-var rv))
           (ch (cl-cc/type:type-children v)))
      (expect (length ch) :to-equal 2)
      (assert-when-present nil
        (expect (type-var-p (second ch)) :to-be-truthy))))
  (it-sequential "type-children-variant-variants open"
    (let* ((rv (when t (fresh-type-var :name "rho")))
           (cases (if t
                      (list (cons :ok type-int))
                      (list (cons :some type-int) (cons :none type-null))))
           (v  (make-type-variant :cases cases :row-var rv))
           (ch (cl-cc/type:type-children v)))
      (expect (length ch) :to-equal 2)
      (assert-when-present t
        (expect (type-var-p (second ch)) :to-be-truthy)))))

(progn
  (it-sequential "type-children-quantifier-return-body forall"
    (let ((ch (cl-cc/type:type-children
               (make-type-forall :var (fresh-type-var :name "a") :body type-int))))
      (expect (length ch) :to-equal 1)
      (expect type-int :to-be-type-equal-to (first ch))))
  (it-sequential "type-children-quantifier-return-body exists"
    (let ((ch (cl-cc/type:type-children
               (make-type-exists :var (fresh-type-var :name "a") :body type-string))))
      (expect (length ch) :to-equal 1)
      (expect type-string :to-be-type-equal-to (first ch)))))

(it-sequential "type-children-app"
  (let* ((app (make-type-app :fun type-int :arg type-string))
         (ch  (cl-cc/type:type-children app)))
    (expect (length ch) :to-equal 2)
    (expect type-int :to-be-type-equal-to (first ch))
    (expect type-string :to-be-type-equal-to (second ch))))

(it-sequential "type-children-lambda-and-mu"
  (let ((a (fresh-type-var :name "a")))
    (let ((ch (cl-cc/type:type-children (cl-cc/type:make-type-lambda :var a :body type-int))))
      (expect (length ch) :to-equal 1)
      (expect type-int :to-be-type-equal-to (first ch)))
    (let ((ch (cl-cc/type:type-children (make-type-mu :var a :body type-int))))
      (expect (length ch) :to-equal 1))))

(progn
  (it-sequential "type-children-wrapper-types refinement"
    (let ((ch (cl-cc/type:type-children
               (cl-cc/type:make-type-refinement :base type-int :predicate #'numberp))))
      (expect (length ch) :to-equal 1)
      (expect type-int :to-be-type-equal-to (first ch))))
  (it-sequential "type-children-wrapper-types linear"
    (let ((ch (cl-cc/type:type-children (make-type-linear :base type-int :grade :one))))
      (expect (length ch) :to-equal 1)
      (expect type-int :to-be-type-equal-to (first ch))))
  (it-sequential "type-children-wrapper-types capability"
    (let ((ch (cl-cc/type:type-children
               (cl-cc/type:make-type-capability :base type-int :cap 'read))))
      (expect (length ch) :to-equal 1)
      (expect type-int :to-be-type-equal-to (first ch)))))

(progn
  (it-sequential "type-children-effect-row-variants closed"
    (let* ((rv  (when nil (fresh-type-var :name "rho")))
           (eff (make-type-effect-op :name 'io :args nil))
           (row (make-type-effect-row :effects (list eff) :row-var rv))
           (ch  (cl-cc/type:type-children row)))
      (expect (length ch) :to-equal 1)
      (expect (cl-cc/type:type-effect-op-p (first ch)) :to-be-truthy)
      (assert-when-present nil
        (expect (type-var-p (second ch)) :to-be-truthy))))
  (it-sequential "type-children-effect-row-variants open"
    (let* ((rv  (when t (fresh-type-var :name "rho")))
           (eff (make-type-effect-op :name 'io :args nil))
           (row (make-type-effect-row :effects (list eff) :row-var rv))
           (ch  (cl-cc/type:type-children row)))
      (expect (length ch) :to-equal 2)
      (expect (cl-cc/type:type-effect-op-p (first ch)) :to-be-truthy)
      (assert-when-present t
        (expect (type-var-p (second ch)) :to-be-truthy)))))

(progn
  (it-sequential "type-children-effect-op-cases no-args"
    (let* ((eff (make-type-effect-op :name 'io :args nil))
           (ch  (cl-cc/type:type-children eff)))
      (assert-when-present nil
        (progn (expect (length ch) :to-equal nil)
               (expect type-int :to-be-type-equal-to (first ch))))
      (assert-when-present (not nil)
        (expect ch :to-be-null))))
  (it-sequential "type-children-effect-op-cases with-args"
    (let* ((eff (make-type-effect-op :name 'state :args (list type-int)))
           (ch  (cl-cc/type:type-children eff)))
      (assert-when-present 1
        (progn (expect (length ch) :to-equal 1)
               (expect type-int :to-be-type-equal-to (first ch))))
      (assert-when-present (not 1)
        (expect ch :to-be-null)))))

(it-sequential "type-children-advanced-collects-from-args-properties-evidence"
  (let* ((adv (cl-cc/type::%make-type-advanced
                :feature-id "FR-9001"
                :args (list type-int)
                :properties (list (cons :k type-string))
                :evidence type-bool))
         (ch  (cl-cc/type:type-children adv)))
    (expect (length ch) :to-equal 3)
    (expect type-int :to-be-type-equal-to (first ch))
    (expect type-string :to-be-type-equal-to (second ch))
    (expect type-bool :to-be-type-equal-to (third ch))))

(it-sequential "type-children-handler-has-three-children"
  (let* ((eff (make-type-effect-op :name 'io :args nil))
         (h   (cl-cc/type:make-type-handler :effect eff :input type-int :output type-string))
         (ch  (cl-cc/type:type-children h)))
    (expect (length ch) :to-equal 3)))

(it-sequential "type-children-constraint-has-one-child"
  (let* ((c  (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int))
         (ch (cl-cc/type:type-children c)))
    (expect (length ch) :to-equal 1)
    (expect type-int :to-be-type-equal-to (first ch))))

(it-sequential "type-children-qualified-has-two-children"
  (let* ((c  (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int))
         (q  (make-type-qualified :constraints (list c) :body type-string))
         (ch (cl-cc/type:type-children q)))
    (expect (length ch) :to-equal 2)
    (expect type-string :to-be-type-equal-to (second ch))))

;;; ─── type-bound-var ────────────────────────────────────────────────────────

(progn
  (it-sequential "type-bound-var-binding-types forall"
    (expect (type-var-p (cl-cc/type:type-bound-var
                          (let ((a (fresh-type-var :name "a")))
                            (make-type-forall :var a :body type-int))))
            :to-be-truthy))
  (it-sequential "type-bound-var-binding-types exists"
    (expect (type-var-p (cl-cc/type:type-bound-var
                          (let ((a (fresh-type-var :name "a")))
                            (make-type-exists :var a :body type-int))))
            :to-be-truthy))
  (it-sequential "type-bound-var-binding-types lambda"
    (expect (type-var-p (cl-cc/type:type-bound-var
                          (let ((a (fresh-type-var :name "a")))
                            (cl-cc/type:make-type-lambda :var a :body type-int))))
            :to-be-truthy))
  (it-sequential "type-bound-var-binding-types mu"
    (expect (type-var-p (cl-cc/type:type-bound-var
                          (let ((a (fresh-type-var :name "a")))
                            (make-type-mu :var a :body type-int))))
            :to-be-truthy)))

(progn
  (it-sequential "type-bound-var-non-binding-cases primitive"
    (expect (cl-cc/type:type-bound-var type-int) :to-be-null))
  (it-sequential "type-bound-var-non-binding-cases var"
    (expect (cl-cc/type:type-bound-var (fresh-type-var :name "a")) :to-be-null))
  (it-sequential "type-bound-var-non-binding-cases arrow"
    (expect (cl-cc/type:type-bound-var (make-type-arrow (list type-int) type-bool)) :to-be-null))
  (it-sequential "type-bound-var-non-binding-cases product"
    (expect (cl-cc/type:type-bound-var (make-type-product :elems (list type-int))) :to-be-null))
  (it-sequential "type-bound-var-non-binding-cases union"
    (expect (cl-cc/type:type-bound-var (make-type-union (list type-int type-string))) :to-be-null)))

;;; ─── Integration: type-free-vars still works correctly ─────────────────────

(it-sequential "type-free-vars-via-children-simple"
  (let* ((a   (fresh-type-var :name "a"))
         (arr (make-type-arrow (list a) type-int)))
    (expect (length (type-free-vars arr)) :to-equal 1)
    (expect (type-var-equal-p a (first (type-free-vars arr))) :to-be-truthy)))

(it-sequential "type-free-vars-forall-bound-var-excluded"
  (let* ((a (fresh-type-var :name "a"))
         (f (make-type-forall :var a :body a)))
    (expect (type-free-vars f) :to-be-null)))

(it-sequential "type-free-vars-forall-only-unbound-vars-are-free"
  (let* ((a (fresh-type-var :name "a"))
         (b (fresh-type-var :name "b"))
         (f (make-type-forall :var a :body (make-type-arrow (list a) b))))
    (expect (length (type-free-vars f)) :to-equal 1)
    (expect (type-var-equal-p b (first (type-free-vars f))) :to-be-truthy)))

(it-sequential "type-free-vars-via-children-record"
  (let* ((a  (fresh-type-var :name "a"))
         (rv (fresh-type-var :name "rho"))
         (r  (make-type-record :fields (list (cons :x a)) :row-var rv)))
    (expect (length (type-free-vars r)) :to-equal 2)))

(it-sequential "type-free-vars-via-children-mu"
  (let* ((a (fresh-type-var :name "a"))
         (b (fresh-type-var :name "b"))
         (m (make-type-mu :var a :body (make-type-product :elems (list a b)))))
    (expect (length (type-free-vars m)) :to-equal 1)
    (expect (type-var-equal-p b (first (type-free-vars m))) :to-be-truthy)))

(it-sequential "type-free-vars-via-children-nested"
  (let* ((a (fresh-type-var :name "a"))
         (b (fresh-type-var :name "b"))
         (ty (make-type-union
              (list (make-type-arrow (list a) type-int)
                    (make-type-product :elems (list b type-string))))))
    (expect (length (type-free-vars ty)) :to-equal 2)))

;;; ─── Integration: type-occurs-p still works correctly ──────────────────────

(it-sequential "type-occurs-p-direct-arrow-and-absent"
  (let ((a (fresh-type-var :name "a"))
        (b (fresh-type-var :name "b"))
        (s (make-substitution)))
    (expect (type-occurs-p a a s) :to-be-truthy)
    (expect (type-occurs-p a (make-type-arrow (list a) type-int) s) :to-be-truthy)
    (expect (type-occurs-p b (make-type-arrow (list a) type-int) s) :to-be-falsy)))

(it-sequential "type-occurs-p-follows-subst-chain"
  (let* ((a (fresh-type-var :name "a"))
         (b (fresh-type-var :name "b"))
         (subst (make-substitution)))
    (subst-extend! b a subst)
    (expect (type-occurs-p a b subst) :to-be-truthy)))

(it-sequential "type-occurs-p-finds-var-in-nested-union"
  (let* ((a (fresh-type-var :name "a"))
         (ty (make-type-union
              (list type-int
                    (make-type-product :elems
                      (list type-string
                            (make-type-arrow (list a) type-bool)))))))
    (expect (type-occurs-p a ty (make-substitution)) :to-be-truthy)))
