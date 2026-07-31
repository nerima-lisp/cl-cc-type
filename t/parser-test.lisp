;;;; t/parser-test.lisp — Type Parser Tests (primitive/compound/structural)
;;;;
;;;; Tests for src/parser.lisp:
;;;; parse-type-specifier, parse-primitive-type, parse-compound-type,
;;;; typed AST nodes, looks-like-type-specifier-p.
;;;; Arrow/quantifier/modal tests → parser-arrow-quantifier-test.lisp.

(in-package :cl-cc-type/test)

;;; ─── parse-type-specifier: atoms ─────────────────────────────────────────

(progn
  (it-sequential "parse-hole-type-specifiers question-mark"
    (expect (cl-cc/type:type-error-p (cl-cc/type:parse-type-specifier (quote ?))) :to-be-truthy))
  (it-sequential "parse-hole-type-specifiers underscore"
    (expect (cl-cc/type:type-error-p (cl-cc/type:parse-type-specifier (quote _))) :to-be-truthy)))

(it-sequential "parse-option-type"
  (let ((ty (cl-cc/type:parse-type-specifier '(option string))))
    (expect (type-union-p ty) :to-be-truthy)
    (expect (length (type-union-types ty)) :to-equal 2)
    (expect (some (lambda (x) (type-equal-p x type-null)) (type-union-types ty)) :to-be-truthy)
    (expect (some (lambda (x) (type-equal-p x type-string)) (type-union-types ty)) :to-be-truthy)))

(it-sequential "looks-like-type-specifier-option"
  (expect (cl-cc/type:looks-like-type-specifier-p '(option fixnum)) :to-be-truthy))

(defun %primitive-symbols-test-expected-type (key)
  "Resolve a table-test KEY keyword to its expected singleton type-node.
it-each's row data is literal, unevaluated data (confirmed against
cl-weave's own dsl-guide.md after an earlier attempt at this table
embedded evaluated type-node references directly and every case failed);
a keyword indirection is what lets a data row still name a real object."
  (ecase key
    (:null type-null) (:int type-int) (:string type-string)
    (:bool type-bool) (:symbol type-symbol) (:char type-char)
    (:any type-any) (:cons type-cons)))

(it-each (("parse-primitive-symbols nil"     nil       :null)
          ("parse-primitive-symbols fixnum"  fixnum    :int)
          ("parse-primitive-symbols integer" integer   :int)
          ("parse-primitive-symbols string"  string    :string)
          ("parse-primitive-symbols boolean" boolean   :bool)
          ("parse-primitive-symbols bool"    bool      :bool)
          ("parse-primitive-symbols symbol"  symbol    :symbol)
          ("parse-primitive-symbols character" character :char)
          ("parse-primitive-symbols char"    char      :char)
          ("parse-primitive-symbols t"       t         :any)
          ("parse-primitive-symbols top"     top       :any)
          ("parse-primitive-symbols cons"    cons      :cons))
    "~A"
    (name-ignored input expected-key)
  (declare (ignore name-ignored))
  (expect (%primitive-symbols-test-expected-type expected-key)
          :to-be-type-equal-to (cl-cc/type:parse-type-specifier input)))

(it-sequential "parse-unknown-symbol"
  (let ((ty (cl-cc/type:parse-type-specifier 'my-custom-type)))
    (expect (type-primitive-p ty) :to-be-truthy)
    (expect (type-primitive-name ty) :to-be 'my-custom-type)))

;;; parse-primitive-type's alias-registry branch: when a symbol misses the
;;; *primitive-type-name-table* but IS registered in *type-alias-registry*,
;;; it resolves by recursively parsing the alias's target spec instead of
;;; falling through to the raw make-type-primitive fallback above.
;;; REGISTER-TYPE-ALIAS -- the DEFINE-REGISTRY-generated public setter for
;;; this exact table -- had no caller anywhere in the tree (only its
;;; LOOKUP-TYPE-ALIAS sibling was exercised); using it here instead of
;;; poking the hash table directly closes that gap and is the more
;;; idiomatic way to populate the registry under test in the first place.
(it-sequential "parse-primitive-type-alias-registry-lookup"
  (let* ((table cl-cc/type:*type-alias-registry*)
         (key 'parser-test-alias-symbol)
         (saved (gethash key table)))
    (unwind-protect
        (progn
          (cl-cc/type:register-type-alias key 'string)
          (expect type-string :to-be-type-equal-to (cl-cc/type:parse-type-specifier key)))
      (if saved
          (setf (gethash key table) saved)
          (remhash key table)))))

;;; ─── parse-type-specifier: union / intersection ──────────────────────────

(progn
  (it-sequential "parse-set-type-ops or-two"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (or fixnum string)))))
      (expect (type-union-p ty) :to-be-truthy)
      (expect (length (type-union-types ty)) :to-equal 2)))
  (it-sequential "parse-set-type-ops and-compatible"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (and fixnum integer)))))
      (expect (type-intersection-p ty) :to-be-truthy)
      (expect (length (type-intersection-types ty)) :to-equal 2)))
  (it-sequential "parse-set-type-ops or-empty-error"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (or)))))
  (it-sequential "parse-set-type-ops and-empty-error"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (and)))))
  (it-sequential "parse-set-type-ops and-uninhabited-error"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (and fixnum string))))))

