;;;; tests/unit/type/parser-typed-tests.lisp — Type Parser Tests (Row / Typed Parameters)
;;;;
;;;; Continuation of parser-tests.lisp:
;;;; Row types (record/variant), type-app fallback, constraint spec parsing,
;;;; lambda-list parsing, typed parameters, typed AST nodes,
;;;; looks-like-type-specifier-p.

(in-package :cl-cc-type/test)

;;; ─── Row types: Record / Variant ─────────────────────────────────────────

(it-sequential "parse-record-closed"
  (let ((ty (cl-cc/type:parse-type-specifier '(record (x fixnum) (y string)))))
    (expect (type-record-p ty) :to-be-truthy)
    (expect (length (type-record-fields ty)) :to-equal 2)
    (expect (cl-cc/type:type-record-row-var ty) :to-be-null)))

(it-sequential "parse-record-open"
  (let ((ty (cl-cc/type:parse-type-specifier
             `(record (x fixnum) ,(intern "|" :cl-cc/type) rho))))
    (expect (type-record-p ty) :to-be-truthy)
    (expect (length (type-record-fields ty)) :to-equal 1)
    (expect (not (null (cl-cc/type:type-record-row-var ty))) :to-be-truthy)))

(it-sequential "parse-variant-form"
  (let ((ty (cl-cc/type:parse-type-specifier '(variant (some fixnum) (none null)))))
    (expect (type-variant-p ty) :to-be-truthy)
    (expect (length (cl-cc/type:type-variant-cases ty)) :to-equal 2)))

;;; ─── Type application fallback ───────────────────────────────────────────

(progn
  (it-sequential "parse-type-app-cases single-arg"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (maybe fixnum)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-p (cl-cc/type:type-app-fun ty)) :to-be-truthy)))
  (it-sequential "parse-type-app-cases multi-arg"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (f a b)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-app-p (cl-cc/type:type-app-fun ty)) :to-be-truthy))))

;;; ─── Constraint spec parsing ─────────────────────────────────────────────

(progn
  (it-sequential "parse-constraint-spec-cases basic"
    (let ((c (cl-cc/type::parse-constraint-spec (quote (num fixnum)))))
      (expect (cl-cc/type:type-constraint-p c) :to-be-truthy)
      (expect (cl-cc/type:type-constraint-class-name c) :to-be (quote num))))
  (it-sequential "parse-constraint-spec-cases error"
    (signals cl-cc/type:type-parse-error
      (cl-cc/type::parse-constraint-spec (quote num)))))

;;; ─── Lambda list parsing ─────────────────────────────────────────────────

(it-sequential "parse-lambda-list-typed"
  (multiple-value-bind (names types)
      (cl-cc/type:parse-lambda-list-with-types '((x fixnum) (y string)))
    (expect names :to-equal '(x y))
    (expect (length types) :to-equal 2)
    (expect (type-equal-p type-int (first types)) :to-be-truthy)
    (expect (type-equal-p type-string (second types)) :to-be-truthy)))

(it-sequential "parse-lambda-list-untyped"
  (multiple-value-bind (names types)
      (cl-cc/type:parse-lambda-list-with-types '(x y))
    (expect names :to-equal '(x y))
    (expect (type-equal-p type-any (first types)) :to-be-truthy)
    (expect (type-equal-p type-any (second types)) :to-be-truthy)))

(it-sequential "parse-lambda-list-mixed"
  (multiple-value-bind (names types)
      (cl-cc/type:parse-lambda-list-with-types '((x fixnum) y))
    (expect names :to-equal '(x y))
    (expect (type-equal-p type-int (first types)) :to-be-truthy)
    (expect (type-equal-p type-any (second types)) :to-be-truthy)))

(it-sequential "parse-lambda-list-empty"
  (multiple-value-bind (names types)
      (cl-cc/type:parse-lambda-list-with-types nil)
    (expect names :to-be-null)
    (expect types :to-be-null)))

(it-sequential "parse-lambda-list-error"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-lambda-list-with-types '(42))))

;;; ─── parse-typed-parameter ───────────────────────────────────────────────

(progn
  (it-sequential "parse-typed-parameter-cases typed"
    (let ((result (cl-cc/type:parse-typed-parameter (quote (x fixnum)))))
      (expect (car result) :to-be (quote x))
      (expect (type-equal-p type-int (cdr result)) :to-be-truthy)))
  (it-sequential "parse-typed-parameter-cases bare"
    (let ((result (cl-cc/type:parse-typed-parameter (quote x))))
      (expect (car result) :to-be (quote x))
      (expect (type-equal-p type-any (cdr result)) :to-be-truthy))))

;;; ─── parse-typed-optional-parameter ──────────────────────────────────────

(progn
  (it-sequential "parse-optional-parameter-cases typed"
    (let ((result (cl-cc/type:parse-typed-optional-parameter (quote (x fixnum nil)))))
      (expect (car result) :to-be (quote x))
      (expect (type-equal-p type-int (cdr result)) :to-be-truthy)))
  (it-sequential "parse-optional-parameter-cases bare"
    (let ((result (cl-cc/type:parse-typed-optional-parameter (quote x))))
      (expect (car result) :to-be (quote x))
      (expect (type-equal-p type-any (cdr result)) :to-be-truthy))))

;;; ─── extract-return-type ─────────────────────────────────────────────────

(progn
  (it-sequential "extract-return-type-cases with-declare"
    (expect (type-equal-p type-int (cl-cc/type:extract-return-type (quote ((declare (return-type fixnum)) (+ x 1))))) :to-be-truthy))
  (it-sequential "extract-return-type-cases no-declare"
    (expect (cl-cc/type:extract-return-type (quote ((+ x 1)))) :to-be-null))
  (it-sequential "extract-return-type-cases nil-body"
    (expect (cl-cc/type:extract-return-type nil) :to-be-null)))

;;; ─── Typed AST nodes ─────────────────────────────────────────────────────

(it-sequential "parse-typed-defun-basic"
  (let ((node (cl-cc/type:parse-typed-defun '(defun foo ((x fixnum)) (+ x 1)))))
    (expect (cl-cc/type::ast-defun-typed-p node) :to-be-truthy)
    (expect (cl-cc/type:ast-defun-typed-name node) :to-be 'foo)
    (expect (cl-cc/type:ast-defun-typed-params node) :to-equal '(x))
    (expect (length (cl-cc/type:ast-defun-typed-param-types node)) :to-equal 1)
    (expect (type-equal-p type-int (first (cl-cc/type:ast-defun-typed-param-types node))) :to-be-truthy)))

(it-sequential "parse-typed-lambda-basic"
  (let ((node (cl-cc/type:parse-typed-lambda '(lambda ((x fixnum)) (+ x 1)))))
    (expect (cl-cc/type::ast-lambda-typed-p node) :to-be-truthy)
    (expect (cl-cc/type:ast-lambda-typed-params node) :to-equal '(x))
    (expect (length (cl-cc/type:ast-lambda-typed-param-types node)) :to-equal 1)))

;;; ─── looks-like-type-specifier-p ─────────────────────────────────────────

(progn
  (it-sequential "looks-like-type-specifier-p-cases fixnum"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote fixnum)) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases string"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote string)) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases boolean"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote boolean)) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases question-mark"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote ?)) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases or-composite"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote (or fixnum string))) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases function-type"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote (-> fixnum string))) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases values-type"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote (values fixnum string))) :to-be-truthy))
  (it-sequential "looks-like-type-specifier-p-cases unknown-symbol"
    (expect (cl-cc/type:looks-like-type-specifier-p (quote my-random-thing)) :to-be-falsy)))

;;; ─── parse-type-specifier-maybe ──────────────────────────────────────────

(progn
  (it-sequential "parse-type-specifier-maybe-cases known"
    (expect (type-equal-p type-int (cl-cc/type::parse-type-specifier-maybe (quote fixnum))) :to-be-truthy))
  (it-sequential "parse-type-specifier-maybe-cases unknown"
    (expect (cl-cc/type::parse-type-specifier-maybe (quote my-random-thing)) :to-be-null)))

;;; ─── make-type-arrow ─────────────────────────────────────────────────────

(it-sequential "make-type-arrow-basic"
  (let ((ty (cl-cc/type:make-type-arrow (list type-int) type-string)))
    (expect (type-arrow-p ty) :to-be-truthy)
    (expect (length (type-arrow-params ty)) :to-equal 1)
    (expect (type-equal-p type-string (type-arrow-return ty)) :to-be-truthy)))

;;; ─── Error on non-s-expression ───────────────────────────────────────────

(it-sequential "parse-invalid-atom"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier 42)))
