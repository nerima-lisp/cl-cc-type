;;;; t/types-utility-test.lisp — TS-Style Utility Types Tests
;;;;
;;;; Tests for src/types-utility.lisp (FR-3303/3304):
;;;; type-level naturals/strings, record transforms, and the Writable, Readonly,
;;;; Pick, Omit, Exclude, Extract, NonNullable, ReturnType utility-type family.

(in-package :cl-cc-type/test)

(it-sequential "concrete-utility-type-helpers-operate-on-nats-strings-and-record-transforms"
  (let* ((nat-two (cl-cc/type:make-type-level-natural 2))
         (nat-five (cl-cc/type:type-plus nat-two 3))
         (template (cl-cc/type:template-literal-type
                    "user-" (cl-cc/type:make-type-level-string "id")))
         (record (cl-cc/type:make-type-record :fields (list (cons 'name cl-cc/type:type-string)
                                                            (cons 'age cl-cc/type:type-int))
                                              :row-var nil))
         (partial (cl-cc/type:partial-type record))
         (required (cl-cc/type:required-type partial))
         (frozen (cl-cc/type:freeze "value" cl-cc/type:type-string))
         (matrix-product (cl-cc/type:matrix-mul-type
                          (cl-cc/type:make-matrix-type 2 3 cl-cc/type:type-int)
                          (cl-cc/type:make-matrix-type 3 4 cl-cc/type:type-int)))
         (format-fn (cl-cc/type:format-type "~A => ~D")))
    (expect (cl-cc/type:type-level-natural-value nat-five) :to-equal 5)
    (expect (cl-cc/type:known-nat-value nat-five) :to-equal 5)
    (expect (cl-cc/type:type-level-string-value template) :to-equal "user-id")
    (let ((vec (cl-cc/type:make-length-indexed-vector-type 3 cl-cc/type:type-int)))
      (expect (cl-cc/type:type-constructor-p vec) :to-be-truthy)
      (expect (cl-cc/type:type-constructor-name vec) :to-be 'vector)
      (expect (cl-cc/type:type-level-natural-value (first (cl-cc/type:type-constructor-args vec)))
              :to-equal 3))
    (expect (cl-cc/type:type-advanced-p (cl-cc/type:has-field-type 'name cl-cc/type:type-string))
            :to-be-truthy)
    (expect (cl-cc/type:type-union-p (cl-cc/type:get-field-type 'name partial)) :to-be-truthy)
    (expect cl-cc/type:type-string :to-be-type-equal-to (cl-cc/type:get-field-type 'name required))
    (expect (cl-cc/type:frozen-value-p frozen) :to-be-truthy)
    (let ((args (cl-cc/type:type-constructor-args matrix-product)))
      (expect (cl-cc/type:type-level-natural-value (first args)) :to-equal 2)
      (expect (cl-cc/type:type-level-natural-value (second args)) :to-equal 4)
      (expect cl-cc/type:type-int :to-be-type-equal-to (third args)))
    (expect (cl-cc/type:type-arrow-p format-fn) :to-be-truthy)
    (expect (length (cl-cc/type:type-arrow-params format-fn)) :to-equal 2)))

(it-sequential "make-type-level-natural-rejects-non-natural-values"
  (signals error
      (cl-cc/type:make-type-level-natural -1))
  (signals error
      (cl-cc/type:make-type-level-natural "3")))

(it-sequential "type-mul-computes-fr-1701-type-level-natural-multiplication"
  ;; TYPE-PLUS is exercised above via NAT-FIVE; its sibling TYPE-MUL had no
  ;; test anywhere.
  (let ((product (cl-cc/type:type-mul (cl-cc/type:make-type-level-natural 3)
                                       (cl-cc/type:make-type-level-natural 4))))
    (expect (cl-cc/type:type-level-natural-value product) :to-equal 12)))

(it-sequential "type-level-natural-p-is-falsy-for-unrelated-types"
  (expect (cl-cc/type:type-level-natural-p (cl-cc/type:make-type-level-natural 3))
          :to-be-truthy)
  (expect (cl-cc/type:type-level-natural-p cl-cc/type:type-int) :to-be-falsy))

(it-sequential "type-level-natural-value-accepts-a-raw-non-negative-integer-directly"
  ;; Every pre-existing call passes a wrapped FR-1701 nat node, so the
  ;; COND's first clause, (AND (INTEGERP type) (NOT (MINUSP type))), had
  ;; only ever been observed false (via the wrapped-node calls) or reached
  ;; via a non-integer (also false) -- never its own true outcome.
  (expect (cl-cc/type:type-level-natural-value 5) :to-equal 5))

(it-sequential "type-level-natural-value-signals-when-the-value-is-not-statically-known"
  ;; Neither a raw non-negative integer nor a proper FR-1701 nat node with
  ;; a known integer arg: the COND's final ERROR clause was never reached.
  (signals error
      (cl-cc/type:type-level-natural-value "not-a-natural"))
  (signals error
      (cl-cc/type:type-level-natural-value cl-cc/type:type-int)))

(it-sequential "type-level-natural-value-signals-for-a-raw-negative-integer"
  ;; Every pre-existing call site passes either a non-negative raw integer
  ;; or a non-integer, so the first COND clause's (MINUSP type) conjunct
  ;; had only ever been observed false -- never its own true outcome. A
  ;; raw negative integer is INTEGERP but MINUSP, so it falls through to
  ;; the final ERROR clause rather than the wrapped-node clause (which
  ;; also fails, since a raw integer is never TYPE-LEVEL-NATURAL-P).
  (signals error
      (cl-cc/type:type-level-natural-value -5)))

(it-sequential "make-type-level-string-rejects-a-non-string-value"
  (signals error
      (cl-cc/type:make-type-level-string :not-a-string)))

(it-sequential "type-level-string-p-is-falsy-for-unrelated-types"
  (expect (cl-cc/type:type-level-string-p (cl-cc/type:make-type-level-string "id"))
          :to-be-truthy)
  (expect (cl-cc/type:type-level-string-p cl-cc/type:type-string) :to-be-falsy))

(it-sequential "type-level-string-value-accepts-a-raw-string-and-signals-otherwise"
  ;; TEMPLATE-LITERAL-TYPE never calls TYPE-LEVEL-STRING-VALUE on a raw
  ;; string part (it takes the PRINC-TO-STRING branch instead), so this
  ;; COND's first clause -- and its final ERROR clause -- were untested.
  (expect (cl-cc/type:type-level-string-value "already-a-string") :to-equal "already-a-string")
  (signals error
      (cl-cc/type:type-level-string-value 42)))

(it-sequential "get-field-type-rejects-a-non-record-type-and-an-unknown-field"
  (let ((record (cl-cc/type:make-type-record
                 :fields (list (cons 'name cl-cc/type:type-string))
                 :row-var nil)))
    (signals error
        (cl-cc/type:get-field-type 'name cl-cc/type:type-string))
    (signals error
        (cl-cc/type:get-field-type 'missing-field record))))

(it-sequential "get-field-type-matches-a-non-symbol-field-name-designator-case-insensitively"
  ;; %FIELD-NAME= falls back to PRINC-TO-STRING when its argument is not a
  ;; symbol; the pre-existing tests only ever search with a symbol.
  (let ((record (cl-cc/type:make-type-record
                 :fields (list (cons 'name cl-cc/type:type-string))
                 :row-var nil)))
    (expect cl-cc/type:type-string
            :to-be-type-equal-to (cl-cc/type:get-field-type "name" record))))

(it-sequential "get-field-type-matches-when-the-records-own-field-key-is-a-non-symbol"
  ;; The case above only ever drives %FIELD-NAME='s search-argument (LEFT)
  ;; through the non-symbol PRINC-TO-STRING fallback; every record's own
  ;; field key (RIGHT, matched via CAR) is conventionally a symbol, so that
  ;; side of the same fallback had never fired.
  (let ((record (cl-cc/type:make-type-record
                 :fields (list (cons "name" cl-cc/type:type-string))
                 :row-var nil)))
    (expect cl-cc/type:type-string
            :to-be-type-equal-to (cl-cc/type:get-field-type 'name record))))

(it-sequential "matrix-mul-type-rejects-non-matrix-arguments"
  (signals error
      (cl-cc/type:matrix-mul-type
       cl-cc/type:type-int
       (cl-cc/type:make-matrix-type 3 4 cl-cc/type:type-int)))
  ;; The case above only drives LEFT through the non-matrix path; the
  ;; guard's own (TYPE-CONSTRUCTOR-P right) conjunct had never been
  ;; observed false, since every other call passes a valid matrix RIGHT.
  (signals error
      (cl-cc/type:matrix-mul-type
       (cl-cc/type:make-matrix-type 2 3 cl-cc/type:type-int)
       cl-cc/type:type-int)))

(it-sequential "matrix-mul-type-rejects-mismatched-inner-dimensions"
  (signals error
      (cl-cc/type:matrix-mul-type
       (cl-cc/type:make-matrix-type 2 3 cl-cc/type:type-int)
       (cl-cc/type:make-matrix-type 4 4 cl-cc/type:type-int))))

(it-sequential "matrix-mul-type-rejects-mismatched-element-types"
  (signals error
      (cl-cc/type:matrix-mul-type
       (cl-cc/type:make-matrix-type 2 3 cl-cc/type:type-int)
       (cl-cc/type:make-matrix-type 3 4 cl-cc/type:type-string))))

(it-sequential "format-type-rejects-a-non-string-control-string"
  (signals error
      (cl-cc/type:format-type :not-a-string)))

(it-sequential "format-type-infers-float-and-char-directives"
  ;; The pre-existing test only ever drives ~A (string) and ~D (int); the
  ;; %FORMAT-DIRECTIVE-TYPE CASE clauses for float directives (~F ~E ~G ~$)
  ;; and ~C were never taken.
  (let ((float-fn (cl-cc/type:format-type "~F"))
        (char-fn (cl-cc/type:format-type "~C")))
    (expect (first (cl-cc/type:type-arrow-params float-fn))
            :to-be-type-equal-to cl-cc/type:type-float)
    (expect (first (cl-cc/type:type-arrow-params char-fn))
            :to-be-type-equal-to cl-cc/type:type-char)))

(it-sequential "format-type-rejects-an-unsupported-directive"
  ;; %FORMAT-DIRECTIVE-TYPE's OTHERWISE clause (returning NIL) drives
  ;; FORMAT-TYPE's own (T (ERROR ...)) arm -- neither was exercised.
  (signals error
      (cl-cc/type:format-type "~Z")))

(it-sequential "format-type-treats-a-doubled-tilde-as-a-literal-tilde-not-a-directive"
  (let ((fn (cl-cc/type:format-type "100~~ done")))
    (expect (cl-cc/type:type-arrow-params fn) :to-be-null)))

(it-sequential "format-type-tolerates-a-trailing-tilde-with-no-following-directive"
  (let ((fn (cl-cc/type:format-type "value~")))
    (expect (cl-cc/type:type-arrow-params fn) :to-be-null)))

(it-sequential "types-utility-family-covers-writable-deep-readonly-pick-omit-exclude-extract"
  (let* ((record (cl-cc/type:make-type-record
                  :fields (list (cons 'name cl-cc/type:type-string)
                                (cons 'age cl-cc/type:type-int))
                  :row-var nil))
         (writable (cl-cc/type:writable-type cl-cc/type:type-int))
         (deep (cl-cc/type:deep-readonly-type record))
         (picked (cl-cc/type:pick-type record '(name)))
         (omitted (cl-cc/type:omit-type record '(name)))
         (union (cl-cc/type:make-type-union
                 (list cl-cc/type:type-int cl-cc/type:type-string cl-cc/type:type-bool)))
         (excluded (cl-cc/type:exclude-type union cl-cc/type:type-string))
         (extracted (cl-cc/type:extract-type union cl-cc/type:type-int))
         (fn (cl-cc/type:make-type-arrow (list cl-cc/type:type-int) cl-cc/type:type-string)))
    (expect (cl-cc/type:type-capability-p writable) :to-be-truthy)
    (expect (cl-cc/type:type-capability-p deep) :to-be-truthy)
    (expect (= (length (cl-cc/type:type-record-fields picked)) 1) :to-be-truthy)
    (expect (car (first (cl-cc/type:type-record-fields picked))) :to-be 'name)
    (expect (= (length (cl-cc/type:type-record-fields omitted)) 1) :to-be-truthy)
    (expect (car (first (cl-cc/type:type-record-fields omitted))) :to-be 'age)
    (expect (cl-cc/type:type-union-p excluded) :to-be-truthy)
    (expect extracted :to-be-type-equal-to cl-cc/type:type-int)
    ;; Excluding every member collapses to type-null; extracting nothing does too.
    (expect (cl-cc/type:exclude-type (cl-cc/type:make-type-union (list cl-cc/type:type-int))
                                       cl-cc/type:type-int) :to-be-type-equal-to cl-cc/type:type-null)
    ;; Non-union exclude/extract go through the plain-type branches.
    (expect (cl-cc/type:exclude-type cl-cc/type:type-int cl-cc/type:type-string) :to-be-type-equal-to cl-cc/type:type-int)
    ;; EXCLUDE-TYPE's own non-union branch only had its "not a subtype, kept
    ;; as-is" outcome tested above; a non-union UNION that IS a subtype of
    ;; EXCLUDED collapses to TYPE-NULL, the other outcome of that same IF.
    (expect (cl-cc/type:exclude-type cl-cc/type:type-int cl-cc/type:type-int) :to-be-type-equal-to cl-cc/type:type-null)
    (expect (cl-cc/type:extract-type cl-cc/type:type-int cl-cc/type:type-int) :to-be-type-equal-to cl-cc/type:type-int)
    (expect (cl-cc/type:extract-type cl-cc/type:type-int cl-cc/type:type-string) :to-be-type-equal-to cl-cc/type:type-null)
    ;; non-nullable-type: direct union and non-union paths.
    (expect (cl-cc/type:non-nullable-type
              (cl-cc/type:make-type-union (list cl-cc/type:type-null cl-cc/type:type-int))) :to-be-type-equal-to cl-cc/type:type-int)
    (expect (cl-cc/type:non-nullable-type cl-cc/type:type-int) :to-be-type-equal-to cl-cc/type:type-int)
    (expect (cl-cc/type:return-type-of fn) :to-be-type-equal-to cl-cc/type:type-string)
    (signals error (cl-cc/type:return-type-of cl-cc/type:type-int))
    (signals error (cl-cc/type:pick-type cl-cc/type:type-int '(name)))
    (signals error (cl-cc/type:omit-type cl-cc/type:type-int '(name)))))

(it-sequential "deep-readonly-type-recurses-into-a-union-not-only-a-record"
  ;; DEEP-READONLY-TYPE's COND has a dedicated TYPE-UNION-P clause; the
  ;; pre-existing test only ever drives its TYPE-RECORD-P and fallback
  ;; (plain-type) clauses.
  (let ((deep (cl-cc/type:deep-readonly-type
               (cl-cc/type:make-type-union
                (list cl-cc/type:type-int cl-cc/type:type-string)))))
    (expect (cl-cc/type:type-capability-p deep) :to-be-truthy)
    (expect (cl-cc/type:type-union-p (cl-cc/type:type-capability-base deep)) :to-be-truthy)))

(it-sequential "partial-type-and-required-type-have-a-plain-type-fallback-branch"
  ;; Both IFs' pre-existing tests only ever drove the TYPE-RECORD-P arm.
  (expect (cl-cc/type:type-union-p (cl-cc/type:partial-type cl-cc/type:type-int)) :to-be-truthy)
  (expect (cl-cc/type:required-type cl-cc/type:type-int) :to-be-type-equal-to cl-cc/type:type-int))

(it-sequential "exclude-type-collapses-to-a-single-remaining-member-not-only-none-or-many"
  ;; EXCLUDE-TYPE's own COND (distinct source forms from EXTRACT-TYPE's
  ;; identically-shaped one) had its "exactly one member survives" clause
  ;; untested: the pre-existing test only ever left 0 or 2+ members.
  (expect (cl-cc/type:exclude-type
           (cl-cc/type:make-type-union (list cl-cc/type:type-int cl-cc/type:type-string))
           cl-cc/type:type-string)
          :to-be-type-equal-to cl-cc/type:type-int))

(it-sequential "non-nullable-type-covers-the-all-null-and-multi-member-union-cases"
  ;; The pre-existing test only exercises NON-NULLABLE-TYPE's single-
  ;; remaining-member clause; its "every member was null" (collapses to
  ;; type-null) and "several non-null members remain" (stays a union)
  ;; clauses were both untested.
  (expect (cl-cc/type:non-nullable-type (cl-cc/type:make-type-union (list cl-cc/type:type-null)))
          :to-be-type-equal-to cl-cc/type:type-null)
  (expect (cl-cc/type:type-union-p
           (cl-cc/type:non-nullable-type
            (cl-cc/type:make-type-union
             (list cl-cc/type:type-null cl-cc/type:type-int cl-cc/type:type-string))))
          :to-be-truthy))