;;; %primitive-types-disjoint-p only fires its subtype checks when BOTH
;;; members of a pair are type-primitive-p; when one member is a compound
;;; type (here a type-app), the AND short-circuits to nil for that pair, so
;;; the intersection is never flagged as uninhabited. A single-arg `and`
;;; also exercises the degenerate case where the inner "other members" loop
;;; is empty.
(it-sequential "parse-set-type-ops and-non-primitive-member-not-uninhabited"
  (let ((ty (cl-cc/type:parse-type-specifier (quote (and fixnum (list string))))))
    (expect (type-intersection-p ty) :to-be-truthy)
    (expect (length (type-intersection-types ty)) :to-equal 2)))

(it-sequential "parse-set-type-ops and-single-arg"
  (let ((ty (cl-cc/type:parse-type-specifier (quote (and fixnum)))))
    (expect (type-intersection-p ty) :to-be-truthy)
    (expect (length (type-intersection-types ty)) :to-equal 1)))

;;; %primitive-types-disjoint-p's two type-name-subtype-p checks short-circuit
;;; via AND: and-compatible above (fixnum integer) has type-name-subtype-p
;;; true on its first check, so the second is never even evaluated. Ordering
;;; the pair the other way round a genuinely asymmetric relation (boolean is
;;; a subtype of symbol, not vice versa) forces the first check false and the
;;; second true, reaching the branch neither prior test could.
(it-sequential "parse-set-type-ops and-compatible-asymmetric-subtype-order"
  (let ((ty (cl-cc/type:parse-type-specifier (quote (and symbol boolean)))))
    (expect (type-intersection-p ty) :to-be-truthy)
    (expect (length (type-intersection-types ty)) :to-equal 2)))

;;; ─── parse-type-specifier: function / values ──────────────────────────────

(progn
  (it-sequential "parse-function-type-cases one-param"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (-> fixnum string)))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 1)
      (expect type-string :to-be-type-equal-to (type-arrow-return ty))))
  (it-sequential "parse-function-type-cases multi-param"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (-> fixnum string boolean)))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 2)
      (expect type-bool :to-be-type-equal-to (type-arrow-return ty)))))

(progn
  (it-sequential "parse-type-specifier-wrong-arity-errors arrow-no-param-list"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (-> fixnum)))))
  (it-sequential "parse-type-specifier-wrong-arity-errors list-two-args"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (list fixnum string))))))

