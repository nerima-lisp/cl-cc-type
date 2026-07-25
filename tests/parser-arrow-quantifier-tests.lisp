;;;; tests/unit/type/parser-arrow-quantifier-tests.lisp — Arrow & Quantifier Parser Tests
;;;;
;;;; Tests for src/type/parser.lisp: arrow multiplicity (->1/->0), bang effects,
;;;; forall/exists/mu quantifiers, type-lambda, qualified types (=>), and graded modal (!1/!0/!W).
;;;; Suite: parser-suite (defined in parser-tests.lisp).

(in-package :cl-cc-type/test)

;;; ─── Arrow types: ->, ->1, ->0 ──────────────────────────────────────────

(progn
  (it-sequential "parse-arrow-basic-cases pure"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "->" :cl-cc/type) fixnum string))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 1)
      (expect (type-effect-row-p (type-arrow-effects ty)) :to-be-truthy)))
  (it-sequential "parse-arrow-basic-cases multi-param"
    (let ((ty (cl-cc/type:parse-type-specifier `(,(intern "->" :cl-cc/type) fixnum string boolean))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 2))))

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
      (expect (type-equal-p type-int (cl-cc/type:type-forall-body ty)) :to-be-truthy)))
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
    (expect (type-equal-p type-int (type-lambda-body ty)) :to-be-truthy)))

;;; ─── Qualified types: => ─────────────────────────────────────────────────

(progn
  (it-sequential "parse-qualified-type-cases valid"
    (let* ((form `(,(intern "=>" :cl-cc/type) (num fixnum) string))
           (ty (cl-cc/type:parse-type-specifier form)))
      (expect (type-qualified-p ty) :to-be-truthy)
      (expect (length (type-qualified-constraints ty)) :to-equal 1)
      (expect (type-equal-p type-string (cl-cc/type:type-qualified-body ty)) :to-be-truthy)))
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
