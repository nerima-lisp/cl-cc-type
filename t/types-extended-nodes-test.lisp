;;;; t/types-extended-nodes-test.lisp — Type Representation Tests
;;;;
;;;; Tests for src/types-extended-nodes.lisp (advanced type nodes, type-equal-p
;;;; branches, type-free-vars) and src/types-env.lisp (type-env operations and
;;;; type-constructor encoding).
(in-package :cl-cc-type/test)

;;; ─── type-equal-p: product ─────────────────────────────────────────────────
(it-sequential
  "type-equal-product-same-elements-is-true"
  (expect (make-type-product :elems (list type-int type-string)) :to-be-type-equal-to (make-type-product :elems (list type-int type-string))))

(it-sequential
  "type-equal-product-different-length-is-false"
  (expect-not (make-type-product :elems (list type-int)) :to-be-type-equal-to (make-type-product :elems (list type-int type-string))))

(it-sequential
  "type-equal-product-different-element-is-false"
  (expect-not (make-type-product :elems (list type-int type-int)) :to-be-type-equal-to (make-type-product :elems (list type-int type-string))))

;;; ─── type-equal-p: type-var ─────────────────────────────────────────────────
(it-sequential
  "type-equal-var-same-id-distinct-objects-is-true"
  (let ((v1 (cl-cc/type::%make-type-var :id 90001 :name "a"))
        (v2 (cl-cc/type::%make-type-var :id 90001 :name "b")))
    (expect v1 :to-be-type-equal-to v2)))

(it-sequential
  "type-equal-var-different-fresh-vars-is-false"
  (expect-not (fresh-type-var :name "a") :to-be-type-equal-to (fresh-type-var :name "b")))

(it-sequential
  "type-equal-forall-same-body-is-true"
  (let ((v (fresh-type-var :name "a")))
    (expect (make-type-forall :var v :body (make-type-arrow (list v) type-int)) :to-be-type-equal-to (make-type-forall :var v :body (make-type-arrow (list v) type-int)))))

(it-sequential
  "type-equal-forall-different-body-is-false"
  (let ((v (fresh-type-var :name "a")))
    (expect-not (make-type-forall :var v :body type-int) :to-be-type-equal-to (make-type-forall :var v :body type-string))))

(it-sequential
  "type-equal-exists-and-mu-same-is-true"
  (let ((v (fresh-type-var :name "a")))
    (expect (make-type-exists :var v :body type-int) :to-be-type-equal-to (make-type-exists :var v :body type-int))
    (expect (make-type-mu :var v :body type-int) :to-be-type-equal-to (make-type-mu :var v :body type-int))))

;;; ─── type-equal-p: union / intersection ────────────────────────────────────
(progn
  (it-sequential "type-equal-union-intersection-same union"
    (expect (make-type-union (list type-int type-string)) :to-be-type-equal-to (make-type-union (list type-int type-string))))
  (it-sequential "type-equal-union-intersection-same intersection"
    (expect (make-type-intersection (list type-int type-any)) :to-be-type-equal-to (make-type-intersection (list type-int type-any)))))

;;; ─── type-equal-p: type-app / type-linear ──────────────────────────────────
(it-sequential
  "type-equal-type-app-same-is-true"
  (expect (make-type-app :fun type-int :arg type-string) :to-be-type-equal-to (make-type-app :fun type-int :arg type-string)))

(it-sequential
  "type-equal-type-app-different-arg-is-false"
  (expect-not (make-type-app :fun type-int :arg type-string) :to-be-type-equal-to (make-type-app :fun type-int :arg type-int)))

(it-sequential
  "type-equal-linear-same-grade-is-true"
  (let ((l1 (make-type-linear :base type-int :grade :one))
        (l2 (make-type-linear :base type-int :grade :one)))
    (expect l1 :to-be-type-equal-to l2)))

(it-sequential
  "type-equal-linear-different-grade-is-false"
  (let ((l1 (make-type-linear :base type-int :grade :one))
        (l3 (make-type-linear :base type-int :grade :omega)))
    (expect-not l1 :to-be-type-equal-to l3)))

