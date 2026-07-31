;;;; t/parser-arrow-quantifier-test.lisp — Arrow & Quantifier Parser Tests
;;;;
;;;; Tests for src/parser.lisp: arrow multiplicity (->1/->0), bang effects,
;;;; forall/exists/mu quantifiers, type-lambda, qualified types (=>), and graded modal (!1/!0/!W).
;;;; Suite: parser-suite (defined in parser-test.lisp).

(in-package :cl-cc-type/test)

;;; ─── Arrow types: ->, ->1, ->0 ──────────────────────────────────────────

(progn
  (it-sequential "parse-arrow-basic-cases pure"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "->" :cl-cc/type) fixnum string))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 1)
      (expect (type-effect-row-p (type-arrow-effects ty)) :to-be-truthy)))
  (it-sequential "parse-arrow-basic-cases multi-param"
    (let ((ty (cl-cc/type:parse-type-specifier
               `(,(intern "->" :cl-cc/type) fixnum string boolean))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 2)))
  (it-sequential "parse-arrow-basic-cases compound-param-is-not-a-symbol"
    ;; PARSE-ARROW-TYPE's bang/slash scan, (POSITION-IF (LAMBDA (x) (AND
    ;; (SYMBOLP x) ...)) ARGS), had only ever scanned bare symbol params
    ;; (FIXNUM/STRING/BOOLEAN above); a compound param spec like (VECTOR
    ;; FIXNUM) is a list, not a symbol, so SYMBOLP itself is false for
    ;; that element mid-scan -- distinct from it being true but not "!".
    (let ((ty (cl-cc/type:parse-type-specifier
               `(,(intern "->" :cl-cc/type) (vector fixnum) string))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 1))))

(progn
  (it-sequential "parse-arrow-multiplicity linear"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "->1" :cl-cc/type) fixnum string))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-arrow-mult ty) :to-be :one)))
  (it-sequential "parse-arrow-multiplicity erased"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "->0" :cl-cc/type) fixnum string))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-arrow-mult ty) :to-be :zero))))

(progn
  (it-sequential "parse-type-specifier-malformed-errors arrow-too-few"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier `(,(intern "->" :cl-cc/type) fixnum))))
  (it-sequential "parse-type-specifier-malformed-errors refinement-no-pred"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (refine fixnum)))))
  (it-sequential "parse-type-specifier-malformed-errors record-field-no-type"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (record (x)))))))

(it-sequential "parse-arrow-with-bang-effects"
  (let ((ty (cl-cc/type:parse-type-specifier
             `(,(intern "->" :cl-cc/type) fixnum string ,(intern "!" :cl-cc/type) io))))
    (expect (type-arrow-p ty) :to-be-truthy)
    (let ((eff (type-arrow-effects ty)))
      (expect (type-effect-row-p eff) :to-be-truthy)
      (expect (> (length (type-effect-row-effects eff)) 0) :to-be-truthy))))

;;; ─── Quantifiers: forall, exists, mu ─────────────────────────────────────

(progn
  (it-sequential "parse-quantifier-binding-types forall"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (forall a fixnum)))))
      (expect (type-forall-p ty) :to-be-truthy)
      (expect (type-var-p (type-forall-var ty)) :to-be-truthy)
      (expect type-int :to-be-type-equal-to (cl-cc/type:type-forall-body ty))))
  (it-sequential "parse-quantifier-binding-types exists"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (exists a fixnum)))))
      (expect (type-exists-p ty) :to-be-truthy)
      (expect (type-var-p (cl-cc/type:type-exists-var ty)) :to-be-truthy)))
  (it-sequential "parse-quantifier-binding-types mu"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (mu a fixnum)))))
      (expect (type-mu-p ty) :to-be-truthy)
      (expect (type-var-p (cl-cc/type:type-mu-var ty)) :to-be-truthy))))

(progn
  (it-sequential "parse-quantifier-arity-errors forall"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (forall a)))))
  (it-sequential "parse-quantifier-arity-errors exists"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (exists a)))))
  (it-sequential "parse-quantifier-arity-errors mu"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier (quote (mu a))))))

