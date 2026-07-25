;;;; tests/unit/type/parser-tests.lisp — Type Parser Tests (primitive/compound/structural)
;;;;
;;;; Tests for src/type/parser.lisp:
;;;; parse-type-specifier, parse-primitive-type, parse-compound-type,
;;;; typed AST nodes, looks-like-type-specifier-p.
;;;; Arrow/quantifier/modal tests → parser-arrow-quantifier-tests.lisp.

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

(progn
  (it-sequential "parse-primitive-symbols nil"
    (expect (type-equal-p type-null (cl-cc/type:parse-type-specifier nil)) :to-be-truthy))
  (it-sequential "parse-primitive-symbols fixnum"
    (expect (type-equal-p type-int (cl-cc/type:parse-type-specifier (quote fixnum))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols integer"
    (expect (type-equal-p type-int (cl-cc/type:parse-type-specifier (quote integer))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols string"
    (expect (type-equal-p type-string (cl-cc/type:parse-type-specifier (quote string))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols boolean"
    (expect (type-equal-p type-bool (cl-cc/type:parse-type-specifier (quote boolean))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols bool"
    (expect (type-equal-p type-bool (cl-cc/type:parse-type-specifier (quote bool))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols symbol"
    (expect (type-equal-p type-symbol (cl-cc/type:parse-type-specifier (quote symbol))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols character"
    (expect (type-equal-p type-char (cl-cc/type:parse-type-specifier (quote character))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols char"
    (expect (type-equal-p type-char (cl-cc/type:parse-type-specifier (quote char))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols t"
    (expect (type-equal-p type-any (cl-cc/type:parse-type-specifier t)) :to-be-truthy))
  (it-sequential "parse-primitive-symbols top"
    (expect (type-equal-p type-any (cl-cc/type:parse-type-specifier (quote top))) :to-be-truthy))
  (it-sequential "parse-primitive-symbols cons"
    (expect (type-equal-p type-cons (cl-cc/type:parse-type-specifier (quote cons))) :to-be-truthy)))

(it-sequential "parse-unknown-symbol"
  (let ((ty (cl-cc/type:parse-type-specifier 'my-custom-type)))
    (expect (type-primitive-p ty) :to-be-truthy)
    (expect (type-primitive-name ty) :to-be 'my-custom-type)))

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

;;; ─── parse-type-specifier: function / values ──────────────────────────────

(progn
  (it-sequential "parse-function-type-cases one-param"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (-> fixnum string)))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 1)
      (expect (type-equal-p type-string (type-arrow-return ty)) :to-be-truthy)))
  (it-sequential "parse-function-type-cases multi-param"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (-> fixnum string boolean)))))
      (expect (type-arrow-p ty) :to-be-truthy)
      (expect (length (type-arrow-params ty)) :to-equal 2)
      (expect (type-equal-p type-bool (type-arrow-return ty)) :to-be-truthy))))

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
      (expect (type-equal-p type-int (type-app-arg ty)) :to-be-truthy)))
  (it-sequential "parse-collection-type-apps vector"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (vector fixnum)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote vector))
      (expect (type-equal-p type-int (type-app-arg ty)) :to-be-truthy)))
  (it-sequential "parse-collection-type-apps simple-vector"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (simple-vector fixnum)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote vector))
      (expect (type-equal-p type-int (type-app-arg ty)) :to-be-truthy)))
  (it-sequential "parse-collection-type-apps array"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (array string)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect (type-equal-p type-string (type-app-arg ty)) :to-be-truthy)))
  (it-sequential "parse-collection-type-apps simple-array"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (simple-array string)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect (type-equal-p type-string (type-app-arg ty)) :to-be-truthy))))

(progn
  (it-sequential "parse-cl-numeric-range-type-specifiers unsigned-byte"
    (expect (type-equal-p type-int (cl-cc/type:parse-type-specifier (quote (unsigned-byte 64)))) :to-be-truthy))
  (it-sequential "parse-cl-numeric-range-type-specifiers signed-byte"
    (expect (type-equal-p type-int (cl-cc/type:parse-type-specifier (quote (signed-byte 32)))) :to-be-truthy))
  (it-sequential "parse-cl-numeric-range-type-specifiers integer-range"
    (expect (type-equal-p type-int (cl-cc/type:parse-type-specifier (quote (integer 0 *)))) :to-be-truthy))
  (it-sequential "parse-cl-numeric-range-type-specifiers mod"
    (expect (type-equal-p type-int (cl-cc/type:parse-type-specifier (quote (mod 256)))) :to-be-truthy)))

(progn
  (it-sequential "parse-collection-type-apps-with-dimensions vector-size"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (vector (unsigned-byte 8) 4)))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote vector))
      (expect (type-equal-p type-int (type-app-arg ty)) :to-be-truthy)))
  (it-sequential "parse-collection-type-apps-with-dimensions array-dims"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (array (unsigned-byte 8) (*))))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect (type-equal-p type-int (type-app-arg ty)) :to-be-truthy)))
  (it-sequential "parse-collection-type-apps-with-dimensions simple-array"
    (let ((ty (cl-cc/type:parse-type-specifier (quote (simple-array (unsigned-byte 8) (*))))))
      (expect (type-app-p ty) :to-be-truthy)
      (expect (type-primitive-name (type-app-fun ty)) :to-be (quote array))
      (expect (type-equal-p type-int (type-app-arg ty)) :to-be-truthy))))

(it-sequential "parse-ansi-function-type-specifier"
  (let ((ty (cl-cc/type:parse-type-specifier '(function (fixnum string) boolean))))
    (expect (type-arrow-p ty) :to-be-truthy)
    (expect (length (type-arrow-params ty)) :to-equal 2)
    (expect (type-equal-p type-bool (type-arrow-return ty)) :to-be-truthy)))

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
    (expect (type-equal-p (make-type-primitive :name 'number)
                          (cl-cc/type:type-var-upper-bound var)) :to-be-truthy)
    (expect (type-equal-p type-int (cl-cc/type:type-var-lower-bound var)) :to-be-truthy)))

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
      (expect (type-equal-p type-int (type-refinement-base result)) :to-be-truthy)
      (expect (type-refinement-predicate result) :to-be-truthy)))
  (it-sequential "parser-refinement-syntax symbol-pred"
    (let ((result (cl-cc/type:parse-type-specifier (quote (refine fixnum positive-p)))))
      (expect (type-refinement-p result) :to-be-truthy)
      (expect (type-equal-p type-int (type-refinement-base result)) :to-be-truthy)
      (expect (eq (quote positive-p)
                  (cl-cc/type:type-refinement-predicate result)) :to-be-falsy))))