;;; ─── type-equal-p: type-refinement ──────────────────────────────────────────
(it-sequential
  "type-equal-refinement-same-base-and-predicate-is-true"
  (expect (make-type-refinement :base type-int :predicate #'numberp) :to-be-type-equal-to (make-type-refinement :base type-int :predicate #'numberp)))

(it-sequential
  "type-equal-refinement-different-base-is-false"
  (expect-not (make-type-refinement :base type-int :predicate #'numberp) :to-be-type-equal-to (make-type-refinement :base type-string :predicate #'numberp)))

(it-sequential
  "type-equal-refinement-different-predicate-is-false"
  (expect-not (make-type-refinement :base type-int :predicate #'numberp) :to-be-type-equal-to (make-type-refinement :base type-int :predicate #'stringp)))

;;; ─── type-equal-p: effect-row / effect-op ──────────────────────────────────
(it-sequential
  "type-equal-effect-rows-and-ops"
  (expect +pure-effect-row+ :to-be-type-equal-to +pure-effect-row+)
  (expect-not +pure-effect-row+ :to-be-type-equal-to +io-effect-row+)
  (expect (make-type-effect-op :name 'io :args nil) :to-be-type-equal-to (make-type-effect-op :name 'io :args nil))
  (expect-not (make-type-effect-op :name 'io :args nil) :to-be-type-equal-to (make-type-effect-op :name 'state :args nil)))

(it-sequential
  "type-equal-effect-row-both-row-vars-present-and-equal-is-true"
  (let* ((rv (fresh-type-var :name "rho"))
         (r1 (make-type-effect-row :effects nil :row-var rv))
         (r2 (make-type-effect-row :effects nil :row-var rv)))
    (expect r1 :to-be-type-equal-to r2)))

(it-sequential
  "type-equal-effect-row-both-row-vars-present-and-different-is-false"
  (let* ((r1 (make-type-effect-row :effects nil :row-var (fresh-type-var :name "a")))
         (r2 (make-type-effect-row :effects nil :row-var (fresh-type-var :name "b"))))
    (expect-not r1 :to-be-type-equal-to r2)))

;;; ─── type-equal-p: constraint / qualified ──────────────────────────────────
(it-sequential
  "type-equal-constraint-and-qualified"
  (with-soft-assertions
    (expect (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int) :to-be-type-equal-to (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int))
    (expect-not (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int) :to-be-type-equal-to (cl-cc/type:make-type-constraint :class-name 'ord :type-arg type-int))
    (let* ((tc (cl-cc/type:make-type-constraint :class-name 'eq :type-arg type-int))
           (q1 (make-type-qualified :constraints (list tc) :body type-int))
           (q2 (make-type-qualified :constraints (list tc) :body type-int)))
      (expect q1 :to-be-type-equal-to q2))))

;;; ─── type-equal-p: error sentinel and rigid vars ────────────────────────────
(it-sequential
  "type-equal-error-node-never-equal"
  (let ((e (make-type-error :message "test")))
    (expect-not e :to-be-type-equal-to e)
    (expect-not e :to-be-type-equal-to type-int)))

(it-sequential
  "type-equal-rigid-var-equal-only-to-itself"
  (let ((r (fresh-rigid-var "a"))
        (r1 (fresh-rigid-var "a"))
        (r2 (fresh-rigid-var "b")))
    (expect r :to-be-type-equal-to r)
    (expect-not r1 :to-be-type-equal-to r2)))

;;; ─── type-equal-p: advanced ─────────────────────────────────────────────────
(it-sequential
  "type-equal-advanced-same-feature-args-properties-evidence-is-true"
  (let ((a (cl-cc/type::%make-type-advanced
             :feature-id "FR-9001" :name 'widget
             :args (list type-int)
             :properties (list (cons :k type-string))
             :evidence type-bool))
        (b (cl-cc/type::%make-type-advanced
             :feature-id "FR-9001" :name 'widget
             :args (list type-int)
             :properties (list (cons :k type-string))
             :evidence type-bool)))
    (expect a :to-be-type-equal-to b)))

(it-sequential
  "type-equal-advanced-different-feature-id-is-false"
  (let ((a (cl-cc/type::%make-type-advanced :feature-id "FR-9001" :args (list type-int)))
        (b (cl-cc/type::%make-type-advanced :feature-id "FR-9002" :args (list type-int))))
    (expect-not a :to-be-type-equal-to b)))

;;; ─── type-free-vars ────────────────────────────────────────────────────────
(it-sequential
  "free-vars-primitive-has-no-free-vars"
  (expect (type-free-vars type-int) :to-be-null))

(it-sequential
  "free-vars-type-var-is-its-own-free-var"
  (let* ((v (fresh-type-var :name "a"))
         (fvs (type-free-vars v)))
    (expect (length fvs) :to-equal 1)
    (expect (type-var-equal-p v (first fvs)) :to-be-truthy)))

(it-sequential
  "free-vars-binding-forms-remove-bound-var"
  (let ((v (fresh-type-var :name "a")))
    (expect (type-free-vars (make-type-forall :var v :body v)) :to-be-null)
    (expect (type-free-vars (make-type-exists :var v :body v)) :to-be-null)
    (expect (type-free-vars (make-type-mu :var v :body v)) :to-be-null)))

(progn
  (it-sequential "free-vars-count-cases arrow"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((v1 (fresh-type-var :name "a"))
                    (v2 (fresh-type-var :name "b")))
                (make-type-arrow (list v1) v2))))))
      :to-equal 2))
  (it-sequential "free-vars-count-cases product"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((v1 (fresh-type-var :name "a"))
                    (v2 (fresh-type-var :name "b")))
                (make-type-product :elems (list v1 type-int v2)))))))
      :to-equal 2))
  (it-sequential "free-vars-count-cases record"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((v (fresh-type-var :name "a"))
                    (rv (fresh-type-var :name "rho")))
                (make-type-record :fields (list (cons 'x v)) :row-var rv))))))
      :to-equal 2))
  (it-sequential "free-vars-count-cases variant"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((v (fresh-type-var :name "a")))
                (make-type-variant :cases (list (cons 'x v)) :row-var nil))))))
      :to-equal 1))
  (it-sequential "free-vars-count-cases linear"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((v (fresh-type-var :name "a")))
                (make-type-linear :base v :grade :one))))))
      :to-equal 1))
  (it-sequential "free-vars-count-cases type-app"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((v1 (fresh-type-var :name "f"))
                    (v2 (fresh-type-var :name "a")))
                (make-type-app :fun v1 :arg v2))))))
      :to-equal 2))
  (it-sequential "free-vars-count-cases effect-row"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let ((rv (fresh-type-var :name "ε")))
                (make-type-effect-row :effects nil :row-var rv))))))
      :to-equal 1))
  (it-sequential "free-vars-count-cases qualified"
    (expect
      (length
        (type-free-vars
          (funcall
            (lambda ()
              (let* ((v (fresh-type-var :name "a"))
                     (tc (cl-cc/type:make-type-constraint :class-name 'eq :type-arg v)))
                (make-type-qualified :constraints (list tc) :body v))))))
      :to-equal 1)))

;;; ─── Type environment operations ───────────────────────────────────────────
(it-sequential
  "type-env-lookup-in-empty-returns-nil"
  (let ((env (type-env-empty)))
    (multiple-value-bind (scheme found-p) (cl-cc/type:type-env-lookup 'x env)
      (expect scheme :to-be-null)
      (expect found-p :to-be-falsy))))

(it-sequential
  "type-env-extend-and-lookup-finds-scheme"
  (let* ((env (type-env-empty))
         (env2 (cl-cc/type:type-env-extend 'x (type-to-scheme type-int) env)))
    (multiple-value-bind (result found-p) (cl-cc/type:type-env-lookup 'x env2)
      (expect found-p :to-be-truthy)
      (expect type-int :to-be-type-equal-to (cl-cc/type:type-scheme-type result)))))

(it-sequential
  "type-env-extend*-adds-multiple-bindings"
  (let* ((env (type-env-empty))
         (bindings
        (list
          (cons 'x (type-to-scheme type-int))
          (cons 'y (type-to-scheme type-string))))
         (env2 (cl-cc/type:type-env-extend* bindings env)))
    (expect (nth-value 1 (cl-cc/type:type-env-lookup 'x env2)) :to-be-truthy)
    (expect (nth-value 1 (cl-cc/type:type-env-lookup 'y env2)) :to-be-truthy)))

(it-sequential
  "type-env-free-vars-collects-from-bindings"
  (let* ((v (fresh-type-var :name "a"))
         (env (cl-cc/type:type-env-extend 'x (type-to-scheme v) (type-env-empty)))
         (fvs (cl-cc/type:type-env-free-vars env)))
    (expect (length fvs) :to-equal 1)))

(it-sequential
  "type-env-free-vars-collects-from-a-raw-unwrapped-binding"
  ;; TYPE-ENV-FREE-VARS unwraps a TYPE-SCHEME binding via (IF (TYPE-SCHEME-P
  ;; s) (TYPE-SCHEME-TYPE s) s); the pre-existing test only ever binds a
  ;; TYPE-SCHEME (via TYPE-TO-SCHEME), never a bare type directly.
  (let* ((v (fresh-type-var :name "b"))
         (env (cl-cc/type:type-env-extend 'x v (cl-cc/type:type-env-empty)))
         (fvs (cl-cc/type:type-env-free-vars env)))
    (expect (length fvs) :to-equal 1)))

;;; ─── Constructor and printing cases ────────────────────────────────────────
(it-sequential
  "type-var-constructor-name-is-preserved"
  (let ((v (cl-cc/type:fresh-type-var 'x)))
    (expect (type-var-p v) :to-be-truthy)
    (expect (type-var-name v) :to-be 'x)))

(it-sequential
  "type-constructor-name-and-args"
  (let ((tc (cl-cc/type:make-type-constructor 'list (list type-int))))
    (expect (cl-cc/type:type-constructor-p tc) :to-be-truthy)
    (expect (cl-cc/type:type-constructor-name tc) :to-be 'list)
    (expect (length (cl-cc/type:type-constructor-args tc)) :to-equal 1)))

(it-sequential
  "type-constructor-name-and-args-recognize-the-option-union-shape"
  ;; %OPTION-TYPE-CONSTRUCTOR-P (a 2-member union including TYPE-NULL) is a
  ;; second, distinct TYPE-CONSTRUCTOR-P/-NAME/-ARGS shape besides TYPE-APP
  ;; chains; every pre-existing constructor test builds a TYPE-APP via
  ;; MAKE-TYPE-CONSTRUCTOR, never this union shape.
  (let ((tagged (cl-cc/type:make-type-union (list type-int type-null)
                                            :constructor-name 'maybe))
        (untagged (cl-cc/type:make-type-union (list type-string type-null))))
    (expect (cl-cc/type:type-constructor-p tagged) :to-be-truthy)
    (expect (cl-cc/type:type-constructor-name tagged) :to-be 'maybe)
    (expect (cl-cc/type:type-constructor-args tagged) :to-equal (list type-int))
    ;; With no explicit constructor name, TYPE-CONSTRUCTOR-NAME falls back
    ;; to interning "OPTION" in the current package.
    (expect (string= (symbol-name (cl-cc/type:type-constructor-name untagged)) "OPTION")
            :to-be-truthy)
    (expect (cl-cc/type:type-constructor-args untagged) :to-equal (list type-string))))

(it-sequential
  "type-constructor-name-and-args-return-nil-for-neither-shape"
  ;; Both prior tests only ever call TYPE-CONSTRUCTOR-NAME/-ARGS on values
  ;; that match one of the COND's two clauses (a TYPE-APP chain, or an
  ;; option-shaped union), so %OPTION-TYPE-CONSTRUCTOR-P's own test
  ;; expression -- as evaluated inside that COND, once TYPE-APP-P has
  ;; already failed -- had only ever been observed TRUE. A plain
  ;; TYPE-PRIMITIVE is neither shape, falling off the end of the COND.
  (expect (cl-cc/type:type-constructor-name type-int) :to-be-null)
  (expect (cl-cc/type:type-constructor-args type-int) :to-be-null))

(it-sequential
  "type-specifier-parse-unparse-roundtrip"
  (let* ((ty (cl-cc/type:parse-type-specifier '(Option string)))
         (spec (cl-cc/type:unparse-type ty)))
    (expect (first spec) :to-be 'Option)
    (expect ty :to-be-type-equal-to (cl-cc/type:parse-type-specifier spec))))

(it-sequential
  "type-arrow-default-mult-is-omega"
  (let ((f (make-type-arrow (list type-int) type-string)))
    (expect (type-arrow-p f) :to-be-truthy)
    (expect (type-arrow-mult f) :to-be :omega)))

(it-sequential
  "type-to-string-returns-string-for-all-forms"
  (expect (stringp (type-to-string type-int)) :to-be-truthy)
  (expect (stringp (type-to-string cl-cc/type:+type-unknown+)) :to-be-truthy)
  (expect (stringp (type-to-string nil)) :to-be-truthy)
  (expect
    (search "->" (type-to-string (make-type-arrow (list type-int) type-string)))
    :to-be-truthy))
