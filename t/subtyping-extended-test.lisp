;;;; t/subtyping-extended-test.lisp — Extended Subtyping and Lattice Tests
;;;;
;;;; Additional coverage for is-subtype-p, type-join, and type-meet beyond the
;;;; base cases in subtyping-test.lisp. Depends on subtyping-test.lisp being
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
    (expect type-int :to-be-type-equal-to (funcall #'cl-cc/type:type-join type-int type-int)))
  (it-sequential "type-join-meet-equal-types join-string"
    (expect type-string :to-be-type-equal-to (funcall #'cl-cc/type:type-join type-string type-string)))
  (it-sequential "type-join-meet-equal-types join-bool"
    (expect type-bool :to-be-type-equal-to (funcall #'cl-cc/type:type-join type-bool type-bool)))
  (it-sequential "type-join-meet-equal-types meet-int"
    (expect type-int :to-be-type-equal-to (funcall #'cl-cc/type:type-meet type-int type-int)))
  (it-sequential "type-join-meet-equal-types meet-string"
    (expect type-string :to-be-type-equal-to (funcall #'cl-cc/type:type-meet type-string type-string))))

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
  (expect (cl-cc/type:type-join tp tp) :to-be-type-equal-to tp))

(it-property "type-meet-idempotent"
    ((tp (gen-member (list type-int type-string type-bool type-null type-any))))
  (expect (cl-cc/type:type-meet tp tp) :to-be-type-equal-to tp))

(it-property "type-join-commutative"
    ((a (gen-member (list type-int type-string type-bool type-null type-any)))
     (b (gen-member (list type-int type-string type-bool type-null type-any))))
  (expect (cl-cc/type:type-join a b) :to-be-type-equal-to (cl-cc/type:type-join b a)))

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
    (expect type-int :to-be-type-equal-to result)))

(it-sequential "type-meet-incompatible-makes-intersection"
  (let ((result (cl-cc/type:type-meet type-int type-string)))
    (expect (type-intersection-p result) :to-be-truthy)
    (expect (length (type-intersection-types result)) :to-equal 2)))

;;; ─── type-join / type-meet — refinement recursion branches ──────────────────
;;;
;;; type-join and type-meet both special-case a type-refinement T1 by
;;; recursing on its base (regardless of T2's shape), and — only when T1 is
;;; neither a primitive nor a refinement — special-case a type-refinement T2
;;; by recursing on ITS base. The primitive/primitive and default
;;; (make-type-union / make-type-intersection) arms are already covered
;;; above; these arms specifically exercise the two refinement-recursion
;;; paths plus the primitive-vs-non-primitive union fallback, none of which
;;; appear elsewhere in this file or in subtyping-test.lisp.

(it-sequential "type-join-refinement-lhs-delegates-to-base"
  (let* ((refined (cl-cc/type:make-type-refinement :base type-int :predicate #'plusp))
         (result  (cl-cc/type:type-join refined type-string)))
    ;; Same result as joining the unwrapped base against type-string directly.
    (expect result :to-be-type-equal-to (cl-cc/type:type-join type-int type-string))))

(it-sequential "type-join-non-primitive-lhs-with-refinement-rhs"
  (let* ((rec1     (make-type-record :fields (list (cons 'x type-int)) :row-var nil))
         (rec2     (make-type-record :fields (list (cons 'y type-string)) :row-var nil))
         (refined2 (cl-cc/type:make-type-refinement :base rec2 :predicate #'identity))
         (result   (cl-cc/type:type-join rec1 refined2)))
    ;; rec1 and rec2 are structurally incomparable (neither has the other's
    ;; required field), so the refinement-rhs arm recurses to
    ;; (type-join rec1 rec2), landing in the generic make-type-union fallback.
    (expect (type-union-p result) :to-be-truthy)
    (expect (= (length (type-union-types result)) 2) :to-be-truthy)))

(it-sequential "type-join-primitive-lhs-with-non-primitive-rhs-yields-union"
  (let* ((rec    (make-type-record :fields (list (cons 'x type-int)) :row-var nil))
         (result (cl-cc/type:type-join type-int rec)))
    ;; type-int is not a subtype of rec (and vice versa), so the
    ;; type-primitive/non-primitive arm of type-join's typecase builds a
    ;; plain union rather than searching *subtype-table*.
    (expect (type-union-p result) :to-be-truthy)
    (expect (= (length (type-union-types result)) 2) :to-be-truthy)))

(it-sequential "type-meet-refinement-lhs-delegates-to-base"
  (let* ((refined (cl-cc/type:make-type-refinement :base type-int :predicate #'plusp))
         (result  (cl-cc/type:type-meet refined type-string)))
    (expect result :to-be-type-equal-to (cl-cc/type:type-meet type-int type-string))))

(it-sequential "type-meet-non-refinement-lhs-with-refinement-rhs"
  (let* ((refined-string (cl-cc/type:make-type-refinement :base type-string :predicate #'stringp))
         (result         (cl-cc/type:type-meet type-int refined-string)))
    ;; type-int is neither a primitive-match nor a refinement, so the
    ;; refinement-rhs arm recurses to (type-meet type-int type-string).
    (expect (type-intersection-p result) :to-be-truthy)))

;;; ─── subtypep — direct type-node arguments (not just symbols) ──────────────
;;;
;;; subtypep normalizes each argument independently via
;;; (if (typep argN 'type-node) argN (parse-type-specifier argN)); every
;;; existing test passes plain symbols for both arguments, so the
;;; already-a-type-node branch is never exercised. Mix a type-node TYPE1
;;; with a symbol TYPE2 (and vice versa) to hit both sides of that check.

(it-sequential "subtypep-accepts-type-nodes-directly"
  (multiple-value-bind (ok surep) (cl-cc/type:subtypep type-int type-any)
    (expect ok :to-be-truthy)
    (expect surep :to-be-truthy))
  (multiple-value-bind (ok surep) (cl-cc/type:subtypep type-string 'integer)
    (expect ok :to-be-falsy)
    (expect surep :to-be-truthy))
  (multiple-value-bind (ok surep) (cl-cc/type:subtypep 'fixnum type-any)
    (expect ok :to-be-truthy)
    (expect surep :to-be-truthy)))

;;; ─── is-subtype-p — structural record field labels are package-independent ──
;;;
;;; %subtype-row-p matches record fields via %row-label-equal-p, which
;;; accepts symbols with the same NAME from different packages (not just EQ
;;; symbols). The existing record-subtyping tests always use labels interned
;;; in the same package, so that branch of %row-label-equal-p (symbolp a,
;;; symbolp b, string= names, not EQ) is never taken. A keyword label and a
;;; plain symbol label with the same name ("X") are never EQ but do compare
;;; string=.

(it-sequential "is-subtype-p-record-field-labels-compare-package-independently"
  (let ((wide   (make-type-record :fields (list (cons :x type-int)
                                                 (cons :y type-string))
                                  :row-var nil))
        (narrow (make-type-record :fields (list (cons 'x type-int)) :row-var nil)))
    (expect (not (eq :x 'x)) :to-be-truthy)
    (expect (cl-cc/type:is-subtype-p wide narrow) :to-be-truthy)))

(it-sequential "row-label-equal-p-rejects-a-non-symbol-label-that-does-not-match-by-eq"
  ;; %ROW-LABEL-EQUAL-P's (SYMBOLP a) conjunct had only ever been observed
  ;; true: every existing record/variant field label above is a symbol
  ;; (plain or keyword). A non-symbol label (a string) can never EQ any
  ;; existing field, forcing evaluation into the AND, where SYMBOLP
  ;; correctly rejects it instead of erroring on SYMBOL-NAME.
  (let ((wide   (make-type-record :fields (list (cons 'x type-int)) :row-var nil))
        (narrow (make-type-record :fields (list (cons "x" type-int)) :row-var nil)))
    (expect (cl-cc/type:is-subtype-p wide narrow) :to-be-falsy)))

(it-sequential "primitive-class-record-type-returns-nil-for-a-non-primitive-type"
  ;; %PRIMITIVE-CLASS-RECORD-TYPE's own (TYPE-PRIMITIVE-P ty) guard is
  ;; always true through its sole caller (IS-SUBTYPE-P's TYPE-PRIMITIVE
  ;; typecase arm already guarantees TY is a primitive); called directly
  ;; with a non-primitive to exercise the guard's false path.
  (expect (cl-cc/type::%primitive-class-record-type (cl-cc/type:fresh-type-var))
          :to-be-null))

;;; ─── register-protocol-type / %coerce-structural-field-spec ────────────────
;;;
;;; %coerce-structural-field-spec accepts three input shapes: a bare symbol
;;; (type defaults to type-any — already covered by the 'drawable protocol in
;;; subtyping-test.lisp), a (name type-specifier) pair whose type is parsed
;;; via parse-type-specifier, a (name type-node) pair whose type is used
;;; as-is, and anything else signals an error. Only the bare-symbol shape is
;;; exercised elsewhere in this suite.

(it-sequential "register-protocol-type-name-and-specifier-pair"
  (let ((cl-cc/type:*protocol-type-registry* (make-hash-table :test #'eq)))
    (cl-cc/type:register-protocol-type 'countable '((count integer)))
    (let ((fields (cl-cc/type:lookup-protocol-type 'countable)))
      (expect fields :to-be-truthy)
      (expect (cdr (first fields)) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 'integer)))))

(it-sequential "register-protocol-type-name-and-type-node-pair"
  (let ((cl-cc/type:*protocol-type-registry* (make-hash-table :test #'eq)))
    (cl-cc/type:register-protocol-type 'sized `((size ,type-int)))
    (let ((fields (cl-cc/type:lookup-protocol-type 'sized)))
      (expect fields :to-be-truthy)
      (expect (cdr (first fields)) :to-be-type-equal-to type-int))))

(it-sequential "register-protocol-type-invalid-spec-signals-error"
  (signals error
    (cl-cc/type:register-protocol-type 'malformed (list 42))))

;;; ─── is-subtype-p — FR-1503 information-flow payloads without a base type ──
;;;
;;; %subtype-advanced-information-flow-p falls back to comparing the two
;;; payloads directly (via TYPE-ADVANCED-PAYLOAD-EQUAL-P) when either side's
;;; payload has no extractable base type -- every existing FR-1503 test
;;; payload is a well-formed (LABEL base-type-node) pair, so that fallback
;;; was never taken. Built directly via MAKE-TYPE-ADVANCED, bypassing the
;;; :flow-property validator (a different check, for a different purpose)
;;; that parse-type-specifier would otherwise route this through.

(it-sequential "is-subtype-p-fr-1503-falls-back-to-payload-equality-without-a-base-type"
  (let ((n1 (cl-cc/type:make-type-advanced :feature-id "FR-1503" :name 'advanced
                                           :args (list '(secret)) :properties nil))
        (n2 (cl-cc/type:make-type-advanced :feature-id "FR-1503" :name 'advanced
                                           :args (list '(secret)) :properties nil)))
    (expect (cl-cc/type:is-subtype-p n1 n2) :to-be-truthy))
  (let ((n1 (cl-cc/type:make-type-advanced :feature-id "FR-1503" :name 'advanced
                                           :args (list '(secret)) :properties nil))
        (n2 (cl-cc/type:make-type-advanced :feature-id "FR-1503" :name 'advanced
                                           :args (list '(secret different-marker)) :properties nil)))
    (expect (cl-cc/type:is-subtype-p n1 n2) :to-be-falsy)))

(it-sequential "lookup-protocol-type-unregistered-returns-nil"
  (let ((cl-cc/type:*protocol-type-registry* (make-hash-table :test #'eq)))
    (expect (cl-cc/type:lookup-protocol-type 'never-registered-protocol) :to-be-falsy)))

;;; ─── is-subtype-p — protocol type-constructor edge cases ───────────────────
;;;
;;; %protocol-required-record-type returns nil (rather than a record) both
;;; when the constructor isn't a well-formed (protocol NAME) shape at all
;;; (%protocol-type-p false — e.g. a differently-named single-arg
;;; constructor) and when it IS well-formed but NAME was never registered
;;; (lookup-protocol-type returns nil). Both make %is-subtype-p-by-t2's
;;; type-constructor arm fall through to nil. Neither is exercised by the
;;; existing 'drawable protocol test, which only covers the
;;; record-field-mismatch failure path.

(it-sequential "is-subtype-p-non-protocol-constructor-never-satisfied"
  (expect (cl-cc/type:is-subtype-p
           type-int
           (cl-cc/type:make-type-constructor 'vector (list type-int)))
          :to-be-falsy))

(it-sequential "is-subtype-p-unregistered-protocol-never-satisfied"
  (let ((cl-cc/type:*protocol-type-registry* (make-hash-table :test #'eq)))
    (expect (cl-cc/type:is-subtype-p
             type-int
             (cl-cc/type:parse-type-specifier '(protocol totally-unregistered-protocol)))
            :to-be-falsy)))

;;; ─── is-subtype-p — type-constructor / type-constructor (both sides) ───────
;;;
;;; is-subtype-p's own type-constructor typecase arm (T1 driving) requires
;;; T2 to also be a type-constructor with the SAME name, the SAME arity, and
;;; pointwise-covariant args. The 'drawable protocol tests only ever put a
;;; type-primitive or (protocol X) constructor on T1's side; this exercises
;;; a plain non-protocol constructor vs. constructor comparison directly.

(it-sequential "is-subtype-p-type-constructor-covariant-args"
  (expect (cl-cc/type:is-subtype-p
           (cl-cc/type:make-type-constructor 'vector (list type-int))
           (cl-cc/type:make-type-constructor 'vector (list type-any)))
          :to-be-truthy))

(it-sequential "is-subtype-p-type-constructor-name-mismatch"
  (expect (cl-cc/type:is-subtype-p
           (cl-cc/type:make-type-constructor 'vector (list type-int))
           (cl-cc/type:make-type-constructor 'matrix (list type-int)))
          :to-be-falsy))

(it-sequential "is-subtype-p-type-constructor-arity-mismatch"
  (expect (cl-cc/type:is-subtype-p
           (cl-cc/type:make-type-constructor 'vector (list type-int))
           (cl-cc/type:make-type-constructor 'vector (list type-int type-int)))
          :to-be-falsy))

;;; ─── %subtype-arrow-p — effects and multiplicity comparison ────────────────
;;;
;;; The existing "subtype-function-variance" and
;;; "is-subtype-function-contravariant-params" tests never set :effects or
;;; :mult, so every arrow they build has effects=nil and mult=:omega on both
;;; sides — only the "both nil" arm of the effects OR-clause, and the
;;; trivially-equal :omega/:omega arm of the mult EQL check, are reached.
;;;
;;; IMPORTANT: type-equal-p for type-arrow (see types-env.lisp) compares only
;;; params, return, and mult — never effects. Since is-subtype-p's very first
;;; disjunct is (type-equal-p t1 t2), two arrows built with identical params/
;;; return/mult but *different* effects are already type-equal-p and short-
;;; circuit true before %subtype-arrow-p's effects logic ever runs. To
;;; genuinely exercise that logic below, every case here uses two distinct
;;; (but contravariantly-related) param lists — (list type-any) vs.
;;; (list type-int) — so type-equal-p is false and is-subtype-p must actually
;;; recurse into %subtype-arrow-p; the return type and one other field stay
;;; equal so effects/mult are what determines the outcome.

(it-sequential "subtype-arrow-matching-effect-rows"
  (let ((io1 (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                   :row-var nil))
        (io2 (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                   :row-var nil)))
    (expect (cl-cc/type:is-subtype-p
             (make-type-arrow (list type-any) type-int :effects io1)
             (make-type-arrow (list type-int) type-int :effects io2))
            :to-be-truthy)))

(it-sequential "subtype-arrow-mismatched-effect-rows"
  (let ((io-row    (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                         :row-var nil))
        (state-row (make-type-effect-row :effects (list (make-type-effect-op :name 'state :args nil))
                                         :row-var nil)))
    (expect (cl-cc/type:is-subtype-p
             (make-type-arrow (list type-any) type-int :effects io-row)
             (make-type-arrow (list type-int) type-int :effects state-row))
            :to-be-falsy)))

(it-sequential "subtype-arrow-effects-present-on-one-side-only"
  (let ((io-row (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                      :row-var nil)))
    (expect (cl-cc/type:is-subtype-p
             (make-type-arrow (list type-any) type-int :effects io-row)
             (make-type-arrow (list type-int) type-int))
            :to-be-falsy)
    (expect (cl-cc/type:is-subtype-p
             (make-type-arrow (list type-any) type-int)
             (make-type-arrow (list type-int) type-int :effects io-row))
            :to-be-falsy)))

(it-sequential "subtype-arrow-multiplicity-mismatch-and-match"
  (expect (cl-cc/type:is-subtype-p
           (make-type-arrow (list type-int) type-int :mult :one)
           (make-type-arrow (list type-int) type-int :mult :omega))
          :to-be-falsy)
  (expect (cl-cc/type:is-subtype-p
           (make-type-arrow (list type-any) type-int :mult :zero)
           (make-type-arrow (list type-int) type-int :mult :zero))
          :to-be-truthy))

;;; ─── is-subtype-p — type-effect-row branch ──────────────────────────────────
;;;
;;; is-subtype-p's type-effect-row typecase arm (effect-row-subset-p, then
;;; fallback to %is-subtype-p-by-t2) is never reached by any existing test:
;;; type-effect-row values only ever appear nested inside type-arrow's
;;; :effects slot, compared by %subtype-arrow-p (a different function), never
;;; passed directly to is-subtype-p.

(it-sequential "is-subtype-p-effect-row-subset"
  (let ((io-row  (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                       :row-var nil))
        (io-st-row (make-type-effect-row
                    :effects (list (make-type-effect-op :name 'io :args nil)
                                   (make-type-effect-op :name 'state :args nil))
                    :row-var nil)))
    (expect (cl-cc/type:is-subtype-p io-row io-st-row) :to-be-truthy)
    (expect (cl-cc/type:is-subtype-p io-st-row io-row) :to-be-falsy)))

(it-sequential "is-subtype-p-effect-row-open-row-var-is-superset"
  (let ((io-row  (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                       :row-var nil))
        (open-row (make-type-effect-row :effects nil
                                        :row-var (cl-cc/type:fresh-type-var))))
    (expect (cl-cc/type:is-subtype-p io-row open-row) :to-be-truthy)))

(it-sequential "is-subtype-p-effect-row-non-effect-row-t2-reaches-the-t2-fallback"
  ;; Both cases above have T2 typep TYPE-EFFECT-ROW, so the TYPE-EFFECT-
  ;; ROW clause's (AND (TYPEP T2 'TYPE-EFFECT-ROW) ...) always short-
  ;; circuits via EFFECT-ROW-SUBSET-P, never via TYPEP itself being
  ;; false. A union containing a compatible effect row reaches
  ;; %IS-SUBTYPE-P-BY-T2 via that other path, with a real match in its
  ;; TYPE-UNION clause.
  (let ((io-row (make-type-effect-row :effects (list (make-type-effect-op :name 'io :args nil))
                                      :row-var nil)))
    (expect (cl-cc/type:is-subtype-p
             io-row (cl-cc/type:make-type-union (list io-row type-string)))
            :to-be-truthy)))

;;; ─── is-subtype-p — type-advanced / FR-1503 information-flow subtyping ─────
;;;
;;; %subtype-advanced-p and %subtype-advanced-information-flow-p are never
;;; exercised anywhere in this test suite (no t/*.lisp file mentions
;;; "FR-1503"). FR-1503 payloads encode a security label plus a base type as
;;; a 2-element list (LABEL-HEAD BASE-TYPE); is-subtype-p should permit flow
;;; from a less-restrictive label to a more-restrictive one (public ->
;;; trusted) when the base types agree, and reject the reverse direction.

(it-sequential "is-subtype-p-advanced-information-flow-permits-upward-flow"
  (let ((public-int  (cl-cc/type:make-type-advanced
                       :feature-id "FR-1503"
                       :args (list (list 'public type-int))))
        (trusted-int (cl-cc/type:make-type-advanced
                      :feature-id "FR-1503"
                      :args (list (list 'trusted type-int)))))
    (expect (cl-cc/type:is-subtype-p public-int trusted-int) :to-be-truthy)
    (expect (cl-cc/type:is-subtype-p trusted-int public-int) :to-be-falsy)))

(it-sequential "is-subtype-p-advanced-different-feature-ids-never-related"
  (let ((flow-node    (cl-cc/type:make-type-advanced
                        :feature-id "FR-1503"
                        :args (list (list 'public type-int))))
        (dynamic-node (cl-cc/type:make-type-dynamic type-int)))
    (expect (cl-cc/type:is-subtype-p flow-node dynamic-node) :to-be-falsy)
    (expect (cl-cc/type:is-subtype-p dynamic-node flow-node) :to-be-falsy)))

(it-sequential "is-subtype-p-advanced-generic-feature-requires-payload-equality"
  (let ((dyn-int-1 (cl-cc/type:make-type-dynamic type-int))
        (dyn-int-2 (cl-cc/type:make-type-dynamic type-int))
        (dyn-str   (cl-cc/type:make-type-dynamic type-string)))
    ;; FR-2501 (Dynamic) has no custom-validator, so %subtype-advanced-p
    ;; falls through to its default (t (type-equal-p t1 t2)) arm.
    (expect (cl-cc/type:is-subtype-p dyn-int-1 dyn-int-2) :to-be-truthy)
    (expect (cl-cc/type:is-subtype-p dyn-int-1 dyn-str) :to-be-falsy)))

;;; ─── upgraded-array-element-type ────────────────────────────────────────────
;;;
;;; Entirely untested prior to this file: not referenced anywhere under t/.
;;; Exercises all three branches (bit, character, default-to-top) plus the
;;; non-symbol/non-type-node input path of the internal
;;; %normalize-type-specifier helper, which bypasses parse-type-specifier
;;; entirely and defaults straight to the top type.

(it-sequential "upgraded-array-element-type-bit"
  (expect (cl-cc/type:upgraded-array-element-type 'bit) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 'bit)))

(it-sequential "upgraded-array-element-type-character"
  (expect (cl-cc/type:upgraded-array-element-type 'character) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 'character)))

(it-sequential "upgraded-array-element-type-defaults-to-top"
  (expect (cl-cc/type:upgraded-array-element-type 'fixnum) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 't)))

(it-sequential "upgraded-array-element-type-non-symbol-input-defaults-to-top"
  ;; %normalize-type-specifier only calls parse-type-specifier for symbol
  ;; typespecs; a compound list specifier like (vector fixnum) is neither a
  ;; type-node nor a symbol, so it skips straight to the top-type default.
  (expect (cl-cc/type:upgraded-array-element-type '(vector fixnum)) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 't)))

(it-sequential "upgraded-array-element-type-accepts-type-node-directly"
  (expect (cl-cc/type:upgraded-array-element-type type-char) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 'character)))

;;; ─── upgraded-complex-part-type ─────────────────────────────────────────────
;;;
;;; Entirely untested prior to this file. Both arguments are ignored — the
;;; function unconditionally returns the REAL type — so any TYPESPEC/
;;; ENVIRONMENT combination should produce the same result.

(it-sequential "upgraded-complex-part-type-always-real"
  (expect (cl-cc/type:upgraded-complex-part-type 'fixnum) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 'real))
  (expect (cl-cc/type:upgraded-complex-part-type 'string nil) :to-be-type-equal-to (cl-cc/type:parse-type-specifier 'real)))

;;; ─── %primitive-class-record-type — inference.lisp load-order guard ───────
;;;
;;; SUBTYPING.LISP (position 61 in cl-cc-type.asd) deliberately has no hard
;;; load-order dependency on INFERENCE.LISP (position 71), which defines
;;; LOOKUP-CLASS-TYPE / LOOKUP-CLASS-METHOD-TYPES; %PRIMITIVE-CLASS-RECORD-
;;; TYPE guards both calls behind FBOUNDP so a smaller subsystem or a
;;; future reordering degrades gracefully instead of erroring. In the
;;; fully loaded system this guard always succeeds, so its false path is
;;; reached only by temporarily FMAKUNBOUND-ing both symbols.

(it-sequential "primitive-class-record-type-degrades-gracefully-when-inference-lisp-is-unloaded"
  (let ((class-type-fn (symbol-function 'cl-cc/type:lookup-class-type))
        (method-types-fn (symbol-function 'cl-cc/type:lookup-class-method-types)))
    (unwind-protect
        (progn
          (fmakunbound 'cl-cc/type:lookup-class-type)
          (fmakunbound 'cl-cc/type:lookup-class-method-types)
          (expect (cl-cc/type::%primitive-class-record-type type-int) :to-be-null))
      (setf (symbol-function 'cl-cc/type:lookup-class-type) class-type-fn)
      (setf (symbol-function 'cl-cc/type:lookup-class-method-types) method-types-fn))))