(it-sequential "parse-type-lambda"
  (let ((ty (cl-cc/type:parse-type-specifier '(type-lambda a fixnum))))
    (expect (type-lambda-p ty) :to-be-truthy)
    (expect (type-var-p (type-lambda-var ty)) :to-be-truthy)
    (expect type-int :to-be-type-equal-to (type-lambda-body ty))))

;;; ─── Bounded quantifier variable: malformed bound specs ──────────────────
;;; %parse-bounded-quantifier-var has three error paths: a non-symbol bound
;;; operator (kind resolves to nil), a recognised operator with no trailing
;;; bound value, and a quantifier variable spec that is neither a symbol nor
;;; a (name . bounds) cons.

(progn
  (it-sequential "parse-bounded-quantifier-malformed-bounds invalid-operator"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(forall (a 42 number) a))))
  (it-sequential "parse-bounded-quantifier-malformed-bounds unrecognized-operator-symbol"
    ;; Distinct from the non-symbol case above: 42 never reaches
    ;; %BOUND-OPERATOR-KIND's own COND at all (its outer (WHEN (SYMBOLP op)
    ;; ...) guard short-circuits first). FOO is a genuine symbol that
    ;; matches neither the upper- nor lower-bound operator name lists, so
    ;; it reaches -- and falls through -- both MEMBER checks to (T NIL).
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(forall (a foo number) a))))
  (it-sequential "parse-bounded-quantifier-malformed-bounds missing-bound-value"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(forall (a subtype-of) a))))
  (it-sequential "parse-bounded-quantifier-malformed-bounds non-symbol-spec"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type:parse-type-specifier '(forall 42 a)))))

;;; ─── Qualified types: => ─────────────────────────────────────────────────

(progn
  (it-sequential "parse-qualified-type-cases valid"
    (let* ((form `(,(intern "=>" :cl-cc/type) (num fixnum) string))
           (ty (cl-cc/type:parse-type-specifier form)))
      (expect (type-qualified-p ty) :to-be-truthy)
      (expect (length (type-qualified-constraints ty)) :to-equal 1)
      (expect type-string :to-be-type-equal-to (cl-cc/type:type-qualified-body ty))))
  (it-sequential "parse-qualified-type-cases no-body"
    (let ((form `(,(intern "=>" :cl-cc/type))))
      (signals cl-cc/type:type-parse-error
        (cl-cc/type:parse-type-specifier form)))))

;;; ─── Graded modal types ─────────────────────────────────────────────────

(progn
  (it-sequential "parse-graded-modal-types one"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "!1" :cl-cc/type) fixnum))))
      (expect (type-linear-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-linear-grade ty) :to-be :one)))
  (it-sequential "parse-graded-modal-types zero"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "!0" :cl-cc/type) fixnum))))
      (expect (type-linear-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-linear-grade ty) :to-be :zero)))
  (it-sequential "parse-graded-modal-types omega"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "!W" :cl-cc/type) fixnum))))
      (expect (type-linear-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-linear-grade ty) :to-be :omega)))
  (it-sequential "parse-graded-modal-types explicit"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "!" :cl-cc/type) 1 fixnum))))
      (expect (type-linear-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-linear-grade ty) :to-be :one))))

(progn
  (it-sequential "parse-graded-modal-types explicit-zero"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "!" :cl-cc/type) 0 fixnum))))
      (expect (type-linear-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-linear-grade ty) :to-be :zero)))
  (it-sequential "parse-graded-modal-types explicit-unrecognized-defaults-omega"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "!" :cl-cc/type) whatever fixnum))))
      (expect (type-linear-p ty) :to-be-truthy)
      (expect (cl-cc/type:type-linear-grade ty) :to-be :omega))))

;;; ─── Arrow effect annotations: (/ ...) form and row-var pipe syntax ───────
;;; parse-arrow-type also recognizes a "/" separator (as an alternative to
;;; "!") ahead of the effect specs, and parse-effect-row-spec/
;;; %parse-effect-names-and-row-var support an open row-var after "|" in
;;; both the flat-list and single-form (angle-bracket) effect spec shapes.

(it-sequential "parse-arrow-slash-effect-annotation"
  (let ((ty (cl-cc/type:parse-type-specifier
             `(,(intern "->" :cl-cc/type) fixnum string ,(intern "/" :cl-cc/type) io))))
    (expect (type-arrow-p ty) :to-be-truthy)
    (let ((eff (type-arrow-effects ty)))
      (expect (type-effect-row-p eff) :to-be-truthy)
      (expect (> (length (type-effect-row-effects eff)) 0) :to-be-truthy))))

(progn
  (it-sequential "parse-arrow-effect-row-with-row-var flat-list"
    (let* ((ty (cl-cc/type:parse-type-specifier
                `(,(intern "->" :cl-cc/type) fixnum string
                  ,(intern "!" :cl-cc/type) io state ,(intern "|" :cl-cc/type) rho)))
           (eff (type-arrow-effects ty)))
      (expect (type-effect-row-p eff) :to-be-truthy)
      (expect (length (type-effect-row-effects eff)) :to-equal 2)
      (expect (cl-cc/type:type-effect-row-row-var eff) :to-be-truthy)))
  (it-sequential "parse-arrow-effect-row-with-row-var angle-bracket-form"
    (let* ((ty (cl-cc/type:parse-type-specifier
                `(,(intern "->" :cl-cc/type) fixnum string
                  ,(intern "!" :cl-cc/type) (io state ,(intern "|" :cl-cc/type) rho))))
           (eff (type-arrow-effects ty)))
      (expect (type-effect-row-p eff) :to-be-truthy)
      (expect (length (type-effect-row-effects eff)) :to-equal 2)
      (expect (cl-cc/type:type-effect-row-row-var eff) :to-be-truthy))))

(it-sequential "parse-arrow-effect-row-with-a-non-symbol-effect-element-signals"
  ;; %PARSE-EFFECT-NAMES-AND-ROW-VAR's pipe scan, (POSITION-IF (LAMBDA
  ;; (x) (AND (SYMBOLP x) ...)) ELTS), had only ever scanned all-symbol
  ;; effect lists above (io/state/rho), so SYMBOLP's own false outcome
  ;; had never been observed during the scan. A non-symbol effect
  ;; element makes it false there, but -- since every scanned element
  ;; before the pipe also becomes a TYPE-EFFECT-OP :NAME, and that slot
  ;; is declared :TYPE SYMBOL -- it still can't reach a successful
  ;; parse; MAKE-TYPE-EFFECT-OP itself signals once construction is
  ;; attempted.
  (signals error
      (cl-cc/type:parse-type-specifier
       `(,(intern "->" :cl-cc/type) fixnum string
         ,(intern "!" :cl-cc/type) 42 io))))