(it-sequential "parse-product-type-forms"
  (let ((ty (cl-cc/type:parse-type-specifier '(values fixnum string))))
    (expect (type-product-p ty) :to-be-truthy)
    (expect (length (type-product-elems ty)) :to-equal 2)))

;;; ─── parse-type-specifier: list / vector / array ─────────────────────────

(progn
  (it-sequential "parse-collection-type-apps list"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (list fixnum)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote list))
      (expect type-int :to-be-type-equal-to (type-app-arg ty))))
  (it-sequential "parse-collection-type-apps vector"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (vector fixnum)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote vector))
      (expect type-int :to-be-type-equal-to (type-app-arg ty))))
  (it-sequential "parse-collection-type-apps simple-vector"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (simple-vector fixnum)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote vector))
      (expect type-int :to-be-type-equal-to (type-app-arg ty))))
  (it-sequential "parse-collection-type-apps array"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (array string)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect type-string :to-be-type-equal-to (type-app-arg ty))))
  (it-sequential "parse-collection-type-apps simple-array"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (simple-array string)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect type-string :to-be-type-equal-to (type-app-arg ty)))))

(progn
  (it-sequential "parse-cl-numeric-range-type-specifiers unsigned-byte"
    (expect type-int :to-be-type-equal-to (cl-cc/type:parse-type-specifier (quote (unsigned-byte 64)))))
  (it-sequential "parse-cl-numeric-range-type-specifiers signed-byte"
    (expect type-int :to-be-type-equal-to (cl-cc/type:parse-type-specifier (quote (signed-byte 32)))))
  (it-sequential "parse-cl-numeric-range-type-specifiers integer-range"
    (expect type-int :to-be-type-equal-to (cl-cc/type:parse-type-specifier (quote (integer 0 *)))))
  (it-sequential "parse-cl-numeric-range-type-specifiers mod"
    (expect type-int :to-be-type-equal-to (cl-cc/type:parse-type-specifier (quote (mod 256))))))

;;; %parse-cl-integer-range-type: arity-check and bound-designator error
;;; branches for UNSIGNED-BYTE/SIGNED-BYTE/MOD/INTEGER, plus the args-nil
;;; short-circuit ((and args ...)) for the unbounded unsigned-byte case.
(progn
  (it-sequential "parse-cl-integer-range-type-errors unsigned-byte-unbounded-ok"
    (expect type-int :to-be-type-equal-to (cl-cc/type:parse-type-specifier (quote (unsigned-byte)))))
  (it-sequential "parse-cl-integer-range-type-errors unsigned-byte-too-many-bounds"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (unsigned-byte 8 16)))))
  (it-sequential "parse-cl-integer-range-type-errors unsigned-byte-non-designator-bound"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (unsigned-byte 3.5)))))
  (it-sequential "parse-cl-integer-range-type-errors signed-byte-too-many-bounds"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (signed-byte 8 16)))))
  (it-sequential "parse-cl-integer-range-type-errors mod-no-bound"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (mod)))))
  (it-sequential "parse-cl-integer-range-type-errors mod-non-designator-bound"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (mod "big")))))
  (it-sequential "parse-cl-integer-range-type-errors integer-too-many-bounds"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (integer 0 5 10)))))
  (it-sequential "parse-cl-integer-range-type-errors integer-non-designator-bound"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (integer "low" 5))))))

(progn
  (it-sequential "parse-collection-type-apps-with-dimensions vector-size"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (vector (unsigned-byte 8) 4)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote vector))
      (expect type-int :to-be-type-equal-to (type-app-arg ty))))
  (it-sequential "parse-collection-type-apps-with-dimensions array-dims"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (array (unsigned-byte 8) (*))))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect type-int :to-be-type-equal-to (type-app-arg ty))))
  (it-sequential "parse-collection-type-apps-with-dimensions simple-array"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (simple-array (unsigned-byte 8) (*))))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect type-int :to-be-type-equal-to (type-app-arg ty)))))

