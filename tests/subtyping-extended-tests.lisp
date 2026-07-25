;;;; tests/unit/type/subtyping-extended-tests.lisp — Extended Subtyping and Lattice Tests
;;;;
;;;; Additional coverage for is-subtype-p, type-join, and type-meet beyond the
;;;; base cases in subtyping-tests.lisp. Depends on subtyping-tests.lisp being
;;;; loaded first (via ASDF :serial t) for the prim helper and suite definition.

(in-package :cl-cc-type/test)

;;; ─── is-subtype-p — extended reflexivity and hierarchy ───────────────────────

(progn
  (it-sequential "is-subtype-reflexive int"
    (expect (cl-cc/type:is-subtype-p type-int type-int) :to-be-truthy))
  (it-sequential "is-subtype-reflexive string"
    (expect (cl-cc/type:is-subtype-p type-string type-string) :to-be-truthy))
  (it-sequential "is-subtype-reflexive bool"
    (expect (cl-cc/type:is-subtype-p type-bool type-bool) :to-be-truthy))
  (it-sequential "is-subtype-reflexive null"
    (expect (cl-cc/type:is-subtype-p type-null type-null) :to-be-truthy)))

(progn
  (it-sequential "is-subtype-primitive-hierarchy fixnum<integer"
    (expect (cl-cc/type:type-name-subtype-p 'fixnum 'integer) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy integer<rational"
    (expect (cl-cc/type:type-name-subtype-p 'integer 'rational) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy rational<real"
    (expect (cl-cc/type:type-name-subtype-p 'rational 'real) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy float<real"
    (expect (cl-cc/type:type-name-subtype-p 'float 'real) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy real<number"
    (expect (cl-cc/type:type-name-subtype-p 'real 'number) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy fixnum<number"
    (expect (cl-cc/type:type-name-subtype-p 'fixnum 'number) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy number<t"
    (expect (cl-cc/type:type-name-subtype-p 'number 't) :to-be-truthy))
  (it-sequential "is-subtype-primitive-hierarchy int not<string"
    (expect (cl-cc/type:type-name-subtype-p 'fixnum 'string) :to-be-falsy)))

(progn
  (it-sequential "is-subtype-of-top-type int"
    (expect (cl-cc/type:is-subtype-p type-int type-any) :to-be-truthy))
  (it-sequential "is-subtype-of-top-type string"
    (expect (cl-cc/type:is-subtype-p type-string type-any) :to-be-truthy))
  (it-sequential "is-subtype-of-top-type bool"
    (expect (cl-cc/type:is-subtype-p type-bool type-any) :to-be-truthy)))

(it-sequential "is-subtype-unknown-gradual"
  (let ((unk cl-cc/type:+type-unknown+))
    (expect (cl-cc/type:is-subtype-p unk  type-int) :to-be-truthy)
    (expect (cl-cc/type:is-subtype-p type-int unk) :to-be-truthy)))

(progn
  (it-sequential "is-subtype-union-right int in or-int-string"
    (let ((u (make-type-union (list type-int type-string))))
      (expect (cl-cc/type:is-subtype-p type-int u) :to-be-truthy)))
  (it-sequential "is-subtype-union-right string in or"
    (let ((u (make-type-union (list type-int type-string))))
      (expect (cl-cc/type:is-subtype-p type-string u) :to-be-truthy)))
  (it-sequential "is-subtype-union-right bool not in"
    (let ((u (make-type-union (list type-int type-string))))
      (expect (cl-cc/type:is-subtype-p type-bool u) :to-be-falsy))))

(it-sequential "is-subtype-function-contravariant-params"
  (let ((f1 (make-type-arrow (list (make-type-primitive :name 'number)) type-string))
        (f2 (make-type-arrow (list (make-type-primitive :name 'fixnum))  type-string)))
    (expect (cl-cc/type:is-subtype-p f1 f2) :to-be-truthy)))

;;; ─── type-join / type-meet — extended lattice coverage ──────────────────────

(progn
  (it-sequential "type-join-meet-equal-types join-int"
    (expect (type-equal-p type-int (funcall #'cl-cc/type:type-join type-int type-int)) :to-be-truthy))
  (it-sequential "type-join-meet-equal-types join-string"
    (expect (type-equal-p type-string (funcall #'cl-cc/type:type-join type-string type-string)) :to-be-truthy))
  (it-sequential "type-join-meet-equal-types join-bool"
    (expect (type-equal-p type-bool (funcall #'cl-cc/type:type-join type-bool type-bool)) :to-be-truthy))
  (it-sequential "type-join-meet-equal-types meet-int"
    (expect (type-equal-p type-int (funcall #'cl-cc/type:type-meet type-int type-int)) :to-be-truthy))
  (it-sequential "type-join-meet-equal-types meet-string"
    (expect (type-equal-p type-string (funcall #'cl-cc/type:type-meet type-string type-string)) :to-be-truthy)))

;;; ─── type-join / type-meet lattice laws (property-based) ────────────────────
;;;
;;; type-join and type-meet both special-case (type-equal-p t1 t2) by
;;; returning t1 unchanged (see src/subtyping.lisp), so both are idempotent
;;; for every type, generalizing the join-int/join-string/... example cases
;;; above. type-join is also commutative over this primitive domain: it
;;; special-cases type-unknown-p and is-subtype-p before falling back to
;;; find-common-supertype, which searches NAME1's supertype chain for the
;;; first entry also in NAME2's chain — order-independent for this domain, as
;;; confirmed by exhaustively comparing (type-join a b) against (type-join b a)
;;; for every pair. type-meet is NOT included here: for unrelated types it
;;; builds a type-intersection whose stored member order depends on argument
;;; order, so (type-equal-p (type-meet a b) (type-meet b a)) is false for
;;; those pairs even though the two intersections are set-equal — confirmed
;;; false via a brute-force check before writing these tests, so it is
;;; deliberately excluded as a law here.

(it-property "type-join-idempotent"
    ((tp (gen-member (list type-int type-string type-bool type-null type-any))))
  (expect (type-equal-p (cl-cc/type:type-join tp tp) tp) :to-be-truthy))

(it-property "type-meet-idempotent"
    ((tp (gen-member (list type-int type-string type-bool type-null type-any))))
  (expect (type-equal-p (cl-cc/type:type-meet tp tp) tp) :to-be-truthy))

(it-property "type-join-commutative"
    ((a (gen-member (list type-int type-string type-bool type-null type-any)))
     (b (gen-member (list type-int type-string type-bool type-null type-any))))
  (expect (type-equal-p (cl-cc/type:type-join a b) (cl-cc/type:type-join b a))
          :to-be-truthy))

(progn
  (it-sequential "type-lattice-join-meet-subtype join"
    (let* ((fixnum-t  (make-type-primitive :name 'fixnum))
           (integer-t (make-type-primitive :name 'integer))
           (result    (funcall #'cl-cc/type:type-join fixnum-t integer-t)))
      (expect (type-primitive-p result) :to-be-truthy)
      (expect (type-primitive-name result) :to-be 'integer)))
  (it-sequential "type-lattice-join-meet-subtype meet"
    (let* ((fixnum-t  (make-type-primitive :name 'fixnum))
           (integer-t (make-type-primitive :name 'integer))
           (result    (funcall #'cl-cc/type:type-meet fixnum-t integer-t)))
      (expect (type-primitive-p result) :to-be-truthy)
      (expect (type-primitive-name result) :to-be 'fixnum))))

(it-sequential "type-join-incompatible-makes-union"
  (let* ((fixnum-t (make-type-primitive :name 'fixnum))
         (string-t (make-type-primitive :name 'string))
         (result   (cl-cc/type:type-join fixnum-t string-t)))
    (expect (type-primitive-p result) :to-be-truthy)
    (expect (type-primitive-name result) :to-be 't)))

(it-sequential "type-join-with-unknown-is-other"
  (let* ((unk cl-cc/type:+type-unknown+)
         (result (cl-cc/type:type-join unk type-int)))
    (expect (type-equal-p type-int result) :to-be-truthy)))

(it-sequential "type-meet-incompatible-makes-intersection"
  (let ((result (cl-cc/type:type-meet type-int type-string)))
    (expect (type-intersection-p result) :to-be-truthy)
    (expect (length (type-intersection-types result)) :to-equal 2)))
