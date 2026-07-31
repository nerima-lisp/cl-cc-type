;;;; t/parser-typed-test.lisp — Type Parser Tests (Row / Typed Parameters)
;;;;
;;;; Continuation of parser-test.lisp:
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

(it-sequential "parse-row-type-rejects-a-malformed-field-spec"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier '(record (x)))))

(it-sequential "parse-row-type-rejects-a-field-spec-that-is-not-a-list-at-all"
  ;; The case above has (CONSP F) true but (= (LENGTH F) 2) false (a
  ;; 1-element list); PARSE-ROW-TYPE's field-validity check's own (CONSP
  ;; F) conjunct had never been observed false -- a bare atom field spec
  ;; isn't even a list.
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier '(record x))))

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
    (expect type-int :to-be-type-equal-to (first types))
    (expect type-string :to-be-type-equal-to (second types))))

(it-sequential "parse-lambda-list-untyped"
  (multiple-value-bind (names types)
      (cl-cc/type:parse-lambda-list-with-types '(x y))
    (expect names :to-equal '(x y))
    (expect type-any :to-be-type-equal-to (first types))
    (expect type-any :to-be-type-equal-to (second types))))

(it-sequential "parse-lambda-list-mixed"
  (multiple-value-bind (names types)
      (cl-cc/type:parse-lambda-list-with-types '((x fixnum) y))
    (expect names :to-equal '(x y))
    (expect type-int :to-be-type-equal-to (first types))
    (expect type-any :to-be-type-equal-to (second types))))

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
      (expect type-int :to-be-type-equal-to (cdr result))))
  (it-sequential "parse-typed-parameter-cases bare"
    (let ((result (cl-cc/type:parse-typed-parameter (quote x))))
      (expect (car result) :to-be (quote x))
      (expect type-any :to-be-type-equal-to (cdr result)))))

;;; ─── parse-typed-optional-parameter ──────────────────────────────────────

(progn
  (it-sequential "parse-optional-parameter-cases typed"
    (let ((result (cl-cc/type:parse-typed-optional-parameter (quote (x fixnum nil)))))
      (expect (car result) :to-be (quote x))
      (expect type-int :to-be-type-equal-to (cdr result))))
  (it-sequential "parse-optional-parameter-cases bare"
    (let ((result (cl-cc/type:parse-typed-optional-parameter (quote x))))
      (expect (car result) :to-be (quote x))
      (expect type-any :to-be-type-equal-to (cdr result))))
  (it-sequential "parse-optional-parameter-cases single-element-list-defaults-to-any"
    ;; Distinct from both prior cases: a CONSP item (so it does not take
    ;; the outer ELSE branch) whose length is under 2 (so the inner
    ;; (>= (length item) 2) check -- previously always true -- is false).
    (let ((result (cl-cc/type:parse-typed-optional-parameter (quote (x)))))
      (expect (car result) :to-be (quote x))
      (expect type-any :to-be-type-equal-to (cdr result)))))

;;; ─── extract-return-type ─────────────────────────────────────────────────

(progn
  (it-sequential "extract-return-type-cases with-declare"
    (expect type-int :to-be-type-equal-to (cl-cc/type:extract-return-type
                           (quote ((declare (return-type fixnum)) (+ x 1))))))
  (it-sequential "extract-return-type-cases no-declare"
    (expect (cl-cc/type:extract-return-type (quote ((+ x 1)))) :to-be-null))
  (it-sequential "extract-return-type-cases nil-body"
    (expect (cl-cc/type:extract-return-type nil) :to-be-null))
  (it-sequential "extract-return-type-cases declare-present-but-not-return-type"
    ;; Distinct from "no-declare": BODY does start with a (DECLARE ...)
    ;; form, so the outer WHEN is true, but its content isn't a
    ;; (RETURN-TYPE ...) clause, so the inner WHEN's final STRING=
    ;; comparison -- previously only ever seen true -- is false here.
    (expect (cl-cc/type:extract-return-type
             (quote ((declare (ignore x)) (+ x 1))))
            :to-be-null))
  (it-sequential "extract-return-type-cases empty-declare"
    ;; An empty (DECLARE) makes DECL itself NIL, the AND's own first
    ;; conjunct false -- distinct from "declare-present-but-not-return-
    ;; type" above, where DECL is non-NIL but its car isn't a RETURN-TYPE
    ;; clause.
    (expect (cl-cc/type:extract-return-type (quote ((declare) (+ x 1))))
            :to-be-null))
  (it-sequential "extract-return-type-cases declare-with-a-non-cons-declaration"
    ;; (DECLARE FOO): DECL is (FOO), non-NIL, but (CAR DECL) is the bare
    ;; symbol FOO, not a CONS -- the AND's second conjunct false, distinct
    ;; from both cases above.
    (expect (cl-cc/type:extract-return-type (quote ((declare foo) (+ x 1))))
            :to-be-null))
  (it-sequential "extract-return-type-cases declaration-head-is-not-a-symbol"
    ;; (DECLARE (42 FOO)): (CAR DECL) is (42 FOO), a CONS, but (CAAR
    ;; DECL) is 42, not a symbol -- the innermost AND's own SYMBOLP
    ;; conjunct false, distinct from "declare-present-but-not-return-
    ;; type" above (a symbol that just isn't named RETURN-TYPE).
    (expect (cl-cc/type:extract-return-type (quote ((declare (42 foo)) (+ x 1))))
            :to-be-null)))

;;; ─── Typed AST nodes ─────────────────────────────────────────────────────

(it-sequential "parse-typed-defun-basic"
  (let ((node (cl-cc/type:parse-typed-defun '(defun foo ((x fixnum)) (+ x 1)))))
    (expect (cl-cc/type::ast-defun-typed-p node) :to-be-truthy)
    (expect (cl-cc/type:ast-defun-typed-name node) :to-be 'foo)
    (expect (cl-cc/type:ast-defun-typed-params node) :to-equal '(x))
    (expect (length (cl-cc/type:ast-defun-typed-param-types node)) :to-equal 1)
    (expect type-int :to-be-type-equal-to (first (cl-cc/type:ast-defun-typed-param-types node)))))

(it-sequential "parse-typed-defun-with-an-empty-body-defaults-return-type-to-any"
  ;; The bare-return-type computation's very first conjunct, (NOT (NULL
  ;; REST)), had only ever been observed true across every other test
  ;; here, since REST always carries at least a body form. An empty-
  ;; bodied defun -- degenerate, but syntactically legal input to this
  ;; parser -- makes REST NIL, so this conjunct alone short-circuits the
  ;; whole AND before any of the others run.
  (let ((node (cl-cc/type:parse-typed-defun '(defun foo ((x fixnum))))))
    (expect type-any :to-be-type-equal-to (cl-cc/type:ast-defun-typed-return-type node))
    (expect (cl-cc/type:ast-defun-typed-body node) :to-be-null)))

(it-sequential "parse-typed-defun-with-a-bare-return-type-symbol-before-the-body"
  ;; PARSE-TYPED-DEFUN's own RETURN-TYPE computation short-circuits at
  ;; (not (consp (first rest))) for every other test in this file, since
  ;; their REST always starts with a list (a DECLARE form or a body form).
  ;; A bare return-type symbol immediately after the lambda-list -- valid
  ;; Lisp-flavored-typed syntax, (defun name (params) return-type body) --
  ;; is the only way (first rest) is not a CONSP, reaching the two
  ;; previously-dark conjuncts: (not (eq (first rest) 'declare)) and the
  ;; actual PARSE-TYPE-SPECIFIER-MAYBE call.
  ;; Unlike the DECLARE form below, EXTRACT-RETURN-TYPE does not recognize
  ;; this bare-symbol shape, so BODY keeps the leading return-type symbol
  ;; rather than having it stripped -- a real, if surprising, asymmetry
  ;; between the two return-type spellings that this test documents.
  (let ((node (cl-cc/type:parse-typed-defun '(defun foo ((x fixnum)) string (+ x 1)))))
    (expect type-string :to-be-type-equal-to (cl-cc/type:ast-defun-typed-return-type node))
    (expect (cl-cc/type:ast-defun-typed-body node) :to-equal '(string (+ x 1)))))

(it-sequential "parse-typed-defun-consumes-a-leading-declare-return-type-form"
  ;; The pre-existing PARSE-TYPED-DEFUN test has no DECLARE form in its
  ;; body at all, so (cdr rest) -- BODY with the return-type declaration
  ;; stripped off -- was never reached, even though EXTRACT-RETURN-TYPE
  ;; itself is tested directly elsewhere in this file.
  (let ((node (cl-cc/type:parse-typed-defun
               '(defun foo ((x fixnum)) (declare (return-type string)) (+ x 1)))))
    (expect type-string :to-be-type-equal-to (cl-cc/type:ast-defun-typed-return-type node))
    (expect (cl-cc/type:ast-defun-typed-body node) :to-equal '((+ x 1)))))

(it-sequential "parse-typed-defun-treats-a-bare-declare-symbol-as-not-a-return-type"
  ;; PARSE-TYPED-DEFUN's bare-return-type conjuncts (NOT (CONSP (FIRST
  ;; REST))) and (NOT (EQ (FIRST REST) 'DECLARE)) had only ever been
  ;; observed true, via the bare-symbol test above ('STRING is neither a
  ;; CONSP nor EQ to 'DECLARE). A bare DECLARE symbol -- not wrapped in
  ;; parens, so still not a CONSP -- is the only way to make the second
  ;; conjunct false: EXTRACT-RETURN-TYPE also declines it (it requires
  ;; (CONSP (FIRST BODY))), so neither return-type source fires and the
  ;; default TYPE-ANY is used, body left untouched.
  (let ((node (cl-cc/type:parse-typed-defun '(defun foo ((x fixnum)) declare (+ x 1)))))
    (expect type-any :to-be-type-equal-to (cl-cc/type:ast-defun-typed-return-type node))
    (expect (cl-cc/type:ast-defun-typed-body node) :to-equal '(declare (+ x 1)))))

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
    (expect (cl-cc/type:looks-like-type-specifier-p (quote my-random-thing)) :to-be-falsy))
  (it-sequential "looks-like-type-specifier-p-cases non-symbol-head"
    ;; Every composite case above has a symbol HEAD; SYM-NAME-IN's own
    ;; SYMBOLP guard (shared by the composite-head-strings check) and the
    ;; "!"-prefix check's SYMBOLP guard both need a HEAD that is itself a
    ;; cons, not a symbol, to take their false branch.
    (expect (cl-cc/type:looks-like-type-specifier-p (quote ((nested) more))) :to-be-falsy)))

;;; ─── parse-type-specifier-maybe ──────────────────────────────────────────

(progn
  (it-sequential "parse-type-specifier-maybe-cases known"
    (expect type-int :to-be-type-equal-to (cl-cc/type::parse-type-specifier-maybe (quote fixnum))))
  (it-sequential "parse-type-specifier-maybe-cases unknown"
    (expect (cl-cc/type::parse-type-specifier-maybe (quote my-random-thing)) :to-be-null))
  (it-sequential "parse-type-specifier-maybe-cases looks-like-a-spec-but-fails-to-parse"
    ;; The UNKNOWN case above is filtered out by LOOKS-LIKE-TYPE-SPECIFIER-P
    ;; itself (a bare unrecognized symbol doesn't look like a spec at all),
    ;; so PARSE-TYPE-SPECIFIER-MAYBE's own HANDLER-CASE around
    ;; PARSE-TYPE-SPECIFIER had never actually caught a TYPE-PARSE-ERROR.
    ;; (OR) does look like a spec (its head is a known composite-type-head
    ;; string) but PARSE-TYPE-SPECIFIER signals on an empty OR.
    (expect (cl-cc/type::parse-type-specifier-maybe (quote (or))) :to-be-null)))

;;; ─── make-type-arrow ─────────────────────────────────────────────────────

(it-sequential "make-type-arrow-basic"
  (let ((ty (cl-cc/type:make-type-arrow (list type-int) type-string)))
    (expect (type-arrow-p ty) :to-be-truthy)
    (expect (length (type-arrow-params ty)) :to-equal 1)
    (expect type-string :to-be-type-equal-to (type-arrow-return ty))))

;;; ─── Error on non-s-expression ───────────────────────────────────────────

(it-sequential "parse-invalid-atom"
  (signals cl-cc/type:type-parse-error
    (cl-cc/type:parse-type-specifier 42)))