;;; %parse-compound-type-app's arity check for vector/array/simple-vector/
;;; simple-array is (<= 1 (length args) 2); the happy path (1 or 2 args) is
;;; covered above, these hit the false branch at both ends of the range.
(progn
  (it-sequential "parse-compound-type-app-arity-errors vector-zero-args"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (vector)))))
  (it-sequential "parse-compound-type-app-arity-errors array-three-args"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (array string (1) (2)))))))

(it-sequential "parse-ansi-function-type-specifier"
  (let ((ty (cl-cc/type:parse-type-specifier '(function (fixnum string) boolean))))
    (expect (type-arrow-p ty) :to-be-truthy)
    (expect (length (type-arrow-params ty)) :to-equal 2)
    (expect type-bool :to-be-type-equal-to (type-arrow-return ty))))

(it-sequential "parse-compound-type-app-table-covers-five-aliases"
  (let ((table cl-cc/type::*parse-compound-type-app-table*))
    (expect (length table) :to-equal 5)
    (expect (assoc 'list          table) :to-be-truthy)
    (expect (assoc 'vector        table) :to-be-truthy)
    (expect (assoc 'simple-vector table) :to-be-truthy)
    (expect (assoc 'array         table) :to-be-truthy)
    (expect (assoc 'simple-array  table) :to-be-truthy)))

(it-sequential "parse-compound-multi-arg-table-covers-or-and"
  (let ((table cl-cc/type::*parse-compound-multi-arg-table*))
    (expect (length table) :to-equal 2)
    (expect (assoc 'or  table) :to-be-truthy)
    (expect (assoc 'and table) :to-be-truthy)))

(progn
  (it-sequential "parser-graded-arrow-syntax linear-1"
    (let ((result (cl-cc/type:parse-type-specifier (quote (->1 fixnum boolean)))))
      (expect (type-arrow-p result) :to-be-truthy)
      (expect (type-arrow-mult result) :to-be :one)))
  (it-sequential "parser-graded-arrow-syntax erased-0"
    (let ((result (cl-cc/type:parse-type-specifier (quote (->0 fixnum boolean)))))
      (expect (type-arrow-p result) :to-be-truthy)
      (expect (type-arrow-mult result) :to-be :zero))))

(it-sequential "parser-forall-body-keyword"
  (let* ((result (cl-cc/type:parse-type-specifier '(forall a (-> a a)))))
    (expect (type-forall-p result) :to-be-truthy)
    (expect (type-var-name (type-forall-var result)) :to-be 'a)
    (expect (type-arrow-p (type-forall-body result)) :to-be-truthy)))

(it-sequential "parser-bounded-forall-variable"
  (let* ((result (cl-cc/type:parse-type-specifier
                  '(forall (a extends number supertype-of fixnum) a)))
         (var (type-forall-var result)))
    (expect (type-forall-p result) :to-be-truthy)
    (expect (type-var-name var) :to-be 'a)
    (expect (make-type-primitive :name 'number) :to-be-type-equal-to (cl-cc/type:type-var-upper-bound var))
    (expect type-int :to-be-type-equal-to (cl-cc/type:type-var-lower-bound var))))

(progn
  (it-sequential "parser-quantified-types exists"
    (let ((result (cl-cc/type:parse-type-specifier (quote (exists a (values string a))))))
      (expect (type-exists-p result) :to-be-truthy)
      (expect (type-var-name (type-exists-var result)) :to-be (quote a))
      (expect (type-product-p (type-exists-body result)) :to-be-truthy)))
  (it-sequential "parser-quantified-types mu"
    (let ((result (cl-cc/type:parse-type-specifier (quote (mu a (or null (values int a)))))))
      (expect (type-mu-p result) :to-be-truthy)
      (expect (type-var-name (type-mu-var result)) :to-be (quote a))
      (expect (type-union-p (type-mu-body result)) :to-be-truthy))))

(progn
  (it-sequential "parser-record closed"
    (let ((result (cl-cc/type:parse-type-specifier (quote (record (name string) (age fixnum))))))
      (expect (type-record-p result) :to-be-truthy)
      (expect (length (type-record-fields result)) :to-equal 2)
      (expect (type-record-row-var result) :to-be-null)))
  (it-sequential "parser-record open"
    (let ((result (cl-cc/type:parse-type-specifier
                   `(record (name string) ,(intern "|" :cl-cc/type) rho))))
      (expect (type-record-p result) :to-be-truthy)
      (expect (length (type-record-fields result)) :to-equal 1)
      (expect (type-record-row-var result) :to-be-truthy))))

(it-sequential "parser-variant-syntax"
  (let ((result (cl-cc/type:parse-type-specifier '(variant (some fixnum) (none null)))))
    (expect (type-variant-p result) :to-be-truthy)
    (expect (length (type-variant-cases result)) :to-equal 2)
    (expect (type-variant-row-var result) :to-be-null)))

(progn
  (it-sequential "parser-linear-modal-syntax linear-1"
    (let ((result (cl-cc/type:parse-type-specifier (quote (!1 fixnum)))))
      (expect (type-linear-p result) :to-be-truthy)
      (expect (type-linear-grade result) :to-be :one)))
  (it-sequential "parser-linear-modal-syntax omega"
    (let ((result (cl-cc/type:parse-type-specifier (quote (!ω string)))))
      (expect (type-linear-p result) :to-be-truthy)
      (expect (type-linear-grade result) :to-be :omega)))
  (it-sequential "parser-linear-modal-syntax erased-0"
    (let ((result (cl-cc/type:parse-type-specifier (quote (!0 boolean)))))
      (expect (type-linear-p result) :to-be-truthy)
      (expect (type-linear-grade result) :to-be :zero))))

(progn
  (it-sequential "parser-refinement-syntax lambda-pred"
    (let ((result (cl-cc/type:parse-type-specifier (quote (refine fixnum (lambda (x) (> x 0)))))))
      (expect (type-refinement-p result) :to-be-truthy)
      (expect type-int :to-be-type-equal-to (type-refinement-base result))
      (expect (type-refinement-predicate result) :to-be-truthy)))
  (it-sequential "parser-refinement-syntax symbol-pred"
    (let ((result (cl-cc/type:parse-type-specifier (quote (refine fixnum positive-p)))))
      (expect (type-refinement-p result) :to-be-truthy)
      (expect type-int :to-be-type-equal-to (type-refinement-base result))
      (expect (eq (quote positive-p)
                  (cl-cc/type:type-refinement-predicate result)) :to-be-falsy))))

;;; ─── Simple compound forms: malformed-arity / malformed-argument errors ──
;;; option/has-slots/protocol/refine/function are dispatched through
;;; parser-extended.lisp's *simple-compound-form-table* by symbol-name string
;;; comparison (package-independent). "option" is also special-cased by eql
;;; in parser.lisp's own parse-compound-type, so a plain 'option symbol (which
;;; the cl-cc-type/test package inherits via :use of cl-cc/type) never reaches
;;; %parse-option-form at all — the :option keyword below has the same
;;; symbol-name "OPTION" but isn't eql to cl-cc/type::option, so it correctly
;;; falls through to the string-based extended dispatcher.

(it-sequential "parse-option-wrong-arity-errors"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier (list :option 'fixnum 'string))))

(it-sequential "parse-has-slots-no-args-errors"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier '(has-slots))))

(progn
  (it-sequential "parse-protocol-malformed-forms wrong-arity"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(protocol))))
  (it-sequential "parse-protocol-malformed-forms non-symbol-name"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(protocol 42)))))

(progn
  (it-sequential "parse-ansi-function-type-malformed-forms wrong-arity"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(function (fixnum)))))
  (it-sequential "parse-ansi-function-type-malformed-forms non-list-params"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(function fixnum boolean)))))

;;; ─── parse-compound-type-extended: non-symbol head fallthrough ──────────
;;; When head isn't a symbol at all, every hn-gated cond clause in
;;; parse-compound-type-extended is skipped, falling all the way through to
;;; the final "Unrecognised compound type" error.

(it-sequential "parse-non-symbol-compound-head-errors"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier '(42 fixnum))))

;;; ─── Advanced feature form: malformed-input error paths ──────────────────
;;; %parse-advanced-feature-form/%parse-advanced-items cover the general
;;; "(advanced FR-xxxx ...)" surface syntax: a missing feature id, an
;;; unregistered feature id, and malformed trailing :evidence/keyword-property
;;; items with no value after them.

(progn
  (it-sequential "parse-advanced-feature-form-malformed no-feature-id"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(advanced))))
  (it-sequential "parse-advanced-feature-form-malformed unknown-feature-id"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(advanced fr-9999-nonexistent foo))))
  (it-sequential "parse-advanced-feature-form-malformed evidence-missing-value"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(advanced fr-1901 recursive-length :evidence))))
  (it-sequential "parse-advanced-feature-form-malformed property-missing-value"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(advanced fr-1901 recursive-length :stage)))))

;;; ─── Advanced feature form / value: internal-function direct calls ───────
;;; Two branches are unreachable through the public parse-type-specifier
;;; dispatch and are only exercisable by calling the internal functions
;;; directly:
;;;  - %parse-advanced-feature-form's "unknown surface head" error only
;;;    triggers for a HEAD that is neither "ADVANCED" nor a registered
;;;    representative head — but parse-compound-type-extended only ever
;;;    calls this function when type-advanced-head-p already confirmed one
;;;    of those two conditions, so the branch is dead from the public API.
;;;  - %parse-advanced-value's leading (typep value 'type-node) passthrough
;;;    branch never fires from parsed input, since raw reader s-expressions
;;;    are never already-constructed type-node instances.

(it-sequential "parse-advanced-feature-form-direct-call-unregistered-head-errors"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type::%parse-advanced-feature-form 'not-a-registered-advanced-head nil)))

(it-sequential "parse-advanced-feature-form-direct-call-non-symbol-head-errors"
  ;; HEAD-NAME's own (SYMBOLP head) guard had only ever seen a symbol
  ;; head (whether registered or not, per the case above) through this
  ;; internal function's one caller in the public dispatch.
  (signals cl-cc/type:type-parse-error
    (cl-cc/type::%parse-advanced-feature-form 42 nil)))

(it-sequential "parse-advanced-value-direct-call-type-node-passthrough"
  (expect (cl-cc/type::%parse-advanced-value type-int) :to-be type-int))

(it-sequential "advanced-type-form-head-p-direct-call-rejects-a-non-symbol-head"
  ;; %ADVANCED-TYPE-FORM-HEAD-P's every conjunct that starts with (AND
  ;; (SYMBOLP head) ...) or computes HN via (AND (SYMBOLP head) ...) had
  ;; only ever been called with a symbol HEAD (via %PARSE-ADVANCED-VALUE
  ;; recursing on the CAR of a nested list, which in every prior test is
  ;; itself a symbol). A non-symbol head -- reachable whenever an
  ;; advanced payload contains a nested list of non-symbol atoms --
  ;; makes SYMBOLP false throughout.
  (expect (cl-cc/type::%advanced-type-form-head-p 1) :to-be-falsy))

(it-sequential "parser-head-name-member-p-direct-call-rejects-a-non-symbol-head"
  ;; %PARSER-HEAD-NAME-MEMBER-P's (AND (SYMBOLP head) ...) guard: every
  ;; caller reachable through the public parser always passes a symbol
  ;; head (or nil, from a malformed but still-consp form), so a non-
  ;; symbol atom head had never made SYMBOLP itself false.
  (expect (cl-cc/type::%parser-head-name-member-p
           42 cl-cc/type::*parse-compound-multi-arg-table*)
          :to-be-falsy))

