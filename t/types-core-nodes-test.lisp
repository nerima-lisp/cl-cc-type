;;;; t/types-core-nodes-test.lisp - 2026 Type System Node and Substitution API Tests
;;;;
;;;; Covers: 2026 type node extensions (rigid vars, product/variant, exists/mu, HKT app,
;;;; record, arrow-mult, linear), ANSI upgrade helpers, and hash-table substitution API.

(in-package :cl-cc-type/test)

;;; ─────────────────────────────────────────────────────────────────────────
;;; 2026 Type System: New Type Node Tests (direct new API)
;;; ─────────────────────────────────────────────────────────────────────────

(it-sequential "type-rigid-var-identity-and-uniqueness"
  (let ((r1 (fresh-rigid-var 'a))
        (r2 (fresh-rigid-var 'a)))
    (expect (type-rigid-p r1) :to-be-truthy)
    (expect (type-rigid-p r2) :to-be-truthy)
    (expect (type-rigid-equal-p r1 r2) :to-be-falsy)
    (expect (type-rigid-equal-p r1 r1) :to-be-truthy)
    (expect (type-rigid-name r1) :to-be 'a)))

(it-sequential "type-product-and-variant-creation"
  (let ((pair (make-type-product :elems (list type-int type-string))))
    (expect (type-product-p pair) :to-be-truthy)
    (expect (length (type-product-elems pair)) :to-equal 2)
    (expect type-int :to-be-type-equal-to (first  (type-product-elems pair)))
    (expect type-string :to-be-type-equal-to (second (type-product-elems pair))))
  (let ((v (make-type-variant :cases (list (cons 'some type-int) (cons 'none type-null))
                              :row-var nil)))
    (expect (type-variant-p v) :to-be-truthy)
    (expect (length (type-variant-cases v)) :to-equal 2)
    (expect (type-variant-row-var v) :to-be-null)))

(it-sequential "type-forall-body-keyword-aliases-type"
  (let* ((a  (fresh-type-var :name 'a))
         (fn (make-type-arrow (list a) a))
         (fa (make-type-forall :var a :body fn)))
    (expect (type-forall-p fa) :to-be-truthy)
    (expect (type-var-equal-p a (type-forall-var fa)) :to-be-truthy)
    (expect fn :to-be-type-equal-to (type-forall-body fa))))

(it-sequential "type-exists-and-mu-creation"
  (let* ((a    (fresh-type-var :name 'a))
         (pair (make-type-product :elems (list type-string a)))
         (ex   (make-type-exists :var a :knd nil :body pair)))
    (expect (type-exists-p ex) :to-be-truthy)
    (expect (type-var-equal-p a (type-exists-var ex)) :to-be-truthy)
    (expect (type-product-p (type-exists-body ex)) :to-be-truthy))
  (let* ((a  (fresh-type-var :name 'a))
         (mu (make-type-mu :var a
                           :body (make-type-union
                                  (list type-null
                                        (make-type-product :elems (list type-int a)))))))
    (expect (type-mu-p mu) :to-be-truthy)
    (expect (type-var-equal-p a (type-mu-var mu)) :to-be-truthy)
    (expect (type-union-p (type-mu-body mu)) :to-be-truthy)))

(it-sequential "type-hkt-app-creation"
  (let* ((list-con (make-type-primitive :name 'list))
         (list-int (make-type-app :fun list-con :arg type-int)))
    (expect (type-app-p list-int) :to-be-truthy)
    (expect (type-primitive-p (type-app-fun list-int)) :to-be-truthy)
    (expect type-int :to-be-type-equal-to (type-app-arg list-int))))

(it-each (("type-record-open-closed closed" nil 2)
          ("type-record-open-closed open"   t   1))
    "~A"
    (name-ignored open-p expected-field-count)
  (declare (ignore name-ignored))
  (let* ((rv  (when open-p (fresh-type-var :name 'rho)))
         (fields (if open-p
                     (list (cons 'name type-string))
                     (list (cons 'name type-string) (cons 'age type-int))))
         (rec (make-type-record :fields fields :row-var rv)))
    (expect (type-record-p rec) :to-be-truthy)
    (expect (length (type-record-fields rec)) :to-equal expected-field-count)
    (if open-p
        (expect (type-var-p (type-record-row-var rec)) :to-be-truthy)
        (expect (type-record-row-var rec) :to-be-null))))


(it-each (("type-arrow-mult-cases linear-one"  type-int  type-int  +pure-effect-row+ :one)
          ("type-arrow-mult-cases erased-zero" type-bool type-null nil                :zero))
    "~A"
    (name-ignored param-t ret-t effs mult)
  (declare (ignore name-ignored))
  (let ((arr (make-type-arrow-raw :params (list param-t) :return ret-t :effects effs :mult mult)))
    (expect (type-arrow-p arr) :to-be-truthy)
    (expect (type-arrow-mult arr) :to-be mult)))


(it-each (("type-linear-creation linear-one"   type-int    :one)
          ("type-linear-creation erased-zero"  type-string :zero)
          ("type-linear-creation unrestricted" type-bool   :omega))
    "~A"
    (name-ignored base grade)
  (declare (ignore name-ignored))
  (let ((lin (make-type-linear :base base :grade grade)))
    (expect (type-linear-p lin) :to-be-truthy)
    (expect (type-linear-grade lin) :to-be grade)
    (expect base :to-be-type-equal-to (type-linear-base lin))))

(it-sequential "type-lambda-creation"
  (let* ((a  (fresh-type-var :name 'a))
         (lam (make-type-lambda :var a :knd nil :body a)))
    (expect (type-lambda-p lam) :to-be-truthy)
    (expect (type-var-equal-p a (type-lambda-var lam)) :to-be-truthy)
    (expect (type-lambda-knd lam) :to-be-null)
    (expect (type-var-equal-p a (type-lambda-body lam)) :to-be-truthy)))

(it-sequential "type-refinement-creation-and-predicate-invocation"
  (let* ((pred (lambda (x) (> x 0)))
         (ref  (make-type-refinement :base type-int :predicate pred)))
    (expect (type-refinement-p ref) :to-be-truthy)
    (expect type-int :to-be-type-equal-to (type-refinement-base ref))
    (expect (funcall (type-refinement-predicate ref) 5) :to-be-truthy)
    (expect (funcall (type-refinement-predicate ref) -5) :to-be-falsy)))

(it-sequential "type-capability-creation"
  (let ((cap (make-type-capability :base type-string :cap 'read)))
    (expect (type-capability-p cap) :to-be-truthy)
    (expect type-string :to-be-type-equal-to (type-capability-base cap))
    (expect (type-capability-cap cap) :to-be 'read)))

(it-sequential "fresh-type-var-positional-name-argument"
  (let ((v (fresh-type-var 'positional-name)))
    (expect (type-var-p v) :to-be-truthy)
    (expect (type-var-name v) :to-be 'positional-name)
    (expect (type-var-link v) :to-be-null)
    (expect (type-var-upper-bound v) :to-be-null)
    (expect (type-var-lower-bound v) :to-be-null)))

(it-sequential "fresh-type-var-rejects-odd-keyword-plist"
  (signals error
    (fresh-type-var :name 'a :upper-bound)))

(it-sequential "fresh-type-var-rejects-unknown-keyword"
  (signals error
    (fresh-type-var :bogus-keyword 42)))

(it-sequential "reset-type-vars!-restarts-id-counter-from-one"
  (let ((cl-cc/type::*type-var-counter* cl-cc/type::*type-var-counter*))
    (reset-type-vars!)
    (let ((v1 (fresh-type-var 'first))
          (v2 (fresh-type-var 'second)))
      (expect (type-var-id v1) :to-equal 1)
      (expect (type-var-id v2) :to-equal 2))))

(it-sequential "type-var-equal-p-false-when-argument-is-not-a-type-var"
  (let ((v (fresh-type-var 'a)))
    (expect (type-var-equal-p v type-int) :to-be-falsy)
    (expect (type-var-equal-p type-int v) :to-be-falsy)
    (expect (type-var-equal-p type-int type-string) :to-be-falsy)))

(it-sequential "type-rigid-equal-p-false-when-argument-is-not-a-type-rigid"
  (let ((r (fresh-rigid-var 'a)))
    (expect (type-rigid-equal-p r type-int) :to-be-falsy)
    (expect (type-rigid-equal-p type-int r) :to-be-falsy)
    (expect (type-rigid-equal-p type-int type-string) :to-be-falsy)))

(it-sequential "fresh-rigid-var-without-name-defaults-to-nil"
  (let ((r (fresh-rigid-var)))
    (expect (type-rigid-p r) :to-be-truthy)
    (expect (type-rigid-name r) :to-be-null)))

(it-sequential "make-type-arrow-explicit-nil-mult-defaults-to-omega"
  (let* ((a   (fresh-type-var :name 'a))
         (arr (make-type-arrow (list a) a :mult nil)))
    (expect (type-arrow-p arr) :to-be-truthy)
    (expect (type-arrow-mult arr) :to-be :omega)
    (expect (type-arrow-effects arr) :to-be-null)))

(it-sequential "make-type-union-preserves-constructor-name-sugar"
  (let ((u (make-type-union (list type-int type-null) :constructor-name 'option)))
    (expect (type-union-p u) :to-be-truthy)
    (expect (type-union-constructor-name u) :to-be 'option))
  (let ((u2 (make-type-union (list type-int type-string))))
    (expect (type-union-constructor-name u2) :to-be-null)))

(it-sequential "make-type-intersection-positional-constructor"
  (let ((i (make-type-intersection (list type-int type-string))))
    (expect (type-intersection-p i) :to-be-truthy)
    (expect (length (type-intersection-types i)) :to-equal 2)
    (expect type-int :to-be-type-equal-to (first  (type-intersection-types i)))
    (expect type-string :to-be-type-equal-to (second (type-intersection-types i)))))

(it-sequential "type-node-family-slot-defaults-fire-when-keywords-are-omitted"
  ;; Every constructor above is exercised only with every keyword supplied,
  ;; which never runs the struct's own default-value forms (TYPE-NODE's
  ;; SOURCE-LOCATION/KIND included, via :include on every one of these).
  ;; Constructing each with the defaultable keywords omitted is what
  ;; actually reaches those forms.
  (let ((prim (make-type-primitive :name 'x)))
    (expect (type-node-source-location prim) :to-be-null)
    (expect (type-node-kind prim) :to-be-null))
  (let ((prod (make-type-product)))
    (expect (type-product-elems prod) :to-be-null))
  (let ((rec (make-type-record)))
    (expect (type-record-fields rec) :to-be-null)
    (expect (type-record-row-var rec) :to-be-null))
  (let ((var (make-type-variant)))
    (expect (type-variant-cases var) :to-be-null)
    (expect (type-variant-row-var var) :to-be-null))
  (let ((ex (make-type-exists)))
    (expect (type-exists-var ex) :to-be-null)
    (expect (type-exists-knd ex) :to-be-null)
    (expect (type-exists-body ex) :to-be-null))
  (let ((app (make-type-app)))
    (expect (type-app-fun app) :to-be-null)
    (expect (type-app-arg app) :to-be-null))
  (let ((lam (make-type-lambda)))
    (expect (type-lambda-var lam) :to-be-null)
    (expect (type-lambda-knd lam) :to-be-null)
    (expect (type-lambda-body lam) :to-be-null))
  (let ((mu (make-type-mu)))
    (expect (type-mu-var mu) :to-be-null)
    (expect (type-mu-body mu) :to-be-null))
  (let ((ref (make-type-refinement)))
    (expect (type-refinement-base ref) :to-be-null)
    (expect (type-refinement-predicate ref) :to-be-null))
  (let ((lin (make-type-linear)))
    (expect (type-linear-base lin) :to-be-null)
    (expect (type-linear-grade lin) :to-be :omega))
  (let ((cap (make-type-capability)))
    (expect (type-capability-base cap) :to-be-null)
    (expect (type-capability-cap cap) :to-be-null)))

(it-sequential "upgraded-array-and-complex-part-types"
  (let ((bit-upgraded (upgraded-array-element-type 'bit))
        (char-upgraded (upgraded-array-element-type 'character))
        (fallback-upgraded (upgraded-array-element-type '(or fixnum string)))
        (complex-part (upgraded-complex-part-type 'complex)))
    (expect (cl-cc/type:parse-type-specifier 'bit) :to-be-type-equal-to bit-upgraded)
    (expect (cl-cc/type:parse-type-specifier 'character) :to-be-type-equal-to char-upgraded)
    (expect type-any :to-be-type-equal-to fallback-upgraded)
    (expect (cl-cc/type:parse-type-specifier 'real) :to-be-type-equal-to complex-part)))

;;; ─────────────────────────────────────────────────────────────────────────
;;; 2026 Type System: Hash-Table Substitution API Tests
;;; ─────────────────────────────────────────────────────────────────────────

(it-sequential "subst-empty-has-no-bindings"
  (let ((s (make-substitution)))
    (expect (substitution-p s) :to-be-truthy)
    (expect (substitution-generation s) :to-equal 0)
    (let ((v (fresh-type-var)))
      (multiple-value-bind (bound found) (subst-lookup v s)
        (declare (ignore bound))
        (expect found :to-be-falsy)))))

(it-sequential "subst-extend-is-functional"
  (let* ((v  (fresh-type-var))
         (s0 (make-substitution))
         (s1 (subst-extend v type-int s0)))
    (multiple-value-bind (b f) (subst-lookup v s0) (declare (ignore b)) (expect f :to-be-falsy))
    (multiple-value-bind (bound found) (subst-lookup v s1)
      (expect found :to-be-truthy)
      (expect type-int :to-be-type-equal-to bound))
    (expect (> (substitution-generation s1) (substitution-generation s0)) :to-be-truthy)))

(it-sequential "subst-extend!-mutates-in-place"
  (let* ((v (fresh-type-var))
         (s (make-substitution)))
    (subst-extend! v type-string s)
    (multiple-value-bind (bound found) (subst-lookup v s)
      (expect found :to-be-truthy)
      (expect type-string :to-be-type-equal-to bound))))

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
